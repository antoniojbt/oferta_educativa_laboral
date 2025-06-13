#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 2) {
  stop("Error: Not enough arguments. Usage: Rscript some_script.R <input_csv> <output_csv>")
}

input_csv <- args[1]
output_csv <- args[2]

if (!file.exists(input_csv)) {
  stop(paste("Error: Input file does not exist:", input_csv))
}

# Check if input file is a valid CSV
if (!grepl("\\.csv$", input_csv)) {
  stop("Error: Input file must be a .csv file.")
}

df <- read.csv(input_csv)

df$new_var <- df[[1]] / df[[2]]

write.csv(df, output_csv, row.names = FALSE)
