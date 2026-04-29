# feat(collection): slice family verbs for survey_collection

**Date**: 2026-04-29
**Branch**: feature/survey-collection-slice-verbs
**Phase**: Phase 0.7
**Spec**: `plans/spec-survey-collection.md` (§IV.6, §III.2, §II.3.3, §IX.3)
**Implementation plan**: `plans/impl-survey-collection.md` (PR 2d)

## What Changed

PR 2d of the survey_collection verb-dispatch arc. Wires the six slice
verbs (`slice`, `slice_head`, `slice_tail`, `slice_min`, `slice_max`,
`slice_sample`) to `survey_collection`, adds a verb-specific slice-zero
pre-flight, and implements per-survey deterministic seeding for
`slice_sample`.

### Modified: `R/slice.R` — six `survey_collection` methods

- `slice.survey_collection(.data, ...)` — `.detect_missing = "none"`; no
  `.if_missing_var` arg (no column refs in the bare-positional API).
- `slice_head.survey_collection(.data, ..., n, prop)` and
  `slice_tail.survey_collection` — `.detect_missing = "none"`; same
  no-`.if_missing_var` rationale (per §III.2).
- `slice_min.survey_collection(.data, order_by, ..., n, prop, by,
  with_ties, na_rm, .if_missing_var)` and `slice_max.survey_collection` —
  `.detect_missing = "pre_check"` (data-mask `order_by`); reject
  per-call `by`.
- `slice_sample.survey_collection(.data, ..., n, prop, by, weight_by,
  replace, seed, .if_missing_var)` — detection mode is conditional on
  `weight_by`: `"pre_check"` when `weight_by` is supplied (data-mask
  reference), `"none"` otherwise. Rejects per-call `by`. Adds a
  reproducibility-oriented `seed` argument absent from the
  `survey_base` method.
- All non-dotted scalar args (`n`, `prop`, `replace`, `with_ties`,
  `na_rm`) flow through the dispatcher's new `.scalar_args` channel
  (added in this PR), avoiding the dplyr 1.2.0 "supply n or prop, but
  not both" error path triggered when explicit `prop = NULL` reaches
  `dplyr::slice_*`.

### New: `.check_slice_zero()` (slice-zero pre-flight)

Verb-specific helper at the top of `R/slice.R`. Per §IV.6:

- `slice`: NSE-evaluates `...` in an empty env; raises if any quosure
  resolves to a literal zero-length integer/numeric vector. Catches
  failures (column refs, `n()`) and silently passes.
- `slice_head`/`slice_tail`/`slice_min`/`slice_max`/`slice_sample`:
  raises if `n == 0L` or `prop == 0`.

Raises `surveytidy_error_collection_slice_zero` BEFORE any member is
touched — the pre-flight asserts no mutation by ref-comparing
`coll@surveys` in the corresponding tests.

### New: `.derive_member_seed()` and `.slice_sample_seeded()`

- `.derive_member_seed(survey_name, seed)` — deterministic per-survey
  seed via `strtoi(substr(rlang::hash(paste0(survey_name, "::", seed)),
  1, 7), 16L)`, returning an integer in `[0, 2^28)`.
- `.slice_sample_seeded()` — manual per-survey loop (mirrors the
  dispatcher's six-step contract) used only when `seed != NULL`. Saves
  and restores ambient `.Random.seed` via `on.exit()`. Wraps each
  per-survey `dplyr::slice_sample` call with `set.seed()` keyed on the
  derived per-survey seed. Per-survey results are stable regardless of
  collection ordering or addition/removal of other members.

### Modified: `R/collection-dispatch.R` — `.scalar_args` channel

`.dispatch_verb_over_collection()` gains a `.scalar_args = list()`
parameter. Splices NULL-pruned scalars after `enquos(...)` capture so
non-dotted control args (`n`, `prop`, `replace`, etc.) reach the
underlying `dplyr::slice_*` as plain values rather than quosures.
NULL-pruning sidesteps dplyr 1.2.0's `missing()`-based "supplied"
detection.

### Modified: `R/zzz.R` — survey_collection slice block filled

Six `registerS3method()` calls inside the pre-allocated
`# ── survey_collection: slice verbs (PR 2d) ──` block. All registered
against `"surveycore::survey_collection"` to the `dplyr` namespace.

### Modified: `plans/error-messages.md`

Added one row: `surveytidy_error_collection_slice_zero` (raised by the
verb-specific pre-flight before any member is touched).

### New: `tests/testthat/test-collection-slice.R`

Covers every slice variant with the §IX.3 dual-invariant pattern
(`test_collection_invariants(coll)` + per-member `test_invariants`):

- `.check_slice_zero()` direct unit tests for each verb's arg shape,
  plus the NSE-fallback path on `slice`.
- `.derive_member_seed()` direct unit tests: determinism,
  survey-name-dependence, seed-dependence, integer range.
- Per-verb happy path across all three design types.
- Slice-zero pre-flight for each variant — raises the typed error
  BEFORE any member is touched.
- `slice_min`/`slice_max`/`slice_sample` `by`-rejection
  (`surveytidy_error_collection_by_unsupported`).
- `slice_min` `.if_missing_var = "error"` (typed
  `surveytidy_error_collection_verb_failed`) and `"skip"`
  (heterogeneous fixture with bad members dropped).
- `slice_sample` reproducibility:
  - `seed = NULL`: same upstream `set.seed()` produces identical
    output across calls.
  - `seed = <int>`: identical output across calls; per-survey output
    invariant under collection reorder; ambient `.Random.seed`
    restored after the call; cleanup branch when no ambient
    `.Random.seed` exists.
  - `weight_by` + missing column under `"error"` (typed) and
    `"skip"` (drop bad members) for both `seed = NULL` and
    `seed = <int>` paths.
  - Empty-result error path for both stored `@if_missing_var = "skip"`
    and per-call `.if_missing_var = "skip"`.
- Per-member `surveycore_warning_physical_subset` multiplicity for
  every variant (assert N firings on N-member collection).
- `visible_vars` preservation across every variant.

### Modified: `R/slice.R` `inject()` argument-splice fix

Replaced the inline `!!!if (cond) list(arg = !!quo) else list()`
construction (which fails because `inject()` does not recurse through
`if/else` to substitute nested `!!`) with a pre-built args list
spliced via `!!!`. Affected both the dispatcher pass-through and the
`.slice_sample_seeded()` paths when `weight_by` is supplied.

## Verification

- `devtools::test()` — 18,987 tests pass (0 failures)
- `devtools::check()` — 0 errors, 0 warnings, 1 pre-approved note
  (timestamp note)
- `covr::package_coverage()` — 100% on `R/slice.R` and
  `R/collection-dispatch.R`; 100% overall
- `air format` — applied to all touched files

## Files Modified

- `R/slice.R` — six `survey_collection` methods, `.check_slice_zero`,
  `.derive_member_seed`, `.slice_sample_seeded`,
  `.reject_collection_by`
- `R/collection-dispatch.R` — `.scalar_args` parameter and NULL-prune
- `R/zzz.R` — filled PR 2d registration block (6 `registerS3method`
  calls)
- `tests/testthat/test-collection-slice.R` — new
- `plans/error-messages.md` — added
  `surveytidy_error_collection_slice_zero`
- `man/slice.Rd` — regenerated for the new collection methods and the
  master `@param` block
- `plans/impl-survey-collection.md` — PR 2d marked complete
