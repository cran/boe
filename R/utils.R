# utils.R — internal helpers for BoE API access + caching

BOE_API <- "https://www.bankofengland.co.uk/boeapps/database/_iadb-fromshowcolumns.asp"

#' Fetch series from the Bank of England Interactive Statistical Database
#'
#' @param series_codes Character vector of BoE series codes.
#' @param from Date or character. Start date (inclusive).
#' @param to Date or character. End date (inclusive). Defaults to today.
#' @param cache Logical. Use cached response if available?
#' @return A data frame with columns: date, code, value.
#' @noRd
boe_fetch <- function(series_codes, from, to = Sys.Date(), cache = TRUE) {
  from_str <- format_boe_date(from)
  to_str   <- format_boe_date(to)
  codes    <- paste(series_codes, collapse = ",")

  url <- paste0(
    BOE_API,
    "?csv.x=yes",
    "&Datefrom=", from_str,
    "&Dateto=", to_str,
    "&SeriesCodes=", codes,
    "&UsingCodes=Y",
    "&CSVF=TN"
  )

  path <- download_cached_boe(url, cache = cache)
  parse_boe_csv(path, series_codes)
}

#' Format a date for the BoE API (DD/Mon/YYYY)
#' @noRd
format_boe_date <- function(x) {
  if (is.character(x)) {
    x <- as.Date(x)
  }
  format(x, "%d/%b/%Y")
}

#' Parse BoE CSV response into a tidy data frame
#' @noRd
parse_boe_csv <- function(path, expected_codes) {
  lines <- readLines(path, warn = FALSE)

  # BoE returns an HTML error page for invalid series

  if (length(lines) == 0 || any(grepl("<title>Error</title>", lines, ignore.case = TRUE))) {
    cli::cli_abort(c(
      "The Bank of England returned an error.",
      "i" = "Check that your series codes are valid: {.val {expected_codes}}"
    ))
  }

  # Filter out blank lines
  lines <- lines[nzchar(trimws(lines))]
  if (length(lines) < 2) {
    cli::cli_abort("No data returned for series: {.val {expected_codes}}")
  }

  raw <- utils::read.csv(text = paste(lines, collapse = "\n"),
                          stringsAsFactors = FALSE, check.names = FALSE)

  if (nrow(raw) == 0) {
    cli::cli_abort("No data returned for series: {.val {expected_codes}}")
  }

  # First column is DATE; remaining columns are series codes
  date_col <- raw[[1]]
  dates    <- as.Date(trimws(date_col), format = "%d %b %Y")

  code_cols <- names(raw)[-1]
  results <- list()

  for (col in code_cols) {
    vals <- suppressWarnings(as.numeric(raw[[col]]))
    results[[length(results) + 1]] <- data.frame(
      date  = dates,
      code  = col,
      value = vals,
      stringsAsFactors = FALSE
    )
  }

  out <- do.call(rbind, results)
  # Drop rows with NA dates or values (from mixed-frequency gaps)
  out <- out[!is.na(out$date) & !is.na(out$value), ]
  rownames(out) <- NULL
  out
}

#' Download a URL with local caching
#' @noRd
download_cached_boe <- function(url, cache = TRUE) {
  cache_dir  <- tools::R_user_dir("boe", "cache")
  ext        <- ".csv"
  cache_file <- file.path(cache_dir, paste0(digest_url_boe(url), ext))

  if (cache && file.exists(cache_file)) {
    cli::cli_progress_step("Using cached data")
    return(cache_file)
  }

  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  cli::cli_progress_step("Downloading from Bank of England")

  tryCatch(
    httr2::request(url) |>
      httr2::req_timeout(60) |>
      httr2::req_perform(path = cache_file),
    error = function(e) {
      if (file.exists(cache_file)) unlink(cache_file)
      cli::cli_abort(c(
        "Download failed.",
        "i" = "Check your internet connection.",
        "x" = conditionMessage(e)
      ))
    }
  )

  cache_file
}

#' Simple URL hash for cache filenames
#' @noRd
digest_url_boe <- function(url) {
  chars    <- utf8ToInt(url)
  weights  <- seq_along(chars)
  checksum <- sum(as.numeric(chars) * weights) %% (2^31 - 1)
  sprintf("%010.0f_%04d", as.numeric(checksum), nchar(url) %% 10000L)
}

#' Validate and parse date arguments
#' @noRd
parse_date_arg <- function(x, arg_name = "from") {
  if (is.null(x)) return(NULL)
  if (inherits(x, "Date")) return(x)
  d <- tryCatch(as.Date(x), error = function(e) NA)
  if (is.na(d)) {
    cli::cli_abort("{.arg {arg_name}} must be a valid date (e.g. {.val 2020-01-01}).")
  }
  d
}
