# Anderson-Sleath yield curve archive helpers.
#
# The BoE publishes one zip per (curve, frequency) combination at fixed URLs.
# Each zip contains 3 Excel workbooks split by period (e.g. 1970-2015,
# 2016-2024, 2025-present), each with the same internal layout. Older real
# and OIS curves start later (real ~1985, OIS ~2009), so the archive zips
# may contain only 2 workbooks for those.

#' Yield-curve archive zip URLs (5 curves x 2 frequencies = 10 entries)
#' @noRd
yield_archive_registry <- function() {
  base <- "https://www.bankofengland.co.uk/-/media/boe/files/statistics/yield-curves"
  list(
    daily = list(
      nominal   = sprintf("%s/glcnominalddata.zip",   base),
      real      = sprintf("%s/glcrealddata.zip",      base),
      inflation = sprintf("%s/glcinflationddata.zip", base),
      ois       = sprintf("%s/oisddata.zip",          base),
      blc       = sprintf("%s/blcnomddata.zip",       base)
    ),
    monthly = list(
      nominal   = sprintf("%s/glcnominalmonthedata.zip",   base),
      real      = sprintf("%s/glcrealmonthedata.zip",      base),
      inflation = sprintf("%s/glcinflationmonthedata.zip", base),
      ois       = sprintf("%s/oismonthedata.zip",          base),
      blc       = sprintf("%s/blcnominalmonthedata.zip",   base)
    )
  )
}

#' Look up the archive zip URL for a (curve, frequency) pair
#' @noRd
yield_archive_url <- function(curve, frequency) {
  reg <- yield_archive_registry()
  if (is.null(reg[[frequency]][[curve]])) {
    cli::cli_abort(c(
      "No archive registered for curve={.val {curve}} frequency={.val {frequency}}.",
      "i" = "Valid curves: nominal, real, inflation, ois, blc."
    ))
  }
  reg[[frequency]][[curve]]
}

#' Download a yield-curve archive zip with a long cache TTL.
#'
#' Archive zips are stable historical artefacts; the BoE only revises them
#' when methodology updates land. A 30-day TTL (720 hours) is a reasonable
#' default. The latest-month zip used by `download_yield_zip()` keeps its
#' shorter 24-hour TTL.
#'
#' @noRd
download_yield_archive <- function(curve, frequency,
                                   cache       = TRUE,
                                   cache_ttl_h = 720) {
  url <- yield_archive_url(curve, frequency)

  cache_dir <- boe_cache_dir()
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  cache_file <- file.path(
    cache_dir,
    sprintf("yield-archive-%s-%s.zip", curve, frequency)
  )

  if (cache && file.exists(cache_file)) {
    age_h <- as.numeric(difftime(Sys.time(),
                                 file.info(cache_file)$mtime,
                                 units = "hours"))
    if (age_h < cache_ttl_h) {
      cli::cli_progress_step(
        "Using cached {curve} {frequency} yield-curve archive"
      )
      return(list(path = cache_file, url = url))
    }
  }

  cli::cli_progress_step(
    "Downloading {curve} {frequency} yield-curve archive from Bank of England"
  )

  tryCatch(
    httr2::request(url) |>
      httr2::req_user_agent("boe R package (https://github.com/charlescoverdale/boe)") |>
      httr2::req_timeout(300) |>
      httr2::req_retry(
        max_tries    = 3,
        is_transient = function(resp) httr2::resp_status(resp) %in% c(429L, 503L)
      ) |>
      httr2::req_perform(path = cache_file),
    error = function(e) {
      if (file.exists(cache_file)) unlink(cache_file)
      cli::cli_abort(c(
        "Download failed for {.val {url}}.",
        "i" = "Check your internet connection.",
        "x" = conditionMessage(e)
      ))
    }
  )

  list(path = cache_file, url = url)
}

#' Extract every Excel workbook in an archive zip that matches a curve.
#'
#' Archive zips contain multiple per-period workbooks (e.g. "1970 to 2015",
#' "2016 to 2024", "2025 to present") all with the same layout. We extract
#' them all and let the parser concatenate.
#'
#' @noRd
extract_archive_excels <- function(zip_path, curve, frequency) {
  files_in_zip <- utils::unzip(zip_path, list = TRUE)$Name

  freq_pattern <- if (frequency == "daily") "daily" else "month end"
  curve_pattern <- switch(curve,
    nominal   = "GLC Nominal",
    real      = "GLC Real",
    inflation = "GLC Inflation",
    ois       = "OIS",
    blc       = "BLC Nominal"
  )

  candidates <- files_in_zip[
    grepl(curve_pattern, files_in_zip, fixed = TRUE) &
    grepl(freq_pattern, files_in_zip, ignore.case = TRUE) &
    grepl("\\.xlsx?$", files_in_zip, ignore.case = TRUE)
  ]

  if (length(candidates) == 0L) {
    cli::cli_abort(c(
      "Could not find any {.val {curve}} {.val {frequency}} workbooks in archive.",
      "i" = "Files in archive: {.val {files_in_zip}}"
    ))
  }

  out_dir <- tempfile("boe_yield_archive_")
  dir.create(out_dir, recursive = TRUE)
  utils::unzip(zip_path,
               files     = candidates,
               exdir     = out_dir,
               junkpaths = TRUE)
  file.path(out_dir, basename(candidates))
}
