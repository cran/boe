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

test_that("boe_consumer_credit() defaults to the excl-student-loans measure", {
  skip_on_cran()
  skip_if_offline()

  out <- boe_consumer_credit(from = "2024-01-01", to = "2024-06-30")
  codes <- attr(out, "boe_query")$series_codes
  expect_setequal(codes, c("LPMBI2O", "LPMVZRJ", "LPMB4TS"))

  # Components sum to the total (all three are seasonally adjusted on
  # the same basis, so the identity holds exactly).
  wide <- reshape(as.data.frame(out), idvar = "date", timevar = "type",
                  direction = "wide")
  expect_equal(wide$amount_gbp_m.credit_card + wide$amount_gbp_m.other,
               wide$amount_gbp_m.total)
})

test_that("boe_consumer_credit(include_student_loans = TRUE) uses the annual-update codes", {
  skip_on_cran()
  skip_if_offline()

  out <- boe_consumer_credit(type = "total", from = "2024-01-01",
                             to = "2024-06-30",
                             include_student_loans = TRUE)
  codes <- attr(out, "boe_query")$series_codes
  expect_identical(unname(codes), "LPMVZRI")

  # The including-student-loans total is strictly larger than the
  # headline excluding measure.
  excl <- boe_consumer_credit(type = "total", from = "2024-01-01",
                              to = "2024-06-30")
  expect_true(mean(out$amount_gbp_m) > mean(excl$amount_gbp_m))
})
