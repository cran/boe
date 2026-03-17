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
