#' Clear locally cached Bank of England data
#'
#' Removes cached data files downloaded from the Bank of England.
#'
#' @param max_age_days Numeric or `NULL`. If specified, only removes files
#'   older than this many days. If `NULL` (the default), removes all
#'   cached files.
#'
#' @return Invisibly returns the number of files removed.
#'
#' @examples
#' \donttest{
#' # Remove files older than 7 days
#' clear_cache(max_age_days = 7)
#'
#' # Remove everything
#' clear_cache()
#' }
#'
#' @export
clear_cache <- function(max_age_days = NULL) {
  cache_dir <- tools::R_user_dir("boe", "cache")

  if (!dir.exists(cache_dir)) {
    cli::cli_alert_info("No cache directory found.")
    return(invisible(0L))
  }

  files <- list.files(cache_dir, full.names = TRUE)

  if (length(files) == 0) {
    cli::cli_alert_info("Cache is empty.")
    return(invisible(0L))
  }

  if (!is.null(max_age_days)) {
    info    <- file.info(files)
    age     <- difftime(Sys.time(), info$mtime, units = "days")
    files   <- files[age > max_age_days]
  }

  if (length(files) == 0) {
    cli::cli_alert_info("No files older than {max_age_days} day{?s}.")
    return(invisible(0L))
  }

  unlink(files)
  cli::cli_alert_success("Removed {length(files)} cached file{?s}.")
  invisible(length(files))
}
