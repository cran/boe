# Tests for boe_mpr_forecasts() (parses BoE Projections Databank).

test_that("boe_mpr_forecasts URL helper toggles on year >= 2025", {
  expect_match(mpr_zip_url("november", 2024L), "chart-slides-and-data\\.zip$")
  expect_match(mpr_zip_url("february", 2026L), "charts-slides-and-data\\.zip$")
  expect_match(mpr_zip_url("november", 2024L),
               "/monetary-policy-report/2024/november/")
})

test_that("latest_mpr_release picks a sensible recent quarter", {
  rel_apr <- latest_mpr_release(today = as.Date("2026-04-25"))
  expect_equal(rel_apr$month, "february")
  expect_equal(rel_apr$year,  2026L)

  rel_jan <- latest_mpr_release(today = as.Date("2026-01-15"))
  expect_equal(rel_jan$month, "november")
  expect_equal(rel_jan$year,  2025L)

  rel_feb <- latest_mpr_release(today = as.Date("2026-02-05"))
  # Feb release usually published mid-month; before day 14 we still expect Nov 2025
  expect_equal(rel_feb$month, "november")
  expect_equal(rel_feb$year,  2025L)
})

test_that("resolve_mpr_release validates inputs", {
  expect_error(resolve_mpr_release(month = "march", year = 2026L), "february")
  expect_error(resolve_mpr_release(month = "february", year = 2018L), "2019")
  expect_error(resolve_mpr_release(month = "february", year = NULL), "both")
})

test_that("quarter_label_to_date parses the BoE format", {
  d <- quarter_label_to_date(c("2024 Q1", "2024 Q4", "2025 Q2"))
  expect_equal(d, as.Date(c("2024-01-01", "2024-10-01", "2025-04-01")))
})

test_that("boe_mpr_forecasts fetches and parses the latest release", {
  testthat::skip_on_cran()
  testthat::skip_if_offline()
  testthat::skip_if_not_installed("readxl")

  op <- options(boe.cache_dir = tempfile("boe_mpr_"))
  on.exit(options(op), add = TRUE)

  out <- boe_mpr_forecasts(series = c("cpi_inflation", "bank_rate"))

  expect_s3_class(out, "boe_tbl")
  expected_cols <- c("date", "horizon", "horizon_date", "series", "value")
  expect_true(all(expected_cols %in% names(out)))
  expect_gt(nrow(out), 100L)
  expect_true(all(out$series %in% c("cpi_inflation", "bank_rate")))
  expect_true(all(grepl("^\\d{4} Q[1-4]$", out$horizon)))
  expect_s3_class(out$horizon_date, "Date")

  q <- attr(out, "boe_query")
  expect_equal(q$function_name, "boe_mpr_forecasts")
})
