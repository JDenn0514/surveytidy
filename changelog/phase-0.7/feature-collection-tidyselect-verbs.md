# feat(collection): tidyselect verbs for survey_collection

**Date**: 2026-04-28
**Branch**: feature/survey-collection-tidyselect-verbs
**Phase**: Phase 0.7
**Spec**: `plans/spec-survey-collection.md`
**Implementation plan**: `plans/impl-survey-collection.md` (PR 2b)

## What Changed

PR 2b of the survey_collection verb-dispatch arc. Wires the seven
tidyselect-shaped verbs (`select`, `relocate`, `rename`, `rename_with`,
`distinct`, `drop_na`, `rowwise`) to the PR 1 dispatcher with
`.detect_missing = "class_catch"`. Adds two pre-flight typed errors
that protect the surveycore class validator G1b invariant (uniform
`@groups` across collection and members).

### New: `R/select.R` — `.check_select_group_removal()`, `select.survey_collection`, `relocate.survey_collection`

- `select.survey_collection(.data, ..., .if_missing_var = NULL)` runs
  the group-removal pre-flight against the first member's `@data`,
  raising `surveytidy_error_collection_select_group_removed` if any
  column in `coll@groups` would be removed. Then dispatches
  `dplyr::select` per member with class-catch.
- `relocate.survey_collection(.data, ..., .before = NULL, .after = NULL, .if_missing_var = NULL)`
  uses the closure pattern (mirrors `relocate.survey_base`) to forward
  `.before` / `.after` quosures through `rlang::inject` per member.
  No group-removal pre-flight — relocate only reorders.

### New: `R/rename.R` — `.check_group_rename_coverage()`, `rename.survey_collection`, `rename_with.survey_collection`

- `.check_group_rename_coverage(coll, verb_name, rename_olds_per_member)`
  checks that every group column being renamed is renamed on **every**
  member. Partial group renames raise
  `surveytidy_error_collection_rename_group_partial`. Defense-in-depth
  for plain `rename` (G1b regressions); genuinely reachable for
  `rename_with` when `.cols` resolves differently across heterogeneous
  members.
- `rename.survey_collection(.data, ..., .if_missing_var = NULL)` —
  evaluates the rename map per member via `tidyselect::eval_rename`
  before dispatch, runs the group-rename pre-flight, dispatches
  normally.
- `rename_with.survey_collection(.data, .fn, .cols = dplyr::everything(), ..., .if_missing_var = NULL)` —
  captures `.cols` as a quosure, resolves per member via
  `tidyselect::eval_select`, runs the same pre-flight, then dispatches
  via a closure that re-injects the quosure.

### New: `R/distinct.R` — `distinct.survey_collection`

Per-member dispatch with `.may_change_groups = FALSE`. V9 contract:
two members containing a literally identical row both retain that row
post-`distinct()` — there is no cross-survey collapse. Per-member
`surveycore_warning_physical_subset` fires N times on an N-member
collection.

### New: `R/drop-na.R` — `drop_na.survey_collection`

Per-member domain-aware NA marking; `.may_change_groups = FALSE`.
Note: `tidyr::drop_na`'s generic calls `rlang::check_dots_unnamed()`
**before** S3 dispatch, which rejects any named `...` argument. As a
result, `drop_na.survey_collection(data, ...)` cannot accept a
per-call `.if_missing_var`. The collection's stored `@if_missing_var`
remains the only way to control behavior; documented in the method's
roxygen.

### New: `R/rowwise.R` — `rowwise.survey_collection`

Per-member dispatch; sets `@variables$rowwise = TRUE` and
`@variables$rowwise_id_cols` on every member. Collection has no
rowwise marker; soft uniformity invariant is by-construction (mixed
state warns at `mutate.survey_collection` per PR 2a, not blocked).

### Modified: `R/zzz.R`

Filled the `# ── survey_collection: tidyselect verbs (PR 2b) ──`
block with seven `registerS3method()` calls for `select`, `relocate`,
`rename`, `rename_with`, `distinct`, `drop_na`, `rowwise` against
`"surveycore::survey_collection"`. `drop_na` registers with the
`tidyr` namespace; the rest with `dplyr`.

### Modified: `R/rename.R` — fixed pre-existing empty-rename-map bug

`.apply_rename_map` previously fired the design-var rename warning
when the rename map resolved to zero entries (e.g., `any_of()` with
no matches). Gated the warning on `if (any(is_domain))` so empty
maps now return without spurious warnings.

### Modified: `plans/error-messages.md`

Added two new error classes:
- `surveytidy_error_collection_select_group_removed`
- `surveytidy_error_collection_rename_group_partial`

### Coverage lift: 85% → 100%

Coverage on this branch had dropped to 85.48% — the survey_collection
work expanded `R/` without proportional test additions, and covr could
not measure two structural patterns:

- `.onLoad()` in `R/zzz.R` (326 lines) runs before covr instruments
- the `.make_slice_method()` factory closure in `R/slice.R` (40 lines)
  cannot be traced from source through closure indirection

Both were excluded via `.covrignore` (zzz.R) and `# nocov` markers
(slice.R) with comments pointing to the tests that verify them.
Added 38 targeted test blocks across 8 test files for the remaining
genuine gaps in `joins.R`, `rename.R`, `utils.R`, `transform.R`,
`mutate.R`, `filter.R`, `case-when.R`, `recode-values.R`,
`replace-values.R`, and `select.R`. Also added `.covrignore` to
`.Rbuildignore` to suppress the "hidden files and directories" R CMD
check note. Final coverage: 100% across every measured file.

### New: `tests/testthat/test-collection-select.R`

Cross-design happy paths for `select` and `relocate` with dual
`test_collection_invariants` + per-member `test_invariants`
discipline; group-removal pre-flight (typed error + snapshot);
relocate exercises all four closure paths (`.before`-only,
`.after`-only, both-supplied, neither-supplied);
`.if_missing_var` modes; emptied error.

### New: `tests/testthat/test-collection-rename.R`

Happy paths for `rename` and `rename_with`; group-rename partial
pre-flight (heterogeneous member shapes via `attr(coll, "surveys") <-`
to bypass S7 per-assignment validation); `.if_missing_var` modes;
emptied error.

### New: `tests/testthat/test-collection-distinct.R`

Cross-design happy path; **V9 no-cross-survey-collapse test** (two
members with identical rows both retain the row); per-member
physical-subset warning multiplicity (N firings on N members);
`.if_missing_var` modes; emptied error.

### New: `tests/testthat/test-collection-drop-na.R`

Cross-design happy path with NAs injected via `attr(m, "data") <-`;
no-cols default path; `.if_missing_var` error/skip/emptied;
per-call `.if_missing_var` constraint test (tidyr-generic
`check_dots_unnamed` rejects named `...`); domain accumulation with
prior `filter()`.

### New: `tests/testthat/test-collection-rowwise.R`

Cross-design happy path (per-member rowwise state); id-cols
forwarding; `@groups` invariant (rowwise does not change `@groups`);
`@id` and `@if_missing_var` preserved; `.if_missing_var` modes;
emptied error.

## Verification

- `devtools::test()` — all tests pass
- `devtools::check()` — 0 errors, 0 warnings, 0 notes
- `covr::package_coverage()` — 100% across every measured file
- `air format` — applied to all touched files

## Files Modified

- `R/select.R` — `.check_select_group_removal`, `select.survey_collection`,
  `relocate.survey_collection`
- `R/rename.R` — `.check_group_rename_coverage`, `rename.survey_collection`,
  `rename_with.survey_collection`, empty-map bug fix
- `R/distinct.R` — `distinct.survey_collection`
- `R/drop-na.R` — `drop_na.survey_collection`
- `R/rowwise.R` — `rowwise.survey_collection`
- `R/zzz.R` — filled PR 2b registration block (7 `registerS3method` calls)
- `tests/testthat/test-collection-select.R` — new (covers select + relocate)
- `tests/testthat/test-collection-rename.R` — new
- `tests/testthat/test-collection-distinct.R` — new
- `tests/testthat/test-collection-drop-na.R` — new
- `tests/testthat/test-collection-rowwise.R` — new
- `tests/testthat/_snaps/collection-select.md` — new
- `tests/testthat/_snaps/collection-rename.md` — new
- `tests/testthat/_snaps/collection-distinct.md` — new
- `tests/testthat/_snaps/collection-drop-na.md` — new
- `tests/testthat/_snaps/collection-rowwise.md` — new
- `man/select.Rd`, `man/relocate.Rd`, `man/rename.Rd`, `man/distinct.Rd`,
  `man/drop_na.Rd`, `man/rowwise.Rd` — regenerated for the new
  collection methods
- `plans/error-messages.md` — added two new error classes
- `.covrignore` — new; excludes `R/zzz.R` from coverage measurement
- `.Rbuildignore` — added `.covrignore`
- `R/slice.R` — `# nocov` markers on the `.make_slice_method` factory closure
- `tests/testthat/test-filter.R`, `test-joins.R`, `test-mutate.R`,
  `test-recode.R`, `test-rename.R`, `test-transform.R`, `test-utils.R` —
  38 new test blocks closing genuine coverage gaps
