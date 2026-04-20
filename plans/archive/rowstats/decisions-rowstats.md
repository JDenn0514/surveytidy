# Decisions Log — surveytidy rowstats

This file records planning decisions made during rowstats.
Each entry corresponds to one planning session.

---

## 2026-04-15 — Methodology lock: row_means() / row_sums()

### Context

Stage 2 methodology review found two issues: one REQUIRED judgment call about
how to handle design variable columns appearing in `.cols`, and one SUGGESTION
(unambiguous) about documenting the full `@data` resolution context. Both were
resolved in this session.

### Questions & Decisions

**Q: When `.cols` resolves to columns that include design variables (weights, FPC, strata codes, PSU IDs), what should happen?**
- Options considered:
  - **Warn (`surveytidy_warning_rowstats_includes_design_var`):** Intersect `source_cols` with `surveycore::.get_design_vars_flat(x)` after `mutate.survey_base()` captures the `surveytidy_recode` attr. Emit a named warning listing offending columns. Computation proceeds. Consistent with `mutate.survey_base()`'s existing pattern of warning (not erroring) when design variables are involved.
  - **Error (`surveytidy_error_rowstats_includes_design_var`):** Hard stop. Overly restrictive — no design variable is being modified, only read. Rare legitimate use cases would be blocked.
  - **Document only:** Add a `@section` note in roxygen but take no action. Silent wrong behavior, insufficient given how easily `where(is.numeric)` triggers this.
- **Decision:** Warn.
- **Rationale:** Consistent with the existing `mutate.survey_base()` pattern of warning on design variable involvement. A warning surfaces accidental inclusion (the common case) while allowing intentional inclusion to proceed. The check is placed in `mutate.survey_base()` (not inside `row_means()`/`row_sums()` directly) because only `mutate.survey_base()` has access to the survey object's design variable registry via `surveycore::.get_design_vars_flat(x)`.

### Outcome

Spec v0.2 adds Behavior Rule 8 (design variable check), `surveytidy_warning_rowstats_includes_design_var` to the Warning tables in §III and §IV, test cases #21–23 in §VII, an updated §IX integration contract noting that `mutate.R` requires a small addition, and a documentation note in Behavior Rule 1 about the full `@data` resolution context.

---

## 2026-04-15 — Stage 4 resolve: GAPs + spec-review issues

### Context

Stage 4 resolved 8 issues from the Stage 3 spec review (4 REQUIRED, 4
SUGGESTION) and all 5 open GAPs (GAP-1 through GAP-5). All decisions below
were made interactively with the user.

### Questions & Decisions

**Q (Issue 1): How is `na.rm` validated relative to `.validate_transform_args()`?**
- Options considered:
  - **Inline before shared helper:** `row_means()` / `row_sums()` validate `na.rm` with a direct `cli_abort()` call, then call `.validate_transform_args()` for `.label` and `.description`. Matches `make_rev()` / `make_flip()` pattern.
  - **Extend `.validate_transform_args()`:** Add optional `na.rm` param to the shared helper. More DRY but touches 8+ existing call sites.
- **Decision:** Inline validation before `.validate_transform_args()`.
- **Rationale:** Matches established pattern; zero risk to existing call sites.

**Q (GAP-1): Move `.set_recode_attrs()` to `R/utils.R` or duplicate inline?**
- Options considered:
  - **Move to `utils.R`:** Satisfies the code-style.md 2+ source files rule (3 files total: `transform.R`, `rowstats.R`, and `utils.R` itself).
  - **Duplicate inline:** 4-line duplication; acceptable by size but breaks the project rule.
- **Decision:** Move to `R/utils.R`.
- **Rationale:** Rule is explicit; pure code move with no behavioral change.

**Q (GAP-2): Pre-validate non-numeric columns in `row_means()` / `row_sums()`?**
- Options considered:
  - **Pre-validate:** Check `is.numeric()` per column after `dplyr::pick()`. Throw a typed error naming offending columns.
  - **Let `rowMeans()` / `rowSums()` error propagate:** Generic base R message; poor UX.
- **Decision:** Pre-validate. Error classes: `surveytidy_error_row_means_non_numeric`, `surveytidy_error_row_sums_non_numeric`.
- **Rationale:** Better UX; engineering-preferences.md §4 (handle edge cases).

**Q (GAP-3 / GAP-5): Error on zero columns for both functions?**
- Options considered:
  - **Error for both:** Consistent behavior at the boundary. `row_sums()` would otherwise silently return 0 (worse than `row_means()` returning NaN with a warning).
  - **Error only for `row_means()`:** Asymmetric; mirrors base R asymmetry but confuses users.
  - **Let base R behavior propagate for both:** No pre-check; confusing outputs.
- **Decision:** Error for both. Classes: `surveytidy_error_row_means_zero_cols`, `surveytidy_error_row_sums_zero_cols`.
- **Rationale:** Consistent API surface; engineering-preferences.md §4.

### Outcome

Spec v0.3: All GAPs resolved, all 8 spec-review issues fixed. Four new error
classes and one new warning class added to both `spec-rowstats.md` and
`plans/error-messages.md`. Test plan expanded to 28 tests. Spec is fully
implementable — ready for `/implementation-workflow`.

---

## 2026-04-15 — Stage 3 resolve: implementation plan review

### Context

Stage 3 worked through 5 issues from `plans/plan-review-rowstats.md`
(2 REQUIRED, 3 SUGGESTION). All were resolved in this session.

### Questions & Decisions

**Q (Issue 5): Should test 16 (row_sums metadata) be split into separate blocks to match the row_means() pattern?**
- Options considered:
  - **Split into 16a/16b/16c:** Three blocks for `.label`, `.label = NULL` fallback, and `.description`/`source_cols`. Matches row_means() tests 5–8 pattern. Total count: 30.
  - **Keep as one block with asymmetry comment:** Stays at 28 tests; still violates one-behavior rule.
  - **Do nothing:** Follow spec's 28-test count.
- **Decision:** Split into 16a/16b/16c (30 total tests).
- **Rationale:** `testing-standards.md` §1 — one observable behavior per `test_that()` block. Row_means() metadata tests set the correct pattern; row_sums() should mirror it for debuggability.

### Outcome

Implementation plan approved. 5 fixes applied: (1) PR 1 acceptance criteria adds "Changelog entry"; (2) Task 1.1 step 2 addresses the `# internal helpers` section comment; (3) `air format` criterion covers both `R/rowstats.R` and `R/mutate.R`; (4) Task 2.2/2.5 use accurate ERROR/snapshot language; (5) test 16 split into 16a/16b/16c, total 30 tests.

---
