# Tests for boe_curve() and boe_curve_panel().
# Network-dependent paths are skipped on CRAN and offline.

# ---- argument validation (offline, no network) ------------------------------

test_that("boe_curve rejects invalid curve / measure / frequency", {
  expect_error(boe_curve(curve = "foo"))
  expect_error(boe_curve(measure = "par"))
  expect_error(boe_curve(frequency = "weekly"))
})

test_that("boe_curve rejects from > to", {
  expect_error(
    boe_curve(curve = "nominal", from = "2020-01-01", to = "2019-01-01"),
    regexp = "must be before"
  )
})

test_that("boe_curve_panel rejects non-positive maturities", {
  expect_error(boe_curve_panel(maturities = c(-1, 5)))
  expect_error(boe_curve_panel(maturities = c(0, 5)))
})

test_that("boe_curve and boe_curve_panel reject invalid segment", {
  expect_error(boe_curve(segment = "frontend"))
  expect_error(boe_curve_panel(segment = "frontend"))
})

# ---- short-end sheet selection (offline, pure function) ----------------------

test_that("yield_sheet_pattern selects sheets by measure and segment", {
  # Standard sheets (modern + curve-name-infixed older layout).
  expect_match("4. spot curve",         yield_sheet_pattern("spot", "standard"))
  expect_match("4. nominal spot curve", yield_sheet_pattern("spot", "standard"))
  expect_match("2. fwd curve",          yield_sheet_pattern("forward", "standard"))

  # Short-end sheets: spot uses "spot, short end"; forward is plural "fwds".
  expect_match("3. spot, short end",         yield_sheet_pattern("spot", "short"))
  expect_match("3. nominal spot, short end", yield_sheet_pattern("spot", "short"))
  expect_match("1. fwds, short end",         yield_sheet_pattern("forward", "short"))
  expect_match("1. nominal fwds, short end", yield_sheet_pattern("forward", "short"))
})

test_that("yield_sheet_pattern does not cross-match segments", {
  expect_false(grepl(yield_sheet_pattern("spot", "standard"),
                     "3. spot, short end", ignore.case = TRUE))
  expect_false(grepl(yield_sheet_pattern("spot", "short"),
                     "4. spot curve", ignore.case = TRUE))
  expect_false(grepl(yield_sheet_pattern("forward", "standard"),
                     "1. fwds, short end", ignore.case = TRUE))
})

# ---- panel pillar labelling (offline, mocked boe_curve) ---------------------

test_that("boe_curve_panel keeps labels aligned when a pillar is dropped", {
  fake_long <- new_boe_tbl(
    data.frame(
      date           = rep(as.Date(c("2020-01-01", "2020-01-02")), each = 3),
      maturity_years = rep(c(1, 2, 5), times = 2),
      rate_pct       = c(1.1, 2.2, 5.5, 1.2, 2.3, 5.6)
    ),
    query = list(function_name = "boe_curve", source = "latest")
  )
  testthat::local_mocked_bindings(boe_curve = function(...) fake_long)

  # Pillar 10 is absent from the (1, 2, 5) grid, so it must drop without
  # shifting the labels of the surviving columns.
  expect_warning(
    panel <- boe_curve_panel(curve = "nominal", maturities = c(1, 2, 5, 10)),
    regexp = "not on the"
  )
  expect_named(panel, c("date", "m1", "m2", "m5"))
  expect_equal(panel$m1[panel$date == as.Date("2020-01-01")], 1.1)
  expect_equal(panel$m5[panel$date == as.Date("2020-01-01")], 5.5)
})

# ---- network-dependent: short end -------------------------------------------

test_that("boe_curve fetches the short end with monthly maturities", {
  testthat::skip_on_cran()
  testthat::skip_if_offline()
  testthat::skip_if_not_installed("readxl")

  op <- options(boe.cache_dir = tempfile("boe_short_"))
  on.exit(options(op), add = TRUE)

  out <- boe_curve(curve = "nominal", measure = "spot", segment = "short")

  expect_s3_class(out, "boe_tbl")
  expect_gt(nrow(out), 50L)
  expect_lt(min(out$maturity_years), 0.5)    # sub-6-month points exist
  expect_lte(max(out$maturity_years), 5.01)  # short end caps near 5 years

  q <- attr(out, "boe_query")
  expect_equal(q$segment, "short")
  expect_match(q$series_codes, "AS_NOMINAL_SPOT_SHORT")
})

test_that("short end caps lower than standard; forward short end parses", {
  testthat::skip_on_cran()
  testthat::skip_if_offline()
  testthat::skip_if_not_installed("readxl")

  op <- options(boe.cache_dir = tempfile("boe_short2_"))
  on.exit(options(op), add = TRUE)

  std   <- boe_curve(curve = "nominal", measure = "spot", segment = "standard")
  short <- boe_curve(curve = "nominal", measure = "spot", segment = "short")
  expect_lt(max(short$maturity_years), max(std$maturity_years))

  fwd <- boe_curve(curve = "nominal", measure = "forward", segment = "short")
  expect_gt(nrow(fwd), 50L)
})

test_that("OIS short end skips periods without a short-end sheet", {
  testthat::skip_on_cran()
  testthat::skip_if_offline()
  testthat::skip_if_not_installed("readxl")

  op <- options(boe.cache_dir = tempfile("boe_ois_short_"))
  on.exit(options(op), add = TRUE)

  # OIS publishes no short end for 2009-2015; requesting from 2009 must skip
  # those workbooks cleanly rather than error, and still return later data.
  out <- boe_curve(curve = "ois", measure = "spot", segment = "short",
                   from = "2009-01-01")
  expect_s3_class(out, "boe_tbl")
  expect_gt(nrow(out), 0L)
  expect_gt(min(out$date), as.Date("2010-01-01"))
})

test_that("boe_curve_panel short segment returns short-end pillars", {
  testthat::skip_on_cran()
  testthat::skip_if_offline()
  testthat::skip_if_not_installed("readxl")

  op <- options(boe.cache_dir = tempfile("boe_panel_short_"))
  on.exit(options(op), add = TRUE)

  panel <- boe_curve_panel(curve = "nominal", measure = "spot",
                           segment = "short", maturities = c(1, 2, 5))
  expect_s3_class(panel, "boe_tbl")
  expect_named(panel, c("date", "m1", "m2", "m5"))
  expect_gt(nrow(panel), 10L)
})

# ---- archive URL registry (offline) -----------------------------------------

test_that("yield_archive_registry has 5 curves x 2 frequencies", {
  reg <- yield_archive_registry()
  expect_named(reg, c("daily", "monthly"))
  expect_named(reg$daily,
               c("nominal", "real", "inflation", "ois", "blc"),
               ignore.order = TRUE)
  expect_named(reg$monthly,
               c("nominal", "real", "inflation", "ois", "blc"),
               ignore.order = TRUE)
})

test_that("yield_archive_url constructs valid URLs", {
  u <- yield_archive_url("nominal", "daily")
  expect_match(u, "^https://www.bankofengland.co.uk/.*\\.zip$")
  expect_match(u, "glcnominalddata.zip$")

  u2 <- yield_archive_url("ois", "monthly")
  expect_match(u2, "oismonthedata.zip$")

  u3 <- yield_archive_url("blc", "daily")
  expect_match(u3, "blcnomddata.zip$")
})

test_that("yield_archive_url errors on unknown curve", {
  expect_error(yield_archive_url("treasury", "daily"))
})

# ---- maturity-row detection (offline, synthetic) ----------------------------

test_that("detect_maturity_row finds row 4 in modern layout", {
  raw <- data.frame(
    matrix(c(
      "title", NA, NA, NA, NA, NA,
      "Maturity ", NA, NA, NA, NA, NA,
      "months:", "6", "12", "24", "36", "60",
      "years:", 0.5, 1, 2, 3, 5,
      NA, NA, NA, NA, NA, NA,
      "1970-01-31", 1.0, 1.1, 1.2, 1.3, 1.4
    ), nrow = 6, byrow = TRUE),
    stringsAsFactors = FALSE
  )
  expect_equal(detect_maturity_row(raw), 4L)
})

test_that("detect_maturity_row falls back when row 4 is empty", {
  raw <- data.frame(
    matrix(c(
      "title", NA, NA, NA, NA, NA,
      "years:", 0.5, 1, 2, 3, 5,           # row 2 holds maturities
      NA, NA, NA, NA, NA, NA,
      NA, NA, NA, NA, NA, NA,              # row 4 is empty
      NA, NA, NA, NA, NA, NA,
      "1970-01-31", 1.0, 1.1, 1.2, 1.3, 1.4
    ), nrow = 6, byrow = TRUE),
    stringsAsFactors = FALSE
  )
  out <- detect_maturity_row(raw)
  expect_true(is.na(out) || out %in% c(3L, 5L, 6L))
})

# ---- network-dependent: latest month (default behaviour) --------------------

test_that("boe_curve fetches and parses the nominal spot curve", {
  testthat::skip_on_cran()
  testthat::skip_if_offline()
  testthat::skip_if_not_installed("readxl")

  op <- options(boe.cache_dir = tempfile("boe_curve_"))
  on.exit(options(op), add = TRUE)

  out <- boe_curve(curve = "nominal", measure = "spot")

  expect_s3_class(out, "boe_tbl")
  expect_true(all(c("date", "maturity_years", "rate_pct") %in% names(out)))
  expect_gt(nrow(out), 50L)
  expect_true(all(out$maturity_years >= 0.5))
  expect_true(all(is.finite(out$rate_pct)))

  q <- attr(out, "boe_query")
  expect_equal(q$function_name, "boe_curve")
  expect_equal(q$source, "latest")
  expect_match(q$series_codes, "AS_NOMINAL_SPOT")
})

test_that("boe_curve forward measure works for nominal", {
  testthat::skip_on_cran()
  testthat::skip_if_offline()
  testthat::skip_if_not_installed("readxl")

  op <- options(boe.cache_dir = tempfile("boe_curve_fwd_"))
  on.exit(options(op), add = TRUE)

  out <- boe_curve(curve = "nominal", measure = "forward")
  expect_s3_class(out, "boe_tbl")
  expect_gt(nrow(out), 50L)
})

test_that("boe_curve fetches inflation and OIS curves", {
  testthat::skip_on_cran()
  testthat::skip_if_offline()
  testthat::skip_if_not_installed("readxl")

  op <- options(boe.cache_dir = tempfile("boe_curve_misc_"))
  on.exit(options(op), add = TRUE)

  inflation <- boe_curve(curve = "inflation", measure = "spot")
  expect_s3_class(inflation, "boe_tbl")
  expect_gt(nrow(inflation), 0L)

  ois <- boe_curve(curve = "ois", measure = "spot")
  expect_s3_class(ois, "boe_tbl")
  expect_gt(nrow(ois), 0L)
})

# ---- network-dependent: archive paths ---------------------------------------

test_that("boe_curve fetches monthly archive for OIS (smallest zip)", {
  testthat::skip_on_cran()
  testthat::skip_if_offline()
  testthat::skip_if_not_installed("readxl")

  op <- options(boe.cache_dir = tempfile("boe_curve_arc_"))
  on.exit(options(op), add = TRUE)

  out <- boe_curve(curve = "ois", measure = "spot",
                   frequency = "monthly", from = "2015-01-01")

  expect_s3_class(out, "boe_tbl")
  expect_gt(nrow(out), 100L)
  expect_true(min(out$date) >= as.Date("2015-01-01"))

  q <- attr(out, "boe_query")
  expect_equal(q$source, "archive")
  expect_equal(q$frequency, "monthly")
})

test_that("boe_curve_panel returns wide format with requested pillars", {
  testthat::skip_on_cran()
  testthat::skip_if_offline()
  testthat::skip_if_not_installed("readxl")

  op <- options(boe.cache_dir = tempfile("boe_panel_"))
  on.exit(options(op), add = TRUE)

  # OIS only extends to ~5y so test pillars stay within that range
  panel <- boe_curve_panel(
    curve     = "ois",
    measure   = "spot",
    frequency = "monthly",
    from      = "2015-01-01",
    maturities = c(1, 3, 5)
  )

  expect_s3_class(panel, "boe_tbl")
  expect_named(panel, c("date", "m1", "m3", "m5"))
  expect_gt(nrow(panel), 100L)
  expect_true(all(is.finite(panel$m5) | is.na(panel$m5)))
})

test_that("boe_curve fetches BLC daily latest", {
  testthat::skip_on_cran()
  testthat::skip_if_offline()
  testthat::skip_if_not_installed("readxl")

  op <- options(boe.cache_dir = tempfile("boe_blc_"))
  on.exit(options(op), add = TRUE)

  out <- boe_curve(curve = "blc", measure = "spot")
  expect_s3_class(out, "boe_tbl")
  expect_gt(nrow(out), 50L)
})
