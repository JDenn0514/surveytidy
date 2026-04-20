# Claude Decisions Log — surveytidy Transformation Functions

This file records planning decisions made during implementation of the
Transformation Functions feature (`feature/transformation`).

---

## 2026-03-16 — Stage 3 issue resolution (impl-transformation.md)

### Context

Worked through all 10 open issues from plan-review-transformation.md (Pass 1
and Pass 2). Issues 8, 9, and 10 were already resolved in the plan before this
session; the remaining 7 required plan edits.

### Questions & Decisions

**Q: Issue 1 — Should the recode structural update be limited to 2 files or cover all 7?**
- Options considered:
  - **Option A:** List all 7 files explicitly (case-when.R, replace-when.R, if-else.R, na-if.R, recode-values.R, replace-values.R, utils.R)
  - **Option B:** Move recode structural update to a follow-on PR
- **Decision:** Option A — list all 7 files
- **Rationale:** The update is mechanical and consistent across files; a follow-on PR would leave 6 of 7 files with stale structure and silently fail the quality gate.

**Q: Issue 2 — How should the `.wrap_labelled()` code path be handled for the recode attr update?**
- Options considered:
  - **Option A:** Update `.wrap_labelled()` signature to accept `fn` and `var`; update all 6 callers
  - **Option B:** Document that `.wrap_labelled()` path retains `list(description=)` only
- **Decision:** Option A — update signature
- **Rationale:** `.wrap_labelled()` is a shared helper; all code paths should emit a consistent structure. A partial update would leave the helper emitting a different structure from every direct attr-setting site.

**Q: Issue 3 — Should argument validation be inline (5 copies) or a shared helper?**
- Options considered:
  - **Option A:** Add `.validate_transform_args(label, description, error_class)` at top of transform.R
  - **Option B:** Parameterize existing `.validate_label_args()` in utils.R
- **Decision:** Option A — new helper in transform.R
- **Rationale:** Keeps the helper co-located with its callers; avoids touching the shared utils.R helper. One definition, 5 call sites; error class passes as an argument so make_factor() uses its own class and the other four share `surveytidy_error_transform_bad_arg`.

**Q: Issue 6 — Should the changelog live under `phase-0.6/` or a new `phase-transformation/` subdirectory?**
- Options considered:
  - **Option A:** `changelog/phase-0.6/feature-transformation.md`
  - **Option B:** `changelog/phase-transformation/feature-transformation.md` (new subdirectory)
- **Decision:** Option B — new subdirectory
- **Rationale:** User preference; transformation functions are distinct enough from the Phase 0.6 recode functions to warrant their own changelog directory.

### Outcome

`plans/impl-transformation.md` updated with: definitive 7-file recode list,
`.wrap_labelled()` signature task (Task 28a), `.validate_transform_args()` helper
pattern, expanded coverage/test-passing acceptance criteria, correct changelog path,
and rephrased Task 23. Plan approved for implementation.

---
