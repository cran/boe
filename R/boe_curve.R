#' Download the BoE Anderson-Sleath fitted yield curves
#'
#' Downloads the Bank of England's published fitted yield curves at
#' all maturities (typically 0.5 to 25 or 40 years) using the Anderson
#' and Sleath (2001) smoothing methodology. Returns the latest month's
#' daily data covering the four published curves: nominal gilt, real
#' (index-linked) gilt, implied inflation, and overnight index swap
#' (OIS).
#'
#' Coverage is limited to the latest published month. Historical archive
#' loading is planned for a subsequent release.
#'
#' @param curve Character. Which curve to fetch. One of `"nominal"`,
#'   `"real"`, `"inflation"`, or `"ois"`. Defaults to `"nominal"`.
#' @param measure Character. `"spot"` (default) or `"forward"`.
#' @param cache Logical. Use cached download if available and less
#'   than 24 hours old (default `TRUE`).
#'
#' @return A `boe_tbl` data frame with columns:
#'   \describe{
#'     \item{date}{Date. Observation date.}
#'     \item{maturity_years}{Numeric. Maturity in years.}
#'     \item{rate_pct}{Numeric. Yield or implied rate (percent).}
#'   }
#'
#' @details
#' Requires the \pkg{readxl} package. The data is published as an
#' Excel workbook inside a zip archive at
#' \url{https://www.bankofengland.co.uk/statistics/yield-curves}.
#'
#' @references
#' Anderson, N. and Sleath, J. (2001). New estimates of the UK real
#' and nominal yield curves. \emph{Bank of England Working Paper No.
#' 126.} \url{https://www.bankofengland.co.uk/working-paper/2001/new-estimates-of-the-uk-real-and-nominal-yield-curves}
#'
#' @source <https://www.bankofengland.co.uk/statistics/yield-curves>
#'
#' @examples
#' \donttest{
#' if (requireNamespace("readxl", quietly = TRUE)) {
#'   op <- options(boe.cache_dir = tempdir())
#'   # Latest nominal spot curve at all maturities
#'   curve <- boe_curve(curve = "nominal", measure = "spot")
#'   head(curve)
#'   options(op)
#' }
#' }
#'
#' @family interest rates
#' @export
boe_curve <- function(curve   = c("nominal", "real", "inflation", "ois"),
                      measure = c("spot", "forward"),
                      cache   = TRUE) {

  curve   <- match.arg(curve)
  measure <- match.arg(measure)

  if (!requireNamespace("readxl", quietly = TRUE)) {
    cli::cli_abort(c(
      "Package {.pkg readxl} is required to parse BoE yield curve data.",
      "i" = "Install it with {.code install.packages(\"readxl\")}."
    ))
  }

  zip_path <- download_yield_zip(cache = cache)
  xls_path <- extract_yield_excel(zip_path, curve)
  parse_yield_excel(xls_path, measure = measure, curve = curve)
}


#' @noRd
yield_zip_url <- function() {
  "https://www.bankofengland.co.uk/-/media/boe/files/statistics/yield-curves/latest-yield-curve-data.zip"
}


#' Download the BoE yield curve zip archive (latest month)
#' @noRd
download_yield_zip <- function(cache = TRUE) {
  cache_dir <- boe_cache_dir()
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  cache_file <- file.path(cache_dir, "yield-curve-latest.zip")

  if (cache && file.exists(cache_file)) {
    age_h <- as.numeric(difftime(Sys.time(),
                                 file.info(cache_file)$mtime,
                                 units = "hours"))
    if (age_h < 24) {
      cli::cli_progress_step("Using cached yield curve archive")
      return(cache_file)
    }
  }

  cli::cli_progress_step("Downloading yield curve archive from Bank of England")

  tryCatch(
    httr2::request(yield_zip_url()) |>
      httr2::req_user_agent("boe R package (https://github.com/charlescoverdale/boe)") |>
      httr2::req_timeout(180) |>
      httr2::req_retry(
        max_tries    = 3,
        is_transient = function(resp) httr2::resp_status(resp) %in% c(429L, 503L)
      ) |>
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


#' Extract a single curve Excel file from the zip archive
#' @noRd
extract_yield_excel <- function(zip_path, curve) {
  files_in_zip <- utils::unzip(zip_path, list = TRUE)$Name

  pattern <- switch(curve,
    nominal   = "GLC Nominal",
    real      = "GLC Real",
    inflation = "GLC Inflation",
    ois       = "OIS"
  )

  candidates <- files_in_zip[
    grepl(pattern, files_in_zip, fixed = TRUE) &
    grepl("daily", files_in_zip, ignore.case = TRUE) &
    grepl("\\.xlsx?$", files_in_zip, ignore.case = TRUE)
  ]

  if (length(candidates) == 0L) {
    cli::cli_abort(c(
      "Could not find {.val {curve}} daily Excel file in BoE archive.",
      "i" = "Files in archive: {.val {files_in_zip}}"
    ))
  }

  out_dir <- tempfile("boe_yield_")
  dir.create(out_dir, recursive = TRUE)
  utils::unzip(zip_path,
               files     = candidates[1L],
               exdir     = out_dir,
               junkpaths = TRUE)
  file.path(out_dir, basename(candidates[1L]))
}


#' Parse a single curve Excel file
#'
#' BoE yield-curve workbooks share a common structure:
#' the main sheets are named like "4. spot curve" and "2. fwd curve".
#' Row 4 contains the maturity row (years), with maturities starting
#' in column 2. Data rows begin at row 6, with column 1 holding an
#' Excel serial date and remaining columns holding the rate at each
#' maturity (in percent).
#'
#' @noRd
parse_yield_excel <- function(path, measure, curve) {
  sheets <- readxl::excel_sheets(path)

  pattern <- if (measure == "spot") "spot curve$" else "fwd curve$"
  hits <- grep(pattern, sheets, ignore.case = TRUE)
  if (length(hits) == 0L) {
    cli::cli_abort(c(
      "Could not find a {.val {measure}} curve sheet.",
      "i" = "Available sheets: {.val {sheets}}"
    ))
  }
  sheet_name <- sheets[hits[1L]]

  raw <- suppressMessages(
    readxl::read_excel(path, sheet = sheet_name, col_names = FALSE)
  )
  raw <- as.data.frame(raw, stringsAsFactors = FALSE)

  if (nrow(raw) < 6L || ncol(raw) < 2L) {
    cli::cli_abort("Yield curve sheet {.val {sheet_name}} is too small to parse.")
  }

  maturities <- suppressWarnings(as.numeric(unlist(raw[4L, -1L])))
  good_cols  <- !is.na(maturities)
  if (!any(good_cols)) {
    cli::cli_abort("Could not detect maturities in row 4 of {.val {sheet_name}}.")
  }
  maturities <- maturities[good_cols]

  body <- raw[6L:nrow(raw), c(TRUE, good_cols), drop = FALSE]
  date_serials <- suppressWarnings(as.numeric(body[[1L]]))
  body <- body[!is.na(date_serials), , drop = FALSE]
  date_serials <- date_serials[!is.na(date_serials)]

  if (length(date_serials) == 0L) {
    cli::cli_abort("No data rows found in {.val {sheet_name}}.")
  }

  dates <- as.Date(date_serials, origin = "1899-12-30")

  vals <- suppressWarnings(matrix(
    as.numeric(as.matrix(body[, -1L, drop = FALSE])),
    nrow = nrow(body),
    ncol = length(maturities)
  ))

  long <- data.frame(
    date           = rep(dates, times = ncol(vals)),
    maturity_years = rep(maturities, each = nrow(vals)),
    rate_pct       = as.numeric(vals),
    stringsAsFactors = FALSE
  )
  long <- long[!is.na(long$rate_pct), , drop = FALSE]
  long <- long[order(long$date, long$maturity_years), , drop = FALSE]
  rownames(long) <- NULL

  cli::cli_progress_done()
  new_boe_tbl(long, query = list(
    series_codes  = sprintf("AS_%s_%s", toupper(curve), toupper(measure)),
    from          = min(long$date),
    to            = max(long$date),
    frequency     = "daily",
    function_name = "boe_curve"
  ))
}
