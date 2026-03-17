#' Download SONIA interest rate
#'
#' Downloads the Sterling Overnight Index Average (SONIA), the risk-free
#' reference rate for sterling markets. Available daily from January 1997.
#'
#' @param from Date or character (YYYY-MM-DD). Start date. Defaults to
#'   `"1997-01-02"`.
#' @param to Date or character (YYYY-MM-DD). End date. Defaults to today.
#' @param frequency Character. One of `"daily"` (default), `"monthly"`
#'   (monthly average), or `"annual"` (annual average).
#' @param cache Logical. Use cached data if available (default `TRUE`).
#'
#' @return A data frame with columns:
#'   \describe{
#'     \item{date}{Date. Observation date.}
#'     \item{rate_pct}{Numeric. SONIA rate (percent).}
#'   }
#'
#' @source
#' <https://www.bankofengland.co.uk/boeapps/database/>
#'
#' @examples
#' \donttest{
#' op <- options(boe.cache_dir = tempdir())
#' boe_sonia(from = "2020-01-01")
#' options(op)
#' }
#'
#' @family interest rates
#' @export
boe_sonia <- function(from      = "1997-01-02",
                      to        = Sys.Date(),
                      frequency = c("daily", "monthly", "annual"),
                      cache     = TRUE) {

  frequency <- match.arg(frequency)
  code <- switch(frequency,
    daily   = "IUDSOIA",
    monthly = "IUMASOIA",
    annual  = "IUAASOIA"
  )

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
