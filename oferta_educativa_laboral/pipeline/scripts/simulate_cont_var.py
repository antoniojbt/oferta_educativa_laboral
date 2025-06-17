##!/usr/bin/env python3
"""
simulate_cont_var.py
======================

:Author: |author_names|
:Release: |version|
:Date: |today|


Purpose
=======

Generate a random set of quantitative variables of arbitrary rows and columns.
These are then intended to be used for QTL analysis testing for example.
Rows are features (variables) and columns are individuals (samples).


Usage and options
=================

[--sample-size=<int>] [-O FILE]

Usage:
       simulate_cont_var.py (--createDF) [options]
       simulate_cont_var.py --config=<file> [options]
       simulate_cont_var.py [-h | --help] [-V | --version]

Options:
    --createDF              Create a pandas data frame
    --config=<file>         Configuration CSV to describe columns
    --sample-size=<int>     Specify a sample size (number of rows) [default: 1000]
    --var-size=<int>        Specify the number of variables (number of columns) [default: 10000]
    --mean=<float>          Mean value of distribution [default: 2.0]
    --sd=<float>            Standard deviation of distribution [default: 0.10]
    --lower-bound=<float>   Lower bound value for distribution [default: 0.0]
    --upper-bound=<float>   Upper bound value for distribution [default: 20.0]
    -O FILE                 Output file name
    -h --help               Show this screen
    -V --version            Show version


Input:

None

Output:

Saves a dataframe to disk.


Requirements:

Python packages only.


Documentation
=============

    Modified from:

https://github.com/antoniojbt/teaching_ICL/blob/master/code/simulate_cont_var.py

"""
##############
# Get all the modules needed
# Understanding Python:
# import this

# System:
import sys

# Options and help:
import docopt

# Data science:
import pandas
import numpy as np
import scipy.stats as stats

# Import additional packages:
import string  # this is used in the pandas function
import random

##############

##############
#####
# Create a pandas dataframe and save to disk:


def id_generator(
    text="ID_", size=6, chars=string.ascii_uppercase + string.digits, sample_size=1000
):
    """Generates a random sequence of letters and numbers and outputs a pandas
    series  of a given sample size that is is
    """

    # Modified from:
    # https://stackoverflow.com/questions/2257441/random-string-generation-with-upper-case-letters-and-digits-in-python?rq=1

    ID_list = []
    sample_size = sample_size + 1  # Python index is 0-based, stop number is
    # excluded
    for i in range(1, sample_size):
        i = "".join(random.choice(chars) for i in range(size))
        i = str(text + i)
        ID_list.append(i)

    ID_list = pandas.Series(ID_list)
    # print(ID_list.head(),
    #      ID_list.tail(),
    #      ID_list.describe(),
    #      )

    return ID_list


def number_generator(lower_bound=0, upper_bound=1001, mean=1, sd=1, sample_size=1000):
    """Generate a set of random values based on a given mean, standard
    deviation, list size and range from a normal distribution.
    The output is a pandas series of a given sample size.
    """
    # See:
    # https://docs.scipy.org/doc/scipy-0.17.0/reference/generated/scipy.stats.truncnorm.html
    # stackoverflow how-to-specify-upper-and-lower-limits
    # In Python indexing is 0-based (includes the start but excludes the stop)
    sample = stats.truncnorm.rvs(
        a=lower_bound, b=upper_bound, loc=mean, scale=sd, size=sample_size
    )
    sample = pandas.Series(sample)
    # print(sample.head(),
    #      sample.tail(),
    #      sample.describe(),
    #      )

    return sample


def create_df_from_config(
    config_path: str,
    sample_size: int = 1000,
    outfile: str | None = None,
    seed: int | None = None,
) -> pandas.DataFrame:
    """Generate a DataFrame based on a CSV configuration file.

    Parameters
    ----------
    config_path : str
        Path to the CSV file describing the columns.
    sample_size : int, default 1000
        Number of rows to generate.
    outfile : str | None, optional
        If provided, save the generated DataFrame to this path.
    seed : int | None, optional
        Random seed for reproducibility.
    """

    if seed is not None:
        random.seed(seed)
        np.random.seed(seed)

    config = pandas.read_csv(config_path)
    df = pandas.DataFrame(index=range(sample_size))

    for _, row in config.iterrows():
        name = str(row.get("col_name"))
        dtype = str(row.get("type", "float")).lower()
        dist = str(row.get("dist", "truncnorm")).lower()
        mean = row.get("mean", 0.0)
        sd = row.get("sd", 1.0)
        lower = row.get("lower", 0.0)
        upper = row.get("upper", 1.0)

        if dist == "categorical":
            levels = str(row.get("levels", "")).split("|")
            probs = row.get("probabilities")
            if pandas.isna(probs):
                weights = None
            else:
                weights = [float(x) for x in str(probs).split("|")]
            values = random.choices(levels, weights=weights, k=sample_size)
            series = pandas.Series(values, dtype="category")
        elif dist == "uniform":
            series = stats.uniform.rvs(loc=lower, scale=upper - lower, size=sample_size)
        elif dist == "lognormal":
            series = np.random.lognormal(mean, sd, size=sample_size)
        elif dist == "id":
            series = id_generator(text=name + "_", sample_size=sample_size)
        else:  # truncnorm
            a = (float(lower) - float(mean)) / float(sd)
            b = (float(upper) - float(mean)) / float(sd)
            series = stats.truncnorm.rvs(
                a=a,
                b=b,
                loc=mean,
                scale=sd,
                size=sample_size,
            )

        if dtype == "int":
            series = pandas.Series(series).round().astype("Int64")
        elif dtype == "string":
            series = pandas.Series(series).astype(str)
        else:
            series = pandas.Series(series)

        miss = row.get("missing_rate", 0)
        if miss and float(miss) > 0:
            mask = np.random.rand(sample_size) < float(miss)
            series[mask] = pandas.NA

        df[name] = series

    if outfile:
        df.to_csv(outfile, sep="\t", index=False, na_rep="NA")

    return df


def createDF(
    var_size=10000,
    sample_size=1000,
    mean=2.0,
    sd=0.10,
    lower_bound=0.0,
    upper_bound=20.0,
    outfile="continuous_var_simulation.tsv",
):
    """
    Generate a pandas dataframe that uses random IDs and random values from
    a given distribution given a mean, standard
    deviation, list size and range from a normal distribution.
    """

    # Generate an empty dataframe:
    #    var_df = pandas.DataFrame({'sample_ID': id_generator(text = 'sample_',
    #                                                         size = 6,
    #                                                         chars = string.ascii_uppercase + string.digits,
    #                                                         sample_size = sample_size),
    #                               },
    #                                )
    var_df = pandas.DataFrame()
    values = []
    for i in range(sample_size):
        value = str("per" + str(i))
        values.append(value)

    # Add to dataframe:
    var_df["sample_ID"] = values

    # Add and arbitrary number of rows and columns:
    for i in range(var_size):
        # Generate one variable name:
        var_ID = str("var" + str(i))
        #        id_generator(text = 'var_',
        #                              size = 6,
        #                              chars = string.ascii_uppercase + string.digits,
        #                              sample_size = 1)
        # id_generator returns a pandas series, convert to string:
        #       var_ID = var_ID.to_string(index = False)

        # Generate values for the variable:
        var_value = number_generator(
            lower_bound=lower_bound,
            upper_bound=upper_bound,
            mean=mean,
            sd=sd,
            sample_size=sample_size,
        )

        var_df[str(var_ID)] = var_value

    # Transpose file so that columns are features
    var_df = var_df.set_index("sample_ID").transpose()

    print(
        "\n",
        "The first rows of your data frame are:",
        "\n",
        "\n",
        var_df.head(),
        "\n",
        "\n",
        "The last rows of your data frame are:",
        "\n",
        "\n",
        var_df.tail(),
        "\n",
        "\n",
        "Some basic stats:" "\n",
        "\n",
        var_df.describe(),
        "\n",
    )

    # Save the file to disk with a default name:
    print(
        "\n", "Saving the dataframe as a tab separated file: {}".format(outfile), "\n"
    )
    var_df.to_csv(
        outfile,
        sep="\t",
        na_rep="NA",
        header=True,
        index=True,
    )
    return var_df


#####
##############


##############
def main():
    """with docopt main() expects a dictionary with arguments from docopt()
    docopt will automatically check your docstrings for usage, set -h, etc.
    """
    version = "0.2.0"
    options = docopt.docopt(__doc__, version=version)
    welcome_msg = str("\n" + "Welcome to simulate_cont_var.py v{}" + "\n").format(
        version
    )
    print(welcome_msg)
    # print(options)
    docopt_error_msg = str("\n" + "simulate_cont_var.py exited due to an error." + "\n")
    docopt_error_msg = str(
        docopt_error_msg
        + "\n"
        + "Try  --help"
        + "\n"
        + "\n"
        + "Options in place:"
        + "\n"
        + str(options)
        + "\n"
    )

    try:
        if options["--config"]:
            sample_size = (
                int(options["--sample-size"]) if options["--sample-size"] else 1000
            )
            outfile = (
                str(options["-O"]).strip("[]").strip("''") + ".tsv"
                if options["-O"]
                else "continuous_var_simulation.tsv"
            )
            config_path = str(options["--config"])
            create_df_from_config(
                config_path=config_path,
                sample_size=sample_size,
                outfile=outfile,
            )
        elif options["--createDF"]:
            # if not options['--sample-size']:
            #    sample_size = 1000
            #    print(''' Using default values for sample size.''')
            if options["--sample-size"] and len(options["--sample-size"]) > 0:
                sample_size = str(options["--sample-size"]).strip("[]").strip("''")
                sample_size = int(sample_size)
                print("\n", "Your sample size is: {}".format(sample_size))

            # if not options['--var-size']:
            #    var_size = 10000
            #    print(''' Using default values for number of variables.''')
            if options["--var-size"]:
                var_size = str(options["--var-size"]).strip("[]").strip("''")
                var_size = int(var_size)
                print("\n", "Number of variables is: {}".format(var_size))

            # if not options['--mean']:
            #    mean = 2.0
            #    print('no mean')
            #    print('\n', 'Mean is: {}'.format(mean))
            if options["--mean"]:
                mean = str(options["--mean"]).strip("[]").strip("''")
                mean = float(mean)
                print("\n", "Mean is: {}".format(mean))

            # if not options['--sd']:
            #    sd = 0.10
            #    print('\n', 'SD is: {}'.format(sd))
            if options["--sd"]:
                sd = str(options["--sd"]).strip("[]").strip("''")
                sd = float(sd)
                print("\n", "SD is: {}".format(sd))

            # if not options['--lower-bound']:
            #    lower_bound = 0.0
            #    print('\n', 'Lower bound of distribution is: {}'.format(lower_bound))
            if options["--lower-bound"]:
                lower_bound = str(options["--lower-bound"]).strip("[]").strip("''")
                lower_bound = float(lower_bound)
                print("\n", "Lower bound of distribution is: {}".format(lower_bound))

            # if not options['--upper-bound']:
            #    upper_bound = 20.0
            #    print('\n', 'Upper bound of distribution is: {}'.format(upper_bound))
            if options["--upper-bound"]:
                upper_bound = str(options["--upper-bound"]).strip("[]").strip("''")
                upper_bound = float(upper_bound)
                print("\n", "Upper bound of distribution is: {}".format(upper_bound))

            if not options["-O"]:
                outfile = "continuous_var_simulation.tsv"
                print("\n", "Saving your dataframe with the name: {}".format(outfile))
            elif options["-O"] and len(options["-O"]) > 0:
                outfile = str(options["-O"]).strip("[]").strip("''")
                outfile = str(outfile + ".tsv")
                print("\n", "Saving your dataframe with the name: {}".format(outfile))

            createDF(
                sample_size=sample_size,
                var_size=var_size,
                outfile=outfile,
                mean=mean,
                sd=sd,
                lower_bound=lower_bound,
                upper_bound=upper_bound,
            )

        else:
            print(docopt_error_msg)
            print(
                """ Did you ask for the --createDF option?
                      Is your --sample-size an integer and greater than 0?
                      Did you set a variable size?
                      Exiting...
                  """
            )
            sys.exit()

    # Handle exceptions:
    except docopt.DocoptExit:
        print(docopt_error_msg)
        raise


##############


##############
# Finish and exit with docopt arguments:
if __name__ == "__main__":
    sys.exit(main())
##############
