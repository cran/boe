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
#' @param series Character vector of series to return. The five
#'   traditional series are the default: `"cpi_inflation"`,
#'   `"gdp_growth"`, `"gdp_level"`, `"unemployment"`, and `"bank_rate"`.
#'   From the April 2026 report the Bank also publishes scenario paths
#'   for `"output_gap"`, `"energy_prices"`, `"average_earnings"`, and
#'   `"world_export_prices"`, which can be requested explicitly. Series
#'   not published in a given release are skipped with a warning: the
#'   scenario-only series are absent from classic releases (February
#'   2026 and earlier), and the April 2026 scenario-format release drops
#'   `"gdp_level"` and `"bank_rate"`. Hybrid releases (July 2026 onward)
#'   publish all nine.
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
#'     \item{date}{Date. Publication date of the MPR release.}
#'     \item{horizon}{Character. Quarter label (e.g. `"2026 Q1"`).}
#'     \item{horizon_date}{Date. Start of the quarter.}
#'     \item{series}{Character. Series identifier (e.g. `"cpi_inflation"`).}
#'     \item{scenario}{Character. Scenario or vintage label in the
#'       scenario-based format (e.g. `"April 2026 Scenario A"`); `NA` in
#'       the classic format, which carries a single central projection.}
#'     \item{value}{Numeric. Forecast value (percent for rates and
#'       growth; index for `gdp_level`).}
#'   }
#'
#' @details
#' Requires the \pkg{readxl} package. The MPR is published as a zip
#' archive containing a projections databank workbook plus chart data
#' and slides; this function reads only the projection sheets.
#'
#' In the classic format (up to February 2026) each row of a projection
#' sheet is one MPR publication and the columns are forecast quarters,
#' so the function returns one row per publication and horizon with a
#' single central projection (`scenario` is `NA`). In the scenario-based
#' format (April 2026) each sheet holds one series with the quarters
#' down the rows and one column per scenario, so the function returns
#' the full quarterly path (history and projection) for every scenario,
#' tagged in the `scenario` column. Hybrid releases (July 2026 onward)
#' carry both: central projections for all publications (`scenario` is
#' `NA`) plus the current report's scenario paths (labelled, e.g.
#' `"Adverse Scenario"`), in one output.
#'
#' @source <https://www.bankofengland.co.uk/monetary-policy>
#'
#' @section Release format:
#' Following the Bernanke review of forecasting, the Bank replaced the
#' single central projection of the classic "Projections Databank" with
#' a scenario-based "Scenario Projections Databank" in the April 2026
#' report, then merged the two from the July 2026 report into one
#' hybrid workbook holding both the classic central-projection sheets
#' (GDP level and Bank Rate restored) and a "Quarterly scenarios"
#' section. All three layouts are parsed and share the same output
#' columns; the format is detected automatically from the release. The
#' April 2026 release alone lacks a GDP level and Bank Rate sheet (Bank
#' Rate was published as a conditioning assumption), so those two
#' series are skipped with a warning for that release. Pre-2020 MPRs
#' that predate the single databank workbook may error.
#'
#' @examples
#' \donttest{
#' if (requireNamespace("readxl", quietly = TRUE)) {
#'   op <- options(boe.cache_dir = tempdir())
#'
#'   # Latest CPI inflation projections. In the scenario-based format
#'   # this returns one path per scenario (see the `scenario` column).
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

  series_default <- eval(formals()$series)
  series_choices <- c(series_default, "output_gap", "energy_prices",
                      "average_earnings", "world_export_prices")
  if (missing(series)) {
    series <- series_default
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
  }

  xls_path  <- extract_projections_databank(zip_path)
  fmt       <- mpr_databank_format(xls_path)
  rel_label <- sprintf("%s %d", tools::toTitleCase(release$month), release$year)

  parts   <- list()
  skipped <- character(0)
  for (s in series) {
    df <- mpr_parse_series(xls_path, s, fmt = fmt, release = release)
    if (is.null(df)) skipped <- c(skipped, s) else parts[[s]] <- df
  }

  if (length(skipped) > 0L) {
    hint <- switch(fmt,
      classic  = "These series are published from the April 2026 report onward.",
      scenario = "The scenario-based format (April 2026) drops the GDP level and Bank Rate sheets (Bank Rate is now a conditioning assumption).",
      hybrid   = "The requested sheets were not found in this release's databank workbook."
    )
    cli::cli_warn(c(
      "!" = "Series {.val {skipped}} not published in the {rel_label} MPR; skipping.",
      "i" = hint
    ))
  }
  if (length(parts) == 0L) {
    cli::cli_abort(c(
      "None of the requested series are available in the {rel_label} MPR.",
      "i" = "See {.help boe_mpr_forecasts} for which series each report format publishes."
    ))
  }

  out <- do.call(rbind, parts)
  out <- out[order(out$date, out$horizon_date, out$series, out$scenario), ,
             drop = FALSE]
  rownames(out) <- NULL

  cli::cli_progress_done()
  new_boe_tbl(out, query = list(
    series_codes  = paste0("MPR_", toupper(names(parts))),
    from          = min(out$date),
    to            = max(out$date),
    frequency     = "quarterly",
    function_name = "boe_mpr_forecasts",
    vintage       = sprintf("%s %d", release$month, release$year)
  ))
}


#' Sheet name for a series in the classic Projections Databank
#'
#' Returns `NA` for series that the classic format does not publish (the
#' scenario-only series). Sheet numbers drift between releases, so the
#' downstream parser matches on the descriptive name, not the number.
#' @noRd
mpr_sheet_old <- function(series) {
  switch(series,
    cpi_inflation = "1. CPI inflation",
    gdp_growth    = "2. GDP growth",
    gdp_level     = "3. GDP level",
    unemployment  = "4. Unemployment",
    bank_rate     = "38. Bank Rate",
    NA_character_
  )
}


#' Sheet name for a series in the scenario-based Projections Databank
#'
#' Returns `NA` for series the scenario format does not publish (GDP
#' level and Bank Rate; Bank Rate is now a conditioning assumption).
#' Each series has a quarterly sheet (used here) and an annual duplicate;
#' the parser prefers the quarterly one.
#' @noRd
mpr_sheet_scenario <- function(series) {
  switch(series,
    cpi_inflation       = "2. CPI inflation",
    gdp_growth          = "3. GDP growth",
    unemployment        = "4. Unemployment",
    output_gap          = "5. Output gap",
    energy_prices       = "6. Energy prices",
    average_earnings    = "7. Average weekly earnings",
    world_export_prices = "8. World export prices",
    NA_character_
  )
}


#' Which layout does a Projections Databank workbook use?
#'
#' Three formats exist:
#' * `"classic"`: up to February 2026. One sheet per series, MPR
#'   publications down the rows, forecast quarters across the columns.
#' * `"scenario"`: April 2026 only. The workbook is named "Scenario
#'   Projections Databank"; each sheet holds one series transposed, with
#'   one column per scenario. GDP level and Bank Rate are dropped.
#' * `"hybrid"`: July 2026 onward. A single workbook restores the
#'   classic central-projection sheets (including GDP level and Bank
#'   Rate) and adds a "Quarterly scenarios" section of transposed
#'   scenario sheets.
#' @noRd
mpr_databank_format <- function(xls_path) {
  if (grepl("Scenario", basename(xls_path), fixed = TRUE)) {
    return("scenario")
  }
  sheets <- readxl::excel_sheets(xls_path)
  if (any(grepl("Quarterly scenarios", sheets, ignore.case = TRUE))) {
    return("hybrid")
  }
  "classic"
}


#' Sheets in the "Quarterly scenarios" section of a hybrid workbook
#'
#' Hybrid workbooks group sheets with divider tabs ending in "==>". The
#' scenario sheets sit between the "Quarterly scenarios ==>" divider and
#' the next divider. Restricting scenario lookups to this pool matters
#' because the classic section carries same-named sheets (e.g. "22.
#' Output gap" central projection vs "47. Output gap" scenarios).
#' @noRd
hybrid_scenario_pool <- function(sheets) {
  start <- grep("Quarterly scenarios", sheets, ignore.case = TRUE)
  if (length(start) == 0L) return(character(0))
  rest    <- sheets[-seq_len(start[[1L]])]
  divider <- grep("==>$", trimws(rest))
  if (length(divider) > 0L) rest <- rest[seq_len(divider[[1L]] - 1L)]
  rest
}


#' Parse one series from whichever databank format the release uses
#'
#' Returns `NULL` (the caller skips and warns) when the series is not
#' published in the given release's format. In the hybrid format a
#' series can appear both as a classic central-projection sheet and as
#' a quarterly scenario sheet; both are parsed and combined, with the
#' scenario column distinguishing the rows.
#' @noRd
mpr_parse_series <- function(path, series, fmt, release) {
  if (fmt == "classic") {
    sheet <- mpr_sheet_old(series)
    if (is.na(sheet)) return(NULL)
    return(parse_projection_sheet(path, sheet, series))
  }

  if (fmt == "scenario") {
    sheet <- mpr_sheet_scenario(series)
    if (is.na(sheet)) return(NULL)
    return(parse_scenario_sheet(path, sheet, series, release))
  }

  # Hybrid: classic central projections plus any quarterly scenario sheet.
  parts <- list()

  classic_sheet <- mpr_sheet_old(series)
  if (!is.na(classic_sheet)) {
    parts$classic <- parse_projection_sheet(path, classic_sheet, series)
  }

  scenario_sheet <- mpr_sheet_scenario(series)
  if (!is.na(scenario_sheet)) {
    pool <- hybrid_scenario_pool(readxl::excel_sheets(path))
    parts$scenario <- parse_scenario_sheet(path, scenario_sheet, series,
                                           release, candidates = pool)
  }

  parts <- parts[!vapply(parts, is.null, logical(1L))]
  if (length(parts) == 0L) return(NULL)
  do.call(rbind, unname(parts))
}


#' Publication date of a release (first day of the publication month)
#' @noRd
release_pub_date <- function(release) {
  m <- match(tolower(release$month), tolower(month.name))
  as.Date(sprintf("%d-%02d-01", release$year, m))
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


#' Select the most recent published MPR release
#'
#' Walks back through candidate releases, newest first, and returns the
#' first one whose data archive exists. Both the classic and the
#' scenario-based formats are parsed, so no format filtering is needed.
#' Errors only if no release resolves in the lookback window.
#' @noRd
pick_mpr_release <- function(today = Sys.Date(), cache = TRUE,
                             max_lookback = 8L) {
  candidates <- mpr_release_candidates(today, n_months = max_lookback)

  for (rel in candidates) {
    url <- mpr_resolve_url(rel$month, rel$year)
    if (is.null(url)) next
    zip_path <- download_mpr_zip(rel$month, rel$year, cache = cache, url = url)
    return(list(release = rel, zip_path = zip_path))
  }

  cli::cli_abort(c(
    "Could not find a published MPR release in the last {max_lookback} months.",
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
    scenario     = NA_character_,
    value        = as.numeric(vals),
    stringsAsFactors = FALSE
  )
  long <- long[!is.na(long$value), , drop = FALSE]
  rownames(long) <- NULL
  long
}


#' Resolve a scenario-databank sheet name, preferring the quarterly sheet
#'
#' The scenario databank carries each series twice: a quarterly sheet
#' (e.g. "2. CPI inflation") and an annual duplicate (e.g. "9. CPI
#' inflation"). Sheet numbers drift, so we match on the descriptive name
#' and take the first hit, which is the quarterly sheet (it precedes the
#' annual one). Returns `NA` if the series is absent from the workbook.
#' @noRd
resolve_scenario_sheet <- function(sheets, target, series_name) {
  if (target %in% sheets) return(target)
  key  <- sub("^\\d+\\.\\s*", "", target)
  hits <- grep(key, sheets, ignore.case = TRUE, fixed = FALSE, value = TRUE)
  if (length(hits) == 0L) return(NA_character_)
  hits[[1L]]
}


#' Parse one sheet of the scenario-based (transposed) databank
#'
#' Scenario sheets hold a single series with quarter labels down column
#' A (under a "Date" header) and one column per scenario or vintage
#' (e.g. "February 2026 central", "April 2026 Scenario A"). Returns the
#' full quarterly path for every scenario in long format, or `NULL` if
#' the sheet is absent from the workbook. `candidates` restricts the
#' sheets considered (used for hybrid workbooks, whose classic section
#' carries same-named sheets in a different layout).
#' @noRd
parse_scenario_sheet <- function(path, sheet_name, series_name, release,
                                 candidates = NULL) {
  sheets <- readxl::excel_sheets(path)
  if (!is.null(candidates)) sheets <- intersect(sheets, candidates)
  sheet  <- resolve_scenario_sheet(sheets, sheet_name, series_name)
  if (is.na(sheet)) return(NULL)

  raw <- suppressMessages(readxl::read_excel(
    path, sheet = sheet, col_names = FALSE
  ))
  raw <- as.data.frame(raw, stringsAsFactors = FALSE)

  hdr_row <- which(tolower(trimws(as.character(raw[[1L]]))) == "date")[1L]
  if (is.na(hdr_row)) {
    cli::cli_abort("Could not find the {.val Date} header row in sheet {.val {sheet}}.")
  }

  scen_labels <- as.character(unlist(raw[hdr_row, -1L]))
  keep        <- !is.na(scen_labels) & nzchar(trimws(scen_labels))
  scen_labels <- trimws(scen_labels[keep])
  if (length(scen_labels) == 0L) {
    cli::cli_abort("No scenario columns found in sheet {.val {sheet}}.")
  }

  body <- raw[(hdr_row + 1L):nrow(raw), c(TRUE, keep), drop = FALSE]
  qtr  <- trimws(as.character(body[[1L]]))
  is_q <- grepl("^\\d{4}\\s*Q[1-4]$", qtr)
  body <- body[is_q, , drop = FALSE]
  qtr  <- qtr[is_q]
  if (length(qtr) == 0L) {
    cli::cli_abort("No quarter-label rows found in sheet {.val {sheet}}.")
  }

  vals <- suppressWarnings(matrix(
    as.numeric(as.matrix(body[, -1L, drop = FALSE])),
    nrow = length(qtr),
    ncol = length(scen_labels)
  ))

  long <- data.frame(
    date         = release_pub_date(release),
    horizon      = rep(qtr,                  times = length(scen_labels)),
    horizon_date = rep(quarter_label_to_date(qtr), times = length(scen_labels)),
    series       = series_name,
    scenario     = rep(scen_labels,          each  = length(qtr)),
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
