# boe

[![CRAN status](https://www.r-pkg.org/badges/version/boe)](https://CRAN.R-project.org/package=boe) [![CRAN downloads](https://cranlogs.r-pkg.org/badges/boe)](https://cran.r-project.org/package=boe) [![Lifecycle: stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html#stable) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

An R package for downloading data from the [Bank of England](https://www.bankofengland.co.uk) Statistical Database.

## What is the Bank of England?

The Bank of England is the United Kingdom's central bank. Founded in 1694, it is responsible for setting monetary policy (including Bank Rate), issuing banknotes, supervising the banking system, and maintaining financial stability. Its Monetary Policy Committee meets eight times a year to set the interest rate that ripples through every mortgage, savings account, and bond in the UK economy.

The Bank publishes thousands of statistical time series through its [Interactive Statistical Database](https://www.bankofengland.co.uk/boeapps/database/) - covering interest rates, exchange rates, money and credit, gilt yields, and housing market indicators. This data underpins monetary policy analysis, financial research, and economic journalism in the UK.

## How is this different from existing packages?

The [`bbk`](https://cran.r-project.org/package=bbk) package on CRAN provides a single generic function for Bank of England data (`bbk::boe_data()`), but it is primarily a Bundesbank client - the Bank of England is one of seven central banks it covers, and its BoE support amounts to a raw API wrapper. You still need to know the series codes, and the output requires further processing.

This package is different. It is built specifically for the Bank of England and provides named, documented functions for the series people actually use - `boe_bank_rate()`, `boe_mortgage_rates()`, `boe_yield_curve()`, and so on. You don't need to know that Bank Rate is `IUDBEDR` or that a 2-year fixed mortgage rate is `IUMBV34`. The package handles series codes, date formatting, caching, and error handling internally.

## Why does this package exist?

The data is freely available, but using it programmatically requires knowing obscure series codes, constructing query URLs with a non-standard date format (`DD/Mon/YYYY`), parsing CSV responses with irregular date formats, and handling HTML error pages returned with HTTP 200 status codes. Every analyst who works with this data writes the same boilerplate.

This package replaces all of that with named functions that return clean data frames.

```r
# Without this package
url <- paste0(
  "https://www.bankofengland.co.uk/boeapps/database/",
  "_iadb-fromshowcolumns.asp?csv.x=yes",
  "&SeriesCodes=IUDBEDR&UsingCodes=Y&CSVF=TN",
  "&Datefrom=01/Jan/2020&Dateto=01/Jan/2025"
)
raw <- read.csv(url)
# ... parse dates, rename columns, handle errors ...

# With this package
library(boe)
boe_bank_rate(from = "2020-01-01")
```

---

## Installation

```r
install.packages("boe")

# Or install the development version from GitHub
# install.packages("devtools")
devtools::install_github("charlescoverdale/boe")
```

---

## Functions

| Function | Description | From | To |
|---|---|---|---|
| `boe_get()` | Fetch any series by BoE series code | Any | Present |
| `boe_bank_rate()` | Official Bank Rate (daily or monthly) | 1975 | Present |
| `boe_sonia()` | SONIA risk-free reference rate (daily, monthly, or annual) | 1997 | Present |
| `boe_yield_curve()` | Nominal and real gilt yields at 5yr, 10yr, 20yr maturities | 1985 | Present |
| `boe_exchange_rate()` | Daily sterling spot rates for 27 currencies | 1975 | Present |
| `list_exchange_rates()` | Catalogue of available currency codes | - | -|
| `boe_mortgage_rates()` | Quoted mortgage rates (2yr/3yr/5yr fixed, SVR) | 1995 | Present |
| `boe_mortgage_approvals()` | Monthly mortgage approvals for house purchase | 1993 | Present |
| `boe_consumer_credit()` | Consumer credit outstanding (total, cards, other) | 1993 | Present |
| `boe_money_supply()` | M4 broad money amounts outstanding | 1982 | Present |
| `clear_cache()` | Delete locally cached data files | - | -|

---

## Examples

### What is Bank Rate today?

```r
library(boe)

# Bank Rate since 2000
br <- boe_bank_rate(from = "2000-01-01")
tail(br, 6)
#>         date rate_pct
#>   2026-02-26     3.75
#>   2026-02-27     3.75
#>   2026-03-02     3.75
#>   2026-03-03     3.75
#>   2026-03-04     3.75
#>   2026-03-05     3.75
```

---

### How has sterling moved against other currencies?

```r
# GBP/USD and GBP/EUR
fx <- boe_exchange_rate(c("USD", "EUR"), from = "2024-01-01", to = "2024-01-31")
head(fx, 6)
#>         date currency   rate
#>   2024-01-02      EUR 1.1536
#>   2024-01-03      EUR 1.1580
#>   2024-01-04      EUR 1.1591
#>   2024-01-05      EUR 1.1615
#>   2024-01-08      EUR 1.1623
#>   2024-01-09      EUR 1.1636

# See all 27 available currencies
list_exchange_rates()
```

---

### What are gilt yields doing?

```r
# 10-year nominal gilt yield
yc <- boe_yield_curve(from = "2024-01-01", to = "2024-01-31", maturity = "10yr")
head(yc, 5)
#>         date maturity yield_pct
#>   2024-01-02     10yr    3.7190
#>   2024-01-03     10yr    3.7638
#>   2024-01-04     10yr    3.8006
#>   2024-01-05     10yr    3.8398
#>   2024-01-08     10yr    3.8619

# Full curve: 5yr, 10yr, and 20yr
boe_yield_curve(from = "2024-01-01")

# Real yields
boe_yield_curve(from = "2024-01-01", type = "real", measure = "zero_coupon")
```

---

### What are mortgage rates right now?

```r
# All mortgage rate types
mr <- boe_mortgage_rates(from = "2023-01-01")

# Latest rates (as of December 2024)
#>   2yr_fixed: 4.60%
#>   3yr_fixed: 4.48%
#>   5yr_fixed: 4.37%
#>   svr:       7.47%
```

---

### How active is the housing market?

```r
# Monthly mortgage approvals - a leading indicator of housing activity
ma <- boe_mortgage_approvals(from = "2019-01-01")
tail(ma, 6)
#>         date approvals
#>   2025-08-31     64588
#>   2025-09-30     65436
#>   2025-10-31     64634
#>   2025-11-30     64018
#>   2025-12-31     61007
#>   2026-01-31     59999
```

---

### How much are households borrowing?

```r
# Total consumer credit outstanding
cc <- boe_consumer_credit(type = "total", from = "2024-01-01")
tail(cc, 6)
#>         date  type amount_gbp_m
#>   2024-01-31 total       476154
#>   2024-02-29 total       479974
#>   2024-03-31 total       484269
#>   2024-04-30 total       490106
#>   2024-05-31 total       494904
#>   2024-06-30 total       498639

# Credit card debt only
boe_consumer_credit(type = "credit_card", from = "2024-01-01")
```

---

### How much money is in the economy?

```r
# M4 amounts outstanding
m4 <- boe_money_supply(from = "2024-01-01")
head(m4, 6)
#>         date amount_gbp_m
#>   2024-01-31      2986264
#>   2024-02-29      2999033
#>   2024-03-31      3025146
#>   2024-04-30      3030412
#>   2024-05-31      3028825
#>   2024-06-30      3044464   # ← £3 trillion
```

---

### What is the risk-free rate?

```r
# SONIA replaced LIBOR as the UK's benchmark interest rate
sonia <- boe_sonia(from = "2024-01-01", to = "2024-01-31")
head(sonia, 6)
#>         date rate_pct
#>   2024-01-02   5.1863
#>   2024-01-03   5.1863
#>   2024-01-04   5.1870
#>   2024-01-05   5.1869
#>   2024-01-08   5.1869
#>   2024-01-09   5.1867

# Monthly or annual average
boe_sonia(from = "2020-01-01", frequency = "monthly")
```

---

### Fetching any series by code

```r
# If you know the BoE series code, use boe_get() directly
# Series codes: https://www.bankofengland.co.uk/boeapps/database/

# Multiple series in one call - Bank Rate vs SONIA
boe_get(c("IUDBEDR", "IUDSOIA"), from = "2024-01-01", to = "2024-01-10")
#>          date    code  value
#>    2024-01-02 IUDBEDR 5.2500
#>    2024-01-03 IUDBEDR 5.2500
#>    2024-01-04 IUDBEDR 5.2500
#>    ...
#>    2024-01-02 IUDSOIA 5.1863
#>    2024-01-03 IUDSOIA 5.1863
#>    2024-01-04 IUDSOIA 5.1870
#>    ...
```

---

## Caching

All downloads are cached locally in your user cache directory. Subsequent calls return the cached copy instantly - no network request is made.

```r
# Force a fresh download
boe_bank_rate(from = "2020-01-01", cache = FALSE)

# Remove files older than 7 days
clear_cache(max_age_days = 7)

# Remove all cached files
clear_cache()
```

---

## Related packages

This package is part of a family of R packages for UK economic and fiscal data. They share a consistent interface - named functions, tidy data frames, local caching - and are designed to work together. All outputs join cleanly on date columns.

| Package | What it covers |
|---|---|
| [`ons`](https://github.com/charlescoverdale/ons) | ONS data (GDP, inflation, unemployment, wages, trade, house prices, population) |
| [`hmrc`](https://github.com/charlescoverdale/hmrc) | HMRC tax receipts, corporation tax, stamp duty, R&D credits, and tax gap data |
| [`obr`](https://github.com/charlescoverdale/obr) | OBR fiscal forecasts and the Public Finances Databank |
| [`readecb`](https://github.com/charlescoverdale/readecb) | European Central Bank data (policy rates, HICP, exchange rates, yield curves) |
| [`readoecd`](https://github.com/charlescoverdale/readoecd) | OECD data (GDP, unemployment, inflation, trade across 38 member countries) |
| [`fred`](https://github.com/charlescoverdale/fred) | US Federal Reserve (FRED) data (800,000+ economic time series) |
| [`inflateR`](https://github.com/charlescoverdale/inflateR) | Adjust values for inflation using CPI or GDP deflator data |

---

## Issues

Please report bugs or requests at <https://github.com/charlescoverdale/boe/issues>.

## Keywords

Bank of England, BoE, interest rates, bank rate, SONIA, yield curve, exchange rates, mortgage rates, consumer credit, money supply, monetary policy, UK economic data, R package
