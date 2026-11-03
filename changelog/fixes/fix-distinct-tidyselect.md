# fix(distinct): make the design-variable check use data-masking

**Date**: 2026-11-03
**Branch**: fix/distinct-tidyselect
**Phase**: fixes

## Changes

- `distinct()` on a survey object uses data-masking for `...`, the same as
  `dplyr::distinct()`. Before this fix, the design-variable check resolved
  `...` with tidyselect, but `dplyr::distinct()` then evaluated `...` with
  data-masking. `distinct(d, tidyselect::all_of("x"))` added a junk column
  named `tidyselect::all_of("x")` to `@data` and de-duplicated on that
  constant column.
- The keys are now evaluated once with
  `dplyr::mutate(@data, ..., .keep = "none")`. The design-variable warning
  and the de-duplication both use these key columns. Rows are kept with
  `vctrs::vec_unique_loc()`, the rule that `dplyr::distinct()` uses.
- Computed expressions (`distinct(d, y1 > 50)`,
  `distinct(d, band = round(y1 / 10))`) find duplicates but no longer add a
  column to `@data`.
- The design-variable warning now also fires when a design variable is named
  through `pick()`, `across()`, or `.data$`.
- New error `surveytidy_error_distinct_select_helper`: a tidyselect helper
  (`all_of()`, `any_of()`, `starts_with()`, and others) passed directly in
  `...` stops with a message that points to `pick()`. Without this error, the
  helper gave one constant key and collapsed the design to 1 row.
- `distinct.survey_collection()` now finds missing columns with the
  dispatcher's pre-check (as `arrange()`, `filter()`, and `mutate()` do), in
  place of the tidyselect class-catch.

## NEWS entry

* `distinct()` on a survey object now evaluates `...` with data-masking for
  both the design-variable check and the de-duplication, as
  `dplyr::distinct()` does. A computed key such as `distinct(d, y1 > 50)` no
  longer adds a column to the survey data. A selection helper passed
  directly, such as `distinct(d, all_of(cols))`, now raises
  `surveytidy_error_distinct_select_helper`; use
  `distinct(d, pick(all_of(cols)))` instead.

## Files Modified

- `R/distinct.R` — data-masked keys for the check and the de-duplication;
  new helper `.check_distinct_select_helpers()`; collection method uses
  `.detect_missing = "pre_check"`; roxygen documents data-masking and
  `pick()`.
- `man/distinct.Rd` — regenerated.
- `plans/error-messages.md` — row for
  `surveytidy_error_distinct_select_helper`.
- `tests/testthat/test-distinct.R` — new Section 7 over `make_all_designs()`:
  bare names, `all_of()` inside `pick()` and `across()`, bare selection
  helpers (error and snapshot), computed and named computed keys, and the
  design-variable warning through `pick()` and `.data$`.
- `tests/testthat/_snaps/distinct.md`,
  `tests/testthat/_snaps/collection-distinct.md` — new snapshots for the
  selection-helper error (one per design type, and one for a collection).
- `tests/testthat/test-collection-distinct.R` — the `.if_missing_var` tests
  use bare names in place of `all_of()`; new tests for the selection-helper
  error on a collection, a missing `.data$` column, and `pick(all_of())` on
  a collection.
