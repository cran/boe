#' Download BoE Anderson-Sleath fitted yield curves
#'
#' Downloads the Bank of England's published fitted yield curves at all
#' maturities (typically 0.5 to 25 or 40 years) using the Anderson and
#' Sleath (2001) smoothing methodology. Five curves are supported:
#' nominal gilt, real (index-linked) gilt, implied inflation, overnight
#' index swap (OIS), and the commercial bank liability curve (BLC).
#'
#' Each curve is published in two segments. The default
#' `segment = "standard"` returns the full maturity spectrum in half-year
#' steps (0.5 years out to 25 or 40). `segment = "short"` returns the
#' short end of the curve in monthly steps (one month out to five years),
#' which the Bank fits separately and which is the segment most relevant
#' to near-term policy-rate and money-market analysis. The short end is
#' available for every curve in the latest month, and historically wherever
#' the BoE published it (e.g. OIS short-end data begins later than the OIS
#' standard curve); periods without a short-end sheet are skipped.
#'
#' By default (`from = NULL`, `to = NULL`, `frequency = "daily"`) returns
#' the latest published month of daily data, matching the behaviour of
#' earlier releases of this package. Setting `from`, `to`, or `frequency`
#' switches to the BoE's full archive, which goes back to 1979 for nominal
#' gilts, 1985 for real, 2000 for BLC, and 2009 for OIS.
#'
#' @param curve Character. Which curve to fetch. One of `"nominal"`,
#'   `"real"`, `"inflation"`, `"ois"`, or `"blc"`. Defaults to
#'   `"nominal"`. The commercial bank liability curve (`"blc"`) is only
#'   published in the historical archive zip, so requests for it always
#'   route through the archive path regardless of `from` / `to`.
#' @param measure Character. `"spot"` (default) or `"forward"`.
#' @param segment Character. `"standard"` (default) for the full maturity
#'   spectrum in half-year steps, or `"short"` for the separately fitted
#'   short end in monthly steps (one month to five years).
#' @param frequency Character. `"daily"` (default) or `"monthly"`. Monthly
#'   archives are end-of-month observations and are much smaller files.
#' @param from,to Date or character ("YYYY-MM-DD"). Optional inclusive
#'   bounds. When either is set, the function uses the BoE archive zip
#'   (multi-decade history) and filters by date.
#' @param cache Logical. Use cached download if available and within the
#'   TTL window (default `TRUE`).
#' @param cache_ttl_h Numeric. Cache time-to-live in hours. When `NULL`
#'   (default) the TTL is 24 hours for the latest-month zip and 720 hours
#'   (30 days) for archive zips.
#'
#' @return A `boe_tbl` data frame with columns:
#'   \describe{
#'     \item{date}{Date. Observation date.}
#'     \item{maturity_years}{Numeric. Maturity in years.}
#'     \item{rate_pct}{Numeric. Yield or implied rate (percent).}
#'   }
#'
#' @details
#' Requires the \pkg{readxl} package. Data is published as Excel workbooks
#' inside zip archives at
#' \url{https://www.bankofengland.co.uk/statistics/yield-curves}. Each
#' archive zip contains multiple per-period workbooks; this function
#' concatenates them transparently.
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
#'   # Latest nominal spot curve at all maturities (default behaviour)
#'   curve <- boe_curve(curve = "nominal", measure = "spot")
#'   head(curve)
#'
#'   # Short end of the nominal forward curve (monthly steps to 5 years)
#'   se <- boe_curve(curve = "nominal", measure = "forward",
#'                   segment = "short")
#'   range(se$maturity_years)
#'   options(op)
#' }
#' }
#'
#' \dontrun{
#' # Historical archive: multi-decade downloads, so not run automatically.
#' # 10-year nominal spot back to 2010:
#' long <- boe_curve(curve = "nominal", from = "2010-01-01")
#'
#' # End-of-month real curve since 1990:
#' real_m <- boe_curve(curve = "real", frequency = "monthly",
#'                     from = "1990-01-01")
#' }
#'
#' @family interest rates
#' @export
boe_curve <- function(curve       = c("nominal", "real", "inflation", "ois", "blc"),
                      measure     = c("spot", "forward"),
                      segment     = c("standard", "short"),
                      frequency   = c("daily", "monthly"),
                      from        = NULL,
                      to          = NULL,
                      cache       = TRUE,
                      cache_ttl_h = NULL) {

  curve     <- match.arg(curve)
  measure   <- match.arg(measure)
  segment   <- match.arg(segment)
  frequency <- match.arg(frequency)

  if (!requireNamespace("readxl", quietly = TRUE)) {
    cli::cli_abort(c(
      "Package {.pkg readxl} is required to parse BoE yield curve data.",
      "i" = "Install it with {.code install.packages(\"readxl\")}."
    ))
  }

  from_d <- parse_date_arg(from, "from")
  to_d   <- parse_date_arg(to,   "to")
  if (!is.null(from_d) && !is.null(to_d) && from_d > to_d) {
    cli::cli_abort("{.arg from} ({.val {from_d}}) must be before {.arg to} ({.val {to_d}}).")
  }

  # BLC is only published in the archive zips, not in latest-yield-curve-data.zip,
  # so always route BLC through the archive path.
  use_archive <- curve == "blc" ||
                 !is.null(from_d) || !is.null(to_d) ||
                 frequency != "daily"

  if (use_archive) {
    ttl <- cache_ttl_h %||% 720
    arc <- download_yield_archive(curve, frequency,
                                  cache = cache, cache_ttl_h = ttl)
    xls_paths <- extract_archive_excels(arc$path, curve, frequency)
    out <- parse_yield_workbooks(xls_paths, measure = measure, curve = curve,
                                 segment = segment)
    source_url   <- arc$url
    source_label <- "archive"
  } else {
    ttl <- cache_ttl_h %||% 24
    zip_path <- download_yield_zip(cache = cache, cache_ttl_h = ttl)
    xls_path <- extract_yield_excel(zip_path, curve)
    out <- parse_yield_workbooks(xls_path, measure = measure, curve = curve,
                                 segment = segment)
    source_url   <- yield_zip_url()
    source_label <- "latest"
  }

  if (!is.null(from_d)) out <- out[out$date >= from_d, , drop = FALSE]
  if (!is.null(to_d))   out <- out[out$date <= to_d,   , drop = FALSE]
  rownames(out) <- NULL

  if (nrow(out) == 0L) {
    cli::cli_warn(c(
      "No observations after applying date filter.",
      "i" = "Requested {.val {from_d}} to {.val {to_d}}."
    ))
  }

  query <- list(
    series_codes  = sprintf("AS_%s_%s%s", toupper(curve), toupper(measure),
                            if (segment == "short") "_SHORT" else ""),
    from          = if (nrow(out)) min(out$date) else from_d,
    to            = if (nrow(out)) max(out$date) else to_d,
    frequency     = frequency,
    segment       = segment,
    function_name = "boe_curve",
    source_url    = source_url,
    source        = source_label
  )

  cli::cli_progress_done()
  new_boe_tbl(out, query = query)
}


#' @noRd
yield_zip_url <- function() {
  "https://www.bankofengland.co.uk/-/media/boe/files/statistics/yield-curves/latest-yield-curve-data.zip"
}


#' Download the latest-month yield curve zip
#' @noRd
download_yield_zip <- function(cache = TRUE, cache_ttl_h = 24) {
  cache_dir <- boe_cache_dir()
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  cache_file <- file.path(cache_dir, "yield-curve-latest.zip")

  if (cache && file.exists(cache_file)) {
    age_h <- as.numeric(difftime(Sys.time(),
                                 file.info(cache_file)$mtime,
                                 units = "hours"))
    if (age_h < cache_ttl_h) {
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


#' Extract a single curve Excel file from the latest-month zip
#'
#' The latest-month zip contains daily files for every curve type. Pick the
#' one matching `curve`.
#'
#' @noRd
extract_yield_excel <- function(zip_path, curve) {
  files_in_zip <- utils::unzip(zip_path, list = TRUE)$Name

  pattern <- switch(curve,
    nominal   = "GLC Nominal",
    real      = "GLC Real",
    inflation = "GLC Inflation",
    ois       = "OIS",
    blc       = "BLC Nominal"
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


#' Parse one or more BoE yield-curve workbooks and concatenate.
#'
#' Each workbook has the same internal structure regardless of period:
#' standard sheets named like "4. spot curve" / "2. fwd curve" and
#' short-end sheets named like "3. spot, short end" / "1. fwds, short end"
#' (older workbooks infix the curve name, e.g. "4. nominal spot curve").
#' The maturity row is normally row 4 (years), but older workbooks
#' (pre-2007) sometimes shift it. We use content-based detection: scan
#' rows 3 to 6 for the row whose first non-empty entries are monotonically
#' increasing positive numerics.
#'
#' @param paths Character vector of one or more workbook paths.
#' @param segment `"standard"` or `"short"`; selects which curve sheet to read.
#' @noRd
parse_yield_workbooks <- function(paths, measure, curve, segment = "standard") {
  parts <- lapply(paths, parse_yield_excel_one,
                  measure = measure, curve = curve, segment = segment)
  parts <- parts[vapply(parts, function(p) !is.null(p) && nrow(p) > 0L, logical(1))]

  if (length(parts) == 0L) {
    if (segment == "short") {
      cli::cli_abort(c(
        "No short-end {.val {measure}} data found for the {.val {curve}} curve.",
        "i" = "The BoE does not publish a short end for every curve in every period."
      ))
    }
    cli::cli_abort("Could not parse any data from {.val {curve}} workbooks.")
  }

  out <- do.call(rbind, parts)
  out <- out[!duplicated(out[, c("date", "maturity_years")]), , drop = FALSE]
  out <- out[order(out$date, out$maturity_years), , drop = FALSE]
  rownames(out) <- NULL
  out
}


#' Parse a single yield-curve workbook
#' @noRd
parse_yield_excel_one <- function(path, measure, curve, segment = "standard") {
  sheets <- readxl::excel_sheets(path)
  sheets_trim <- trimws(sheets)

  pattern <- yield_sheet_pattern(measure, segment)
  hits <- grep(pattern, sheets_trim, ignore.case = TRUE)
  if (length(hits) == 0L) {
    # A missing short-end sheet is expected for periods/curves where the
    # BoE never published one (e.g. early OIS); skip the workbook quietly
    # and let the caller decide if *no* workbook yielded data. A missing
    # standard sheet is unexpected, so surface it.
    if (segment != "short") {
      cli::cli_warn(c(
        "Could not find a {.val {measure}} curve sheet in {.file {basename(path)}}.",
        "i" = "Available sheets: {.val {sheets}}"
      ))
    }
    return(NULL)
  }
  sheet_name <- sheets[hits[1L]]

  raw <- suppressMessages(
    readxl::read_excel(path, sheet = sheet_name, col_names = FALSE)
  )
  raw <- as.data.frame(raw, stringsAsFactors = FALSE)

  if (nrow(raw) < 6L || ncol(raw) < 2L) {
    cli::cli_warn("Sheet {.val {sheet_name}} in {.file {basename(path)}} is too small to parse.")
    return(NULL)
  }

  mat_row <- detect_maturity_row(raw)
  if (is.na(mat_row)) {
    cli::cli_warn("Could not detect maturity row in {.file {basename(path)}}.")
    return(NULL)
  }
  maturities <- suppressWarnings(as.numeric(unlist(raw[mat_row, -1L])))
  good_cols  <- !is.na(maturities) & maturities > 0
  if (!any(good_cols)) return(NULL)
  maturities <- maturities[good_cols]

  data_start <- mat_row + 2L
  body <- raw[data_start:nrow(raw), c(TRUE, good_cols), drop = FALSE]

  date_col <- body[[1L]]
  if (inherits(date_col, "POSIXt") || inherits(date_col, "Date")) {
    dates <- as.Date(date_col)
    keep  <- !is.na(dates)
  } else {
    serials <- suppressWarnings(as.numeric(date_col))
    keep    <- !is.na(serials)
    dates   <- as.Date(serials, origin = "1899-12-30")
  }
  body  <- body[keep, , drop = FALSE]
  dates <- dates[keep]

  if (length(dates) == 0L) return(NULL)

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
  long[!is.na(long$rate_pct), , drop = FALSE]
}


#' Build the regex that selects a curve sheet by measure and segment.
#'
#' Sheet names are anchored at the end so the optional curve-name infix in
#' older workbooks (e.g. "4. nominal spot curve", "1. nominal fwds, short
#' end") still matches. Standard forward sheets are singular ("fwd curve")
#' while short-end forward sheets are plural ("fwds, short end"); the
#' patterns tolerate both and an optional comma.
#'
#' @noRd
yield_sheet_pattern <- function(measure, segment) {
  if (segment == "short") {
    if (measure == "spot") "spot,? short end$" else "fwds?,? short end$"
  } else {
    if (measure == "spot") "spot curve$" else "fwd curve$"
  }
}


#' Detect which row holds the maturity grid (years).
#'
#' Default fast path is row 4 (modern BoE workbooks). Fall back to
#' scanning rows 3 to 6 for the row whose first non-empty values are
#' increasing positive numerics starting near 0.5.
#'
#' @noRd
detect_maturity_row <- function(raw) {
  fast <- suppressWarnings(as.numeric(unlist(raw[4L, -1L])))
  if (sum(!is.na(fast) & fast > 0) >= 5L) return(4L)

  for (r in c(3L, 5L, 6L)) {
    if (r > nrow(raw)) next
    cand <- suppressWarnings(as.numeric(unlist(raw[r, -1L])))
    cand <- cand[!is.na(cand)]
    if (length(cand) >= 5L &&
        all(cand > 0) &&
        all(diff(cand[seq_len(min(length(cand), 10L))]) >= 0)) {
      return(r)
    }
  }
  NA_integer_
}


#' Null-coalescing operator
#' @noRd
`%||%` <- function(a, b) if (is.null(a)) b else a
