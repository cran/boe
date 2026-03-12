test_that("boe_bank_rate() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- boe_bank_rate(from = "2024-01-01", to = "2024-01-31")

  expect_s3_class(out, "data.frame")
  expect_named(out, c("date", "rate_pct"))
  expect_s3_class(out$date, "Date")
  expect_type(out$rate_pct, "double")
  expect_true(nrow(out) > 0)
})

test_that("boe_bank_rate() monthly frequency works", {
  skip_on_cran()
  skip_if_offline()

  out <- boe_bank_rate(from = "2024-01-01", to = "2024-06-30", frequency = "monthly")
  expect_true(nrow(out) >= 1)
})
