# boe

[![CRAN status](https://www.r-pkg.org/badges/version/boe)](https://CRAN.R-project.org/package=boe) [![CRAN downloads](https://cranlogs.r-pkg.org/badges/boe)](https://cran.r-project.org/package=boe) [![Total Downloads](https://cranlogs.r-pkg.org/badges/grand-total/boe)](https://CRAN.R-project.org/package=boe) [![Lifecycle: stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html#stable) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

An R package for downloading data from the [Bank of England](https://www.bankofengland.co.uk) Statistical Database.

## What is the Bank of England?

The Bank of England is the United Kingdom's central bank. Founded in 1694, it is responsible for setting monetary policy (including Bank Rate), issuing banknotes, supervising the banking system, and maintaining financial stability. Its Monetary Policy Committee meets eight times a year to set the interest rate that ripples through every mortgage, savings account, and bond in the UK economy.

The Bank publishes thousands of statistical time series through its [Interactive Statistical Database](https://www.bankofengland.co.uk/boeapps/database/) - covering interest rates, exchange rates, money and credit, gilt yields, and housing market indicators. This data underpins monetary policy analysis, financial research, and economic journalism in the UK.

## How is this different from existing packages?

The [`bbk`](https://cran.r-project.org/package=bbk) package on CRAN provides a single generic function for Bank of England data (`bbk::boe_data()`), but it is primarily a Bundesbank client - the Bank of England is one of seven central banks it covers, and its BoE support amounts to a raw API wrapper. You still need to know the series codes, and the output requires further processing.

This package is different. It is built specifically for the Bank of England and provides named, documented functions for the series people actually use - `boe_bank_rate()`, `boe_mortgage_rates()`, `boe_yield_curve()`, and so on. You don't need to know that Bank Rate is `IUDBEDR` or that a 2-year fixed mortgage rate is `IUMBV34`. The package handles series codes, date formatting, caching, and error handling internally.

Beyond the IADB wrappers, it also ships:

- `boe_curve()`: the full Anderson-Sleath fitted yield curves at all maturities, with five curve types (nominal, real, implied inflation, OIS, commercial bank liability), both standard and short-end segments (`segment = "short"` for monthly steps from one month to five years), and full historical archive coverage back to 1979 (nominal), 1985 (real), 2000 (BLC), or 2009 (OIS). `boe_curve_panel()` reshapes to a wide panel at chosen pillar maturities for time-series modelling.
- `boe_search()` / `boe_browse()`: a built-in catalogue of wrapped series so you can find codes from R rather than the website.
- A `boe_tbl` S3 class so every returned data frame carries provenance metadata (series codes, date range, frequency, fetch timestamp).

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

**Data access:**

| Function | Description | From | To |
|---|---|---|---|
| `boe_get()` | Fetch any series by BoE series code | Any | Present |
| `boe_bank_rate()` | Official Bank Rate (daily or monthly) | 1975 | Present |
| `boe_sonia()` | SONIA risk-free reference rate (daily, monthly, or annual) | 1997 | Present |
| `boe_yield_curve()` | Nominal and real gilt yields at 5yr, 10yr, 20yr maturities | 1985 | Present |
| `boe_curve()` | Full Anderson-Sleath fitted curves (nominal / real / inflation / OIS / BLC; spot or forward; standard or short-end) at all maturities | 1979 | Present |
| `boe_curve_panel()` | Wide panel of `boe_curve()` at chosen pillar maturities (segment-aware defaults: 0.5y to 20y standard, 0.5y to 5y short) | 1979 | Present |
| `boe_exchange_rate()` | Daily sterling spot rates for 27 currencies | 1975 | Present |
| `boe_mortgage_rates()` | Quoted mortgage rates (2yr/3yr/5yr fixed, SVR) | 1995 | Present |
| `boe_mortgage_approvals()` | Monthly mortgage approvals for house purchase | 1993 | Present |
| `boe_consumer_credit()` | Consumer credit outstanding (total, cards, other; excluding student loans by default) | 1993 | Present |
| `boe_money_supply()` | M4 broad money amounts outstanding | 1982 | Present |

**Monetary policy:**

| Function | Description | From | To |
|---|---|---|---|
| `boe_mpc_decisions()` | MPC rate-change events: date, new rate, change in bps, direction | 1997 | Present |
| `boe_mpc_votes()` | Full MPC voting record, one row per (meeting, member), with dissent flag | 1997 | Present |
| `boe_mpr_forecasts()` | Monetary Policy Report forecast paths (CPI inflation, GDP growth, GDP level, unemployment, Bank Rate), plus scenario paths from April 2026 | 2019 | Present |

**Discovery:**

| Function | Description |
|---|---|
| `boe_series` | Exported catalogue of every wrapped series (code, title, category, frequency, unit, start date) |
| `boe_search()` | Keyword search over `boe_series` |
| `boe_browse()` | Filter `boe_series` by category or frequency |
| `list_exchange_rates()` | Currency codes available to `boe_exchange_rate()` |

**Cache:**

| Function | Description |
|---|---|
| `boe_cache_info()` | Report cache directory, file count, total size |
| `clear_cache()` | Delete locally cached data files |

---

## Examples

### What is Bank Rate today?

```r
library(boe)

# Bank Rate since 2000
br <- boe_bank_rate(from = "2000-01-01")
tail(br, 6)
#>         date rate_pct
#>   2026-07-23     3.75
#>   2026-07-24     3.75
#>   2026-07-27     3.75
#>   2026-07-28     3.75
#>   2026-07-29     3.75
#>   2026-07-30     3.75
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

### The full Anderson-Sleath fitted curve

For the complete yield curve at every published maturity (typically 0.5 years to 25 or 40 years, in 0.5-year steps), use `boe_curve()`. This parses the BoE's published Excel archive and covers five curves: nominal gilt, real (index-linked) gilt, implied inflation (breakeven), overnight index swap (OIS), and the commercial bank liability curve (BLC). Each curve is published in two segments: the standard curve and a separately fitted short end (monthly steps from one month to five years), reached with `segment = "short"`.

```r
# Latest nominal spot curve at all maturities
nc <- boe_curve(curve = "nominal", measure = "spot")
head(nc, 6)
#>         date maturity_years rate_pct
#>   2026-04-01            0.5    3.95
#>   2026-04-01            1.0    4.10
#>   2026-04-01            1.5    4.13
#>   2026-04-01            2.0    4.15
#>   2026-04-01            2.5    4.16
#>   2026-04-01            3.0    4.17

# Implied inflation curve (breakeven inflation)
boe_curve(curve = "inflation", measure = "spot")

# OIS spot curve
boe_curve(curve = "ois", measure = "spot")

# Short end of the OIS forward curve: the market-implied Bank Rate path
# at monthly resolution, one month to five years
boe_curve(curve = "ois", measure = "forward", segment = "short")
```

Requires the `readxl` package (loaded lazily). Reference: Anderson and Sleath (2001), *New estimates of the UK real and nominal yield curves*, Bank of England Working Paper No. 126.

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
# Total consumer credit outstanding (the monthly headline measure,
# excluding student loans)
cc <- boe_consumer_credit(type = "total", from = "2026-01-01")
tail(cc, 6)
#>         date  type amount_gbp_m
#>   2026-01-31 total       249390
#>   2026-02-28 total       250577
#>   2026-03-31 total       252036
#>   2026-04-30 total       253405
#>   2026-05-31 total       254936
#>   2026-06-30 total       256333

# Credit card debt only
boe_consumer_credit(type = "credit_card", from = "2024-01-01")

# The alternative measure including student loans (updated only once a
# year, when the Student Loans Company publishes its data)
boe_consumer_credit(type = "total", include_student_loans = TRUE)
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

### Tracking MPC decisions and votes

```r
# Every Bank Rate change since 1997
decisions <- boe_mpc_decisions()
tail(decisions, 5)
#>         date new_rate_pct prev_rate_pct change_bps direction
#>   2024-11-07         4.75          5.00        -25       cut
#>   2025-02-06         4.50          4.75        -25       cut
#>   2025-05-08         4.25          4.50        -25       cut
#>   2025-08-07         4.00          4.25        -25       cut
#>   2025-12-18         3.75          4.00        -25       cut

# Full voting record: who dissented, and how
votes <- boe_mpc_votes()
recent_dissents <- subset(votes, dissent & date >= as.Date("2024-01-01"))
head(recent_dissents)

# How does Catherine L Mann vote?
mann <- subset(votes, member == "Catherine L Mann")
table(mann$dissent)
```

---

### Forecasts from the Monetary Policy Report

Since the Bernanke review, the Bank publishes scenario paths alongside its central projections. `boe_mpr_forecasts()` parses all three databank formats (classic to February 2026, scenario-based April 2026, hybrid from July 2026) into one schema, with the `scenario` column labelling scenario paths (`NA` for central projections).

```r
# Latest CPI inflation projections: central projections for every
# publication vintage, plus the current report's scenario paths
cpi <- boe_mpr_forecasts(series = "cpi_inflation")

subset(cpi, !is.na(scenario) & horizon == "2027 Q1")
#>         date horizon horizon_date        series                 scenario value
#>   2026-07-01 2027 Q1   2027-01-01 cpi_inflation         Adverse Scenario   4.3
#>   2026-07-01 2027 Q1   2027-01-01 cpi_inflation Memo: central projection   3.2
#>   2026-07-01 2027 Q1   2027-01-01 cpi_inflation          Milder Scenario   3.0

# All five traditional series for the most recent MPR
all <- boe_mpr_forecasts()
unique(all$series)
#>   [1] "bank_rate" "cpi_inflation" "gdp_growth" "gdp_level" "unemployment"

# Scenario-only series (published from April 2026)
boe_mpr_forecasts(series = "output_gap")
```

Requires the `readxl` package. Coverage runs from November 2019; older releases use a different archive layout.

---

### Searching for a series

```r
# Keyword search across the catalogue
boe_search("mortgage")

# Filter by category and frequency
boe_search(category = "interest_rates", frequency = "daily")

# Browse without a keyword
boe_browse(category = "exchange_rates")

# The full catalogue is exported as a data frame
head(boe_series)
table(boe_series$category)
#>     consumer_credit       exchange_rates       interest_rates
#>                   5                   27                   14
#>     monetary_aggregates    mortgage_market
#>                       2                  6
```

---

### Provenance

Every result from a `boe_*()` function is a `boe_tbl` (a data frame with attached metadata). Printing shows a one-line provenance header, but it behaves like a normal data frame for everything else.

```r
br <- boe_bank_rate(from = "2024-01-01", frequency = "monthly")
br
#> # BoE [boe_bank_rate]: 1 series [IUMABEDR] · 16 obs · 2024-01-01 to 2025-04-30 · freq=monthly
#>         date rate_pct
#>   2024-01-31     5.25
#>   2024-02-29     5.25
#>   ...
```

---

## Caching

All downloads are cached locally in your user cache directory. Subsequent calls return the cached copy instantly - no network request is made. Cached files expire automatically: 24 hours for the latest-month yield curve zip and MPR archive, 30 days for statistical database queries and historical archive zips (BoE revisions eventually reach queries pinned to a fixed date range). Set `options(boe.cache_ttl_h = Inf)` to freeze the statistical database cache for a reproducible run.

```r
# Inspect the cache (path, file count, size, range)
boe_cache_info()
#> BoE cache
#> * Path:  /Users/.../R/boe/cache
#> * Files: 12
#> * Size:  6.4 MB
#> * Range: 2026-04-12 09:14:02 to 2026-04-25 11:30:18

# Force a fresh download
boe_bank_rate(from = "2020-01-01", cache = FALSE)

# Remove files older than 7 days
clear_cache(max_age_days = 7)

# Remove all cached files
clear_cache()
```

---

## Related packages

| Package | Description |
|---|---|
| [`ons`](https://github.com/charlescoverdale/ons) | UK Office for National Statistics data |
| [`hmrc`](https://github.com/charlescoverdale/hmrc) | HM Revenue & Customs tax data |
| [`obr`](https://github.com/charlescoverdale/obr) | Office for Budget Responsibility fiscal forecasts |
| [`fred`](https://github.com/charlescoverdale/fred) | US Federal Reserve (FRED) data |
| [`readecb`](https://github.com/charlescoverdale/readecb) | European Central Bank data |
| [`yieldcurves`](https://github.com/charlescoverdale/yieldcurves) | Yield curve fitting (Nelson-Siegel, Svensson) |
| [`mpshock`](https://github.com/charlescoverdale/mpshock) | Monetary policy shock series (US/UK/AU) |
| [`inflationkit`](https://github.com/charlescoverdale/inflationkit) | Inflation analysis (decomposition, persistence, Phillips curve) |
| [`nowcast`](https://github.com/charlescoverdale/nowcast) | Economic nowcasting (bridge, MIDAS, DFM) |

---

## Issues

Please report bugs or requests at <https://github.com/charlescoverdale/boe/issues>.

## Keywords

Bank of England, BoE, interest rates, bank rate, SONIA, yield curve, exchange rates, mortgage rates, consumer credit, money supply, monetary policy, UK economic data, R package
