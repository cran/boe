#' Search the BoE series catalogue
#'
#' Filters the [boe_series] catalogue by keyword and optional category
#' and frequency. Useful for finding a series code without leaving R.
#' Equivalent to a `grepl` against the title and code columns.
#'
#' @param query Character. Keyword(s) to match against the `title` and
#'   `code` columns. Case-insensitive substring match. If `NULL`,
#'   returns all rows (subject to other filters).
#' @param category Character. Optional filter on the `category` column,
#'   one or more of `"interest_rates"`, `"exchange_rates"`,
#'   `"mortgage_market"`, `"consumer_credit"`, `"monetary_aggregates"`.
#' @param frequency Character. Optional filter on the `frequency`
#'   column, one or more of `"daily"`, `"monthly"`, `"annual"`.
#'
#' @return A data frame with the same columns as [boe_series],
#'   restricted to matching rows.
#'
#' @examples
#' # Find mortgage-related series
#' boe_search("mortgage")
#'
#' # All daily interest-rate series
#' boe_search(category = "interest_rates", frequency = "daily")
#'
#' # Locate the Bank Rate code
#' boe_search("bank rate")
#'
#' @family discovery
#' @seealso [boe_browse()], [boe_series]
#' @export
boe_search <- function(query     = NULL,
                       category  = NULL,
                       frequency = NULL) {

  out <- get("boe_series", envir = asNamespace("boe"))

  if (!is.null(query)) {
    if (!is.character(query)) {
      cli::cli_abort("{.arg query} must be a character string.")
    }
    q <- tolower(paste(query, collapse = " "))
    hay <- tolower(paste(out$title, out$code))
    out <- out[grepl(q, hay, fixed = TRUE), , drop = FALSE]
  }
  if (!is.null(category)) {
    out <- out[out$category %in% category, , drop = FALSE]
  }
  if (!is.null(frequency)) {
    out <- out[out$frequency %in% frequency, , drop = FALSE]
  }

  rownames(out) <- NULL
  out
}


#' Browse the BoE series catalogue
#'
#' Returns the catalogue with optional category or frequency filters.
#' Equivalent to `boe_search(query = NULL, category, frequency)` but
#' framed as a browse / inspect action rather than a keyword search.
#'
#' @inheritParams boe_search
#' @return A data frame with the same columns as [boe_series].
#'
#' @examples
#' # The whole catalogue
#' nrow(boe_browse())
#'
#' # All exchange rate series
#' boe_browse(category = "exchange_rates")
#'
#' # All monthly series
#' boe_browse(frequency = "monthly")
#'
#' @family discovery
#' @seealso [boe_search()], [boe_series]
#' @export
boe_browse <- function(category = NULL, frequency = NULL) {
  boe_search(query = NULL, category = category, frequency = frequency)
}
