# Decisions Log — surveytidy transform

This file records planning decisions made during the transformation functions feature.
Each entry corresponds to one planning session.

---

## 2026-03-13 — Methodology lock: transform

### Context

Three methodology issues were resolved from the Stage 2 pass on `spec-transform.md`
(Issues 1–3). Two were unambiguous fixes; one required a judgment call about scope.

### Questions & Decisions

**Q: How should the spec address the design variable protection gap in `mutate.survey_base()`?**
- Options considered:
  - **Option A — Add a note:** Narrow the adequacy claim in Section X.I to state
    that the weight-column warning is the only protection currently in place. Acknowledge
    strata/PSU/FPC transforms as a known limitation and flag it as a future action item
    for `mutate.R`. No code change in this PR.
  - **Option B — Extend mutate() warnings now:** Open a separate spec for `mutate.R`
    to warn on all design variable column types. Closes the gap but out of scope for
    this feature branch.
  - **Option C — Do nothing:** Leave the spec claim as-is; gap is silently present.
- **Decision:** Option A — add a note to Section X.I.
- **Rationale:** The transform functions are pure vector operations and cannot fix
  `mutate.survey_base()`. The spec should not make an unsupported adequacy claim.
  A note correctly describes the current state and creates an explicit action item
  without expanding the scope of this PR.

### Outcome

Section X.I now states clearly that the existing protection covers weight columns only,
identifies strata/PSU/FPC transforms as a known unwarned gap, and flags it as a future
`mutate.R` enhancement. Spec is at version 0.2.

---

## 2026-03-13 — Stage 4 resolve: spec-review-transform pass 1

### Context

Worked through all 11 issues from the Stage 3 adversarial review. Two blocking
issues (contradictions in `make_factor()` Rule 2 and `make_dicho()` Rule 5),
five required fixes, and four suggestions were resolved.

### Questions & Decisions

**Q: `drop_levels` for factor pass-through — Rule 1 (apply it) vs Rule 2 (ignore it)?**
- **Decision:** Rule 1 is authoritative. `drop_levels` applies to factor pass-through.
- **Rationale:** A factor with empty levels is a real input condition;
  `drop_levels = TRUE` should clean it up. Rule 2's exclusion was written for
  the character path (which builds levels from observations and has no empty-level
  concept), not the factor path.

**Q: Validate `ordered`/`drop_levels`/`na.rm` argument types explicitly?**
- **Decision:** Yes — add `surveytidy_error_make_factor_bad_arg` with `cli_abort`
  for non-`logical(1)` inputs to these args. `.validate_label_args()` handles
  `.label`/`.description`.
- **Rationale:** Consistent with Phase 0.6 recode function behavior. Bad arg types
  should produce surveytidy errors, not base R errors from inside `factor()`.

**Q: Remove `make_dicho()` Rule 5 (2-level short-circuit)?**
- **Decision:** Yes — remove Rule 5 entirely.
- **Rationale:** The normal qualifier-stripping path (Steps 1–6) already handles
  2-level inputs correctly. Rule 5 added special-case logic that contradicted the
  title-casing contract and broke qualifier-stripping for the most common real-world
  input (`c("Strongly Agree", "Strongly Disagree")`). Simpler spec, same behavior.

**Q: `make_factor()` character input level order — alphabetical vs first-appearance?**
- **Decision:** Level order is input-type–specific: numeric/haven_labelled → ordered
  by numeric value (from `attr(x, "labels")`); character → alphabetical; factor
  pass-through → levels preserved.
- **Rationale:** This is already what the spec specifies for numeric input. The
  open question was only about character input; alphabetical is confirmed for that
  case. A "Level Ordering" subsection was added to Section III to make this explicit.

**Q: Inline `.get_labels_attr`/`.get_label_attr` helpers or keep them?**
- **Decision:** Inline — remove both helpers from the Architecture spec.
- **Rationale:** One-character name difference is a realistic typo bug path with no
  compensating benefit. The `exact = TRUE` behavior is self-documenting inline.

### Outcome

All 11 issues resolved. Spec updated with all Stage 4 fixes applied. One new error
class added (`surveytidy_error_make_factor_bad_arg`). New test entries: 3a, 3b, 12b,
44b. Rule 5 removed from `make_dicho()`. Section X.I corrected to reflect existing
structural-var warnings. Spec is ready for `/implementation-workflow`.

---

## 2026-03-16 — Stage 4 resolve: spec-review-transform pass 2

### Context

Worked through 5 issues from the Stage 3 Pass 2 review. Three required fixes and
two suggestions. No blocking issues remained from Pass 1.

### Questions & Decisions

**Q: All-plain-NA input with `drop_levels = TRUE` — warn, document, or leave unspecified?**
- Options considered:
  - **Option A — Document (no warning):** Add a behavior note; this is defined output.
  - **Option B — Add `surveytidy_warning_make_factor_all_na`:** Immediate user feedback.
  - User feedback added a third dimension: haven tagged NAs and special missing values
    (`na_values`/`na_range`) with label entries ARE observations and should become factor
    levels when `na.rm = FALSE`. The "all NA" edge case applies only to plain R NAs.
- **Decision:** Option A, with spec clarification distinguishing plain NAs from haven
  special missing values. Behavior rules 2, 3, 4 expanded to cover this distinction.
- **Rationale:** No new warning class needed. The edge case (all-plain-NA → 0-level
  factor) is defined, predictable behavior. Downstream errors at `make_dicho()` are
  the appropriate failure signal. The spec now correctly describes that `na_values`/
  `na_range` values participate in level building when `na.rm = FALSE`.

**Q: Argument validation for `make_dicho()`, `make_binary()`, `make_rev()`, `make_flip()` — per-function error classes or shared class?**
- **Decision:** Shared class — `surveytidy_error_transform_bad_arg` — for all four
  functions. Argument Validation sections added to all four.
- **Rationale:** Per-function classes add no diagnostic value over a shared class.
  All four functions validate the same two argument types (`.label`/`.description`
  and boolean flags). Shared class keeps the error table compact.

**Q: `force = TRUE` branch — why "return early"?**
- The phrase "return early (skip label-completeness check)" implied an early `return()`
  before `.set_recode_attrs()` is called, violating the Section II guarantee.
- **Decision:** Revised to: "call `.set_recode_attrs(result, ...)`, then return.
  (Skips label-completeness check — `labels_attr` is NULL, so no labels to check.)"

**Q: Integration Test Requirements — test range issue (56–57 as vector pipelines)?**
- **Verification:** In spec v0.3, tests 54–55 are the vector pipeline tests; tests 56–59
  are all `mutate()` integration tests on design objects. The note is CORRECT.
- **Decision:** Close without behavior change. Added clarifying sentence for 54–55.

### Outcome

Spec updated to v0.4. One new error class (`surveytidy_error_transform_bad_arg`).
Behavior rules 2, 3, 4 clarified for plain NA vs. haven special missing values.
Argument Validation sections added to Sections IV–VII. Test entries 26c, 26d, 32c,
32d, 39b, 49b added. Quality Gate error class count updated to 10. Spec is ready
for `/implementation-workflow`.

---

## 2026-03-16 — Plan Review Pass 2: spec v0.4 vs. impl plan v1.0

### Context

Spec v0.4 introduced three discrepancies with the implementation plan:
1. `call` removed from `surveytidy_recode` structure (§II/§XI use 3 fields; §III–VII output
   contracts were not fully updated — stale).
2. `mutate.survey_base()` step 8 update required (§X, §XI) but absent from plan.
3. Single vs. multi-input recode function distinction in §X quality gate not reflected in Tasks 27–30.

### Questions & Decisions

**Q: Should transform functions include `call` in `surveytidy_recode`?**
- Spec §II and §XI both define the structure as `list(fn, var, description)` — 3 fields.
- Spec §X quality gate for recode functions explicitly says "drop `call`".
- Spec §III–VII output contracts still show `list(fn, var, call, description)` — these are stale.
- **Decision:** No `call` field. Follow §II/§XI. The output contracts will be treated as stale
  until the spec is updated.
- **Rationale:** §II is the architecture definition; §XI is the integration contracts section.
  Both are more authoritative than per-function output tables. `call` was never consumed by
  `mutate()` (the `expr` field comes from the quosure, not the attr).

**Q: Where does the `mutate.R` update fit in the task sequence?**
- It must run after the transform functions are implemented and their tests pass (Tasks 1–26),
  but before the recode file updates — the recode updates need to be tested against a
  `mutate.R` that reads the expanded structure.
- **Decision:** Insert as Task 27, before the recode file tasks (renumbered 28–31).

**Q: How to handle single vs. multi-input recode functions in Tasks 28–30?**
- Single-input (`na_if`, `replace_when`, `replace_values`, `recode_values`): `var` set via
  `cur_column()` — these transform one column at a time.
- Multi-input (`case_when`, `if_else`): `var = NULL` — they receive multiple columns; `mutate()`
  derives source columns via quosure `all.vars()` fallback.
- **Decision:** Split into separate tasks (Task 29 for single-input, Task 30 for multi-input).

### Outcome

Implementation plan updated to v1.1:
- `call_expr` capture removed from Notes and all implementation tasks.
- `.set_recode_attrs()` signature updated to `(result, label, labels, fn, var, description)`.
- `R/mutate.R` added to Files; Task 27 added for step 8 update.
- Tasks 28–31 replace old Tasks 27–30: explicit single/multi-input split; no `call` field.
- Acceptance criteria updated: `list(fn, var, description)` noted; mutate step 8 criterion added.
- Changelog path corrected to `changelog/phase-0.6/feature-transformation.md`.
- Task 23 framing corrected.
- Pass 1 Issues 1–5 (recode file scope, `.wrap_labelled()`, DRY, coverage, snapshot regressions)
  remain open — require architectural decisions before plan is fully unblocked.

---
