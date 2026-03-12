test_that("boe_yield_curve() rejects real par_yield", {
  expect_error(
    boe_yield_curve(type = "real", measure = "par_yield"),
    "par yields"
  )
})

test_that("boe_yield_curve() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- boe_yield_curve(from = "2024-01-01", to = "2024-01-31", maturity = "10yr")

  expect_s3_class(out, "data.frame")
  expect_named(out, c("date", "maturity", "yield_pct"))
  expect_true(all(out$maturity == "10yr"))
  expect_true(nrow(out) > 0)
})

test_that("boe_yield_curve() handles multiple maturities", {
  skip_on_cran()
  skip_if_offline()

  out <- boe_yield_curve(from = "2024-01-01", to = "2024-01-31")
  expect_true(all(c("5yr", "10yr", "20yr") %in% out$maturity))
})
