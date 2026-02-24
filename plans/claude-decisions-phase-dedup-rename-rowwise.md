# Claude Decisions Log — surveytidy dedup/rename_with/rowwise phase

This file records planning decisions made during spec review and resolution.

---

## 2026-02-24 — Implementation plan review resolution (7 issues)

### Context

Worked through 7 issues from the adversarial review of
`plans/implementation-plan-dedup-rename-rowwise.md`. All 4 REQUIRED issues
and all 3 SUGGESTION issues resolved. One non-obvious user decision was made.

### Questions & Decisions

**Q: What should the per-PR line coverage criterion say?**
- Options considered:
  - **95% floor only:** Match the CI enforcement threshold exactly
  - **Tiered language:** Reflect a hierarchy of aspiration vs. minimum
- **Decision:** Tiered language: aim for 100%, 98% is the target, 95% is the
  bare minimum (CI enforced). Applied to all three PRs' acceptance criteria.
- **Rationale:** User preference stated explicitly. Sets the right expectation
  that 95% is a floor, not a goal.

**Other decisions (all accepted recommended option A):**
- Issue 1: Header false merge-ordering claim removed; PRs correctly described
  as independent with Sequencing section as authority.
- Issue 2: `surveytidy_warning_distinct_design_var` criterion updated to use
  `expect_warning(class=)` — the dual pattern (error + snapshot) does not
  apply to warnings.
- Issue 3: PR 2 acceptance criteria now explicitly require `rename()` AND
  `rename_with()` each tested separately for `@groups` staleness behavior.
- Issue 4: PR 3 Notes pseudocode now includes explicit `if (is_rowwise)` guard
  around `dplyr::ungroup()` call so the conditional is unambiguous.
- Issue 5: Sequencing section now notes rebase requirement for PRs 2 and 3
  before merge (all three PRs share `R/reexports.R` and `R/zzz.R`).
- Issue 7: PR 3 file list now explicitly marks `test-group-by.R` as NOT
  modified, explaining that rowwise group_by/ungroup behaviors go in
  `test-rowwise.R` per spec §VI.4.

### Outcome

Implementation plan approved. Three feature branches ready to implement:
`feature/distinct`, `feature/rename-with`, `feature/rowwise`.

---

## 2026-02-24 — Spec review resolution: Review Pass 2 (Issues 23–32)

### Context

Worked through 10 new issues from adversarial Review Pass 2. One major
architectural decision was made; all other issues resolved with recommended
options.

### Questions & Decisions

**Q: How should rowwise mode be stored — sentinel string in `@groups` (existing spec) or `@variables$rowwise` (attribute approach)?**
- Options considered:
  - **Sentinel in `@groups` (original spec):** Push `"..surveytidy_rowwise.."` as the first element of `@groups`. Simple to implement initially; requires `setdiff()` to strip the sentinel wherever `@groups` is read.
  - **`@variables$rowwise` attribute (proposed):** Store `@variables$rowwise = TRUE` and `@variables$rowwise_id_cols = character(0)` in the free-form `@variables` list. `@groups` remains clean — only real column names. Same pattern as `visible_vars` and `domain`. No surveycore changes required.
- **Decision:** Use `@variables$rowwise`. Eliminates Issues 28 (3-file sentinel reference), 31 (`arrange(.by_group=TRUE)` crash), and simplifies `is_grouped()`, `group_vars()`, and `arrange()` by removing all sentinel-stripping logic. Also simplifies `group_by(.add=TRUE)` logic (explicit id_col promotion rather than implicit sentinel-aware setdiff).
- **Rationale:** Cleaner architecture with fewer special cases. User experience is identical to dplyr::rowwise(). The old sentinel approach caused cascading complexity across 4+ files; the attribute approach contains rowwise state in one place (`@variables`). Verdict: the attribute approach is simpler under the hood AND eliminates multiple review issues.

**Q: With `@variables$rowwise`, what does `rowwise(d, id_col) |> group_by(region, .add=TRUE)` produce?**
- Decision: id cols in `@variables$rowwise_id_cols` are promoted to `@groups` first (matching dplyr's behavior), then new groups appended. `@variables$rowwise` and `@variables$rowwise_id_cols` are cleared.
- Rationale: mirrors dplyr exactly, same as the prior session's decision for the sentinel approach.

### Outcome

Spec updated. Architectural change affects: §II.1, §II.4, §V.2, §V.3, §V.4, §V.5, §V.7, §VI.4, §VII, §VIII. Also resolved: Issue 24 (documented three behavioral changes to rename()), Issue 25 (reexports.R added to spec), Issue 26 (distinct() empty-... default now uses non-design cols), Issue 27 (warning message template added to §II.3), Issue 29 (all 4 rename_with() error conditions now in test plan), Issue 32 (stale GAP note removed). Issue 30 (id_col → "group" in test plan) incorporated directly into §VI.4 during architecture update.

---

## 2026-02-24 — Spec review resolution: distinct, rename_with, rowwise

### Context

Worked through 22 issues from the adversarial spec review of
`plans/spec-dedup-rename-rowwise.md`. All blocking and required issues
resolved; all suggestions accepted. Two non-obvious decisions were made
that are not fully self-evident from the spec edits alone.

### Questions & Decisions

**Q: How should `group_by(.add = TRUE)` behave when the design is in rowwise mode?**
- Options considered:
  - **Option A (original review rec):** Clear the sentinel, then add the new groups (discards id cols)
  - **Mirror dplyr exactly:** Strip the sentinel but preserve rowwise id columns as regular group keys, then append new groups — matching dplyr's `group_by.data.frame` behavior on `rowwise_df` objects
- **Decision:** Mirror dplyr exactly. Verified by running dplyr: `rowwise(df, id) |> group_by(region, .add = TRUE)` produces groups `c("id", "region")` — the rowwise class is dropped but id cols survive as regular groups.
- **Rationale:** surveytidy mirrors dplyr UX wherever possible; users who know dplyr will expect this behavior. Implementation: `base_groups <- setdiff(.data@groups, ROWWISE_SENTINEL); unique(c(base_groups, group_names))`.

**Q: Should `is_rowwise()` be the only exported predicate, or also add `is_grouped()` and `group_vars()`?**
- Options considered:
  - **`is_rowwise()` only:** Minimal; Phase 1 can check `@groups` directly
  - **`is_rowwise()` + `is_grouped()` + `group_vars.survey_base()`:** Full predicate surface; Phase 1 never needs to know about `ROWWISE_SENTINEL` or access `@groups` directly
- **Decision:** Add all three. `is_grouped()` encapsulates the sentinel-stripping logic (`length(setdiff(@groups, ROWWISE_SENTINEL)) > 0`). `group_vars.survey_base()` is a dplyr generic that returns real group column names excluding the sentinel — this is what Phase 1 estimation functions will actually need.
- **Rationale:** `@groups` is nominally public API but Phase 1 reading it directly would silently break if the sentinel convention ever changes. Three one-liner functions fully insulate Phase 1 from the sentinel implementation detail.

### Outcome

Spec approved. Three feature branches to implement:
- `feature/distinct` — `distinct.survey_base()` with design-var warning
- `feature/rename-with` — `.apply_rename_map()` refactor + `rename_with.survey_base()`
- `feature/rowwise` — `rowwise.survey_base()` + mutate() changes + three predicates + `group_by()` `.add=TRUE` fix

---
