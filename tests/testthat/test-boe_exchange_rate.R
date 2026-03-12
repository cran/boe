test_that("boe_exchange_rate() rejects unknown currency", {
  expect_error(boe_exchange_rate("XYZ"), "Unknown")
})

test_that("list_exchange_rates() returns expected structure", {
  out <- list_exchange_rates()
  expect_s3_class(out, "data.frame")
  expect_named(out, c("currency", "description", "boe_code"))
  expect_true("USD" %in% out$currency)
  expect_true("EUR" %in% out$currency)
  expect_true(nrow(out) > 20)
})

test_that("boe_exchange_rate() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- boe_exchange_rate("USD", from = "2024-01-01", to = "2024-01-31")

  expect_s3_class(out, "data.frame")
  expect_named(out, c("date", "currency", "rate"))
  expect_true(all(out$currency == "USD"))
  expect_true(nrow(out) > 0)
})

test_that("boe_exchange_rate() handles multiple currencies", {
  skip_on_cran()
  skip_if_offline()

  out <- boe_exchange_rate(c("USD", "EUR"), from = "2024-01-01", to = "2024-01-31")
  expect_true(all(c("USD", "EUR") %in% out$currency))
})
