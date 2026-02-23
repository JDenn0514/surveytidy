# Convert drop_na() from physical row removal to domain-aware filtering

| Field | Value |
|-------|-------|
| **Package** | surveytidy |
| **Phase** | 0.5 |
| **Branch** | main (direct commit) |
| **PR** | — |
| **Date** | 2026-02-22 |

## Executive Summary

`drop_na()` previously removed rows containing `NA` from the survey object,
mirroring `tidyr::drop_na()` on a plain data frame. This was statistically
incorrect: removing rows changes which units contribute to variance estimation,
producing incorrect standard errors for any downstream regression or estimation.
The correct approach — consistent with the rest of surveytidy's design — is
domain estimation: mark incomplete rows as out-of-domain instead of removing
them. `drop_na()` now behaves identically to the equivalent
`filter(!is.na(col1), !is.na(col2), ...)` chain, giving users correct variance
estimates without requiring them to know the filter pattern. The all-NA edge
case changes from an error to a warning, matching `filter()` behavior.

---

## Commits

### `fix(tidyr): convert drop_na() to domain-aware filtering`

**Purpose:** The physical-removal behavior of `drop_na()` contradicted the
core statistical design principle of surveytidy — that rows must never be
removed for subpopulation analyses. Making `drop_na()` domain-aware closes
the gap between it and `filter()`, ensures correct standard errors for
downstream models, and removes the last verb in the package that silently
produced statistically invalid results for survey data.

**Key changes:**
- `R/drop-na.R`: removed `.warn_physical_subset()` call and physical row
  deletion (`data@data <- data@data[keep_mask, , drop = FALSE]`); replaced
  with domain column update (same logic as `filter()`); changed all-NA case
  from `cli_abort(...surveytidy_error_subset_empty_result)` to
  `cli_warn(...surveycore_warning_empty_domain)`; stores constructed
  `!is.na(col)` quosures in `@variables$domain`; updated roxygen description,
  `@return`, and `@examples`
- `tests/testthat/test-tidyr.R`: removed physical-removal and physical-subset
  warning assertions; added tests for domain column correctness, chaining
  AND-behavior, quosure storage, no-warning on normal use, and empty-domain
  warning with object still returned
- `tests/testthat/_snaps/tidyr.md`: replaced old error snapshot with warning
  snapshot for `surveycore_warning_empty_domain`
