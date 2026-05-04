# feat(collection): data-mask verbs for survey_collection

**Date**: 2026-04-28
**Branch**: feature/survey-collection-data-mask-verbs
**Phase**: Phase 0.7
**Spec**: `plans/spec-survey-collection.md`
**Implementation plan**: `plans/impl-survey-collection.md` (PR 2a)

## What Changed

PR 2a of the survey_collection verb-dispatch arc. Wires the four
data-masking verbs (`filter`, `filter_out`, `mutate`, `arrange`) to the
PR 1 dispatcher with `.detect_missing = "pre_check"` and
`.may_change_groups = FALSE`. Adds a `mutate`-only rowwise mixed-state
pre-check (spec §IV.5) and shared `.by` rejection across `filter`,
`filter_out`, and `mutate` (spec §IV).

### Modified: `R/filter.R`

- `filter.survey_collection(.data, ..., .by = NULL, .preserve = FALSE, .if_missing_var = NULL)`
  — rejects `.by` with `surveytidy_error_collection_by_unsupported`,
  then dispatches `dplyr::filter` per member. Domain accumulation,
  empty-domain warning, and chained-filter AND semantics are all handled
  per-member by `filter.survey_base`.
- `filter_out.survey_collection(.data, ..., .by = NULL, .preserve = FALSE, .if_missing_var = NULL)`
  — same shape; routes to `filter_out.survey_base` per member.

### Modified: `R/mutate.R`

- `mutate.survey_collection(.data, ..., .by = NULL, .keep, .before = NULL, .after = NULL, .if_missing_var = NULL)`
  — rejects `.by`, then runs the rowwise mixed-state pre-check before
  dispatch:
  - Computes `is_rowwise()` for every member.
  - When some members are rowwise and others are not, fires
    `surveytidy_warning_collection_rowwise_mixed` exactly once, naming
    the rowwise and non-rowwise members.
  - Dispatches normally; per-member rowwise/non-rowwise mutate semantics
    apply for that call.
- `match.arg(.keep)` runs before dispatch so the receiving verb sees a
  resolved string.

### Modified: `R/arrange.R`

- `arrange.survey_collection(.data, ..., .by_group = FALSE, .locale = NULL, .if_missing_var = NULL)`
  — straight dispatch. `arrange` does not accept `.by`, so no rejection
  guard is needed.

### Modified: `R/zzz.R`

Filled the `# ── survey_collection: data-mask verbs (PR 2a) ──` block
with `registerS3method()` calls for `filter`, `filter_out`, `mutate`,
and `arrange` against `"surveycore::survey_collection"` (registered with
the `dplyr` namespace).

### Modified: `R/collection-dispatch.R`

Two patches needed once verb methods started forwarding scalar control
args (`.keep`, `.before`, `.after`, `.preserve`) through the dispatcher:

- New `.unwrap_scalar_dots(dots)` helper. After `enquos(...)`, every
  argument — including dotted-name scalars — is wrapped as a quosure.
  `inject(fn(survey, !!!dots))` does not unwrap quosures for non-NSE
  parameters, so the receiving verb's `match.arg(.keep)` saw a quosure
  and errored. The helper walks the captured quosures and `eval_tidy`s
  any whose name starts with `.`. Bare-name args remain quosures so
  data-masking semantics still work.
- `.pre_check_missing_vars()` skips dotted-name args. After unwrapping,
  scalar slots no longer hold quosures, so calling
  `quo_get_expr()` on them would crash the pre-check.

The dispatcher now correctly handles both quosure-wrapped data-mask
expressions and pre-evaluated scalar control args in the same `dots`
list. Behavior for filter/filter_out (which only forward bare-name
args plus `.preserve = FALSE`) is unchanged; mutate (which forwards
`.keep`, `.before`, `.after`) and any future dispatcher consumer with
scalar control args now works correctly.

### Modified: `R/collection-dispatch.R` — roxygen

Removed `@noRd` from the `survey_collection_args` parameter stub so an
`.Rd` file is generated; this is required for `@inheritParams
survey_collection_args` to find the `.if_missing_var` documentation in
the four new verb methods. Kept `@keywords internal` so the page is not
indexed.

### New: `tests/testthat/test-collection-filter.R`

Cross-design happy path with dual `test_collection_invariants` +
per-member `test_invariants` discipline; `.if_missing_var = "error"`
typed error + snapshot; `"skip"` drops offending member + typed
informational message; precedence check (per-call beats stored, both
directions); emptied error when every member is skipped; `.by`
rejection (snapshot); domain column preservation across chained filters;
`visible_vars` preservation on every member.

### New: `tests/testthat/test-collection-mutate.R`

Same coverage skeleton as filter, plus:

- Per-member `surveytidy_warning_mutate_weight_col` multiplicity:
  `withCallingHandlers()` count confirms one warning per affected
  member (not collapsed, not multiplied by collection size).
- Rowwise mixed-state pre-check: builds a collection where one member
  is rowwise and others aren't; asserts exactly one
  `surveytidy_warning_collection_rowwise_mixed` fires + snapshot of the
  message; uniform-state regression confirms the warning does not fire
  when every member's `is_rowwise()` agrees.
- Domain preservation after a pre-filter (mutate must not clobber the
  domain column).

### New: `tests/testthat/test-collection-arrange.R`

Cross-design happy path; `.if_missing_var` modes; emptied error;
domain preservation under sort (verifies the domain column travels
with the rows by reordering against the input); `visible_vars`
preservation. No `.by` rejection test — `arrange` doesn't accept `.by`.

### Modified: `plans/error-messages.md`

Added `surveytidy_warning_collection_rowwise_mixed` (warning, source
`R/mutate.R`). The other classes used by these methods
(`_collection_verb_failed`, `_collection_verb_emptied`,
`_collection_by_unsupported`, `_collection_skipped_surveys`,
`_pre_check_missing_var`) were already documented in PR 1.

## Verification

- `devtools::test()` — all packages tests pass (`16,163 PASS`)
- `devtools::check()` — 0 errors, 0 warnings, 0 notes
- `covr::package_coverage()` —
  `R/arrange.R` 100% · `R/collection-dispatch.R` 100% ·
  `R/filter.R` 98.43% · `R/mutate.R` 98.95%
  (uncovered lines in `filter.R` and `mutate.R` are pre-existing
  defensive branches not introduced by PR 2a)
- `air format` — applied to all touched files

## Files Modified

- `R/filter.R` — `filter.survey_collection`, `filter_out.survey_collection`
- `R/mutate.R` — `mutate.survey_collection` + rowwise mixed-state pre-check
- `R/arrange.R` — `arrange.survey_collection`
- `R/collection-dispatch.R` — `.unwrap_scalar_dots()`, pre-check skip
  for dotted args, `survey_collection_args` Rd visibility
- `R/zzz.R` — filled PR 2a registration block (4 `registerS3method` calls)
- `tests/testthat/test-collection-filter.R` — new
- `tests/testthat/test-collection-mutate.R` — new
- `tests/testthat/test-collection-arrange.R` — new
- `tests/testthat/_snaps/collection-filter.md` — new
- `tests/testthat/_snaps/collection-mutate.md` — new
- `tests/testthat/_snaps/collection-arrange.md` — new
- `man/arrange.Rd`, `man/filter.Rd`, `man/mutate.Rd` — regenerated for
  the new collection methods
- `man/survey_collection_args.Rd` — new (parameter stub now has Rd)
- `plans/error-messages.md` — added `surveytidy_warning_collection_rowwise_mixed`

In addition, `air format .` produced layout-only changes in
`R/case-when.R`, `R/if-else.R`, `R/na-if.R`, `R/recode-values.R`,
`R/replace-values.R`, `R/replace-when.R`, and
`tests/testthat/test-transform.R`. No behavioral change in any of those.
