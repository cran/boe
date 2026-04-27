# Tests for boe_curve() (Anderson-Sleath fitted yield curves).
# Network-dependent; skipped on CRAN and offline.

test_that("boe_curve rejects invalid curve / measure", {
  expect_error(boe_curve(curve = "foo"))
  expect_error(boe_curve(measure = "par"))
})

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
