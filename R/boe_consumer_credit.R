#' Download consumer credit outstanding
#'
#' Downloads monthly outstanding amounts of consumer credit (total,
#' credit cards, and other consumer credit). Seasonally adjusted.
#' Available from April 1993.
#'
#' @param type Character vector. One or more of `"total"`, `"credit_card"`,
#'   `"other"`. Defaults to all three.
#' @param from Date or character (YYYY-MM-DD). Start date. Defaults to
#'   `"1993-04-01"`.
#' @param to Date or character (YYYY-MM-DD). End date. Defaults to today.
#' @param cache Logical. Use cached data if available (default `TRUE`).
#'
#' @return A data frame with columns:
#'   \describe{
#'     \item{date}{Date. End of month.}
#'     \item{type}{Character. Credit type.}
#'     \item{amount_gbp_m}{Numeric. Outstanding amount (millions of
#'       pounds).}
#'   }
#'
#' @source
#' <https://www.bankofengland.co.uk/boeapps/database/>
#'
#' @examples
#' \donttest{
#' boe_consumer_credit(from = "2015-01-01")
#' }
#'
#' @export
boe_consumer_credit <- function(type  = c("total", "credit_card", "other"),
                                from  = "1993-04-01",
                                to    = Sys.Date(),
                                cache = TRUE) {

  type <- match.arg(type, several.ok = TRUE)

  code_map <- c(
    "total"       = "LPMVZRI",
    "credit_card" = "LPMVZRJ",
    "other"       = "LPMVZRK"
  )

  codes <- code_map[type]

  from <- parse_date_arg(from, "from")
  to   <- parse_date_arg(to, "to")

  out <- boe_fetch(codes, from = from, to = to, cache = cache)

  code_to_type <- stats::setNames(names(codes), codes)
  out$type <- code_to_type[out$code]

  result <- data.frame(
    date        = out$date,
    type        = out$type,
    amount_gbp_m = out$value,
    stringsAsFactors = FALSE
  )

  result <- result[order(result$type, result$date), ]
  rownames(result) <- NULL

  cli::cli_progress_done()
  result
}
