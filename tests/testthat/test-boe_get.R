test_that("boe_get() rejects empty series_codes", {
  expect_error(boe_get(character(0)), "series_codes")
})

test_that("boe_get() rejects non-character series_codes", {
 expect_error(boe_get(123), "series_codes")
})

test_that("boe_get() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- boe_get("IUDBEDR", from = "2024-01-01", to = "2024-01-31")

  expect_s3_class(out, "data.frame")
  expect_named(out, c("date", "code", "value"))
  expect_s3_class(out$date, "Date")
  expect_type(out$code, "character")
  expect_type(out$value, "double")
  expect_true(nrow(out) > 0)
  expect_true(all(out$code == "IUDBEDR"))
})

test_that("boe_get() handles multiple series", {
  skip_on_cran()
  skip_if_offline()

  out <- boe_get(c("IUDBEDR", "IUDSOIA"), from = "2024-01-01", to = "2024-01-31")

  expect_true(all(c("IUDBEDR", "IUDSOIA") %in% out$code))
})
