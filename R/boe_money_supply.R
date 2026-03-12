#' Download M4 money supply
#'
#' Downloads monthly M4 (broad money) amounts outstanding from the Bank
#' of England. Available from June 1982.
#'
#' @param from Date or character (YYYY-MM-DD). Start date. Defaults to
#'   `"1982-06-01"`.
#' @param to Date or character (YYYY-MM-DD). End date. Defaults to today.
#' @param seasonally_adjusted Logical. Return seasonally adjusted series
#'   (default `TRUE`) or non-seasonally adjusted (`FALSE`).
#' @param cache Logical. Use cached data if available (default `TRUE`).
#'
#' @return A data frame with columns:
#'   \describe{
#'     \item{date}{Date. End of month.}
#'     \item{amount_gbp_m}{Numeric. M4 amounts outstanding (millions of
#'       pounds).}
#'   }
#'
#' @source
#' <https://www.bankofengland.co.uk/boeapps/database/>
#'
#' @examples
#' \donttest{
#' boe_money_supply(from = "2000-01-01")
#' }
#'
#' @export
boe_money_supply <- function(from                = "1982-06-01",
                             to                  = Sys.Date(),
                             seasonally_adjusted = TRUE,
                             cache               = TRUE) {

  code <- if (seasonally_adjusted) "LPMAUYN" else "LPMAUYM"

  from <- parse_date_arg(from, "from")
  to   <- parse_date_arg(to, "to")

  out <- boe_fetch(code, from = from, to = to, cache = cache)

  result <- data.frame(
    date         = out$date,
    amount_gbp_m = out$value,
    stringsAsFactors = FALSE
  )

  cli::cli_progress_done()
  result
}
