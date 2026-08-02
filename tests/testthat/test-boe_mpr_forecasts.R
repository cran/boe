# Tests for boe_mpr_forecasts() (parses the BoE projections databank,
# classic and scenario-based formats).

# ---- URL + release resolution (offline, pure) --------------------------------

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

# ---- format-aware series mapping (offline, pure) -----------------------------

test_that("series-to-sheet maps are format-aware", {
  # Classic format: the five traditional series; scenario-only series NA.
  expect_equal(mpr_sheet_old("cpi_inflation"), "1. CPI inflation")
  expect_equal(mpr_sheet_old("bank_rate"),     "38. Bank Rate")
  expect_true(is.na(mpr_sheet_old("output_gap")))

  # Scenario format: renumbered sheets; GDP level and Bank Rate dropped.
  expect_equal(mpr_sheet_scenario("cpi_inflation"), "2. CPI inflation")
  expect_equal(mpr_sheet_scenario("output_gap"),    "5. Output gap")
  expect_true(is.na(mpr_sheet_scenario("gdp_level")))
  expect_true(is.na(mpr_sheet_scenario("bank_rate")))
})

test_that("release_pub_date is the first of the publication month", {
  expect_equal(release_pub_date(list(month = "april",    year = 2026L)),
               as.Date("2026-04-01"))
  expect_equal(release_pub_date(list(month = "november", year = 2025L)),
               as.Date("2025-11-01"))
})

test_that("hybrid_scenario_pool isolates the Quarterly scenarios section", {
  sheets <- c("Cover", "Central projections ==>", "1. CPI inflation",
              "22. Output gap", "Quarterly scenarios ==>",
              "44. CPI inflation", "47. Output gap",
              "Scenario conditioning paths ==>", "51. Conditioning assumptions")
  pool <- hybrid_scenario_pool(sheets)
  expect_equal(pool, c("44. CPI inflation", "47. Output gap"))

  # No scenario section -> empty pool.
  expect_equal(hybrid_scenario_pool(c("Cover", "1. CPI inflation")),
               character(0))
})

test_that("resolve_scenario_sheet prefers the quarterly over the annual sheet", {
  sheets <- c("Cover", "2. CPI inflation", "3. GDP growth",
              "9. CPI inflation", "10. GDP growth")
  # Exact match.
  expect_equal(resolve_scenario_sheet(sheets, "2. CPI inflation", "cpi_inflation"),
               "2. CPI inflation")
  # Number drift: fall back to the first name match, which is quarterly.
  expect_equal(resolve_scenario_sheet(sheets, "99. CPI inflation", "cpi_inflation"),
               "2. CPI inflation")
  # Absent series -> NA (caller skips with a warning).
  expect_true(is.na(resolve_scenario_sheet(sheets, "5. Output gap", "output_gap")))
})

# ---- network: release resolution ---------------------------------------------

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

test_that("pick_mpr_release returns the most recent published release", {
  testthat::skip_on_cran()
  testthat::skip_if_offline()

  op <- options(boe.cache_dir = tempfile("boe_pick_"))
  on.exit(options(op), add = TRUE)

  picked <- pick_mpr_release()
  # The crux of the original 404 bug: the auto-selected release must be
  # downloadable. Both classic and scenario formats are parsed, so no
  # format filtering is applied.
  expect_false(is.null(mpr_resolve_url(picked$release$month,
                                       picked$release$year)))
  expect_true(file.exists(picked$zip_path))
})

# ---- network: parsing both formats -------------------------------------------

test_that("scenario-format release parses with a scenario dimension (April 2026)", {
  testthat::skip_on_cran()
  testthat::skip_if_offline()
  testthat::skip_if_not_installed("readxl")

  op <- options(boe.cache_dir = tempfile("boe_scn_"))
  on.exit(options(op), add = TRUE)

  out <- boe_mpr_forecasts(series = c("cpi_inflation", "gdp_growth",
                                      "unemployment"),
                           month = "april", year = 2026)

  expect_s3_class(out, "boe_tbl")
  expect_true(all(c("date", "horizon", "horizon_date", "series",
                    "scenario", "value") %in% names(out)))
  expect_setequal(unique(out$series),
                  c("cpi_inflation", "gdp_growth", "unemployment"))
  # Several scenario paths, at least one labelled "... Scenario ...".
  expect_gt(length(unique(out$scenario)), 1L)
  expect_true(any(grepl("Scenario", out$scenario)))
  expect_equal(unique(out$date), as.Date("2026-04-01"))
  expect_true(all(grepl("^\\d{4} Q[1-4]$", out$horizon)))

  # A scenario-only series is available on request.
  og <- boe_mpr_forecasts(series = "output_gap", month = "april", year = 2026)
  expect_gt(nrow(og), 0L)
  expect_true(all(og$series == "output_gap"))

  # Series the scenario format drops are skipped with a warning, not an error.
  expect_warning(
    dropped <- boe_mpr_forecasts(
      series = c("cpi_inflation", "bank_rate", "gdp_level"),
      month = "april", year = 2026),
    "not published"
  )
  expect_false(any(c("bank_rate", "gdp_level") %in% dropped$series))
  expect_true("cpi_inflation" %in% dropped$series)
})

test_that("classic-format release still parses, with scenario = NA (February 2026)", {
  testthat::skip_on_cran()
  testthat::skip_if_offline()
  testthat::skip_if_not_installed("readxl")

  op <- options(boe.cache_dir = tempfile("boe_classic_"))
  on.exit(options(op), add = TRUE)

  out <- boe_mpr_forecasts(
    series = c("cpi_inflation", "gdp_growth", "gdp_level",
               "unemployment", "bank_rate"),
    month = "february", year = 2026)

  expect_setequal(
    unique(out$series),
    c("cpi_inflation", "gdp_growth", "gdp_level", "unemployment", "bank_rate"))
  expect_true("scenario" %in% names(out))
  expect_true(all(is.na(out$scenario)))
  expect_gt(nrow(out), 100L)
})

test_that("hybrid-format release parses central projections and scenarios (July 2026)", {
  testthat::skip_on_cran()
  testthat::skip_if_offline()
  testthat::skip_if_not_installed("readxl")

  op <- options(boe.cache_dir = tempfile("boe_hybrid_"))
  on.exit(options(op), add = TRUE)

  out <- boe_mpr_forecasts(series = c("cpi_inflation", "bank_rate",
                                      "gdp_level", "output_gap"),
                           month = "july", year = 2026)

  # All four series present: the hybrid workbook restores GDP level and
  # Bank Rate, and carries the scenario-only series in its Quarterly
  # scenarios section. Nothing is skipped, so no warning.
  expect_setequal(unique(out$series),
                  c("cpi_inflation", "bank_rate", "gdp_level", "output_gap"))

  # Central projections (classic sheets) have scenario = NA and span
  # multiple publication vintages.
  central <- out[is.na(out$scenario) & out$series == "cpi_inflation", ]
  expect_gt(length(unique(central$date)), 5L)

  # Scenario paths are labelled and dated to the release.
  scen <- out[!is.na(out$scenario), ]
  expect_gt(nrow(scen), 0L)
  expect_true(any(grepl("Scenario", scen$scenario)))
  expect_equal(unique(scen$date), as.Date("2026-07-01"))

  # The scenario paths for output_gap come from the Quarterly scenarios
  # section (sheet 47), not the classic "22. Output gap" sheet: every
  # output_gap row must carry a scenario label.
  og <- out[out$series == "output_gap", ]
  expect_true(all(!is.na(og$scenario)))
})

test_that("boe_mpr_forecasts auto-selects and parses the latest release", {
  testthat::skip_on_cran()
  testthat::skip_if_offline()
  testthat::skip_if_not_installed("readxl")

  op <- options(boe.cache_dir = tempfile("boe_auto_"))
  on.exit(options(op), add = TRUE)

  out <- suppressWarnings(boe_mpr_forecasts(series = "cpi_inflation"))

  expect_s3_class(out, "boe_tbl")
  expect_true(all(c("date", "horizon", "horizon_date", "series",
                    "scenario", "value") %in% names(out)))
  expect_gt(nrow(out), 100L)
  expect_true(all(out$series == "cpi_inflation"))
  expect_true(all(grepl("^\\d{4} Q[1-4]$", out$horizon)))
  expect_s3_class(out$horizon_date, "Date")
  expect_equal(attr(out, "boe_query")$function_name, "boe_mpr_forecasts")
})
