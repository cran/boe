#' Monetary Policy Committee voting history
#'
#' Downloads the Bank of England's published MPC voting record and
#' returns it in long format. Each row is one (meeting, member) pair
#' showing the rate the member voted for and whether that constituted
#' a dissent from the committee's decision.
#'
#' Coverage runs from the first MPC meeting in June 1997 through the
#' most recent published minutes. Both current and past committee
#' members are included.
#'
#' @param cache Logical. Use cached download if less than 24 hours old
#'   (default `TRUE`). The voting workbook is small (~110 KB).
#'
#' @return A `boe_tbl` data frame with columns:
#'   \describe{
#'     \item{date}{Date. Meeting date.}
#'     \item{member}{Character. MPC member name.}
#'     \item{member_vote_pct}{Numeric. The Bank Rate the member voted
#'       for (percent).}
#'     \item{decision_pct}{Numeric. The committee's decision (percent).}
#'     \item{dissent}{Logical. `TRUE` if the member's vote differed from
#'       the committee decision.}
#'   }
#'
#' @details Requires the \pkg{readxl} package.
#'
#' @source <https://www.bankofengland.co.uk/monetary-policy>
#'
#' @examples
#' \donttest{
#' if (requireNamespace("readxl", quietly = TRUE)) {
#'   op <- options(boe.cache_dir = tempdir())
#'   votes <- boe_mpc_votes()
#'
#'   # Recent dissents
#'   recent <- subset(votes, dissent & date >= as.Date("2024-01-01"))
#'   head(recent)
#'
#'   options(op)
#' }
#' }
#'
#' @family monetary policy
#' @seealso [boe_mpc_decisions()]
#' @export
boe_mpc_votes <- function(cache = TRUE) {

  if (!requireNamespace("readxl", quietly = TRUE)) {
    cli::cli_abort(c(
      "Package {.pkg readxl} is required to parse the MPC voting file.",
      "i" = "Install it with {.code install.packages(\"readxl\")}."
    ))
  }

  cache_file <- file.path(boe_cache_dir(), "mpcvoting.xlsx")
  dir.create(dirname(cache_file), recursive = TRUE, showWarnings = FALSE)

  fresh <- cache &&
    file.exists(cache_file) &&
    as.numeric(difftime(Sys.time(), file.info(cache_file)$mtime,
                        units = "hours")) < 24

  if (fresh) {
    cli::cli_progress_step("Using cached MPC voting record")
  } else {
    cli::cli_progress_step("Downloading MPC voting record from Bank of England")
    url <- mpcvoting_url()
    tryCatch(
      httr2::request(url) |>
        httr2::req_user_agent("boe R package (https://github.com/charlescoverdale/boe)") |>
        httr2::req_timeout(60) |>
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
  }

  parse_mpcvoting(cache_file)
}


#' @noRd
mpcvoting_url <- function() {
  "https://www.bankofengland.co.uk/-/media/boe/files/monetary-policy-summary-and-minutes/mpcvoting.xlsx"
}


#' Parse the BoE MPC voting workbook
#'
#' Sheet "Bank Rate Decisions" lays out one row per meeting (from row
#' 11 downwards) and one column per member (in row 3). Column 2 holds
#' an Excel serial meeting date and column 3 holds the rate as a
#' decimal (e.g. 0.04 for 4.00%).
#'
#' @noRd
parse_mpcvoting <- function(path) {
  raw <- suppressMessages(readxl::read_excel(
    path, sheet = "Bank Rate Decisions", col_names = FALSE
  ))
  raw <- as.data.frame(raw, stringsAsFactors = FALSE)

  if (nrow(raw) < 11L || ncol(raw) < 4L) {
    cli::cli_abort("MPC voting sheet is too small to parse.")
  }

  header  <- as.character(unlist(raw[3L, ]))
  is_name <- !is.na(header) &
             nzchar(header) &
             !header %in% c("Current members", "Past members")
  member_cols  <- which(is_name)
  member_names <- header[member_cols]

  if (length(member_cols) == 0L) {
    cli::cli_abort("No MPC member names found on row 3 of the voting sheet.")
  }

  body    <- raw[11L:nrow(raw), , drop = FALSE]
  serials <- suppressWarnings(as.numeric(body[[2L]]))
  rates   <- suppressWarnings(as.numeric(body[[3L]]))
  good    <- !is.na(serials) & !is.na(rates) & serials > 30000
  body    <- body[good, , drop = FALSE]
  serials <- serials[good]
  rates   <- rates[good]

  if (nrow(body) == 0L) {
    cli::cli_abort("No meeting rows found in the MPC voting sheet.")
  }

  meeting_dates <- as.Date(serials, origin = "1899-12-30")
  decision_pct  <- rates * 100

  vote_mat <- suppressWarnings(matrix(
    as.numeric(as.matrix(body[, member_cols, drop = FALSE])),
    nrow = nrow(body),
    ncol = length(member_cols)
  )) * 100

  long <- data.frame(
    date            = rep(meeting_dates, times = ncol(vote_mat)),
    member          = rep(member_names,  each  = nrow(vote_mat)),
    member_vote_pct = as.numeric(vote_mat),
    decision_pct    = rep(decision_pct,  times = ncol(vote_mat)),
    stringsAsFactors = FALSE
  )
  long$dissent <- !is.na(long$member_vote_pct) &
    abs(long$member_vote_pct - long$decision_pct) > 1e-6
  long <- long[!is.na(long$member_vote_pct), , drop = FALSE]
  long <- long[order(long$date, long$member), , drop = FALSE]
  rownames(long) <- NULL

  cli::cli_progress_done()
  new_boe_tbl(long, query = list(
    series_codes  = "MPCVOTING_BANKRATE",
    from          = min(long$date),
    to            = max(long$date),
    frequency     = "meeting",
    function_name = "boe_mpc_votes"
  ))
}
