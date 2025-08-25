"""
pipeline_oferta_laboral
=============

:Author: Antonio Berlanga
:Release: 0.1
:Date: 30 Dec 2024



Ejecuta los scripts para el analisis descriptivo de cada quincena del SIAP.


Uso:

    python pipeline_oferta_laboral.py --help


Input son las bases de datos en accdb.

Output son varias graficas, tablas, etc. y un reporte de qmd.

"""

################
# Get modules needed:
import sys
import os
import re
import subprocess
import pprint
from typing import List

# Pipeline:
from ruffus import (
    follows,
    originate,
    transform,
    regex,
    suffix,
    mkdir,
)

# Database:
import sqlite3

# CGAT tools:
import cgatcore.iotools as iotools
from cgatcore import pipeline as P
import cgatcore.experiment as E


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

################
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


################

################
# Load options from the config file
# Pipeline configuration
ini_paths = [
    os.path.abspath(os.path.dirname(sys.argv[0])),
    "../",
    os.getcwd(),
]


def get_params_files(paths: List[str] = ini_paths) -> List[str]:
    """
    Search for python ini files in given paths, append files with full
    paths for :func:`P.get_parameters` to read. The current default paths are
    where this code is executing, one directory up, and the current directory.
    """
    params_files: List[str] = []
    for path in paths:
        for f in os.listdir(os.path.abspath(path)):
            ini_file = re.search(r"pipelin(.*).yml", f)
            if ini_file:
                ini_file = os.path.join(os.path.abspath(path), ini_file.group())
                params_files.append(ini_file)
    return params_files


P.get_parameters(
    [
        "%s/pipeline.yml" % os.path.splitext(__file__)[0],
        "../pipeline.yml",
        "pipeline.yml",
    ],
)


PARAMS = P.PARAMS
# Print the options loaded from ini files and possibly a .cgat file:
pprint.pprint(PARAMS)
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


def get_ini_path() -> str:
    """
    Get the path to scripts for this project, e.g.
    project_xxxx/code/project_xxxx/:
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


################


################
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


################

################
# Specific pipeline tasks
# Tools called need the full path or be directly callable


# TO DO: continue here

INI_file = PARAMS


@transform((INI_file, "conf.py"), regex(r"(.*)\.(.*)"), r"\1.counts")
def countWords(infile, outfile):
    """count the number of words in the pipeline configuration files."""

    # the command line statement we want to execute
    statement = """awk 'BEGIN { printf("word\\tfreq\\n"); }
    {for (i = 1; i <= NF; i++) freq[$i]++}
    END { for (word in freq) printf "%%s\\t%%d\\n", word, freq[word] }'
    < %(infile)s > %(outfile)s"""

    # execute command in variable statement.
    #
    # The command will be sent to the cluster.  The statement will be
    # interpolated with any options that are defined in in the
    # configuration files or variable that are declared in the calling
    # function.  For example, %(infile)s will we substituted with the
    # contents of the variable "infile".
    P.run(statement)


@transform(countWords, suffix(".counts"), "_counts.load")
def loadWordCounts(infile, outfile):
    """load results of word counting into database."""
    P.load(infile, outfile, "--add-index=word")


################


################
# Copy to log environment from conda:
@follows(loadWordCounts)
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


################

################
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


################


###################################################
# target functions for code execution             #
###################################################


################
# Create the "full" pipeline target to run all functions specified
@follows(make_report)
@originate("pipeline_complete.touch")
def full(outfile):
    statement = "touch %(outfile)s"
    P.run(statement)


################


################
def main(argv=None):
    if argv is None:
        argv = sys.argv
    P.main(argv)


if __name__ == "__main__":
    sys.exit(P.main(sys.argv))
################
