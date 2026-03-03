# feat(survey-result): add meta-updating select, rename, rename_with for survey_result

**Date**: 2026-03-03
**Branch**: feature/survey-result-meta
**Phase**: Phase survey-result

## Changes

- Implement `select.survey_result()` with `.meta` pruning: drops stale
  `meta$group` entries for removed columns; handles inline renames
  (`select(r, grp = group)`) by applying the rename map before subsetting
- Implement `rename.survey_result()` that propagates column renames to all
  `.meta` key references (`$group`, `$x`, `$numerator$name`,
  `$denominator$name`) via `.apply_result_rename_map()`
- Implement `rename_with.survey_result()` that applies `.fn` to selected
  columns and propagates renames to `.meta`; errors with
  `"surveytidy_error_rename_fn_bad_output"` for non-character, wrong-length,
  `NA`, or duplicate-name output from `.fn`
- Register 3 new S3 methods (`select`, `rename`, `rename_with`) in `.onLoad()`
  against `"survey_result"` base class covering all six subclasses
- Add 20+ test sections (Sections 5–22, 27–28) covering rename group/x key
  updates, select column pruning, chained verb meta coherence, parameterized
  invalid `.fn` tests with snapshot assertions, zero-match edge cases, and
  identity renames
- Add `plans/error-messages.md` entry for `surveytidy_error_rename_fn_bad_output`
- Update `NEWS.md` with PR 2 bullet

## Files Modified

- `R/verbs-survey-result.R` — `select.survey_result()`, `rename.survey_result()`, `rename_with.survey_result()`
- `R/zzz.R` — three new `registerS3method()` calls in `.onLoad()` under PR 2 block
- `tests/testthat/test-verbs-survey-result.R` — 20+ new test sections for PR 2 verbs
- `tests/testthat/_snaps/verbs-survey-result.md` — snapshots for `rename_with` error cases
- `plans/error-messages.md` — `surveytidy_error_rename_fn_bad_output` entry
- `NEWS.md` — development bullet for `select`, `rename`, `rename_with` on `survey_result`
