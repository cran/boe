#' Bank Rate decision history
#'
#' Returns the history of Monetary Policy Committee decisions to change
#' Bank Rate, derived from the daily Bank Rate series. Each row is one
#' rate-change event, showing the effective date, the new rate, the
#' previous rate, and the change in basis points. Holds (meetings where
#' the rate was unchanged) are not included; for the full meeting-level
#' record including holds, see [boe_mpc_votes()].
#'
#' @param from Date or character. Start date. Defaults to
#'   `"1997-06-06"` (the first MPC meeting).
#' @param to Date or character. End date. Defaults to today.
#' @param cache Logical. Use cached Bank Rate data if available
#'   (default `TRUE`).
#'
#' @return A `boe_tbl` data frame with columns:
#'   \describe{
#'     \item{date}{Date. Effective date of the rate change.}
#'     \item{new_rate_pct}{Numeric. Bank Rate after the decision (percent).}
#'     \item{prev_rate_pct}{Numeric. Bank Rate before the decision (percent).}
#'     \item{change_bps}{Integer. Change in basis points (positive = hike,
#'       negative = cut).}
#'     \item{direction}{Character. `"hike"` or `"cut"`.}
#'   }
#'
#' @source
#' Derived from BoE series `IUDBEDR` (daily Bank Rate). See
#' <https://www.bankofengland.co.uk/monetary-policy>.
#'
#' @examples
#' \donttest{
#' op <- options(boe.cache_dir = tempdir())
#' # All MPC decisions since the global financial crisis
#' boe_mpc_decisions(from = "2007-01-01")
#'
#' # Just decisions in 2024 to date
#' boe_mpc_decisions(from = "2024-01-01")
#' options(op)
#' }
#'
#' @family monetary policy
#' @seealso [boe_bank_rate()], [boe_mpc_votes()]
#' @export
boe_mpc_decisions <- function(from  = "1997-06-06",
                              to    = Sys.Date(),
                              cache = TRUE) {

  br <- boe_bank_rate(from = from, to = to,
                      frequency = "daily", cache = cache)

  rates <- br$rate_pct
  dates <- br$date
  if (length(rates) < 2L) {
    cli::cli_abort("Not enough Bank Rate observations to detect changes.")
  }

  dr      <- diff(rates)
  changes <- which(dr != 0)
  if (length(changes) == 0L) {
    out <- data.frame(
      date          = as.Date(character(0)),
      new_rate_pct  = numeric(0),
      prev_rate_pct = numeric(0),
      change_bps    = integer(0),
      direction     = character(0),
      stringsAsFactors = FALSE
    )
  } else {
    out <- data.frame(
      date          = dates[changes + 1L],
      new_rate_pct  = rates[changes + 1L],
      prev_rate_pct = rates[changes],
      change_bps    = as.integer(round((rates[changes + 1L] - rates[changes]) * 100)),
      direction     = ifelse(dr[changes] > 0, "hike", "cut"),
      stringsAsFactors = FALSE
    )
  }

  new_boe_tbl(out, query = list(
    series_codes  = "IUDBEDR",
    from          = from,
    to            = to,
    frequency     = "decision",
    function_name = "boe_mpc_decisions"
  ))
}
