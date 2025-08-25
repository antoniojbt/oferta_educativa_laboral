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


def getDir(path=_ROOT):
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


def getParamsFiles(paths=ini_paths):
    """
    Search for python ini files in given paths, append files with full
    paths for P.getParameters() to read.
    Current paths given are:
    where this code is executing, one up, current directory
    """
    p_params_files = []
    for path in ini_paths:
        for f in os.listdir(os.path.abspath(path)):
            ini_file = re.search(r"pipelin(.*).yml", f)
            if ini_file:
                ini_file = os.path.join(os.path.abspath(path), ini_file.group())
                p_params_files.append(ini_file)
    return p_params_files


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

    try:
        if str("python") in PARAMS["general"]["py_exec"]:
            py_exec = "{}".format(PARAMS["general"]["py_exec"])
    except NameError:
        E.warn(
            """
               You need to specify the python executable, just "python" or
               "pythonw" is needed in pipeline.yml.
               """
        )
    # else:
    #    test_cmd = subprocess.check_output(['which', 'pythonw'])
    #    sys_return = re.search(r'(.*)pythonw', str(test_cmd))
    #    if sys_return:
    #        py_exec = 'pythonw'
    #    else:
    #        py_exec = 'python'
    return py_exec


# get_py_exec()


def getINIpaths():
    """
    Get the path to scripts for this project, e.g.
    ../scripts/:
    e.g. my_cmd = "%(scripts_dir)s/bam2bam.py" % P.Parameters.get_params()
    """
    # Check getParams as was updated to get_params but
    # PARAMS = P.Parameters.get_parameters(getParamsFiles())
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
@originate(os.path.join(results_dir, "dummy.csv"))
def convert_to_csv(outfile):
    """Dummy step that would convert .accdb tables to CSV files."""
    statement = "touch %(outfile)s"
    P.run(statement)


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


@follows(mkdir(report_dir))
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
        P.run(statement)

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
    P.run(statement)


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
