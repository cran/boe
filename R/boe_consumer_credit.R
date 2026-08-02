#' Download consumer credit outstanding
#'
#' Downloads monthly outstanding amounts of consumer credit (total,
#' credit cards, and other consumer credit). Seasonally adjusted.
#' Available from April 1993.
#'
#' By default the headline measure excluding the Student Loans Company
#' is returned. This is the measure updated every month in the Bank's
#' Money and Credit release. The alternative measure including student
#' loans is only updated once a year, when the Student Loans Company
#' publishes its data, so its recent months lag the headline measure by
#' up to a year; request it with `include_student_loans = TRUE`.
#'
#' @param type Character vector. One or more of `"total"`, `"credit_card"`,
#'   `"other"`. Defaults to all three.
#' @param from Date or character (YYYY-MM-DD). Start date. Defaults to
#'   `"1993-04-01"`.
#' @param to Date or character (YYYY-MM-DD). End date. Defaults to today.
#' @param cache Logical. Use cached data if available (default `TRUE`).
#' @param include_student_loans Logical. If `FALSE` (default), the
#'   monthly headline series excluding the Student Loans Company are
#'   used (`LPMBI2O`, `LPMVZRJ`, `LPMB4TS`). If `TRUE`, the annually
#'   updated series including student loans are used (`LPMVZRI`,
#'   `LPMVZRJ`, `LPMVZRK`); note their most recent months trail the
#'   headline measure. Credit cards are identical under both measures.
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
#' op <- options(boe.cache_dir = tempdir())
#' boe_consumer_credit(from = "2015-01-01")
#' options(op)
#' }
#'
#' @family credit and housing
#' @export
boe_consumer_credit <- function(type  = c("total", "credit_card", "other"),
                                from  = "1993-04-01",
                                to    = Sys.Date(),
                                cache = TRUE,
                                include_student_loans = FALSE) {

  type <- match.arg(type, several.ok = TRUE)

  code_map <- if (isTRUE(include_student_loans)) {
    c(
      "total"       = "LPMVZRI",
      "credit_card" = "LPMVZRJ",
      "other"       = "LPMVZRK"
    )
  } else {
    c(
      "total"       = "LPMBI2O",
      "credit_card" = "LPMVZRJ",
      "other"       = "LPMB4TS"
    )
  }

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
  new_boe_tbl(result, query = list(
    series_codes  = unname(codes),
    from          = from,
    to            = to,
    frequency     = "monthly",
    function_name = "boe_consumer_credit"
  ))
}
