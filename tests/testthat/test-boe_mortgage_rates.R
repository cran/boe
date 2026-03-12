test_that("boe_mortgage_rates() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- boe_mortgage_rates(from = "2024-01-01", to = "2024-06-30")

  expect_s3_class(out, "data.frame")
  expect_named(out, c("date", "type", "rate_pct"))
  expect_true(nrow(out) > 0)
  expect_true(all(out$type %in% c("2yr_fixed", "3yr_fixed", "5yr_fixed", "svr")))
})

test_that("boe_mortgage_rates() type filter works", {
  skip_on_cran()
  skip_if_offline()

  out <- boe_mortgage_rates(type = "2yr_fixed", from = "2024-01-01", to = "2024-06-30")
  expect_true(all(out$type == "2yr_fixed"))
})
