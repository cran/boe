# Tests for the boe_tbl S3 class.

test_that("new_boe_tbl returns a data.frame subclass", {
  df <- data.frame(date = Sys.Date(), value = 1)
  x  <- new_boe_tbl(df, query = list(series_codes = "IUDBEDR"))

  expect_s3_class(x, "boe_tbl")
  expect_s3_class(x, "data.frame")
  expect_true(is.data.frame(x))
})

test_that("new_boe_tbl attaches query metadata", {
  df <- data.frame(date = Sys.Date(), value = 1)
  q  <- list(series_codes = c("IUDBEDR", "IUDSOIA"),
             from = as.Date("2020-01-01"),
             to   = as.Date("2020-12-31"),
             frequency = "daily",
             function_name = "boe_get")

  x   <- new_boe_tbl(df, query = q)
  got <- attr(x, "boe_query")

  expect_equal(got$series_codes, c("IUDBEDR", "IUDSOIA"))
  expect_equal(got$frequency, "daily")
  expect_equal(got$function_name, "boe_get")
  expect_s3_class(got$fetched_at, "POSIXct")
})

test_that("new_boe_tbl coerces non-data-frames", {
  m <- matrix(1:4, ncol = 2, dimnames = list(NULL, c("a", "b")))
  x <- new_boe_tbl(m)
  expect_s3_class(x, "boe_tbl")
  expect_true(is.data.frame(x))
})

test_that("new_boe_tbl preserves a user-supplied fetched_at", {
  ts <- as.POSIXct("2026-01-01 00:00:00", tz = "UTC")
  x  <- new_boe_tbl(data.frame(a = 1), query = list(fetched_at = ts))
  expect_equal(attr(x, "boe_query")$fetched_at, ts)
})

test_that("print.boe_tbl emits a provenance header", {
  df <- data.frame(date = as.Date("2020-01-01") + 0:9, value = 1:10)
  x  <- new_boe_tbl(df, query = list(
    series_codes  = "IUDBEDR",
    from          = as.Date("2020-01-01"),
    to            = as.Date("2020-01-10"),
    frequency     = "daily",
    function_name = "boe_bank_rate"
  ))

  out <- utils::capture.output(print(x))

  expect_true(any(grepl("^# BoE \\[boe_bank_rate\\]:", out)))
  expect_true(any(grepl("1 series \\[IUDBEDR\\]", out)))
  expect_true(any(grepl("10 obs", out)))
  expect_true(any(grepl("freq=daily", out)))
  expect_true(any(grepl("2020-01-01 to 2020-01-10", out)))
})

test_that("print.boe_tbl falls back when function_name is missing", {
  df <- data.frame(a = 1)
  x  <- new_boe_tbl(df, query = list(series_codes = "IUDBEDR"))
  out <- utils::capture.output(print(x))
  expect_true(any(grepl("^# BoE: ", out)))
})

test_that("print.boe_tbl summarises many-series queries without listing all codes", {
  codes <- sprintf("XCODE%02d", 1:10)
  df <- data.frame(a = 1)
  x  <- new_boe_tbl(df, query = list(series_codes = codes))
  out <- utils::capture.output(print(x))
  expect_true(any(grepl("10 series", out)))
  expect_false(any(grepl("XCODE01,XCODE02", out)))
})
