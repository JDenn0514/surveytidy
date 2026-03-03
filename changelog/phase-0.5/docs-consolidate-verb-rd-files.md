# docs(verbs): consolidate per-method Rd files into per-verb Rd files

**Date**: 2026-03-03
**Branch**: docs/consolidate-verb-rd-files
**Phase**: Phase 0.5

## Changes

- Replace per-method Rd files (e.g., `arrange.survey_base.Rd`) with per-verb Rd files (e.g., `arrange.Rd`) that document all S3 methods for a verb under a single help page
- Delete `R/verbs-survey-result.R`; move `survey_result` S3 methods into their respective verb files (`arrange.R`, `filter.R`, `select.R`, etc.) and move shared helpers into `R/utils.R`
- Update roxygen `@rdname` and `@method` tags across all verb files so `devtools::document()` generates per-verb Rd files with correct `\alias{}` entries
- Update `reexports.R` to use `@rdname verb` for primary verbs (redirecting re-export docs into the verb Rd) and plain `@export` for secondary verbs (slice variants, ungroup, rename_with, filter_out)
- Update `_pkgdown.yml` to reference the new per-verb Rd file names
- Fix "S3 methods shown with full name" R CMD check NOTE by using NULL stub + `@name verb` pattern in each verb file

## Files Modified

- `R/arrange.R` — added `survey_result` method; updated roxygen to per-verb Rd pattern
- `R/distinct.R` — updated roxygen to per-verb Rd pattern
- `R/drop-na.R` — added `survey_result` method; updated roxygen to per-verb Rd pattern
- `R/filter.R` — added `survey_result` method; updated roxygen to per-verb Rd pattern
- `R/group-by.R` — updated roxygen to per-verb Rd pattern
- `R/mutate.R` — added `survey_result` method; updated roxygen to per-verb Rd pattern
- `R/reexports.R` — updated `@rdname` strategy for primary vs secondary verbs
- `R/rename.R` — added `survey_result` method; updated roxygen to per-verb Rd pattern
- `R/rowwise.R` — updated roxygen to per-verb Rd pattern
- `R/select.R` — added `survey_result` method; updated roxygen to per-verb Rd pattern
- `R/slice.R` — added `survey_result` method; updated roxygen to per-verb Rd pattern
- `R/utils.R` — added shared `survey_result` helpers (`.restore_survey_result()`, `.prune_result_meta()`, `.apply_result_rename_map()`)
- `R/verbs-survey-result.R` — deleted; content distributed to verb files and `utils.R`
- `_pkgdown.yml` — updated reference section to use new per-verb Rd file names
- `man/arrange.survey_base.Rd` — deleted (replaced by `man/arrange.Rd`)
- `man/arrange.Rd` — new per-verb Rd file
- `man/distinct.survey_base.Rd` — deleted (replaced by `man/distinct.Rd`)
- `man/distinct.Rd` — new per-verb Rd file
- `man/drop_na.survey_base.Rd` — deleted (replaced by `man/drop_na.Rd`)
- `man/drop_na.Rd` — new per-verb Rd file
- `man/filter.survey_base.Rd` — deleted (replaced by `man/filter.Rd`)
- `man/filter.Rd` — new per-verb Rd file
- `man/glimpse.survey_base.Rd` — deleted (replaced by `man/glimpse.Rd`)
- `man/glimpse.Rd` — new per-verb Rd file
- `man/group_by.survey_base.Rd` — deleted (replaced by `man/group_by.Rd`)
- `man/group_by.Rd` — new per-verb Rd file
- `man/mutate.survey_base.Rd` — deleted (replaced by `man/mutate.Rd`)
- `man/mutate.Rd` — new per-verb Rd file
- `man/pull.survey_base.Rd` — deleted (replaced by `man/pull.Rd`)
- `man/pull.Rd` — new per-verb Rd file
- `man/relocate.survey_base.Rd` — deleted (replaced by `man/relocate.Rd`)
- `man/relocate.Rd` — new per-verb Rd file
- `man/rename.survey_base.Rd` — deleted (replaced by `man/rename.Rd`)
- `man/rename.Rd` — new per-verb Rd file
- `man/rowwise.survey_base.Rd` — deleted (replaced by `man/rowwise.Rd`)
- `man/rowwise.Rd` — new per-verb Rd file
- `man/select.survey_base.Rd` — deleted (replaced by `man/select.Rd`)
- `man/select.Rd` — new per-verb Rd file
- `man/slice.survey_base.Rd` — deleted (replaced by `man/slice.Rd`)
- `man/slice.Rd` — new per-verb Rd file
