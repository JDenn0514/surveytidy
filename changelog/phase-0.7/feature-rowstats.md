# feat(rowstats): implement row_means() and row_sums()

**Date**: 2026-04-15
**Branch**: feature/rowstats
**Phase**: Phase 0.7

## Changes

- Add `row_means()` — computes row means across selected columns inside mutate()
- Add `row_sums()` — computes row sums across selected columns inside mutate()
- Both functions integrate with mutate.survey_base() via the surveytidy_recode attribute protocol
- Both record metadata: fn name, source_cols, and optional description in @metadata@transformations
- Add design variable overlap warning in mutate.R: fires surveytidy_warning_rowstats_includes_design_var when .cols includes any design variable
- Add column-name label fallback in mutate.R: when .label is NULL, row_means()/row_sums() fall back to the output column name (since cur_column() is unavailable in regular mutate() context)
- 30 test sections in test-rowstats.R covering happy path, NA behavior, metadata round-trip, tidyselect helpers, error paths, and integration with mutate()

## Files Modified

- `R/rowstats.R` — new file: row_means(), row_sums()
- `R/mutate.R` — add design variable overlap check and label fallback at Step 8
- `tests/testthat/test-rowstats.R` — new test file: 30 test sections
- `tests/testthat/_snaps/rowstats.md` — snapshot file for error message tests
- `_pkgdown.yml` — add row_means, row_sums to Transformation reference section
