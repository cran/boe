#' Download UK gilt yields
#'
#' Downloads nominal or real gilt yields at specified maturities from the
#' Bank of England yield curve data. Nominal par yields are available
#' daily from late 1993; real zero-coupon yields from 1985.
#'
#' @param from Date or character (YYYY-MM-DD). Start date.
#' @param to Date or character (YYYY-MM-DD). End date. Defaults to today.
#' @param maturity Character vector. One or more of `"5yr"`, `"10yr"`,
#'   `"20yr"`. Defaults to all three.
#' @param type Character. `"nominal"` (default) or `"real"`.
#' @param measure Character. `"par_yield"` (default, nominal only) or
#'   `"zero_coupon"`.
#' @param cache Logical. Use cached data if available (default `TRUE`).
#'
#' @return A data frame with columns:
#'   \describe{
#'     \item{date}{Date. Observation date.}
#'     \item{maturity}{Character. Maturity label (e.g. `"5yr"`).}
#'     \item{yield_pct}{Numeric. Yield (percent).}
#'   }
#'
#' @source
#' <https://www.bankofengland.co.uk/boeapps/database/>
#'
#' @examples
#' \donttest{
#' # 10-year nominal gilt yield since 2020
#' boe_yield_curve(from = "2020-01-01", maturity = "10yr")
#'
#' # Full nominal curve
#' boe_yield_curve(from = "2020-01-01")
#'
#' # Real yields
#' boe_yield_curve(from = "2020-01-01", type = "real", measure = "zero_coupon")
#' }
#'
#' @export
boe_yield_curve <- function(from     = "2000-01-01",
                            to       = Sys.Date(),
                            maturity = c("5yr", "10yr", "20yr"),
                            type     = c("nominal", "real"),
                            measure  = c("par_yield", "zero_coupon"),
                            cache    = TRUE) {

  type    <- match.arg(type)
  measure <- match.arg(measure)
  maturity <- match.arg(maturity, several.ok = TRUE)

  if (type == "real" && measure == "par_yield") {
    cli::cli_abort("Real par yields are not available. Use {.code measure = \"zero_coupon\"} for real yields.")
  }

  # Build series code lookup
  code_map <- list(
    nominal_par_yield = c("5yr" = "IUDSNPY", "10yr" = "IUDMNPY", "20yr" = "IUDLNPY"),
    nominal_zero_coupon = c("5yr" = "IUDSNZC", "10yr" = "IUDMNZC", "20yr" = "IUDLNZC"),
    real_zero_coupon = c("5yr" = "IUDSRZC", "10yr" = "IUDMRZC", "20yr" = "IUDLRZC")
  )

  key   <- paste0(type, "_", measure)
  codes <- code_map[[key]][maturity]

  from <- parse_date_arg(from, "from")
  to   <- parse_date_arg(to, "to")

  out <- boe_fetch(codes, from = from, to = to, cache = cache)

  # Map codes back to maturity labels
  code_to_maturity <- stats::setNames(names(codes), codes)
  out$maturity <- code_to_maturity[out$code]

  result <- data.frame(
    date      = out$date,
    maturity  = out$maturity,
    yield_pct = out$value,
    stringsAsFactors = FALSE
  )

  result <- result[order(result$date, result$maturity), ]
  rownames(result) <- NULL

  cli::cli_progress_done()
  result
}
