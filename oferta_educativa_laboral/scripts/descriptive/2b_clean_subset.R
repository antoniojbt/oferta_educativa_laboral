# ////////////
# Script information ----
# SIAP
# Unidad de Personal
# Noviembre 2024
# Subset dataframe
# Input is rdata output from script:
# 2_clean_dups_col_types.R

# Output is rdata with subset dataframe for desc stats, plots, etc.
# ////////////


# ////////////
# Global options ----

# ===
# Stop on error:
# options(error = stop)
# ===
# ////////////


# ////////////
# Import libraries ----
library(data.table)
library(episcout)
library(tidyverse)
library(log4r)
# library(renv)
# command line arguments: input RData and output directory
args <- commandArgs(trailingOnly = TRUE)
if (length(args) >= 1) infile_path <- args[1]
if (length(args) >= 2) results_subdir <- args[2]
# ////////////


# ////////////
# Set working directory to the project root  ----
setwd(here::here())
# renv should be picked up automatically, see 0_xx in project_tools if it interrupts
getwd()
# ////////////


# ////////////
# Load rdata file ----

# ===
rdata_dir <- 'data/data_UP/access_SIAP_18092024/processed/'

# TO DO: Manually set:
# infile <- '2_clean_dups_col_types_Qna_17_Bienestar_2024.rdata.gzip'
# infile <- '2_clean_dups_col_types_Qna_17_Plantilla_2024.rdata.gzip'
infile <- '2_clean_dups_col_types_Qna_07_Plantilla_2025.rdata.gzip'

# For double subset, eg first meds, then by OOAD:
# infile <- "2b_clean_subset_2_clean_dups_col_types_Qna_17_Plantilla_2024_meds.rdata.gzip"
# ===

# ===
# Full path and file name:
infile_path <- paste0(rdata_dir, infile)
print(infile_path)

print(dir(path = normalizePath(rdata_dir), all.files = TRUE))

load(infile_path)
ls()
# ===


# ===
# TO DO: set manually
# Needs column and value
# From e.g.:
data_f <- data_f # rstudio warning
colnames(data_f)
epi_head_and_tail(data_f, cols = ncol(data_f))

summary(data_f$DESCRIP_CLASCATEG)
summary(data_f$DELEGACION)

col_to_subset <- 'DESCRIP_CLASCATEG'
value_to_subset <- '9.RESIDENTES'
# value_to_subset <- '1.MÉDICOS'
# value_to_subset <- '2.ENFERMERAS'

# col_to_subset <- 'DELEGACION'
# value_to_subset <- 'Chiapas'


# TO DO: Manually set:
subset_n <- 'resids'
# subset_n <- 'enfermeras'
# ===


# ===
# Get rid of RStudio warnings for loaded objects:
project_root <- project_root
data_dir <- data_dir
results_dir <- results_dir

all_colnames <- all_colnames
char_cols <- char_cols
date_cols <- date_cols
fact_cols <- fact_cols
int_cols <- int_cols
id_cols <- id_cols
num_cols <- num_cols

print(project_root)
setwd(here::here())
getwd()
print(dir(path = normalizePath(project_root), all.files = TRUE))
# ===
# ////////////


# ////////////
# Source functions/scripts/etc
# TO DO:
# Source (until I update episcout)
source(file.path(paste0(code_dir, '/scripts/funcs_epi_source.R')))
# ////////////


# ////////////
# Output dir, based on today's date ----
script_n <- '2b_clean_subset'
infile_prefix <- strsplit(infile, "\\.")[[1]][1]
results_subdir <- sprintf('%s_%s',
                          format(Sys.Date(), '%d_%m_%Y'),
                          infile_prefix
                          )
results_subdir
results_subdir <- epi_create_dir(base_path = results_dir,
                                 subdir = results_subdir
                                 )
# ////////////


# ////////////
# Capture output / log ----

# ===
# Redirect standard output
if (!interactive()) { # TRUE if not interactive, will then log output
    sink_stdout <- paste0(results_subdir, '/', script_n, '.sink_stdout.log')
    sink(sink_stdout, split = TRUE)

    # Redirect messages and warnings
    sink_msg <- file(paste0(results_subdir, '/', script_n, '.sink_msg.log'), open = "wt")
    sink(sink_msg, type = "message")

    # Example outputs
    cat("Test: This is standard output.\n")
    message("Test: This is a message.")
    warning("Test: This is a warning.")
    }
# ===

# ===
# Create a logger
if (!interactive()) { # TRUE if not interactive, will then log output
    logger <- create.logger()
    log_n <- paste0(results_subdir, '/', script_n, '.log4r.log')
    logfile(logger) <- log_n # Log file location
    level(logger) <- "INFO"  # Set logging level (DEBUG, INFO, WARN, ERROR)

    # Add log messages
    # info(logger, "Script started")
    # debug(logger, "This is a debug message")
    # warn(logger, "This is a warning")
    # error(logger, "This is an error")
    }
# ////////////


# ////////////
# Check column types ----

# ===
# Check loaded cols exist:
# stopifnot(FALSE)  # This will throw an error
stopifnot(length(all_colnames) == (ncol(data_f)))

if (!interactive()) {
    info(logger, "Expected columns match file")
    error(logger, "Expected columns do not match file")
    }

colnames(data_f)

stopifnot(all(all_colnames %in% colnames(data_f)))
setdiff(as.character(all_colnames), as.character(colnames(data_f)))
# ===

# ===
# Check all column types accounted
dim(data_f)
epi_clean_count_classes(df = data_f)
# Looks good
# ===
# ////////////


# ////////////
# Subset ----

print(col_to_subset)
print(value_to_subset)
summary(data_f[[col_to_subset]])

# ===
# Subset data:
df_subset <- which(data_f[[col_to_subset]] == value_to_subset)
df_subset  <- data_f[df_subset , ]
dim(df_subset )
dim(data_f)

epi_head_and_tail(df_subset)
# ===

# ===
# Clean up:
data_f <- df_subset
rm(list = c('df_subset'))
# ===
# ////////////


# ////////////
# The end  ----
# Save objects, to eg .RData file:
print(data_dir)
dir(data_dir)

processed_data_dir <- sprintf('%s/data_UP/access_SIAP_18092024/processed/',
                              data_dir)
infile_prefix
subset_n
suffix <- 'rdata.gzip'
outfile <- sprintf(fmt = '%s/%s_%s_%s.%s',
                   processed_data_dir,
                   script_n,
                   infile_prefix,
                   subset_n,
                   suffix
                   )
outfile

# Check and remove objects that are not necessary to save:
object_sizes <- sapply(ls(), function(x) object.size(get(x)))
object_sizes <- as.matrix(rev(sort(object_sizes))[1:10])
object_sizes
ls()

objects_to_save <- (c('data_f',
                      'project_root',
                      'data_dir',
                      'devel_dir',
                      'code_dir',
                      'results_dir',
                      'id_cols',
                      'date_cols',
                      'char_cols',
                      'int_cols',
                      'fact_cols',
                      'num_cols',
                      'all_colnames',
                      'subset_n'
                      )
                    )

# Save:
save(list = objects_to_save,
     file = outfile,
     compress = 'gzip'
     )

print(sessionInfo())

# Closing message loggers:
if (!interactive()) { # TRUE if not interactive, will then log output
    info(logger, "Script completed successfully")

    # Close screen output log (both screen and warnings/error messages):
    # Stop sinks
    sink(type = "message")
    close(sink_msg)  # Close the connection
    sink()
    }

# Remove/clean up session:
all_objects <- ls()
all_objects
rm_list <- which(!all_objects %in% objects_to_save)
all_objects[rm_list]
rm(list = all_objects[rm_list])
ls() # Anything defined after objects_to_save will still be here

# q()
# ////////////
