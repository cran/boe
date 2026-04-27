#' Monetary Policy Report forecast data
#'
#' Downloads the Bank of England's Monetary Policy Report (MPR) and
#' parses headline projections from the Projections Databank workbook.
#' Returns a long-format data frame where each row is one (publication
#' date, forecast horizon, series) triple.
#'
#' Coverage runs quarterly from November 2019 (when the report was
#' renamed from Inflation Report) to the latest published release.
#'
#' @param series Character vector. One or more of:
#'   `"cpi_inflation"`, `"gdp_growth"`, `"gdp_level"`,
#'   `"unemployment"`, `"bank_rate"`. Defaults to all five.
#' @param month Character. `"february"`, `"may"`, `"august"`, or
#'   `"november"`. If `NULL`, the most recent quarterly release is
#'   used.
#' @param year Integer. MPR year, 2019 or later. If `NULL`, the most
#'   recent quarterly release is used.
#' @param cache Logical. Use cached download if available (default
#'   `TRUE`). Older releases never change so the cache never expires;
#'   the latest release is refreshed if older than 24 hours.
#'
#' @return A `boe_tbl` data frame with columns:
#'   \describe{
#'     \item{date}{Date. Publication date of the MPR (start of quarter
#'       the report covers).}
#'     \item{horizon}{Character. Forecast horizon label (e.g. `"2026 Q1"`).}
#'     \item{horizon_date}{Date. Start of the forecast quarter.}
#'     \item{series}{Character. Series identifier (e.g. `"cpi_inflation"`).}
#'     \item{value}{Numeric. Forecast value (percent for rates and
#'       growth; index for `gdp_level`).}
#'   }
#'
#' @details
#' Requires the \pkg{readxl} package. The MPR is published as a zip
#' archive containing a Projections Databank workbook plus chart data
#' and slides; this function only reads the projection sheets.
#'
#' Each row of a projection sheet is one MPR publication; columns are
#' forecast quarters. The same publication therefore contributes
#' multiple rows here, one per forecast horizon.
#'
#' @source <https://www.bankofengland.co.uk/monetary-policy>
#'
#' @section Older releases:
#' Pre-2025 MPRs are packaged differently and do not contain a single
#' "Projections Databank" workbook. This function targets the post-2025
#' format and may error on older releases.
#'
#' @examples
#' \donttest{
#' if (requireNamespace("readxl", quietly = TRUE)) {
#'   op <- options(boe.cache_dir = tempdir())
#'
#'   # Latest CPI inflation projections
#'   cpi <- boe_mpr_forecasts(series = "cpi_inflation")
#'   head(cpi)
#'
#'   options(op)
#' }
#' }
#'
#' @family monetary policy
#' @seealso [boe_mpc_decisions()], [boe_mpc_votes()]
#' @export
boe_mpr_forecasts <- function(series = c("cpi_inflation", "gdp_growth",
                                         "gdp_level", "unemployment",
                                         "bank_rate"),
                              month  = NULL,
                              year   = NULL,
                              cache  = TRUE) {

  if (!requireNamespace("readxl", quietly = TRUE)) {
    cli::cli_abort(c(
      "Package {.pkg readxl} is required to parse MPR data.",
      "i" = "Install it with {.code install.packages(\"readxl\")}."
    ))
  }

  series_choices <- eval(formals()$series)
  if (missing(series)) {
    series <- series_choices
  } else {
    series <- match.arg(series, choices = series_choices, several.ok = TRUE)
  }

  release <- resolve_mpr_release(month = month, year = year)
  zip_path <- download_mpr_zip(release$month, release$year, cache = cache)
  xls_path <- extract_projections_databank(zip_path)

  parts <- lapply(series, function(s) {
    parse_projection_sheet(xls_path,
                           sheet_name  = mpr_sheet_for(s),
                           series_name = s)
  })
  out <- do.call(rbind, parts)
  out <- out[order(out$date, out$horizon_date, out$series), , drop = FALSE]
  rownames(out) <- NULL

  cli::cli_progress_done()
  new_boe_tbl(out, query = list(
    series_codes  = paste0("MPR_", toupper(series)),
    from          = min(out$date),
    to            = max(out$date),
    frequency     = "quarterly",
    function_name = "boe_mpr_forecasts",
    vintage       = sprintf("%s %d", release$month, release$year)
  ))
}


#' Map a friendly series name to the Projections Databank sheet name
#' @noRd
mpr_sheet_for <- function(series) {
  switch(series,
    cpi_inflation = "1. CPI inflation",
    gdp_growth    = "2. GDP growth",
    gdp_level     = "3. GDP level",
    unemployment  = "4. Unemployment",
    bank_rate     = "38. Bank Rate",
    cli::cli_abort("Unknown MPR series {.val {series}}.")
  )
}


#' Resolve the (month, year) of an MPR release
#'
#' If both NULL, returns the most recent quarterly release that is
#' likely already published. Buffer of 14 days inside the publication
#' month ensures we don't try to fetch a release before it's posted.
#' @noRd
resolve_mpr_release <- function(month = NULL, year = NULL,
                                today = Sys.Date()) {
  if (is.null(month) && is.null(year)) {
    return(latest_mpr_release(today))
  }
  if (is.null(month) || is.null(year)) {
    cli::cli_abort("Specify both {.arg month} and {.arg year}, or neither.")
  }
  month <- tolower(as.character(month))
  if (!month %in% c("february", "may", "august", "november")) {
    cli::cli_abort('{.arg month} must be one of "february", "may", "august", "november".')
  }
  year <- as.integer(year)
  if (year < 2019L) {
    cli::cli_abort("MPR coverage starts at November 2019. For earlier dates use the legacy Inflation Report.")
  }
  list(month = month, year = year)
}


#' @noRd
latest_mpr_release <- function(today = Sys.Date()) {
  yr  <- as.integer(format(today, "%Y"))
  mo  <- as.integer(format(today, "%m"))
  day <- as.integer(format(today, "%d"))

  q_months <- c(11L, 8L, 5L, 2L)
  q_names  <- c("november", "august", "may", "february")

  for (i in seq_along(q_months)) {
    q <- q_months[i]
    if (mo > q || (mo == q && day >= 14L)) {
      return(list(month = q_names[i], year = yr))
    }
  }
  list(month = "november", year = yr - 1L)
}


#' Construct the BoE MPR zip URL for a given month/year
#' @noRd
mpr_zip_url <- function(month, year) {
  pattern <- if (year >= 2025L) "charts-slides-and-data" else "chart-slides-and-data"
  sprintf(
    "https://www.bankofengland.co.uk/-/media/boe/files/monetary-policy-report/%d/%s/mpr-%s-%d-%s.zip",
    year, month, month, year, pattern
  )
}


#' Download the MPR zip with simple time-based caching
#' @noRd
download_mpr_zip <- function(month, year, cache = TRUE) {
  url        <- mpr_zip_url(month, year)
  cache_dir  <- boe_cache_dir()
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  cache_file <- file.path(cache_dir, sprintf("mpr-%s-%d.zip", month, year))

  is_latest_year <- year >= as.integer(format(Sys.Date(), "%Y")) - 1L

  if (cache && file.exists(cache_file)) {
    age_h <- as.numeric(difftime(Sys.time(), file.info(cache_file)$mtime,
                                 units = "hours"))
    if (!is_latest_year || age_h < 24) {
      cli::cli_progress_step(sprintf("Using cached %s %d MPR archive",
                                     tools::toTitleCase(month), year))
      return(cache_file)
    }
  }

  cli::cli_progress_step(sprintf("Downloading %s %d MPR archive",
                                 tools::toTitleCase(month), year))

  tryCatch(
    httr2::request(url) |>
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
        "i" = "Check the {.val {month}} {.val {year}} release exists, and your network connection.",
        "x" = conditionMessage(e)
      ))
    }
  )
  cache_file
}


#' Extract the Projections Databank workbook from an MPR zip
#' @noRd
extract_projections_databank <- function(zip_path) {
  files <- utils::unzip(zip_path, list = TRUE)$Name
  hits  <- grep("Projections Databank", files, fixed = TRUE)
  hits  <- hits[grepl("\\.xlsx?$", files[hits], ignore.case = TRUE)]

  if (length(hits) == 0L) {
    cli::cli_abort(c(
      "Projections Databank not found in MPR archive.",
      "i" = "Files in archive: {.val {files}}"
    ))
  }

  out_dir <- tempfile("boe_mpr_")
  dir.create(out_dir, recursive = TRUE)
  utils::unzip(zip_path,
               files     = files[hits[1L]],
               exdir     = out_dir,
               junkpaths = TRUE)
  file.path(out_dir, basename(files[hits[1L]]))
}


#' Parse one projection sheet into long format
#'
#' Sheet layout varies across the Projections Databank: most sheets put
#' the "Date of publication" header at row 5 with Excel serial dates in
#' column 1, but some (e.g. "38. Bank Rate") place it lower and use
#' text publication labels like "November 2004". This parser auto-
#' detects the header row by scanning for quarter labels, then handles
#' both date encodings.
#'
#' @noRd
parse_projection_sheet <- function(path, sheet_name, series_name) {
  sheets <- readxl::excel_sheets(path)
  if (!(sheet_name %in% sheets)) {
    matches <- grep(sub("^\\d+\\.\\s*", "", sheet_name),
                    sheets, ignore.case = TRUE, value = TRUE)
    matches <- matches[!grepl("distribution|short-term", matches, ignore.case = TRUE)]
    if (length(matches) == 0L) {
      cli::cli_abort(c(
        "Sheet {.val {sheet_name}} not found in MPR Projections Databank.",
        "i" = "Available sheets: {.val {head(sheets, 10)}}{if (length(sheets) > 10) ' ...'}"
      ))
    }
    sheet_name <- matches[1L]
  }

  raw <- suppressMessages(readxl::read_excel(
    path, sheet = sheet_name, col_names = FALSE
  ))
  raw <- as.data.frame(raw, stringsAsFactors = FALSE)
  if (nrow(raw) < 6L || ncol(raw) < 2L) {
    cli::cli_abort("Sheet {.val {sheet_name}} is too small to parse.")
  }

  hdr_row <- detect_header_row(raw)
  if (is.na(hdr_row)) {
    cli::cli_abort("Could not detect quarter-label header row in sheet {.val {sheet_name}}.")
  }

  header        <- as.character(unlist(raw[hdr_row, -1L]))
  is_qtr_label  <- !is.na(header) & grepl("^\\d{4}\\s*Q[1-4]$", trimws(header))
  quarter_labels <- trimws(header[is_qtr_label])
  horizon_dates  <- quarter_label_to_date(quarter_labels)

  body      <- raw[(hdr_row + 1L):nrow(raw), c(TRUE, is_qtr_label), drop = FALSE]
  pub_dates <- parse_publication_date(body[[1L]])
  good      <- !is.na(pub_dates)
  body      <- body[good, , drop = FALSE]
  pub_dates <- pub_dates[good]
  if (length(pub_dates) == 0L) {
    cli::cli_abort("No publication-date rows found in sheet {.val {sheet_name}}.")
  }

  vals <- suppressWarnings(matrix(
    as.numeric(as.matrix(body[, -1L, drop = FALSE])),
    nrow = nrow(body),
    ncol = length(quarter_labels)
  ))

  long <- data.frame(
    date         = rep(pub_dates,      times = ncol(vals)),
    horizon      = rep(quarter_labels, each  = nrow(vals)),
    horizon_date = rep(horizon_dates,  each  = nrow(vals)),
    series       = series_name,
    value        = as.numeric(vals),
    stringsAsFactors = FALSE
  )
  long <- long[!is.na(long$value), , drop = FALSE]
  rownames(long) <- NULL
  long
}


#' Find the row of `raw` whose columns contain quarter labels
#'
#' Scans the first 20 rows for a row where 5 or more cells (excluding
#' the first column) match the `YYYY QN` pattern.
#' @noRd
detect_header_row <- function(raw) {
  n_scan <- min(20L, nrow(raw))
  for (r in seq_len(n_scan)) {
    candidates <- as.character(unlist(raw[r, -1L]))
    n_qtrs <- sum(grepl("^\\d{4}\\s*Q[1-4]$", trimws(candidates)),
                  na.rm = TRUE)
    if (n_qtrs >= 5L) return(r)
  }
  NA_integer_
}


#' Parse a publication-date column, accepting Excel serials or text
#'
#' BoE uses Excel serials in most projection sheets but text labels
#' like "November 2004" or "November 2022 (f)" in others. Footnote
#' markers in parentheses are stripped before parsing the text form.
#' Text dates resolve to the first day of the named month.
#' @noRd
parse_publication_date <- function(x) {
  serials <- suppressWarnings(as.numeric(x))
  out     <- rep(as.Date(NA), length(x))
  ok_ser  <- !is.na(serials) & serials > 30000 & serials < 60000
  out[ok_ser] <- as.Date(serials[ok_ser], origin = "1899-12-30")

  todo <- !ok_ser & !is.na(x) & nzchar(as.character(x))
  if (any(todo)) {
    txt <- sub("\\s*\\([a-z]\\)\\s*$", "", as.character(x[todo]),
               ignore.case = TRUE)
    old <- Sys.getlocale("LC_TIME")
    on.exit(suppressWarnings(Sys.setlocale("LC_TIME", old)), add = TRUE)
    suppressWarnings(Sys.setlocale("LC_TIME", "C"))
    out[todo] <- suppressWarnings(
      as.Date(paste("1", txt), format = "%d %B %Y")
    )
  }
  out
}


#' Convert "2024 Q1" to a Date at the start of the quarter
#' @noRd
quarter_label_to_date <- function(labels) {
  parts <- strsplit(trimws(labels), "\\s+")
  vapply(parts, function(p) {
    if (length(p) < 2L) return(NA_character_)
    yr <- as.integer(p[1L])
    qn <- as.integer(sub("Q", "", p[2L]))
    if (is.na(yr) || is.na(qn) || qn < 1L || qn > 4L) return(NA_character_)
    sprintf("%d-%02d-01", yr, (qn - 1L) * 3L + 1L)
  }, character(1L)) |> as.Date()
}
