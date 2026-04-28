# feat(collection-dispatch): internal verb dispatcher for survey_collection

**Date**: 2026-04-28
**Branch**: feature/survey-collection-dispatch
**Phase**: Phase 0.7
**Spec**: `plans/spec-survey-collection.md`
**Implementation plan**: `plans/impl-survey-collection.md` (PR 1)

## What Changed

PR 1 of the survey_collection verb-dispatch arc. Ships the internal dispatcher
plus the test infrastructure and error-class registry that PRs 2a/2b/2c/2d
build on. **Zero verb methods are registered in this PR** — the dispatcher
exists but only its unit tests call it. Verb wiring lands in PRs 2a–2d via
labelled placeholder blocks inserted here so parallel branches can integrate
without merge conflicts.

### New file: `R/collection-dispatch.R`

- `.dispatch_verb_over_collection(fn, verb_name, collection, ..., .if_missing_var = NULL, .detect_missing = "none", .may_change_groups = FALSE)`
  — the six-step dispatcher per spec §II.3.1:
  1. Resolve `.if_missing_var` (per-call override → stored property).
  2. Per-member apply with one of three missing-variable detection strategies:
     `"pre_check"` (data-mask verbs), `"class_catch"` (tidyselect verbs), or
     `"none"` (verbs that don't reference columns).
  3. Emit a typed `surveytidy_message_collection_skipped_surveys` listing
     every skipped member.
  4. Raise `surveytidy_error_collection_verb_emptied` if no members survived.
  5. Rebuild via `surveycore::as_survey_collection(!!!results, .id = ..., .if_missing_var = ...)`.
  6. Assert `@groups` invariance (unless `.may_change_groups = TRUE`).
- `.pre_check_missing_vars(dots, survey, survey_name)` — internal helper for the
  data-mask detection path. Walks each captured quosure, extracts referenced
  symbols via `all.vars()`, drops `.data`/`.env` pronouns, drops symbols that
  resolve in the quosure's enclosing env, and returns a typed sentinel
  condition (`surveytidy_pre_check_missing_var`) the moment a missing name is
  found. Class chain deliberately omits `rlang_error` per D1 / Issue 3 so the
  dispatcher's parent-chain tests can distinguish the pre-check path from the
  class-catch path.
- `.apply_class_catch(fn, survey, dots, survey_name, verb_name, resolved_if_missing_var)`
  — internal helper for the tidyselect detection path. Wraps `fn(survey, ...)`
  in `tryCatch` keyed on `vctrs_error_subscript_oob` and
  `rlang_error_data_pronoun_not_found`, with a one-level parent-walk on
  generic `rlang_error` to recover the `all_of()` wrap case.
- `.handle_class_catch(cnd, survey_name, verb_name, resolved_if_missing_var)`
  — shared continuation: returns `NULL` under `"skip"`, re-raises a typed
  `surveytidy_error_collection_verb_failed` with `parent = cnd` under
  `"error"` so `rlang::cnd_chain()` shows the original tidyselect error.
- `survey_collection_args` roxygen stub (`@noRd`) documenting the
  per-verb-method `.if_missing_var` parameter for inheritance via `@inheritParams`
  in PRs 2a/2b/2c/2d.

### Modified: `R/utils.R`

Added two `.sc_*` wrappers under a new
`# ── survey_collection internal accessors ──` section, mirroring the existing
`.sc_update_design_var_names()` / `.sc_rename_metadata_keys()` pattern:

- `.sc_propagate_or_match()` — wraps `surveycore:::.propagate_or_match`
- `.sc_check_groups_match()` — wraps `surveycore:::.check_groups_match`

Both use `get(..., envir = asNamespace("surveycore"))` to avoid `:::` (which
would generate an `R CMD check` note).

### Modified: `R/zzz.R`

Added four labelled placeholder comment blocks at the end of `.onLoad()`,
one per downstream verb-family PR. Each PR inserts its `registerS3method()`
calls inside its own block, so PRs 2a/2b/2c/2d never edit the same hunk:

```r
# ── survey_collection: data-mask verbs (PR 2a) ──
# ── survey_collection: tidyselect verbs (PR 2b) ──
# ── survey_collection: grouping verbs (PR 2c) ──
# ── survey_collection: slice verbs (PR 2d) ──
```

### Modified: `R/rowwise.R`

Added two labelled placeholder blocks at end of file:

```r
# ── rowwise.survey_collection (PR 2b) ──
# ── end ──

# ── is_rowwise.survey_collection (PR 2c) ──
# ── end ──
```

### Modified: `tests/testthat/helper-test-data.R`

Three new helpers:

- `make_test_collection(seed)` — 3-member mixed-subclass collection (taylor +
  replicate + twophase), defaults to `@id = ".survey"` and
  `@if_missing_var = "error"`. Used wherever a generic test collection is
  needed.
- `make_heterogeneous_collection(seed)` — 3-member taylor collection with
  schemas: `m1` (full: `y1`/`y2`/`y3`), `m2` (drops `y2`/`y3`), `m3` (drops
  `y1`, adds `region`). Drives missing-variable detection tests.
- `test_collection_invariants(coll)` — collection-layer invariant checker:
  asserts `survey_collection` class, non-empty `@surveys`, `@id` is a
  non-empty `character(1)`, `@if_missing_var %in% c("error", "skip")`, and
  per-member `survey_base` G1/G1b invariants.

### New file: `tests/testthat/test-utils.R`

Two happy-path tests for the surveycore wrapper helpers in `R/utils.R`:
`.sc_propagate_or_match()` and `.sc_check_groups_match()`. Each test calls
the wrapper with inputs from `make_test_collection(seed = 42L)` and asserts
`expect_identical()` against a direct
`get(".X", envir = asNamespace("surveycore"))(...)` call, covering both the
namespace lookup and the forwarded call lines.

### New file: `tests/testthat/test-collection-dispatch.R`

26 tests, 100% coverage on `R/collection-dispatch.R`. Exercises every
§IX.4 bullet: ungroup pass-through, name/order preservation, both
empty-result message-source variants (stored vs. per-call) via snapshot,
typed `surveytidy_error_collection_verb_emptied` class, every pre-check
env-filter substep (locally-bound, `.data`/`.env` pronouns, column ref,
truly missing name, global-env constants via enclosing function), sentinel
class chain pin (`!inherits(cnd, "rlang_error")`), re-raise parent chain
visible via manual `$parent` walk, typed
`surveytidy_message_collection_skipped_surveys` (snapshot + class), all
three class-catch paths (`vctrs_error_subscript_oob` direct, `all_of()`
wrap via parent walk, `rlang_error_data_pronoun_not_found` both wrapped
and direct, plus fallthrough `stop(cnd)` for unrecognized rlang errors),
`.may_change_groups = FALSE` regression catch (mock fn that mutates
`attr(x, "groups")` raises a `simpleError`), per-call vs stored
precedence in both directions, and a separation-of-concerns test that
inspects the deparsed function body to verify the dispatcher does not
delegate to `surveycore::.dispatch_over_collection`.

### Modified: `plans/error-messages.md`

Added five rows for the dispatcher-layer conditions:

| Class | Type | Source |
|---|---|---|
| `surveytidy_error_collection_verb_emptied` | error | `R/collection-dispatch.R` |
| `surveytidy_error_collection_verb_failed` | error | `R/collection-dispatch.R` |
| `surveytidy_error_collection_by_unsupported` | error | `R/filter.R`, `R/mutate.R`, `R/slice.R` (placeholder; raised by PR 2a/2d methods) |
| `surveytidy_pre_check_missing_var` | error (internal sentinel) | `R/collection-dispatch.R` |
| `surveytidy_message_collection_skipped_surveys` | message | `R/collection-dispatch.R` |

### Modified: `DESCRIPTION`

Bumped `surveycore (>= 0.0.0.9000)` → `surveycore (>= 0.8.2)` (the lowest
release exporting `as_survey_collection`, `add_survey`, `remove_survey`,
`set_collection_id`, `set_collection_if_missing_var`, and the internal
`.propagate_or_match` / `.check_groups_match` accessed via the new `.sc_*`
wrappers).

**Note:** the impl plan also calls for `vctrs (>= 0.7.0)` to be added in
this PR, but `vctrs::vec_c()` isn't used until PR 3 (`pull.survey_collection`).
Adding it now generates a `Namespace in Imports field not imported from`
note. Deferring the `vctrs` Imports entry to PR 3 keeps `R CMD check` clean
in the meantime.

## Verification

- `devtools::test()` — all packages tests pass
- `devtools::check()` — 0 errors, 0 warnings, 1 pre-approved note ("unable
  to verify current time")
- `covr::package_coverage()` — 100% on `R/collection-dispatch.R`
- `air format` — applied to all touched files

## Files Modified

- `R/collection-dispatch.R` — new
- `R/utils.R` — `.sc_propagate_or_match()`, `.sc_check_groups_match()`
- `R/zzz.R` — 4 placeholder blocks inside `.onLoad()`
- `R/rowwise.R` — 2 placeholder blocks at file end
- `tests/testthat/helper-test-data.R` — 3 new helpers
- `tests/testthat/test-collection-dispatch.R` — new (26 tests)
- `tests/testthat/test-utils.R` — new (2 happy-path tests for `.sc_*` wrappers)
- `tests/testthat/_snaps/collection-dispatch.md` — new snapshot file
- `plans/error-messages.md` — 4 error rows + new Messages section
- `DESCRIPTION` — surveycore pin bumped to `>= 0.8.2`
