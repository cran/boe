test_that("boe_sonia() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- boe_sonia(from = "2024-01-01", to = "2024-01-31")

  expect_s3_class(out, "data.frame")
  expect_named(out, c("date", "rate_pct"))
  expect_s3_class(out$date, "Date")
  expect_type(out$rate_pct, "double")
  expect_true(nrow(out) > 0)
})

test_that("boe_sonia() monthly frequency works", {
  skip_on_cran()
  skip_if_offline()

  out <- boe_sonia(from = "2024-01-01", to = "2024-06-30", frequency = "monthly")
  expect_true(nrow(out) >= 1)
  expect_named(out, c("date", "rate_pct"))
})

test_that("boe_sonia() annual frequency works", {
  skip_on_cran()
  skip_if_offline()

  out <- boe_sonia(from = "2020-01-01", to = "2024-12-31", frequency = "annual")
  expect_true(nrow(out) >= 1)
  expect_named(out, c("date", "rate_pct"))
})

test_that("boe_sonia() rejects invalid frequency", {
  expect_error(boe_sonia(frequency = "weekly"))
})
