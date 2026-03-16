# feat(transform): implement make_factor, make_dicho, make_binary, make_rev, make_flip

**Date**: 2026-03-16
**Branch**: feature/transformation
**Phase**: Phase transformation

## Changes

- Add `make_factor()` — converts labelled/numeric/character/factor to R factor;
  levels ordered by value label numeric value; supports `ordered`, `drop_levels`,
  `force`, `na.rm`, `.label`, `.description`
- Add `make_dicho()` — collapses multi-level factor to 2 levels via first-word
  stripping; supports `.exclude`, `flip_levels`, `.label`, `.description`
- Add `make_binary()` — converts dichotomous variable to 0/1 integer; delegates
  to `make_dicho()`; supports `flip_values`, `.exclude`, `.label`, `.description`
- Add `make_rev()` — reverses numeric scale via `min + max - x`; remaps value
  labels; supports `.label`, `.description`; all-NA short-circuit with warning
- Add `make_flip()` — flips semantic valence (keeps values, reverses label strings);
  requires `label` argument; supports `.description`
- Add `.validate_transform_args()` — internal helper for `.label`/`.description`
  validation with caller-specified error class
- Add `.strip_first_word()` — strips first whitespace-delimited word from label
  strings for `make_dicho()` collapse logic
- Add `.set_recode_attrs()` — sets `label`, `labels`, and `surveytidy_recode` attrs
- Update `R/utils.R`: `.wrap_labelled()` signature expanded to accept `fn` and
  `var`; `surveytidy_recode` structure now `list(fn, var, description)`
- Update all Phase 0.6 recode files (`recode-values.R`, `na-if.R`,
  `replace-when.R`, `replace-values.R`, `case-when.R`, `if-else.R`) to use
  the expanded `surveytidy_recode` structure (`list(fn, var, description)`)
- Update `R/mutate.R` step 8 to read `fn` and `var` from `surveytidy_recode`
  attr when present (already updated before this PR)
- Add 10 new error classes and 3 new warning classes to `plans/error-messages.md`
- Add `Transformation` reference section to `_pkgdown.yml`

## Files Modified

- `R/transform.R` — new file: make_factor(), make_dicho(), make_binary(),
  make_rev(), make_flip() + internal helpers (.validate_transform_args,
  .strip_first_word, .set_recode_attrs)
- `tests/testthat/test-transform.R` — new file: 621 test cases covering all
  5 functions plus surveytidy_recode attr structure and integration tests
- `tests/testthat/_snaps/transform.md` — new snapshots for all error tests
- `R/utils.R` — .wrap_labelled() signature updated to accept fn and var
- `R/recode-values.R` — surveytidy_recode expanded to list(fn, var, description)
- `R/na-if.R` — surveytidy_recode expanded
- `R/replace-when.R` — surveytidy_recode expanded
- `R/replace-values.R` — surveytidy_recode expanded
- `R/case-when.R` — surveytidy_recode expanded (var = NULL)
- `R/if-else.R` — surveytidy_recode expanded (var = NULL)
- `plans/error-messages.md` — 10 new error classes, 3 new warning classes
- `_pkgdown.yml` — Transformation reference section added
- `man/make_factor.Rd` — new documentation
- `man/make_dicho.Rd` — new documentation
- `man/make_binary.Rd` — new documentation
- `man/make_rev.Rd` — new documentation
- `man/make_flip.Rd` — new documentation
- `NAMESPACE` — exports for 5 new functions
