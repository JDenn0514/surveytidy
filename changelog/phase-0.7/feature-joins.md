# feat(joins): implement dplyr join functions for survey design objects

**Date**: 2026-04-17
**Branch**: feature/joins
**Phase**: Phase 0.7

## Changes

- Add `left_join()` — domain-aware left join; adds lookup columns from `y`
  without removing any rows; errors if duplicate keys in `y` would expand rows
- Add `semi_join()` — marks rows matching `y` as in-domain; uses row-index
  approach to avoid physical row removal
- Add `anti_join()` — marks rows NOT matching `y` as in-domain (inverse of
  semi_join); uses row-index approach
- Add `inner_join()` — two modes: domain-aware (`.domain_aware = TRUE`,
  default) marks unmatched rows out-of-domain; physical mode
  (`.domain_aware = FALSE`) removes rows with warning; physical mode errors
  for `survey_twophase` designs
- Add `right_join()` — always errors; would add rows with NA design variables
- Add `full_join()` — always errors; same reason as right_join
- Add `bind_cols()` — standalone exported function (not S3 method; vctrs
  dispatch bypasses S3); validates row count parity between `x` and `...`;
  passes through to `dplyr::bind_cols()` for non-survey objects
- Add `bind_rows()` — always errors when called with a survey object (combining
  survey designs has undefined variance structure); passes through to
  `dplyr::bind_rows()` for non-survey objects
- All join functions protect design variable columns (strata, PSU, weights,
  etc.) by dropping conflicting columns from `y` with a warning before joining
- All join functions append a typed sentinel to `@variables$domain` for Phase 1
  consumers to identify join operations in the domain history
- Update `R/zzz.R` with `registerS3method()` calls for all 6 S3 join methods
- Update `R/reexports.R` with re-exports for all 6 dplyr join generics
- Update `plans/error-messages.md` with 7 new error classes and 1 warning class

## Error/Warning Classes Added

- `surveytidy_error_join_survey_to_survey` — `y` is a survey object
- `surveytidy_error_join_adds_rows` — `right_join` or `full_join` called on survey
- `surveytidy_error_join_row_expansion` — duplicate keys in `y` would expand rows
- `surveytidy_error_join_twophase_row_removal` — physical inner_join on twophase
- `surveytidy_error_bind_rows_survey` — `bind_rows()` with survey object
- `surveytidy_error_bind_cols_row_mismatch` — row counts differ in `bind_cols()`
- `surveytidy_error_reserved_col_name` — `..surveytidy_row_index..` already in data
- `surveytidy_warning_join_col_conflict` — `y` has columns named like design vars

## Files Added

- `R/joins.R` — new file: all 8 join functions + shared internal helpers
- `tests/testthat/test-joins.R` — new test file: 32 test sections, 1392 tests
- `tests/testthat/_snaps/joins.md` — snapshot file for error/warning message tests
- `man/bind_cols.Rd` — documentation for bind_cols()
- `man/bind_rows.Rd` — documentation for bind_rows()
- `man/inner_join.Rd` — documentation for inner_join()
- `man/left_join.Rd` — documentation for left_join()
- `man/right_join.Rd` — documentation for right_join() and full_join()
- `man/semi_join.Rd` — documentation for semi_join() and anti_join()

## Files Modified

- `R/zzz.R` — added feature/joins S3 method registrations
- `R/reexports.R` — added join generic re-exports
- `plans/error-messages.md` — added 7 error classes and 1 warning class
- `NAMESPACE` — regenerated with new exports and imports
