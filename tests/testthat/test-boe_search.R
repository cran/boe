# Tests for boe_search() and boe_browse() catalogue helpers.

test_that("boe_series catalogue has required columns and shape", {
  expect_s3_class(boe_series, "data.frame")
  expected_cols <- c("code", "title", "category", "frequency",
                     "unit", "start_date", "seasonal_adjustment", "helper")
  expect_true(all(expected_cols %in% names(boe_series)))
  expect_gt(nrow(boe_series), 40L)
  expect_true(all(nzchar(boe_series$code)))
  expect_true(all(nzchar(boe_series$title)))
})

test_that("boe_search() with no filters returns the full catalogue", {
  expect_equal(nrow(boe_search()), nrow(boe_series))
})

test_that("boe_search() filters on a keyword", {
  hits <- boe_search("mortgage")
  expect_gt(nrow(hits), 0L)
  expect_true(all(grepl("mortgage", hits$title, ignore.case = TRUE) |
                  grepl("mortgage", hits$code,  ignore.case = TRUE)))
})

test_that("boe_search() is case-insensitive", {
  expect_equal(nrow(boe_search("BANK RATE")),
               nrow(boe_search("bank rate")))
})

test_that("boe_search() filters on category", {
  fx <- boe_search(category = "exchange_rates")
  expect_true(all(fx$category == "exchange_rates"))
  expect_gt(nrow(fx), 20L)
})

test_that("boe_search() filters on frequency", {
  daily <- boe_search(frequency = "daily")
  expect_true(all(daily$frequency == "daily"))
})

test_that("boe_search() composes filters", {
  hits <- boe_search("yield", category = "interest_rates", frequency = "daily")
  expect_true(all(hits$category == "interest_rates"))
  expect_true(all(hits$frequency == "daily"))
})

test_that("boe_search() rejects non-character query", {
  expect_error(boe_search(query = 1L), "character")
})

test_that("boe_search() returns zero rows on no match", {
  expect_equal(nrow(boe_search("definitely_not_a_real_series_xyz")), 0L)
})

test_that("boe_browse() equals boe_search() with no query", {
  expect_equal(boe_browse(), boe_search())
  expect_equal(boe_browse(category = "consumer_credit"),
               boe_search(category = "consumer_credit"))
})
