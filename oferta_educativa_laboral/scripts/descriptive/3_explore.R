# ////////////
# Script information ----

# SIAP
# Unidad de Personal
# Noviembre 2024
# Descriptive stats
# Plots of all variable types, basic summaries
# Input is rdata output from script:
# 2_dups_col_types.R

# Output are many plots, tables, etc for descriptive stats
# ////////////


# ////////////
# Global options ----
# options(error = stop)
# ////////////


# ////////////
# Import libraries ----
library(data.table)
library(episcout)
library(ggthemes)
library(cowplot)
library(tidyverse)
library(skimr)
library(pander)
library(log4r)
# command line arguments: input RData and output directory
args <- commandArgs(trailingOnly = TRUE)
if (length(args) >= 1) infile_path <- args[1]
if (length(args) >= 2) results_subdir <- args[2]
# library(quarto)
# library(renv)
# ////////////


# ////////////
# Set working directory to the project root  ----
setwd(here::here())
# renv should be picked up automatically, see 0_xx in project_tools if it interrupts
getwd()
# ////////////


# ////////////
# Global options for plotting, generally need larger fot size:
# If rendering at 60% of linewidth ({ width=60% }) in qmd for PDF output,
# scale base_size accordingly. e.g. for fonts to appear ~12pt in the final PDF, set:

font_size <- 12 / 0.6  # Final appearance size after scaling (≈20), where scaling is at eg 60% for latex PDF output
font_size_x <- font_size - 0 # axis ticks (x-axis)
font_size_y <- font_size - 0 # y-axis ticks

my_theme <- theme_minimal(base_size = font_size) +
  theme(
    plot.title    = element_text(size = font_size, face = "bold"),
    axis.title.x  = element_text(size = font_size),
    axis.title.y  = element_text(size = font_size),
    axis.text.x   = element_text(size = font_size_x),  # x-axis tick labels
    axis.text.y   = element_text(size = font_size_y)  # y-axis tick labels
    # panel.grid    = element_blank()
    # panel.background = element_rect(fill = "white", colour = NA),
    # plot.background  = element_rect(fill = "white", colour = NA),
    # axis.line     = element_blank(),
    # axis.ticks    = element_blank(),
    # legend.key    = element_blank()
  )

theme_set(my_theme)


# cowplot::ggsave2 has dpi = 300 as default
# epi_plot_cow_save has base_height = 11.69, base_width = 8.27, default units is "in"
# these are good options for high quality images
# ////////////


# ////////////
# Load rdata file ----

# ===
rdata_dir <- 'data/data_UP/access_SIAP_18092024/processed/'

# TO DO: Manually set:
# infile <- '2_clean_dups_col_types_Qna_17_Bienestar_2024.rdata.gzip'
# infile <- '2_clean_dups_col_types_Qna_17_Plantilla_2024.rdata.gzip'

# infile <- "2b_clean_subset_2_clean_dups_col_types_Qna_17_Bienestar_2024_meds.rdata.gzip"
# infile <- '2b_clean_subset_2_clean_dups_col_types_Qna_17_Bienestar_2024_enfermeras.rdata.gzip'

# infile <- "2b_clean_subset_2_clean_dups_col_types_Qna_17_Plantilla_2024_meds.rdata.gzip"
# infile <- '2b_clean_subset_2_clean_dups_col_types_Qna_17_Plantilla_2024_enfermeras.rdata.gzip'


infile <- "2b_clean_subset_2_clean_dups_col_types_Qna_07_Plantilla_2025_meds.rdata.gzip"

# Double filter:
# infile <- "2b_clean_subset_Qna_17_Plantilla_2024_meds_Chiapas.rdata.gzip"

# Full path and file name:
infile_path <- paste0(rdata_dir, infile)
print(infile_path)

print(dir(path = normalizePath(rdata_dir), all.files = TRUE))

load(infile_path)
ls()
# ===

# ===
# Get rid of RStudio warnings for loaded objects:
project_root <- project_root
data_dir <- data_dir
results_dir <- results_dir
data_f <- data_f

# TO DO: needs updating:
code_dir <- code_dir

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
script_n <- '3_explore'
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
    script_n <- '2_clean_dups_col_types'
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
# Missing data ----
count_missing <- sum(complete.cases(data_f))
count_missing
dim(data_f)
# all rows have missing data

# Complete cases
epi_head_and_tail(data_f)
table(complete.cases(data_f))
dim(data_f)

# Missing data
na_perc <- epi_stats_na_perc(df = data_f, margin = 2)
na_perc
#

ord <- order(na_perc$na_perc, decreasing = T)
ord
na_perc <- na_perc[c(ord), ]
na_perc

print(infile_prefix)
suffix <- 'txt'
outfile <- sprintf(fmt = '%s/na_perc.%s',
                   results_subdir,
                   suffix
                   )
outfile

epi_write(na_perc,
          outfile,
          row.names = TRUE,
          col.names = TRUE
          )
# ////////////


# ////////////
# Generate summaries for each variable type ----
epi_clean_count_classes(data_f)
str(data_f)

# ===
# Date columns
# Defined in previous script
print(date_cols)

epi_head_and_tail(data_f[, date_cols])

summary(data_f[, date_cols])

# sum_dates_df <- data.frame('variable' = character(0),
#                            'Min' = numeric(0),
#                            'q25%' = numeric(0),
#                            'Median' = numeric(0),
#                            'q75%' = numeric(0),
#                            'Max' = numeric(0),
#                            'IQR' = numeric(0),
#                            stringsAsFactors = FALSE
#                            )
# for (i in date_cols) {
#     sum_dates <- epi_stats_dates(data_f[[i]])
#     # print(sum_dates)
#     stats_vector <- sum_dates$Value  # Extract the values
#
#     # Data frame row to append:
#     new_row <- data.frame(
#         Variable = i,
#         Min = stats_vector[1],
#         `q25%` = stats_vector[2],
#         Median = stats_vector[3],
#         `q75%` = stats_vector[4],
#         Max = stats_vector[5],
#         IQR = stats_vector[6]
#     )
#     sum_dates_df <- rbind(sum_dates_df,
#                           new_row)
# }
# sum_dates_df

epi_stats_dates(data_f$FECHAPROBJUB)
sum_dates <- epi_stats_dates_multi(data_f)

# Save:
infile_prefix
file_n <- 'sum_dates'
suffix <- 'txt'
outfile <- sprintf(fmt = '%s/%s.%s',
                   results_subdir,
                   file_n,
                   suffix
                   )

outfile
epi_write(sum_dates, outfile)
# ===


# ===
# Get frequency tables
dates_list <- list()
for (i in date_cols) {
    # Calculate differences between consecutive dates to find gaps and clusters:
    date_ord <- as.numeric(data_f[[i]])
    inds <- order(date_ord,
                  decreasing = FALSE,
                  na.last = TRUE
    )
    date_ord <- date_ord[inds]
    date_diffs <- diff(date_ord)
    # date_diffs
    # Convert numeric differences back to an interpretable form (e.g., days):
    # date_diffs_days <- as.Date(date_diffs, origin = "1970-01-01") - as.Date("1970-01-01") # although diff() was already working on days, so same result
    # date_diffs_days
    # Frequency table by month-year:
    date_frequencies <- table(format(data_f[[i]], "%Y-%m"))  # Counts by year and month
    # date_frequencies
    dates_list[[i]] <- list(
        Date_Differences = date_diffs,
        Frequencies = date_frequencies
    )
}
names(dates_list)
names(dates_list$FECHAING)
dates_list$FECHAING

# Save:
for (i in names(dates_list)) {
    # print(i)
    infile_prefix
    file_n <- 'freq'
    file_n2 <- 'Date_Differences'
    suffix <- 'txt'
    outfile <- sprintf(fmt = '%s/%s_%s_%s.%s',
                       results_subdir,
                       file_n,
                       i,
                       file_n2,
                       suffix
                       )
    outfile

    # dates_list$xxx$Date_Differences
    df_out <- as.data.frame(dates_list[[i]][[1]])
    epi_write(df_out, outfile)

    infile_prefix
    file_n <- 'freq'
    file_n2 <- 'Frequencies'
    suffix <- 'txt'
    outfile <- sprintf(fmt = '%s/%s_%s_%s.%s',
                       results_subdir,
                       file_n,
                       i,
                       file_n2,
                       suffix
                       )
    outfile
    # dates_list$xxx$Frequencies
    df_out <- as.data.frame(dates_list[[i]][[2]])
    epi_write(df_out, outfile)
    }
# ===
# ////////////


# ////////////
# ===
# Numeric columns ----
test_shapiro <- epi_stats_numeric(data_f$IMP_010)
test_shapiro

stats_num <- epi_stats_summary(df = data_f, class_type = 'int_num')
stats_num

# Numeric data summary doesn't need tidying but could be formatted:
stats_num <- epi_stats_format(stats_num, digits = 2)
# View(stats_num)

# Save as table
# pwd already in results folder:
infile_prefix
file_n <- 'sum_stats'
suffix <- 'txt'
outfile <- sprintf(fmt = '%s/%s.%s',
                   results_subdir,
                   file_n,
                   suffix
                   )
outfile

epi_write(file_object = stats_num, file_name = outfile)
# ===

# ===
# Factor columns:
# Set-up as one file per categorical variable with a frequency table and proportions.
# str(data_f)
# fact_cols
#
# # Get desc stats:
# stats_fct <- epi_stats_summary(df = data_f[, fact_cols], class_type = 'chr_fct')
# stats_fct
# unique(stats_fct$id)
# # View(stats_fct)
# dim(data_f)
# colnames(data_f)
#
# # Add total for percentage calculation and order column to tidy up results:
# perc_n <- nrow(data_f[, fact_cols])
# order_by <- 'percent'
# stats_fct_tidy <- epi_stats_tidy(sum_df = stats_fct,
#                                  order_by = order_by,
#                                  perc_n = perc_n
#                                  )
# stats_fct_tidy
# # Format them if needed:
# stats_fct_tidy <- epi_stats_format(stats_fct_tidy, digits = 0)
# stats_fct_tidy
#
# # Save as table
# file_n <- 'stats_factors'
# suffix <- 'txt'
# outfile <- sprintf(fmt = '%s/%s.%s',
#                    results_subdir,
#                    file_n,
#                    suffix
#                    )
# outfile
#
# epi_write(file_object = stats_fct_tidy,
#           file_name = outfile
#           )
# ===

# ===
# Cleaned up / simple factor cols summary:
sum_factors <- epi_stats_factors(data_f[, fact_cols])

# Save as table
file_n <- 'sum_factors'
suffix <- 'txt'
outfile <- sprintf(fmt = '%s/%s.%s',
                   results_subdir,
                   file_n,
                   suffix
)
outfile

epi_write(file_object = sum_factors,
          file_name = outfile
)
# ===

# ===
# Character columns, these are ID
sum_chars <- epis_stats_chars(data_f[, char_cols])
sum_chars

# Save as table
file_n <- 'sum_chars'
suffix <- 'txt'
outfile <- sprintf(fmt = '%s/%s.%s',
                   results_subdir,
                   file_n,
                   suffix
)
outfile

epi_write(file_object = sum_chars,
          file_name = outfile
)


# ===
# ////////////


# ////////////
# Plots ----

# ===
num_vars <- list()
for (i in colnames(data_f)) {
  if (epi_clean_cond_numeric(data_f[[i]])) {
    num_vars <- c(num_vars, i)
  }
}
num_vars

# Numeric, boxplots:
epi_plot_box(df = data_f, var_y = "EDAD") +
  epi_plot_theme_2(base_size = 10,
                   font_size_x = 30,
                   font_size_y = 30)

# i <- "EDAD"
var_list <- epi_plot_list(vars_to_plot = num_vars)
for (i in names(var_list)) {
  var_list[[i]] <- epi_plot_box(df = data_f, var_y = i) +
    epi_plot_theme_2(base_size = font_size,
                     font_size_x = font_size_x,
                     font_size_y = font_size_y)
  }

# Save plots
# Plot 4 per page or so for easier viewing, but if for quarto PDF keep just one per file:
per_file <- 1
var_names <- names(var_list)

# Split into groups of `per_file` variables
jumps <- seq(1, length(var_names), by = per_file)

for (start_i in jumps) {
  end_i <- min(start_i + per_file - 1, length(var_names))  # Ensure within bounds
  selected_vars <- var_names[start_i:end_i]

  # Create a short, safe filename
  safe_var_part <- paste(selected_vars, collapse = "_")
  safe_var_part <- substr(safe_var_part, 1, 50)  # Truncate if too long
  safe_var_part <- gsub("[^[:alnum:]_]", "_", safe_var_part)  # Remove unsafe chars

  # Construct output file path
  file_n <- sprintf("plots_box_num_%s.pdf", safe_var_part)
  outfile <- file.path(results_subdir, file_n)

  # Generate plot grid for selected variables
  selected_plots <- var_list[selected_vars]
  my_plot_grid <- epi_plots_to_grid(selected_plots)

  # Save the combined plot
  epi_plot_cow_save(file_name = outfile, plot_grid = my_plot_grid)
}
# ===


# ===
# Histograms:
epi_plot_hist(df = data_f, var_x = "EDAD") +
  epi_plot_theme_2(base_size = font_size,
                   font_size_x = font_size_x,
                   font_size_y = font_size_y) +
  labs(y = "Frecuencia")

var_list <- NULL
i <- NULL
var_list <- epi_plot_list(vars_to_plot = num_vars)
for (i in names(var_list)) {
  print(i)

  # TO DO for episcout: switch to dplyr::sym() for tidy evaluation and/or clean up column names initially. Can be useful to keep original column names though
  # i <- paste0("`", i, "`") # because of spaces and special characters in column names
  var_list[[i]] <- epi_plot_hist(df = data_f, var_x = i) +
    epi_plot_theme_2(base_size = font_size,
                     font_size_x = font_size_x,
                     font_size_y = font_size_y) +
    labs(y = "Frecuencia")
  }
var_list

# Save plots
# Plot 4 per page or so for easier viewing, but if for quarto PDF keep just one per file:
per_file <- 1
var_names <- names(var_list)

# Split into groups of `per_file` variables
jumps <- seq(1, length(var_names), by = per_file)

for (start_i in jumps) {
  end_i <- min(start_i + per_file - 1, length(var_names))  # Ensure within bounds
  selected_vars <- var_names[start_i:end_i]

  # Create a short, safe filename
  safe_var_part <- paste(selected_vars, collapse = "_")
  safe_var_part <- substr(safe_var_part, 1, 50)  # Truncate if too long
  safe_var_part <- gsub("[^[:alnum:]_]", "_", safe_var_part)  # Remove unsafe chars

  # Construct output file path
  file_n <- sprintf("plots_hist_num_%s.pdf", safe_var_part)
  outfile <- file.path(results_subdir, file_n)

  # Generate plot grid for selected variables
  selected_plots <- var_list[selected_vars]
  my_plot_grid <- epi_plots_to_grid(selected_plots)

  # Save the combined plot
  epi_plot_cow_save(file_name = outfile, plot_grid = my_plot_grid)
}
# ===

# ===
# IMSS colours:
custom_palette <- c(
  "#911034",      # Original Red
  "#b12f45",      # Slightly brighter red
  "#c19a53",      # Original Gold
  "#e1b86e",      # Lighter gold/beige
  "#2a5c4b",      # Original Green
  "#3b755f",      # Brighter green
  "#DACBA1",      # Original Beige
  "#bba483",      # Darker beige
  "#602218",      # Original Brown
  "#7b3a2a"       # Rich brown
)

# Modified to be colour-blind friendly:
accessible_palette <- c(
  "#911034",      # Original Red
  "#e69f00",      # Gold (more distinct from beige)
  "#56b4e9",      # Blue (replaces a green)
  "#009e73",      # Green (contrast with blue and yellow)
  "#f0e442",      # Yellow
  "#0072b2",      # Dark blue
  "#D55E00",      # Orange
  "#cc79a7",      # Purple (replaces a beige)
  "#602218",      # Original Brown
  "#7b3a2a"       # Rich brown
)

# ===

# ===
# Plots for factors
str(data_f[, fact_cols])

plot_bar <- epi_plot_bar(df = data_f,
                         var_x = 'SEXO',
                         custom_palette = custom_palette
                         ) +
  labs(y = "Frecuencia")
plot_bar

var_list <- epi_plot_list(vars_to_plot = fact_cols)
for (i in names(var_list)) {
    # print(i)
    var_list[[i]] <- epi_plot_bar(df = data_f,
                                  var_x = i,
                                  custom_palette = custom_palette
                                  ) +
    theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
      labs(y = "Frecuencia")
}
# var_list

# Save plots
# Plot 4 per page or so for easier viewing, but if for quarto PDF keep just one per file:
per_file <- 1
var_names <- names(var_list)

# Split into groups of `per_file` variables
jumps <- seq(1, length(var_names), by = per_file)

for (start_i in jumps) {
  end_i <- min(start_i + per_file - 1, length(var_names))  # Ensure within bounds
  selected_vars <- var_names[start_i:end_i]

  # Create a short, safe filename
  safe_var_part <- paste(selected_vars, collapse = "_")
  safe_var_part <- substr(safe_var_part, 1, 50)  # Truncate if too long
  safe_var_part <- gsub("[^[:alnum:]_]", "_", safe_var_part)  # Remove unsafe chars

  # Construct output file path
  file_n <- sprintf("plots_bar_num_%s.pdf", safe_var_part)
  outfile <- file.path(results_subdir, file_n)

  # Generate plot grid for selected variables
  selected_plots <- var_list[selected_vars]
  my_plot_grid <- epi_plots_to_grid(selected_plots)

  # Save the combined plot
  epi_plot_cow_save(file_name = outfile, plot_grid = my_plot_grid)
}
# ===
# ////////////


# ////////////
# Plot dates ----
# TO DO: consider:
# Visualization:
# Plot timelines (e.g., using scatter plots, line charts).
# Visualize counts of events over time (e.g., monthly, yearly trends with bar charts).
# Create heatmaps for temporal patterns (e.g., day of the week vs time).

date_cols
str(data_f[, date_cols])
summary(data_f[, date_cols])

# ===
# Histograms of date frequencies, to check for gaps and clusters:
ggplot(data = data_f, aes(x = FECHAPROBJUB)) +
    geom_histogram() +
  labs(y = "Frecuencia")
table(data_f$FECHAPROBJUB)

i <- 'FECHAPROBJUB'
epi_plot_hist(df = data_f, var_x = i) +
    geom_density(col = 2) +
  epi_plot_theme_2(base_size = font_size,
                   font_size_x = font_size_x,
                   font_size_y = font_size_y) +
  labs(y = "Frecuencia")

var_list <- epi_plot_list(vars_to_plot = date_cols)
for (i in names(var_list)) {
    print(i)
    # i <- paste0("`", i, "`") # because of spaces and special characters in column names
    var_list[[i]] <- epi_plot_hist(df = data_f, var_x = i) +
        geom_density(col = 2) +
      epi_plot_theme_2(base_size = font_size,
                       font_size_x = font_size_x,
                       font_size_y = font_size_y) +
      labs(y = "Frecuencia")
}
var_list

# Save plots
# Plot 4 per page or so for easier viewing, but if for quarto PDF keep just one per file:
per_file <- 1
var_names <- names(var_list)

# Split into groups of `per_file` variables
jumps <- seq(1, length(var_names), by = per_file)

for (start_i in jumps) {
  end_i <- min(start_i + per_file - 1, length(var_names))  # Ensure within bounds
  selected_vars <- var_names[start_i:end_i]

  # Create a short, safe filename
  safe_var_part <- paste(selected_vars, collapse = "_")
  safe_var_part <- substr(safe_var_part, 1, 50)  # Truncate if too long
  safe_var_part <- gsub("[^[:alnum:]_]", "_", safe_var_part)  # Remove unsafe chars

  # Construct output file path
  file_n <- sprintf("plots_hist_dates_%s.pdf", safe_var_part)
  outfile <- file.path(results_subdir, file_n)

  # Generate plot grid for selected variables
  selected_plots <- var_list[selected_vars]
  my_plot_grid <- epi_plots_to_grid(selected_plots)

  # Save the combined plot
  epi_plot_cow_save(file_name = outfile, plot_grid = my_plot_grid)
}
# ===


# ===
# Box Plots: visualise range, median, quartiles, and outliers in date distributions:
i <- 'FECHAPROBJUB' # TO DO: need to sort out tidy evaluation in episcout
epi_plot_box(data_f, var_y = i)

var_list <- epi_plot_list(vars_to_plot = date_cols)
for (i in names(var_list)) {
    # print(i)
    var_list[[i]] <- epi_plot_box(df = data_f, var_y = i) +
      epi_plot_theme_2(base_size = font_size,
                       font_size_x = font_size_x,
                       font_size_y = font_size_y)
    }
# var_list

# Save plots
# Plot 4 per page or so for easier viewing, but if for quarto PDF keep just one per file:
per_file <- 1
var_names <- names(var_list)

# Split into groups of `per_file` variables
jumps <- seq(1, length(var_names), by = per_file)

for (start_i in jumps) {
  end_i <- min(start_i + per_file - 1, length(var_names))  # Ensure within bounds
  selected_vars <- var_names[start_i:end_i]

  # Create a short, safe filename
  safe_var_part <- paste(selected_vars, collapse = "_")
  safe_var_part <- substr(safe_var_part, 1, 50)  # Truncate if too long
  safe_var_part <- gsub("[^[:alnum:]_]", "_", safe_var_part)  # Remove unsafe chars

  # Construct output file path
  file_n <- sprintf("plots_box_dates_%s.pdf", safe_var_part)
  outfile <- file.path(results_subdir, file_n)

  # Generate plot grid for selected variables
  selected_plots <- var_list[selected_vars]
  my_plot_grid <- epi_plots_to_grid(selected_plots)

  # Save the combined plot
  epi_plot_cow_save(file_name = outfile, plot_grid = my_plot_grid)
}
# ===

# ===
# Time Series Plot: Visualise distribution over time:

# Needs dates ordered, increasing:
i <- 'FECHAPROBJUB'
ord_i <- sort(as.Date(data_f[[i]]))
# ord_i <- data_f[ord_i, i]
# ord_i <- as.vector(ord_i)
str(ord_i)
head(ord_i)
tail(ord_i)
length(ord_i)

# Get a subset to plot:
rand_size <- 0.05 * nrow(data_f)
rand_indices <- sort(sample(length(ord_i), size = rand_size, replace = FALSE))
# rand_indices <- rand_indices[order(rand_indices)]
head(rand_indices)
tail(rand_indices)

# Subset the data frame:
date <- ord_i[rand_indices]
value <- seq_along(date)
plot_data <- data.frame(i = date, value = value)
colnames(plot_data)[1] <- i
str(plot_data)
epi_head_and_tail(plot_data, cols = 2)

# Plot:
# But it's a random subset, so annotate:
label_annot <- sprintf("random subset of %s", rand_size)
ggplot(plot_data, aes(x = !!sym(i), y = value)) +
    geom_line() +
    geom_point() +
    annotate("text", x = mean(range(plot_data[[i]])), y = -Inf,
             label = label_annot, vjust = -1, size = 2, color = "gray20") +
  labs(y = "Frecuencia")
# ===

# ===
var_list <- epi_plot_list(vars_to_plot = date_cols)
for (i in names(var_list)) {
    # Get date, sort it, pass it as vector, add value var for plotting:
    date <- sort(as.Date(data_f[[i]]))
    value <- seq_along(date)
    plot_data <- data.frame(i = date, value = value)
    colnames(plot_data)[1] <- i
    # Plot:
    var_list[[i]] <- ggplot(plot_data, aes(x = !!sym(i), y = value)) +
        geom_line() +
        geom_point() +
      labs(y = "Frecuencia")
}
# var_list

# Save plots
# Plot 4 per page or so for easier viewing, but if for quarto PDF keep just one per file:
per_file <- 1
var_names <- names(var_list)

# Split into groups of `per_file` variables
jumps <- seq(1, length(var_names), by = per_file)

for (start_i in jumps) {
  end_i <- min(start_i + per_file - 1, length(var_names))  # Ensure within bounds
  selected_vars <- var_names[start_i:end_i]

  # Create a short, safe filename
  safe_var_part <- paste(selected_vars, collapse = "_")
  safe_var_part <- substr(safe_var_part, 1, 50)  # Truncate if too long
  safe_var_part <- gsub("[^[:alnum:]_]", "_", safe_var_part)  # Remove unsafe chars

  # Construct output file path
  file_n <- sprintf("plots_time_%s.pdf", safe_var_part)
  outfile <- file.path(results_subdir, file_n)

  # Generate plot grid for selected variables
  selected_plots <- var_list[selected_vars]
  my_plot_grid <- epi_plots_to_grid(selected_plots)

  # Save the combined plot
  epi_plot_cow_save(file_name = outfile, plot_grid = my_plot_grid)
}
# ===
# ////////////


# ////////////
# The end ----
# Outputs saved to disk, no need to save as rdata.
sessionInfo()

# Closing message loggers:
if (!interactive()) { # TRUE if not interactive, will then log output
    info(logger, "Script completed successfully")

    # Close screen output log (both screen and warnings/error messages):
    # Stop sinks
    sink(type = "message")
    close(sink_msg)  # Close the connection
    sink()
    }

# q()
# ////////////
