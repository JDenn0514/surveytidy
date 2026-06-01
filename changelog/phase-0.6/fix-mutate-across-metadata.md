# fix(mutate): sync metadata for recode columns produced by across()

**Date**: 2026-05-27
**Branch**: fix/mutate-across-metadata
**Phase**: Phase 0.6

## Changes

- `mutate.survey_base()` now syncs `@metadata` (variable labels, value labels,
  transformation log) for columns recoded inside `dplyr::across()` — previously
  only explicitly-named LHS mutations were tracked
- After `dplyr::mutate()` runs, scan `new_data` for columns carrying a
  `surveytidy_recode` attr and union them into `effective_mutated_names` so
  Steps 4 (label extraction), 5a (recode attr capture), and 8 (transformation
  log) all process across()-produced columns correctly
- Added a new branch in Step 8 for the `is.null(q) && !is.null(recode_attr)`
  case (across() columns have no quosure but do have recode attr with `fn`
  and `var` filled in)

## Files Modified

- `R/mutate.R` — compute `effective_mutated_names` after Step 3; use it in
  Steps 4, 5a, and 8; add across() branch in the transformation-log loop
- `R/utils.R` — update `.extract_metadata_attrs()` comment to reflect that
  `changed_cols` now covers across() outputs (remove "accepted limitation" note)
- `tests/testthat/test-mutate.R` — update the existing across() test and add
  two new tests: metadata sync and transformation log for across() recode calls
