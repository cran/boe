#' Download mortgage approvals for house purchase
#'
#' Downloads the monthly count of mortgage approvals for house purchase,
#' a widely watched leading indicator of housing market activity.
#' Available from April 1993.
#'
#' @param from Date or character (YYYY-MM-DD). Start date. Defaults to
#'   `"1993-04-01"`.
#' @param to Date or character (YYYY-MM-DD). End date. Defaults to today.
#' @param seasonally_adjusted Logical. Return seasonally adjusted series
#'   (default `TRUE`) or non-seasonally adjusted (`FALSE`).
#' @param cache Logical. Use cached data if available (default `TRUE`).
#'
#' @return A data frame with columns:
#'   \describe{
#'     \item{date}{Date. End of month.}
#'     \item{approvals}{Numeric. Number of mortgage approvals.}
#'   }
#'
#' @source
#' <https://www.bankofengland.co.uk/boeapps/database/>
#'
#' @examples
#' \donttest{
#' op <- options(boe.cache_dir = tempdir())
#' boe_mortgage_approvals(from = "2015-01-01")
#' options(op)
#' }
#'
#' @family credit and housing
#' @export
boe_mortgage_approvals <- function(from                 = "1993-04-01",
                                   to                   = Sys.Date(),
                                   seasonally_adjusted  = TRUE,
                                   cache                = TRUE) {

  code <- if (seasonally_adjusted) "LPMVTVX" else "LPMVTVU"

  from <- parse_date_arg(from, "from")
  to   <- parse_date_arg(to, "to")

  out <- boe_fetch(code, from = from, to = to, cache = cache)

  result <- data.frame(
    date      = out$date,
    approvals = out$value,
    stringsAsFactors = FALSE
  )

  cli::cli_progress_done()
  result
}
