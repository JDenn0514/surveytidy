# Spec Review: Deduplication, Programmatic Renaming, and Row-Wise Operations

**Reviewed:** 2026-02-24
**Spec file:** `plans/spec-dedup-rename-rowwise.md`
**Reviewer:** Adversarial spec review (all five lenses)

---

## Section II — Architecture

**Issue 1: ROWWISE_SENTINEL file placement contradiction**
Severity: BLOCKING
Violates engineering-preferences.md §5 (explicit over clever) — the spec gives three different answers.

§II.1 file org table says: `"Defined at the top of R/rowwise.R"`. §II.4 body says: `"it should move to R/utils.R"`. §VII quality gate says: `"ROWWISE_SENTINEL constant in R/utils.R"`. The implementer cannot reconcile these without making an architectural guess. §II.1's file org table (the authoritative layout reference) contradicts the quality gate.

Options:
- **[A]** Remove the rowwise.R line from §II.1's file org table; add `utils.R` entry; delete the ⚠️ GAP note (it's now resolved) — Effort: low, Risk: low, Impact: unblocks implementation
- **[B]** Keep sentinel in rowwise.R; update quality gate — Effort: low, Risk: low, Impact: violates code-style.md §4 (helpers used in 2+ files belong in utils.R)
- **[C] Do nothing** — implementer guesses; 50/50 chance of misplacing the constant

**Recommendation: A** — utils.R is correct per code-style.md §4 since both rowwise.R and mutate.R need it; resolve the contradiction in the spec.

---

**Issue 2: `@groups` update contract is contradicted by the quality gate and test plan**
Severity: BLOCKING
Three sections of the spec disagree on whether `.apply_rename_map()` updates `@groups`.

§II.3 `.apply_rename_map()` contract explicitly states: `"What does NOT change: @groups — passed through unchanged."` §IV.4 Rule 5 says the same: `"@groups is not automatically updated — the renamed column still matches its new name in @data so estimation will fail."` The GAP recommends Option A (fix it). But §VII quality gate says: `"@groups updated by .apply_rename_map() when renamed cols are in @groups"`. And §VI.3 test plan says: `"Renaming a column that is in @groups updates @groups accordingly"`. The quality gate and test plan have already committed to Option A, but the contract section still says Option C (do nothing).

Reading the actual `rename.survey_base()` implementation confirms: `@groups` is never touched (the attr() block at lines 119–148 of rename.R updates @data, @variables, @metadata only). Adding @groups update to `.apply_rename_map()` is a new behavioral change that must be reflected in the contract.

Options:
- **[A]** Update §II.3 contract to include `@groups` update: add bullet 2.5 — "If any renamed column appears in `@groups`, the old name is replaced with the new name in `@groups`." Remove the ⚠️ GAP note (decision made) — Effort: low, Risk: low, Impact: unblocks implementation and testing
- **[B]** Remove the @groups update from §VII and §VI.3; restore Option C behavior — Effort: low, Risk: low, Impact: latent bug in rename() documented as known limitation
- **[C] Do nothing** — implementer uses the quality gate as truth, ignores the contract section; §II.3 is now incorrect documentation

**Recommendation: A** — the quality gate and test plan already commit to Option A; update the contract to match.

---

## Section III — `distinct()`

**Issue 3: `visible_vars` GAP (Option A vs B) unresolved; test plan assumes Option A**
Severity: BLOCKING
The spec calls out the gap ("Confirm before implementation") but §VI.2 Section 3 has already committed to Option A: `"result@variables$visible_vars equals original visible_vars — not updated"`. If Option B is chosen, every test in Section 3 would need different assertions.

The ⚠️ GAP note says to confirm before implementation. But the test plan doesn't mention this dependency. An implementer reading only §VI.2 would write tests for Option A, then receive feedback that Option B was decided.

Options:
- **[A]** Decide Option A (current draft: pure row op, visible_vars unchanged) — remove the ⚠️ GAP note; proceed — Effort: low, Risk: low, Impact: simplest; consistent with "row operations don't touch visible_vars"
- **[B]** Decide Option B (update visible_vars to user's column selection when `...` non-empty) — update §III.2 output contract and all of §VI.2 Section 3 accordingly — Effort: medium, Risk: medium, Impact: closer dplyr UX but couples row verb to column display state
- **[C] Do nothing** — implementer picks one; test plan disagrees 50% of the time

**Recommendation: A** — Option A is consistent with the established invariant that row operations don't touch visible_vars; the decision cost is low.

---

**Issue 4: `distinct()` with `...` including design variables — dangerous case not warned**
Severity: SUGGESTION
Violates engineering-preferences.md §4 (handle more edge cases, not fewer).

`distinct(d, strata)` deduplicates by the strata variable alone. This would remove rows from PSUs needed for variance estimation, silently corrupting the design. The spec allows any column in `...` including design variables. There is no mention of a warning, error, or even documentation note for this case.

Options:
- **[A]** Add a `surveytidy_warning_distinct_design_var` warning when `...` resolves to include protected columns — analogous to `surveytidy_warning_rename_design_var` — Effort: low, Risk: low, Impact: real survey workflows could trigger this
- **[B]** Document in roxygen that deduplicating by design variables may corrupt variance estimation — Effort: low, Risk: low, Impact: user-visible; no code change
- **[C] Do nothing** — silent data corruption risk

**Recommendation: A** — the pattern is identical to the rename() warning and the infrastructure already exists via `.protected_cols()`; add it to the error table.

---

## Section IV — `rename_with()`

**Issue 5: `...` forwarding mechanism absent from `rename_with()` behavior contract**
Severity: BLOCKING
Violates contract completeness: a function argument (`...`) has no corresponding rule in the behavior section.

§IV.2 signature specifies `...` as "Additional arguments passed to `.fn`." §IV.4 lists six behavior rules. None of them mention how `...` is forwarded to `.fn`. The correct implementation is `rlang::exec(.fn, old_names, !!!rlang::list2(...))` or similar — but the spec leaves this entirely to the implementer. This matters practically: `rename_with(d, stringr::str_replace, pattern = "y", replacement = "Y")` must pass `pattern` and `replacement` through.

Options:
- **[A]** Add Rule 2.5: "Apply `.fn` to the resolved old names as: `new_names <- rlang::exec(.fn, old_names, !!!rlang::list2(...))`. Support formula syntax via `rlang::as_function(.fn)` for consistency with dplyr." — Effort: low, Risk: low, Impact: specifies exact implementation; unblocks formula support decision
- **[B]** Add Rule 2.5 without formula support: "Apply `.fn` to the resolved old names as: `new_names <- do.call(.fn, c(list(old_names), list(...)))`. Formula syntax is not supported." — Effort: low, Risk: low, Impact: breaks `~ toupper(.)` style
- **[C] Do nothing** — implementer invents the forwarding mechanism; formula support is undefined

**Recommendation: A** — dplyr's `rename_with()` supports `rlang::as_function()` and users will expect the same; specify both forwarding AND formula support in one rule.

---

**Issue 6: `rename_with()` applied to domain column — behavior not specified**
Severity: REQUIRED
Violates engineering-preferences.md §4 (handle more edge cases, not fewer).

`rename_with(d, toupper, .cols = everything())` will select `everything()` including `..surveycore_domain..` (the domain column). `.protected_cols()` will trigger `surveytidy_warning_rename_design_var`. But the domain column is not just a named design variable — it has a fixed identity (`SURVEYCORE_DOMAIN_COL`) used by filter() and estimation. If it is renamed to `"..SURVEYCORE_DOMAIN.."` (upper-cased), the domain column's identity is corrupted silently: `filter()` would stop finding it.

The spec says "Domain column preserved — because @data columns are unchanged" for `distinct()`, but `rename_with()` does change column names. This case is entirely unaddressed.

Options:
- **[A]** Block renaming the domain column: add `SURVEYCORE_DOMAIN_COL` to `.protected_cols()` skip list (or issue a specific error if domain col is in the rename map) — Effort: low, Risk: low, Impact: prevents silent corruption
- **[B]** Warn with `surveytidy_warning_rename_design_var` (already covers protected cols) AND update `SURVEYCORE_DOMAIN_COL` reference internally — Effort: high, Risk: high, Impact: domain col identity is a constant; renaming it is never correct
- **[C] Do nothing** — `everything()` silently renames the domain column; `filter()` silently breaks

**Recommendation: A** — the domain column is a fixed identity constant, not a user-named variable; `.apply_rename_map()` should skip it with a warning, just as surveycore protects it.

---

**Issue 7: Cross-design loops absent from `rename_with()` test sections**
Severity: REQUIRED
Violates testing-surveytidy.md: "Never write a verb test that only covers one design type."

§VI.3 test sections list assertions as flat statements (e.g., "`rename_with(d, toupper)` — all non-design columns uppercased"). There is no `for (d in designs)` instruction anywhere in the rename_with test plan. §VI.2 for `distinct()` explicitly says "all three design types" and `make_all_designs()`. §VI.3 does not.

Options:
- **[A]** Add explicit cross-design loop language to each §VI.3 section: "For each design in `make_all_designs(seed = N)`:" prefix on every test block — Effort: low, Risk: low, Impact: consistent with testing-surveytidy.md
- **[C] Do nothing** — test file may be written for one design type only; CI catches it later

**Recommendation: A** — a one-line addition to each section; consistent with §VI.2 and §VI.4.

---

**Issue 8: `eval_rename()` vs `eval_select()` — wrong function listed first for `.cols` resolution**
Severity: REQUIRED
Using `eval_rename()` for `.cols` in `rename_with()` produces incorrect behavior.

§IV.4 Rule 1 says: "Resolve `.cols` using `tidyselect::eval_rename()` or `tidyselect::eval_select()`." These are not equivalent alternatives — they have different semantics. `eval_rename()` expects `new_name = old_name` syntax (for `rename()`); `eval_select()` expects a selection expression and returns selected column names. For `rename_with()`, `.cols` is a column selection (e.g., `starts_with("y")`), not a rename specification. An implementer using `eval_rename()` would get an error or incorrect results when `.cols` is a tidyselect expression like `starts_with("y")`.

The correct function is `tidyselect::eval_select()`. dplyr's own `rename_with()` implementation uses `eval_select()`.

Options:
- **[A]** Replace the rule with: "Resolve `.cols` using `tidyselect::eval_select(rlang::expr(.cols), .data@data)` — this returns a named integer vector where names are the selected column names." — Effort: low, Risk: low, Impact: removes the wrong-function trap; specifies the exact call signature
- **[C] Do nothing** — an implementer unfamiliar with the distinction uses `eval_rename()` first; gets runtime error or silent corruption

**Recommendation: A** — remove the ambiguity; `eval_rename()` should not appear in this rule.

---

**Issue 9: Domain preservation test missing from §VI.3 (`rename_with()`)**
Severity: REQUIRED
Violates testing-surveytidy.md §VI.1: "Domain column preservation asserted for every verb."

§VI.3 has five test sections. None of them include a test asserting that the domain column (`SURVEYCORE_DOMAIN_COL`) is present and unchanged after `rename_with()` is applied to columns other than the domain column (the normal case). The coverage gap: a regression in `.apply_rename_map()` that accidentally removes or renames the domain column when it is not in the rename_map would not be caught.

Note: Issue 6 addresses the case where `rename_with()` tries to rename the domain column. This issue addresses the orthogonal case: `rename_with()` on other columns must leave the domain column intact.

Options:
- **[A]** Add to §VI.3 (happy paths section): "Filtered design case: `rename_with(d_filtered, toupper, .cols = starts_with('y'))` — `SURVEYCORE_DOMAIN_COL` is present and unchanged in `result@data`" — Effort: low, Risk: low, Impact: aligns with domain preservation rule applied to every verb
- **[C] Do nothing** — domain preservation for rename_with() is implicitly tested only via test_invariants() (which does not check the domain column); silent regression possible

**Recommendation: A** — one test block; consistent with the universal domain preservation rule.

---

## Section V — `rowwise()`

**Issue 10: Spec's §V.5 replacement code has two bugs that leave the implementation broken**
Severity: BLOCKING
The proposed code block in §V.5 is the only implementation guidance for the mutate() change. It has two defects that together make the rowwise path non-functional.

**Bug 1 — `effective_by` unbound in the rowwise branch.** The existing `mutate.survey_base()` (lines 115–119 of R/mutate.R) defines `effective_by` in all branches. The spec's replacement block assigns `effective_by` only in the `else if` and `else` branches — the `is_rowwise` branch never assigns it. The code at line 155 (`has_by <- !is.null(effective_by)`) then errors with "object 'effective_by' not found" when `is_rowwise = TRUE`. Fix: add `effective_by <- NULL` inside the `is_rowwise` branch.

**Bug 2 — `base_data` never used in the dplyr::mutate() call.** The spec assigns `base_data <- dplyr::rowwise(.data@data, ...)` in the rowwise branch. But the spec then says "The rest of mutate.survey_base() continues as-is" — meaning line 157 (`dplyr::mutate(.data@data, ...)`) is NOT changed. The rowwise-wrapped `base_data` is built and immediately discarded. The mutation runs on the unwrapped `.data@data`. Fix: the dplyr::mutate() call at line 157 must use `base_data` instead of `.data@data`. The spec must explicitly say so.

Options:
- **[A]** Fix both bugs in the spec's §V.5 code block: add `effective_by <- NULL` in the rowwise branch; change the dplyr::mutate() call to use `base_data`; add an explicit note "Line 157 changes from `.data@data` to `base_data`" — Effort: low, Risk: low, Impact: unblocks correct implementation
- **[C] Do nothing** — the implementation will fail at runtime; discovered in testing

**Recommendation: A** — these are spec-level bugs in the reference code; fix them before coding begins.

---

**Issue 11: `group_by(.add = TRUE)` while in rowwise mode — unspecified interaction**
Severity: REQUIRED
Violates engineering-preferences.md §4 (handle more edge cases, not fewer).

§V.2 specifies that `group_by(data, ...)` (default `.add = FALSE`) replaces `@groups`, clearing the rowwise sentinel. But the existing `group_by.survey_base()` implementation (R/group-by.R lines 107–111) handles `.add = TRUE` by doing `unique(c(.data@groups, group_names))`. If `@groups = c(ROWWISE_SENTINEL)` and the user calls `group_by(d, region, .add = TRUE)`, the result is `@groups = c(ROWWISE_SENTINEL, "region")`. `mutate()` would then detect `is_rowwise = TRUE` and route to `dplyr::rowwise(.data@data, dplyr::all_of("region"))` — treating "region" as a rowwise id column, not a group-by column. This is silently wrong.

Options:
- **[A]** Specify that `group_by(.add = TRUE)` when in rowwise mode clears the sentinel first, then adds the new groups — rowwise and group_by are mutually exclusive regardless of `.add` — Effort: low, Risk: low, Impact: correct semantics; group_by always exits rowwise mode
- **[B]** Document the limitation: `group_by(.add = TRUE)` on a rowwise design produces undefined behavior; users should call `ungroup()` first — Effort: trivial, Risk: none, Impact: user-visible documentation
- **[C] Do nothing** — `group_by(.add = TRUE)` on a rowwise design silently corrupts the groups state; no test exists to catch it

**Recommendation: A** — rowwise and group_by are mutually exclusive; the sentinel should always be cleared when `group_by()` is called, regardless of `.add`.

---

**Issue 12: `test_invariants()` absent from rowwise test sections 2–6**
Severity: REQUIRED
Violates §VI.1: "`test_invariants()` is the first assertion in every `test_that()` block."

§VI.4 Section 1 mentions `test_invariants()` explicitly. Sections 2–6 do not. Each section creates or transforms a survey object and should call `test_invariants()` as the first assertion.

Options:
- **[A]** Add "`test_invariants(result)` is the first assertion" language to Sections 2, 3, 4, 5, and 6 of §VI.4 — Effort: low, Risk: low, Impact: enforces the universal rule
- **[C] Do nothing** — the test file is written without invariant checks in most blocks; coverage gap discovered in code review

**Recommendation: A** — mechanical fix; add one phrase per section.

---

**Issue 13: Partial `ungroup()` behavior specified in §V.2 but has no test in §VI.4**
Severity: REQUIRED
Violates testing-surveytidy.md: every specified behavior must be tested.

§V.2 explicitly specifies: `"ungroup(data, some_col) removes some_col from @groups but does NOT remove the sentinel — rowwise mode persists."` This is a non-obvious behavior (contrast with `ungroup(data)` which clears everything). Reading `ungroup.survey_base()` confirms it already works this way via `setdiff(x@groups, to_remove)` — but there is no test for it in §VI.4. The test plan covers full `ungroup()` in Section 3 but not partial.

Options:
- **[A]** Add to §VI.4 Section 3: "Partial ungroup: `rowwise(d, id_col) |> ungroup(id_col)` → sentinel still present in `@groups`; `mutate()` is still row-wise" — Effort: low, Risk: low, Impact: specifies behavior of a working feature
- **[C] Do nothing** — behavior is untested; a future refactor of ungroup() could silently break it

**Recommendation: A** — the behavior is already correct in code; add the test to lock it in.

---

**Issue 14: Domain preservation missing from `rowwise() |> mutate()` test (§VI.4 Section 2)**
Severity: REQUIRED
Violates testing-surveytidy.md: "Assert domain column present and correct after every verb operation."

§VI.4 Section 2 tests `rowwise(d) |> mutate(row_max = max(c_across(...)))`. The test assertions check row count and design var preservation but not the domain column. If the domain column exists in a filtered design piped through rowwise + mutate, it should survive unchanged.

Options:
- **[A]** Add to §VI.4 Section 2: "Domain column (`SURVEYCORE_DOMAIN_COL`) is present and unchanged in the result" — Effort: low, Risk: low, Impact: aligns with universal domain preservation rule
- **[C] Do nothing** — domain preservation tested implicitly via test_invariants() (which doesn't check domain column); silent regression possible

**Recommendation: A** — one line; consistent with the domain preservation rule applied to every verb.

---

**Issue 15: Cross-design loops not specified for most `rowwise()` test sections**
Severity: REQUIRED
Violates testing-surveytidy.md: "Every verb is tested with all three design types."

§VI.4 Section 1 says "all three designs." Sections 2–6 do not specify which design(s) to use. A reader implementing Section 2 ("rowwise + mutate") would likely only use one design.

Options:
- **[A]** Add "For each design in `make_all_designs(seed = N)`:" to Sections 2, 3, 4, 5, and 6 — Effort: low, Risk: low, Impact: enforces the cross-design coverage rule
- **[C] Do nothing** — sections 2–6 are written for one design; CI does not catch this gap automatically

**Recommendation: A** — same pattern as §VI.2; apply consistently.

---

**Issue 16: `is_rowwise()` predicate recommended in §VIII but not specified**
Severity: REQUIRED
Violates engineering-preferences.md §5 (explicit over clever): a recommended public function has no signature, location, or contract.

§VIII says: "Recommendation: Option A — export `is_rowwise(design)` as a public predicate." But the spec provides nothing else: no signature, no return type, no file location, no test, no `zzz.R` registration, no error-messages.md entry. This recommendation is in the same spec that will be handed to an implementer. If `is_rowwise()` is a Phase 1 concern only, say so explicitly and note that Phase 1 must depend on this Phase's implementation adding it.

Options:
- **[A]** Add a minimal `is_rowwise()` contract: "Signature: `is_rowwise(design)`. Returns: scalar logical. Location: R/rowwise.R. Exported: yes, @export. Test: one test block in test-rowwise.R, Section 1." Add to §VII quality gate. — Effort: low, Risk: low, Impact: complete spec; Phase 1 can depend on it
- **[B]** Mark `is_rowwise()` as Phase 1 scope: "This predicate will be implemented in Phase 1; Phase 0.5 implementation need not include it." — Effort: low, Risk: low, Impact: defers but acknowledges the gap
- **[C] Do nothing** — implementer may or may not ship `is_rowwise()`; Phase 1 spec cannot depend on it

**Recommendation: A** — it's a one-liner predicate; spec it and ship it in this phase since rowwise.R already has all required context.

---

## Section VII — Quality Gates

**Issue 17: `plans/error-messages.md` referenced in quality gate but does not exist**
Severity: REQUIRED
The quality gate at §VII says: "`plans/error-messages.md` updated with `surveytidy_error_rename_fn_bad_output`." CLAUDE.md also states: "`plans/error-messages.md` — surveytidy error/warning classes (update before adding any new class)." However, this file does not exist in the repository (`plans/` contains only domain-estimation-vignette.md and the two spec files).

The quality gate gate cannot be satisfied until the file exists. Furthermore, §IV.5 GAP note says "It must be added to `plans/error-messages.md` before implementation" — but there is no file to add it to.

Options:
- **[A]** Create `plans/error-messages.md` as part of this phase's pre-implementation setup; spec it as a quality gate prerequisite rather than a deliverable — Effort: low, Risk: low, Impact: unblocks the quality gate; establishes the canonical error table
- **[B]** Remove the reference from the quality gate; track error classes in a comments block at the top of each source file — Effort: low, Risk: medium, Impact: loses the centralized error table; diverges from CLAUDE.md instructions
- **[C] Do nothing** — the quality gate is permanently unsatisfiable; the class is added without documentation

**Recommendation: A** — create the file as part of this phase; it's a small stub at minimum.

---

## Section VI — Testing

**Issue 18: `@metadata` assertion in §VI.2 Section 3 is too vague**
Severity: SUGGESTION
"`@metadata` preserved as-is" is not a testable assertion without specifying what is checked.

Options:
- **[A]** Replace with: "`expect_identical(result@metadata, original@metadata)` — full metadata object is unchanged after `distinct()`" — Effort: low, Risk: low, Impact: implementer knows exactly what to assert
- **[C] Do nothing** — implementer writes a vague test; coverage is incomplete

**Recommendation: A** — two words added; eliminates ambiguity.

---

## Section II — Architecture (DRY)

**Issue 19: Sentinel value duplicated in §II.4 and §V.2**
Severity: SUGGESTION
Violates DRY — engineering-preferences.md §1.

The literal string `"..surveytidy_rowwise.."` appears in both §II.4 ("Rowwise Sentinel Constant" definition section) and §V.2 ("Storage: Rowwise Sentinel in @groups"). §V.2 should reference the constant name `ROWWISE_SENTINEL` only, not the raw string. If the string changes, two places must be updated.

Options:
- **[A]** Replace the literal string in §V.2 with `ROWWISE_SENTINEL` (the constant name); note "as defined in §II.4" — Effort: trivial, Risk: none, Impact: one source of truth
- **[C] Do nothing** — two-place update risk if value ever changes; acceptable for a constant

**Recommendation: A** — trivial fix; good hygiene.

---

**Issue 20: Return value visibility not stated for `distinct()` or `rename_with()`**
Severity: SUGGESTION
§V.3 explicitly states `rowwise()` "Returns visibly." §III.2 and §IV.3 output contracts are silent on visibility. All dplyr verbs must return visibly (per surveytidy-conventions.md §5).

Options:
- **[A]** Add "Return value: visibly returned (consistent with all dplyr verbs)" to §III.2 and §IV.3 output contract tables — Effort: trivial, Risk: none, Impact: explicit; no ambiguity
- **[C] Do nothing** — convention covers it; implementer knows

**Recommendation: A** — one row per table; makes the contract explicit and consistent with §V.3.

---

## Section IV — `rename_with()` (continued)

**Issue 21: `.fn` formula/lambda syntax not addressed**
Severity: SUGGESTION
dplyr's `rename_with()` supports `~ toupper(.)` via `rlang::as_function()`. The spec says `.fn` is "A function" — bare function only. Users who use purrr-style lambdas will get an uninformative error.

Options:
- **[A]** Covered by Issue 5 Option A — wrap `.fn` with `rlang::as_function(.fn)` before calling; supports bare functions AND `~` formulas AND `\(x)` lambdas — Effort: low, Risk: low, Impact: consistent with dplyr UX
- **[B]** Explicitly document that formula syntax is not supported — Effort: trivial, Risk: none, Impact: user discovers limitation from docs not from an obscure error
- **[C] Do nothing** — users get `Error in .fn(old_names)` with no guidance

**Recommendation: A** — `rlang::as_function()` is a one-liner; if Issue 5 is resolved with Option A, this is automatically covered. Link to Issue 5.

---

**Issue 22: `.fn` returning non-character output not covered by error contract**
Severity: SUGGESTION
§IV.4 Rule 6 specifies errors for wrong-length output and duplicate names — but not for non-character output. `toupper(c(1, 2, 3))` silently coerces to character in R, but a `.fn` that returns, say, a list or logical vector would not be caught by the length or duplicate check.

Options:
- **[A]** Add to Rule 6: "Also error with `surveytidy_error_rename_fn_bad_output` if `.fn` returns a non-character vector." — Effort: trivial, Risk: low, Impact: explicit validation
- **[C] Do nothing** — non-character output propagates to `names(new_data) <- new_names` which errors with an opaque base R message

**Recommendation: A** — one `is.character(new_names)` check; add it to Rule 6.

---

## Summary (Review Pass 1 — 2026-02-24)

| Severity | Count |
|---|---|
| BLOCKING | 5 |
| REQUIRED | 11 |
| SUGGESTION | 6 |

**Total issues:** 22

**Overall assessment:** The spec has five blocking issues that must be resolved before any implementation begins — two architectural contradictions (sentinel placement, @groups update contract), one unresolved gap that the test plan already depends on (visible_vars behavior for distinct()), a genuinely broken reference implementation in §V.5 (two bugs in the mutate() code block that cause runtime errors), and a missing `...` forwarding rule in rename_with() that makes the contract unimplementable. Eleven required issues cover systematic gaps in the test plan (missing cross-design loops, missing test_invariants() calls, missing domain preservation tests, and an unspecified group_by/.add interaction). Six suggestions are low-effort quality improvements. None of the issues require rethinking the architecture — all can be resolved with targeted edits to the spec.

---

---

# Review Pass 2 — 2026-02-24

> **Stage 3 instructions:** Issues 1–22 above have already been incorporated into the current spec (`plans/spec-dedup-rename-rowwise.md`). **Skip them entirely** — do not re-litigate, re-resolve, or log decisions for any issue numbered 1–22. Start resolution at **Issue 23**.

---

## Section V — `rowwise()` (new issues)

**Issue 23: `rowwise_df` stored in `@data` leaks rowwise semantics to all subsequent operations**
Severity: BLOCKING
Violates engineering-preferences.md §4 (handle more edge cases, not fewer).

The spec's §V.5 replacement code assigns the result of `dplyr::mutate(base_data, ...)` directly to `@data`. When `base_data` is a `rowwise_df` (constructed by `dplyr::rowwise(.data@data, ...)`), the result of `dplyr::mutate(base_data, ...)` is **also** a `rowwise_df`. The spec does not specify stripping this class before assigning to `@data`. Consequence: `@data` becomes a `rowwise_df` permanently. Every subsequent `dplyr::mutate(.data@data, ...)` call anywhere in the package will then behave rowwise, even after `ungroup()` clears `@groups`. This is because `ungroup.survey_base()` only clears `@groups` — it never touches `@data`.

Verified with dplyr 1.2.0: `dplyr::mutate(rowwise_df, ...)` returns a `rowwise_df`, and a second `mutate()` on that result still computes row-by-row. The existing test plan for Section 2 does NOT catch this — it only checks that `row_max` is correct, not that subsequent non-rowwise operations are vectorized. `test_invariants()` also does not catch it because `is.data.frame(rowwise_df)` returns `TRUE`.

The fix requires two additions to §V.5: (1) add `new_data <- dplyr::ungroup(new_data)` after the `dplyr::mutate(base_data, ...)` call in the rowwise branch; (2) add a test in §VI.4 Section 2 that verifies a subsequent non-rowwise `mutate()` after `rowwise() |> mutate() |> ungroup()` produces vectorized (not rowwise) results.

Options:
- **[A]** Add `new_data <- dplyr::ungroup(new_data)` to §V.5 immediately after the `dplyr::mutate(base_data, ...)` call in the rowwise branch; add test to §VI.4 Section 2: "`rowwise(d) |> mutate(row_max = max(c_across(starts_with('y')))) |> ungroup() |> mutate(y_mean = mean(y1))` → `y_mean` is the overall mean (vectorized), not row-by-row" — Effort: low, Risk: low, Impact: prevents silent correctness failure
- **[B]** Strip via `as.data.frame(new_data)` — same semantic effect but loses `tbl_df` class if present — Effort: low, Risk: low, Impact: functionally equivalent but slightly degraded class
- **[C] Do nothing** — every `rowwise() |> mutate()` permanently corrupts `@data` with rowwise semantics; hard to debug

**Recommendation: A** — one-line fix in the spec code block plus one test; without it, the rowwise path is a correctness bug.

---

**Issue 31: `arrange(.by_group = TRUE)` on a rowwise design errors at runtime — unaddressed**
Severity: REQUIRED
Violates engineering-preferences.md §4 (handle more edge cases, not fewer).

The existing `arrange.survey_base()` does:
```r
if (isTRUE(.by_group) && length(.data@groups) > 0L) {
  dplyr::arrange(.data@data, dplyr::across(dplyr::all_of(.data@groups)), ...)
}
```
After `rowwise()`, `@groups = c("..surveytidy_rowwise..")`. The sentinel is not a column in `@data`. Calling `dplyr::all_of("..surveytidy_rowwise..")` inside `across()` will error: `"Element '..surveytidy_rowwise..' doesn't exist."` The spec lists `arrange.R` as unchanged in §II.1 and §VIII, but it IS broken by the rowwise sentinel. §VI.4 Section 5 tests `rowwise(d) |> filter()` and `rowwise(d) |> select()` but NOT `rowwise(d) |> arrange(y1, .by_group = TRUE)`.

The fix: `arrange.survey_base()` must filter out the sentinel before passing groups to `dplyr::all_of()`, using `group_names <- setdiff(.data@groups, ROWWISE_SENTINEL)`.

Options:
- **[A]** Add `arrange.R` to §II.1 as "MODIFIED — strip sentinel from `@groups` before passing to `dplyr::all_of()` in the `.by_group = TRUE` path"; add test to §VI.4 Section 5: "`rowwise(d) |> arrange(y1, .by_group = TRUE)` → completes without error, sentinel preserved in `@groups`" — Effort: low, Risk: low, Impact: prevents runtime error in a common pipeline
- **[B]** Document that `arrange(.by_group = TRUE)` on a rowwise design is undefined behavior — Effort: trivial, Risk: none, Impact: user discovers limitation from docs, not a crash
- **[C] Do nothing** — `arrange(.by_group = TRUE)` on any rowwise design errors at runtime; not caught by the specified tests

**Recommendation: A** — the fix is a one-liner in arrange.R that mirrors the sentinel-stripping pattern already needed in mutate.R; the interaction is a real user workflow.

---

## Section IV — `rename_with()` (new issues)

**Issue 24: §IV.1 "No behavioral change to `rename()`" is false — three changes are introduced by the refactor**
Severity: BLOCKING
Violates engineering-preferences.md §5 (explicit over clever) — a stated contract is incorrect.

§IV.1 states: "No change to observable behaviour." But the refactor changes `rename.survey_base()` to delegate to `.apply_rename_map()`, which introduces three behaviors the current Phase 0.5 `rename.survey_base()` does **not** have:

**Change 1 — `@groups` update (new):** Current `rename.survey_base()` never touches `@groups`. After refactor, `.apply_rename_map()` bullet 2.5 updates `@groups` when a renamed column appears there. This is new behavior for `rename()`.

**Change 2 — Domain column protection (new):** Current `rename.survey_base()` would rename `SURVEYCORE_DOMAIN_COL` if asked (warning, then rename). After refactor, `.apply_rename_map()` bullet 1.5 silently drops the domain column from the rename map and warns — rename is blocked. This is new behavior for `rename()`.

**Change 3 — Warning message text change (snapshot regression):** The current warning is issued in `rename.survey_base()` and says `"! rename() renamed design variable(s)..."`. After refactor, the warning is issued inside `.apply_rename_map()` — a shared helper that is also called by `rename_with()`. The shared helper cannot hardcode `"rename()"`. This changes the warning message text, which will break the existing `_snaps/rename.md` snapshot in CI.

The spec does not acknowledge any of these three behavioral changes, does not provide the new message template for `.apply_rename_map()`, and does not mention that the `rename.md` snapshot must be updated.

Options:
- **[A]** Remove "No behavioral change to `rename()`" from §IV.1; replace with an explicit list of the three behavioral changes and their consequences; specify a new generic warning message template for `.apply_rename_map()` (e.g., `"! Renamed design variable{?s}: {.field {design_cols}}."` — no function name); note that the `rename.md` snapshot must be reviewed and updated after the refactor — Effort: low, Risk: low, Impact: accurate contract; prevents snapshot regression blocking CI
- **[B]** Preserve the "no behavioral change" claim by keeping warnings in each caller — Effort: medium, Risk: medium, Impact: avoids snapshot regression but duplicates warning logic across `rename()` and `rename_with()`
- **[C] Do nothing** — CI fails when the rename.md snapshot breaks; three undocumented behavioral changes surprise the implementer

**Recommendation: A** — document the real contract; the snapshot regression will fail CI if not addressed.

---

**Issue 27: `.apply_rename_map()` warning message template unspecified — shared helper cannot hardcode `"rename()"`**
Severity: REQUIRED
Violates contract completeness — a warning class is required on every `cli_warn()` call (per code-style.md §3) but the message template is entirely absent from the spec.

§II.3 bullet 1 says `.apply_rename_map()` "warns with `surveytidy_warning_rename_design_var`" but provides no message template. The class is defined in `plans/error-messages.md` but without a template, the implementer must invent the text. Any text that omits `"rename()"` will break the existing `_snaps/rename.md` snapshot. This issue is closely related to Issue 24 but is distinct: it is a contract completeness gap in §II.3 specifically, not just a false claim in §IV.1.

Options:
- **[A]** Add a message template to §II.3 bullet 1 that does not name the calling function, e.g.: `cli::cli_warn(c("!" = "Renamed design variable{?s} {.field {design_cols}}.", "i" = "The survey design has been updated to track the new name{?s}."), class = "surveytidy_warning_rename_design_var")` — and note that the `rename.md` snapshot must be updated as part of the `feature/rename-with` branch — Effort: low, Risk: low, Impact: implementer knows exactly what to write; snapshot regression acknowledged
- **[B]** Add a `.fn_name` parameter to `.apply_rename_map()` so callers pass their own function name into the message, preserving the exact current text for `rename()` — Effort: low, Risk: low, Impact: no snapshot regression; more verbose helper signature
- **[C] Do nothing** — implementer invents a message; breaks rename() snapshot; CI fails

**Recommendation: A** — option B creates a leaky abstraction (implementation detail bleeds into shared helper); option A acknowledges the snapshot change is intentional.

---

**Issue 29: §VI.3 error test plan covers only 2 of 4 specified error conditions for `surveytidy_error_rename_fn_bad_output`**
Severity: REQUIRED
Violates testing-standards.md: "every error class gets a test" — all four triggers must be tested.

§IV.4 Rule 6 specifies four conditions that raise `surveytidy_error_rename_fn_bad_output`:
1. `.fn` returns a non-character vector
2. `.fn` returns a vector of the wrong length
3. `.fn` returns duplicate names
4. `.fn` returns names conflicting with existing non-renamed column names

§VI.3 section "rename_with() — error cases (dual pattern)" lists only conditions 2 and 3. Conditions 1 (non-character output) and 4 (conflicting names) have no corresponding test entries. Additionally, the section header says "dual pattern" but does not explicitly list `expect_snapshot(error=TRUE)` alongside `expect_error(class=)`.

Options:
- **[A]** Add two test entries to §VI.3 error section: `.fn` returning a non-character vector (e.g., `\(x) seq_along(x)`) → `surveytidy_error_rename_fn_bad_output`; `.fn` returning a conflicting name (e.g., a `.fn` that returns `"y2"` when `"y2"` already exists as a non-renamed column) → `surveytidy_error_rename_fn_bad_output`; add `expect_snapshot(error=TRUE)` alongside each `expect_error(class=)` in the section description — Effort: low, Risk: low, Impact: all four error conditions verified; snapshot locks in message text
- **[C] Do nothing** — two error conditions remain untested; a regression in the non-character or conflicting-name check would not be caught by CI

**Recommendation: A** — all four triggers are specified in §IV.4 Rule 6; testing-standards.md requires each trigger to be tested.

---

## Section III — `distinct()` (new issues)

**Issue 26: §III.1 "If empty, all non-design columns are used" contradicts the §III.3 internal call**
Severity: REQUIRED
Violates contract completeness — the argument description promises behavior the specified implementation cannot deliver.

§III.1 states: "Columns used to determine uniqueness. If empty, all non-design columns are used." But §III.3 Rule 3 specifies: `dplyr::distinct(.data@data, ..., .keep_all = TRUE)`. With empty `...`, `dplyr::distinct(.data@data, .keep_all = TRUE)` deduplicates on **all** columns in `@data` — including design variables (weights, strata, PSU). The spec makes a promise it cannot keep with the specified implementation. Note that deduplicating on design variables by default has survey-statistical merit (or harm), but either way the description and implementation must match.

Options:
- **[A]** Correct the description to match the implementation: "If empty, all columns in `@data` are used for uniqueness." Accept that design variables may influence deduplication when `...` is empty — Effort: trivial, Risk: low, Impact: accurate description; simpler implementation; still issues warning if design vars produce non-unique rows
- **[B]** Correct the implementation to match the description: when `...` is empty, resolve to non-design columns only and pass them explicitly: `non_design <- setdiff(names(.data@data), .protected_cols(.data)); dplyr::distinct(.data@data, dplyr::across(dplyr::all_of(non_design)), .keep_all = TRUE)` — Effort: low, Risk: low, Impact: survey-safe default; matching the stated promise
- **[C] Do nothing** — description and implementation disagree; implementer picks one; the other is undocumented

**Recommendation: B** — the description reflects sound survey methodology (don't deduplicate by design vars by default); specify the mechanism for the empty-`...` path explicitly in §III.3 Rule 3.

---

## Section II — Architecture (new issues)

**Issue 28: `ROWWISE_SENTINEL` is used in three files but spec §II.4 lists only two**
Severity: REQUIRED
Violates DRY — engineering-preferences.md §5 (explicit over clever).

§II.4 states: "Both `rowwise.R` and `mutate.R` reference it from there." But the spec also requires:
1. `group_by.survey_base()` sentinel-stripping in the `.add = TRUE` path (§V.2): `setdiff(.data@groups, ROWWISE_SENTINEL)`
2. `group_vars.survey_base()` sentinel exclusion (§V.7): `setdiff(x@groups, ROWWISE_SENTINEL)`

Both live in `R/group-by.R`. The sentinel is therefore referenced in **three** files: `rowwise.R`, `mutate.R`, and `group-by.R`. The spec already correctly places `ROWWISE_SENTINEL` in `utils.R`. But the rationale citing only two files could mislead an implementer into thinking `group-by.R` doesn't need to import it.

Options:
- **[A]** Update §II.4: "Referenced by `rowwise.R` (sentinel setting), `mutate.R` (rowwise detection), and `group-by.R` (sentinel stripping in `.add = TRUE` and `group_vars.survey_base()`)." — Effort: trivial, Risk: none, Impact: complete list; prevents subtle omission in group-by.R
- **[C] Do nothing** — sentinel is in utils.R regardless; group-by.R's use is findable by reading §V.2 and §V.7; not a blocker

**Recommendation: A** — one sentence; prevents a subtle omission when implementing the group-by changes.

---

## Section II + VII — Reexports and Accessibility (new issue)

**Issue 25: `R/reexports.R` never mentioned — new dplyr generics inaccessible after `library(surveytidy)` only**
Severity: REQUIRED
Violates the package convention established by all Phase 0.5 verbs.

The spec's §II.1 and §VII quality gates say "`R/zzz.R` updated with `registerS3method()` calls." But `zzz.R` registers S3 methods in the dplyr namespace — it does **not** make the generic functions available to users who haven't loaded dplyr. The existing `R/reexports.R` re-exports all Phase 0.5 dplyr generics (`filter`, `select`, `mutate`, `rename`, `arrange`, `group_by`, `ungroup`, `pull`, `glimpse`, `slice_*`) via `#' @export dplyr::verb` entries. Without the same pattern for new verbs, calling `distinct(d)`, `rename_with(d, toupper)`, `rowwise(d)`, and `group_vars(d)` after `library(surveytidy)` alone will produce `Error: could not find function`.

Options:
- **[A]** Add `R/reexports.R` to §II.1 as "MODIFIED — add `dplyr::distinct`, `dplyr::rename_with`, `dplyr::rowwise`, `dplyr::group_vars` re-exports"; add a re-export checkbox to each per-branch quality gate — Effort: low, Risk: low, Impact: users can call new verbs without `library(dplyr)`
- **[C] Do nothing** — users get confusing function-not-found errors; the package appears to not implement the new verbs

**Recommendation: A** — one line per verb; consistent with the pattern already followed for all Phase 0.5 verbs.

---

## Section VI — Testing (new issues)

**Issue 30: §VI.4 tests reference non-existent column `"id_col"` throughout — all such tests fail at runtime**
Severity: REQUIRED
Violates testing-standards.md: "`@examples` must run during R CMD check" — by analogy, test code must be runnable.

§VI.4 Sections 1, 3, and 4 repeatedly reference `rowwise(d, id_col)`. The test data from `make_all_designs()` has columns: `psu`, `strata`, `fpc`, `wt`, `y1`, `y2`, `y3`, `group` (plus replicate weights for replicate designs). There is no column named `id_col`. Any test calling `rowwise(d, id_col)` will fail immediately with a tidyselect column-not-found error.

Options:
- **[A]** Replace `id_col` with a real column from the test data throughout §VI.4 — `"group"` is the most semantically appropriate (a non-design, non-outcome column). Update all associated expected values (e.g., `c(ROWWISE_SENTINEL, "group")`, `@groups == c("group", "group_col")`) accordingly — Effort: low, Risk: low, Impact: tests are directly runnable
- **[B]** Keep `id_col` as pseudocode and add a note at the start of §VI.4: "`id_col` denotes any non-design column; use `y1` or `group` in actual test code" — Effort: trivial, Risk: low, Impact: less confusing than Option A but still requires implementer interpretation
- **[C] Do nothing** — all tests referencing `id_col` fail immediately when the implementer runs `devtools::test()`

**Recommendation: A** — explicit column names are clearer and directly runnable; use `"group"` throughout.

---

## Section IV — `rename_with()` (continued, new issue)

**Issue 32: §IV.5 GAP note is stale — `plans/error-messages.md` already exists and contains the new class**
Severity: SUGGESTION

§IV.5 contains:
> ⚠️ GAP: `surveytidy_error_rename_fn_bad_output` is a new error class. It must be added to `plans/error-messages.md` before implementation.

`plans/error-messages.md` now exists (created as part of resolving Issue 17 from Review Pass 1) and already contains entries for both `surveytidy_error_rename_fn_bad_output` and `surveytidy_warning_distinct_design_var`. The GAP note was valid before the file was created but was not removed after. An implementer reading this note will waste time checking a file that is already complete.

Options:
- **[A]** Remove the ⚠️ GAP note at §IV.5; the quality gate reference to `plans/error-messages.md` already handles this as a checklist item — Effort: trivial, Risk: none, Impact: cleaner spec
- **[C] Do nothing** — implementer is momentarily confused; checks the file; finds it is already done

**Recommendation: A** — stale notes erode trust in the spec; remove it.

---

## Summary (Review Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 2 |
| REQUIRED | 7 |
| SUGGESTION | 1 |

**Total new issues:** 10 (Issues 23–32)

**Combined totals (all passes):**

| Severity | Pass 1 | Pass 2 | Total |
|---|---|---|---|
| BLOCKING | 5 | 2 | 7 |
| REQUIRED | 11 | 7 | 18 |
| SUGGESTION | 6 | 1 | 7 |
| **Total** | **22** | **10** | **32** |

**Overall assessment (Pass 2):** Two new blocking issues must be resolved before any implementation begins. Issue 23 is a runtime correctness bug introduced by the §V.5 code block — the rowwise path stores a `rowwise_df` in `@data`, permanently corrupting subsequent non-rowwise computations in a way the test plan does not catch. Issue 24 reveals that the "no behavioral change to `rename()`" claim in §IV.1 is false on three counts, with a snapshot regression that will immediately fail CI. The seven required issues are systematic gaps: the reexports.R omission (users can't call new verbs without `library(dplyr)`), test column name errors (all `id_col` references fail), test coverage gaps for 2 of 4 error conditions, an unaddressed `arrange(.by_group=TRUE)` runtime error, a description/implementation mismatch in `distinct()`, and missing warning message template in `.apply_rename_map()`. None require architectural rethinking.
