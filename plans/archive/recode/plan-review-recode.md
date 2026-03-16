## Plan Review: Phase 0.6 (recode) — Pass 1 (2026-03-09)

---

### New Issues

#### Section: PR Map

No issues found.

---

#### Section: PR 1 — feature/recode

---

**Issue 1: TDD ordering broken — test_invariants() extension in STEP 2 makes STEP 5 tests unpassable until STEP 6 is complete**
Severity: BLOCKING
[Violates testing-surveytidy.md: "test_invariants() required as first assertion in every verb test block" + conflicts with the stated TDD goal in Task 5.4]

STEP 2 extends `test_invariants()` to assert that no column in `result@data` carries a `"surveytidy_recode"` attribute. STEP 5 (which comes after STEP 2) writes and runs tests for all 6 recode functions — they all call `test_invariants(result)` on the output of `mutate(d, col = case_when(..., .label = ...))`.

The problem: when case_when() (after Task 5.3) returns a haven_labelled vector with `surveytidy_recode` attr set, `dplyr::mutate()` preserves that attr in the output data frame (confirmed: dplyr does not strip custom attrs). The existing `mutate.survey_base()` stores this directly into `@data` (step 7: `.data@data <- new_data`) without stripping — the strip step is not added until STEP 6. Similarly, surveycore does NOT strip haven or custom attrs during `@data` assignment.

Therefore, when `test_invariants()` runs on the mutate result in STEP 5, it checks `attr(result@data[["cat"]], "surveytidy_recode")` — which is non-NULL — and FAILS. Task 5.4 ("All section 3 tests should now pass") is incorrect: the tests remain broken until STEP 6 is complete. The same applies to the Task 5.5–5.9 "run tests — section N passes" steps.

Additionally, even if the attr check didn't fail, the metadata assertions in STEP 5 tests (e.g. `expect_identical(result@metadata@variable_labels$cat, "Response category")`) would also fail because post-detection is not wired until STEP 6. The STEP 5 TDD loop tests full mutate() pipeline behavior that doesn't exist yet.

Options:
- **[A]** Move the `test_invariants()` extension (STEP 2) to after STEP 6 is complete. Renumber as Task 6.8. In STEP 5, write tests that call `test_invariants()` (without the recode-attr check) to verify recode functions are correct in isolation when embedded inside mutate(). Defer metadata assertions (from test sections 1 and 2) to Task 6.1 stubs and confirm after STEP 6. — Effort: low, Risk: low, Impact: restores valid TDD ordering
- **[B]** In STEP 5, test recode functions directly (not inside mutate()): `result_vec <- case_when(x > 5 ~ "high", .default = "low", .label = "Cat")` and assert on the vector directly (has `surveytidy_recode` attr set, haven_labelled class, etc.). Only STEP 6 and 7 test through `mutate()`. Defer calling `test_invariants()` to STEP 7. — Effort: medium, Risk: low, Impact: cleaner separation of unit vs integration tests
- **[C] Do nothing** — Implementer will hit a wall at Task 5.4; every section 3–8 test will fail despite correct recode function implementations.

**Recommendation: A** — Moving STEP 2 to Task 6.8 (after mutate.R is fully wired) is the minimal change that restores the TDD ordering. STEP 5 tests can still use the pre-extended `test_invariants()`. The recode-attr invariant fires on all subsequent tests once Task 6.8 is done.

---

**Issue 2: `tests/testthat/test-mutate.R` not listed in the Files section**
Severity: REQUIRED
[Violates Lens 5 — File Completeness]

Task 6.2 explicitly states: "Also update `tests/testthat/test-mutate.R`: change any reference to `surveytidy_warning_mutate_design_var` → `surveytidy_warning_mutate_weight_col`." The file `tests/testthat/test-mutate.R` is modified in this PR but is absent from the Files section at the top of the plan.

An implementer who uses the Files list as a checklist will miss this file.

Options:
- **[A]** Add `tests/testthat/test-mutate.R` to the Files section with the annotation: "MODIFIED: update warning class reference from `surveytidy_warning_mutate_design_var` to `surveytidy_warning_mutate_weight_col`." — Effort: low, Risk: low
- **[B] Do nothing** — Missing from the PR diff checklist; easy to omit in review.

**Recommendation: A**

---

**Issue 3: `tests/testthat/_snaps/mutate.md` snapshot update not addressed**
Severity: REQUIRED
[Violates testing-standards.md: "Snapshot failures block PRs"]

`tests/testthat/_snaps/mutate.md` contains a snapshot for the existing `surveytidy_warning_mutate_design_var` warning (line 7: `! mutate() modified design variable(s): wt.`). Task 6.2 replaces this class with `surveytidy_warning_mutate_weight_col` and splits behavior into two separate warnings — the message text will change. The plan does not mention:
1. That the existing snapshot in `_snaps/mutate.md` will break
2. That `testthat::snapshot_review()` must be run to approve the updated text
3. What the new warning messages should look like (they're in Task 6.2 code, but no explicit "update snapshot" step exists)

Options:
- **[A]** Add a task (e.g., Task 6.2b) explicitly: "Run `devtools::test()` — expect snapshot failure for `mutate()` warns when a design variable is modified. Run `testthat::snapshot_review()` to approve the new warning message for `surveytidy_warning_mutate_weight_col`." — Effort: low, Risk: low
- **[B] Do nothing** — CI will fail on the snapshot mismatch; the implementer will discover it, but it's a needless surprise.

**Recommendation: A**

---

**Issue 4: Line coverage criterion missing from acceptance criteria**
Severity: REQUIRED
[Violates testing-standards.md: "98%+ line coverage is the project target; PRs that drop coverage below 95% are blocked by CI"; and stage 2 review instructions: "Is the 98%+ line coverage requirement stated?"]

The acceptance criteria list does not include a coverage requirement. The spec §XIII lists "Coverage ≥95% for all new/modified code" (this itself is below the 98%+ target in testing-standards.md, but at minimum the acceptance criteria should reference it).

Options:
- **[A]** Add `- [ ] Line coverage ≥98% for R/recode.R and R/utils.R new helpers; no drop below 95% overall` to the acceptance criteria. — Effort: low, Risk: low
- **[B] Do nothing** — Coverage not verified before PR open; may regress.

**Recommendation: A**

---

**Issue 5: Missing snapshot test for `surveytidy_error_recode_unmatched_values` in Task 7.1 section 12**
Severity: REQUIRED
[Violates testing-standards.md dual pattern requirement; violates spec §XII.1 section 12: "expect_snapshot(error = TRUE) for each class in §XI"]

The spec §XI lists 8 error/warning classes. Section 12 requires a snapshot for each. Task 7.1's section 12 block has 7 `expect_snapshot()` calls — it is missing one for `surveytidy_error_recode_unmatched_values`. The test for `surveytidy_error_recode_use_labels_no_attrs` is present (`mutate(d, cat = recode_values(y1, from = 1, to = 2, .use_labels = TRUE))`), and the test for `surveytidy_error_recode_from_to_missing` is present, but there is no snapshot for the unmatched-values error.

Triggering it requires: `mutate(d, cat = recode_values(y1, from = 99, to = "other", .unmatched = "error"))` (where 99 does not appear in y1).

Options:
- **[A]** Add to Task 7.1 section 12: `expect_snapshot(error = TRUE, mutate(d, cat = recode_values(y1, from = 99L, to = "other", .unmatched = "error")))` — Effort: low, Risk: low
- **[B] Do nothing** — `surveytidy_error_recode_unmatched_values` has no snapshot; dual pattern requirement violated for this class.

**Recommendation: A**

---

**Issue 6: Section 11 (.description argument) tests only cover case_when() — spec requires all 6 functions**
Severity: REQUIRED
[Violates spec §XII.1 section 11: ".description argument (all 6 functions)"]

Task 7.1's section 11 tests use only `case_when()` to verify that `.description` is stored in `@metadata@transformations[[col]]$description`. The spec requires this test for all 6 functions. The other 5 functions (`replace_when`, `if_else`, `na_if`, `recode_values`, `replace_values`) are not tested for `.description` behavior in section 11.

Additionally, the "no surveytidy args → no surveytidy_recode attr" backward compat test in section 11 only uses `dplyr::case_when()` explicitly — it doesn't test the other 5 surveytidy functions with no surveytidy args, which is where shadowing behavior could accidentally leave attrs.

Options:
- **[A]** Expand section 11 in Task 7.1 with at minimum one `.description` test per function (can be a single loop or one block per function). Also add a backward-compat check for each shadowed function (`if_else`, `na_if`) with no args. — Effort: medium, Risk: low, Impact: closes the spec coverage gap
- **[B]** Consolidate into a parametrized helper that runs a `.description` smoke test for each of the 6 functions. — Effort: medium
- **[C] Do nothing** — 5 of 6 functions have no `.description` test; spec requirement unmet; coverage gap.

**Recommendation: A**

---

**Issue 7: Behavioral regression — domain column mutation loses its warning after Task 6.2**
Severity: REQUIRED
[DRY/correctness: changes in Task 6.2 silently drop existing behavior for protected columns]

The current `mutate.survey_base()` uses `intersect(.protected_cols(.data), names(.data@data))` to detect modified protected columns — this includes the domain column (`"..surveycore_domain.."`). If a user writes `mutate(d, ..surveycore_domain.. = TRUE)`, the existing code emits `surveytidy_warning_mutate_design_var`.

Task 6.2 replaces this with a two-pronged check using `weight_var` and `structural_vars <- setdiff(.survey_design_var_names(.data), weight_var)`. The domain column is not returned by `.survey_design_var_names()` (it's added only by `.protected_cols()` on top of design vars). After Task 6.2, mutating the domain column silently produces no warning.

While domain column mutation by users is unlikely (the name is obscure), this is a regression in coverage of a previously-guarded behavior.

Options:
- **[A]** After computing `changed_structural`, add a third check: `changed_domain <- intersect(mutated_names, surveycore::SURVEYCORE_DOMAIN_COL)`. If non-empty, emit `surveytidy_warning_mutate_structural_var` (or a domain-specific message). — Effort: low, Risk: low
- **[B]** Accept the regression with a code comment: "Domain column mutation is not detected (obscure use case; not worth a separate warning class)." Document it. — Effort: low, Risk: low, Impact: intentional gap
- **[C] Do nothing** — Silent regression; no test documents the intentional removal.

**Recommendation: B** — Domain column mutation is genuinely obscure. Accept the regression with a comment rather than adding another warning path.

---

#### Section: Implementation Tasks (STEP sequence)

---

**Issue 8: Task 6.5 is entirely superseded by Task 6.6 but left with content — misleading**
Severity: SUGGESTION
[Engineering-preferences.md: "Explicit over clever"; plan should not contradict itself]

Task 6.5 describes a transformation log implementation, then its own final paragraph says "REVISE: capture recode_attrs from new_data BEFORE calling .strip_label_attrs() in Task 6.4. See revised ordering in Task 6.6." Task 6.6 then provides the actual implementation that supersedes everything in 6.5.

An implementer reading Task 6.5 in isolation would waste time implementing something that's immediately discarded. The plan contradicts itself in consecutive tasks.

Options:
- **[A]** Remove Task 6.5 body content entirely. Replace with: `#### Task 6.5 — [SUPERSEDED by Task 6.6]\n\nSee Task 6.6 for the correct implementation ordering.` — Effort: low
- **[B]** Merge 6.5 and 6.6 into a single Task 6.5 with the final correct ordering. — Effort: low
- **[C] Do nothing** — Implementer may implement 6.5 before reading 6.6, wasting time.

**Recommendation: A**

---

**Issue 9: Missing edge case — `.use_labels = TRUE` + `.factor = TRUE` in recode_values()**
Severity: SUGGESTION
[Engineering-preferences.md: "Handle more edge cases, not fewer"]

The spec §VIII.5 describes the output contract for `recode_values()` when `.factor = TRUE`: calls `.factor_from_result(result, .value_labels, unique(to))`. When combined with `.use_labels = TRUE`, `to` becomes `names(labels_attr)` (the label strings). The interaction is: factor levels are set to `unique(names(labels_attr))` — the label strings become both the new values AND the factor levels.

This interaction is not tested anywhere in the plan. Section 7 in Task 5.8 covers `.use_labels = TRUE` and `.factor = TRUE` separately but not together. The level-ordering behavior when `to = names(labels_attr)` and `.value_labels = NULL` is non-trivial.

Options:
- **[A]** Add to section 7 test requirements: `.use_labels = TRUE` + `.factor = TRUE` → factor levels = unique label strings in label-definition order. — Effort: low, Risk: low
- **[B] Do nothing** — Interaction is accepted as untested in Phase 0.6.

**Recommendation: A**

---

**Issue 10: Test prescriptiveness inconsistency across functions**
Severity: SUGGESTION
[Engineering-preferences.md: "Explicit over clever"]

Task 5.1 provides full test code for all case_when() section 3 tests. Tasks 5.5 (replace_when()), 5.6 (if_else()), 5.7 (na_if()), 5.8 (recode_values()), and 5.9 (replace_values()) say "Write tests covering: [narrative list]" with no code.

This inconsistency means the implementer must author ~40 test blocks from scratch for 5 of the 6 functions, while case_when() is fully prescribed. Section 2b (structural-var warnings, Task 6.1) is similarly narrative-only.

Options:
- **[A]** Add at minimum skeleton test blocks (with `# stub` comments) for each function and section, matching the case_when() level of prescription. — Effort: medium
- **[B]** Accept the inconsistency; narrative tests are acceptable per spec §XII.1 which provides a text description for each section. — Effort: none
- **[C] Do nothing** — Works, but inconsistency between functions increases implementer ambiguity.

**Recommendation: B** — The spec §XII.1 provides a clear bullet list for each section. Narrative test requirements for non-case_when functions are acceptable; adding full test code for all 5 functions is high effort with marginal value given the spec coverage.

---

**Issue 11: Spec §I.1 says "2 internal helpers" but plan correctly implements 4**
Severity: SUGGESTION
[Spec fidelity: minor inconsistency could confuse future readers]

The spec §I.1 Deliverables table states: "New file: 6 exported functions + **2 internal helpers**". However, §X defines 4 internal helpers (`.validate_label_args()`, `.wrap_labelled()`, `.factor_from_result()`, `.merge_value_labels()`). The plan correctly implements all 4.

An implementer reading §I.1 first might expect only 2 helpers and be confused when §X describes 4. The spec is approved so it can't be changed, but the plan could note this discrepancy explicitly.

Options:
- **[A]** Add a note in Task 4's header: "Note: spec §I.1 says '2 internal helpers' but §X specifies 4. Implement all 4 as described in §X." — Effort: low
- **[B] Do nothing** — Spec §X is clear; an implementer who reads both sections will resolve the conflict.

**Recommendation: B** — Any implementer who reads §X (which they must, since it defines the helpers) will see all 4.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 6 |
| SUGGESTION | 4 |

**Total issues:** 11

**Overall assessment:** The plan is largely sound — function contracts, task sequence, and file organization are correct. However, one blocking flaw in the TDD ordering must be resolved before implementation begins: STEP 2's test_invariants() extension makes all STEP 5 per-function TDD loops fail until STEP 6's strip step is wired. There are also six required fixes (missing file in list, missing snapshot, missing coverage criterion, regression in domain-col warning behavior, incomplete section 11, and unaddressed existing snapshot breakage) that would cause CI failures or spec coverage gaps.
