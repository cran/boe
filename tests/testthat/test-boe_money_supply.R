test_that("boe_money_supply() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- boe_money_supply(from = "2024-01-01", to = "2024-06-30")

  expect_s3_class(out, "data.frame")
  expect_named(out, c("date", "amount_gbp_m"))
  expect_s3_class(out$date, "Date")
  expect_type(out$amount_gbp_m, "double")
  expect_true(nrow(out) > 0)
})
