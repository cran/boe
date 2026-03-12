#' Fetch any series from the Bank of England Statistical Database
#'
#' The core data retrieval function. Fetches one or more series by their
#' BoE series codes and returns a tidy data frame. Use this when the
#' convenience functions (e.g. [boe_bank_rate()], [boe_exchange_rate()])
#' do not cover the series you need.
#'
#' Series codes can be found via the Bank of England Interactive
#' Statistical Database at
#' <https://www.bankofengland.co.uk/boeapps/database/>.
#'
#' @param series_codes Character vector of one or more BoE series codes.
#' @param from Date or character (YYYY-MM-DD). Start date. Defaults to
#'   `"1960-01-01"`.
#' @param to Date or character (YYYY-MM-DD). End date. Defaults to today.
#' @param cache Logical. Use cached data if available (default `TRUE`).
#'
#' @return A data frame with columns:
#'   \describe{
#'     \item{date}{Date. Observation date.}
#'     \item{code}{Character. BoE series code.}
#'     \item{value}{Numeric. Observation value.}
#'   }
#'
#' @source
#' <https://www.bankofengland.co.uk/boeapps/database/>
#'
#' @examples
#' \donttest{
#' # Bank Rate since 2000
#' boe_get("IUDBEDR", from = "2000-01-01")
#'
#' # Multiple series
#' boe_get(c("IUDBEDR", "IUDSOIA"), from = "2020-01-01")
#' }
#'
#' @export
boe_get <- function(series_codes,
                    from  = "1960-01-01",
                    to    = Sys.Date(),
                    cache = TRUE) {

  if (length(series_codes) == 0 || !is.character(series_codes)) {
    cli::cli_abort("{.arg series_codes} must be a character vector of BoE series codes.")
  }
  if (length(series_codes) > 300) {
    cli::cli_abort("The BoE API supports a maximum of 300 series per request.")
  }

  from <- parse_date_arg(from, "from")
  to   <- parse_date_arg(to, "to")

  out <- boe_fetch(series_codes, from = from, to = to, cache = cache)

  cli::cli_progress_done()
  out
}
