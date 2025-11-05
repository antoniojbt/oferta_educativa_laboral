"""
pipeline_oferta_laboral
=============

:Author: Antonio Berlanga
:Release: 0.1
:Date: 30 Dec 2024

Ejecuta los scripts para el analisis descriptivo de cada quincena del SIAP.


# Data:
# ~/Documents/work/comp_med_medicina_datos/projects/int_op/oferta_educativa_laboral/data/data_UP/access_SIAP_18092024/processed/pipe_tests

# Results:
# ~/Documents/work/comp_med_medicina_datos/projects/int_op/oferta_educativa_laboral/results

# Code:
# ~/Documents/work/science/devel/github/antoniojbt/oferta_educativa_laboral/oferta_educativa_laboral/pipeline


# Run:
  # Load once?
    # 1_dir_locations.R
  # Fail early:
    # 1b_accdb_tables_check.R
  # Actual work:
    # 2_clean_dups_col_types.R #
    # If subsetting: 2b_clean_subset.R
    # 3_explore.R
    # 4_bivar.R

# Load:
# funcs_epi_source.R
# epi_plot_theme_imss provided by episcout

# Not needed:
# 2c_subset_PLZOCU.R
# blurbs.R
# 3b_skim_summary.qmd

Uso:

    python pipeline_oferta_laboral.py --help


Input son las bases de datos en accdb.

Output son varias graficas, tablas, etc. y un reporte de qmd.

"""

###################################################
# Modules
###################################################


################
# Get modules needed:
import sys
import os
import re
import subprocess
import glob
from typing import List

# Pipeline: attempt to import ruffus but fall back to no-op stubs for
# testing environments where the package is missing.
try:  # pragma: no cover - simple import guard
    from ruffus import (
        follows,
        originate,
        transform,
        suffix,
        regex,
        mkdir,
    )
except ModuleNotFoundError:  # pragma: no cover - executed only if Ruffus absent

    def _stub_decorator(*d_args, **d_kwargs):  # type: ignore
        def wrapper(func):
            return func

        return wrapper

    def follows(*args, **kwargs):  # noqa: D401 - mimic Ruffus decorator
        return _stub_decorator

    def originate(*args, **kwargs):  # noqa: D401 - mimic Ruffus decorator
        return _stub_decorator

    def transform(*args, **kwargs):  # noqa: D401 - mimic Ruffus decorator
        return _stub_decorator

    def suffix(*args, **kwargs):  # noqa: D401 - mimic Ruffus decorator
        return _stub_decorator

    def regex(*args, **kwargs):  # noqa: D401 - mimic Ruffus decorator
        return _stub_decorator

    def mkdir(directory):  # noqa: D401 - mimic Ruffus mkdir helper
        os.makedirs(directory, exist_ok=True)
        return directory


# Database:
import sqlite3

# CGAT tools may not be installed during testing. Provide lightweight stubs so
# the module can still be imported and inspected.
try:  # pragma: no cover - simple import guard
    import cgatcore.iotools as iotools
    from cgatcore import pipeline as P
    import cgatcore.experiment as E
except ModuleNotFoundError:  # pragma: no cover

    class _Dummy:
        """Simplistic object to stand in for missing cgatcore modules."""

        PARAMS: dict = {}

        def __getattr__(self, name):
            def _stub(*args, **kwargs):
                return None

            return _stub

    iotools = _Dummy()
    P = _Dummy()
    E = _Dummy()
# Import this project's module, uncomment if building something more elaborate:
# try:
#    import  pipeline_template.module_template

# except ImportError:
#    print("Could not import this project's module, exiting")
#    raise

# Import additional packages:
# Set path if necessary:
# os.system('''export PATH="~/xxxx/xxxx:$PATH"''')
################


###################################################
# Pipeline preliminaries
# Locations, config file, script paths
# DB connector
###################################################

# Get locations of source code (this file)
# os.path.join note: a subsequent argument with an '/' discards anything
# before it
# For function to search path see:
# http://stackoverflow.com/questions/4519127/setuptools-package-data-folder-location

_ROOT = os.path.abspath(os.path.dirname(__file__))

def get_dir(path: str = _ROOT) -> str:
    """Get the absolute path to where this function resides. Useful for
    determining the user's path to a package. If a sub-directory is given it
    will be added to the path returned. Use '..' to go up directory levels."""
    # src_top_dir = os.path.abspath(os.path.join(_ROOT, '..'))
    src_dir = _ROOT
    return os.path.abspath(os.path.join(src_dir, path))


# Load options from the config file
# Pipeline configuration
ini_paths = [
    os.path.abspath(os.path.dirname(sys.argv[0])),
    "../",
    os.getcwd(),
]


def get_params_files(paths: List[str] | None = None) -> List[str]:
    """Return a list of configuration files found in ``paths``.

    Parameters
    ----------
    paths:
        Iterable of directory paths to search.  If ``None`` (default), the
        module level :data:`ini_paths` list is used.  Passing ``None`` ensures
        that runtime modifications to :data:`ini_paths` (e.g. by tests) are
        respected.

    Returns
    -------
    list of str
        Full paths to ``pipeline*.yml`` files within the supplied directories.
    """

    if paths is None:
        paths = ini_paths

    params_files: List[str] = []
    for path in paths:
        for f in os.listdir(os.path.abspath(path)):
            ini_file = re.search(r"pipelin(.*).yml", f)
            if ini_file:
                ini_file = os.path.join(os.path.abspath(path), ini_file.group())
                params_files.append(ini_file)
    return params_files


def getParamsFiles(paths: List[str] | None = None) -> List[str]:
    """Backward compatible wrapper for :func:`get_params_files`."""

    return get_params_files(paths)


def get_ini_paths() -> str:
    """Return the ``project_scripts_dir`` path from :data:`PARAMS`.

    The returned path is guaranteed to end with a trailing ``/`` to match the
    expectations of legacy code and tests.  A :class:`KeyError` is raised if
    the required keys are missing from :data:`PARAMS`.
    """

    scripts_dir = PARAMS["general"]["project_scripts_dir"]
    return f"{scripts_dir.rstrip('/')}/"


def getINIpaths() -> str:
    """Backward compatible wrapper for :func:`get_ini_paths`."""

    return get_ini_paths()


config_path = os.path.join(os.path.dirname(__file__), "configuration", "pipeline.yml")
P.get_parameters(
    [config_path, "../pipeline.yml", "pipeline.yml"],
)


PARAMS = P.PARAMS
# Print the options loaded from ini files and possibly a .cgat file:
# pprint.pprint(PARAMS)
# From the command line:
# python ../code/pq_example/pipeline_pq_example/pipeline_pq_example.py printconfig


# Set global parameters here, obtained from the ini file
# e.g. get the cmd tools to run if specified:
# cmd_tools = P.asList(PARAMS["cmd_tools_to_run"])


def get_py_exec():
    """
    Look for the python executable. This is only in case of running on a Mac
    which needs pythonw for matplotlib for instance.
    """

    py_exec = "python"
    try:
        config_exec = PARAMS["general"]["py_exec"]
    except KeyError as exc:
        raise KeyError(
            "Missing 'py_exec' setting under 'general' in pipeline configuration"
        ) from exc
    if not config_exec:
        raise ValueError("Configuration 'general.py_exec' must not be empty")
    if "python" in str(config_exec):
        py_exec = str(config_exec)
    return py_exec


# get_py_exec()


def get_ini_path() -> str:
    """
    Get the path to scripts for this project, e.g.
    ../scripts/:
    e.g. my_cmd = "%(scripts_dir)s/bam2bam.py" % P.Parameters.get_params()
    """
    # Check getParams as was updated to get_params but
    # PARAMS = P.Parameters.get_parameters(get_params_files())
    # is what seems to work
    try:
        project_scripts_dir = "{}/".format(PARAMS["general"]["project_scripts_dir"])
        E.info(
            """
               Location set for the projects scripts is:
               {}
               """.format(
                project_scripts_dir
            )
        )
    except KeyError:
        E.warn(
            """
               Could not set project scripts location, this needs to be
               specified in the project ini file.
               """
        )
        raise

    return project_scripts_dir


# Utility functions
def connect():
    """utility function to connect to database.

    Use this method to connect to the pipeline database.
    Additional databases can be attached here as well.

    Returns an sqlite3 database handle.
    """

    dbh = sqlite3.connect(PARAMS["database"]["name"])
    statement = """ATTACH DATABASE '%s' as annotations""" % (
        PARAMS["annotations"]["database"]
    )
    cc = dbh.cursor()
    cc.execute(statement)
    cc.close()

    return dbh

def get_initial_files():
    """Utility function to retrieve .accdb file names

    Use this function to get names from .accdb files and store it
    in a python list. The list is used as a ruffus input for the
    convert_to_csv method of the pipeline.
    
    Returns an empty list if no .accdb files are found, allowing the
    module to be imported without errors. The pipeline will fail at
    runtime if no files are available when tasks are executed.
    """
    initial_files = glob.glob("../../data/*.accdb")
    #TODO: handle unsupported file names, eg: names with spaces
    if not initial_files:
        # Return empty list during import to allow testing
        # The pipeline will naturally skip tasks if no input files exist
        print("Warning: No .accdb files found in the data directory!")
        return []
    else:
        print(f"Success, .accdb files found are: {initial_files}")
    return initial_files

###################################################
# Specific pipeline tasks
###################################################

# Tools called need the full path or be directly callable


# TO DO: continue here

# ----------------------------------------------------------------------
# Example tasks for converting Access databases and running R scripts.
# These are minimal placeholders so the pipeline can be imported and its
# task graph examined during testing.

results_dir = PARAMS.get("paths", {}).get("results_dir", "results")


@follows(mkdir(results_dir))
@transform(get_initial_files(), regex(r".*/([^/]+)\.accdb$"), r"../../results/\1.done")
def convert_to_csv(infile, outfile):
    """Dummy step that would convert .accdb tables to CSV files."""
    project_root = os.environ.get('PROJECT_ROOT', '../..')
    statement1 = (
    f"bash scripts/accdb_to_csv_encodings_copy.sh {infile} "
    f"{project_root}/results"
    )
    P.run(statement1)
    statement2 = "touch %(outfile)s"
    P.run(statement2)


@transform(convert_to_csv, suffix(".csv"), "_tables_check.rdata.gzip")
def run_tables_check(infile, outfile):
    """Dummy step that would run the 1b_accdb_tables_check.R script."""
    statement = "touch %(outfile)s"
    P.run(statement)


# Backwards compatibility for older tests
run_1b_accdb_tables_check = run_tables_check


@transform(run_tables_check, suffix(".rdata.gzip"), "_summary.rdata.gzip")
def countWords(infile, outfile):
    """Dummy processing of the checked tables output."""
    statement = "touch %(outfile)s"
    P.run(statement)


@transform(countWords, suffix("_summary.rdata.gzip"), "_counts.load")
def loadWordCounts(infile, outfile):
    """Load results of word counting into database."""
    P.load(infile, outfile, "--add-index=word")


# Build the report:
report_dir = "pipeline_report"


@follows(mkdir(report_dir), convert_to_csv)
def make_report():
    """Run a report generator script (e.g. with quarto render options)
    generate_report.R will create an html quarto document.
    """
    report_path = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "pipeline_report")
    )
    if (
        os.path.exists(report_dir)
        and os.path.isdir(report_dir)
        and not os.listdir(report_dir)
    ):

        statement = """cd {} ;
                       Rscript generate_report.R
                    """.format(
            report_dir
        )
        E.info("""Building report in {}.""".format(report_dir))
#        P.run(statement)

    elif (
        os.path.exists(report_dir)
        and os.path.isdir(report_dir)
        and os.listdir(report_dir)
    ):
        raise RuntimeError(
            """{} exists, not overwriting. Delete the folder and re-run make_report""".format(
                report_dir
            )
        )

    else:
        raise RuntimeError(
            """The directory "pipeline_report" does not exist. Are the paths correct? {}""".format(
                report_path
            )
        )

    return


###################################################
# Report and environment info
###################################################


# Copy to log environment from conda:
@follows(make_report)
@originate("conda_info.txt")
def conda_info(outfile):
    """
    Save to logs conda information and packages installed.
    """

    packages = "conda_packages.txt"
    channels = "conda_channels.txt"
    environment = "environment.yml"

    statement = """conda info -a > %(outfile)s ;
                   conda list -e > %(packages)s ;
                   conda list --show-channel-urls > %(channels)s ;
                   conda env export > %(environment)s
                """
# TODO: remove comment to run statement after updating to micromamba commands
#    P.run(statement)


# Create the "full" pipeline target to run all functions specified


@follows(conda_info)
@originate("pipeline_complete.touch")
def full(outfile):
    statement = "touch %(outfile)s"
    P.run(statement)


###################################################
# Execute
###################################################


def main(argv=None):
    if argv is None:
        argv = sys.argv
    P.main(argv)


if __name__ == "__main__":
    sys.exit(P.main(sys.argv))
