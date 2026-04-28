# Implementation Plan: `survey_collection` Verb Dispatch

**Spec:** `plans/spec-survey-collection.md` (v0.2, methodology-locked + Stage 4 complete)
**Decisions log:** `plans/decisions-survey-collection.md`
**Phase:** 0.7
**Branch prefix:** `feature/survey-collection-*`
**Changelog dir:** `changelog/phase-0.7/`

---

## Overview

Deliver dplyr/tidyr **verb dispatch** for `survey_collection` objects — the
class, validators, and analysis-side dispatcher already ship in surveycore.
Work is sequenced as one foundation PR (the dispatcher + test infrastructure),
four verb-family PRs that share that foundation, a collapsing-verbs PR, and a
final polish PR for join error stubs and re-exports. PRs 2a/2b/2c/2d all ship
in parallel after PR 1.

---

## PR Map

- [x] PR 1: `feature/survey-collection-dispatch` — dispatcher, `.sc_*` wrappers, test helpers (`make_test_collection`, `make_heterogeneous_collection`, `test_collection_invariants`), error-class registry rows for dispatcher-level conditions, dispatcher unit tests
- [ ] PR 2a: `feature/survey-collection-data-mask-verbs` — `filter` / `filter_out` / `mutate` / `arrange` collection methods (`.detect_missing = "pre_check"`), shared `.by` rejection, per-verb test files
- [ ] PR 2b: `feature/survey-collection-tidyselect-verbs` — `select` / `relocate` / `rename` / `rename_with` / `drop_na` / `distinct` / `rowwise` collection methods (`.detect_missing = "class_catch"`), `select` group-removal pre-flight, `rename`/`rename_with` group-rename pre-flight, per-verb test files
- [ ] PR 2c: `feature/survey-collection-grouping-verbs` — `group_by` / `ungroup` / `group_vars` / `is_rowwise` collection methods, per-verb test files
- [ ] PR 2d: `feature/survey-collection-slice-verbs` — `slice` / `slice_head` / `slice_tail` / `slice_min` / `slice_max` / `slice_sample` collection methods, slice-zero pre-flight, `slice_sample` reproducibility, per-verb test files
- [ ] PR 3: `feature/survey-collection-collapsing` — `pull.survey_collection`, `glimpse.survey_collection` (default + `.by_survey` modes), id-collision pre-flight, type-coercion footer (D7), per-verb test files
- [ ] PR 4: `feature/survey-collection-joins-and-reexports` — `*_join.survey_collection` error stubs (V8), surveycore setter re-exports, NEWS block, DESCRIPTION pin bumps, final QA

---

### PR 1: Dispatcher + test infrastructure

**Branch:** `feature/survey-collection-dispatch`
**Depends on:** none

**Files:**
- `R/collection-dispatch.R` — NEW: `.dispatch_verb_over_collection()` and the `survey_collection_args` roxygen stub
- `R/utils.R` — MODIFIED: add `.sc_propagate_or_match()`, `.sc_check_groups_match()`
- `R/zzz.R` — MODIFIED: structural prep only (no per-verb registrations yet); add four labelled placeholder blocks (one per verb-family PR) so PRs 2a/2b/2c/2d can each insert inside their own block without merge conflicts
- `R/rowwise.R` — MODIFIED: pre-allocate two labelled placeholder blocks (`# ── rowwise.survey_collection (PR 2b) ──` and `# ── is_rowwise.survey_collection (PR 2c) ──`) so PRs 2b and 2c insert into non-overlapping regions.
- `DESCRIPTION` — MODIFIED: add `vctrs (>= 0.7.0)` to Imports; bump `surveycore` minimum-version pin to a version exporting `add_survey`, `remove_survey`, `set_collection_id`, `set_collection_if_missing_var`, `as_survey_collection`, `.propagate_or_match`, `.check_groups_match`
- `tests/testthat/helper-test-data.R` — MODIFIED: add `make_test_collection()`, `make_heterogeneous_collection()`, `test_collection_invariants()`
- `tests/testthat/test-collection-dispatch.R` — NEW: dispatcher unit tests (per §IX.4)
- `plans/error-messages.md` — MODIFIED: add rows for `surveytidy_error_collection_verb_emptied`, `surveytidy_error_collection_verb_failed`, `surveytidy_error_collection_by_unsupported`, `surveytidy_message_collection_skipped_surveys`, `surveytidy_pre_check_missing_var`
- `changelog/phase-0.7/feature-collection-dispatch.md` — NEW

**Acceptance criteria:**
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] `tests/testthat/test-collection-dispatch.R` covers all §IX.4 bullets:
  - [ ] Names and order preserved (and skipped members removed without reordering surviving members)
  - [ ] `@groups` sync correctness when a per-member verb updates `@groups`
  - [ ] Re-raise with `parent = cnd` produces a chain visible via `rlang::cnd_chain()`
  - [ ] Dispatcher does not call `surveycore::.dispatch_over_collection()`
  - [ ] Env-aware pre-check substeps (locally-bound constant; global-env constant; `.data`/`.env` pronouns; column reference resolved by `@data`; truly missing name flagged with `surveytidy_pre_check_missing_var`)
  - [ ] Internal `@groups` regression catch (`expect_error(class = "simpleError")` when a mock per-member method mutates `@groups` under `.may_change_groups = FALSE`)
  - [ ] Sentinel class chain pin (`inherits(cnd, "surveytidy_pre_check_missing_var") && !inherits(cnd, "rlang_error")` for the synthesized condition)
  - [ ] Typed `surveytidy_message_collection_skipped_surveys` (`expect_message(class = …)` plus snapshot of the body naming every skipped survey)
- [ ] `make_test_collection()` and `make_heterogeneous_collection()` exercised
      in dispatcher tests; both helpers smoke-tested
- [ ] `test_collection_invariants()` validated against a known-good collection
- [ ] `covr::package_coverage()` ≥98% on `R/collection-dispatch.R`
- [ ] `air format .` run and committed
- [ ] `plans/error-messages.md` updated for the 5 dispatcher-layer classes
- [ ] Changelog entry written and committed on this branch
- [ ] DESCRIPTION pin is verified against the installed surveycore at PR time
      (per spec §X) and bumped if needed

**Tasks:**

1. Branch from `develop`; record current `surveycore` installed version
   (`packageVersion("surveycore")`).
2. Update `DESCRIPTION`: add `vctrs (>= 0.7.0)` under Imports; pin
   `surveycore` at the recorded version (or the lowest version that
   exports every symbol in spec §VI + §XIII.1).
3. Run `devtools::check()` to confirm DESCRIPTION still parses.
4. Add `.sc_propagate_or_match()` and `.sc_check_groups_match()` thin
   wrappers to `R/utils.R` under a new section comment
   `# ── survey_collection internal accessors ──`. Mirror the existing
   `.sc_update_design_var_names()` pattern.
5. Write a failing test in `helper-test-data.R` smoke pass via
   `test-wiring.R`-style file: `make_test_collection(seed = 42)` returns
   a 3-member collection with `@id == ".survey"` and
   `@if_missing_var == "error"`.
6. Implement `make_test_collection()` per spec §IX.2. Run; confirm
   passing.
7. Implement `make_heterogeneous_collection()` per spec §IX.2 with the
   full contract (3 members named `m1`/`m2`/`m3`, all `survey_taylor`,
   schemas: full / drops `y2`+`y3` / drops `y1` adds `region`). Write
   contract test asserting member names, schema, common-column union.
8. Run; confirm passing.
9. Implement `test_collection_invariants()` per spec §IX.2. Add a
   smoke test in `test-collection-dispatch.R` that calls it on a
   fresh `make_test_collection()`.
10. Run; confirm passing.
11. Author the `survey_collection_args` roxygen stub at the top of
    `R/collection-dispatch.R` per spec §VIII (with `@noRd`).
12. Run `devtools::document()` to confirm the stub doesn't generate a
    bogus `.Rd` file.
13. Write a failing dispatcher test: calling
    `.dispatch_verb_over_collection(fn = dplyr::ungroup, verb_name = "ungroup", collection = coll, .detect_missing = "none", .may_change_groups = TRUE)`
    on `make_test_collection()` returns a `survey_collection` with
    `@groups == character(0)`.
14. Implement `.dispatch_verb_over_collection()` in
    `R/collection-dispatch.R` covering steps 1–6 of spec §II.3.1.
    Default `.detect_missing = "none"` and `.may_change_groups = FALSE`
    per Issue 28.
15. Run the test from step 13; confirm passing.
16. Write a failing test for step 1.5 — `id_from_stored` flag:
    construct a collection where `@if_missing_var = "skip"`; call the
    dispatcher with `.if_missing_var = NULL` and verify the empty-result
    error message reports the per-call/stored distinction (snapshot the
    body).
17. Implement step 1.5 in the dispatcher. Run; confirm passing.
18. Write a failing test for the pre-check env-filter substeps from
    §II.3.1 step 2 (each bullet in §IX.4):
    locally-bound constant; global-env constant; `.data` / `.env`
    pronouns; column reference resolved by `@data`; truly missing name.
19. Implement the pre-check path with the 4-substep filter
    (`all.vars` → drop `.data`/`.env` → drop env-resolvable → compare
    to `@data`).
20. Run; confirm passing.
21. Write a failing test that the pre-check sentinel class chain is
    `c("surveytidy_pre_check_missing_var", "error", "condition")` and
    NOT `inherits(cnd, "rlang_error")`
    (per `decisions-survey-collection.md`, 2026-04-27 Stage 3
    spec-review resolution, Q: Issue 3).
22. Synthesize the sentinel via `rlang::abort(class = ...)` (or
    `cli::cli_abort(class = ...)` with explicit class chain). Run;
    confirm passing.
23. Write failing tests for class-catch path: trigger
    `vctrs_error_subscript_oob` and `rlang_error_data_pronoun_not_found`;
    verify dispatcher catches both. Include `all_of()` wrap case
    (parent-walk one level).
24. Implement the class-catch handler. Run; confirm passing.
25. Write a failing test for the skipped-surveys typed message:
    construct `make_heterogeneous_collection()`; dispatch a verb that
    triggers a missing variable on one member under
    `resolved_if_missing_var = "skip"`; assert
    `expect_message(class = "surveytidy_message_collection_skipped_surveys")`
    fires AND snapshot the body (must name the skipped survey).
26. Implement step 3 (skipped-surveys message). Run; confirm passing.
27. Write a failing test for empty-result raising
    `surveytidy_error_collection_verb_emptied`; snapshot the message.
28. Implement step 4. Run; confirm passing.
29. Write a failing test for step 5 constructor rebuild via
    `surveycore::as_survey_collection(!!!results, .id = ..., .if_missing_var = ...)`.
    Verify `out_coll@id` and `out_coll@if_missing_var` match input;
    `names(out_coll@surveys)` matches input minus skipped.
30. Implement step 5. Run; confirm passing.
31. Write a failing test for the `.may_change_groups = FALSE`
    regression catch — use a mock per-member function that mutates
    `@groups`; assert `expect_error(class = "simpleError")`.
32. Implement the `stopifnot()` assertion. Run; confirm passing.
33. Write a failing test for re-raise with `parent = cnd` chain
    (`rlang::cnd_chain()` shows both).
34. Implement re-raise via `cli::cli_abort(parent = cnd, class = "surveytidy_error_collection_verb_failed")`.
    Run; confirm passing.
35. Write a failing test pinning the rule from spec §II.3 final
    bullet: dispatcher does NOT call
    `surveycore::.dispatch_over_collection`. Use `mockery::stub()` or
    a search of the source.
36. Confirm test passes (negative assertion).
37. Add 5 rows to `plans/error-messages.md` per §VII.1 (for the
    classes listed in this PR's scope).
38. Add four labelled placeholder comment blocks in `R/zzz.R`, one
    per verb-family PR — each on its own pair of lines so parallel
    inserts into different blocks never conflict at integration:

    ```r
    # ── survey_collection: data-mask verbs (PR 2a) ──

    # ── survey_collection: tidyselect verbs (PR 2b) ──

    # ── survey_collection: grouping verbs (PR 2c) ──

    # ── survey_collection: slice verbs (PR 2d) ──
    ```

    Each PR inserts its `registerS3method()` calls inside its own
    block.
39. Add two labelled placeholder comment blocks in `R/rowwise.R`,
    appended after the existing file content — each on its own pair
    of lines so parallel inserts from PRs 2b and 2c never conflict
    at integration:

    ```r
    # ── rowwise.survey_collection (PR 2b) ──
    # ── end ──

    # ── is_rowwise.survey_collection (PR 2c) ──
    # ── end ──
    ```

    PR 2b inserts `rowwise.survey_collection` inside the first block;
    PR 2c inserts `is_rowwise.survey_collection` inside the second.
40. Run the full test suite and `devtools::check()`. Resolve any
    notes/warnings.
41. Run `covr::package_coverage()`; confirm ≥98% on the new file.
42. Run `air format .`.
43. Author `changelog/phase-0.7/feature-collection-dispatch.md`.
44. Commit each logical chunk separately; open PR.

**Notes:**
- This PR ships zero verb-side methods. The dispatcher exists but has no
  call sites in the package. Tests exercise it directly. The
  `register S3method` calls are deferred to the verb-family PRs so each
  one is self-contained.
- The `surveycore` minimum-version pin must be confirmed at PR time —
  recompute against `packageVersion("surveycore")` after rebasing onto
  the latest `develop`. If a re-exported setter isn't in the pinned
  version, bump.
- The dispatcher signature defaults `.detect_missing = "none"` and
  `.may_change_groups = FALSE` per Issue 28 — this is the safe default
  for any verb method that forgets to pass an explicit value.
- Do NOT register dispatch for `survey_collection` in `zzz.R` yet —
  there are no methods to register.
- The `surveytidy_pre_check_missing_var` class chain MUST drop
  `rlang_error` (per `decisions-survey-collection.md`, 2026-04-27
  Stage 3 spec-review resolution, Q: Issue 3). Construct the condition via
  `rlang::abort(class = c("surveytidy_pre_check_missing_var", "error", "condition"))`
  (or `cli::cli_abort(class = ...)` with the same chain — verify the
  class chain by inspection in the test, not just by name).

---

### PR 2a: Data-masking collection verbs

**Branch:** `feature/survey-collection-data-mask-verbs`
**Depends on:** PR 1

**Files:**
- `R/filter.R` — MODIFIED: add `filter.survey_collection`, `filter_out.survey_collection`
- `R/mutate.R` — MODIFIED: add `mutate.survey_collection` (includes rowwise mixed-state pre-check per spec §IV.5)
- `R/arrange.R` — MODIFIED: add `arrange.survey_collection`
- `R/zzz.R` — MODIFIED: register S3 methods for these verbs against `"surveycore::survey_collection"`
- `tests/testthat/test-collection-filter.R` — NEW
- `tests/testthat/test-collection-mutate.R` — NEW
- `tests/testthat/test-collection-arrange.R` — NEW (arrange-only file; slice family lives in PR 2d's `test-collection-slice.R`)
- `plans/error-messages.md` — MODIFIED: add `surveytidy_warning_collection_rowwise_mixed`
- `changelog/phase-0.7/feature-collection-data-mask-verbs.md` — NEW

**Acceptance criteria:**
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] Per-verb test files cover every §IX.3 row applicable to data-mask
      verbs: happy path (with dual `test_collection_invariants` +
      `test_invariants` discipline), `@id`/`@if_missing_var` preservation,
      `.if_missing_var = "error"`/`"skip"`/precedence, empty-result,
      domain preservation (skipped for filter/filter_out — these
      modify the domain; required for mutate/arrange), per-member
      warning multiplicity for `mutate`'s `surveytidy_warning_mutate_weight_col`,
      cross-design via `make_test_collection()`, subclass-asymmetric
      design columns (where applicable)
- [ ] Domain column preservation asserted on mutate + arrange
- [ ] `visible_vars` preservation asserted on every verb in this PR
      (filter, filter_out, mutate, arrange): on a collection where
      every member has `@variables$visible_vars = c("y1", "y2")`, every
      member still has the same `visible_vars` after the verb
- [ ] `.by` rejection raises `surveytidy_error_collection_by_unsupported`
      from filter, filter_out, mutate (snapshot per verb)
- [ ] `mutate.survey_collection` rowwise mixed-state pre-check
      raises `surveytidy_warning_collection_rowwise_mixed` exactly
      once when `is_rowwise()` is non-uniform across `coll@surveys`,
      names the offending members in the warning, and dispatches
      normally afterward; tested via `withCallingHandlers()` count
      (snapshot of message) per spec §IV.5
- [ ] All examples include `library(dplyr)` per CI gotcha
- [ ] `covr::package_coverage()` ≥95% on each modified file
- [ ] `air format .` run
- [ ] Changelog entry written

**Tasks:**

For EACH verb (`filter`, `filter_out`, `mutate`, `arrange`),
in this order. The TDD cycle below is one full pass per verb.

1. Identify the verb. Open the existing source file (e.g., `R/filter.R`).
2. Write a failing happy-path test in
   `tests/testthat/test-collection-<verb>.R`: build
   `make_test_collection()`, call
   `test_collection_invariants(coll)` + `test_invariants(member)`
   loop, apply the verb, call both invariant helpers on the output,
   assert verb-specific behavior (e.g., for `filter` — domain column
   updated on every member; member count and order preserved).
3. Run the test; confirm FAILING (no method registered yet).
4. Author the `verb.survey_collection` method per spec §III.1 template
   in the existing source file (under the `survey_base` method and the
   `survey_result` method, if present). Use the per-verb argument
   table from §IV; pass `.detect_missing = "pre_check"` and
   `.may_change_groups = FALSE` (except `group_by` — handled in PR 2c).
5. Add `#' @rdname <verb>` and `#' @method <verb> survey_collection`
   roxygen tags. Add `#' @inheritParams survey_collection_args` for
   `.if_missing_var`. Add `#' @section Survey collections:` block per
   §VIII point 3.
6. Add an `@examples` block showing collection usage. Include
   `library(dplyr)` as the first example line per CI gotcha.
7. Register the method in `R/zzz.R` via `registerS3method()` against
   `"surveycore::survey_collection"`, mirroring the `survey_base`
   block. Insert inside the
   `# ── survey_collection: data-mask verbs (PR 2a) ──` block
   pre-allocated by PR 1.
8. Run `devtools::document()`. Inspect `NAMESPACE` for the
   `S3method(<verb>, surveycore::survey_collection)` line.
9. Run the test from step 2; confirm PASSING.
10. Write a failing `.if_missing_var = "error"` test using
    `make_heterogeneous_collection()`: a referenced column is missing
    on one member; assert
    `expect_error(class = "surveytidy_error_collection_verb_failed")`
    AND `expect_snapshot(error = TRUE, ...)` per spec §IX.5.
11. Run; confirm passing (the dispatcher already implements this; the
    test verifies the wiring).
12. Write a failing `.if_missing_var = "skip"` test on the same
    fixture: assert the offending member is dropped AND
    `expect_message(class = "surveytidy_message_collection_skipped_surveys")`
    fires.
13. Run; confirm passing.
14. Write a failing `.if_missing_var` precedence test: stored
    `coll@if_missing_var = "error"` + per-call `"skip"` → skip wins;
    reverse → error wins.
15. Run; confirm passing.
16. Write a failing empty-result test: a verb call where every member
    is skipped → `expect_error(class = "surveytidy_error_collection_verb_emptied")`
    + snapshot.
17. Run; confirm passing.
18. Write a failing `.by` rejection test (filter, filter_out, mutate
    only): per-call `.by = some_col` → `expect_error(class = "surveytidy_error_collection_by_unsupported")`
    + snapshot. The `.by` rejection MUST run BEFORE any dispatch (no
    side effects on members).
19. Implement the `.by` check at the top of each verb method per spec
    §III.1's "Shared `.by` rejection contract" using the cli template.
20. Run; confirm passing.
21. Write a failing per-member warning multiplicity test (mutate
    only): mutate the weight column on a 3-member collection;
    assert `surveytidy_warning_mutate_weight_col` fires 3 times via
    `withCallingHandlers()` count.
22. Run; confirm passing (no implementation needed — per-member
    dispatch already produces N firings).
22a. Write a failing rowwise mixed-state warning test (mutate
    only). Build a 3-member collection where one member has been
    passed through `rowwise()` before `as_survey_collection()` and
    the other two have not. Call `mutate(coll, z = y1 + 1)`. Assert
    via `withCallingHandlers()` that
    `surveytidy_warning_collection_rowwise_mixed` fires EXACTLY
    once (not per member), AND that the warning message names the
    rowwise member by `coll@surveys` name. Snapshot. Then assert
    `mutate()` still returns a valid collection (per-member
    dispatch is not blocked by the warning) — call
    `test_collection_invariants(out)` and `test_invariants(member)`
    on every member.
22b. Implement the pre-check at the top of `mutate.survey_collection`
    (after `.by` rejection, before the dispatcher call). Compute
    `rowwise_state <- vapply(.data@surveys, is_rowwise, logical(1))`;
    if `any(rowwise_state) && !all(rowwise_state)`, emit
    `surveytidy_warning_collection_rowwise_mixed` once with class
    `"surveytidy_warning_collection_rowwise_mixed"`, naming the
    rowwise members (`names(.data@surveys)[rowwise_state]`) and
    non-rowwise members (`names(.data@surveys)[!rowwise_state]`)
    in the message. Use the `cli_warn()` template per
    `.claude/rules/code-style.md` §3 (`"!"` + two `"i"` bullets:
    one explaining the per-member semantics divergence, one
    pointing to `rowwise(coll)` or `ungroup(coll)` as the fix).
    Do NOT abort dispatch — fall through to the regular dispatcher
    call.
22c. Run; confirm passing.
22d. Write a failing uniform-state regression test: on a uniformly
    rowwise collection (every member rowwise), and on a uniformly
    non-rowwise collection (the default), `mutate()` does NOT fire
    `surveytidy_warning_collection_rowwise_mixed`. Use
    `withCallingHandlers()` to assert zero firings. Snapshot
    omitted (no warning means no message).
22e. Run; confirm passing.
23. Write a failing cross-design assertion test: every prior assertion
    runs unchanged on `make_test_collection()` (which mixes taylor /
    replicate / twophase). Use a parameterized test loop or inline
    assertions.
24. Run; confirm passing.
25. Write a failing domain-preservation test (mutate + arrange only):
    pre-filter the input; apply the verb; assert domain column still
    present on every surviving member with unchanged values.
26. Run; confirm passing.
27. Write a failing `visible_vars`-preservation test (every verb in this
    PR): build `make_test_collection()`; on every member, set
    `@variables$visible_vars <- c("y1", "y2")` (use the `attr<-` bypass
    + `S7::validate()` pattern); apply the verb; assert every surviving
    member's `@variables$visible_vars` is still `c("y1", "y2")`.
28. Run; confirm passing.
29. Move to next verb. Repeat 1–28.

**Per-PR closure tasks (after all 4 verbs):**

30. Add the new warning class row to `plans/error-messages.md`:
    `surveytidy_warning_collection_rowwise_mixed` (source `R/mutate.R`).
31. Run full test suite. Resolve any failures.
32. Run `devtools::check()`. Resolve any notes/warnings.
33. Run `covr::package_coverage()`; confirm ≥95% on each modified file.
34. Run `air format .`.
35. Author `changelog/phase-0.7/feature-collection-data-mask-verbs.md`.
36. Open PR.

**Notes:**
- All 4 verbs use `.detect_missing = "pre_check"` because they accept
  bare-name data-masking expressions.
- `arrange` is data-mask (sort expressions). `filter`/`filter_out`
  reject `.by`; `mutate` rejects `.by`; `arrange` doesn't accept
  `.by` (no rejection needed).
- The `@section Survey collections:` block must include the
  per-member-warning-multiplicity note for `mutate` (per spec
  §IV.5) and per-member-empty-domain-warning note for
  `filter`/`filter_out` (per V4).
- `filter_out` is a surveytidy primitive (not in dplyr) — its
  `survey_base` method already exists. The collection method follows
  the same template as `filter`.
- Domain-preservation tests for filter/filter_out are
  SKIPPED per spec §IX.3 — those verbs legitimately modify the
  domain column.
- `mutate.survey_collection` is the only collection-layer consumer of
  per-member rowwise state. The mixed-state pre-check (steps 22a–22e)
  implements the soft uniformity invariant from spec §IV.10 — rowwise
  uniformity cannot be enforced at the surveycore class validator
  because `@variables$rowwise` is owned by surveytidy. The check is
  diagnostic only: it warns once, names the offending members, and
  falls through to per-member dispatch. The fixture in step 22a builds
  a mixed collection by calling `rowwise()` (the `survey_base` method
  shipped in v0.3.0) on one member before `as_survey_collection()`,
  so this PR does not depend on `rowwise.survey_collection` (PR 2b).

---

### PR 2b: Tidyselect collection verbs

**Branch:** `feature/survey-collection-tidyselect-verbs`
**Depends on:** PR 1

**Files:**
- `R/select.R` — MODIFIED: add `select.survey_collection`, `relocate.survey_collection`, group-removal pre-flight helper
- `R/rename.R` — MODIFIED: add `rename.survey_collection`, `rename_with.survey_collection`, group-rename pre-flight helper
- `R/distinct.R` — MODIFIED: add `distinct.survey_collection`
- `R/drop-na.R` — MODIFIED: add `drop_na.survey_collection`
- `R/rowwise.R` — MODIFIED: add `rowwise.survey_collection` inside the pre-allocated `# ── rowwise.survey_collection (PR 2b) ──` block (allocated by PR 1)
- `R/zzz.R` — MODIFIED: register S3 methods for these verbs
- `tests/testthat/test-collection-select.R` — NEW
- `tests/testthat/test-collection-rename.R` — NEW
- `tests/testthat/test-collection-distinct.R` — NEW
- `tests/testthat/test-collection-drop-na.R` — NEW
- `tests/testthat/test-collection-rowwise.R` — NEW (covers `rowwise.survey_collection`; `is_rowwise` lives in PR 2c)
- `plans/error-messages.md` — MODIFIED: add `surveytidy_error_collection_select_group_removed`, `surveytidy_error_collection_rename_group_partial`
- `changelog/phase-0.7/feature-collection-tidyselect-verbs.md` — NEW

**Acceptance criteria:**
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] Per-verb test files cover every §IX.3 row applicable to tidyselect
      verbs: happy path with dual invariants, `@id`/`@if_missing_var`,
      `.if_missing_var` modes + precedence, empty-result, domain
      preservation, `visible_vars` propagation (select/relocate),
      per-member `@metadata` (rename/select), cross-design,
      subclass-asymmetric design columns (rename/rename_with/select/
      relocate), per-member warning multiplicity for
      `surveytidy_warning_rename_design_var`
- [ ] V9 (per-survey distinct, no cross-survey collapse) explicitly tested
- [ ] `drop_na` test covers happy path with dual invariants,
      `@id`/`@if_missing_var` preservation, `.if_missing_var` modes +
      precedence, empty-result, missing-variable detection via
      class-catch on `vctrs_error_subscript_oob`, cross-design via
      `make_test_collection()`, and `visible_vars` preservation
      (collection where every member has
      `@variables$visible_vars = c("y1", "y2")` retains it on every
      surviving member after the verb). Domain preservation is
      SKIPPED per spec §IX.3 — `drop_na` legitimately modifies the
      domain column.
- [ ] `select` group-removal pre-flight raises
      `surveytidy_error_collection_select_group_removed` BEFORE any
      member is mutated (snapshot)
- [ ] `rename`/`rename_with` group-rename pre-flight raises
      `surveytidy_error_collection_rename_group_partial` BEFORE any
      member is mutated (snapshot)
- [ ] `relocate` exempt from group-removal pre-flight, with a test
      asserting it does NOT raise on negative tidyselect of a group
      column (Issue 21)
- [ ] `covr::package_coverage()` ≥95% on each modified file
- [ ] All examples include `library(dplyr)` (or `library(tidyr)` for
      `drop_na`) per CI gotcha

**Tasks:**

For each verb (`select`, `relocate`, `rename`, `rename_with`, `distinct`,
`drop_na`, `rowwise`), follow the same TDD cycle as PR 2a (steps 1–28).
Differences and additions:

1. Use `.detect_missing = "class_catch"` for all verbs (except where the
   verb-specific extras below override).
1a. Insert each `registerS3method()` call inside the
   `# ── survey_collection: tidyselect verbs (PR 2b) ──` block in
   `R/zzz.R` pre-allocated by PR 1.
1b. Skip PR 2a steps 27–28 (visible_vars preservation) for `select` and
   `relocate` — those verbs legitimately change `visible_vars` and have
   their own propagation tests under "Verb-specific extras / Select"
   below. Apply steps 27–28 unchanged to `rename`, `rename_with`,
   `distinct`, `drop_na`, and `rowwise`.
1c. For `drop_na` only: examples must include `library(tidyr)` (not
   `library(dplyr)`) per CI gotcha, since `drop_na` is re-exported from
   tidyr.
1d. Skip PR 2a steps 25–26 (domain preservation) for `drop_na` — like
   `filter`/`filter_out`, it legitimately modifies the domain column
   per spec §IX.3. Apply 25–26 unchanged to the other tidyselect verbs.
2. Each verb's class-catch test (analogue of PR 2a step 10/11) must
   trigger `vctrs_error_subscript_oob` (or `rlang_error_data_pronoun_not_found`
   for `.data$missing_col`); confirm dispatcher catches and re-raises
   per `.if_missing_var`.

**Verb-specific extras:**

**Select:**
3. Implement `.check_select_group_removal(coll, expr)` helper. Resolve
   the user's tidyselect against `coll@surveys[[1]]@data`; check
   whether any column in `coll@groups` would be removed. Place the
   helper at the top of `R/select.R` per code-style.md helper-placement
   rule (used in 1 file). Raise
   `surveytidy_error_collection_select_group_removed` BEFORE
   dispatch.
4. Write a failing test: `select(coll_with_groups, -group_col)` raises
   the typed error AND no member's `@data` has been touched (verify
   by comparing `coll@surveys` pre/post — must be identical refs).
5. Implement and run; confirm passing.
6. Add `visible_vars` propagation tests per §IX.3:
   `select(coll, y1, y2)` → every member's `@variables$visible_vars`
   equals `c("y1", "y2")`; `select(coll, psu, strata)` → every
   member's `@variables$visible_vars` is NULL.
7. Add a `select(coll, repweights)` test on `make_test_collection()`
   under both `.if_missing_var` modes per the subclass-asymmetric row
   in §IX.3.

**Relocate:**
8. Add a regression test asserting `relocate.survey_collection` does
   NOT run the group-removal pre-flight: `relocate(coll, -group_col, .before = wt)`
   succeeds (column reordered, not removed). Verifies Issue 21.

**Rename / rename_with:**
9. Implement `.check_group_rename_coverage(coll, rename_map)` helper.
   For every `old_name` in `coll@groups`, verify every member's
   `@data` contains it. Raise
   `surveytidy_error_collection_rename_group_partial` BEFORE
   dispatch.
10. Write a failing pre-flight test for `rename`: this case is
    structurally redundant given G1b but kept as defense-in-depth
    (per §IV.4 reachability note); the test asserts the helper is
    invoked and behaves correctly on a synthetic G1b violation
    (manually construct a malformed collection via `attr<-` bypass —
    this requires deliberate test infrastructure, not a real
    user-reachable case).
11. Write a failing pre-flight test for `rename_with`: build a
    grouped fixture by constructing three `survey_taylor` members
    inline, calling `dplyr::group_by(member, psu)` on each, and
    passing the grouped members to `surveycore::as_survey_collection()`
    — the constructor sees consistent `@groups = "psu"` on every
    member and on the collection (G1 holds). Do NOT use
    `coll@groups <- "psu"` directly: S7 validates after every `@<-`
    assignment and `make_test_collection()`'s default `@groups`
    (`character(0)`) fails G1 the moment the collection's slot is
    assigned.

    **Fixture asymmetry (required to actually trigger partial
    resolution):** `make_survey_data()` produces `psu` as character
    (`paste0("psu_", ...)`), so `where(is.factor)` resolves to nothing
    on every member by default and the partial-rename scenario never
    fires. Before calling `rename_with`, type member A's `psu` column
    as factor while leaving members B and C with character `psu`.
    Members B and C must remain valid `survey_taylor` objects with
    consistent `@groups = "psu"`, so use the established surveytidy
    `attr<-` bypass + `S7::validate()` pattern (per the
    "S7 Validator Bypass for rename()" memory) only on member A:

    ```r
    m1_data <- m1@data
    m1_data$psu <- factor(m1_data$psu)
    attr(m1, "data") <- m1_data
    S7::validate(m1)
    ```

    Members B and C are constructed normally (no factor conversion).
    Then re-pass `list(m1, m2, m3)` to
    `surveycore::as_survey_collection()`.

    Then call `rename_with(coll, toupper, .cols = where(is.factor))`.
    Assert:
    - Member A's resolved rename map includes `psu` (resolves to the
      factor column).
    - Members B and C: `where(is.factor)` resolves to an empty set.
    - Because the resolved column set differs across members, the
      dispatcher raises
      `surveytidy_error_collection_rename_group_partial` BEFORE any
      member's `@data` is mutated.

    Snapshot the error message.
12. Add per-member-warning-multiplicity test (rename only):
    `rename(coll, new_wt = wt)` on a 3-member collection where `wt`
    is a weight column on every member emits
    `surveytidy_warning_rename_design_var` 3 times.
13. Add `@metadata` propagation tests per §IX.3.

**Distinct:**
14. Write a failing V9 test. Construct the fixture inline (do NOT use
    `make_test_collection()` — its seeded random data cannot force the
    needed duplicates):
    - Build three plain `data.frame`s where rows 1 and 2 of `df1` are
      identical (internal duplicate within member 1), and row 1 of `df2`
      is identical to row 1 of `df1` (cross-member duplicate between
      members 1 and 2). `df3` is unrelated.
    - Wrap each via `surveycore::as_survey(..., weights = wt)` to produce
      three `survey_taylor` objects.
    - Pass the three designs to `surveycore::as_survey_collection()`.
    - Call `distinct(coll)` and assert: member 1's internal duplicate
      collapses (rows 1–2 → 1 row); member 2 is unchanged (1 row); the
      cross-member duplicate between members 1 and 2 is preserved (V9 —
      no cross-survey collapse). `coll@id` and per-member `@variables`
      are unchanged.

**Drop_na:**
15. Create `tests/testthat/test-collection-drop-na.R`. Apply the
    standard per-verb TDD cycle (PR 2a steps 1–28, omitting steps
    21–22 weight-mutation multiplicity — `drop_na` does not warn on
    weights — and omitting `.by` rejection — `drop_na` has no `.by`
    arg). Use `.detect_missing = "class_catch"` per spec §II.4.
16. Write a failing class-catch test: `drop_na(coll, missing_col)`
    raises `vctrs_error_subscript_oob` per-member, the dispatcher
    catches and re-raises as `surveytidy_error_collection_verb_failed`
    under `.if_missing_var = "error"`; under `.if_missing_var = "skip"`
    the offending member is dropped with a typed
    `surveytidy_message_collection_skipped_surveys` message. Snapshot.
17. Per-member empty-domain warning multiplicity test (analogue of
    rename's per-member multiplicity in step 12): on a 3-member
    collection, a `drop_na()` call that empties the domain on every
    member emits `surveycore_warning_empty_domain` 3 times (per spec
    §IV.2 and V4). Use `withCallingHandlers()` to count firings.

**Rowwise:**
18. Use `.may_change_groups = FALSE` per spec §IV.10 — the per-member
    `rowwise()` does NOT touch `@groups` (per `R/rowwise.R`
    contradiction noted in spec-review Issue 4 and corrected). This
    means `rowwise` is NOT in the `.may_change_groups = TRUE`
    whitelist.
19. Create `tests/testthat/test-collection-rowwise.R`. Apply the
    standard per-verb TDD cycle (PR 2a steps 1–28, omitting steps
    21–22 weight-mutation multiplicity, omitting 25–26 domain
    preservation since `rowwise` does not modify `@data`, and
    omitting `.by` rejection — `rowwise` has no `.by` arg).
    `is_rowwise.survey_collection` tests belong to PR 2c and are
    deferred.

**Per-PR closure tasks:**
20. Add the 2 new error-class rows to `plans/error-messages.md`
    (`surveytidy_error_collection_select_group_removed`,
    `surveytidy_error_collection_rename_group_partial`).
21. Run full suite, `devtools::check()`, coverage, `air format`.
22. Author changelog entry.
23. Open PR.

**Notes:**
- The select group-removal pre-flight uses
  `coll@surveys[[1]]@data` for resolution per spec §IV.3 — V2 permits
  per-member tidyselect resolution; first-member resolution is
  sufficient because the union of group columns must exist on every
  member by G1b.
- The rename pre-flight is per-member because `rename_with`'s `.cols`
  resolves per-member. Plain `rename` is structurally redundant but
  kept (per §IV.4 reachability note) — DO NOT short-circuit it.
- `distinct.survey_collection` adds an explicit roxygen note
  documenting V9 divergence from `bind_rows()`.
- `drop_na.survey_collection` lives in `R/drop-na.R` and uses tidyselect
  for column args per spec §II.4 — same evaluation engine and
  detection mode (`class_catch`) as every other verb in this PR. The
  per-member empty-domain warning fires N times on an N-member
  collection (mirrors V4's per-member treatment for `filter`/
  `filter_out`). The `@section Survey collections:` block must
  document this multiplicity.
- `rowwise.survey_collection` is correctly excluded from the
  `.may_change_groups = TRUE` whitelist; ensure it's not in the
  whitelist.
- The soft uniformity invariant for rowwise (spec §IV.10) is enforced
  at `mutate.survey_collection`'s pre-check, not here. PR 2a steps
  22a–22e implement the warning. `rowwise.survey_collection` itself
  produces uniform rowwise state by construction, so it does not
  contribute to mixed-state collections.

---

### PR 2c: Grouping collection verbs

**Branch:** `feature/survey-collection-grouping-verbs`
**Depends on:** PR 1

**Files:**
- `R/group-by.R` — MODIFIED: add `group_by.survey_collection`,
  `ungroup.survey_collection`, `group_vars.survey_collection`
- `R/rowwise.R` — MODIFIED: add `is_rowwise.survey_collection`
  one-liner inside the pre-allocated `# ── is_rowwise.survey_collection (PR 2c) ──` block (allocated by PR 1)
- `R/zzz.R` — MODIFIED: register S3 methods for these verbs
- `tests/testthat/test-collection-group-by.R` — NEW (covers group_by,
  ungroup, group_vars, is_rowwise)
- `changelog/phase-0.7/feature-collection-grouping-verbs.md` — NEW

**Acceptance criteria:**
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] `group_by` test covers happy path with dual invariants,
      `@groups` sync (every member's `@groups == out@groups`), `.add`
      and `.drop` arg pass-through, missing group col + `.if_missing_var`
      modes, validator G1b safety net
- [ ] `ungroup` test covers `@groups` cleared on collection AND every
      member, no-op on already-ungrouped collection
- [ ] `group_vars` returns `coll@groups` directly (does NOT invoke
      dispatcher)
- [ ] `is_rowwise` returns TRUE iff every member is rowwise; tested
      after `rowwise()` (PR 2b) and on a non-rowwise collection
- [ ] `visible_vars` preservation asserted on `group_by` and `ungroup`:
      on a collection where every member has
      `@variables$visible_vars = c("y1", "y2")`, every member still has
      the same `visible_vars` after the verb
- [ ] `covr::package_coverage()` ≥95% on each modified file
- [ ] All examples include `library(dplyr)` per CI gotcha

**Tasks:**

**Group_by:**
1. Write a failing happy-path test: `group_by(coll, group)` on
   `make_test_collection()` returns a collection with
   `@groups == "group"` AND every member's `@groups == "group"`.
   Use dual invariants.
2. Implement `group_by.survey_collection` per spec §IV.7. Pass
   `.detect_missing = "pre_check"` and `.may_change_groups = TRUE`.
3. Register in `R/zzz.R` inside the
   `# ── survey_collection: grouping verbs (PR 2c) ──` block
   pre-allocated by PR 1. Run `devtools::document()`.
4. Run; confirm passing.
5. Write failing tests for `.add = TRUE`, `.add = FALSE`, `.drop` —
   verify they pass through to per-member.
6. Run; confirm passing.
7. Write G1b coverage in two parts. G1b is structurally unreachable
   through the dispatcher (skip drops the offending member; error
   raises before the validator runs), so the safety-net test must
   simulate the broken state directly.

   **Part 1 — happy-path skip (no G1b violation, normal dispatch):**
   Build a collection where members A, B, C all have column `region`
   but only member B has column `state`. Call
   `group_by(coll, state, .if_missing_var = "skip")`. Assert: A and C
   are dropped via `surveytidy_message_collection_skipped_surveys`;
   B remains; the rebuilt collection has `@groups == "state"` and
   the surviving member's `@groups == "state"`. G1b is structurally
   satisfied because every surviving member has the column — the
   safety net does not fire on this path.

   **Part 2 — defense-in-depth synthetic G1b violation:** Construct
   a valid grouped collection (`group_by(coll, region)` on a
   collection where every member has `region`). Then simulate a
   regression in surveycore's per-member enforcement by bypassing
   validators: use `attr(coll, "surveys")` to replace one member's
   `@data` with a frame that lacks `region` (`attr(member, "data") <-
   df_without_region`). Call `S7::validate(coll)` directly. Assert
   it raises `surveycore_error_collection_group_not_in_member_data`
   (G1b). Add a comment in the test file:
   `# G1b is unreachable through normal dispatch; this test exercises
   # the validator's defense-in-depth against a regression in
   # surveycore's per-member enforcement.`
8. Run; confirm passing.

**Ungroup:**
9. Write a failing test: `ungroup(group_by(coll, group))` returns a
   collection with `@groups == character(0)` AND every member's
   `@groups == character(0)`.
10. Implement `ungroup.survey_collection`. Pass
    `.detect_missing = "none"` and `.may_change_groups = TRUE`.
11. Register, document, run.

**visible_vars preservation (group_by + ungroup):**
11a. Write a failing test for `group_by`: build
    `make_test_collection()`; set every member's
    `@variables$visible_vars <- c("y1", "y2")` via the `attr<-` bypass
    + `S7::validate()` pattern; call `group_by(coll, group)`; assert
    every member's `visible_vars` is still `c("y1", "y2")`.
11b. Run; confirm passing.
11c. Write the same failing test for `ungroup` on the grouped
    fixture; run; confirm passing.

**Group_vars:**
12. Write a failing test: `group_vars(coll)` returns `coll@groups`
    directly (no dispatcher invocation). Verify by stubbing the
    dispatcher with `mockery::stub(...)` and confirming it's not
    called.
13. Implement the one-liner per spec §IV.9. Register.
14. Run; confirm passing.

**Is_rowwise:**
15. Write a failing test: on a collection where every member is
    rowwise (constructed via per-member `rowwise()` call before
    `as_survey_collection`), `is_rowwise(coll)` returns TRUE; on a
    non-rowwise collection, FALSE; on a mixed collection, FALSE.
16. Implement per spec §IV.10. Register.
17. Run; confirm passing.

**Closure:**
18. Run full test suite + `devtools::check()`.
19. Run coverage and `air format`.
20. Author changelog entry.
21. Open PR.

**Notes:**
- `group_by` and `ungroup` set `.may_change_groups = TRUE` because
  they legitimately change collection-level groups. They're in the
  whitelist of §III.4 along with `rename` and `rename_with`.
- `group_vars` and `is_rowwise` do NOT use the dispatcher — they're
  diagnostic one-liners.
- The `mockery` package is in Suggests for surveytidy already (verify
  before writing the stub-based test).

---

### PR 2d: Slice family collection verbs

**Branch:** `feature/survey-collection-slice-verbs`
**Depends on:** PR 1

**Files:**
- `R/slice.R` — MODIFIED: add `slice.survey_collection`,
  `slice_head.survey_collection`, `slice_tail.survey_collection`,
  `slice_min.survey_collection`, `slice_max.survey_collection`,
  `slice_sample.survey_collection`, slice-zero pre-flight helper,
  and `.derive_member_seed()` (single-call-site helper, defined at
  the top of the file per `code-style.md` §4)
- `R/zzz.R` — MODIFIED: register S3 methods for these verbs
- `tests/testthat/test-collection-slice.R` — NEW (slice family only; arrange lives in PR 2a's `test-collection-arrange.R`)
- `plans/error-messages.md` — MODIFIED: add
  `surveytidy_error_collection_slice_zero`
- `changelog/phase-0.7/feature-collection-slice-verbs.md` — NEW

**Acceptance criteria:**
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] Per-slice-verb test covers happy path with dual invariants,
      `@id`/`@if_missing_var`, missing-var (where applicable —
      `slice_min`/`slice_max` with `order_by` arg; `slice_sample`
      with `weight_by` arg), empty-result, domain preservation,
      cross-design, per-member `surveycore_warning_physical_subset`
      multiplicity
- [ ] Slice-zero pre-flight raises
      `surveytidy_error_collection_slice_zero` BEFORE any member is
      touched (snapshot per slice variant)
- [ ] `slice_sample` reproducibility: `seed = NULL` consumes ambient
      RNG in iteration order; `seed = <int>` produces identical
      output regardless of collection reorder
- [ ] `by` rejection (`slice_min`, `slice_max`, `slice_sample`)
      raises `surveytidy_error_collection_by_unsupported`
- [ ] `.if_missing_var` is OMITTED from signatures of `slice`,
      `slice_head`, `slice_tail`, and `slice_sample` when
      `weight_by = NULL` (per §III.2 exception)
- [ ] `visible_vars` preservation asserted on every slice variant
      (`slice`, `slice_head`, `slice_tail`, `slice_min`, `slice_max`,
      `slice_sample`): on a collection where every member has
      `@variables$visible_vars = c("y1", "y2")`, every surviving member
      still has the same `visible_vars` after the verb
- [ ] `covr::package_coverage()` ≥95% on each modified file

**Tasks:**

For each slice variant, follow the standard TDD cycle. Variants:

| Verb | `.detect_missing` | `.if_missing_var` arg? | `by` rejection? |
|---|---|---|---|
| `slice` | `"none"` | NO | NO (no `by` arg) |
| `slice_head`, `slice_tail` | `"none"` | NO | NO |
| `slice_min`, `slice_max` | `"pre_check"` | YES | YES |
| `slice_sample` | conditional | conditional | YES |

**Slice-zero pre-flight:**
1. Write a `.check_slice_zero(verb_name, ...)` helper at the top of
   `R/slice.R`. Per §IV.6:
   - `slice`: NSE-evaluate `...` in an empty env; if integer(0),
     raise. If eval fails (NSE refs a column or `n()`), silently skip.
   - `slice_head`/`slice_tail`/`slice_sample`: check `n == 0` and
     `prop == 0` (or unset).
   - `slice_min`/`slice_max`: same n/prop check; do NOT pre-evaluate
     `order_by`.
2. Write failing tests for each variant: passing args that empty
   every member raises `surveytidy_error_collection_slice_zero`
   BEFORE any member is touched. Use ref-comparison on `coll@surveys`
   to assert no mutation.
3. Implement the helper. Run; confirm passing.

**Helper: `.derive_member_seed()`:**

4. Write a failing test for `.derive_member_seed(survey_name, seed)`
   in `test-collection-slice.R`: deterministic output for fixed
   inputs; different `survey_name` produces different seeds.
5. Define `.derive_member_seed()` at the top of `R/slice.R` per spec
   §II.3.3 (`rlang::hash` + `strtoi(substr(..., 1, 7), 16L)`).
   Single-call-site helper per `code-style.md` §4 — consumed only by
   `slice_sample.survey_collection` below. Run; confirm passing.

**Per-verb implementation:**

Insert each `registerS3method()` call inside the
`# ── survey_collection: slice verbs (PR 2d) ──` block in `R/zzz.R`
pre-allocated by PR 1.

6. For `slice`: write happy-path test, implement method per spec
   §IV.6 (no `.if_missing_var` in signature; `.detect_missing =
   "none"`), register, document, run.
7. For `slice_head`/`slice_tail`: same pattern. Note `n` and
   `prop` args; signature does NOT include `.if_missing_var`.
8. For `slice_min`/`slice_max`: signature INCLUDES `.if_missing_var`
   per §III.2; `.detect_missing = "pre_check"` (data-mask `order_by`).
   Reject `by` arg with `surveytidy_error_collection_by_unsupported`.
9. For `slice_sample`: the signature **always** includes both
   `weight_by = NULL` and `.if_missing_var`. The verb body branches
   on `is.null(weight_by)` at runtime: when `weight_by = NULL`,
   call the dispatcher with `.detect_missing = "none"` and
   `.if_missing_var` is unused (no data-mask path); when `weight_by`
   is non-NULL, call the dispatcher with `.detect_missing =
   "pre_check"` and `.if_missing_var` is honored. See spec §IV.6
   lines 791–794. Implement the `seed` argument per the same
   section's reproducibility subsection.
10. Implement per-survey seeding via `.derive_member_seed()` (defined
    at the top of `R/slice.R` in step 5). Wrap each per-survey call
    with `set.seed()` + `on.exit()` to restore ambient `.Random.seed`.
11. Write failing seed-reproducibility tests:
    - `seed = NULL`: ambient RNG consumed in iteration order; assert
      fixed-seed reproducibility AND that adding/removing a survey
      changes downstream samples.
    - `seed = <int>`: same `seed` produces same per-survey output
      regardless of collection reorder; ambient `.Random.seed`
      restored after the call.
12. Run; confirm passing.

**Closure:**
13. Add per-member `surveycore_warning_physical_subset` multiplicity
    test for each slice variant (assert N firings on N-member
    collection).
14. Add a `visible_vars`-preservation test for every slice variant:
    build `make_test_collection()`; set every member's
    `@variables$visible_vars <- c("y1", "y2")` via the `attr<-` bypass
    + `S7::validate()` pattern; apply the verb with args that retain
    at least one row per member; assert every surviving member's
    `visible_vars` is still `c("y1", "y2")`.
15. Add row to `plans/error-messages.md` for
    `surveytidy_error_collection_slice_zero`.
16. Run full suite + check + coverage + format.
17. Author changelog entry.
18. Open PR.

**Notes:**
- The slice-zero pre-flight is verb-specific (different arg shapes per
  variant). The shared helper takes the verb name and dispatches
  internally.
- `slice_sample` is the most complex variant — its conditional
  signature and per-survey seeding need extra care. Test both
  `seed = NULL` (ambient) and `seed = <int>` (deterministic) paths
  thoroughly.
- The `seed = NULL` default is intentional per D2 (avoid silently
  changing semantics of existing piped pipelines). Document in
  roxygen with the strong recommendation to pass an explicit `seed`
  for reproducible analyses.
- `slice` accepts NSE — use `tryCatch(eval_tidy(quo, data = NULL))`
  for the pre-flight per spec §IV.6 evaluation rules.

---

### PR 3: Collapsing verbs (`pull`, `glimpse`)

**Branch:** `feature/survey-collection-collapsing`
**Depends on:** PR 1

**Files:**
- `R/collection-pull-glimpse.R` — NEW: `pull.survey_collection`,
  `glimpse.survey_collection`, type-coercion footer renderer
- `R/zzz.R` — MODIFIED: register S3 methods for these verbs
- `tests/testthat/test-collection-pull.R` — NEW
- `tests/testthat/test-collection-glimpse.R` — NEW
- `plans/error-messages.md` — MODIFIED: add
  `surveytidy_error_collection_pull_incompatible_types`,
  `surveytidy_error_collection_glimpse_id_collision`
- `changelog/phase-0.7/feature-collection-collapsing.md` — NEW

**Acceptance criteria:**
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] `pull` test covers happy path, `var = -1` default, `var =
      <bare>`, `var = last_col()`, `var = where(is.numeric)`, `name =
      NULL`, `name = coll@id` (with default and user-set `coll@id`),
      `name = "<other_col>"`, `.if_missing_var` modes,
      `vctrs_error_incompatible_type` re-raise as
      `surveytidy_error_collection_pull_incompatible_types`,
      class-catch detection (NOT pre-check — verifies Issue 22 / Pass
      2 fix), domain-inclusion contract documented and tested
- [ ] `glimpse` test covers default mode (single bound tibble),
      `.by_survey = TRUE` (per-member labelled blocks), id-collision
      pre-flight raise BEFORE binding, `..surveycore_domain..` →
      `.in_domain` rename in display only (not in member `@data`),
      type-coercion footer (D7 truncation rule at 5 columns),
      footer omitted when no conflicts
- [ ] `covr::package_coverage()` ≥95% on the new file

**Tasks:**

**Pull:**
1. Write a failing happy-path test: `pull(coll, y1)` on
   `make_test_collection()` returns a numeric vector of length
   sum(per-member nrow); unnamed.
2. Implement `pull.survey_collection` per spec §V.1. `pull` does
   **not** use `.dispatch_verb_over_collection` — the dispatcher
   returns a collection, but `pull` returns a vector. Iterate
   per-member directly: for each member, call
   `dplyr::pull(member, var, name)` inside a `tryCatch` /
   `withCallingHandlers` that replicates the class-catch handler
   from the dispatcher (catch `vctrs_error_subscript_oob`; under
   `.if_missing_var = "error"` re-raise as
   `surveytidy_error_collection_verb_failed`; under `"skip"` drop
   the member with a typed
   `surveytidy_message_collection_skipped_surveys`). Combine the
   per-member results across members via `vctrs::vec_c()`. The
   duplicated class-catch handler is acceptable per
   `engineering-preferences.md` §3 — see PR Notes.
3. Register in `zzz.R`. Document. Run.
4. Write failing tests for `name = NULL`, `name = coll@id` (default
   `.survey`), `name = coll@id` with custom `.id`, `name =
   "<other_col>"`. Run, confirm passing.
5. Write a failing class-catch test: `pull(coll, missing_col)` under
   `.if_missing_var = "error"` re-raises as
   `surveytidy_error_collection_verb_failed` with parent =
   `vctrs_error_subscript_oob`. Run, confirm passing.
6. Write a failing class-catch test for `name = "missing_col"`:
   under `.if_missing_var = "error"`, re-raises with parent =
   `vctrs_error_subscript_oob`.
7. Write a failing test for `vctrs::vec_c()` type incompatibility:
   construct a `make_heterogeneous_collection()`-style fixture where
   one member has `y1` as numeric and another as character. Calling
   `pull(coll, y1)` raises
   `surveytidy_error_collection_pull_incompatible_types` with parent
   = `vctrs_error_incompatible_type`. Snapshot.
8. Implement the `vctrs::vec_c()` call with `tryCatch` re-raise. Run.
9. Write a domain-inclusion test (per spec §V.1 step 2): pre-filter
   the collection so some rows are out-of-domain; `pull(coll, y1)`
   returns a vector that includes BOTH in-domain and out-of-domain
   values. Document this in the roxygen `@section Domain inclusion:`
   block.
10. Add a tidyselect-helper test: `pull(coll, last_col())` works
    without false-positive missing-variable detection (verifies
    class-catch over pre-check choice from Issue 22).

**Glimpse:**
11. Write a failing happy-path test for default mode:
    `glimpse(coll)` prints a single tibble with prepended `coll@id`
    column; returns `invisible(coll)`.
12. Implement default mode. Use `dplyr::bind_rows(map(@surveys,
    function(s) s@data))` with the `.id` arg. Run.
13. Write a failing test for the id-collision pre-flight: construct
    a collection where one member's `@data` already contains a
    column named `.survey` (via `mutate(coll, .survey = ...)` —
    but actually that needs to bypass the pre-check; construct
    inline). Calling `glimpse(coll)` raises
    `surveytidy_error_collection_glimpse_id_collision` BEFORE
    binding. Snapshot.
14. Implement the pre-flight. Run, confirm passing.
15. Write a failing test for `..surveycore_domain..` → `.in_domain`
    display rename: pre-filter the collection so the column exists;
    `glimpse(coll)` shows `.in_domain` (visually verified by
    capturing output via `capture.output()` or
    `testthat::expect_output()`); per-member `@data` retains the
    original column name. Run, confirm passing.
16. Write a failing test for `.by_survey = TRUE`: each member's
    glimpse rendered under a `▸ <member_name>` header; same
    `.in_domain` rename applied per member.
17. Implement `.by_survey = TRUE` mode.
18. Write failing tests for the type-coercion footer:
    - No conflicts → no footer.
    - 1 conflict → footer with one row.
    - 6 conflicts → footer with first 5 rows + `+ 1 more conflicting
      columns` (D7 truncation).
    - Coercion type matches `bind_rows`'s standard rules.
19. Implement the footer renderer. Use 80-char width cap.
20. Run; confirm passing.

**Closure:**
21. Add 2 rows to `plans/error-messages.md`.
22. Run full suite + check + coverage + format.
23. Author changelog entry.
24. Open PR.

**Notes:**
- `pull.survey_collection` does NOT call
  `.dispatch_verb_over_collection` directly — it iterates per-member
  manually because the result is a vector, not a `survey_collection`.
  The class-catch handler structure is duplicated locally; this is
  acceptable per `engineering-preferences.md` §3 (the alternative —
  generalizing the dispatcher to also support collapsing return types
  — is over-engineering until a third collapsing verb appears).
- `glimpse.survey_collection` does not use the dispatcher either
  (also collapsing).
- The id-collision pre-flight is for the user-introduced collision
  case (e.g., user did `mutate(coll, .survey = wave_year)`). The
  pre-flight runs BEFORE bind_rows.
- D7 footer truncation: 5 rows + summary line. Deterministic
  selection (column order in `combined`).

---

### PR 4: Joins, re-exports, polish

**Branch:** `feature/survey-collection-joins-and-reexports`
**Depends on:** PR 2a, 2b, 2c, 2d, 3 (final integration)

**Files:**
- `R/joins.R` — MODIFIED: add `*_join.survey_collection` error stubs
  for `left_join`, `right_join`, `inner_join`, `full_join`,
  `semi_join`, `anti_join`
- `R/reexports.R` — MODIFIED: re-export
  `surveycore::as_survey_collection`,
  `surveycore::set_collection_id`,
  `surveycore::set_collection_if_missing_var`,
  `surveycore::add_survey`, `surveycore::remove_survey`
- `R/zzz.R` — MODIFIED: register S3 methods for the join error stubs
- `tests/testthat/test-collection-joins.R` — NEW
- `tests/testthat/test-collection-reexports.R` — NEW
- `plans/error-messages.md` — MODIFIED: add
  `surveytidy_error_collection_verb_unsupported`
- `NEWS.md` — MODIFIED: add `### survey_collection support` section
  under `## (development version)`
- `DESCRIPTION` — MODIFIED: bump version (e.g., to `0.5.0.9000` or
  similar — confirm with `develop`'s current state at PR time)
- `changelog/phase-0.7/feature-collection-joins-and-reexports.md` —
  NEW

**Acceptance criteria:**
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] `*_join.survey_collection` for all 6 join verbs raises
      `surveytidy_error_collection_verb_unsupported` with the verb
      name interpolated; snapshot per verb
- [ ] All 5 surveycore re-exports load via
      `library(surveytidy)` alone (no `library(surveycore)`)
- [ ] `print.survey_collection` rendering still discoverable for
      `@id` / `@if_missing_var` / `@groups` after a verb pipeline,
      snapshotted via `expect_snapshot(print(coll))` in the
      cross-verb pipeline test
- [ ] Cross-verb integration test: pipe through 4–5 verbs from
      different families (e.g., `coll |> filter(...) |> select(...)
      |> group_by(...) |> mutate(...)`) and assert the result is a
      well-formed `survey_collection` via dual invariants
- [ ] `NEWS.md` `## (development version)` section has a `###
      survey_collection support` block listing every new method, the
      `.if_missing_var` arg, and the new error/warning/message
      classes
- [ ] DESCRIPTION pin matches §X gate
- [ ] `covr::package_coverage()` ≥95% on the new files

**Tasks:**

**Joins:**
1. Write a failing test for each join verb:
   `left_join(coll, df, by = "x")` raises
   `surveytidy_error_collection_verb_unsupported` with the verb name
   in the message. Snapshot. Repeat for `right_join`, `inner_join`,
   `full_join`, `semi_join`, `anti_join`.
2. Implement each error stub per spec §V.3 template. Use a shared
   internal helper `.collection_join_unsupported(verb_name)` if
   helpful.
3. Register all 6 stubs in `zzz.R`.
4. Run `devtools::document()`. Confirm NAMESPACE entries.
5. Run; confirm passing.

**Re-exports:**
6. Write a failing test in `test-collection-reexports.R` that
   `library(surveytidy)` alone makes `as_survey_collection`,
   `set_collection_id`, `set_collection_if_missing_var`,
   `add_survey`, `remove_survey` available. Use
   `expect_true(exists("as_survey_collection", where = "package:surveytidy", inherits = FALSE))`
   for each.
7. Implement the re-exports in `R/reexports.R` per spec §VI:

   ```r
   #' @export
   surveycore::as_survey_collection
   ```

   And so on for each setter.
8. Run `devtools::document()`. Inspect NAMESPACE for `export()`
   lines.
9. Run; confirm passing.

**Polish:**
10. Add a cross-verb integration test in
    `test-collection-reexports.R` (or a new
    `test-collection-pipeline.R`). Follow the TDD shape: write the
    failing test first, then add the integration test fixture / any
    helper plumbing needed to make it pass. Build
    `make_test_collection()`, pipe through 4–5 verbs, assert the
    final collection is well-formed.

    The pipeline `coll |> filter(...) |> select(...) |> group_by(...)
    |> mutate(...)` is offered as a starting suggestion, but it must
    be extended (or substituted) so the requirements below are met.
    The implementer may choose any concrete pipeline that satisfies
    them.

    **Required by this task (acceptance criteria for the test):**

    - The pipeline MUST include at least one verb from each of:
      - PR 2a (mutating: e.g., `filter`, `mutate`, or `arrange`)
      - PR 2b (tidyselect: e.g., `select`, `rename`, or `rename_with`)
      - PR 2c (grouping: e.g., `group_by`, `ungroup`, or `rowwise`)
      - PR 2d (slicing: e.g., `slice_head`, `slice_tail`, or
        `slice_sample`)
    - The test MUST assert the dual invariant explicitly:
      - `test_collection_invariants(result)` (collection-level)
      - For each surviving member: `test_invariants(member)`
        (per-member)
    - The test MUST snapshot `print(result)` so output regressions
      surface.
11. Extend the cross-verb pipeline test from task 10 with
    `expect_snapshot(print(coll_after_pipeline))` (placed alongside
    the dual-invariant assertion). The snapshot captures the full
    rendered output — `@id`, `@if_missing_var`, `@groups`, and
    member summary. Future regressions go through
    `testthat::snapshot_review()` like every other surveytidy
    snapshot. Snapshot file lands in
    `tests/testthat/_snaps/collection-reexports.md` (or the
    integration test file's snap dir).
12. Add `surveytidy_error_collection_verb_unsupported` row to
    `plans/error-messages.md`.
13. Author the `### survey_collection support` block in `NEWS.md`
    under `## (development version)`. List:
    - All new collection methods (per §II.4)
    - The `.if_missing_var` argument and its semantics
    - New error/warning/message classes
    - DESCRIPTION dependency changes (vctrs, surveycore pin bump)
14. Bump `DESCRIPTION` Version field if appropriate (consult
    `develop`'s current value). For Phase 0.7 this is likely a
    `0.5.0.9000` → continued dev or a minor bump.
15. Re-confirm `surveycore` minimum-version pin against installed
    surveycore (per §X gate).
16. Run `air format .`, `devtools::document()`, `devtools::check()`,
    `covr::package_coverage()`.
17. Author changelog entry summarizing all four collection PRs (this
    is the final batch entry).
18. Open PR.

**Notes:**
- Re-exports should use the `surveycore::function_name` syntax, not
  `function_name <- surveycore::function_name`. roxygen2 handles the
  bare-symbol export form.
- The cross-verb integration test is the proof that all 4 verb-family
  PRs compose correctly — this is the load-bearing assertion.
- DESCRIPTION pin verification: re-run
  `packageVersion("surveycore")` and confirm it matches the pin
  written at PR 1 (or bump if newer surveycore work landed).

---

## Closing notes

- After PR 4 merges to `develop`, the next merge to `main` should
  use `/merge-main` per `.claude/skills/merge-main`.
- Tests must use the dual-invariant discipline
  (`test_collection_invariants` + per-member `test_invariants`) as
  the FIRST assertions in every collection verb test block (§IX.3).
  Treat this as non-negotiable; reviewers should reject PRs that
  skip it.
- The `mockery` package is needed for tests that stub the dispatcher
  (PR 2c, optionally PR 1). Verify it's in `Suggests` before
  starting; if not, add it in PR 1.
- Per `code-style.md`: `air format` runs separately from
  functional commits — do not bundle reformatting with logic changes
  in the same commit.
- All examples include `library(dplyr)` (or `library(tidyr)`) per
  CI gotcha (CLAUDE.md). Verify in each PR.
- Coverage target reconciliation: spec §IX.5 was updated in this
  pass to match §X (≥98% overall; ≥95% on each new file). The plan's
  per-PR targets reflect §X.
