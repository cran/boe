#' Download Bank of England Bank Rate history
#'
#' Downloads the official Bank Rate (base interest rate) set by the Monetary
#' Policy Committee. Available as a daily series from January 1975.
#'
#' @param from Date or character (YYYY-MM-DD). Start date. Defaults to
#'   `"1975-01-02"`.
#' @param to Date or character (YYYY-MM-DD). End date. Defaults to today.
#' @param frequency Character. One of `"daily"` (default) or `"monthly"`
#'   (monthly average).
#' @param cache Logical. Use cached data if available (default `TRUE`).
#'
#' @return A data frame with columns:
#'   \describe{
#'     \item{date}{Date. Observation date.}
#'     \item{rate_pct}{Numeric. Bank Rate (percent).}
#'   }
#'
#' @source
#' <https://www.bankofengland.co.uk/boeapps/database/>
#'
#' @examples
#' \donttest{
#' # Bank Rate since 2000
#' boe_bank_rate(from = "2000-01-01")
#'
#' # Monthly average
#' boe_bank_rate(from = "2020-01-01", frequency = "monthly")
#' }
#'
#' @export
boe_bank_rate <- function(from      = "1975-01-02",
                          to        = Sys.Date(),
                          frequency = c("daily", "monthly"),
                          cache     = TRUE) {

  frequency <- match.arg(frequency)
  code <- if (frequency == "daily") "IUDBEDR" else "IUMABEDR"

  from <- parse_date_arg(from, "from")
  to   <- parse_date_arg(to, "to")

  out <- boe_fetch(code, from = from, to = to, cache = cache)

  result <- data.frame(
    date     = out$date,
    rate_pct = out$value,
    stringsAsFactors = FALSE
  )

  cli::cli_progress_done()
  result
}
