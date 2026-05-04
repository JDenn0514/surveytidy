## Plan Review: Transformation — Pass 1 (2026-03-16)

### New Issues

#### Section: PR Map / Files

**Issue 1: Quality gate recode file list names the wrong files — 7 files need updating, not 2**
Severity: BLOCKING
Violates Lens 5 (File Completeness) and Spec §X Quality Gates

The plan's Files section and Tasks 27–30 name `R/recode.R` and `R/recode-values.R`
as the Phase 0.6 files to update with the expanded `surveytidy_recode` structure.
But `R/recode.R` is **empty** (just a redirect comment pointing to the split files).
And the actual `surveytidy_recode` attribute is set in **7 source files across 9 locations**:

| File | Lines | Count |
|------|-------|-------|
| `R/case-when.R` | 245, 254 | 2 direct sites |
| `R/replace-when.R` | 163 | 1 direct site |
| `R/if-else.R` | 168 | 1 direct site |
| `R/na-if.R` | 156 | 1 direct site |
| `R/recode-values.R` | 281, 290 | 2 direct sites |
| `R/replace-values.R` | 167 | 1 direct site |
| `R/utils.R` (`.wrap_labelled()`) | 245 | 1 site via shared helper |

If only `recode-values.R` is updated (and the empty `recode.R` is trivially
touched), the spec's quality gate — "Phase 0.6 recode functions updated to use the
expanded `list(fn, var, call, description)` structure" — will be silently not met.
6 of 7 source files will still emit `list(description = .description)` after this PR.

The problem is concrete: an implementer reading Task 28 ("Add `var_name`/`call_expr`
capture to `R/recode.R`") opens the file, finds it empty, and has no clear path.

Options:
- **[A]** Replace Tasks 27–30 with a corrected task list covering all 7 files. List
  all 7 files explicitly in the Files section. — Effort: low, Risk: low, Impact: quality gate met
- **[B]** Move the recode structural update to a separate follow-on PR, removing
  it from this one entirely; mark it as a follow-on task. — Effort: low, Risk: low,
  Impact: defers tech debt but keeps this PR focused
- **[C] Do nothing** — Implementer updates 2 of 7 files; 6 files left behind; quality gate
  unmet; misleading PR description.

**Recommendation: A** — The update is mechanical (same 3-line `var_name`/`call_expr`
capture + expanded attr list in each function body), and having all recode functions
consistent is the right outcome. Listing all 7 files explicitly removes all ambiguity.

---

**Issue 2: `.wrap_labelled()` design decision missing — recode attribute update requires a signature change**
Severity: BLOCKING
Violates Lens 3 (Acceptance Criteria — completeness) and Lens 5 (File Completeness)

Each Phase 0.6 recode function has THREE code paths that set `surveytidy_recode`:

1. Via `.wrap_labelled()` in `R/utils.R` (when `.label` or `.value_labels` is non-null)
   — currently sets `list(description = description)` inside `.wrap_labelled()`
2. Via direct `attr(result, "surveytidy_recode") <-` (`.factor = TRUE` branches in
   `case_when()` and `recode_values()`)
3. Via direct `attr(result, "surveytidy_recode") <-` guarded by
   `if (!is.null(.description))` (the "description-only" path)

To add `fn/var/call` to ALL paths, the `.wrap_labelled()` path requires a decision:

- **Option A**: Update `.wrap_labelled(fn, var, call, ...)` signature and update all
  6 callers to pass these values through.
- **Option B**: After the `return(.wrap_labelled(...))` call, overwrite the attribute
  with the expanded structure — but this requires restructuring the early-return pattern.
- **Option C**: Accept that `.wrap_labelled()` code path will never have `fn/var/call`
  set, and document this as a known gap.

The plan doesn't mention `.wrap_labelled()` at all. An implementer either silently
skips that code path (leaving it with `list(description = .description)`) or discovers
the issue mid-implementation with no guidance.

Options:
- **[A]** Choose Option A (signature update) and add it to the plan explicitly:
  update `.wrap_labelled()` signature to accept `fn/var/call`; add that as an explicit
  Task in the plan. — Effort: medium, Risk: low, Impact: all paths consistent
- **[B]** Choose Option C (document the gap): add a plan note that `.wrap_labelled()`
  code path will retain `list(description = description)` structure; only the direct
  attr-setting paths get the expanded structure. — Effort: low, Risk: low, Impact: partial update but explicit
- **[C] Do nothing** — Implementer discovers the design decision gap mid-task; either
  silently leaves `.wrap_labelled()` path incomplete or makes an undocumented choice.

**Recommendation: A** — Updating `.wrap_labelled()` is the right call: it's a shared
helper that should emit a consistent structure. Add an explicit task (e.g., "Task 27b:
Update `.wrap_labelled()` signature to accept `fn`, `var`, `call`; update all callers").

---

#### Section: Acceptance Criteria

**Issue 3: DRY violation — 5 identical inline arg validation blocks instead of a parameterized helper**
Severity: REQUIRED
Violates Engineering Preferences Rule 1 (DRY) and `code-style.md` Internal Helper Placement

The plan note says: "Write inline validation in each function body (3–5 `cli_abort`
calls at the top) rather than trying to parameterize or reuse the existing helper."
The stated reason is correct — `.validate_label_args()` raises
`surveytidy_error_recode_label_not_scalar`, not `surveytidy_error_make_factor_bad_arg`
or `surveytidy_error_transform_bad_arg`. But the proposed solution (copy-paste in 5
functions) creates a maintainability trap: changing the error message wording for
`surveytidy_error_transform_bad_arg` requires editing 4 function bodies.

The fix is trivial: add an `error_class =` parameter to `.validate_label_args()`, or
write a new thin wrapper `.validate_transform_args(label, description, error_class)`.
The rule is: "used in 2+ files → `R/utils.R`". The transform validation logic lives
in `R/transform.R` but conceptually spans 4 functions in the same file — the helper
belongs at the top of `transform.R`.

`code-style.md` § "Internal helper placement": helpers used in exactly 1 source file
live at the top of that file. Writing `.validate_transform_args()` in `transform.R`
is within the rules — it just needs to be listed in the plan rather than 5 inline copies.

Options:
- **[A]** Add a new internal helper `.validate_transform_args(label, description, error_class)`
  to the skeleton in Task 2, called from all 4 transform functions that use the shared
  error class. Keep `make_factor()`'s standalone `make_factor_bad_arg` class inline
  or via a `make_factor`-specific helper. — Effort: low, Risk: low, Impact: DRY
- **[B]** Parameterize `.validate_label_args()` in `utils.R` to accept `error_class =`
  and update transform functions to use it. — Effort: low, Risk: low, Impact: DRY, less new code
- **[C] Do nothing** — Same 3-line block in each of 5 functions; future message
  changes require editing 5 places; violates Engineering Preferences Rule 1.

**Recommendation: A** — A new `.validate_transform_args()` at the top of `transform.R`
keeps the helper co-located with its callers and avoids touching `utils.R`. One function
definition, 4–5 call sites.

---

**Issue 4: Coverage acceptance criterion excludes updated recode files**
Severity: REQUIRED
Violates Lens 3 (Acceptance Criteria) and `testing-standards.md` Coverage Target

The acceptance criterion reads: "Line coverage ≥ 98% on `R/transform.R`."
This PR also modifies 6–7 existing recode source files. If `var_name`/`call_expr`
capture code is added to those files but not exercised in existing or new tests,
no acceptance criterion will catch the gap.

The existing tests in `test-recode.R` (and other recode test files) cover the
recode functions, but they weren't written to verify the `fn/var/call` fields in
the `surveytidy_recode` attribute — they only check `description`. New assertions
are needed, or coverage must be verified, to confirm the new fields are set correctly.

Options:
- **[A]** Add criterion: "Line coverage on modified recode files does not decrease;
  new `fn/var/call` fields verified in at least one test per recode function." —
  Effort: low, Risk: low, Impact: catches missed paths in recode updates
- **[B]** Add a dedicated test task ("Task 30b: Write targeted tests verifying
  `fn/var/call` fields in `surveytidy_recode` for at least one recode function per
  file after structural update"). — Effort: medium, Risk: low, Impact: same
- **[C] Do nothing** — New code paths in recode files are exercised only incidentally
  by existing tests; `fn/var/call` field correctness is never explicitly verified.

**Recommendation: A** — Adding the criterion is a one-line change; the assertion
work is small and fits in Task 30.

---

**Issue 5: Missing acceptance criterion — existing recode tests still pass after structural update**
Severity: REQUIRED
Violates Lens 3 (Acceptance Criteria — completeness)

The PR updates the `surveytidy_recode` attribute structure in Phase 0.6 recode files.
Existing snapshot tests for recode functions (`test-recode.R`) snapshot `@metadata@transformations`
content, which is populated from `surveytidy_recode$description`. Snapshot tests that
include a full `transformations` dump will not fail if the structure changes (since
`$description` still exists), but any test that captures the entire `surveytidy_recode`
attribute directly may break.

No acceptance criterion requires confirming that existing recode tests pass clean
(0 failures, 0 skipped) after the structural update, or that any snapshot diffs
from the update are reviewed via `snapshot_review()`.

Options:
- **[A]** Add criterion: "Existing recode tests pass 0 failures after structural
  update; any snapshot diffs reviewed with `snapshot_review()` before opening PR."
  Add a task: "Task 30: Run `devtools::test()` on full package — verify 0 failures.
  If snapshots for recode functions changed, review each diff with `snapshot_review()`."
  — Effort: low, Risk: low, Impact: prevents silent test regressions
- **[B] Do nothing** — Structural change to recode attrs silently breaks snapshots
  that would be caught only during CI; implementer may open PR with failing snapshots.

**Recommendation: A** — The task is already in the plan (Task 30: "Run `devtools::test()`
— verify recode file tests still pass") but the acceptance criterion in the PR checklist
doesn't list it. Add it there.

---

**Issue 6: Changelog path is missing the required phase subdirectory**
Severity: REQUIRED
Violates existing changelog convention (Lens 5 — File Completeness)

The plan says: `changelog/feature-transformation.md`

All existing changelogs are organized under phase subdirectories:
```
changelog/phase-0.5/feature-filter-out.md
changelog/phase-0.6/feature-recode.md
changelog/phase-survey-result/feature-add-survey-result.md
```

A file at `changelog/feature-transformation.md` (no subdirectory) is inconsistent
with the established convention and will be an orphan at the root.

Options:
- **[A]** Change path to `changelog/phase-0.6/feature-transformation.md` —
  transformation functions are part of Phase 0.6 (same phase as the recode
  functions they extend). — Effort: trivial, Risk: none
- **[B]** Create a new `changelog/phase-transformation/` subdirectory for this
  feature if it's considered a distinct phase. — Effort: trivial, Risk: none
- **[C] Do nothing** — File is created in wrong location; breaks changelog
  organizational convention.

**Recommendation: A** — These are Phase 0.6 vector-level transformation helpers;
`changelog/phase-0.6/feature-transformation.md` is the natural home.

---

#### Section: Tasks

**Issue 7: Task 23 "verify or fix" framing implies the code might already work — it won't**
Severity: SUGGESTION
Minor clarity gap

Task 23 reads: "If all 3 tests pass with the existing implementation, no code change
needed. If any fail, fix the `var_name`/`call_expr` capture in the relevant function."
At the point Task 23 runs, all 5 functions ARE implemented (Tasks 5, 11, 14, 17, 20).
If the `var_name`/`call_expr` capture was written correctly in each of those tasks,
tests 51–53 should pass. The "verify or fix" framing is accurate.

However: the framing "no code change needed" implies there's a scenario where the
capture works without explicit implementation — which could mislead the implementer
into skipping the capture in earlier tasks. Tightening the language would clarify
that the tests will pass only if Tasks 5, 11, 14, 17, 20 each correctly included the
`var_name`/`call_expr` capture per the Task 2 skeleton pattern.

Options:
- **[A]** Rephrase Task 23: "These 3 tests verify that the `var_name`/`call_expr`
  capture in each function body (from the Task 2 pattern) is correct. If any fail,
  the capture in that function's implementation task is the bug — fix it there."
  — Effort: trivial, Risk: none
- **[B] Do nothing** — Minor framing confusion; unlikely to cause actual bugs.

**Recommendation: A** — One sentence fix; prevents a "why do these tests exist if
they should just pass?" moment.

---

### Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 2 |
| REQUIRED | 4 |
| SUGGESTION | 1 |

**Total issues:** 7

**Overall assessment:** The plan has two blockers that would cause the implementer
to either stall (Task 28 targets an empty file) or make undocumented architectural
decisions mid-implementation (`.wrap_labelled()` path). Fix the recode file list and
add the `.wrap_labelled()` design decision before coding starts.

---

## Plan Review: Transformation — Pass 2 (2026-03-16)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | Quality gate recode file list names wrong files | ⚠️ Still open |
| 2 | `.wrap_labelled()` design decision missing | ⚠️ Still open |
| 3 | DRY violation — 5 identical inline arg validation blocks | ⚠️ Still open |
| 4 | Coverage criterion excludes updated recode files | ⚠️ Still open |
| 5 | Missing criterion — existing recode tests still pass | ⚠️ Still open |
| 6 | Changelog path missing phase subdirectory | ⚠️ Still open |
| 7 | Task 23 "verify or fix" framing | ⚠️ Still open |

All 7 Pass 1 issues are still open — the plan has not been updated since Pass 1.

### New Issues

#### Section: Notes — `var_name` / `call_expr` capture

**Issue 8: `call_expr` capture removed from spec — plan still includes it**
Severity: BLOCKING
Spec §II defines `surveytidy_recode` as a 3-field list: `list(fn, var, description)`.
Spec §XI confirms: "The `surveytidy_recode` structure `list(fn, var, description)` is
backward-compatible." The quality gate (§X) for recode functions explicitly says
"using `list(fn, var, description)` (drop `call`)".

The implementation plan contradicts this in three places:

1. **Notes — `var_name` / `call_expr` capture:** includes `call_expr <- rlang::expr_text(rlang::current_call())` as a required second capture line.
2. **Task 2 skeleton:** `.set_recode_attrs(result, label, labels, fn, var, call, description)` — `call` is in the helper signature.
3. **Tasks 28–29:** the expanded recode attr structure includes `call = call_expr`.

Note: spec §III–VII output contracts still say `list(fn, var, call, description)` — this
is a stale inconsistency in the spec (§II and §XI are the authoritative definition of the
structure; the output contract tables were not fully updated). The plan should follow §II/§XI.

Options:
- **[A]** Remove `call_expr` capture from the Notes pattern and from all references in Tasks
  2, 28, 29. Update `.set_recode_attrs()` signature to `(result, label, labels, fn, var,
  description)`. Update recode attr structure in Tasks 28–29 to 3-field list.
  — Effort: low, Risk: none, Impact: plan matches spec §II/§XI
- **[B] Do nothing** — Implementer writes code with `call` field that the spec dropped;
  integration tests for `surveytidy_recode$call` will fail since `mutate()` doesn't read
  it; the stale output contracts will cause confusion.

**Recommendation: A** — Straightforward edit; the authoritative spec definition is clear.

---

#### Section: Files / Tasks — `mutate.R` missing entirely

**Issue 9: `mutate.survey_base()` step 8 update required by spec but absent from plan**
Severity: BLOCKING
Spec §XI: "**One change to `mutate.R` is required**: step 8 must be updated to read
`surveytidy_recode$fn` and `surveytidy_recode$var` from the attr rather than deriving
them from the quosure."
Spec §X quality gate: "`mutate.survey_base()` step 8 updated to read
`surveytidy_recode$fn` and `surveytidy_recode$var` from the attr."

The plan's Files list does not include `R/mutate.R`. There is no task for this change.
There is no acceptance criterion requiring it. An implementer following the plan would
ship `R/transform.R` without the `mutate.R` change that makes the feature actually work
— `@metadata@transformations` would never get `fn` or `source_cols` set from the new
attribute.

Options:
- **[A]** Add `R/mutate.R` to Files. Add a task (e.g., Task 27b) before the recode
  tasks: "Update `mutate.survey_base()` step 8 to read `surveytidy_recode$fn` and
  `surveytidy_recode$var` from the attr when present. Columns without the attr are
  unaffected." Add acceptance criterion: "`mutate.survey_base()` step 8 reads
  `surveytidy_recode$fn` and `surveytidy_recode$var`; verified by integration test 56."
  — Effort: low, Risk: low, Impact: feature complete
- **[B] Do nothing** — The five transform functions ship without the mutate integration
  that reads `fn` and `var`; `@metadata@transformations` never gets those fields;
  integration tests 56–57 would fail.

**Recommendation: A** — Required by the spec; without it the feature is half-shipped.

---

#### Section: Tasks 27–30 — recode structure update

**Issue 10: Single-input vs. multi-input recode function distinction missing**
Severity: REQUIRED
Spec §X quality gate specifies two different behaviors for recode functions:

> Single-input functions (`na_if`, `replace_when`, `replace_values`, `recode_values`):
> set `var` via `cur_column()`
>
> Multi-input functions (`case_when`, `if_else`): set `var = NULL` and rely on
> mutate's quosure `all.vars()` fallback

Tasks 28–29 describe a single pattern applied uniformly to all recode functions: add
`var_name` capture at the top and set `var = var_name`. For `case_when` and `if_else`,
this would be wrong — those functions receive multiple input columns, so capturing a
single `var_name` via `cur_column()` is incorrect. The plan should explicitly call out
the two-pattern split.

Options:
- **[A]** Split Tasks 28–29 into two sub-tasks each: one for single-input functions
  (add `var_name` capture + set `var = var_name`) and one for multi-input functions
  (set `var = NULL`, skip `var_name` capture). — Effort: low, Risk: none, Impact: correct implementation
- **[B] Do nothing** — Implementer applies `cur_column()` to `case_when` and `if_else`,
  which would set `var` to the output column name (not a meaningful input source_col);
  multi-input transformation records would have wrong `source_cols`.

**Recommendation: A** — One additional sub-task; prevents a subtle correctness bug.

---

### Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 2 (Issues 8, 9) |
| REQUIRED | 1 (Issue 10) |
| SUGGESTION | 0 |

**Total new issues:** 3

**Overall assessment:** Two new blockers, both driven by spec v0.4 changes. Issue 8
(`call` removed) and Issue 9 (`mutate.R` update missing) must be resolved before
implementation. Issue 10 is a required correctness fix for multi-input recode functions.
