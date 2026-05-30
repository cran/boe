#' Wide panel of BoE yield curve at chosen pillar maturities
#'
#' Convenience wrapper around `boe_curve()` that returns a wide-format
#' panel: one row per date, one column per requested pillar maturity.
#' This is the form most users want for time-series modelling and quick
#' plotting.
#'
#' For each requested pillar, the function picks the published maturity
#' closest to the request (within a 0.05-year tolerance) and uses that.
#' The standard grid steps in 0.5-year increments and the short-end grid
#' (`segment = "short"`) in monthly increments, so pillars at integer,
#' half-integer, or whole-month maturities align exactly.
#'
#' @inheritParams boe_curve
#' @param maturities Numeric vector of pillar maturities in years. When
#'   `NULL` (default) a sensible set is chosen for the segment:
#'   `c(0.5, 1, 2, 5, 10, 20)` for `"standard"` and
#'   `c(0.5, 1, 2, 3, 5)` for `"short"`. Pillars not on the published grid
#'   for the chosen curve and segment are dropped with a warning.
#'
#' @return A `boe_tbl` data frame with columns `date` and one numeric
#'   column per pillar named like `m0.5`, `m1`, `m2`, `m5`, `m10`, `m20`.
#'
#' @examples
#' \donttest{
#' if (requireNamespace("readxl", quietly = TRUE)) {
#'   op <- options(boe.cache_dir = tempdir())
#'   # Latest month: wide panel at chosen pillar maturities
#'   panel <- boe_curve_panel(curve = "nominal", measure = "spot",
#'                            maturities = c(2, 5, 10, 20))
#'   head(panel)
#'   options(op)
#' }
#' }
#'
#' \dontrun{
#' # Historical panel (multi-decade archive download; not run automatically)
#' hist <- boe_curve_panel(curve = "nominal", measure = "spot",
#'                         from = "2020-01-01", maturities = c(2, 5, 10, 20))
#' }
#'
#' @family interest rates
#' @export
boe_curve_panel <- function(curve       = c("nominal", "real", "inflation", "ois", "blc"),
                            measure     = c("spot", "forward"),
                            segment     = c("standard", "short"),
                            frequency   = c("daily", "monthly"),
                            from        = NULL,
                            to          = NULL,
                            maturities  = NULL,
                            cache       = TRUE,
                            cache_ttl_h = NULL) {

  curve     <- match.arg(curve)
  measure   <- match.arg(measure)
  segment   <- match.arg(segment)
  frequency <- match.arg(frequency)

  if (is.null(maturities)) {
    maturities <- if (segment == "short") c(0.5, 1, 2, 3, 5)
                  else                     c(0.5, 1, 2, 5, 10, 20)
  }
  if (!is.numeric(maturities) || any(maturities <= 0)) {
    cli::cli_abort("{.arg maturities} must be a positive numeric vector.")
  }
  maturities <- sort(unique(maturities))

  long <- boe_curve(
    curve       = curve,
    measure     = measure,
    segment     = segment,
    frequency   = frequency,
    from        = from,
    to          = to,
    cache       = cache,
    cache_ttl_h = cache_ttl_h
  )

  if (nrow(long) == 0L) {
    out <- data.frame(date = as.Date(character()))
    for (m in maturities) out[[sprintf("m%g", m)]] <- numeric()
    return(new_boe_tbl(out, query = c(attr(long, "boe_query"),
                                      list(maturities = maturities))))
  }

  available <- sort(unique(long$maturity_years))
  matched <- vapply(maturities, function(m) {
    diffs <- abs(available - m)
    if (min(diffs) > 0.05) return(NA_real_)
    available[which.min(diffs)]
  }, numeric(1))

  # Drop pillars off the published grid, but keep the requested pillar
  # labels aligned with the maturities they matched (filtering both with
  # the same mask) so surviving columns are never mislabelled.
  keep        <- !is.na(matched)
  if (any(!keep)) {
    dropped <- maturities[!keep]
    cli::cli_warn(c(
      "{length(dropped)} requested pillar{?s} not on the {curve} {segment} grid; dropped: {.val {dropped}}.",
      "i" = "Available maturities span {.val {min(available)}} to {.val {max(available)}} years."
    ))
  }
  pillars     <- maturities[keep]
  matched_mat <- matched[keep]
  if (length(matched_mat) == 0L) {
    cli::cli_abort("None of the requested pillars matched the published grid.")
  }

  dates <- sort(unique(long$date))
  out <- data.frame(date = dates, stringsAsFactors = FALSE)

  for (i in seq_along(matched_mat)) {
    m <- matched_mat[[i]]
    label <- sprintf("m%g", pillars[[i]])
    sub <- long[abs(long$maturity_years - m) < 1e-8, c("date", "rate_pct"),
                drop = FALSE]
    out[[label]] <- sub$rate_pct[match(out$date, sub$date)]
  }

  q <- attr(long, "boe_query")
  q$maturities    <- maturities
  q$function_name <- "boe_curve_panel"

  new_boe_tbl(out, query = q)
}
