library(testthat)
library(withr)

# Basic smoke test for scripts/some_script.R

#script <- file.path("..", "..", "scripts", "some_script.R")
script_loc <- here::here("scripts", "some_script.R")

test_that("some_script.R executes and creates output", {
  in_csv <- withr::local_tempfile(fileext = ".csv")
  out_csv <- withr::local_tempfile(fileext = ".csv")
  write.csv(data.frame(a = 1:2, b = 2:3), in_csv, row.names = FALSE)
  exit_code <- system2("Rscript", c(script_loc, in_csv, out_csv))
  expect_equal(exit_code, 0)
  expect_true(file.exists(out_csv))
})

test_that("output has expected columns", {
  in_csv <- withr::local_tempfile(fileext = ".csv")
  out_csv <- withr::local_tempfile(fileext = ".csv")
  write.csv(data.frame(a = 1:2, b = 2:3), in_csv, row.names = FALSE)
  system2("Rscript", c(script_loc, in_csv, out_csv))
  out <- read.csv(out_csv)
  expect_equal(names(out), c("a", "b", "new_var"))
  expect_type(out$new_var, "double")
})

#test_that("missing input triggers error", {
#  missing <- tempfile(fileext = ".csv")
#  out_csv <- tempfile(fileext = ".csv")
#  expect_error(
#    system2("Rscript", c(script_loc, missing, out_csv), stderr = TRUE, stdout = TRUE),
#    "Input file does not exist"
#  )
#})

test_that("missing input triggers error", {
  expect_error(system2("Rscript", c(script_loc, "nonexistent.csv", "output.csv")), 
               "Input file does not exist")
})
