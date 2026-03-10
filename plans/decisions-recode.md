# Decisions Log — surveytidy recode

This file records planning decisions made during the recode Phase 0.6 feature.
Each entry corresponds to one planning session.

---

## 2026-03-09 — Stage 4 spec resolve: Pass 2 Issues 1–8

### Context

Stage 4 resolve of `spec-review-recode.md` Pass 2. Pass 1 was fully resolved
in prior sessions. This session resolved all 8 new issues (1 BLOCKING, 5
REQUIRED, 2 SUGGESTION) surfaced by the Pass 2 adversarial review.

### Questions & Decisions

**Q: Issue 1 [BLOCKING] — How should `.factor_from_result()` derive factor levels for `case_when()` when RHS formulas may contain function calls (not just literals)?**
- Options considered:
  - **Pre-dplyr extraction (A):** Walk formulas via `rlang::f_rhs()`, extract literal values in order. Requires quosure-walking; cannot handle computed RHS.
  - **Post-dplyr extraction (B):** Call dplyr first, derive levels from `unique(as.character(result))`. Handles computed RHS; drops empty levels.
  - **All-literal-or-fallback (user Option 1):** Detect if all RHS are syntactic literals. If yes → pre-dplyr (formula order, empty levels preserved). If any non-literal → post-dplyr (appearance order, empty levels dropped). Mutually exclusive paths.
  - **Literal-union:** Pre-extract literals for ordering, append post-dplyr computed values. Preserves empty levels for literals only; complex level ordering (literal-first, computed-appended regardless of formula position).
- **Decision:** All-literal-or-fallback (user Option 1).
- **Rationale:** Literal-union has a subtle level-ordering problem — a computed-RHS formula appearing *before* a literal formula ends up with its values sorted *after* literal values. This is hard to explain and will surprise users. All-literal-or-fallback has two clean, mutually exclusive modes. Users who need full level control use `.value_labels`. Detection via `rlang::is_syntactic_literal()` per formula RHS.

**Q: Issue 2 [REQUIRED] — Where does the `.description`-only output path (no label args) get the `surveytidy_recode` attr set?**
- Options considered:
  - **Option A:** Add an explicit step to each function's "else → plain vector" fallback.
  - **Option B:** Consolidate into `.wrap_labelled()` (always sets attr, even when returning `x` unchanged).
- **Decision:** Option A.
- **Rationale:** Keeps `.wrap_labelled()` focused on wrapping labelled outputs. The caller-sets-attr-directly path is already documented in §X.1; it just needed to appear concretely in each function's contract.

**Q: Issue 4 [REQUIRED] — Should the label-merge algorithm be a shared helper or a cross-reference?**
- Options considered:
  - **Option A:** New `.merge_value_labels(base_labels, override_labels)` internal helper in §X.
  - **Option B:** Cross-reference §IX.4 to §V.4 ("same algorithm").
- **Decision:** Option A.
- **Rationale:** Cross-reference documents shared intent but does not direct the implementer to write shared code. A DRY violation in the same file needs a helper, not a comment.

**Q: Issue 6 [REQUIRED] — Should `.description` validation be added to `.validate_label_args()` or a separate helper?**
- Options considered:
  - **Option A:** Extend `.validate_label_args()` with a third `description = NULL` arg.
  - **Option B:** Separate `.validate_description()` helper.
- **Decision:** Option A.
- **Rationale:** The validation condition (`!is.null(x) && !(is.character(x) && length(x) == 1)`) is identical for `.label` and `.description`. One helper with three args is simpler than two helpers with one check each. `na_if()` calls it with `label = NULL, value_labels = NULL, description = .description`.

**Q: Issue 7 [SUGGESTION] — Should `replace_when()` and `replace_values()` inherit variable label from `attr(x, "label")`?**
- Options considered:
  - **Option A:** Add inheritance — when `.label` is NULL, use `attr(x, "label")` as effective label.
  - **Option B:** Document non-inheritance explicitly.
- **Decision:** Option A.
- **Rationale:** All three partial-replacement functions (`na_if`, `replace_when`, `replace_values`) operate on vectors of unchanged type. Consistent inheritance is the least-surprise behavior. Users who want no label can pass `.label = ""` or use `set_var_label()` afterward to clear it.

**Q: Issue 8 [SUGGESTION] — Should `...` in `recode_values()` and `replace_values()` be wired through to dplyr or removed?**
- Options considered:
  - **Option A:** Wire `...` through to the dplyr delegation call.
  - **Option B:** Remove `...` from both signatures.
- **Decision:** Option A.
- **Rationale:** `...` is already in both function signatures and the arg table documents it. Silently dropping it (Option C) is the worst outcome. Wiring through is one-word fixes in both delegation calls and is forward-compatible if dplyr adds args.

### Outcome

All Pass 2 issues resolved. Spec bumped to version 0.6. Key additions: two-path
literal detection in §IV.3, `.merge_value_labels()` helper in §X.4,
`.validate_label_args()` extended to three args, variable label inheritance in
`replace_when()` and `replace_values()`. Ready for `/implementation-workflow`.

---

## 2026-03-09 — Stage 4 spec resolve: Issues 3–8

### Context

Continuation of Stage 4 resolve for `spec-review-recode.md`. Resolved the
remaining 6 issues (3 REQUIRED + 3 SUGGESTION). Issues 1–2 were resolved in
the prior session. Issue 6 was already resolved by the prior session's work.

### Questions & Decisions

**Q: Issue 3 — Where should error test bullets for replace_when(), if_else(), replace_values() go?**
- Options considered:
  - **Option A:** Add bullets to each function's section in §XII.1 (co-located).
  - **Option B:** Consolidate into a shared section at the top of §XII.1.
- **Decision:** Option A.
- **Rationale:** Co-location keeps the test plan readable alongside each function's contract.

**Q: Issue 4 — Should .label/.value_labels validation be extracted to a shared helper?**
- Options considered:
  - **Option A:** Add `.validate_label_args()` to §X; update 5 error tables to reference it.
  - **Option B:** Cross-reference from §XI only (no helper extraction directed).
- **Decision:** Option A.
- **Rationale:** Direct DRY violation — same 2 checks in 5 places in the same file. Extraction is the correct fix.

**Q: Issue 5 — How should recode_values() enforce from = NULL when .use_labels = FALSE?**
- Options considered:
  - **Option A:** Add `surveytidy_error_recode_from_to_missing`; delegate length mismatch to dplyr.
  - **Option B:** Document delegation only, no new error class.
- **Decision:** Option A.
- **Rationale:** Missing-from is the most user-facing failure path; it deserves a surveytidy class for testability. Length mismatch is a dplyr-domain concern.

**Q: Issue 7 — Should .update_labels type validation use a new error class or rlang::check_scalar_bool()?**
- Options considered:
  - **Option A:** New `surveytidy_error_recode_update_labels_not_scalar`.
  - **Option B:** `rlang::check_scalar_bool(.update_labels)` — no new error class.
- **Decision:** Option B.
- **Rationale:** `rlang::check_scalar_bool()` exists for exactly this purpose. No new class needed.

**Q: Issue 8 — Should the surveytidy_recode attr lifecycle invariant be in test_invariants() or per-test?**
- Options considered:
  - **Option A:** Per-test assertion bullet in §XII.1 section 2.
  - **Option B:** Extend `test_invariants()` so it applies automatically.
- **Decision:** Option B.
- **Rationale:** Automatic coverage is stronger — no test author can forget it. Belongs in `test_invariants()` with the other structural invariants.

### Outcome

All 8 spec review issues resolved. Spec is at version 0.5. New error class
`surveytidy_error_recode_from_to_missing` added. New internal helper
`.validate_label_args()` specified in §X.3. `test_invariants()` extension
for `surveytidy_recode` attr specified in §XII.2. Ready for
`/implementation-workflow`.

---

## 2026-03-09 — Stage 4 spec resolve: Issues 1–2 + .description design

### Context

Stage 4 resolve of `spec-review-recode.md`. Working through 8 issues (5
REQUIRED, 3 SUGGESTION) one at a time. This session resolved Issues 1 and 2.
Issue 2 surfaced a new design decision about transformation attribution that
expanded the scope of the fix.

### Questions & Decisions

**Q: Issue 1 — Which implementation correctly describes replace_when()? Three sections said three different things.**
- Options considered:
  - **Option A:** Delegate to `dplyr::replace_when()` directly. Update all three sections (§II.1, §II.2, §V.3) to match.
  - **Option B:** Keep the `dplyr::case_when(.default = x)` workaround and update §II.1 and §II.2 to match.
- **Decision:** Option A.
- **Rationale:** `dplyr::replace_when()` exists in dplyr 1.2.0 and is the natural target. No reason to use the `case_when` workaround when the real function is available.

**Q: Issue 2 — When a column is replaced with a factor via case_when(.factor = TRUE), should old @metadata labels be cleared?**
- Options considered:
  - **Option A:** Fix §IV.3 to say old labels ARE cleared (matching §III.4's Else branch behavior).
  - **Option B:** Change §III.4 to explicitly skip the Else branch for factor columns (retain old labels).
- **Decision:** Option A. Old labels are cleared when a column is replaced with a factor.
- **Rationale:** Old labels described the previous encoding (e.g., numeric codes 1/2/3). After the column becomes a factor, those labels are stale and incorrect. Clearing is the right behavior.

**Q: Issue 2 extension — How should transformation attribution be recorded in @metadata@transformations? Raised because the GAP in §III.2 step 8 needed resolving alongside the factor/post-detection fix.**
- Options considered:
  - **Option A — Deparsed string only:** Store just the R call as a character string.
  - **Option B — Structured list:** Store `list(fn, source_cols, expr, output_type, description)`. Machine-readable; source columns extracted via `all.vars()`.
  - **Option C — Append-per-call log:** Append a new list entry each time the same column is mutated. Preserves full history.
- **Decision:** Option B, extended with a `.description` argument on all 6 recode functions.
- **Rationale:** Option B is the right level of structure for Phase 0.6. The user raised that plain-language descriptions are needed for codebooks and non-R audiences — a `.description = NULL` arg on each function is the correct solution (user-provided; not auto-generated from the expression). Option A is too flat. Option C is over-engineered for now.

**Q: .description design — Should it live on the recode functions or on mutate()?**
- **Decision:** On the recode functions (e.g., `case_when(..., .description = "Age category: young (<30), ...")`).
- **Rationale:** Scoped per-column; matches where `.label` and `.value_labels` already live.

**Q: .description design — Should a warning fire when .description is omitted?**
- **Decision:** No. `.description` is optional with `NULL` default. No warning when omitted.
- **Rationale:** Warning on every recode call would be noisy for non-codebook workflows.

**Q: .description design — What is stored when .description is NULL?**
- **Decision:** `description = NULL` in the transformation record. Codebook output simply omits the field.
- **Rationale:** A minimal auto-generated fallback (e.g., "Created using case_when()") adds noise without useful information.

**Q: surveytidy_recode attr — Should it remain `TRUE` or become a list to carry description?**
- **Decision:** Change from `attr(...) <- TRUE` to `attr(...) <- list(description = .description)`.
- **Rationale:** Allows `description` to flow from the recode function through `.extract_labelled_outputs()` to `mutate.survey_base()`'s transformation record without a separate side channel. Clean single-attr approach.

**Q: When is the surveytidy_recode attr set? (backward compatibility boundary)**
- **Decision:** Set only when at least one surveytidy arg is used (`.label`, `.value_labels`, `.description` non-NULL, or `.factor = TRUE`). When no surveytidy args are used, output is identical to dplyr (no extra attrs).
- **Rationale:** Preserves the §XII section 10 backward-compatibility guarantee.

### Outcome

Issues 1 and 2 resolved. Spec is at version 0.4. Remaining open issues: 3, 4,
5, 6, 7, 8. Next session continues Stage 4 from Issue 3.

---

## 2026-03-09 — Stage 4 spec resolve: Pass 3 Issues 1–7

### Context

Stage 4 resolve of `spec-review-recode.md` Pass 3. All Pass 1 and Pass 2 issues were
previously resolved. This session resolved all 7 new issues (2 REQUIRED, 5 SUGGESTION).

### Questions & Decisions

**Q: Issue 1 [REQUIRED] — `.factor = TRUE` + `.default` non-NULL silently converts `.default` rows to NA in the all-literal path. Fix with one-line append or error?**
- Options considered:
  - **Option A:** Append `.default` to `formula_values` in the all-literal path when non-NULL and `!is.na(.default)`.
  - **Option B:** Error when `.default` + `.factor = TRUE` + no `.value_labels`.
- **Decision:** Option A.
- **Rationale:** Appending `.default` is one line and produces the intuitive result. Option B forces unnecessary user burden for a very common pattern (`case_when(cond ~ val, .default = "other", .factor = TRUE)`).

**Q: Issue 2 [REQUIRED] — Should the structural-var warning test section cover both structural and weight warnings?**
- Options considered:
  - **Option A:** Full section covering strata/PSU/FPC/repweights + weight-col confirmation, all 3 design types.
  - **Option B:** New section covers structural vars only.
- **Decision:** Option A.
- **Rationale:** Testing both warning types together verifies the step 1 extension didn't break the existing weight-col warning path.

**Q: Issue 5 [SUGGESTION] — Add "All 3 design types" per section or via a preamble?**
- Options considered:
  - **Option A:** Add bullet to sections 1 and 2 individually.
  - **Option B:** Preamble statement covering all sections.
- **Decision:** Option A (user's choice).
- **Rationale:** Uniform per-section pattern is already established in sections 3–9.

### Outcome

All 7 Pass 3 issues resolved. Spec bumped to version 0.7. Key changes: all-literal
path appends `.default` to `formula_values` (§IV.3), structural-var warning test
section added (§XII.1 section 2b), §II.2 clarifies delegation complexity,
domain-preservation tests now specify `filter()` setup, type-stable notes added
to §V and §IX, intentional `.unmatched` asymmetry documented in §IV.4. The spec
is now fully reviewed and ready for `/implementation-workflow`.

---

## 2026-03-09 — Implementation workflow Stage 3: plan-review-recode.md resolve

### Context

Stage 3 resolve of `plan-review-recode.md` (11 issues: 1 BLOCKING, 6 REQUIRED,
4 SUGGESTION). All issues resolved in this session.

### Questions & Decisions

**Q: Issue 1 [BLOCKING] — How to fix the TDD ordering problem where test_invariants() extension in STEP 2 makes all STEP 5 tests fail?**
- Options considered:
  - **Option A:** Move test_invariants() extension to Task 6.8 (after strip step is wired). STEP 5 uses unmodified test_invariants().
  - **Option B:** In STEP 5, test recode functions directly on vectors (not through mutate()); only STEP 6–7 test through mutate().
- **Decision:** Option A.
- **Rationale:** Minimal change that restores valid TDD ordering. STEP 5 tests still go through mutate() — which is the correct integration surface — they just defer the recode-attr invariant check to after the strip step exists.

**Q: Issue 7 [REQUIRED] — Should domain column mutation silently lose its warning after Task 6.2, or should a third check be added?**
- Options considered:
  - **Option A:** Add a third intersect check for `SURVEYCORE_DOMAIN_COL` and emit `surveytidy_warning_mutate_structural_var`.
  - **Option B:** Accept the regression with a code comment; document the intentional gap.
- **Decision:** Option B.
- **Rationale:** The domain column name (`"..surveycore_domain.."`) is intentionally obscure — no realistic user writes it in a mutate() call. Adding a check adds a test path for something extremely unlikely. The gap is documented in Task 6.2.

**Q: Issue 10 [SUGGESTION] — Should skeleton test blocks be added for all 5 non-case_when functions to match case_when()'s level of prescription?**
- **Decision:** No (accept inconsistency).
- **Rationale:** Spec §XII.1 provides a clear bullet list per section. Narrative test requirements are acceptable given spec coverage. Adding full code for all 5 functions is high effort with marginal value.

**Q: Issue 11 [SUGGESTION] — Should a note be added to Task 4 flagging the spec §I.1 vs §X discrepancy (2 helpers listed vs 4 specified)?**
- **Decision:** No (accept as-is).
- **Rationale:** Any implementer who reads §X (which they must) sees all 4 helpers. The discrepancy in §I.1 is in the approved spec and cannot be changed here.

### Outcome

All 11 plan-review issues resolved. Key plan changes: STEP 2 deferred to Task
6.8; test-mutate.R added to Files list; Task 6.2b added for snapshot review;
coverage criterion added to acceptance criteria; missing unmatched-values
snapshot added to section 12; section 11 expanded to cover all 6 functions;
domain column regression documented; Task 6.5 replaced with SUPERSEDED stub;
interaction edge case (.use_labels + .factor) added to Task 5.8.

---

## 2026-03-09 — Methodology lock: recode

### Context

7 methodology issues were resolved in this session (Stage 2 Resolve). 4 were
unambiguous fixes; 3 were judgment calls. The key questions were about the
pre-attachment architecture, stale metadata handling, and error class routing
for `recode_values()`.

### Questions & Decisions

**Q: Issue 2 — Should pre-attachment use `attr<-` only (no class change) or `haven::labelled()` (full haven_labelled class)?**
- Options considered:
  - **Option A — attr-only:** Use `attr<-` for `"labels"` and `"label"`. Columns inside `mutate()` gain attrs but NOT the `"haven_labelled"` class. Recode functions detect pre-attached labels via `attr(x, "labels")`, not `inherits()`. Simpler; avoids unexpected S3 dispatch in third-party code.
  - **Option B — haven::labelled():** Create proper `haven_labelled` objects during pre-attachment. Cleaner semantics but risks dispatch surprises.
- **Decision:** Option A (attr-only). Additionally: `.wrap_labelled()` sets `attr(result, "surveytidy_recode") <- TRUE` on recode function outputs, and post-detection gates on this flag rather than `inherits(haven_labelled)`. Also expanded `@metadata@transformations` to log recode function calls (GAP added: confirm surveycore structure).
- **Rationale:** attr-only is simpler and consistent with how `§V.4` and `§VII.3` already detect labels via `attr()`. The `surveytidy_recode` flag makes post-detection more precise — only surveytidy recode function outputs update `@metadata`, not incidental `haven_labelled` objects from third-party code inside `mutate()`.

**Q: Issue 3 — Should recoding structural design variables (strata, PSU, FPC, repweights) via mutate() trigger a warning?**
- Options considered:
  - **Option A:** Generalize to one warning class `surveytidy_warning_mutate_design_var` for all design variables (weights + structural).
  - **Option B:** Separate class `surveytidy_warning_mutate_structural_var` for structural variables, distinct from the existing weight warning. More alarming message.
  - **Option C:** Defer to a later phase; document as known gap.
- **Decision:** Option B. New class `surveytidy_warning_mutate_structural_var` for strata, PSU, FPC, repweights. Kept separate from `surveytidy_warning_mutate_weight_col`.
- **Rationale:** Phase 0.6 introduces recode functions that make structural variable modification dramatically easier. Not extending warnings at the same time is a missed opportunity. Differentiating weight vs. structural modification is the methodologically correct distinction — structural recoding can invalidate the probability model entirely, not just effective sample size.

**Q: Issue 4 — When a labelled column is overwritten with non-labelled output, should @metadata retain the old labels (stale) or be cleared?**
- Options considered:
  - **Option A (current spec):** Retain old metadata. User must manually clear labels with `set_val_labels(d, col, NULL)`.
  - **Option B:** Clear `@metadata@variable_labels[[col]]` and `@metadata@value_labels[[col]]` for any column in `changed_cols` when output is not tagged `surveytidy_recode`.
  - **Option C:** Issue a warning when a labelled column is overwritten with non-labelled output.
- **Decision:** Option B. Explicit overwrite of a column clears its old labels.
- **Rationale:** The user wrote `col = recode_values(...)`, explicitly replacing the column. Retaining pre-existing labels for a structurally different column is confusing and produces wrong output in downstream label-reading. Users who want to preserve labels have the `.label` / `.value_labels` args for that purpose.

**Q: Issue 6 — `recode_values()` tryCatch catches all errors; how to avoid misclassifying type-mismatch errors as unmatched-values errors?**
- Options considered:
  - **Option A:** Inspect dplyr's condition class; gate reclassification on `inherits(e, "dplyr_error_recode_unmatched")`. Re-throw all other errors via `stop(e)`.
  - **Option B:** Remove tryCatch entirely; accept dplyr's own error class.
  - **Option C:** Use `grepl()` on `conditionMessage(e)` as a heuristic guard.
- **Decision:** Option A. Gate on the specific dplyr condition class. Added GAP note to §VIII.3 and §XIII to verify the exact class name from dplyr 1.2.0 source before implementing.
- **Rationale:** Correct error class routing is non-negotiable for testability. The grepl heuristic is fragile. Option B loses the `surveytidy_error_recode_unmatched_values` class entirely. Option A is correct; the only cost is verifying the dplyr class name.

### Outcome

Spec is now at version 0.3 and is methodology-locked. Two implementation GAPs
added to §XIII Quality Gates: (1) confirm `@metadata@transformations` structure
in surveycore 0.0.0.9000, (2) confirm dplyr's unmatched-values error condition
class in dplyr 1.2.0 source.

---
