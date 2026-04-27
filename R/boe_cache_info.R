#' Inspect the local BoE cache
#'
#' Reports the cache directory, number of cached files, total size,
#' and oldest / newest modification timestamps. Prints a short summary
#' and returns the underlying values invisibly.
#'
#' The cache directory defaults to `tools::R_user_dir("boe", "cache")`
#' and can be overridden with `options(boe.cache_dir = ...)`.
#'
#' @return Invisibly, a list with elements:
#'   \describe{
#'     \item{path}{Character. Cache directory.}
#'     \item{n_files}{Integer. Number of cached files.}
#'     \item{total_size_bytes}{Numeric. Total size on disk (bytes).}
#'     \item{oldest}{POSIXct. Modification time of oldest file (or
#'       `NA` if cache is empty).}
#'     \item{newest}{POSIXct. Modification time of newest file (or
#'       `NA` if cache is empty).}
#'   }
#'
#' @examples
#' \donttest{
#' op <- options(boe.cache_dir = tempdir())
#' boe_cache_info()
#' options(op)
#' }
#'
#' @family cache
#' @seealso [clear_cache()]
#' @export
boe_cache_info <- function() {
  dir   <- boe_cache_dir()
  files <- if (dir.exists(dir)) {
    list.files(dir, full.names = TRUE)
  } else {
    character(0L)
  }
  n      <- length(files)
  info   <- if (n) file.info(files) else NULL
  size   <- if (n) sum(info$size, na.rm = TRUE) else 0
  oldest <- if (n) min(info$mtime, na.rm = TRUE) else as.POSIXct(NA)
  newest <- if (n) max(info$mtime, na.rm = TRUE) else as.POSIXct(NA)

  msg <- c(
    "BoE cache",
    "*" = sprintf("Path:  %s", dir),
    "*" = sprintf("Files: %d", n),
    "*" = sprintf("Size:  %s", format_cache_size(size))
  )
  if (n) {
    msg <- c(msg, "*" = sprintf("Range: %s to %s",
                                format(oldest), format(newest)))
  }
  cli::cli_inform(msg)

  invisible(list(
    path             = dir,
    n_files          = n,
    total_size_bytes = as.numeric(size),
    oldest           = oldest,
    newest           = newest
  ))
}

#' Format a byte count as a human-readable string
#' @noRd
format_cache_size <- function(bytes) {
  if (is.na(bytes) || bytes < 0) return(NA_character_)
  if (bytes < 1024)        return(sprintf("%d B", as.integer(bytes)))
  if (bytes < 1024^2)      return(sprintf("%.1f KB", bytes / 1024))
  if (bytes < 1024^3)      return(sprintf("%.1f MB", bytes / 1024^2))
  sprintf("%.1f GB", bytes / 1024^3)
}
