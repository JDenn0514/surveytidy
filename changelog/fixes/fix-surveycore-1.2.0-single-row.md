# fix(utils): support the surveycore 1.2.0 two-row minimum

**Date**: 2026-11-03
**Branch**: fix/surveycore-1.2.0-single-row
**Phase**: fixes

## Changes

- surveycore 1.2.0 (surveycore #248) refuses a design whose `@data` has 0 or
  1 rows. Six surveytidy tests failed against it with
  `surveycore_error_single_row`. surveytidy was archived on CRAN on
  2026-09-27 together with surveycore, and cannot be resubmitted until these
  tests pass.
- Raise the surveycore floor in Imports from `>= 0.8.2` to `>= 1.2.0`.
- A verb that reduces a design to 1 row now raises surveycore's
  `surveycore_error_single_row`. surveytidy passes the error through and
  does not wrap it. This applies to `distinct()`, `slice()`, `slice_head()`,
  `slice_tail()`, `slice_min()`, `slice_max()`, `slice_sample()`,
  `subset()`, and `inner_join(.domain_aware = FALSE)`.
- The 0-row error (`surveytidy_error_subset_empty_result`) now says that
  survey objects require at least 2 rows, not 1.

## Files Modified

- `DESCRIPTION` — surveycore floor raised to `>= 1.2.0`.
- `R/filter.R`, `R/joins.R`, `R/slice.R` — the 0-row error message says
  "at least 2 rows".
- `tests/testthat/_snaps/arrange.md`, `collection-slice.md`, `filter.md`,
  `joins.md` — snapshots updated for the new message text.
- `tests/testthat/test-distinct.R` — the two tests where `distinct()`
  collapses data to 1 row now expect `surveycore_error_single_row`.
- `tests/testthat/test-collection-distinct.R` — the `.if_missing_var = "skip"`
  test uses bare `y3`; `all_of("y3")` became a constant column under data
  masking and collapsed each member to 1 row.
- `tests/testthat/test-collection-slice.R` — three `slice_sample(weight_by =)`
  tests use `n = 2L` in place of `n = 1L`.
- `tests/testthat/test-arrange.R` — new tests: each slice verb with 1 row
  raises `surveycore_error_single_row`, for all three design types.
- `tests/testthat/test-filter.R` — new test: `subset()` that matches 1 row
  raises `surveycore_error_single_row`, for all three design types.
- `tests/testthat/test-joins.R` — new test: `inner_join(.domain_aware =
  FALSE)` that matches 1 row raises `surveycore_error_single_row` (taylor and
  replicate; twophase errors earlier by design).
