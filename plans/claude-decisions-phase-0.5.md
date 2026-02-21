# Claude Decisions Log — surveytidy Phase 0.5

This file captures planning questions and decisions made during Phase 0.5
(dplyr/tidyr verbs: filter, select, mutate, rename, arrange, group_by,
and stretch goals tidyr/joins) of the surveytidy package.

A new entry is appended at the end of each planning session, before
implementation begins. See `../survey-standards/.claude/rules/changelog-workflow.md`
for format details.

---

<!-- New entries go below this line -->

## 2026-02-20 — Phase 0.5 full scope planning (select through tidyr)

### Context

Planning the remaining verbs for Phase 0.5: select, mutate, rename, arrange
(including slice-family), group_by, and tidyr stretch goals. filter() is
already complete.

### Questions & Decisions

**Q: Should rename() on design variables error or warn?**
- Options considered:
  - **Error (abort):** Safest; forces the user to use update_design() instead. Prevents accidental design corruption.
  - **Warn + update @variables:** Allows the rename while keeping the design consistent; more flexible for users who know what they're doing.
- **Decision:** Warn + update @variables.
- **Rationale:** Renaming a design variable doesn't make the design invalid if @variables is updated in sync. An error would be unnecessarily restrictive — a user might legitimately rename `wt` to `weight` for clarity. The warning gives visibility without blocking the operation.

**Q: Should error/warning classes use the `surveytidy_` or `surveycore_` prefix?**
- Options considered:
  - **surveytidy_ for new verb errors:** New errors thrown by surveytidy code get `surveytidy_error_*` prefix. Reuses existing `surveycore_*` classes for errors already defined there.
  - **surveycore_ everywhere:** Unified error namespace across both packages.
  - **surveytidy_ for everything surveytidy throws:** Maximum package isolation.
- **Decision:** `surveytidy_` prefix for new errors introduced in surveytidy (e.g., `surveytidy_warning_mutate_design_var`, `surveytidy_warning_rename_design_var`). Reuse `surveycore_*` classes that already exist (e.g., `surveycore_warning_physical_subset`, `surveycore_error_design_var_removed`).
- **Rationale:** Preserves package-level identity while avoiding duplicate class definitions. Users catch `surveycore_warning_physical_subset` regardless of whether it came from subset() or slice().

**Q: `@importFrom` stubs vs `::` everywhere for dynamically-registered dplyr verbs?**
- Options considered:
  - **Stubs in surveytidy-package.R only:** Minimal exception; `::` everywhere in source files.
  - **:: everywhere, accept R CMD check notes:** Strict adherence; notes count against the ≤2 budget.
- **Decision:** `@importFrom` stubs in surveytidy-package.R only.
- **Rationale:** R CMD check cannot detect that verbs are being used via dynamic S3 registration. Without stubs, "object not found" notes would appear. Adding stubs only in the package documentation file is the established pattern for dplyr extension packages, and keeps all source files using `::`.

**Q: Should slice() behave like filter() (domain marking) or subset() (physical removal)?**
- Options considered:
  - **Domain marking (like filter):** Positional slicing marks rows in-domain without removing them.
  - **Physical removal (like subset):** Removes rows, warns the user.
- **Decision:** Physical removal + `surveycore_warning_physical_subset` warning.
- **Rationale:** Positional slicing (`slice(d, 1:50)`) has no statistical meaning for domain estimation — there's no analytical subpopulation defined by "rows 1–50." Unlike filter(), there's no survey-meaningful interpretation of the operation. Physical removal with a warning is the honest behavior.

**Q: How should dplyr_reconstruct() handle mismatched row counts?**
- Options considered:
  - **Drop domain column when rows change:** Safe but silent loss of filter() state.
  - **Error if domain present and rows change:** Loud but restrictive.
  - **No special handling:** Works because all Phase 0.5 verbs preserve row count.
- **Decision:** No special handling needed.
- **Rationale:** Row count changes only occur for (a) slice-family, which we handle by registering explicit methods that do physical removal, and (b) joins, which are out of scope. For all verbs we implement (select, mutate, rename, arrange, group_by), rows are never added or removed, so the domain column is always valid. dplyr_reconstruct() as implemented in 01-filter.R is complete and correct.

**Deferred: join verbs**
- Joining survey objects raises non-trivial statistical questions (how do you combine two designs with different strata?). Deferred to a future phase — not Phase 0.5 or Phase 1.

### Outcome

Phase 0.5 will implement 6 sequential feature branches: select (including pull, glimpse, relocate), mutate, rename, arrange (including slice-family), group_by, and tidyr stretch goals. New warning classes: `surveytidy_warning_mutate_design_var`, `surveytidy_warning_rename_design_var`.

---

## 2026-02-20 — Architecture and test review of Phase 0.5 plan

### Context

Full adversarial review of the implementation plan before any code was written,
covering architecture, code quality, and test coverage. 12 issues identified
and resolved.

### Questions & Decisions

**Q: Should `visible_vars = character(0)` when user selects only design variables?**
- **Decision:** Normalise to `NULL`. `if (length(user_cols) == 0L) NULL else user_cols`.
- **Rationale:** `NULL` is the established sentinel for "show all"; `character(0)` would silently show nothing, which is not what the user intended.

**Q: Should `relocate()` reorder `@data` columns, `visible_vars`, or both?**
- **Decision:** Reorder `visible_vars` when set; reorder `@data` when not set.
- **Rationale:** Produces correct print output in both cases. Reordering `@data` alone when `visible_vars` is active would produce a silent no-op in the display.

**Q: `mutate()` transformation tracking via `names(rlang::exprs(...))` breaks for `across()`.**
- **Decision:** Track only newly-created columns (before/after column name diff). In-place modifications not tracked in Phase 0.5. Complex operations (case_when, across) deferred to a future phase where they can build in their own tracking.
- **Rationale:** The approach is honest about what it tracks, avoids misleading partial tracking, and doesn't over-engineer for Phase 0.5.

**Q: Should `mutate()` warning for design-var modification use `names(exprs(...))` (broken for `across()`) or before/after value comparison?**
- **Decision:** Before/after comparison of design variable values. Fires correctly for all mutation patterns including `across()`.
- **Rationale:** `names(exprs(...))` silently fails for `across()` — the warning would not fire even when it should. Value comparison is the only correct approach.

**Q: Should `select()` physically remove non-design columns from `@data`, or just hide them via `visible_vars`?**
- **Decision:** Physically remove. `select()` removes non-selected non-design columns from `@data`. Design variables always kept. `visible_vars` hides design vars from print.
- **Rationale:** Rows must be preserved for variance estimation; columns do not. Standard dplyr behaviour. Metadata deletion is then honest (tied to actual data removal). `select()` is irreversible within a pipeline. CLAUDE.md updated to reflect this.

**Q: DRY — protected column computation repeated across 5 verb files.**
- **Decision:** Internal `.protected_cols(design)` helper in `R/00-zzz.R`. Single source of truth; all verbs call it.
- **Rationale:** One change point if surveycore ever adds a new protected column type.

**Q: `rename()` updates `visible_vars` using deprecated `dplyr::recode()`.**
- **Decision:** Plain R string replacement loop. No dplyr dependency for this operation.
- **Rationale:** Zero deprecation risk; simpler than any dplyr API that may continue to change.

**Q: Slice-family has 6 nearly identical functions; should they use a factory?**
- **Decision:** Factory function `.make_slice_method(fn_name, dplyr_fn)` generates all 6. Shared `.warn_physical_subset(fn_name)` helper used by slice-family, `subset()`, and `drop_na()`.
- **Rationale:** Eliminates DRY violation; also fixes a likely correctness bug where `{.fn slice}` would appear in `slice_head()`'s warning instead of `{.fn slice_head}`.

**Q: How should `group_by()` validate that grouping variables exist in `@data`?**
- **Decision:** `tidyselect::eval_select()` — same resolution path as `select()`. Tidyselect provides the validation and error message for free; also supports helpers like `starts_with()`.
- **Rationale:** Consistent with dplyr's own `group_by()` internals. No custom validation code to maintain.

**Q: Should warning snapshots be added alongside class checks for new surveytidy_ warning classes?**
- **Decision:** Yes. `expect_snapshot()` alongside every `expect_warning(class=)` for `surveytidy_warning_mutate_design_var` and `surveytidy_warning_rename_design_var`.
- **Rationale:** Required by testing-standards.md dual pattern. Locks in message text.

**Q: Should there be cross-verb pipeline (integration) tests?**
- **Decision:** Yes. Dedicated `tests/testthat/test-pipeline.R` created on `feature/group-by` branch (when all verbs exist). 6 integration tests covering domain survival, visible_vars propagation, @groups survival, and filter chaining.
- **Rationale:** Verb interactions are the most likely source of hidden bugs; unit tests alone do not catch state propagation failures across operations.

**Q: Are there missing edge cases in the `select()` test plan?**
- **Decision:** Added 6 missing tests: negative selection (`-y3`), `everything()`, chained select of removed column, design-var-only select, domain column survival, `pull()` of a design variable.
- **Rationale:** These are all real usage patterns; several would silently produce wrong results without explicit tests.

**Q: Should `arrange()` + domain test check value correctness or just column presence?**
- **Decision:** Value correctness. After `filter() |> arrange()`, verify that domain values stay correctly row-associated with the data they describe.
- **Rationale:** A naive implementation that sorts `@data` rows but forgets the domain column is sorted with them would pass a presence-only test but produce wrong variance estimates.

### Outcome

12 issues resolved. Plan updated, CLAUDE.md updated, decisions logged. Implementation of `feature/select` branch can begin.

---
