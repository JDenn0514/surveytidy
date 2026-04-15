# refactor(utils): move .validate_transform_args() and .set_recode_attrs() to R/utils.R

**Date**: 2026-04-15
**Branch**: refactor/rowstats-shared-helpers
**Phase**: Phase 0.7

## Changes

- Move `.validate_transform_args()` from `R/transform.R` to `R/utils.R` — required so `R/rowstats.R` can call it without violating the 2+ source files rule
- Move `.set_recode_attrs()` from `R/transform.R` to `R/utils.R` — same reason
- Both moves are pure: identical function bodies, no behavioral change
- Update file header comments in both files

## Files Modified

- `R/utils.R` — add `# ── transform helpers ──` section with both helpers
- `R/transform.R` — remove both helpers; update section comment and file header
