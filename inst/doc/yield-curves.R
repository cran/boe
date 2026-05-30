## ----setup, include = FALSE---------------------------------------------------
library(boe)
not_on_cran <- identical(Sys.getenv("NOT_CRAN"), "true")
knitr::opts_chunk$set(
  collapse = TRUE,
  comment  = "#>",
  fig.width  = 7,
  fig.height = 4.5,
  eval = not_on_cran
)
op <- options(boe.cache_dir = tempfile("boe_vignette_"))

## ----latest-------------------------------------------------------------------
# latest <- boe_curve(curve = "nominal", measure = "spot")
# range(latest$date)
# range(latest$maturity_years)

## ----latest-provenance--------------------------------------------------------
# attr(latest, "boe_query")$source
# attr(latest, "boe_query")$series_codes

## ----hist-10y-----------------------------------------------------------------
# panel <- boe_curve_panel(
#   curve     = "nominal",
#   measure   = "spot",
#   frequency = "monthly",
#   from      = "2000-01-01",
#   maturities = c(2, 5, 10, 20)
# )
# head(panel)

## ----hist-10y-plot, fig.alt = "10-year UK nominal spot rate, 2000 to present"----
# if (requireNamespace("ggplot2", quietly = TRUE)) {
#   ggplot2::ggplot(panel, ggplot2::aes(date, m10)) +
#     ggplot2::geom_line(colour = "#1f77b4") +
#     ggplot2::labs(
#       title    = "UK 10-year nominal spot rate",
#       subtitle = "End of month, Anderson-Sleath fitted",
#       x = NULL, y = "Per cent"
#     ) +
#     ggplot2::theme_minimal()
# }

## ----five-five----------------------------------------------------------------
# inflation_fwd <- boe_curve_panel(
#   curve     = "inflation",
#   measure   = "forward",
#   frequency = "monthly",
#   from      = "2010-01-01",
#   maturities = c(5, 10)
# )
# 
# inflation_fwd$five_y_five_y <- (inflation_fwd$m10 * 10 -
#                                 inflation_fwd$m5  *  5) / 5
# head(inflation_fwd[, c("date", "m5", "m10", "five_y_five_y")])

## ----five-five-plot, fig.alt = "UK 5y5y forward implied inflation, 2010 to present"----
# if (requireNamespace("ggplot2", quietly = TRUE)) {
#   ggplot2::ggplot(inflation_fwd, ggplot2::aes(date, five_y_five_y)) +
#     ggplot2::geom_line(colour = "#d62728") +
#     ggplot2::geom_hline(yintercept = 2.0, linetype = "dashed",
#                         colour = "grey40") +
#     ggplot2::annotate("text", x = max(inflation_fwd$date),
#                       y = 2.0, label = "2% target", hjust = 1, vjust = -0.5,
#                       colour = "grey40", size = 3) +
#     ggplot2::labs(
#       title    = "UK 5y5y forward implied inflation",
#       subtitle = "End of month, derived from the BoE implied-inflation forward curve",
#       x = NULL, y = "Per cent per annum"
#     ) +
#     ggplot2::theme_minimal()
# }

## ----ois-cycle----------------------------------------------------------------
# ois <- boe_curve_panel(
#   curve     = "ois",
#   measure   = "spot",
#   frequency = "monthly",
#   from      = "2020-01-01",
#   maturities = c(0.5, 1, 2, 5)
# )
# 
# mpc <- boe_mpc_decisions(from = "2020-01-01")
# mpc <- data.frame(date = mpc$date, bank_rate = mpc$new_rate_pct)
# 
# merged <- merge(ois, mpc, by = "date", all.x = TRUE)
# merged$bank_rate <- as.numeric(merged$bank_rate)
# 
# # carry the bank rate forward between MPC dates
# for (i in seq_along(merged$bank_rate)) {
#   if (i > 1 && is.na(merged$bank_rate[i])) {
#     merged$bank_rate[i] <- merged$bank_rate[i - 1]
#   }
# }
# tail(merged)

## ----ois-cycle-plot, fig.alt = "UK OIS spot pillars and Bank Rate, 2020 to present"----
# if (requireNamespace("ggplot2", quietly = TRUE)) {
#   long <- data.frame(
#     date  = rep(merged$date, 5),
#     pillar = rep(c("Bank Rate", "6m OIS", "1y OIS", "2y OIS", "5y OIS"),
#                  each = nrow(merged)),
#     rate  = c(merged$bank_rate, merged$m0.5, merged$m1, merged$m2, merged$m5)
#   )
#   long$pillar <- factor(long$pillar,
#                         levels = c("Bank Rate", "6m OIS", "1y OIS",
#                                    "2y OIS", "5y OIS"))
# 
#   ggplot2::ggplot(long, ggplot2::aes(date, rate, colour = pillar)) +
#     ggplot2::geom_line() +
#     ggplot2::labs(
#       title    = "UK OIS spot pillars and Bank Rate, 2020 to present",
#       subtitle = "Tightening cycle visible across all pillars",
#       x = NULL, y = "Per cent", colour = NULL
#     ) +
#     ggplot2::theme_minimal() +
#     ggplot2::theme(legend.position = "bottom")
# }

## ----short-end----------------------------------------------------------------
# short <- boe_curve(curve = "nominal", measure = "spot", segment = "short")
# range(short$maturity_years)   # monthly grid, ~1/12 to 5 years

## ----short-ois----------------------------------------------------------------
# ois_short  <- boe_curve(curve = "ois", measure = "forward", segment = "short")
# latest_day <- ois_short[ois_short$date == max(ois_short$date), ]
# head(latest_day)

## ----short-ois-plot, fig.alt = "UK OIS short-end forward curve on the latest published date"----
# if (requireNamespace("ggplot2", quietly = TRUE)) {
#   ggplot2::ggplot(latest_day, ggplot2::aes(maturity_years, rate_pct)) +
#     ggplot2::geom_line(colour = "#1f77b4") +
#     ggplot2::geom_point(size = 0.8, colour = "#1f77b4") +
#     ggplot2::labs(
#       title    = "UK OIS instantaneous forward curve, short end",
#       subtitle = paste("Market-implied Bank Rate path on",
#                        format(max(ois_short$date), "%d %B %Y")),
#       x = "Horizon (years)", y = "Per cent"
#     ) +
#     ggplot2::theme_minimal()
# }

## ----teardown, include = FALSE------------------------------------------------
# options(op)

