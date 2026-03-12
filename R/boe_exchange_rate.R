#' Download sterling exchange rates
#'
#' Downloads daily spot exchange rates for sterling against major currencies
#' from the Bank of England. Most series available from January 1975.
#'
#' @param currency Character vector. One or more currency codes. Use
#'   [list_exchange_rates()] to see all available currencies. Defaults to
#'   `"USD"`.
#' @param from Date or character (YYYY-MM-DD). Start date. Defaults to
#'   `"1975-01-02"`.
#' @param to Date or character (YYYY-MM-DD). End date. Defaults to today.
#' @param cache Logical. Use cached data if available (default `TRUE`).
#'
#' @return A data frame with columns:
#'   \describe{
#'     \item{date}{Date. Observation date.}
#'     \item{currency}{Character. Currency code (e.g. `"USD"`).}
#'     \item{rate}{Numeric. Units of foreign currency per GBP.}
#'   }
#'
#' @source
#' <https://www.bankofengland.co.uk/boeapps/database/>
#'
#' @examples
#' \donttest{
#' # GBP/USD since 2020
#' boe_exchange_rate("USD", from = "2020-01-01")
#'
#' # Multiple currencies
#' boe_exchange_rate(c("USD", "EUR", "JPY"), from = "2020-01-01")
#' }
#'
#' @export
boe_exchange_rate <- function(currency = "USD",
                              from     = "1975-01-02",
                              to       = Sys.Date(),
                              cache    = TRUE) {

  fx_map <- fx_code_map()
  currency <- toupper(currency)

  bad <- setdiff(currency, names(fx_map))
  if (length(bad) > 0) {
    cli::cli_abort(c(
      "Unknown currenc{?y/ies}: {.val {bad}}",
      "i" = "Use {.code list_exchange_rates()} to see available currencies."
    ))
  }

  codes <- fx_map[currency]

  from <- parse_date_arg(from, "from")
  to   <- parse_date_arg(to, "to")

  out <- boe_fetch(codes, from = from, to = to, cache = cache)

  # Map codes back to currency labels
  code_to_ccy <- stats::setNames(names(codes), codes)
  out$currency <- code_to_ccy[out$code]

  result <- data.frame(
    date     = out$date,
    currency = out$currency,
    rate     = out$value,
    stringsAsFactors = FALSE
  )

  result <- result[order(result$currency, result$date), ]
  rownames(result) <- NULL

  cli::cli_progress_done()
  result
}


#' List available exchange rate currencies
#'
#' Returns a data frame of currency codes and descriptions available
#' from the Bank of England exchange rate series.
#'
#' @return A data frame with columns:
#'   \describe{
#'     \item{currency}{Character. ISO currency code.}
#'     \item{description}{Character. Currency name.}
#'     \item{boe_code}{Character. BoE series code.}
#'   }
#'
#' @examples
#' list_exchange_rates()
#'
#' @export
list_exchange_rates <- function() {
  codes <- fx_code_map()
  descs <- fx_descriptions()
  data.frame(
    currency    = names(codes),
    description = descs[names(codes)],
    boe_code    = unname(codes),
    stringsAsFactors = FALSE,
    row.names   = NULL
  )
}


#' @noRd
fx_code_map <- function() {
  c(
    "USD" = "XUDLGBD",
    "EUR" = "XUDLERS",
    "JPY" = "XUDLJYS",
    "CHF" = "XUDLSFS",
    "AUD" = "XUDLADS",
    "CAD" = "XUDLCDS",
    "NZD" = "XUDLNDS",
    "SEK" = "XUDLSKS",
    "NOK" = "XUDLNKS",
    "DKK" = "XUDLDKS",
    "CNY" = "XUDLBK89",
    "INR" = "XUDLBK97",
    "HKD" = "XUDLHDS",
    "SGD" = "XUDLSGS",
    "KRW" = "XUDLBK93",
    "ZAR" = "XUDLZRS",
    "TRY" = "XUDLBK95",
    "PLN" = "XUDLBK47",
    "CZK" = "XUDLBK27",
    "HUF" = "XUDLBK35",
    "ILS" = "XUDLBK65",
    "SAR" = "XUDLSRS",
    "THB" = "XUDLBK87",
    "TWD" = "XUDLTWS",
    "BRL" = "XUDLB8KL",
    "MYR" = "XUDLBK83",
    "ERI" = "XUDLBK67"
  )
}


#' @noRd
fx_descriptions <- function() {
  c(
    "USD" = "US Dollar",
    "EUR" = "Euro",
    "JPY" = "Japanese Yen",
    "CHF" = "Swiss Franc",
    "AUD" = "Australian Dollar",
    "CAD" = "Canadian Dollar",
    "NZD" = "New Zealand Dollar",
    "SEK" = "Swedish Krona",
    "NOK" = "Norwegian Krone",
    "DKK" = "Danish Krone",
    "CNY" = "Chinese Yuan",
    "INR" = "Indian Rupee",
    "HKD" = "Hong Kong Dollar",
    "SGD" = "Singapore Dollar",
    "KRW" = "South Korean Won",
    "ZAR" = "South African Rand",
    "TRY" = "Turkish Lira",
    "PLN" = "Polish Zloty",
    "CZK" = "Czech Koruna",
    "HUF" = "Hungarian Forint",
    "ILS" = "Israeli Shekel",
    "SAR" = "Saudi Riyal",
    "THB" = "Thai Baht",
    "TWD" = "Taiwan Dollar",
    "BRL" = "Brazilian Real",
    "MYR" = "Malaysian Ringgit",
    "ERI" = "Sterling Effective Exchange Rate Index"
  )
}
