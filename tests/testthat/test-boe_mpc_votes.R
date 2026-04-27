# Tests for boe_mpc_votes() (parses BoE mpcvoting.xlsx).

test_that("boe_mpc_votes returns the expected schema", {
  testthat::skip_on_cran()
  testthat::skip_if_offline()
  testthat::skip_if_not_installed("readxl")

  op <- options(boe.cache_dir = tempfile("boe_mpc_votes_"))
  on.exit(options(op), add = TRUE)

  out <- boe_mpc_votes()

  expect_s3_class(out, "boe_tbl")
  expected_cols <- c("date", "member", "member_vote_pct",
                     "decision_pct", "dissent")
  expect_true(all(expected_cols %in% names(out)))
  expect_gt(nrow(out), 100L)
  expect_true(all(is.finite(out$member_vote_pct)))
  expect_true(all(is.finite(out$decision_pct)))
  expect_true(is.logical(out$dissent))
  expect_true(all(out$date >= as.Date("1997-06-01")))

  q <- attr(out, "boe_query")
  expect_equal(q$function_name, "boe_mpc_votes")
})
