#' Catalogue of BoE series wrapped by this package
#'
#' A reference data frame of Bank of England Statistical Database series
#' codes for which the package provides a named convenience function.
#' Used by [boe_search()] and [boe_browse()].
#'
#' @format A data frame with 8 columns:
#' \describe{
#'   \item{code}{Character. BoE series code (e.g. `"IUDBEDR"`).}
#'   \item{title}{Character. Human-readable description.}
#'   \item{category}{Character. Topic grouping. One of `"interest_rates"`,
#'     `"exchange_rates"`, `"mortgage_market"`, `"consumer_credit"`,
#'     `"monetary_aggregates"`.}
#'   \item{frequency}{Character. Native publication frequency
#'     (`"daily"`, `"monthly"`, `"annual"`).}
#'   \item{unit}{Character. Unit of measurement (`"percent"`,
#'     `"millions_gbp"`, `"currency_per_gbp"`, `"index"`, `"count"`).}
#'   \item{start_date}{Date. Earliest available observation date.}
#'   \item{seasonal_adjustment}{Character or `NA`. `"SA"`, `"NSA"`, or
#'     `NA` if not applicable.}
#'   \item{helper}{Character. Convenience function in the package that
#'     wraps the series.}
#' }
#'
#' @source <https://www.bankofengland.co.uk/boeapps/database/>
#' @examples
#' head(boe_series)
#' table(boe_series$category)
"boe_series"
