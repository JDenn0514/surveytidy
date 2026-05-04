# Decisions Log — surveytidy joins

This file records planning decisions made during feature/joins.
Each entry corresponds to one planning session.

---

## 2026-04-16 — Methodology lock: joins

### Context

Stage 2 methodology review identified 10 issues (2 blocking, 6 required, 2
suggestion). 7 were unambiguous fixes applied directly to the spec. 3
required judgment calls, resolved in this session.

### Questions & Decisions

**Q: GAP-1 — How should `inner_join` handle unmatched rows?**
- Options considered:
  - **Option A (physical subset + warning):** Unmatched rows physically
    removed; emits `surveycore_warning_physical_subset`. Low effort. Matches
    base R intuition (fewer rows). Risk: compromises variance estimation if
    used carelessly.
  - **Option B (domain-aware by default):** Implement as `semi_join + left_join`
    internally; unmatched rows marked `FALSE` in the domain column; all rows
    remain in `@data`. Medium effort. Survey-correct default. Matches
    `filter()` and `semi_join()` precedents.
  - **User-requested refinement:** Two-mode design: default domain-aware,
    physical mode opt-in via `.domain_aware = FALSE`.
- **Decision:** Two-mode design with `.domain_aware = TRUE` (default, domain-aware)
  and `.domain_aware = FALSE` (physical subset + warning). GAP-1 closed.
- **Rationale:** The surveytidy philosophy is that verbs do not silently
  invalidate variance estimation. Making domain-aware the default is
  survey-correct. The `.domain_aware = FALSE` escape hatch lets users who
  explicitly want physical subsetting opt in without being blocked. The
  `nrow()` surprise of the default mode is consistent with `filter()` and
  `semi_join()` precedents already established in surveytidy.

**Q: GAP-2 — Should `left_join` row expansion (duplicate keys in `y`) error or warn?**
- Options considered:
  - **Error:** Halt with `surveytidy_error_join_row_expansion`. User must
    deduplicate `y` before joining. Prevents silent phantom row creation.
  - **Warn + allow:** Return the expanded object. The resulting survey has
    more rows than respondents, invalidating the probability model silently.
- **Decision:** Error. GAP-2 closed.
- **Rationale:** A phantom duplicate row in a survey means the same respondent
  appears multiple times, corrupting variance estimation regardless of user
  intent. There is no legitimate use case for an expanded survey object with
  duplicate respondent rows.

**Q: GAP-5 — Should `@variables$domain` be updated after `semi_join`/`anti_join`?**
- Options considered:
  - **Option A (leave unchanged):** `@variables$domain` reflects only prior
    `filter()` quosures. Risk: Phase 1 could silently miss join-based domain
    restrictions if it reads the quosure list.
  - **Option B (structured sentinel):** Append
    `list(type = "semi_join"|"anti_join"|"inner_join", keys = resolved_by)`
    to `@variables$domain`. Costs almost nothing. Lets Phase 1 know a
    join-based restriction was applied. Authoritative state is still the
    domain column.
  - **Option C (defer to Phase 1):** Violates HARD-GATE.
- **Decision:** Option B — structured sentinel. GAP-5 closed.
- **Rationale:** The sentinel is nearly free to implement and protects Phase 1
  from a silent contract violation. Even if Phase 1 only uses the domain
  column, the sentinel serves as auditable documentation of what domain
  operations were applied. Extended to `inner_join` domain-aware mode as
  well (sentinel `type = "inner_join"`).

### Outcome

Spec is at version 0.2 (methodology-locked). GAPs 1, 2, 5 resolved. GAPs 3,
4, 6 deferred (3 to Stage 3; 4 and 6 to implementation). `inner_join` now
has a two-mode design with `.domain_aware = TRUE` as default. All methodology
issues from Stage 2 review are addressed.

---

## 2026-04-16 — Stage 4 resolve: spec-review issues 1–12

### Context

Stage 3 identified 12 issues (2 blocking, 7 required, 3 suggestions). This
session worked through all 12, resolving each before handing off to
implementation.

### Questions & Decisions

**Q: Issue 9 — how should the `@variables$domain` sentinel be typed for Phase 1 consumers?**
- Options considered:
  - **Option A (prose contract):** Document that consumers must call `rlang::is_quosure()` before evaluating list entries.
  - **Option B (typed S3 wrapper):** Use `structure(list(type, keys), class = "surveytidy_join_domain")` so `inherits(entry, "surveytidy_join_domain")` gives clean dispatch.
- **Decision:** Option B — typed S3 wrapper, constructed by `.new_join_domain_sentinel(type, keys)`.
- **Rationale:** The S3 class makes the contract self-documenting and removes any ambiguity about how Phase 1 should distinguish join sentinels from quosures. The scope increment is a single three-line constructor.

### Outcome

All 12 issues resolved. Blocking issues 1 and 2 fixed the call-site
inconsistency in `.check_join_col_conflict` and added the missing
row-expansion guard to `inner_join` domain-aware Step 6. GAPs 3 and 4 are
now closed. Test plan extended with test 12b and inline assertions for
`@variables$domain` sentinel, `@groups` preservation, and `@metadata` label
absence in tests 1, 9, 14, 18, and 23. Suffix repair logic extracted into
named helper `.repair_suffix_renames()`. Spec is at version 0.3 (Stage 4
complete); ready for implementation.

---

## 2026-04-16 — Stage 4 resolve: spec-review issues 13–19 (Pass 2)

### Context

Stage 3 Pass 2 found 8 new issues (0 blocking, 3 required, 5 suggestions) after
Pass 1 issues were all resolved in the prior session. This session resolved all
8 through direct spec edits.

### Questions & Decisions

**Q: Issue 13 — Missing Step 7 in `inner_join` domain-aware behavior rules**
- **Decision:** Add explicit Step 7 to §VI domain-aware behavior rules: append
  sentinel via `.new_join_domain_sentinel('inner_join', resolved_by)`.
- **Rationale:** Behavior rules are the implementation guide; omitting a step
  that the output contract requires is a spec defect, not an implementation detail.

**Q: Issue 14 — `bind_cols` Steps 2–4 discard the cleaned frame**
- **Decision:** Restructure Steps 2–4 to name `cleaned_y` explicitly; Step 4
  binds `cleaned_y` rather than the original `...`. This mirrors the
  `y <- .check_join_col_conflict(...)` capture pattern used in `left_join` and
  `inner_join`.
- **Rationale:** The conflict guard was structurally sound (warns correctly) but
  the original `...` were re-introduced in Step 4, making the guard a no-op for
  actual cleanup.

**Q: Issue 15 — `surveytidy_error_reserved_col_name` untested**
- **Decision:** Add tests 13b (`semi_join`) and 13c (`anti_join`) with dual
  pattern (class check + snapshot) for the reserved column name guard in §IV Step 2.
- **Rationale:** `testing-surveytidy.md` requires dual pattern for all
  user-facing errors; this error class had no test.

**Q: Issue 16 — Return-value capture omitted in `left_join` and `inner_join` call sites**
- **Decision:** Show explicit `y <- .check_join_col_conflict(x, y, by)` assignment
  in §III Step 2, §VI domain-aware Step 2, and §VI physical Step 3. Subsequent
  steps reference the cleaned `y`.
- **Rationale:** The spec aims to be implementation-grade; leaving the capture
  implicit violates explicit-over-clever and would produce a guard that warns
  but does not clean.

**Q: Issue 17 — `bind_rows` survey-in-non-first-position unaddressed**
- **Decision:** Acknowledge the limitation in §VIII with a documented note.
  Require the limitation to appear in roxygen `@details`. The intercept case is
  out of scope.
- **Rationale:** The high-effort vctrs/dplyr_reconstruct approach was out of
  scope; the limitation should be documented rather than silently ignored.

**Q: Issues 18–19 — `visible_vars` preservation untested for `semi_join`, `anti_join`, and `inner_join` physical mode**
- **Decision:** Add inline assertions to tests 9 (semi_join), 14 (anti_join),
  and 24 (inner_join physical mode). One-line assertion each; no new test blocks.
- **Rationale:** §XI specifies `visible_vars` is unchanged for these functions;
  the contract was untested.

### Outcome

All 8 Pass 2 issues resolved via spec edits. The spec is fully reviewed and
ready for handoff to `/implementation-workflow`.

---

## 2026-04-17 — Stage 3 resolve: implementation plan review issues 1–11

### Context

Stage 2 review of `plans/impl-joins.md` found 11 issues across two passes (2 blocking,
5 required, 4 suggestions). This session resolved all 11 before handing off to
`/r-implement`.

### Questions & Decisions

**Q: Issue 2 — S3 registration deferred to Phase 6 breaks TDD red-green cycle**
- Options considered:
  - **Option A:** Move each `registerS3method` call into the task that implements the
    corresponding function (Tasks 4b, 8b, 12b, 16b, 20b). Phase 6 becomes reexports-only.
  - **Option B:** Change Phase 1–5 tests to call methods directly, verify dispatch in Phase 6.
- **Decision:** Option A — registrations distributed into Phases 1–5.
- **Rationale:** TDD requires the tests to exercise the actual dispatch path. Deferring
  registration means "confirm pass" steps cannot verify that the implemented method is
  actually called. The incremental registration pattern matches the existing pattern for
  all other surveytidy verbs.

**Q: Issue 3 — `anti_join` double-negation bug in Task 8 code block**
- **Decision:** Remove `# For anti_join: new_mask <- !new_mask` pre-negation comment.
  `new_mask` is always `TRUE = matched by y` for both functions. The negation for
  `anti_join` happens exclusively in the domain AND step: `existing_domain & !new_mask`.
- **Rationale:** The plan's pre-negation + spec's `!new_mask` in the AND step produces
  double-negation, silently inverting anti_join semantics. Aligning with spec exactly
  (Option A) is the safest fix.

**Q: Issue 9 — Test 23d contradicts §VI domain-aware Step 6 row expansion guard**
- Options considered:
  - **Option A:** Change test 23d to expect `surveytidy_error_join_row_expansion`.
    Consistent with §VI error table "Both modes."
  - **Option B:** Add `dplyr::distinct(y)` deduplication before the left_join in
    domain-aware mode. Requires spec amendment.
- **Decision:** Option A — test 23d now expects `surveytidy_error_join_row_expansion`
  with dual pattern.
- **Rationale:** "Error on duplicate keys, both modes" is the declared contract
  (§VI error table). Changing the test requires one line. Option B would silently
  change the contract, violating explicit-over-clever.

### Other resolutions (no meaningful alternatives considered)

- **Issue 1:** 8th error class (`surveytidy_error_reserved_col_name`) moved into Task 1's
  explicit list; redundant Implementation Notes callout removed.
- **Issue 4:** Test 23e added — `inner_join` domain-aware with reserved column name →
  `surveytidy_error_reserved_col_name`, dual pattern.
- **Issue 5:** Dual pattern annotation added to test 30 (per-function snapshot required).
- **Issue 6:** Tests 31–32 added — 0-row `y` (left_join, semi_join, anti_join) and
  0-column `y` (left_join, bind_cols) edge cases from spec §XII.
- **Issues 7, 11:** Ambiguous "dual pattern for the warning" replaced with explicit
  `expect_warning(class = "surveytidy_warning_join_col_conflict")` assertions in
  tests 4, 21, and 26.
- **Issue 8:** Log step added to Task 4 for `.check_join_row_expansion` signature
  extension `(original_nrow, new_nrow, by_label = NULL)`.
- **Issue 10:** Test 24 added to `@groups` preservation acceptance criterion.

### Outcome

All 11 issues resolved. Plan is approved and ready for `/r-implement`. PR 1 covers
all 8 join functions in a single branch (`feature/joins`).

---
