#' Download quoted mortgage interest rates
#'
#' Downloads monthly quoted (advertised) mortgage rates from the Bank of
#' England, including fixed-rate products and the standard variable rate
#' (SVR). Available from January 1995.
#'
#' @param type Character vector. One or more of `"2yr_fixed"`,
#'   `"3yr_fixed"`, `"5yr_fixed"`, `"svr"`. Defaults to all four.
#' @param from Date or character (YYYY-MM-DD). Start date. Defaults to
#'   `"1995-01-01"`.
#' @param to Date or character (YYYY-MM-DD). End date. Defaults to today.
#' @param cache Logical. Use cached data if available (default `TRUE`).
#'
#' @return A data frame with columns:
#'   \describe{
#'     \item{date}{Date. End of month.}
#'     \item{type}{Character. Mortgage product type.}
#'     \item{rate_pct}{Numeric. Quoted rate (percent).}
#'   }
#'
#' @source
#' <https://www.bankofengland.co.uk/boeapps/database/>
#'
#' @examples
#' \donttest{
#' op <- options(boe.cache_dir = tempdir())
#' # All mortgage rate types since 2015
#' boe_mortgage_rates(from = "2015-01-01")
#'
#' # 2-year fixed only
#' boe_mortgage_rates(type = "2yr_fixed", from = "2020-01-01")
#' options(op)
#' }
#'
#' @family credit and housing
#' @export
boe_mortgage_rates <- function(type  = c("2yr_fixed", "3yr_fixed", "5yr_fixed", "svr"),
                               from  = "1995-01-01",
                               to    = Sys.Date(),
                               cache = TRUE) {

  type <- match.arg(type, several.ok = TRUE)

  code_map <- c(
    "2yr_fixed" = "IUMBV34",
    "3yr_fixed" = "IUMBV37",
    "5yr_fixed" = "IUMBV42",
    "svr"       = "IUMTLMV"
  )

  codes <- code_map[type]

  from <- parse_date_arg(from, "from")
  to   <- parse_date_arg(to, "to")

  out <- boe_fetch(codes, from = from, to = to, cache = cache)

  code_to_type <- stats::setNames(names(codes), codes)
  out$type <- code_to_type[out$code]

  result <- data.frame(
    date     = out$date,
    type     = out$type,
    rate_pct = out$value,
    stringsAsFactors = FALSE
  )

  result <- result[order(result$type, result$date), ]
  rownames(result) <- NULL

  cli::cli_progress_done()
  result
}
