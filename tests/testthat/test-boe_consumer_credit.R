test_that("boe_consumer_credit() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- boe_consumer_credit(from = "2024-01-01", to = "2024-06-30")

  expect_s3_class(out, "data.frame")
  expect_named(out, c("date", "type", "amount_gbp_m"))
  expect_true(nrow(out) > 0)
  expect_true(all(out$type %in% c("total", "credit_card", "other")))
})

test_that("boe_consumer_credit() type filter works", {
  skip_on_cran()
  skip_if_offline()

  out <- boe_consumer_credit(type = "credit_card", from = "2024-01-01", to = "2024-06-30")
  expect_true(all(out$type == "credit_card"))
})
