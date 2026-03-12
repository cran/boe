test_that("boe_mortgage_approvals() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- boe_mortgage_approvals(from = "2024-01-01", to = "2024-06-30")

  expect_s3_class(out, "data.frame")
  expect_named(out, c("date", "approvals"))
  expect_s3_class(out$date, "Date")
  expect_type(out$approvals, "double")
  expect_true(nrow(out) > 0)
})
