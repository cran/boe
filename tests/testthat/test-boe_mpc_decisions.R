# Tests for boe_mpc_decisions().

test_that("boe_mpc_decisions returns the expected schema", {
  testthat::skip_on_cran()
  testthat::skip_if_offline()

  op <- options(boe.cache_dir = tempfile("boe_mpc_dec_"))
  on.exit(options(op), add = TRUE)

  out <- boe_mpc_decisions(from = "2020-01-01", to = "2024-12-31")

  expect_s3_class(out, "boe_tbl")
  expected_cols <- c("date", "new_rate_pct", "prev_rate_pct",
                     "change_bps", "direction")
  expect_true(all(expected_cols %in% names(out)))
  expect_true(all(out$direction %in% c("hike", "cut")))
  expect_true(all(is.finite(out$change_bps)))
  expect_true(all(out$change_bps != 0L))
  expect_equal(out$new_rate_pct - out$prev_rate_pct,
               out$change_bps / 100, tolerance = 1e-6)

  q <- attr(out, "boe_query")
  expect_equal(q$function_name, "boe_mpc_decisions")
})

test_that("boe_mpc_decisions captures known events (March 2020 cut)", {
  testthat::skip_on_cran()
  testthat::skip_if_offline()

  op <- options(boe.cache_dir = tempfile("boe_mpc_known_"))
  on.exit(options(op), add = TRUE)

  out <- boe_mpc_decisions(from = "2020-03-01", to = "2020-03-31")
  expect_gt(nrow(out), 0L)
  expect_true(all(out$direction == "cut"))
})
