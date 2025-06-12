# ////////////
# Script information ----

# SIAP
# Unidad de Personal
# Noviembre 2024
# Descriptive stats
# Descriptive stats - bivariable analysis
# Input is rdata output from script:
# 2_dups_col_types.R

# Output are many plots, tables, etc for two or more variables
# Focus is on plazas vacantes vs ocupadas
# ////////////


# ////////////
# Preliminaries ----
## Global options ----
# options(error = stop)
# ////////////


# ////////////
## Import libraries ----
library(data.table)
library(episcout)
library(ggthemes)
library(cowplot)
library(tidyverse)
library(log4r)
library(dplyr)
library(tidyr)
# library(skimr)
# command line arguments: input RData and output directory
args <- commandArgs(trailingOnly = TRUE)
if (length(args) >= 1) infile_path <- args[1]
if (length(args) >= 2) results_subdir <- args[2]
# ////////////


# ////////////
## Set working directory to the project root  ----
setwd(here::here())
# renv should be picked up automatically, see 0_xx in project_tools if it interrupts
getwd()
# ////////////


# ////////////
## Load rdata file ----

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
## Output dir, based on today's date ----
script_n <- '4_bivar'
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
## Capture output / log ----

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
## Check column types ----

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
# Bivariate analysis ----
## Numerical vs numerical ----
### Correlation matrix ----
# TO DO:
# Consider adding
# Covariance:
# Compute and visualize covariance matrix.
# Time-Series Specifics (if applicable):
# Check lag correlations for time-dependent variables.

cormat_all <- epi_stats_corr(df = data_f[, num_cols], method = 'spearman')
names(cormat_all)
names(cormat_all$cormat)
cormat_all$cormat$r
cormat_all$cormat_melted_r
class(cormat_all)

# Save files:
r_values <- as.data.frame(cormat_all$cormat_melted_r)
p_values <- as.data.frame(cormat_all$cormat_melted_pval)

file_n <- 'spearman_r'
suffix <- 'txt'
outfile <- sprintf(fmt = '%s/%s.%s',
                   results_subdir,
                   file_n,
                   suffix
                   )
outfile
epi_write(file_object = r_values,
          file_name = outfile
          )

file_n <- 'spearman_p_values'
suffix <- 'txt'
outfile <- sprintf(fmt = '%s/%s.%s',
                   results_subdir,
                   file_n,
                   suffix
                   )
outfile
epi_write(p_values, outfile)


### Plot numerical vs numerical ----
###  scatterplots with trend lines or smoothing (e.g., LOESS curves).
# # TO DO:
# # Scatter/Pairwise/multi plots for relevant combinations
# # Need to code a convenience function
# scatter.smooth(df_factor$IgA_Lavado, df_factor$IgA_Suero)
#
# ggplot(df_factor, aes(x = IgA_Lavado, y = IgA_Suero)) +
#   geom_point() +
#   geom_smooth(method = "lm", se = TRUE) +  # 'se' controls the confidence interval display
#   theme_minimal() +
#   labs(x = "IgA_Lavado", y = "IgA_Suero", title = "Scatter Plot with Best Fit Line")
# ////////////


# ////////////
# ===
## Categorical vs Categorical: Factors only ----
### Create contingency tables nxn ----

# Comparison
# 2x2 tables n, percent, signif tests
# nxn tables: max 3 variables, hard to visualise/summarise otherwise
# Loop for 'PLZOCU' plots and signif tests for factors

# TO DO:
# Consider:
# Contingency Analysis:
# Generate cross-tabulations.
# Compute association measures (e.g., Chi-square, Cramér’s V).
# Visualization:
# Stacked bar charts or mosaic plots.
# Heatmaps for large contingency tables.

fact_cols
epi_head_and_tail(data_f[, fact_cols])

# epi_plot_bar(df = data_f, var_x = 'PLZOCU')
# epi_plot_hist(df = data_f, var_x = "EDAD")
# ===


# ===
#### Check other vars vs PLZOCUP ----
summary(data_f)
dep_var <- "PLZOCU"
# ind_vars <- c("CLASIF_UNIDAD")
ind_vars <- c("ADSCRIPCION")

df_result <- epi_stats_table(
    df = data_f,
    dep_var = dep_var,
    ind_vars = ind_vars
    )

epi_head_and_tail(df_result, cols = ncol(df_result))


# Loop through relevant vars, most are factors with many options though
colnames(data_f)
summary(data_f)
summary(data_f$TipoMcaOcup)
summary(data_f$COMSIN)

# dep_var <- "PLZOCU"
# ind_vars <- c("TipoMcaOcup")
df <- data_f

# Exclude dependent and non-factor columns:
cols_to_loop <- colnames(df)[!colnames(df) %in% c("PLZOCU")]
cols_to_loop <- cols_to_loop[cols_to_loop %in% fact_cols]
cols_to_loop
length(cols_to_loop)
summary(data_f[, cols_to_loop])


for (i in cols_to_loop) {
    ind_vars <- i
    print(ind_vars)

    df_result <- epi_stats_table(
        df = df,
        dep_var = dep_var,
        ind_vars = ind_vars
        )
    # epi_head_and_tail(df_result)

    file_n <- paste0('table_', dep_var, '_', ind_vars)
    suffix <- 'txt'
    outfile <- sprintf(fmt = '%s/%s.%s',
                       results_subdir,
                       file_n,
                       suffix
                       )
    print(outfile)
    epi_write(df_result, outfile)
    }
# ===
# ////////////

# # TO DO: continue here
# # epi stats table needs updating in episcout, now called epi_stats_contingency_nxn
# # also sort out funcs epi source R
#
# # ////////////
# # ===
# ### Generate contingency tables 2x2 ----
# # Generate a contingency table for two variables
# fact_cols
#
# contingency_2x2_df <- epi_stats_contingency_2x2_df(data_f[, fact_cols], x_var = "PLZOCU", y_var = "SEXO")
# print(contingency_2x2_df)
#
# # Generate contingency tables for all variables
# contingency_2x2_list <- epi_stats_contingency_2x2_tables(data_f[, fact_cols], x_var = "PLZOCU")
# print(contingency_2x2_list[[1]])
#
# # Rename columns in contingency tables
# # TO DO: not sure what this is actually doing
# # renamed_list <- rename_contingency_2x2_cols(contingency_2x2_list, data_f[, fact_cols], x_var = "Plaza_ocupada")
# # print(renamed_list[[1]])
#
# # Perform a single 2x2 test
# result <- epi_stats_contingency_2x2_test(data_f[, fact_cols], "PLZOCU", "SEXO")
# print(result)
#
# # Select columns for testing
# testable_columns <- epi_stats_contingency_2x2_cols(data_f[, fact_cols])
# print(testable_columns)
#
# # Run tests on all testable columns
# results_df <- epi_stats_contingency_2x2_all(data_f[, fact_cols], "PLZOCU")
# print(results_df)
#
# # Save results
# file_n <- '2x2_sig_tests'
# suffix <- 'txt'
# outfile <- sprintf(fmt = '%s/%s.%s',
#                    results_subdir,
#                    file_n,
#                    suffix
#                    )
# outfile
# epi_write(file_object = results_df,
#           file_name = outfile
#           )
#
# # ===
#
#
# # ===
# #### Contingency table 2x2 significance tests ----
# ### Compute association measures (Chi-square, Fisher’s exact test)
# # Also extra at this point as unclear what the value is
# # will run anyway
#
# # ===
#
#
# # ===
# # TO DO: create a function and move to episcout
# # Create a new workbook:
# wb <- openxlsx::createWorkbook()
# # Add each data frame from the list as a new sheet
# lapply(names(results), function(x) {
#   openxlsx::addWorksheet(wb, x)
#   openxlsx::writeData(wb, sheet = x, results[[x]])
# })
# # Save the workbook
# openxlsx::saveWorkbook(wb, "2x2_tables_vs_Estado.xlsx", overwrite = TRUE)
# # ===
#
#
# # ===
# #### Plot/Visualize with mosaic plots or stacked bar charts. ----
# # # TO DO: continue here ----
# #
# # # TO DO: move to episcout
# # cont_plot <- function(df, x_var = 'Var1', y_var = 'Var2') {
# #   ggplot(df, aes(x = !!sym(x_var), y = Freq, fill = !!sym(y_var))) +
# #     geom_bar(stat = "identity", position = "dodge")
# #   }
# #
# # contingency_df <- cont_df(df = col_facts, x_var = 1, y_var = 3)
# # contingency_df
# # cont_plot(contingency_df, colnames(contingency_df)[1], colnames(contingency_df)[2])
# #
# # for (i in 1:length(results)) {
# #   df <- results[[i]]
# #   fact_plot <- cont_plot(df = df, x_var = colnames(df)[1], y_var = colnames(df)[2])
# #   file_name <- sprintf('cont_bar_plot_Estado_%s.pdf', names(results)[i])
# #   epi_plot_cow_save(file_name = file_name,
# #                     # base_height = 12,
# #                     # base_width = 12,
# #                     plot_grid = fact_plot
# #   )
# #   }
# # ===
#
# # ===
# # # Pair plots of contingency tables, not sure they add much (?)
# # # library(GGally)
# # colnames(col_facts)
# # facts_plot <- GGally::ggpairs(col_facts[, c("Estado", "HAS")],
# #                                 axisLabels = 'show',
# #                                 showStrips = TRUE)
# # facts_plot
# # epi_plot_cow_save(file_name = 'ggpairs_edo_HAS.pdf',
# #                   base_height = 6,
# #                   base_width = 6,
# #                   plot_grid = facts_plot
# #                   )
# #
# # facts_plot_1 <- GGally::ggpairs(col_facts[, c("Estado", "Sexo", "Inmunofenotipo_1")],
# #                                 axisLabels = 'show',
# #                                 showStrips = TRUE)
# # facts_plot_1
# # epi_plot_cow_save(file_name = 'ggpairs_edo_sexo_inmunofeno.pdf',
# #                   base_height = 6,
# #                   base_width = 6,
# #                   plot_grid = facts_plot_1
# #                   )
# # facts_plot_2 <- GGally::ggpairs(col_facts[, c("Estado", "Sexo", "Inmunofenotipo_1", "HAS")],
# #                                 axisLabels = 'show',
# #                                 showStrips = TRUE)
# # facts_plot_2
# # epi_plot_cow_save(file_name = 'ggpairs_edo_sexo_inmunofeno_HAS.pdf',
# #                   base_height = 6,
# #                   base_width = 6,
# #                   plot_grid = facts_plot_2
# #                   )
# #
# #
# # facts_plot_3 <- GGally::ggpairs(col_facts[, c("Estado", "Sexo", "Inmunofenotipo_1", "HAS",
# #                                               "DM2", "Obesidad", "EPOC", "IRC",
# #                                               "BULUT_1")],
# #                                 axisLabels = 'show',
# #                                 showStrips = TRUE)
# # facts_plot_3
# # epi_plot_cow_save(file_name = 'ggpairs_facts.pdf',
# #                   base_height = 40,
# #                   base_width = 40,
# #                   plot_grid = facts_plot_3
# #                   )
#
# # # Create ggpairs plot, remove duplicated plots from diagonal:
# # # Custom function for lower triangle: scatter plot
# # show_lower <- function(data, mapping, ...) {
# #   ggplot(data = data, mapping = mapping) #+ geom_point(...)
# #   }
# #
# # # Custom function for upper triangle: blank
# # blank_upper <- function(data, mapping, ...) {
# #   ggplot() + theme_void()
# #   }
# #
#
# # facts_plot <- GGally::ggpairs(col_facts[, c("Estado", "HAS")],
# #                               lower = list(discrete = wrap("lower", show_lower)),
# #                               upper = list(discrete = wrap("upper", blank_upper)),
# #                               axisLabels = 'show',
# #                               showStrips = TRUE
# #                               )
#
# # ===
#
# # ===
# ## Numerical vs Categorical ----
# #### Visualize with grouped boxplots or violin plots ----
#
# # TO DO:
# # Consider:
# # Visualization:
# # Boxplots, violin plots, or beeswarm plots by groups.
# # Add jitter to scatter plots to display overlapping points.
#
# #### Boxplots / violin Plots
# # colnames(col_nums)
# #
# # epi_plot_box(df = df_factor,
# #              var_y = 'Neu_count_1',
# #              var_x = 'Estado'
# #              )
# #
# # epi_plot_box(df = df_factor,
# #              var_y = 'IFN_g',
# #              var_x = 'Estado'
# #              )
# #
# # epi_plot_box(df = df_factor,
# #              var_y = 'Lin_count_1',
# #              var_x = 'Estado'
# #              )
# #
# # epi_plot_box(df = df_factor,
# #              var_y = 'IgA_Lavado',
# #              var_x = 'Estado'
# #              )
# #
# # # Plot all numeric variables vs 'Estado'
# # colnames(col_nums)
# # i <- "Lin_count_1"
# # # eval(i)
# # # sym(i)
# # epi_plot_box(df = df_factor, var_y = i)
# # epi_plot_box(df = df_factor, var_y = i, var_x = 'Estado')
# #
# # box_list <- epi_plot_list(vars_to_plot = colnames(col_nums))
# # for (i in names(box_list)) {
# #   # print(i)
# #   box_list[[i]] <- epi_plot_box(df = df_factor,
# #                                 var_y = i,
# #                                 var_x = 'Estado'
# #                                 )
# #   }
# # length(box_list)
# # names(box_list)
# #
# # # Save plots
# # # Plot 4 per page or so:
# # per_file <- 4
# # jumps <- seq(1, length(box_list), per_file)
# # length(jumps)
# #
# # # i <- 2
# # for (i in jumps) {
# #   file_name <- sprintf('plots_box_%s.pdf', i)
# #   start_i <- i
# #   end_i <- i + 3
# #   my_plot_grid <- epi_plots_to_grid(box_list[start_i:end_i])
# #   epi_plot_cow_save(file_name = file_name, plot_grid = my_plot_grid)
# # }
#
# # ===
# # ////////////
#
#
# # ////////////
# #### Perform group comparisons and significance tests ----
#
# # TO DO:
# # Consider:
# # Group Comparisons:
# # Calculate group means, medians, or distributions.
# # Test for significant differences:
# # T-tests or Wilcoxon tests (for two groups).
# # ANOVA or Kruskal-Wallis tests (for more than two groups).
#
# # TO DO: significance tests for num vars vs 'Estado'
# # TO DO: create a function and move to episcout
#
# # # Wilcoxon Rank-Sum Test
# # factor_var <- df_factor[['Estado']]
# # num_var <- df_factor$Neu_count_1
# #
# # if (length(unique(factor_var)) == 2) {
# #   group1 <- num_var[factor_var == levels(factor_var)[1]]
# #   group2 <- num_var[factor_var == levels(factor_var)[2]]
# #   test <- wilcox.test(group1, group2,
# #                       exact = TRUE,
# #                       correct = TRUE,
# #                       conf.int = TRUE,
# #                       conf.level = 0.95
# #                       )
# #   print(test)
# # }
# # test$statistic
# #
# # # TO DO: continue here
# # wilcoxon_res <- data.frame(Group1 = character(),
# #                            Group2 = character(),
# #                            Variable = character(),
# #                            W = numeric(),
# #                            P.Value = numeric(),
# #                            CI95_low = numeric(),
# #                            CI95_high = numeric(),
# #                            stringsAsFactors = FALSE
# #                            )
# #
# # unique_groups <- unique(df_factor[['Estado']])
# # combinations <- combn(unique_groups, 2)
# # factor_var <- df_factor[['Estado']]
# # df <- df_factor
# # dim(combinations)
# #
# # # c <- 'Neu_count_1' #'Peso'
# # # # Example manual test for verification
# # # test_example <- wilcox.test(df$Edad[df$Estado == "Defuncion"], df$Edad[df$Estado == "Mejoria"])
# # # print(test_example)
# #
# # for (c in colnames(col_nums)) {
# #   for (i in 1:ncol(combinations)) {
# #     group1_data <- df[factor_var == combinations[1, i], c]
# #     group2_data <- df[factor_var == combinations[2, i], c]
# #     # print(head(group1_data))  # Check the data
# #     # print(head(group2_data))  # Check the data
# #     test <- wilcox.test(group1, group2,
# #                         exact = TRUE,
# #                         correct = TRUE,
# #                         conf.int = TRUE,
# #                         conf.level = 0.95
# #                         )
# #     wilcoxon_res <- rbind(wilcoxon_res,
# #                           data.frame(Group1 = combinations[1, i],
# #                                      Group2 = combinations[2, i],
# #                                      Variable = c,
# #                                      W = test$statistic,
# #                                      P.Value = test$p.value,
# #                                      CI95_low = test$conf.int[1],
# #                                      CI95_high = test$conf.int[2]
# #                                      )
# #                           )
# #   }
# # }
# # epi_head_and_tail(wilcoxon_res, cols = 7)
# # ////////////
#
#
# # ////////////
# # Date Variables with Other Types ----
#
# # TO DO:
# # Consider:
# # Trends:
# # Aggregate numerical data over time (e.g., monthly averages, yearly totals).
# # Plot time-series trends with line charts.
# # Event Analysis:
# # Compare categorical event frequencies over time.
# # Use Gantt charts or event plots for timelines.
# # Lagged Effects:
# # Analyze lag relationships (e.g., weekly sales impact on monthly outcomes).
# # ////////////
#
#
# # ////////////
# # TO DO:
# # Consider:
# # Outlier Detection ----
# # Numerical Variables:
# # Detect outliers using:
# # Z-scores or modified Z-scores.
# # IQR rule (values outside [Q1 - 1.5IQR, Q3 + 1.5IQR]).
# # Visualize with boxplots or scatter plots.
# # Multivariate Outliers:
# # Use Mahalanobis distance or DBSCAN clustering.
# # ////////////
#
#
# # ////////////
# # TO DO:
#
# # To a table:
# # (summary(na.omit(df_factor$IgA_Lavado)),
# #       summary(na.omit(df_factor$IgA_Suero)),
# #       summary(na.omit(df_factor$IgG_Lavado)),
# #       summary(na.omit(df_factor$IgG_Suero)),
# #       summary(na.omit(df_factor$IgM_Lavado)),
# #       summary(na.omit(df_factor$IgM_Suero))
# #       )
#
#
# # Two/+ factors
# # clustered bar, stacked bar, heatmap
#
# # Pause after this as descriptive
# # ////////////
#
#
# # ////////////
# # Next:
# # Impute based on key variables
# # Comparisons for survival
# # Comparisons for local vs systemic response
# # Inferential analysis
# # ////////////
#
#
# # ////////////
# # The end ----
# # Outputs saved to disk, no need to save as rdata.
# sessionInfo()
#
# # Closing message loggers:
# if (!interactive()) { # TRUE if not interactive, will then log output
#     info(logger, "Script completed successfully")
#
#     # Close screen output log (both screen and warnings/error messages):
#     # Stop sinks
#     sink(type = "message")
#     close(sink_msg)  # Close the connection
#     sink()
#     }
#
# # q()
# # ////////////
