# S3 class for Bank of England query results.

#' Construct a boe_tbl
#'
#' Internal constructor for the `boe_tbl` S3 class. Wraps a data frame
#' with provenance metadata so downstream users can trace any returned
#' table back to the BoE series, date range, and request that produced
#' it.
#'
#' @param df A data frame.
#' @param query A list of query metadata. Recognised fields include
#'   `series_codes`, `from`, `to`, `frequency`, `function_name`,
#'   `source_url`, `fetched_at`, `vintage`.
#' @return A `boe_tbl`, which is a subclass of `data.frame`.
#' @noRd
new_boe_tbl <- function(df, query = list()) {
  if (!is.data.frame(df)) {
    df <- as.data.frame(df, stringsAsFactors = FALSE)
  }
  if (is.null(query$fetched_at)) {
    query$fetched_at <- Sys.time()
  }
  attr(df, "boe_query") <- query
  class(df) <- c("boe_tbl", "data.frame")
  df
}


#' Print method for boe_tbl
#'
#' Adds a one-line provenance header above the data frame body. The
#' header summarises the request: number of series (and codes if few),
#' observation count, date range, frequency, and any vintage tag.
#'
#' @param x A `boe_tbl`.
#' @param ... Passed to the underlying `print.data.frame` method.
#' @return `x`, invisibly.
#' @examples
#' \donttest{
#' op <- options(boe.cache_dir = tempdir())
#' x <- boe_bank_rate(from = "2020-01-01", frequency = "monthly")
#' print(x)
#' options(op)
#' }
#' @export
print.boe_tbl <- function(x, ...) {
  q <- attr(x, "boe_query")
  parts <- character(0L)

  if (!is.null(q$series_codes)) {
    codes <- unname(q$series_codes)
    n <- length(codes)
    label <- sprintf("%d series", n)
    if (n >= 1L && n <= 5L) {
      label <- paste0(label, " [", paste(codes, collapse = ","), "]")
    }
    parts <- c(parts, label)
  }

  parts <- c(parts, sprintf("%d obs", nrow(x)))

  if (!is.null(q$from) && !is.null(q$to)) {
    parts <- c(parts, sprintf("%s to %s",
                              format(as.Date(q$from)),
                              format(as.Date(q$to))))
  }
  if (!is.null(q$frequency) && nzchar(q$frequency)) {
    parts <- c(parts, paste0("freq=", q$frequency))
  }
  if (!is.null(q$vintage) && nzchar(q$vintage)) {
    parts <- c(parts, paste0("as_of=", q$vintage))
  }

  header <- if (!is.null(q$function_name) && nzchar(q$function_name)) {
    sprintf("# BoE [%s]: %s", q$function_name,
            paste(parts, collapse = " \u00b7 "))
  } else {
    sprintf("# BoE: %s", paste(parts, collapse = " \u00b7 "))
  }
  cat(header, "\n", sep = "")
  NextMethod()
}
