library(testthat)

script_path <- file.path("..", "..", "oferta_educativa_laboral", "scripts",
                         "descriptive", "plots_theme_imss_palette.R")
source(script_path)

skip_if_not_installed("ggplot2")
skip_if_not_installed("ggthemes")


test_that("epi_plot_theme_imss returns a ggplot theme", {
  theme_obj <- epi_plot_theme_imss()
  expect_true(inherits(theme_obj, "theme"))
})
