# ////////////
# Script information ----
# SIAP
# Unidad de Personal
# Noviembre 2024
# basic cleaning, duplicate removal, specify column types, re-order
# Input is a converted table from accdb format from SIAP and rdata with project locations from:
# '1_dir_locations.R'

# TO DO: add
# See sh script 'xxx'

# Output is rdata object with column types specified, redundant and admin columns removed, and ready for subsetting, plotting, etc.
# ////////////


# ////////////
# Global options ----

# ===
# Stop on error:
# options(error = stop)
# ===

# ===
# renv can be a hassle
# disable temporarily if batch running, e.g.:
    # Disable renv prompts
# Sys.setenv(RENV_CONFIG_PROMPT_ENABLED = "FALSE") # except renv rewrites rprofile to source itself
    # Load the .rdata.gzip file
    # load("xxx.rdata.gzip")
    # Optionally re-enable prompts if desired
    # Sys.unsetenv("RENV_CONFIG_PROMPT_ENABLED")
# ===
# ////////////


# ////////////
# Import libraries ----
library(data.table)
library(episcout)
library(tidyverse)
library(skimr)
library(knitr)
library(htmltools)
library(log4r)

# command line arguments: infile path and output directory
args <- commandArgs(trailingOnly = TRUE)
if (length(args) >= 1) infile_path <- args[1]
if (length(args) >= 2) results_subdir <- args[2]
# ////////////


# ////////////
# Load rdata file with directory locations ----

# ===
# Set working directory to the project root:
setwd(here::here())
# renv should be picked up automatically, see 0_xx in project_tools if it interrupts
getwd()

# Load the .rdata.gzip file:
load("data/data_UP/access_SIAP_18092024/processed/dir_locations.rdata.gzip")
ls()
# ===

# ===
# Get rid of RStudio warnings for loaded objects:
# Leave this here so it gets logged
project_root <- project_root
all_locs <- all_locs
data_dir <- data_dir
results_dir <- results_dir
code_dir <- code_dir

print(project_root)
setwd(here::here())
getwd()
print(dir(path = normalizePath(project_root), all.files = TRUE))

print(all_locs)
# ===
# ////////////


# ////////////
# Source functions/scripts/etc
# TO DO:
# Source (until I update episcout)
source(file.path(paste0(code_dir, '/scripts/funcs_epi_source.R')))
# ////////////



# ////////////
# Dataset ----
print(dir(path = normalizePath(data_dir), all.files = TRUE))

infiles_dir <- 'data_UP/access_SIAP_18092024/processed/'

# TO DO: Manually set:
# infile <- 'Qna_17_Bienestar_2024.csv'
infile <- 'Qna_07_Plantilla_2025.csv'
infile_path <- paste0(data_dir, infiles_dir, infile)

# Full path and file loaded:
print(infile_path)
# ////////////


# ////////////
# Output dir, based on today's date ----
script_n <- '2_clean_dups_col_types'
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
# Read in ----
data_f <- epi_read(infile_path)
dim(data_f)
str(data_f)

epi_head_and_tail(data_f)
colnames(data_f)
# ////////////


# ////////////
# Find non-unique IDs ----
df_dups <- data_f
dups <- epi_clean_get_dups(df_dups, var = "MATRICULA")
print(dups$MATRICULA)
# MATRICULA has '0' in thousands of rows
dups <- epi_clean_get_dups(df_dups, var = "Nombre")
dups <- epi_clean_get_dups(df_dups, var = "NSS")
dups <- epi_clean_get_dups(df_dups, var = "CURP")
print(dups$CURP)
# 0
print(dups)
# No duplicates by CURP as expected, use CURP as the key ID var
# 31 by name
# 2 by NSS

# Save:
file_n <- 'duplicates_CURP'
suffix <- 'txt'
outfile <- sprintf(fmt = '%s/%s.%s',
                   results_subdir,
                   file_n,
                   suffix
                   )
outfile
epi_write(file_object = dups,
          file_name = outfile
          )


# View(t(dups))
# No real duplicates (by CURP)
# None for infile2

# Clean up:
# data_f <- df_dups # not needed
rm(list = c('df_dups'))
# ////////////


# ////////////
# Basic clean ----

# ===
# EDAD, min 15, max 95 (?)
summary(data_f$EDAD)
length(which(data_f$EDAD < 15))
which(data_f$EDAD < 15)
t(data_f[which(data_f$EDAD < 15), ])

length(which(data_f$EDAD > 65))
length(which(data_f$EDAD > 75))
length(which(data_f$EDAD > 95))

data_f$EDAD <- ifelse(data_f$EDAD < 15, NA, data_f$EDAD)
data_f$EDAD <- ifelse(data_f$EDAD > 95, NA, data_f$EDAD)
summary(data_f$EDAD)

# boxplot(data_f$EDAD)
# hist(data_f$EDAD)
# epi_plot_box(data_f, 'EDAD')
# epi_plot_hist(data_f, 'EDAD') + ylab('Conteo')
# ===

# ===
summary(data_f$FALTASACUMULADAS)
length(which(data_f$FALTASACUMULADAS < 0))
data_f$FALTASACUMULADAS <- ifelse(data_f$FALTASACUMULADAS < 0,
                                  NA,
                                  data_f$FALTASACUMULADAS
                                  )
summary(data_f$FALTASACUMULADAS)
summary(data_f$ANT_DIAS)
summary(data_f$FALTASACUMULADAS / data_f$ANT_DIAS)

data_f[, c('FALTASACUMULADAS', 'ANT_DIAS')]
head(data_f$FALTASACUMULADAS / data_f$ANT_DIAS)
# ===


# ===
# Clean up MATRICULA, NA values mainly:
# Numbers must match for these:
# [1] "MATRICULA"             "Nombre"
#  [3] "RFC"                   "CURP"

data_f$MATRICULA
length(which(data_f$MATRICULA == '0'))

head(data_f$MATRICULA, 20)
summary(data_f$MATRICULA)
summary(as.character(data_f$MATRICULA))

# Check for values with fewer than 9 digits:
col_check <- data_f$MATRICULA
count_char <- nchar(col_check)
summary(count_char)
summary(as.factor(count_char))
length(which(count_char < 8))


to_NA <- c("0")
data_f$MATRICULA <- ifelse(as.character(data_f$MATRICULA) %in% to_NA, NA, data_f$MATRICULA)
summary(data_f$MATRICULA)
# Should match other IDs:
summary(data_f$NSS)
# ===

# ===
# Clean up ESCOLARIDAD, NA values mainly:
head(data_f$ESCOLARIDAD, 20)
summary(data_f$ESCOLARIDAD)
to_NA <- c("-",
           "1-",
           "7-",
           "9-",
           "15|-",
           "3-",
           "8-"
           )
to_correct <- c("BACHILLERATO-",
                "LICENCIATURA EN ENFERMERIA-",
                "LICENCIATURA-",
                "MAESTRIA COMPLETA-"
                )
length(which(data_f$ESCOLARIDAD %in% to_NA))
# vec_test <- ifelse(as.character(data_f$ESCOLARIDAD) %in% to_NA, NA, data_f$ESCOLARIDAD)
data_f$ESCOLARIDAD <- ifelse(as.character(data_f$ESCOLARIDAD) %in% to_NA, NA, data_f$ESCOLARIDAD)

# Also exclude as ambiguous:
# vec_test <- ifelse(as.character(data_f$ESCOLARIDAD) %in% to_correct, NA, data_f$ESCOLARIDAD)
data_f$ESCOLARIDAD <- ifelse(as.character(data_f$ESCOLARIDAD) %in% to_correct, NA, data_f$ESCOLARIDAD)

head(data_f$ESCOLARIDAD)
summary(as.factor(data_f$ESCOLARIDAD))
dim(data_f)
# ===

# ===
# TO DO:
# Get age, gender, municipio, etc. from CURP, compare against registered:
# ===


# ===
# Column names:
# AntiguedadVacA√±os
# which(colnames(data_f) == 'AntiguedadVacAños')
# colnames(data_f)[88]
# ===
# ////////////


# ////////////
# Many columns duplicate information, check ----

# ===

identical(as.character(data_f$MATRICULA),
          as.character(data_f$TITULAR)
          )
epi_head_and_tail(data_f[, c('MATRICULA', 'TITULAR')], cols = 2)
# some zero's
# Compare the columns and count matches
match_count <- length(which(as.character(data_f$MATRICULA) == as.character(data_f$TITULAR)))
match_count
length(which(as.character(data_f$TITULAR) == '0'))
dim(data_f)
# Looks like some zero's in both columns, but largely the same number/information
# Remove
# ===


# ===
identical(data_f$Nombre, data_f$NOMBRE_TITULAR)
epi_head_and_tail(data_f[, c('Nombre', 'NOMBRE_TITULAR')], cols = 2)
# some mismatches
# Compare the columns and count matches
match_count <- length(which(data_f$Nombre == data_f$NOMBRE_TITULAR))
match_count
dim(data_f)
# Looks like ~70% have the same information, 73577 / 90378
mismatches_index <- which(data_f$Nombre != data_f$NOMBRE_TITULAR)
epi_head_and_tail(data_f[mismatches_index, c('Nombre', 'NOMBRE_TITULAR')],
                  cols = 2)
# Remove for now, check
# ===

# ===
# Remove new columns, or those different to test file QNA 17 2024, eg Cedula in QNA 07 2025:
summary(data_f$Cédula)
str(data_f$Cédula)
length(unique(data_f$Cédula))
length(which(is.na(data_f$Cédula)))
# 425502 are missing
# Remove
# ===
# ////////////


# ////////////
# Remove columns that aren't needed ----

# ===
# TO DO: remove this section when passing to pipeline, same for some of the above, although needed for removal of extra columns:
# Link to previous file, add "Cedula" which is new in QNA 07 2025, and now missing PLAZANA
# Many columns, manually looking at data and deciding what types are each
# Convert based on manual inspection, re-read file for column types to convert to.
# 19 Nov 2024, added descriptions, columns to keep, etc. This was manual, directly to the same file:

colnames(data_f)

print(results_dir)
col_types_file <- sprintf("%s/%s/%s",
                          results_dir,
                          "manual_col_types/",
                          "df_col_types2_utf8.csv" # txt was a pain with encodings
                          )
print(col_types_file)

col_types_file <- episcout::epi_read(col_types_file)
epi_head_and_tail(col_types_file)
colnames(col_types_file)

# Dummy object:
df_col_types <- data_f
str(df_col_types)
dim(df_col_types)

# Problematic names:
colnames(df_col_types)
col_types_file[[1]]

string <- colnames(df_col_types)
valid_names <- epi_clean_make_names(string)
valid_names
epi_clean_make_names(valid_names)
colnames(df_col_types) <- valid_names
colnames(df_col_types)

# Manual conversion for some:
# TO DO: switch to regex to avoid using a position:
# col_types_file[[1]][37]
# col_types_file[[1]][88]
# col_types_file[[1]][88] <- 'AntiguedadVacAños'
# ===


# ===
# Column type conversions, except for dates, will run separately:
# i <- 1

missing_cols <- col_types_file$variables[!col_types_file$variables %in% names(df_col_types)]
missing_cols

df_col_types <- setNames(
    lapply(seq_len(nrow(col_types_file)), function(i) {
        col <- col_types_file$variables[i]
        typ <- col_types_file$convert_to[i]
        if (is.na(typ) || !(col %in% names(df_col_types))) return(NULL)
        switch(typ,
               "factor" = as.factor(df_col_types[[col]]),
               "character" = as.character(df_col_types[[col]]),
               "integer" = as.integer(df_col_types[[col]]),
               "numeric" = as.numeric(df_col_types[[col]]),
               df_col_types[[col]])
    }),
    col_types_file$variables
) %>% compact() %>% as.data.frame() %>% select(all_of(col_types_file$variables[col_types_file$variables %in% names(df_col_types)]))

# View missing columns:
cat("Missing columns:\n", missing_cols)


# Check:
str(data_f)
str(df_col_types)

typeof(data_f$MATRICULA) # typeof() gives base R's type
typeof(df_col_types$MATRICULA)

class(data_f$MATRICULA) # class() gives the converted type
class(df_col_types$MATRICULA)

col1 <- t(as.data.frame(lapply(data_f, class)))
col1
col2 <- t(as.data.frame(lapply(df_col_types, class)))
col2

column_types_dfs <- data.frame(original_base = col1,
                               converted_class = col2
                               )
column_types_dfs


# Save an initial summary with all columns:
summary(df_col_types)
skim_summary <- skimr::skim(df_col_types)
skim_summary

epi_write_df(df = df,
             results_subdir = results_subdir,
             file_n = 'skimr_all_cols',
             suffix = 'txt'
)


# # TO DO: try func for html output:
# # Render as HTML
# save_skim_html <- function(df, file) {
#     library(skimr)
#     library(dplyr)
#     library(knitr)
#     library(kableExtra)
#     library(htmltools)
#
#     skimmed_split <- skim(df) %>%
#         group_by(skim_type) %>%
#         group_split()
#
#     html_tables <- lapply(skimmed_split, function(df_part) {
#         df_part %>%
#             select(-skim_type) %>%
#             kable("html") %>%
#             kable_styling(bootstrap_options = c("striped", "hover", "condensed"))
#     })
#
#     html_doc <- tagList(html_tables)
#     save_html(html_doc, file)
# }
#
# # Usage:
# # html_summary <- knitr::knit_print(skim_summary)
# save_path <- file.path(results_subdir, "skimr_all_cols.html")
# save_skim_html(df_col_types, save_path)
# ===

# ===
# Columns to keep:
which_col <- 'keep_simple'
columns_to_keep <- col_types_file$variables[col_types_file[[which_col]] == "y"]
print(columns_to_keep)

# Subset:
df_col_types <- df_col_types[, columns_to_keep]
dim(df_col_types)
dim(data_f)

# Save an initial summary with selected columns:
summary(df_col_types)
df <- skimr::skim(df_col_types)

epi_write_df(df = df,
             results_subdir = results_subdir,
             file_n = 'skimr_selected_cols',
             suffix = 'txt'
             )
# ===

# ===
# Clean up:
data_f <- df_col_types
rm(list = c('df_col_types'))
# ===
# ////////////


# ////////////
# ===
# Convert dates

df_dates <- data_f

date_cols <- df_dates %>%
  select(contains("fech")) %>%
  colnames()
date_cols

epi_head_and_tail(df_dates[, date_cols])
# dd/mm/yyyy

summary(df_dates[, date_cols])
# chr
# ===

# ===
# Convert dates
col_test <- df_dates$FECHAING
summary(col_test)
summary(as.factor(col_test))
col_test
str(col_test)
as.character(col_test)

col_test <- as.Date(col_test, format = "%m/%d/%y")
str(col_test)
# formatted_col_test <- format(col_test, "%d/%m/%Y")

# col_test <- as.character(as.Date(col_test, format = "%m/%d/%y"))
# col_test <- format(as.Date(col_test), "%d/%m/%Y")
# str(col_test)

head(col_test)
head(df_dates$FECHAING)
summary(as.Date(col_test, "%d/%m/%Y"))
summary(as.Date(df_dates$FECHAING, "%m/%d/%y")) # format is different
# Looks good, now as dd/mm/yyyy without hms
# Left as R’s native yyyy-mm-dd format internally
# ===


# ===
# Loop and convert all:
epi_head_and_tail(df_dates[, date_cols])
summary(df_dates[, date_cols])
str(df_dates[, date_cols])

# i <- date_cols[1]
for (i in date_cols) {
    print(i)
    col_i <- df_dates[[i]]
    str(col_i)
    col_i <- as.Date(col_i, format = "%m/%d/%y")
    str(col_i)
    print(head(col_i))
    df_dates[[i]] <- col_i
    print(head(df_dates[, i]))
    print(summary(df_dates[[i]]))
        }

epi_head_and_tail(data_f[, date_cols])
epi_head_and_tail(df_dates[, date_cols])

head(data_f$FECHAING)
head(df_dates$FECHAING)


summary(df_dates[, date_cols])
str(data_f[, date_cols])
str(df_dates[, date_cols])
# Looks good, base R format: "2005-05-16"

# Save dates summary:
df <- skimr::skim(df_dates[, date_cols])
epi_write_df(df = df,
             results_subdir = results_subdir,
             file_n = 'skimr_dates',
             suffix = 'txt'
             )
# Generally looks good
# ===

# ===
# TO DO:
# Converting to date seems to have cleaned these up, needs proper check
# # Clean up NAs and other values:
# # Replace invalid dates with NA:
# # Problematic strings:
# na_exclude <- c("04",
#                 "01",
#                 "00",
#                 "Definitiva",
#                 "<NA>"
#                 )
#
# which(col_test %in% na_exclude)
#
# col_test <- ifelse(col_test %in% na_exclude, NA, col_test)
# col_test <- as.Date(col_test)
# summary(col_test)
# ===


# ===
# Clean up:
data_f <- df_dates
str(data_f[, date_cols])
rm(list = c('df_dates'))
# ===
# ////////////


# ////////////
# Check classes ----

# ===
epi_clean_count_classes(df = data_f)
tibble::glimpse(data_f)
str(data_f)
epi_head_and_tail(data_f)
epi_head_and_tail(data_f, last_cols = T)

data_f %>%
  select_if(~ epi_clean_cond_chr_fct(.)) %>%
  colnames()

data_f %>%
  select_if(~ epi_clean_cond_numeric(.)) %>%
  colnames()

# Explicitly check the type of each column:
as.data.frame(sapply(data_f, typeof))
as.data.frame(sapply(data_f, class))
colnames(data_f)
# ===

# ===
# Get character columns:
char_cols <- data_f %>%
	select_if(is.character) %>%
	colnames()
char_cols
epi_head_and_tail(data_f[, char_cols], cols = length(char_cols))


# Get integer columns:
int_cols <- data_f %>%
	select_if(is.integer) %>%
	colnames()
int_cols
epi_head_and_tail(data_f[, int_cols], cols = length(int_cols))

# Get numeric columns:
num_cols <- data_f %>%
    select_if(~ is.numeric(.) && !is.integer(.)) %>%
	colnames()
num_cols
epi_head_and_tail(data_f[, num_cols], cols = length(num_cols))


# Get factor columns:
fact_cols <- data_f %>%
	select_if(is.factor) %>%
	colnames()
fact_cols
epi_head_and_tail(data_f[, fact_cols], cols = length(fact_cols))


# Check all column types accounted
dim(data_f)
epi_clean_count_classes(df = data_f)
# Looks good
# ===
# ////////////


# ////////////
# ===
# Re-order columns to make it easier to select ----

# ID columns are:
id_cols <- c('MATRICULA',
             'RFC',
             'CURP',
             'NSS'
             )
id_cols
epi_head_and_tail(data_f[, id_cols], cols = length(id_cols))

colnames(data_f)
df_ord <- data_f %>%
  select('MATRICULA',
         'RFC',
         'CURP',
         'NSS',
         'SEXO',
         matches("FECH"),
         everything()
  )

colnames(df_ord)
str(df_ord)
dim(df_ord)
epi_clean_count_classes(data_f)

# Clean up:
data_f <- df_ord
rm(list = c('df_ord'))
# ===
# ////////////


# ////////////
# Get list of column for checks in later scripts  ----
all_colnames <- c(# id_cols, # id_cols are char_cols
                  char_cols,
                  fact_cols,
                  num_cols,
                  int_cols, # no true integer columns though, should be empty
                  date_cols
                  )
all_colnames
# ////////////


# ////////////
# The end  ----
# Save objects, to eg .RData file:
print(data_dir)
dir(data_dir)

processed_data_dir <- sprintf('%s/data_UP/access_SIAP_18092024/processed/',
                              data_dir)
infile_prefix
suffix <- 'rdata.gzip'
outfile <- sprintf(fmt = '%s/%s_%s.%s',
                   processed_data_dir,
                   script_n,
                   infile_prefix,
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
                      'all_colnames'
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
