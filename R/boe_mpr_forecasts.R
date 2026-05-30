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
#' @param month Character. Publication month of the report, e.g.
#'   `"february"` or `"may"`. The report is published roughly quarterly,
#'   but the exact month drifts between years (for example, the second
#'   2026 report appeared in April, not May), so any month name is
#'   accepted and its existence is verified against the Bank's website.
#'   Supply with `year`. If both are `NULL`, the most recent compatible
#'   release is selected automatically.
#' @param year Integer. MPR year, 2019 or later. Supply with `month`.
#'   If both are `NULL`, the most recent compatible release is selected
#'   automatically.
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
#' @section Release format and automatic fallback:
#' From the April 2026 report the Bank moved to a scenario-based
#' "Scenario Projections Databank" with a transposed layout (following
#' the Bernanke review of forecasting). That format is not parsed by
#' this function yet. When automatic selection encounters such a
#' release it skips it, falls back to the most recent compatible release
#' (the classic "Projections Databank" workbook), and warns. Requesting
#' a scenario-format release explicitly via `month`/`year` raises a
#' clear error. Pre-2020 MPRs that predate the single "Projections
#' Databank" workbook may also error.
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

  if (is.null(month) && is.null(year)) {
    picked   <- pick_mpr_release(cache = cache)
    release  <- picked$release
    zip_path <- picked$zip_path
  } else {
    release  <- resolve_mpr_release(month = month, year = year)
    zip_path <- download_mpr_zip(release$month, release$year, cache = cache)
    if (!mpr_zip_is_old_format(zip_path)) {
      rel_label <- sprintf("%s %d", tools::toTitleCase(release$month),
                           release$year)
      cli::cli_abort(c(
        "The {rel_label} MPR uses the Bank of England's new scenario-based format.",
        "i" = "This format is not parsed by {.fn boe_mpr_forecasts} yet.",
        "i" = "Request an earlier release (February 2026 or before), or omit {.arg month} and {.arg year} to auto-select the latest compatible release."
      ))
    }
  }
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


#' Validate an explicitly requested (month, year) MPR release
#'
#' Used only when the caller supplies `month`/`year`. The publication
#' schedule drifts between years, so any valid month name is accepted;
#' whether that release actually exists is verified at download time.
#' @noRd
resolve_mpr_release <- function(month = NULL, year = NULL,
                                today = Sys.Date()) {
  if (is.null(month) && is.null(year)) {
    return(mpr_release_candidates(today)[[1L]])
  }
  if (is.null(month) || is.null(year)) {
    cli::cli_abort("Specify both {.arg month} and {.arg year}, or neither.")
  }
  month <- tolower(as.character(month))
  if (!month %in% tolower(month.name)) {
    cli::cli_abort('{.arg month} must be a month name, e.g. {.val february} or {.val may}.')
  }
  year <- as.integer(year)
  if (year < 2019L) {
    cli::cli_abort("MPR coverage starts at November 2019. For earlier dates use the legacy Inflation Report.")
  }
  list(month = month, year = year)
}


#' Candidate MPR releases, most recent first
#'
#' The report is published roughly quarterly but the exact publication
#' month drifts between years, so rather than assume a fixed Feb/May/
#' Aug/Nov calendar we enumerate the last `n_months` months and let the
#' caller probe which ones actually exist. Eight months spans more than
#' two quarterly cycles, enough to find the latest release even when the
#' two most recent ones are unpublished or in an unsupported format.
#' @noRd
mpr_release_candidates <- function(today = Sys.Date(), n_months = 8L) {
  yr     <- as.integer(format(today, "%Y"))
  mo     <- as.integer(format(today, "%m"))
  months <- tolower(month.name)
  lapply(seq_len(n_months) - 1L, function(k) {
    m <- mo - k
    y <- yr
    while (m <= 0L) {
      m <- m + 12L
      y <- y - 1L
    }
    list(month = months[m], year = y)
  })
}


#' Candidate zip URLs for a release, most likely first
#'
#' The data archive filename drifted from "chart-slides-and-data"
#' (February 2025 and earlier) to "charts-slides-and-data" (May 2025
#' onwards). Both variants are returned so the caller can probe each.
#' @noRd
mpr_zip_urls <- function(month, year) {
  base <- sprintf(
    "https://www.bankofengland.co.uk/-/media/boe/files/monetary-policy-report/%d/%s/mpr-%s-%d-",
    year, month, month, year
  )
  variants <- c("charts-slides-and-data", "chart-slides-and-data")
  if (year < 2025L) variants <- rev(variants)
  paste0(base, variants, ".zip")
}


#' Primary (best-guess) zip URL for a release
#' @noRd
mpr_zip_url <- function(month, year) {
  mpr_zip_urls(month, year)[[1L]]
}


#' Does a URL resolve (HTTP < 400)? Returns FALSE on any network error.
#' @noRd
url_exists_boe <- function(url) {
  tryCatch({
    resp <- httr2::request(url) |>
      httr2::req_user_agent("boe R package (https://github.com/charlescoverdale/boe)") |>
      httr2::req_method("HEAD") |>
      httr2::req_timeout(30) |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_perform()
    httr2::resp_status(resp) < 400L
  }, error = function(e) FALSE)
}


#' First existing zip URL for a release, or NULL if none resolve
#' @noRd
mpr_resolve_url <- function(month, year) {
  for (u in mpr_zip_urls(month, year)) {
    if (url_exists_boe(u)) return(u)
  }
  NULL
}


#' Select the most recent compatible (parseable) MPR release
#'
#' Walks back through candidate releases, newest first, probing each
#' URL. The first release that both exists and uses the classic
#' "Projections Databank" workbook is returned. Newer releases that use
#' the unsupported scenario format are skipped with a warning. Errors
#' only if no compatible release resolves in the lookback window.
#' @noRd
pick_mpr_release <- function(today = Sys.Date(), cache = TRUE,
                             max_lookback = 8L) {
  candidates <- mpr_release_candidates(today, n_months = max_lookback)
  skipped    <- character(0)

  for (rel in candidates) {
    url <- mpr_resolve_url(rel$month, rel$year)
    if (is.null(url)) next

    zip_path <- download_mpr_zip(rel$month, rel$year, cache = cache, url = url)

    if (mpr_zip_is_old_format(zip_path)) {
      if (length(skipped) > 0L) {
        rel_label <- sprintf("%s %d", tools::toTitleCase(rel$month), rel$year)
        cli::cli_warn(c(
          "!" = "Skipping newer MPR release(s) in the Bank of England's new scenario-based format, not parsed by {.fn boe_mpr_forecasts} yet: {.val {skipped}}.",
          "i" = "Returning the most recent compatible release: {rel_label}."
        ))
      }
      return(list(release = rel, zip_path = zip_path))
    }
    skipped <- c(skipped, sprintf("%s %d", tools::toTitleCase(rel$month),
                                  rel$year))
  }

  cli::cli_abort(c(
    "Could not find a compatible MPR release in the last {max_lookback} months.",
    "i" = "Recent releases may use the Bank's new scenario-based format (not parsed by {.fn boe_mpr_forecasts} yet).",
    "i" = "Check your network connection, or request a known release with {.arg month} and {.arg year}."
  ))
}


#' Download the MPR zip with simple time-based caching
#'
#' `url` may be supplied pre-resolved (e.g. by [pick_mpr_release()]) to
#' avoid a second existence probe; otherwise the existing filename
#' variants are probed and the first that resolves is used.
#' @noRd
download_mpr_zip <- function(month, year, cache = TRUE, url = NULL) {
  if (is.null(url)) {
    url <- mpr_resolve_url(month, year)
    if (is.null(url)) {
      cli::cli_abort(c(
        "No MPR data archive found for {.val {month}} {.val {year}}.",
        "i" = "Check the release exists and is published at {.url https://www.bankofengland.co.uk/monetary-policy}."
      ))
    }
  }
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


#' Does an MPR zip contain the classic (parseable) Projections Databank?
#'
#' The April 2026 redesign renamed the workbook to "Scenario Projections
#' Databank" and changed its layout. We treat a release as compatible
#' only when it ships a databank workbook whose name does not contain
#' "Scenario".
#' @noRd
mpr_zip_is_old_format <- function(zip_path) {
  files <- tryCatch(utils::unzip(zip_path, list = TRUE)$Name,
                    error = function(e) character(0))
  db <- files[grepl("Projections Databank", files, fixed = TRUE) &
              grepl("\\.xlsx?$", files, ignore.case = TRUE)]
  any(!grepl("Scenario", db, fixed = TRUE))
}


#' Extract the Projections Databank workbook from an MPR zip
#' @noRd
extract_projections_databank <- function(zip_path) {
  files <- utils::unzip(zip_path, list = TRUE)$Name
  hits  <- grep("Projections Databank", files, fixed = TRUE)
  hits  <- hits[grepl("\\.xlsx?$", files[hits], ignore.case = TRUE)]
  # Prefer the classic workbook over the new "Scenario Projections
  # Databank" when both are present.
  classic <- hits[!grepl("Scenario", files[hits], fixed = TRUE)]
  if (length(classic) > 0L) hits <- classic

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
