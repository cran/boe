# Tests for boe_cache_info().

test_that("boe_cache_info() reports an empty cache without error", {
  d <- tempfile("boe_cache_empty_")
  dir.create(d)
  op <- options(boe.cache_dir = d)
  on.exit(options(op), add = TRUE)

  info <- suppressMessages(boe_cache_info())
  expect_equal(info$path, d)
  expect_equal(info$n_files, 0L)
  expect_equal(info$total_size_bytes, 0)
  expect_true(is.na(info$oldest))
  expect_true(is.na(info$newest))
})

test_that("boe_cache_info() reports a populated cache", {
  d <- tempfile("boe_cache_pop_")
  dir.create(d)
  writeLines("hello", file.path(d, "a.csv"))
  writeLines("world world", file.path(d, "b.csv"))
  op <- options(boe.cache_dir = d)
  on.exit(options(op), add = TRUE)

  info <- suppressMessages(boe_cache_info())
  expect_equal(info$n_files, 2L)
  expect_gt(info$total_size_bytes, 0)
  expect_s3_class(info$oldest, "POSIXct")
  expect_s3_class(info$newest, "POSIXct")
})

test_that("boe_cache_info() handles a non-existent cache directory", {
  d <- tempfile("boe_cache_missing_")
  op <- options(boe.cache_dir = d)
  on.exit(options(op), add = TRUE)

  info <- suppressMessages(boe_cache_info())
  expect_equal(info$path, d)
  expect_equal(info$n_files, 0L)
})

test_that("format_cache_size handles common ranges", {
  expect_equal(format_cache_size(0), "0 B")
  expect_equal(format_cache_size(1023), "1023 B")
  expect_equal(format_cache_size(2048), "2.0 KB")
  expect_equal(format_cache_size(5 * 1024^2), "5.0 MB")
  expect_equal(format_cache_size(2 * 1024^3), "2.0 GB")
})
