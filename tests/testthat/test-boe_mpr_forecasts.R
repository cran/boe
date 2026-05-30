# Tests for boe_mpr_forecasts() (parses BoE Projections Databank).

test_that("mpr_zip_url / mpr_zip_urls handle the filename drift", {
  # Primary best guess: singular "chart" for <= 2024, plural for >= 2025.
  expect_match(mpr_zip_url("november", 2024L), "chart-slides-and-data\\.zip$")
  expect_match(mpr_zip_url("february", 2026L), "charts-slides-and-data\\.zip$")
  expect_match(mpr_zip_url("november", 2024L),
               "/monetary-policy-report/2024/november/")

  # Both filename variants are offered so the caller can probe each.
  urls <- mpr_zip_urls("may", 2025L)
  expect_length(urls, 2L)
  expect_true(any(grepl("charts-slides-and-data.zip", urls, fixed = TRUE)))
  expect_true(any(grepl("mpr-may-2025-chart-slides-and-data.zip", urls,
                        fixed = TRUE)))
})

test_that("mpr_release_candidates lists recent months, newest first", {
  cands <- mpr_release_candidates(today = as.Date("2026-05-29"), n_months = 4L)
  expect_length(cands, 4L)
  expect_equal(cands[[1L]], list(month = "may",      year = 2026L))
  expect_equal(cands[[2L]], list(month = "april",    year = 2026L))
  expect_equal(cands[[4L]], list(month = "february", year = 2026L))

  # Year rollover when walking back past January.
  roll <- mpr_release_candidates(today = as.Date("2026-01-15"), n_months = 3L)
  expect_equal(roll[[1L]], list(month = "january",  year = 2026L))
  expect_equal(roll[[2L]], list(month = "december", year = 2025L))
  expect_equal(roll[[3L]], list(month = "november", year = 2025L))
})

test_that("resolve_mpr_release validates inputs", {
  # Any real month name is accepted: the schedule drifts (the 2026 Q2
  # report was published in April, not May), so we no longer hard-code
  # a Feb/May/Aug/Nov calendar.
  expect_equal(resolve_mpr_release(month = "april", year = 2026L),
               list(month = "april", year = 2026L))
  expect_error(resolve_mpr_release(month = "smarch", year = 2026L), "month name")
  expect_error(resolve_mpr_release(month = "february", year = 2018L), "2019")
  expect_error(resolve_mpr_release(month = "february", year = NULL), "both")
})

test_that("quarter_label_to_date parses the BoE format", {
  d <- quarter_label_to_date(c("2024 Q1", "2024 Q4", "2025 Q2"))
  expect_equal(d, as.Date(c("2024-01-01", "2024-10-01", "2025-04-01")))
})

test_that("URL probing survives schedule drift and filename variants", {
  testthat::skip_on_cran()
  testthat::skip_if_offline()

  # Regression: the 2026 Q2 report was published in April, not May. The
  # old code guessed May and 404'd; the resolver must reflect reality.
  expect_null(mpr_resolve_url("may", 2026L))
  expect_false(is.null(mpr_resolve_url("april", 2026L)))

  # The data archive filename drifted from "chart-slides-and-data"
  # (February 2025, singular) to "charts-slides-and-data" (August 2025,
  # plural). Both must resolve via the variant probing.
  expect_false(is.null(mpr_resolve_url("february", 2025L)))
  expect_false(is.null(mpr_resolve_url("august", 2025L)))

  # The existence check distinguishes a live archive from a 404.
  expect_true(url_exists_boe(mpr_zip_url("august", 2025L)))
  expect_false(url_exists_boe(mpr_zip_url("may", 2026L)))
})

test_that("pick_mpr_release returns a real, parseable release", {
  testthat::skip_on_cran()
  testthat::skip_if_offline()

  op <- options(boe.cache_dir = tempfile("boe_pick_"))
  on.exit(options(op), add = TRUE)

  picked <- suppressWarnings(pick_mpr_release())

  # The crux of the original bug: the auto-selected release must
  # actually be downloadable (no 404) and parseable (classic format).
  expect_false(is.null(mpr_resolve_url(picked$release$month,
                                       picked$release$year)))
  expect_true(file.exists(picked$zip_path))
  expect_true(mpr_zip_is_old_format(picked$zip_path))
})

test_that("boe_mpr_forecasts fetches and parses the latest compatible release", {
  testthat::skip_on_cran()
  testthat::skip_if_offline()
  testthat::skip_if_not_installed("readxl")

  op <- options(boe.cache_dir = tempfile("boe_mpr_"))
  on.exit(options(op), add = TRUE)

  # suppressWarnings: when the latest release uses the unsupported
  # scenario format, the function warns and falls back to an earlier one.
  out <- suppressWarnings(
    boe_mpr_forecasts(series = c("cpi_inflation", "bank_rate"))
  )

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
