# feat(collection): grouping verbs for survey_collection

**Date**: 2026-04-29
**Branch**: feature/survey-collection-grouping-verbs
**Phase**: Phase 0.7
**Spec**: `plans/spec-survey-collection.md` (§IV.7–§IV.10, §III.4, §IX.3)
**Implementation plan**: `plans/impl-survey-collection.md` (PR 2c)

## What Changed

PR 2c of the survey_collection verb-dispatch arc. Wires the four grouping
predicates and verbs (`group_by`, `ungroup`, `group_vars`, `is_rowwise`)
to `survey_collection`. `group_by` and `ungroup` route through the PR 1
dispatcher with `.may_change_groups = TRUE` (the §III.4 whitelist);
`group_vars` and `is_rowwise` are diagnostic one-liners that do not
invoke the dispatcher.

### New: `R/group-by.R` — `group_by.survey_collection`, `ungroup.survey_collection`, `group_vars.survey_collection`

- `group_by.survey_collection(.data, ..., .add = FALSE, .drop = TRUE, .if_missing_var = NULL)`
  dispatches `dplyr::group_by` per member with `.detect_missing = "pre_check"`
  and `.may_change_groups = TRUE`. The dispatcher's step-5 sync — performed
  by `surveycore::as_survey_collection()` re-deriving `@groups` from members —
  lifts the per-member groups onto the rebuilt collection. The class
  validator (G1, G1b, G1c) on the rebuilt collection enforces uniformity.
- `ungroup.survey_collection(x, ..., .if_missing_var = NULL)` dispatches
  `dplyr::ungroup` per member with `.detect_missing = "none"` and
  `.may_change_groups = TRUE`. After dispatch every member's `@groups` is
  empty; the constructor lifts that to `out_coll@groups`.
- `group_vars.survey_collection(x)` returns `x@groups` directly (one-liner,
  no dispatcher).

### Modified: `R/rowwise.R` — `is_rowwise()` extended for `survey_collection`

`is_rowwise()` now checks `S7::S7_inherits(design, surveycore::survey_collection)`
and returns `TRUE` iff every member is rowwise (per §IV.10). Implemented
as an internal class-check branch inside the existing exported function
rather than as a separate S3 method, because surveytidy-owned exported
generics with namespaced S7 class methods trip the R CMD check
"Apparent methods for exported generics not registered" note when
registered only via `registerS3method()` in `.onLoad()`. The single-
function form matches the spec's one-liner predicate intent.

### Modified: `R/zzz.R` — survey_collection grouping block filled

Added three `registerS3method()` calls inside the pre-allocated
`# ── survey_collection: grouping verbs (PR 2c) ──` block: `group_by`,
`ungroup`, `group_vars` against `"surveycore::survey_collection"`,
registered to the `dplyr` namespace.

### Modified: `DESCRIPTION` — `mockery` added to Suggests

The new `group_vars.survey_collection` test verifies (via
`mockery::stub`) that the dispatcher is **not** invoked. Block-level
`skip_if_not_installed("mockery")`.

### New: `tests/testthat/test-collection-group-by.R`

Covers all four entry points with the IX.3 dual-invariant pattern
(`test_collection_invariants(coll)` + per-member `test_invariants(member)`):

- `group_by` happy path (cross-coll + cross-member `@groups`),
  `.add = TRUE` (appends), `.add = FALSE` (replaces), `.drop` pass-through,
  `@id`/`@if_missing_var` preservation.
- `.if_missing_var = "error"` with dual pattern (typed
  `surveytidy_error_collection_verb_failed` + snapshot).
- `.if_missing_var = "skip"` Part 1: heterogeneous fixture; m1, m2 lack
  `region` and are skipped; m3 survives and is grouped on `region`. G1b
  is structurally satisfied because every surviving member has the column.
- `.if_missing_var = "skip"` emptied error when all members lack the
  group column.
- **G1b safety net**: synthesizes a regression in surveycore's per-member
  enforcement by mutating one member's `@data` via `attr(first, "data") <-`
  and `attr(coll, "surveys") <-`, then calls `S7::validate(coll)` directly.
  Asserts `surveycore_error_collection_group_not_in_member_data`.
  Comment in the test file documents this is unreachable through normal
  dispatch.
- `visible_vars` preservation on both `group_by` and `ungroup` (every
  member's `@variables$visible_vars` equal to `c("y1", "y2")` after
  the verb).
- `ungroup` happy path + already-ungrouped no-op.
- `group_vars` returns `coll@groups` directly; mockery-stubbed
  non-invocation test.
- `is_rowwise`: `FALSE` for plain collection, `TRUE` after
  `dplyr::rowwise(coll)`, `FALSE` for a mixed collection (constructed
  via the `attr<-` bypass + `S7::validate()` pattern).

### New: `tests/testthat/_snaps/collection-group-by.md`

One snapshot for the `.if_missing_var = "error"` path on `group_by`.

## Verification

- `devtools::test()` — all tests pass (0 failures)
- `devtools::check()` — 0 errors, 0 warnings, 0 notes
- `covr::package_coverage()` — 100% across every measured file
- `air format` — applied to all touched files

## Files Modified

- `R/group-by.R` — `group_by.survey_collection`, `ungroup.survey_collection`,
  `group_vars.survey_collection`
- `R/rowwise.R` — extended `is_rowwise()` with `survey_collection` branch
- `R/zzz.R` — filled PR 2c registration block (3 `registerS3method` calls)
- `DESCRIPTION` — `mockery` added to Suggests
- `tests/testthat/test-collection-group-by.R` — new
- `tests/testthat/_snaps/collection-group-by.md` — new
- `man/group_by.Rd`, `man/rowwise.Rd` — regenerated for the new
  collection methods / extended predicate
- `plans/impl-survey-collection.md` — PR 2c marked complete
