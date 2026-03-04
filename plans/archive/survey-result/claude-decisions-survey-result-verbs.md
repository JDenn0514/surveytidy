# Claude Decisions Log — surveytidy survey_result verbs

This file records planning decisions made during the Stage 3 spec review for the
`survey_result` verb support feature.

---

## 2026-03-02 — Stage 3 spec resolve: survey-result-verbs

### Context

Working through 11 issues from the adversarial review (`plans/spec-review-survey-result-verbs.md`)
to finalize the spec before implementation. One blocking issue (mutate() warning decision),
five required fixes, and five suggestions.

### Questions & Decisions

**Q: Where should `.apply_result_rename_map()` and `.prune_result_meta()` live?**
- Options considered:
  - **Inline in `R/verbs-survey-result.R`:** All call sites are in one file; code-style.md §4 is unambiguous.
  - **In `R/utils.R`:** Would require documented deviation from the rule.
- **Decision:** Inline at the top of `R/verbs-survey-result.R`
- **Rationale:** Both helpers have all call sites in one file; the code-style rule is clear; no cross-file use is foreseen.

**Q: Should `$x` be described as "always-present" in the `.meta` table?**
- Options considered:
  - **Amend type to `list or NULL`:** Add a lifecycle note explaining `select()` sets it to NULL.
  - **Move to a "conditionally present" section:** Restructure the table.
- **Decision:** Amend the `x` row — type changed to `list or NULL`, lifecycle note added.
- **Rationale:** Smallest targeted fix; eliminates the contradiction without restructuring the table.

**Q: Should `mutate()` warn when it modifies a column in `$group` or `$x`?**
- Options considered:
  - **No warning (silent passthrough):** Treat `survey_result` as a plain tibble; modification is user-directed.
  - **Warn (`surveytidy_warning_mutate_result_var`):** Consistent with `surveytidy_warning_mutate_design_var` for design objects.
- **Decision:** No warning. Silent passthrough is the final contract.
- **Rationale:** `survey_result` objects are post-estimation outputs, not live design objects. Modifying a column is deliberate data manipulation; a warning would add noise without preventing meaningful misuse.

**Q: Should `rename_with()` validation check for NA values in `.fn` output?**
- Options considered:
  - **Add `!anyNA(new_names)` check:** Prevents broken tibbles with NA column names.
  - **Delegate to `names<-` assignment:** Silently creates NA column names (footgun).
- **Decision:** Add NA check to Step 4 validation; error trigger description updated to include "or contains NA values".
- **Rationale:** Small defensive addition; prevents a class of broken output consistent with tidyr's own behavior.

**Q: Should `rename_with()` error test cover all four triggers independently?**
- Options considered:
  - **Separate blocks (12b, 12c, 12d):** One block per missing trigger.
  - **Combined additional block:** Bundle remaining triggers.
- **Decision:** Three separate test blocks (wrong-length, NA, duplicate-names), each with dual pattern.
- **Rationale:** Each trigger is a distinct observable behavior; separate blocks make failures unambiguous.

**Q: How should `result_freqs` be added to PR 2 meta-updating tests?**
- Options considered:
  - **Two targeted freqs test sections (17, 18):** One for rename, one for select, each exercising the empty-`$group` path.
  - **Modify existing tests to loop:** Fewer blocks but may obscure failures.
- **Decision:** Two targeted test sections (17 and 18).
- **Rationale:** The freqs structural distinction (`$group` empty, `$x` has key `"group"`) creates different code paths; separate blocks make failures unambiguous.

**Q: Should the spec explicitly address `dplyr_reconstruct.survey_result`?**
- Options considered:
  - **Add explicit note in Section III.1:** One sentence explaining why it's intentionally omitted.
  - **Leave implicit:** Trust the implementer to infer from the passthrough pattern.
- **Decision:** Add explicit note.
- **Rationale:** A reader familiar with `dplyr_reconstruct.survey_base` might add one by analogy; one sentence prevents that wasted effort.

**Q: Should `make_survey_result()` support multiple design types?**
- Options considered:
  - **Add `design` parameter (taylor/replicate/twophase):** Verifies design-type-agnostic claim in code.
  - **Document gap explicitly:** Accept taylor-only coverage as intentional.
- **Decision:** Add `design = c("taylor", "replicate", "twophase")` parameter to `make_survey_result()`; passthrough test 1 must loop over all design types. Meta-updating tests (PR 2) use taylor only.
- **Rationale:** User requested verification of the design-type-agnostic claim with at least one test per design type.

**Q: Should the passthrough test structure be loop vs. separate blocks?**
- Options considered:
  - **Loop within one block per verb:** Consistent with `make_all_designs()` pattern; 10 blocks total.
  - **Separate blocks per verb-type combination:** 30 blocks; more granular failures.
- **Decision:** One block per verb, inner loop over all result types × design types.
- **Rationale:** Consistent with the established cross-design loop pattern already in use.

### Outcome

Spec updated in place (`plans/spec-survey-result-verbs.md`). All 11 review issues resolved.
Key changes: helpers moved inline; `$x` lifecycle clarified; mutate() confirmed as silent
passthrough; NA validation added to `rename_with()`; three new error test blocks (12b/12c/12d);
two new freqs test sections (17/18); `make_survey_result()` gains a `design` parameter;
passthrough test 1 requires all-types × all-designs loop.

---

## 2026-03-02 — Stage 3 spec resolve: Pass 2 issues (Batches 1–3 of 19)

### Context

Working through 19 issues from the Pass 2 adversarial review of
`plans/spec-review-survey-result-verbs.md`. Six DRY violations, three design
gaps (2 BLOCKING), and ten missing test cases. Session covered Batches 1–3
(issues DRY-1 through EDGE-3, 12 of 19 resolved). Remaining issues (EDGE-4
through EDGE-10) to be resolved in the next session.

### Questions & Decisions

**Q: Should `.restore_survey_result()` be mandated as a shared helper for all 10 passthrough verbs?**
- Options considered:
  - **Add helper (DRY-1A):** One-liner body per passthrough; eliminates 27 lines of boilerplate.
  - **Keep 10 separate 3-line bodies (DRY-1B):** Accepted DRY violation.
- **Decision:** Add `.restore_survey_result()` as a third inline helper in Section III.1.
- **Rationale:** engineering-preferences.md §1 (DRY); 10 identical bodies with real call sites is exactly the case the rule is written for.

**Q: Should `tibble::as_tibble(.data)` be extracted as a `tbl` variable in IV.1–IV.3?**
- Options considered:
  - **Add step 0 (DRY-2A):** Extract `tbl` once; reuse in all subsequent steps.
  - **Leave as-is (DRY-2B):** Minor inefficiency, no correctness impact.
- **Decision:** Add `tbl <- tibble::as_tibble(.data)` as step 0 in all three meta-updating verb sections.
- **Rationale:** Spec pseudocode is what implementers follow; eliminating double coercions prevents copy-paste bugs.

**Q: How should `rename_with()` error tests 12–12d be structured?**
- Options considered:
  - **Parameterized loop (DRY-4A):** Named `bad_fns` list; one loop block; 4 snapshot entries → 1 per label.
  - **Keep four separate blocks (DRY-4B):** Accepted DRY violation.
- **Decision:** Replace 12–12d with one parameterized loop over a `bad_fns` named list.
- **Rationale:** engineering-preferences.md §1; repeated test setup with identical structure belongs in a loop.

**Q: How should `select()` with rename syntax (e.g., `select(r, grp = group)`) be handled?**
- Options considered:
  - **Document as known limitation (GAP-1A):** Add note; users must `rename()` then `select()`. Low effort.
  - **Detect and handle rename-in-select (GAP-1B):** After `eval_select`, compare output vs original names; apply `.apply_result_rename_map()` before pruning. Medium effort, correct behavior.
- **Decision:** 7B — detect and handle rename-in-select.
- **Rationale:** User prioritized correct behavior over simplicity for this case. The implementation (compare `names(selected_cols)` vs `names(tbl)[positions]`; apply rename map before pruning) is well-defined and reuses `.apply_result_rename_map()`.

**Q: How should `mutate(.keep = "none"/"used"/"unused")` handle meta coherence?**
- Options considered:
  - **Document as known limitation (GAP-2A):** Accept incoherent state; add tests asserting the broken meta. Low effort.
  - **Prune meta after NextMethod() (GAP-2B):** Call `.prune_result_meta()` after `.restore_survey_result()`; coherence always maintained.
- **Decision:** 8B — prune meta after `NextMethod()`.
- **Rationale:** User prioritized proactive coherence maintenance. `mutate.survey_result` now diverges from pure passthrough: after `.restore_survey_result()`, it calls `.prune_result_meta(names(result))`. No-op overhead for `.keep = "all"` (common case).

**Q: Should `.prune_result_meta()` null out `meta$numerator`/`meta$denominator` when their columns are dropped?**
- Options considered:
  - **Extend pruning to numerator/denominator (GAP-3A):** Add null-out logic; extend `test_result_meta_coherent()`.
  - **Document limitation (GAP-3B):** Justify exclusion; test known-broken state.
- **Decision:** 9A — extend `.prune_result_meta()` to prune numerator/denominator.
- **Rationale:** Consistent with the GAP-2 decision (8B — proactive coherence). `test_result_meta_coherent()` now checks all four meta reference types.

### Outcome

Spec updated with 12 of 19 Pass 2 issues resolved. Key structural changes:
- `.restore_survey_result()` added as third inline helper; passthrough pattern simplified to one-liner body
- `select()` now detects and handles rename-in-select syntax (correct behavior, not a limitation)
- `mutate()` diverges from pure passthrough: post-`NextMethod()` meta pruning maintains coherence for `.keep` variants
- `.prune_result_meta()` extended to cover `$numerator`/`$denominator`; `test_result_meta_coherent()` extended accordingly
- DRY violations cleaned up: `tbl` extraction, `rename_map` cross-reference, parameterized error test loop, passthrough output contract cross-references
- Tests added: 3b/3c (mutate `.keep`), 16b (rename-in-select), 19 (chained rename+select), 20 (zero-match `.cols`), 21 (identity rename)
- 7 issues remain (EDGE-4 through EDGE-10) for the next session.

---

## 2026-03-02 — Stage 3 spec resolve: Pass 2 final batch (EDGE-4 through EDGE-10)

### Context

Resolving the final 7 issues from the Pass 2 adversarial review. All are
missing test coverage or unspecified edge-case behavior. No architectural
changes required.

### Questions & Decisions

**Q: Should `rename_with()` with `...` forwarded to `.fn` be tested?**
- Options considered:
  - **Add test (EDGE-4A):** `rename_with(result_means, gsub, pattern = "mean", replacement = "avg")` — exercises `...` forwarding and meta update.
  - **Leave untested (EDGE-4B):** Accept the coverage gap.
- **Decision:** Add test 22.
- **Rationale:** The `...` forwarding path is a distinct code path that is easy to test and worth covering.

**Q: Should `drop_na()` primary happy path (actual NAs present) be explicitly tested?**
- Options considered:
  - **Add test (EDGE-5A):** Inject NAs into result fixture; call `drop_na()` on a column; assert row count reduction and class/meta preservation.
  - **Leave untested (EDGE-5B):** Accept the coverage gap.
- **Decision:** Add test 23.
- **Rationale:** The edge-case table only covered the "no NAs present" path; the primary happy path was absent.

**Q: Should `filter(.by = group)` on a `survey_result` be tested?**
- Options considered:
  - **Add test (EDGE-6A):** One block with `.by = group`; verify class and meta survive.
  - **Leave untested (EDGE-6B):** Passthrough; low risk.
- **Decision:** Add test 24.
- **Rationale:** Non-default argument path; low effort.

**Q: Should `slice_min`/`slice_max` with `with_ties = FALSE` and `na_rm = TRUE` be tested?**
- Options considered:
  - **Add tests (EDGE-7A):** Two variants; assert class/meta preserved through non-default argument paths.
  - **Leave untested (EDGE-7B):** Standard dplyr behavior.
- **Decision:** Add test 25 covering both variants.
- **Rationale:** engineering-preferences.md §4; non-default args change the returned row set.

**Q: Should `slice_sample(replace = TRUE, n > nrow)` be tested?**
- Options considered:
  - **Add test (EDGE-8A):** Over-sampling with replacement; asserts class/meta preserved when output has more rows than input.
  - **Leave untested (EDGE-8B):** Unusual pattern.
- **Decision:** Add test 26.
- **Rationale:** Over-sampling is a structurally unusual path (more output rows than input); worth verifying class/meta restoration survives it.

**Q: How should `select()` of zero columns be handled?**
- Options considered:
  - **Document + test degenerate case (EDGE-9A):** Zero-column select is permitted by dplyr; spec note confirms `meta$group = list()`, `meta$x = NULL`, and `test_result_invariants()` passes. Add test 27.
  - **Error on zero-column select (EDGE-9B):** Reject explicitly.
- **Decision:** Option A — document and test the degenerate case.
- **Rationale:** dplyr `select()` allows zero-column results; `tidyselect::eval_select()` returns `integer(0)`; dplyr returns a valid 0-column tibble. Erroring would be surprising behavior inconsistent with dplyr's own contract. User confirmed this direction after clarifying that dplyr does permit zero-column selects.

**Q: Should Test 15 description and assertion be corrected?**
- Options considered:
  - **Fix description and add assertion (EDGE-10A):** Correct "`group` and `y1` absent" to "`y1` absent"; add `is.null(meta(r)$x)` assertion.
  - **Leave the spec bug (EDGE-10B):** Propagates to implementation.
- **Decision:** Fix both errors.
- **Rationale:** Spec bug; would have produced a missed assertion in the implementation.

### Outcome

All 19 Pass 2 issues now resolved. Spec is ready for implementation.
Tests added: 22 (rename_with `...` forwarding), 23 (drop_na primary happy path),
24 (filter `.by`), 25 (slice_min/max non-default args), 26 (slice_sample replacement),
27 (zero-column select). Test 15 corrected. IV.1 spec note added for zero-column behavior.

---

## 2026-03-02 — Stage 3 implementation plan resolve: survey-result-verbs

### Context

Working through 10 issues from the plan adversarial review
(`plans/plan-review-survey-result-verbs.md`). Six required fixes and four
suggestions. No architectural changes required — all issues were documentation
gaps, missing criteria, or minor wording fixes.

### Questions & Decisions

**Q: Should test sections 23–26 remain in PR 1 (current plan) or move to PR 2 (per spec)?**
- Options considered:
  - **Keep in PR 1 (plan's current position):** Passthrough verb edge cases belong in the same PR that delivers those verbs; reviewers see complete coverage at PR 1 merge time.
  - **Move to PR 2 (match spec Section VI):** Strict spec-plan alignment; cleaner PR 1 scope.
- **Decision:** Keep in PR 1. Logged here as an explicit deviation from spec Section VI.
- **Rationale:** The plan's call is the right engineering decision — testing edge cases of passthrough verbs in PR 1 gives reviewers full coverage visibility at merge time. The spec placed them in PR 2 for structural reasons that don't apply now that the test infrastructure is also in PR 1.

**Q: What does the spec mean when Section VIII says `plans/error-messages.md` does not need updating, while Section IX requires updating the source file column for `surveytidy_error_rename_fn_bad_output`?**
- Options considered:
  - **Contradiction is real:** Two conflicting spec sections; plan must pick one.
  - **Sections cover different things:** Section VIII means "no new error class row"; Section IX means "update the source file column for an existing row."
- **Decision:** Sections cover different things. The plan correctly follows Section IX (updating the source file column only, no new row).
- **Rationale:** `surveytidy_error_rename_fn_bad_output` already exists in `plans/error-messages.md` from `rename_with.survey_base`. PR 2 adds `rename_with.survey_result` as a second source file for the same error class — a source file column update, not a new row.

### Outcome

Implementation plan updated with 10 fixes: corrected Implementation Notes wording
(test_result_meta_coherent usage in PR 1); added 95% coverage gate to Quality Gate
Checklist; added test sections 28 (select all columns) and 29 (drop_na no-op); added
NEWS.md to both PRs' Files sections; clarified passthrough heading to "8 verbs (all
except drop_na)"; updated snapshot criterion to acknowledge spec's conditional; added
expected_class derivation note to section 1 loop description. Plan is ready for
implementation.

---
