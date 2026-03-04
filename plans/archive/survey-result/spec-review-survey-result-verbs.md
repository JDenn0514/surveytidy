## Spec Review: survey-result-verbs — Pass 1 (2026-03-02)

> **All 11 issues resolved.** Fixes applied to `plans/spec-survey-result-verbs.md`
> and decisions logged in `plans/claude-decisions-survey-result-verbs.md`.

### Resolved Issues

---

#### Section: II. Architecture — Shared helper placement

**Issue 1: Helper placement violates code-style.md §4** ✅ RESOLVED
Severity: REQUIRED

Both helpers moved inline to the top of `R/verbs-survey-result.R`. Section II
file organization updated to say "inline helpers" and the helper signatures
header updated accordingly.

---

#### Section: II. Architecture — `.meta` key contract

**Issue 2: Contradiction — `$x` is "always-present" but can be set to NULL** ✅ RESOLVED
Severity: REQUIRED

`$x` type updated to `list or NULL` in the always-present keys table. Lifecycle
note added: "Set to `NULL` by `select()` when all focal columns are dropped."

---

#### Section: III.4 — `mutate.survey_result` open question

**Issue 3: Unresolved design decision blocks implementation** ✅ RESOLVED
Severity: BLOCKING

Decision: no warning. `survey_result` objects are post-estimation outputs; mutating
a column is deliberate data manipulation. Section III.4 Behavior note confirmed as
final contract. GAP annotation removed.

---

#### Section: IV.3 — `rename_with.survey_result` validation

**Issue 4: NA values from `.fn` not covered by validation logic** ✅ RESOLVED
Severity: REQUIRED

`!anyNA(new_names)` added to Step 4 validation. Error trigger description updated
to include "or contains NA values."

---

#### Section: VI — PR 2 tests

**Issue 5: `rename_with()` error test only covers non-character output** ✅ RESOLVED
Severity: REQUIRED

Three new test blocks added: 12b (wrong-length), 12c (NA in output), 12d (duplicate
names). Each uses the dual pattern (class= check + snapshot).

---

#### Section: VI — PR 2 tests (coverage gap)

**Issue 6: PR 2 meta-updating tests absent `result_freqs`** ✅ RESOLVED
Severity: REQUIRED

Two new test sections added: 17 (`rename()` on `result_freqs` updates `$x` key)
and 18 (`select()` on `result_freqs` sets `$x` to NULL).

---

#### Section: II. Architecture — dplyr_reconstruct

**Issue 7: No `dplyr_reconstruct.survey_result` specified or ruled out** ✅ RESOLVED
Severity: SUGGESTION

Explicit note added to Section III.1 explaining why `dplyr_reconstruct.survey_result`
is intentionally omitted and warning implementers not to add one.

---

#### Section: V — Test infrastructure

**Issue 8: `make_survey_result()` always uses a taylor design** ✅ RESOLVED
Severity: SUGGESTION

`design = c("taylor", "replicate", "twophase")` parameter added to
`make_survey_result()`. PR 1 test section 1 now requires a loop over all three
design types. PR 2 tests use taylor only (documented as intentional).

---

#### Section: III.6 — `drop_na.survey_result` argument note

**Issue 9: Rationale for `data` argument name is technically inaccurate** ✅ RESOLVED
Severity: SUGGESTION

Rationale corrected: now states that `data` matches tidyr convention and aids
readability, removing the inaccurate claim that `NextMethod()` dispatch depends
on the argument name.

---

#### Section: IX — Quality gates

**Issue 10: `plans/error-messages.md` "unchanged" gate conflicts with needed source file update** ✅ RESOLVED
Severity: SUGGESTION

PR 2 quality gate updated: now requires updating the source file column for
`surveytidy_error_rename_fn_bad_output` to include `R/verbs-survey-result.R`.

---

#### Section: VI — Test block structure

**Issue 11: Cross-type passthrough test structure is ambiguous** ✅ RESOLVED
Severity: SUGGESTION

PR 1 test section 1 updated to specify one `test_that()` block per verb, with an
inner loop over all three result types × all three design types.

---

## Spec Review: survey-result-verbs — Pass 2 (2026-03-02)

Second adversarial pass conducted after Pass 1 fixes were applied. Focuses on
DRY violations, unspecified behavior gaps, and missing test cases.

### New Issues

---

#### DRY Violations

**Issue DRY-1: No `.restore_survey_result()` helper mandated for passthrough pattern** ✅ RESOLVED
Severity: REQUIRED

Decision: [A]. `.restore_survey_result()` added as a third inline helper in
Section II signatures and Section III.1. Passthrough pattern simplified to a
one-liner body: `NextMethod() |> .restore_survey_result(old_class, old_meta)`.
File organization updated to list all three helpers.

Section III.1 names the passthrough pattern but implies 10 separate identical
3-line implementations (30 lines of duplicated class/meta boilerplate). The spec
should mandate a shared internal helper:

```r
.restore_survey_result <- function(result, old_class, old_meta) {
  attr(result, ".meta") <- old_meta
  class(result) <- old_class
  result
}
```

Every passthrough body becomes:
`NextMethod() |> .restore_survey_result(old_class, old_meta)`.

Options:
- **[A]** Add `.restore_survey_result()` to Section III.1 as a mandatory helper;
  update every passthrough signature block to show the one-liner body — Effort: low,
  Risk: low, Impact: eliminates 27 lines of boilerplate across 10 methods
- **[B]** Leave as 10 separate identical 3-line bodies — Effort: none, Risk: low,
  Impact: code duplication accepted
- **[C] Do nothing** — 10 implementations with identical boilerplate; DRY violation
  unaddressed

**Recommendation: [A]** — Violates engineering-preferences.md §1 (DRY). The helper
is trivial and its two real call sites exist in the current scope (10 passthrough
methods).

---

**Issue DRY-2: `tibble::as_tibble(.data)` called redundantly across meta-updating verbs** ✅ RESOLVED
Severity: REQUIRED

Decision: [A]. `tbl <- tibble::as_tibble(.data)` added as step 0 in IV.1, IV.2,
and IV.3. All subsequent uses of `tibble::as_tibble(.data)` in those sections
updated to `tbl`.

In Section IV.2 (rename implementation), step 1:
```r
map <- tidyselect::eval_rename(rlang::expr(c(...)), tibble::as_tibble(.data))
rename_map <- stats::setNames(names(map), names(tibble::as_tibble(.data))[map])
```
`tibble::as_tibble(.data)` appears twice in one step. All three meta-updating verbs
independently convert `.data` to a tibble. Each implementation note should extract
`tbl <- tibble::as_tibble(.data)` once at the top and reuse `tbl`.

Options:
- **[A]** Add `tbl <- tibble::as_tibble(.data)` as step 0 in IV.1, IV.2, and IV.3;
  update all subsequent uses of `tibble::as_tibble(.data)` in those sections to `tbl`
  — Effort: low, Risk: low, Impact: eliminates redundant coercions; cleaner pseudocode
- **[B]** Leave as-is — Effort: none, Risk: none (minor inefficiency only)
- **[C] Do nothing** — Double coercions in spec pseudocode propagate to implementation

**Recommendation: [A]** — Eliminates both the redundant spec text and the corresponding
implementation redundancy.

---

**Issue DRY-3: `rename_map` format documented in three separate places** ✅ RESOLVED
Severity: SUGGESTION

Decision: [A]. "rename_map format:" block removed from IV.2; replaced with
`_rename_map format: see Section II helper signatures._`. IV.3 step 5 updated
to reference Section II instead of restating the convention.

`rename_map` format (`c(old_name = "new_name")`) is defined in:
1. Section II (`.apply_result_rename_map` signature): canonical definition
2. Section IV.2 ("rename_map format" block): verbatim duplicate
3. Section IV.3 (step 5): `stats::setNames(new_names, old_names) (names = old, values = new)`

The IV.2 block repeats what Section II already says. Section IV.3 restates the
same convention with different wording.

Options:
- **[A]** Remove the "rename_map format:" block from IV.2; replace with "See Section II
  for `rename_map` format." Update IV.3 step 5 comment to reference Section II —
  Effort: low, Risk: none, Impact: single source of truth
- **[B]** Leave all three as-is — Effort: none, Risk: low (minor inconsistency risk)
- **[C] Do nothing** — Three definitions of the same contract; sync burden ongoing

**Recommendation: [A]**

---

**Issue DRY-4: Tests 12, 12b, 12c, 12d are structurally identical; should be a parameterized loop** ✅ RESOLVED
Severity: REQUIRED

Decision: [A]. Tests 12–12d replaced with one parameterized block using a named
`bad_fns` list. Each loop iteration generates one snapshot entry keyed by label.

All four blocks use the exact same two-line dual pattern differing only in the bad
function passed. The spec should mandate a single parameterized block:

```r
bad_fns <- list(
  "non-character output" = function(x) 1:length(x),
  "wrong-length output"  = function(x) x[1],
  "NA in output"         = function(x) { x[1] <- NA_character_; x },
  "duplicate names"      = function(x) rep(x[1], length(x))
)
for (label in names(bad_fns)) {
  fn <- bad_fns[[label]]
  expect_error(rename_with(result_means, fn),
               class = "surveytidy_error_rename_fn_bad_output")
  expect_snapshot(error = TRUE, rename_with(result_means, fn))
}
```

Four separate snapshot entries in `_snaps/` for the same error class is bloat.

Options:
- **[A]** Replace tests 12–12d with one parameterized block using a named list of
  bad functions — Effort: low, Risk: low, Impact: 4 snapshot files → 1 per trigger
  label; cleaner failure messages
- **[B]** Keep four separate blocks — Effort: none, Risk: none, Impact: DRY violation
  accepted
- **[C] Do nothing** — Four identical structures in the spec and implementation

**Recommendation: [A]** — engineering-preferences.md §1; repeated test setup belongs
in a loop.

---

**Issue DRY-5: Output contract boilerplate repeated verbatim in Sections III.2–III.6** ✅ RESOLVED
Severity: SUGGESTION

Decision: [A]. Per-verb output contracts in III.2, III.3, III.4 (partial), slice
variants, and III.6 now use "All passthrough invariants from III.1 apply (class,
`.meta`, and columns unchanged)." Each section shows only its Rows line.

Every passthrough verb section repeats:
- "Class: identical to `class(.data)`"
- "`.meta`: identical to `attr(.data, \".meta\")`"
- "Columns: unchanged."

These are fully specified in III.1. Per-verb output contract sections should document
only what differs (the Rows behavior), prefaced with "All passthrough invariants from
III.1 apply."

Options:
- **[A]** Replace the repeated lines in III.2–III.6 with "All passthrough invariants
  from III.1 apply (class, `.meta`, and columns unchanged)." Add only the Rows line
  specific to each verb — Effort: low, Risk: none, Impact: compact, non-redundant
- **[B]** Leave full contracts in each section for self-containedness — Effort: none,
  Risk: none
- **[C] Do nothing** — Sync burden if III.1 ever changes

**Recommendation: [A]**

---

**Issue DRY-6: `test_result_invariants()` requirement stated globally but omitted from some test descriptions** ✅ RESOLVED
Severity: SUGGESTION

Decision: [A]. Section VI preamble updated with one clarifying sentence: "Error-path
blocks (block 12) are exempt because no result is returned. All other blocks call
`test_result_invariants()` as the first assertion."

The VI preamble states "`test_result_invariants()` is the first assertion in every
block." But the requirement is explicitly mentioned in only some test descriptions
(5, 6, 10, 11, 17, 18) and silently omitted from blocks 7–9, 12–12d, 13–16.

This creates implementation ambiguity: are error-path tests (12–12d) exempt? Are
select tests (13–16) exempt?

Options:
- **[A]** Add a note to the preamble: "Error-path blocks (12–12d) are exempt because
  no result is returned. All other blocks call `test_result_invariants()` as the
  first assertion." Remove per-block repetition — Effort: low, Risk: none
- **[B]** Add `test_result_invariants()` explicitly to every non-error block description
  — Effort: low, Risk: none, Impact: verbose but unambiguous
- **[C] Do nothing** — Implementer guesses which blocks are exempt

**Recommendation: [A]**

---

#### Design Gaps

**Issue GAP-1: `select()` with rename syntax produces silently broken meta state** ✅ RESOLVED
Severity: BLOCKING

Decision: [B] (contra recommendation). IV.1 implementation approach updated to
detect rename-in-select: compare `names(selected_cols)` vs `names(tbl)[positions]`;
if any differ, build a rename map and call `.apply_result_rename_map()` before
pruning. Test 16b added: `select(result_means, grp = group)` — meta$group key
updated to `"grp"`, `test_result_meta_coherent()` passes.

dplyr's `select()` supports in-place renaming. With the current `eval_select` +
`.prune_result_meta` implementation, `select(result_means, grp = group)` produces
`names(selected_cols) = "grp"`, but `meta$group` has key `"group"`.
`.prune_result_meta` removes the `"group"` entry because `"group"` is not in
`kept_cols = "grp"`. The column exists as `"grp"` but its group metadata is silently
dropped — `test_result_meta_coherent()` passes because `meta$group` is now empty
(no broken references, just missing information).

The spec must decide and document:

Options:
- **[A]** Document that rename-within-select silently drops metadata for renamed
  columns. Users must `rename()` then `select()` separately to preserve metadata.
  Add a note to Section IV.1 and a test confirming `length(meta(r)$group) == 0L`
  for `select(result_means, grp = group)` — Effort: low, Risk: low, Impact: clear
  limitation with documented workaround
- **[B]** Detect rename-in-select via `eval_select` output (output names ≠ input
  column names), apply a rename map before pruning — Effort: medium, Risk: medium,
  Impact: correct behavior but more complex implementation
- **[C] Do nothing** — Behavior unspecified; implementer discovers breakage in review

**Recommendation: [A]** — Option B adds substantial complexity for an edge case;
documenting the limitation and workaround is the pragmatic choice for Phase 0.5.

---

**Issue GAP-2: `mutate(.keep = "none"/"used")` can silently violate meta coherence invariant** ✅ RESOLVED
Severity: BLOCKING

Decision: [B] (contra recommendation). III.4 mutate now diverges from pure
passthrough: after `.restore_survey_result()`, calls `.prune_result_meta(names(result))`
to maintain coherence. Behavior note updated to distinguish value-overwrite (meta
preserved verbatim) from column-drop via `.keep` (meta pruned). Tests 3b and 3c
added for `.keep = "none"` and `.keep = "used"`.

Section III.4 addresses overwriting meta-referenced column values (coherence holds —
name is still present). It does not address *dropping* meta-referenced columns via `.keep`:

- `mutate(result_means, sig = se < 0.1, .keep = "none")` — drops all original
  columns, keeps only `sig`. `meta$group` still references `"group"` (gone).
  `meta$x` still references `"y1"` (gone). Meta coherence invariant violated.
- `mutate(result_means, sig = se < 0.1, .keep = "used")` — keeps `se` and `sig`
  only. Same violation.

Options:
- **[A]** State that `.keep = "none"/"used"/"unused"` can produce meta-incoherent
  results; this is accepted user responsibility. Document the limitation in Section
  III.4 and add tests for `.keep = "none"` and `.keep = "used"` asserting the exact
  (incoherent) meta state — Effort: low, Risk: low, Impact: documented limitation;
  implementer does not need to add pruning logic
- **[B]** After `NextMethod()`, check `names(result)` against `meta$group` and `meta$x`
  keys and prune proactively — Effort: medium, Risk: low, Impact: coherence always
  maintained; more implementation complexity
- **[C] Do nothing** — Behavior unspecified; coherence invariant silently broken

**Recommendation: [A]** — Consistent with Issue GAP-1 (document limitation rather
than add complexity). Post-estimation `.keep` usage is an unusual pattern.

---

**Issue GAP-3: `select()` dropping numerator/denominator columns does not prune `meta$numerator$name` / `meta$denominator$name`** ✅ RESOLVED
Severity: REQUIRED

Decision: [A] (consistent with GAP-2 proactive approach). `.prune_result_meta()`
extended with steps 3 and 4: null out `meta$numerator` / `meta$denominator` when
their `$name` is not in `kept_cols`. `test_result_meta_coherent()` extended to
check both fields when non-null.

`select(result_ratios, -y1)` drops the numerator column. `.prune_result_meta`
explicitly does NOT update `$numerator` or `$denominator`. `meta$numerator$name`
still equals `"y1"` after the column is gone. `test_result_meta_coherent()` does not
check numerator/denominator, so the broken state passes all assertions silently.

There is currently no justification in the spec for why numerator/denominator are
excluded from `.prune_result_meta()`.

Options:
- **[A]** Extend `.prune_result_meta()` to null out `meta$numerator` and
  `meta$denominator` when their referenced columns are dropped. Extend
  `test_result_meta_coherent()` to check these fields — Effort: low, Risk: low,
  Impact: coherent behavior for ratio results
- **[B]** Explicitly document the limitation: "numerator/denominator are not pruned
  by `select()`" with a justification (e.g., ratio structure is atomic — you cannot
  have a ratio without both components, so dropping one is already a user error).
  Add a test that confirms `meta$numerator$name` after dropping the column and
  documents the known-broken state — Effort: low, Risk: none
- **[C] Do nothing** — No justification for the exclusion; silent incoherence

**Recommendation: [B]** — Ratio metadata is a pair (numerator + denominator); if
either column is dropped, the ratio result is semantically invalid regardless. Nulling
out half of the pair is not clearly better. Document the limitation with a test.

---

#### Missing Test Cases

**Issue EDGE-1: Chained meta-updating verbs never tested** ✅ RESOLVED
Severity: REQUIRED

Decision: [A]. Test 19 added: `rename(grp = group) |> select(grp, y1, mean)` —
asserts `"grp"` in group keys, `"y1"` in x keys, `test_result_meta_coherent()` passes.

`result_means |> rename(grp = group) |> select(grp, y1, mean)` — `meta$group`
should have key `"grp"`, `meta$x` should have key `"y1"`. No test exercises two
meta-updating verbs in sequence. This is the most common real-world usage pattern.

Options:
- **[A]** Add one test block: `rename(grp = group) |> select(grp, y1, mean)` —
  assert `"grp" %in% names(meta(r)$group)`, `"y1" %in% names(meta(r)$x)`,
  `test_result_meta_coherent(r)` passes — Effort: low, Risk: low
- **[B]** Leave untested — Effort: none
- **[C] Do nothing**

**Recommendation: [A]** — Most common real-world pattern; not testing it leaves the
most likely integration bug undetected.

---

**Issue EDGE-2: `rename_with()` with `.cols` resolving to zero columns not tested** ✅ RESOLVED
Severity: REQUIRED

Decision: [A]. Test 20 added: `.cols = dplyr::starts_with("zzz")` resolves to
zero columns — result identical to input; class, meta, and column names unchanged.

`rename_with(result_means, toupper, .cols = dplyr::starts_with("zzz"))` — zero
columns selected. Steps 5–6 build `setNames(character(0), character(0))` and call
`.apply_result_rename_map(.data, empty_map)`. Should be a no-op. This zero-length
input path is untested.

Options:
- **[A]** Add a test block: `.cols` resolving to zero columns → result identical to
  input — Effort: low, Risk: low
- **[B]** Leave untested — Effort: none
- **[C] Do nothing**

**Recommendation: [A]** — engineering-preferences.md §4 (handle more edge cases).

---

**Issue EDGE-3: Identity rename not tested; `eval_rename` behavior on self-rename unspecified** ✅ RESOLVED
Severity: REQUIRED

Decision: [A]. Test 21 added: `rename(result_means, group = group)` — column names
and meta unchanged. Identity rename note added to IV.2: empty/self-referential map
from `eval_rename` is a no-op in `.apply_result_rename_map()`.

`rename(result_means, group = group)` — dplyr's `eval_rename` may return an empty
map, a self-referential map, or error. The resulting meta state should be identical
to the input. This code path is both untested and unspecified.

Options:
- **[A]** Add test for `rename(result_means, group = group)`; add a spec note
  to IV.2 that identity renames are a no-op (map entry is dropped or self-referential;
  `.apply_result_rename_map` handles it correctly) — Effort: low, Risk: low
- **[B]** Leave unspecified and untested — Effort: none
- **[C] Do nothing**

**Recommendation: [A]** — The spec should not be silent on a behavior path that is
easily triggered by user accident.

---

**Issue EDGE-4: `rename_with()` with `...` forwarded to `.fn` never tested** ✅ RESOLVED

Decision: [A]. Test 22 added: `rename_with(result_means, gsub, pattern = "mean", replacement = "avg")` — asserts renamed column, updated meta$x key, test_result_invariants passes.

Every test uses `toupper` (no extra args). The `...` forwarding path
(`rename_with(result_means, gsub, pattern = "mean", replacement = "avg")`) is
completely untested — including both the rename and the meta key update that follows.

Options:
- **[A]** Add a test using `rename_with(result_means, gsub, pattern = "mean", replacement = "avg")`
  — assert the renamed column and updated meta key — Effort: low, Risk: low
- **[B]** Leave untested — Effort: none
- **[C] Do nothing**

**Recommendation: [A]**

---

**Issue EDGE-5: `drop_na()` with actual NAs — core happy-path behavior absent from test plan** ✅ RESOLVED

Decision: [A]. Test 23 added: inject NAs into result fixture, call drop_na(result, se), assert nrow(after) < nrow(before), class/meta preserved, test_result_invariants passes.

The edge cases table covers only "no NAs in result → all rows preserved." The
primary use case — some rows have NAs in specified columns, those rows are dropped,
others kept, class and meta preserved — has no explicit test block.

Options:
- **[A]** Add a test block: inject NAs into a result fixture; `drop_na(result, col)`
  drops those rows; class and `.meta` preserved; `nrow(result_after) < nrow(result_before)`
  — Effort: low, Risk: low
- **[B]** Leave untested — Effort: none
- **[C] Do nothing**

**Recommendation: [A]** — The primary happy path is currently absent from the test plan.

---

**Issue EDGE-6: `filter()` with `.by` argument not tested** ✅ RESOLVED

Decision: [A]. Test 24 added: `filter(result_means, mean > 0, .by = group)` — asserts class preserved, meta unchanged, test_result_invariants passes.

`filter.survey_result` accepts `.by` and passes it to `NextMethod()`. No test
exercises the grouped-filter code path. Add:
`filter(result_means, mean > 0, .by = group)` — verify class and meta survive.

Options:
- **[A]** Add one test block exercising `.by` — Effort: low, Risk: low
- **[B]** Leave untested — Effort: none
- **[C] Do nothing**

**Recommendation: [A]** — Low effort; tests a non-default argument path.

---

**Issue EDGE-7: `slice_min` / `slice_max` with non-default arguments not tested** ✅ RESOLVED

Decision: [A]. Test 25 added: `slice_min(..., with_ties = FALSE)` and `slice_max(..., na_rm = TRUE)` — both assert class/meta preserved and test_result_invariants passes.

Both are common argument values that change which rows are returned. Class and meta
preservation through `with_ties = FALSE` and `na_rm = TRUE` paths is unverified.

Options:
- **[A]** Add test blocks with `with_ties = FALSE` and `na_rm = TRUE` — Effort: low
- **[B]** Leave untested — Effort: none
- **[C] Do nothing**

**Recommendation: [A]** — engineering-preferences.md §4; low effort.

---

**Issue EDGE-8: `slice_sample(replace = TRUE)` not tested** ✅ RESOLVED

Decision: [A]. Test 26 added: `slice_sample(replace = TRUE, n = nrow(result) + 1)` — asserts class/meta preserved even with more rows than input.

Severity: SUGGESTION

Replacement sampling can produce duplicate rows and more rows than the input
(`n > nrow(.data)`). This is an unusual result structure; class and meta preservation
through this path is unverified.

Options:
- **[A]** Add test block with `replace = TRUE, n = nrow(result) + 1` — Effort: low
- **[B]** Leave untested — Effort: none
- **[C] Do nothing**

**Recommendation: [A]** — Engineering-preferences.md §4; unusual path worth testing.

---

**Issue EDGE-9: `select()` of zero columns — behavior unspecified** ✅ RESOLVED

Decision: [A]. Spec note added to IV.1: zero-column select returns a 0-column tibble (dplyr standard); `meta$group = list()`, `meta$x = NULL`; `test_result_invariants()` still passes; no special handling needed. Test 27 added confirming this.

Severity: REQUIRED

`select(result_means, dplyr::starts_with("zzz"))` — dplyr returns a 0-column tibble.
`.prune_result_meta` produces `meta$group = list()`, `meta$x = NULL`. Does
`test_result_invariants()` pass for a 0-column tibble? Does dplyr even allow this?
The spec must specify the expected behavior and add a test.

Options:
- **[A]** Add a spec note to IV.1: "Selecting zero columns is technically permitted
  by tidy-select but produces a degenerate result; `meta$group` becomes `list()` and
  `meta$x` becomes `NULL`. `test_result_invariants()` still passes (the tibble is
  valid). No special handling needed." Add a test confirming this — Effort: low,
  Risk: low
- **[B]** Explicitly error on zero-column select — Effort: medium, Risk: medium
- **[C] Do nothing** — Behavior unspecified; implementer guesses

**Recommendation: [A]** — Document the degenerate case; no error needed since dplyr
itself allows it.

---

**Issue EDGE-10: Test 15 description is internally inconsistent and missing a `meta$x` assertion** ✅ RESOLVED

Decision: [A]. Test 15 description corrected to "y1 absent from selection" (group IS kept). Second assertion added: `expect_true(is.null(meta(r)$x))`.

Severity: REQUIRED

Test 15 states: `select(result_means, group, mean, se)` — "`group` and `y1` (focal)
absent from selection." But `group` IS in the selection. The comment should read
"`y1` absent from selection." Additionally, since `y1` is dropped by this select,
`meta$x` should become `NULL` — but the test only asserts `meta(r)$group$group` is
preserved and never asserts `is.null(meta(r)$x)`. Both errors need correction.

Options:
- **[A]** Fix the description comment to "`y1` absent from selection"; add
  `expect_true(is.null(meta(r)$x))` as a second assertion — Effort: low, Risk: none
- **[B]** Leave the inaccurate description and missing assertion — Effort: none
- **[C] Do nothing**

**Recommendation: [A]** — Test 15 contains a spec bug; fix it now rather than
propagating it to the implementation.

---

## Summary (Pass 2)

| Severity | Total | Resolved | Remaining |
|---|---|---|---|
| BLOCKING | 2 | 2 | 0 |
| REQUIRED | 10 | 10 | 0 |
| SUGGESTION | 7 | 7 | 0 |

**Total issues:** 19 — **19 resolved, 0 remaining**

**All issues resolved.** Spec is ready for implementation.
