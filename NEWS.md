# boe 0.4.0

## Monetary Policy Report: scenario and hybrid formats

* `boe_mpr_forecasts()` now parses all three Projections Databank
  layouts the Bank has published since the Bernanke review of
  forecasting: the classic format (February 2026 and earlier), the
  scenario-based "Scenario Projections Databank" (April 2026), and the
  hybrid workbook introduced with the July 2026 report, which restores
  the classic central-projection sheets (including GDP level and Bank
  Rate) and adds a "Quarterly scenarios" section. The format is
  detected automatically and all three share one output schema.
* New `scenario` column. Scenario paths (e.g. `"Adverse Scenario"`,
  `"Milder Scenario"`) are labelled in `scenario`; central projections
  carry `NA`. For hybrid releases a single call returns both the
  central projections for every publication vintage and the current
  report's scenario paths.
* The `series` argument gains four series published in the scenario
  sheets from April 2026: `"output_gap"`, `"energy_prices"`,
  `"average_earnings"`, and `"world_export_prices"`. The default series
  set is unchanged.
* Series that a release does not publish are skipped with a warning
  rather than erroring: the scenario-only series are absent from
  classic releases, and the April 2026 release alone drops
  `"gdp_level"` and `"bank_rate"` (Bank Rate was published as a
  conditioning assumption). Hybrid releases publish all nine series.
* Automatic release selection now returns the most recent published
  release of any format, rather than falling back to the most recent
  classic-format release.

## Consumer credit: monthly headline measure

* `boe_consumer_credit()` now defaults to the headline measure
  excluding the Student Loans Company (`LPMBI2O`, `LPMVZRJ`,
  `LPMB4TS`), the series updated every month in the Bank's Money and
  Credit release. The previous default series including student loans
  (`LPMVZRI`, `LPMVZRK`) are only updated once a year, when the Student
  Loans Company publishes its data, so their recent months trailed the
  headline measure by up to a year (at the time of this release they
  stopped at March 2026). Levels for `"total"` and `"other"` are
  therefore lower than in previous versions; `"credit_card"` is
  identical under both measures.
* New `include_student_loans` argument restores the previous series
  selection: `boe_consumer_credit(include_student_loans = TRUE)`.
* The `boe_series` catalogue now lists both measures (54 series).

## Caching

* Statistical database responses now expire after 30 days rather than
  being cached indefinitely, so BoE revisions eventually reach queries
  pinned to a fixed date range. Queries whose `to` date is today are
  unaffected (they already produced a fresh URL, and so a fresh
  download, each day). Configurable via `options(boe.cache_ttl_h = )`;
  set it to `Inf` to freeze the cache for a reproducible run.

# boe 0.3.0

## Yield curves: historical archive and panel helper

* `boe_curve()` gains `from`, `to`, `frequency`, and `cache_ttl_h`
  arguments. Setting any of `from` / `to`, or `frequency = "monthly"`,
  routes the request through the BoE archive zips, which extend back to
  ~1979 for nominal gilts, ~1985 for real, ~2000 for the commercial bank
  liability curve, and ~2009 for OIS. Default behaviour
  (`from = NULL`, `to = NULL`, `frequency = "daily"`) is unchanged: the
  function still returns the latest published month from the
  `latest-yield-curve-data.zip` endpoint.
* `boe_curve()` gains a fifth curve type, `"blc"` (commercial bank
  liability curve). BLC is only published in the historical archive
  zip, so requests for it always route through the archive path
  regardless of `from` / `to`.
* New `boe_curve_panel(curve, measure, frequency, from, to, maturities)`:
  wide-format wrapper that returns one row per date and one numeric
  column per pillar maturity. The default pillar set is
  `c(0.5, 1, 2, 5, 10, 20)`, which aligns exactly with the BoE
  half-year grid. Pillars outside a curve's published range trigger a
  warning and are dropped.
* `boe_curve()` and `boe_curve_panel()` gain a `segment` argument.
  `segment = "short"` returns the separately fitted short end of the
  curve (monthly maturity steps from one month out to five years) for
  every curve type; `segment = "standard"` (the default) is unchanged.
  Short-end history extends as far back as the Bank published it (to 1979
  for nominal gilts, later for OIS); periods with no short-end sheet are
  skipped rather than erroring. The panel's default pillars become
  `c(0.5, 1, 2, 3, 5)` when `segment = "short"`.
* `boe_curve_panel()` now keeps pillar column labels aligned with the
  maturities they match when an off-grid pillar is dropped; previously a
  dropped pillar could shift the labels so a surviving column carried the
  wrong name.
* Provenance: `boe_tbl` queries from `boe_curve()` now record
  `source = "latest"` or `"archive"` and the `source_url` so the data
  carries its own audit trail.
* Internal: archive zips cache for 30 days (vs. 24 hours for the
  latest-month zip); per-period workbooks within an archive are
  concatenated transparently, with content-based maturity-row detection
  for older layouts.

## Fixes: Monetary Policy Report release resolution

* `boe_mpr_forecasts()` no longer fails with an HTTP 404 when the latest
  scheduled release does not exist at the guessed URL. The Bank's
  publication month drifts between years (the second 2026 report was
  published in April, not May), and the data archive filename changed
  from `chart-slides-and-data` to `charts-slides-and-data` during 2025.
  Release selection now enumerates recent months, verifies each archive
  exists with a lightweight request, and handles both filename variants,
  instead of assuming a fixed February / May / August / November calendar.
* From the April 2026 report the Bank moved to a scenario-based
  "Scenario Projections Databank" with a transposed layout, which this
  function cannot parse yet. Automatic selection now skips such releases,
  falls back to the most recent compatible release, and warns. Requesting
  a scenario-format release explicitly via `month` / `year` raises a clear
  error rather than a parsing failure. Full support for the scenario
  format is planned for a future release.

# boe 0.2.0

## New: monetary policy data

* New `boe_mpc_decisions(from, to)`: history of MPC rate-change events
  derived from the daily Bank Rate series. Returns date, new rate,
  previous rate, change in basis points, and direction.
* New `boe_mpc_votes()`: full MPC voting record from June 1997, parsed
  from BoE's published `mpcvoting.xlsx`. Long format with one row per
  (meeting, member) including a `dissent` flag.
* New `boe_mpr_forecasts(series, month, year)`: Monetary Policy Report
  forecast paths for CPI inflation, GDP growth, GDP level, unemployment,
  and Bank Rate. Parses the Projections Databank workbook from the
  per-release MPR zip. Defaults to the latest published quarterly
  release; older releases are accessible via `month` / `year` (post-2025
  format only).

## New: search and discovery

* New `boe_series` exported dataset: a 52-row catalogue of every BoE
  series wrapped by the package, with code, title, category, frequency,
  unit, start date, and seasonal-adjustment flag.
* New `boe_search(query, category, frequency)`: keyword + filter search
  over `boe_series`. Case-insensitive substring match against title and
  code.
* New `boe_browse(category, frequency)`: filter-only view of
  `boe_series`. Equivalent to `boe_search()` with no keyword.

## New: yield-curve depth (Anderson-Sleath)

* New `boe_curve(curve, measure)`: full Anderson-Sleath fitted yield
  curves at all maturities (typically 0.5 to 25 or 40 years), covering
  nominal gilt, real gilt, implied inflation, and OIS curves. Both
  spot and forward measures available where published. Latest month of
  daily data; archive coverage planned.
* References Anderson and Sleath (2001, BoE Working Paper 126).
* Adds **readxl** to Suggests (used only by `boe_curve()`; lazily
  required at call time).

## New: cache helpers

* New `boe_cache_info()`: report cache directory, file count, total
  size, and modification timestamp range. Companion to `clear_cache()`.

## Provenance

* New `boe_tbl` S3 class. All `boe_*()` functions now return data
  frames carrying provenance metadata (series codes, date range,
  frequency, function called, fetch timestamp). Subclasses
  `data.frame` so downstream operations are unaffected.
* New `print.boe_tbl()` method shows a one-line provenance header
  above the data frame body, mirroring the `fred_tbl` pattern in the
  `fred` package.

# boe 0.1.2

* Removed non-existent pkgdown URL from DESCRIPTION.

# boe 0.1.1

* Examples now cache to `tempdir()` instead of the user's home directory,
  fixing CRAN policy compliance for `\donttest` examples.
* Cache directory is now configurable via `options(boe.cache_dir = ...)`.

# boe 0.1.0

* Initial release.
* `boe_get()`: fetch any series by code from the BoE Statistical Database.
* `boe_bank_rate()`: Bank Rate history (daily or monthly, from 1975).
* `boe_sonia()`: SONIA interest rate (daily, monthly, or annual, from 1997).
* `boe_yield_curve()`: nominal and real gilt yields at 5yr, 10yr, 20yr
  maturities (from 1985/1993).
* `boe_exchange_rate()`: daily sterling exchange rates for 27 currencies
  (from 1975).
* `list_exchange_rates()`: catalogue of available currency codes.
* `boe_mortgage_rates()`: quoted mortgage rates (2yr/3yr/5yr fixed, SVR,
  from 1995).
* `boe_mortgage_approvals()`: monthly mortgage approvals for house purchase
  (from 1993).
* `boe_consumer_credit()`: consumer credit outstanding by type (from 1993).
* `boe_money_supply()`: M4 broad money amounts outstanding (from 1982).
* `clear_cache()`: delete locally cached data files.
