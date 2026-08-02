test_that("boe_get() rejects empty series_codes", {
  expect_error(boe_get(character(0)), "series_codes")
})

test_that("boe_get() rejects non-character series_codes", {
 expect_error(boe_get(123), "series_codes")
})

test_that("boe_get() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- boe_get("IUDBEDR", from = "2024-01-01", to = "2024-01-31")

  expect_s3_class(out, "data.frame")
  expect_named(out, c("date", "code", "value"))
  expect_s3_class(out$date, "Date")
  expect_type(out$code, "character")
  expect_type(out$value, "double")
  expect_true(nrow(out) > 0)
  expect_true(all(out$code == "IUDBEDR"))
})

test_that("boe_get() handles multiple series", {
  skip_on_cran()
  skip_if_offline()

  out <- boe_get(c("IUDBEDR", "IUDSOIA"), from = "2024-01-01", to = "2024-01-31")

  expect_true(all(c("IUDBEDR", "IUDSOIA") %in% out$code))
})

test_that("cached IADB responses expire after the boe.cache_ttl_h TTL", {
  skip_on_cran()
  skip_if_offline()

  op <- options(boe.cache_dir = tempfile("boe_ttl_"))
  on.exit(options(op), add = TRUE)

  # Prime the cache, then confirm a repeat call reuses the file.
  out1 <- boe_get("IUDBEDR", from = "2024-01-01", to = "2024-01-31")
  files <- list.files(getOption("boe.cache_dir"), full.names = TRUE)
  expect_length(files, 1L)
  mtime1 <- file.info(files)$mtime
  boe_get("IUDBEDR", from = "2024-01-01", to = "2024-01-31")
  expect_equal(file.info(files)$mtime, mtime1)

  # Backdate the cache file beyond the TTL: the next call re-downloads.
  Sys.setFileTime(files, Sys.time() - 40 * 24 * 3600)
  boe_get("IUDBEDR", from = "2024-01-01", to = "2024-01-31")
  expect_gt(as.numeric(file.info(files)$mtime),
            as.numeric(Sys.time()) - 3600)

  # An infinite TTL freezes the cache.
  options(boe.cache_ttl_h = Inf)
  on.exit(options(boe.cache_ttl_h = NULL), add = TRUE)
  Sys.setFileTime(files, Sys.time() - 40 * 24 * 3600)
  mtime_old <- file.info(files)$mtime
  boe_get("IUDBEDR", from = "2024-01-01", to = "2024-01-31")
  expect_equal(file.info(files)$mtime, mtime_old)
})
