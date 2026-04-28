# Decisions Log — surveytidy survey-collection

This file records planning decisions made during survey-collection.
Each entry corresponds to one planning session.

---

## 2026-04-27 — Methodology lock: survey-collection verb dispatch

### Context

Resolved 15 methodology-review issues from
`plans/spec-methodology-survey-collection.md` (Pass 1). Eight were
unambiguous and applied as a batch; seven were judgment calls
walked through individually.

### Questions & Decisions

**Q: Issue 2 — Should `glimpse.survey_collection` default mode expose the internal `..surveycore_domain..` column?**
- Options considered:
  - **A — Drop the column from glimpse render:** loses diagnostic value (users can't see which rows are out of domain).
  - **B — Rename to `.in_domain` for display:** preserves diagnostic value without exposing surveycore-internal column name; per-member `@data` is untouched.
  - **C — Leave as-is:** zero effort but produces inconsistent UX (column appears only after a filter, with the surveycore-internal name).
- **Decision:** B — rename to `.in_domain` for display, in both default mode and `.by_survey = TRUE` mode.
- **Rationale:** preserves diagnostic value for filtered collections without leaking the implementation detail. Per-member `@data` is unchanged so domain semantics elsewhere are unaffected.

**Q: Issue 4 — Should `pull.survey_collection` filter to in-domain rows?**
- Options considered:
  - **A — Inherit `pull.survey_base` semantics + cross-reference:** verify per-survey behavior; document any limitation at the verb level, not the collection level.
  - **B — Filter to in-domain rows at collection layer:** diverges from per-member dispatch contract.
  - **C — Add `.domain_only = TRUE` argument:** asymmetric with `pull.survey_base`.
- **Decision:** A. Confirmed `pull.survey_base` (R/select.R:313) calls `dplyr::pull(@data, ...)` directly with no domain filter; collection method inherits this. Documented as a known limitation in §V.1 step 2 and the roxygen `@section Domain inclusion:` block.
- **Rationale:** any future change to filter by domain should originate at the survey_base layer; the collection layer picks it up automatically. Avoids divergent contracts between per-survey and collection-level pull.

**Q: Issue 7 — How should `slice_*.survey_collection` handle `n = 0` / empty index that would produce 0-row members?**
- Options considered:
  - **A — Pre-flight error at collection layer:** reject with `surveytidy_error_collection_slice_zero` before dispatch.
  - **B — Document pass-through:** user sees the surveycore validator error from the first rebuilt member.
  - **C — Wrap per-member validator failure:** re-raise the validator error with collection context.
- **Decision:** A. Each slice verb's collection method pre-checks the slice arguments and raises `surveytidy_error_collection_slice_zero` before touching any member. Per-member `n=0` results from otherwise valid arguments (e.g., `slice_head(n = 100)` on a 50-row member) still flow through to the surveycore validator.
- **Rationale:** mirrors D3's "intercept at the collection layer when consequences are structurally unrecoverable" pattern. Cheap to implement; produces a diagnostic message naming the verb and the offending arg rather than a misleading "first member is invalid" error.

**Q: Issue 8 — How should `select.survey_collection` / `relocate.survey_collection` handle removal of a group column?**
- Options considered:
  - **A — Verb-layer pre-flight:** raise `surveytidy_error_collection_select_group_removed` before dispatch.
  - **B — Defer to surveycore validator:** validator's G1b error fires after dispatch; document that select can trigger it.
  - **C — Silently update `coll@groups`:** drop removed group columns from `coll@groups`. (Same flaw as the rejected D3 option.)
- **Decision:** A — symmetric with D3's group-rename pre-flight. The verb resolves the user's tidyselect against the first member's data, checks whether any column in `coll@groups` would be removed, and raises the typed error before any member is touched.
- **Rationale:** validator-level error doesn't name `select` as the cause; silent group-update would silently drop the user's grouping. Pre-flight is cheap and preserves D3-pattern consistency.

**Q: Issue 9 — Should `rename` of a non-group design variable batch its warning?**
- Options considered:
  - **A — Document and accept N firings:** maintain per-member dispatch contract.
  - **B — Batch at collection layer:** one warning naming all affected members.
  - **C — Suppress per-member; collection-level only:** breaks `withCallingHandlers()` consumers.
- **Decision:** A — document per-member multiplicity in §IV.4 and the roxygen `@section Survey collections:` block.
- **Rationale:** per-member dispatch is the architectural contract (V4 already establishes the same pattern for `surveycore_warning_empty_domain`). Re-batching adds complexity for marginal UX gain and breaks symmetry.

**Q: Issue 11 — Should `mutate` of a weight column batch its warning?**
- Options considered:
  - **A — Document and accept:** same approach as Issue 9.
  - **B — Batch at collection layer.**
  - **C — Suppress per-member.**
- **Decision:** A — symmetric resolution with Issue 9.
- **Rationale:** identical reasoning — preserve per-member dispatch contract symmetry across all warning classes.

**Q: Issue 13 — How should `glimpse.survey_collection` handle a user-named column that collides with `coll@id`?**
- Options considered:
  - **A — Pre-check + typed error:** raise `surveytidy_error_collection_glimpse_id_collision` before binding.
  - **B — Auto-rename prepended column:** rename to `<id>_member` or similar.
  - **C — Document and let `bind_rows` / `add_column` raise:** leaks internals.
- **Decision:** A — pre-check at the start of default mode; raise the typed error naming the colliding column, `coll@id`'s value, and the offending members.
- **Rationale:** mirrors surveycore's analysis-side `surveycore_error_collection_id_collision` pattern. Verb-side pre-check is needed because the user can introduce a collision after construction (e.g., via `mutate`). Auto-rename is silently surprising; deferring to `bind_rows` produces an error message that doesn't reference glimpse.

### Outcome

The spec now contains:
- Env-aware pre-check that filters `all.vars()` output through `rlang::quo_get_env(quo)` before flagging missing variables (fixes BLOCKING Issue 1).
- Typed sentinel condition `surveytidy_pre_check_missing_var` with documented class chain and fields (Issue 12).
- Explicit `verb_name` parameter on `.dispatch_verb_over_collection()` (Issue 15).
- `.may_change_groups` flag on the dispatcher with post-step-5 invariance assertion via `surveytidy_error_internal_groups_mutation` (Issue 10).
- `.if_missing_var` removed from signatures of `slice` / `slice_head` / `slice_tail` / `slice_sample` (no `weight_by`) — no longer advertised as a no-op (Issue 6).
- Explicit per-member domain preservation contract in §III.3 (Issue 3).
- Per-member `surveycore_warning_physical_subset` propagation noted in §IV.6 (Issue 5).
- Step 4 / §VII.2 inconsistency resolved: dispatcher proactively checks for empty result; validator is a safety-net only (Issue 14).
- Display-only domain rename to `.in_domain` in `glimpse.survey_collection` (Issue 2).
- Verb-layer pre-flights with new error classes for slice-zero (Issue 7), select-group-removed (Issue 8), and glimpse-id-collision (Issue 13).
- Domain-inclusion contract for `pull.survey_collection` documented as inherited from `pull.survey_base` (Issue 4).
- Per-member warning multiplicity documented for rename-design-var (Issue 9) and mutate-weight-col (Issue 11).
- Four new typed conditions added to §VII.1 (`surveytidy_error_collection_slice_zero`, `surveytidy_error_collection_select_group_removed`, `surveytidy_error_collection_glimpse_id_collision`, plus the two internal classes from Issues 10 and 12).

---

## 2026-04-27 — Stage 3 spec-review resolution: survey-collection verb dispatch

### Context

Resolved 21 spec-review issues from `plans/spec-review-survey-collection.md`
(3 BLOCKING, 8 REQUIRED, 10 SUGGESTION). Worked through them one at a time
in spec order. Most resolutions tracked the recommendation; a handful required
judgment calls that are recorded below.

### Questions & Decisions

**Q: Issue 1 — How should the dispatcher signal "this verb references no user
columns" (`slice`, `slice_head`/`slice_tail`, `slice_sample` without
`weight_by`, `ungroup`)?**
- Options considered:
  - **A — Add `"none"` to `.detect_missing`:** explicit third value;
    dispatcher skips both pre-check and class-catch wrapping.
  - **B — Sentinel via `.detect_missing = NULL`:** less explicit; mixes
    "absent" with "absent + meaningful."
  - **C — Always require pre_check or class_catch:** verbs that don't
    reference columns would have to lie about their detection mode.
- **Decision:** A. `.detect_missing` is now `"pre_check" | "class_catch" | "none"`.
- **Rationale:** explicit-over-clever (engineering preference §5). The
  sentinel "none" is the same shape as the other values; readers don't have
  to decode `NULL`. Cheap to implement and removes a hidden assumption.

**Q: Issue 2 — How should the dispatcher distinguish a per-call
`.if_missing_var` override from the stored collection default when emitting
diagnostics?**
- Options considered:
  - **A — Track `id_from_stored` flag in step 1.5:** compute once before
    resolution; pass through to error messages.
  - **B — Re-derive at error time:** repeat the `is.null()` check at every
    error site.
- **Decision:** A.
- **Rationale:** DRY (engineering preference §1) — the "did the caller
  override?" question has one answer per dispatch and should be computed
  once. Step 1.5 keeps the resolution logic adjacent to the resolution
  itself, so future changes don't desync.

**Q: Issue 3 — How should the dispatcher classify errors that are not
`vctrs_error_subscript_oob` but the verb still failed in class_catch mode?**
- Options considered:
  - **A — Drop `rlang_error` from the catch and re-raise unchanged:** the
    only error class we knowingly translate is `vctrs_error_subscript_oob`;
    everything else surfaces as the per-member error with original class.
  - **B — Wrap `rlang_error` too:** broader catch, but loses original class
    information from per-member dispatch.
- **Decision:** A.
- **Rationale:** preserves per-member error class fidelity. `rlang_error`
  is a generic supertype; catching it would mask validator failures and
  surveycore-typed conditions that callers may want to handle.

**Q: Issue 8 — Should `pull.survey_collection` use pre_check or class_catch
to detect a missing variable?**
- Options considered:
  - **A — pre_check via `all.vars()` of the `var` quosure:** symmetric with
    other data-mask verbs.
  - **B — class_catch via `tryCatch` on the per-member `pull`:** `pull`'s
    `var` argument is tidyselect-resolved (single column), not a data-mask
    expression. The `name` argument is also tidyselect.
- **Decision:** B.
- **Rationale:** matches `pull.survey_base`'s actual evaluation semantics.
  Pre-checking with `all.vars()` would misclassify tidyselect helpers
  (`last_col()`, `where()`) as missing variables.

**Q: Issue 12 — Should the post-dispatch group-invariance assertion use a
typed `cli::cli_abort()` with class `surveytidy_error_internal_groups_mutation`
or a `stopifnot()`?**
- Options considered:
  - **A — Typed cli_abort:** consistent with surveytidy error conventions;
    catchable via `tryCatch(class = ...)`.
  - **B — `stopifnot()`:** internal invariant; a failure is a bug, not a
    user-facing condition. No class is needed because no caller should ever
    branch on it.
- **Decision:** B. Section §II.3.1 step 5 now reads
  `stopifnot(identical(out_coll@groups, collection@groups))`.
- **Rationale:** this is a defensive assertion against a developer mistake
  in a verb method, not a user-recoverable error. Engineering preference
  §3 ("engineered enough — not under, not over") — a typed class for an
  internal invariant is over-engineered. The class
  `surveytidy_error_internal_groups_mutation` is dropped from §VII.1.

**Q: Issue 18 — How should the implementation PR be split?**
- Options considered:
  - **A — Single mega-PR:** all collection methods + tests in one branch.
  - **B — Split by verb family (2a–2d):** data-mask, tidyselect, grouping,
    slice — four PRs sharing the dispatcher PR (1) as a base.
  - **C — Per-verb PR:** maximally granular; ~14 PRs.
- **Decision:** B. Phase 2 split into 2a (filter, filter_out, drop_na, mutate,
  arrange), 2b (select, relocate, rename, rename_with, distinct, rowwise),
  2c (group_by, ungroup, group_vars, is_rowwise), 2d (slice family +
  slice-zero pre-flight).
- **Rationale:** matches surveytidy's "one PR per logical unit" rule
  (github-strategy.md). Each PR is reviewable in <300 lines, ships a
  coherent verb family, and can be merged independently once the dispatcher
  lands. Final granularity is owned by `/implementation-workflow` and may be
  revised at planning time.

**Q: Issue 21 — Does `relocate.survey_collection` need the same group-removal
pre-flight as `select.survey_collection`?**
- Options considered:
  - **A — No pre-flight for relocate:** `dplyr::relocate` cannot drop
    columns; it only reorders. Negative selectors preserve the negated
    column.
  - **B — Add the pre-flight defensively:** symmetry with select.
- **Decision:** A. Verified empirically: `dplyr::relocate(mtcars, -cyl)`
  preserves `cyl` (just reorders the others before it). Section §IV.3 now
  scopes the group-removal pre-flight to `select` only.
- **Rationale:** adding a pre-flight that can never trigger is dead code
  (engineering preference §3). Documenting the asymmetry in §IV.3 is
  cheaper and clearer than maintaining a defensive no-op.

### Outcome

The spec is now both methodology-locked (Stage 2) and code-quality-reviewed
(Stage 3). Concrete spec changes:

- `.detect_missing` parameter accepts `"pre_check" | "class_catch" | "none"`
  (Issue 1); verbs that reference no user columns set `"none"`.
- Dispatcher tracks `id_from_stored` (Issue 2) and only catches
  `vctrs_error_subscript_oob` in class_catch mode (Issue 3).
- `is_rowwise.survey_collection` added; collection is rowwise iff every
  member is rowwise (Issue 5).
- `pull.survey_collection` uses class_catch detection (Issue 8); typed
  internal-invariant error class dropped in favor of `stopifnot()` (Issue 12).
- `relocate.survey_collection` is exempt from the group-removal pre-flight
  (Issue 21); §IV.3 documents that `relocate` cannot drop columns.
- Phase 2 implementation split across PRs 2a/2b/2c/2d by verb family
  (Issue 18).
- Per-verb test coverage matrix expanded (§IX.3); dispatcher test plan
  expanded (§IX.4); roxygen `@inheritParams` stub pattern documented in
  §VIII (Issue 20).
- All other REQUIRED and SUGGESTION fixes applied per recommended option:
  spec contradictions resolved (Issues 4, 13, 14, 15, 16), edge case
  coverage tightened (Issues 7, 17), minor doc polish (Issues 9, 10, 11,
  19).

Stage 3 Pass 1 spec-review resolution complete; spec re-entered Stage 3
for a verification pass (Pass 2).

---

## 2026-04-27 — Stage 4 resolution: spec-review Pass 2

### Context

Resolved 8 issues from Pass 2 of `plans/spec-review-survey-collection.md`
(1 BLOCKING, 4 REQUIRED, 3 SUGGESTION). Pass 2 was a verification sweep
that confirmed all 21 Pass 1 issues were correctly applied, then surfaced
fresh gaps and a contradiction between the Pass 1 decisions and the
spec text.

### Questions & Decisions

**Q: Issue 22 — `pull.survey_collection` detection mode contradicts the decisions log.**
The Pass 1 decision was class-catch only, but the spec text at §V.1 step 2 and §II.4 still showed pre-check + class-catch.
- Options considered:
  - **A — Align spec to decisions log:** rewrite §V.1 step 2 and §II.4 to specify class-catch only, with one handler covering both `var` (tidyselect) and `name` (string subscript).
  - **B — Re-litigate Decision B:** revert to pre-check for `var`. Risk: tidyselect helper false positives.
- **Decision:** A.
- **Rationale:** the decisions log is authoritative; `var` is documented `<tidy-select>` and class-catch is the technically correct mode (avoids `last_col()` / `where()` false positives).

**Q: Issue 23 — Atomic property update order on `out_coll` in dispatcher step 5.**
The four `@<-` writes interact with S7 validation in ways that can fail for grouping verbs depending on construction strategy.
- Options considered:
  - **A — Constructor rebuild** via `surveycore::as_survey_collection(!!!results, ...)`. Single validator run on consistent state.
  - **B — Attr-bypass + `S7::validate()`:** mirrors the rename trick.
  - **C — Ordered `@<-` with conditional pre-update of `@groups`** for grouping verbs (two code paths).
- **Decision:** A.
- **Rationale:** surveycore owns the `survey_collection` class contract; surveytidy goes through the documented constructor so any future invariant change in surveycore is picked up automatically. The constructor overhead is acceptable for clarity.

**Q: Issue 24 — `.by` argument handling on non-filter data-masking verbs.**
§IV.1 / §III.1 reject `.by` for filter only; mutate, slice_min, slice_max, slice_sample also accept `.by` and were unspecified.
- Options considered:
  - **A — Reject `.by` across all collection verbs that take it,** with a new shared class `surveytidy_error_collection_by_unsupported`.
  - **B — Forward `.by` to per-member with a documented note.**
  - **C — Reuse `surveytidy_error_filter_by_unsupported`.**
- **Decision:** A.
- **Rationale:** the collection layer already has `coll@groups` for grouping intent; per-call `.by` does not compose cleanly with collection-level groups. New class name reflects collection-layer scope rather than implying filter-only.

**Q: Issue 25 — `make_heterogeneous_collection()` contract was a single sentence.**
Implementer would have to invent member count, subclasses, schemas, and group-column uniformity.
- Options considered:
  - **A — Add full contract** with implementation sketch, deterministic member names (`m1`/`m2`/`m3`), all-`survey_taylor`, three distinct schemas (full / drops `y2`+`y3` / drops `y1` and adds `region`), `group` column uniform across members per G1b.
  - **B — Inline test data per test.**
- **Decision:** A.
- **Rationale:** a shared fixture with explicit contract ensures the V2 `any_of()` test, `.if_missing_var = "skip"` tests, and dispatcher pre-check / class-catch tests all exercise the same heterogeneity pattern.

**Q: Issue 26 — `test_invariants()` is not defined for `survey_collection`.**
`testing-surveytidy.md` mandates `test_invariants(design)` as the first assertion in every verb test block, but the existing helper is `survey_base`-specific.
- Options considered:
  - **A — Define `test_collection_invariants()`** in `helper-test-data.R` covering G1, G1b, `@id` shape, `@if_missing_var` enum, member class type. Require both `test_collection_invariants(coll)` AND `test_invariants(member)` iterated over `@surveys` as the first assertions in every collection verb test.
  - **B — Iterate `test_invariants()` over `@surveys` only:** no new helper.
  - **C — Document that collection tests skip `test_invariants()`.**
- **Decision:** A.
- **Rationale:** the only option that preserves the testing-surveytidy.md invariant-first discipline at the collection layer while also asserting member-level invariants. Effort is trivial; the helper is ~40 lines.

**Q: Issue 27 — §I.3 misstates G1/G1b/G1c as the invariant family that enforces member class type.**
The G1 family is about `@groups` consistency; member type is enforced separately by the S7 class definition.
- Options considered:
  - **A — Rewrite §I.3** to separate the two invariants.
  - **B — Do nothing.**
- **Decision:** A.
- **Rationale:** accurate spec wording prevents future contributor confusion at trivial cost.

**Q: Issue 28 — Dispatcher signature has `.detect_missing` (required) after optional arguments.**
Violates `code-style.md` §4 argument-order convention.
- Options considered:
  - **A — Default `.detect_missing` to `"none"`:** verb methods that need detection always pass an explicit value; callers that forget get the safest no-op.
  - **B — Move `.detect_missing` ahead of `...`.**
- **Decision:** A.
- **Rationale:** safest default; matches the `"none"` mode introduced in Pass 1 Issue 1; verb methods that need detection MUST pass explicit `"pre_check"` or `"class_catch"` per §II.4.

**Q: Issue 29 — `surveytidy_error_collection_rename_group_partial` reachability.**
The check is structurally redundant for plain `rename` (G1b guarantees coverage) but load-bearing for `rename_with` (`.cols` resolves per-member).
- Options considered:
  - **A — Document the rename-vs-rename_with reachability difference** in §IV.4. Keep the shared structure as defense-in-depth.
  - **B — Scope the pre-flight to `rename_with` only.**
- **Decision:** A.
- **Rationale:** the redundancy is intentional defense-in-depth at trivial cost; documenting the reasoning prevents a future contributor from "simplifying" the protective branch and breaking shared code.

### Outcome

All 8 Pass 2 issues are closed. Concrete spec changes:

- §V.1 step 2 and §II.4 pull row rewritten to class-catch only
  (Issue 22).
- §II.3.1 step 5 specifies constructor rebuild via
  `as_survey_collection(!!!results, ...)`; raw `@<-`, clone-and-update,
  and attr-bypass paths explicitly forbidden (Issue 23).
- New shared error class
  `surveytidy_error_collection_by_unsupported` (§VII.1); §III.1 carries
  the rejection contract; §IV.1, §IV.5, §IV.6 reference it (Issue 24).
- `make_heterogeneous_collection()` fully specified in §IX.2 with
  implementation sketch and contract (Issue 25).
- `test_collection_invariants()` defined in §IX.2 with full
  implementation; §IX.3 Happy-path row updated to require dual-invariant
  discipline (Issue 26).
- §I.3 rewritten to separate S7 property-type validation (member class)
  from G1/G1b/G1c (groups consistency) (Issue 27).
- Dispatcher signature `.detect_missing` defaults to `"none"`; §II.3.1
  parameter table updated (Issue 28).
- §IV.4 reachability note distinguishes plain-`rename` (redundant given
  G1b, kept as defense-in-depth) from `rename_with` (load-bearing)
  (Issue 29).

Stage 4 is complete; spec is methodology-locked, code-quality-reviewed
across two passes, and ready for `/implementation-workflow`.

---

## 2026-04-28 — implementation-workflow Stage 3: plan-review resolution

### Context

Resolved 14 plan-review issues from `plans/plan-review-survey-collection.md`
(0 BLOCKING, 5 REQUIRED, 9 SUGGESTION). Worked through them one at a time,
SMALL batch, with explicit user decision per issue. Most resolutions
tracked the recommendation; a handful required judgment calls (Issues 7,
8, 11, 13) recorded below. Edits applied to
`plans/impl-survey-collection.md` and `plans/spec-survey-collection.md`
(§XII PR map only) — no source code changes.

### Questions & Decisions

**Q: Issue 6 — How precise should the bare "(Issue 3)" reference in PR 1
task 24 be?**
- **Decision:** A — replace with the fully qualified
  `decisions-survey-collection.md, 2026-04-27 Stage 3 spec-review
  resolution, Q: Issue 3` citation in both task 24 and PR 1 Notes.
- **Rationale:** the decisions log has multiple sessions with overlapping
  numbering (methodology-lock, spec-review Pass 1, Pass 2). Fully qualified
  references are cheap and remove the grep tax for future implementers.

**Q: Issue 7 — Should `.derive_member_seed()` live in `R/utils.R` (PR 1)
or `R/slice.R` (PR 2d)?**
- Options considered:
  - **A — Keep in `R/utils.R` (PR 1) and document the deviation:** ships
    the helper alongside the other `.sc_*` wrappers, but violates
    `code-style.md` §4 (single-call-site helper).
  - **B — Move to top of `R/slice.R` (PR 2d):** matches `code-style.md`
    §4 by colocating the helper with its only caller
    (`slice_sample.survey_collection`).
- **Decision:** B — moved from PR 1 to PR 2d. PR 1 task list renumbered
  5–46 → 5–43 (three tasks removed); PR 2d task list renumbered 4–16 →
  6–18 with a new TDD pair (steps 4–5) for the helper.
- **Rationale:** `code-style.md` §4 takes precedence over PR-boundary
  ergonomics. The helper has exactly one consumer, and "ships in PR 1
  ahead of its call site" is not a strong enough justification to
  override a written rule. Cleaner final state.

**Q: Issue 8 — How should the `drop_na` detection-mode footnote in PR 2a
("Correction:" framing) be cleaned up?**
- Options considered:
  - **A — Rewrite the note as a single coherent paragraph** distinguishing
    pre-check vs class-catch verbs in PR 2a.
  - **(emerged during discussion) — Move `drop_na` from PR 2a (data-mask)
    to PR 2b (tidyselect) entirely.** PR 2a becomes uniformly `pre_check`;
    PR 2b becomes uniformly `class_catch`; the footnote disappears.
- **Decision:** the user-driven scope expansion. `drop_na` relocated from
  PR 2a → PR 2b across `impl-survey-collection.md` (file lists, acceptance
  criteria, tasks, Notes) and `spec-survey-collection.md` §XII PR map.
- **Rationale:** the asymmetric placement was the underlying inconsistency,
  not the wording. Moving the verb to the PR whose detection mode it
  actually uses is structurally cleaner and removes the need for any
  explanatory footnote at all. Original Issue 8 dissolved by structural
  change.

**Q: Issue 9 — How should PR 2b task 11's `rename_with` grouped fixture be
constructed without violating S7 G1?**
- Options considered:
  - **A — Use the `attr<-` bypass pattern** documented in CLAUDE.md for
    rename: `attr(coll, 'groups') <- 'psu'` plus a per-member loop, then
    `S7::validate(coll)`.
  - **B — Build via per-member `dplyr::group_by` before
    `as_survey_collection()`:** uses only develop-stable APIs; the
    member-level `group_by` exists on develop and the constructor sees
    consistent `@groups` from the start.
- **Decision:** B. Task 11 rewritten to build the grouped fixture via
  per-member `dplyr::group_by(member, psu)` before
  `surveycore::as_survey_collection()`, with an explicit warning against
  the broken `coll@groups <- "psu"` direct-assignment pattern.
- **Rationale:** uses only develop-stable APIs; satisfies G1 by
  construction; matches the "build via inline construction" idiom used
  elsewhere in the plan. The `attr<-` bypass is reserved for paths where
  no constructor can produce the needed state — that's not the case here.

**Q: Issue 10 — The PR 2b V9 distinct test says "build via inline
construction" without spelling out the recipe. Should the recipe be
explicit?**
- **Decision:** A — spell out the three-data.frame fixture: `df1` has rows
  1–2 identical (internal duplicate within member 1); `df2` row 1 matches
  `df1` row 1 (cross-member duplicate between members 1 and 2); `df3`
  unrelated. Wrap each via `surveycore::as_survey()`, pass to
  `as_survey_collection()`, call `distinct(coll)`, assert that the
  internal duplicate collapses while the cross-member duplicate is
  preserved.
- **Rationale:** V9 is the load-bearing semantics of `distinct` on
  collections (per-survey distinct, no cross-survey collapse). A vague
  "inline construction" hint risks the implementer building the wrong
  scenario; spelling out the recipe is cheap.

**Q: Issue 11 — How should the PR 2c task 7 G1b safety-net test be
structured, given that G1b is structurally unreachable through normal
dispatch?**
- Options considered:
  - **A (synthesized) — Two-part test:** Part 1 covers the happy-path
    skip (no G1b violation, normal dispatch); Part 2 simulates a
    synthetic G1b violation by bypassing per-member validators via
    `attr(coll, "surveys")` then calling `S7::validate(coll)` directly.
    Document defense-in-depth framing inline in the test file.
- **Decision:** A. Task 7 rewritten with the two-part recipe and an
  in-test comment explaining that Part 2 exercises the validator's
  defense against a regression in surveycore's per-member enforcement,
  not a reachable path through `group_by.survey_collection`.
- **Rationale:** defense-in-depth tests should exercise the actual
  defense — the alternative is a trivial test that never triggers the
  safety net. The `attr<-` bypass is the only way to construct the
  broken state because every constructor and dispatcher refuses to
  produce it (which is the point of the safety net).

**Q: Issue 12 — How should the misleading "signature is conditional"
language in PR 2d task 9 (slice_sample) be rewritten?**
- **Decision:** A — clarify that the signature is static and always
  includes `.if_missing_var`; the verb body branches on
  `is.null(weight_by)` at runtime to choose `.detect_missing = "none"`
  vs `.detect_missing = "pre_check"`. Reference spec §IV.6 lines
  791–794 directly.
- **Rationale:** R signatures cannot vary by argument value at runtime.
  The original wording (inherited from spec §III.2 line 389) could be
  read to imply two methods or `missing()`/`match.call()` tricks. The
  spec's §IV.6 prose has the correct framing; the plan task should
  paraphrase it accurately rather than the table's loose summary.

**Q: Issue 13 — How should the contradictory PR 3 task 2 wording ("Build
the dispatcher call manually... do NOT use the dispatcher") be cleaned
up?**
- **Decision:** A — rewrite to plainly state "`pull` does **not** use
  `.dispatch_verb_over_collection`," then describe the per-member
  iteration with an inline class-catch handler that replicates the
  dispatcher's behavior. Match the wording of the existing PR 3 Notes
  section verbatim.
- **Rationale:** the Notes section already had the correct framing; the
  task wording was internally contradictory. Consolidating on the
  Notes-section wording removes the ambiguity without inventing new
  semantics.

**Q: Issue 14 — Should the `print.survey_collection` regression check
remain a manual visual check, or be automated?**
- Options considered:
  - **A — `expect_snapshot(print(coll))` after the cross-verb pipeline:**
    integrates with `snapshot_review()` like every other surveytidy
    snapshot; full rendered output captured.
  - **B — Structured `expect_match()` against literal strings** for
    `@id` / `@if_missing_var` / `@groups`: less brittle than full
    snapshot.
- **Decision:** A. Both the acceptance criterion (lines 1035–1037) and
  task 11 (lines 1089–1091) updated to require
  `expect_snapshot(print(coll_after_pipeline))` placed alongside the
  dual-invariant assertion in the cross-verb pipeline test.
- **Rationale:** surveytidy already uses `expect_snapshot()` extensively
  for error messages and print output — the print-specific manual check
  was the outlier. Snapshots integrate with existing tooling and catch
  silent regressions across verb additions, dispatcher changes, and
  constructor changes.

### Outcome

All 14 plan-review issues are closed (5 REQUIRED + 8 SUGGESTION applied
per recommended option; Issue 8 dissolved by structural change). Concrete
plan/spec changes:

- PR map and PR Notes citations fully qualified (Issue 6).
- `.derive_member_seed()` colocated with its caller in `R/slice.R` (PR
  2d), per `code-style.md` §4 (Issue 7).
- `drop_na` relocated from PR 2a to PR 2b, removing the asymmetric
  detection-mode footnote (Issue 8 — dissolved).
- Group-fixture construction in PR 2b uses per-member `dplyr::group_by`
  before `as_survey_collection()`, satisfying G1 by construction
  (Issue 9).
- V9 distinct test recipe spelled out with three-data.frame fixture and
  exact assertions (Issue 10).
- G1b safety-net test split into normal-path + synthetic-violation
  parts, with in-test defense-in-depth documentation (Issue 11).
- `slice_sample` signature/dispatch behavior described accurately:
  static signature, runtime branching on `is.null(weight_by)` (Issue 12).
- `pull.survey_collection` task wording aligned with PR 3 Notes
  section: `pull` does NOT use the dispatcher; per-member iteration with
  inline class-catch handler (Issue 13).
- `print.survey_collection` regression coverage automated via
  `expect_snapshot(print(coll))` in the cross-verb pipeline test
  (Issue 14).
- Earlier-session resolutions (Issues 1–5) covered the REQUIRED
  structural fixes: PR 2c dependency rationale corrected; per-verb
  `visible_vars`-preservation acceptance criteria added; pre-allocated
  per-PR comment blocks in `R/zzz.R` to eliminate merge-conflict
  surface; `test-collection-rowwise.R` ownership assigned to PR 2b;
  arrange/slice test-file split into `test-collection-arrange.R` (PR
  2a) and `test-collection-slice.R` (PR 2d).

Stage 3 is complete; the plan is internally consistent, every spec
function has a buildable PR with concrete tests, and the four-PR map
is ready to enter `/r-implement` starting at PR 1 (dispatcher
infrastructure).

---

## 2026-04-28 — Rowwise uniformity on `survey_collection`: soft invariant

### Context

While reviewing `rowwise.survey_collection` (spec §IV.10), the
question arose whether per-member rowwise state should be enforced as
a hard cross-member invariant — analogous to `@groups`, which the
surveycore S7 class validator (G1) requires to be `identical()` across
every member of a `survey_collection`.

The dispatcher path always produces uniform rowwise state:
`rowwise.survey_collection` calls `rowwise.survey_base` on every
member, so a collection built via the verb is always all-rowwise or
all-not-rowwise. Mixed state can only arise from atypical paths:
`as_survey_collection()` called with members that already have
divergent rowwise state, `add_survey()` adding a non-rowwise survey
to an otherwise-rowwise collection, or direct slot mutation
(`coll@surveys[[i]] <- rowwise(...)`).

### Question & Decision

**Q: Should rowwise uniformity across `coll@surveys` be enforced as a
hard invariant (S7 validator + propagation in `as_survey_collection` /
`add_survey`), the way `@groups` is, or a soft invariant (no
construction-time enforcement; warn at consumption)?**

- Options considered:
  - **A — Hard invariant via surveycore S7 validator.** Symmetric
    with `@groups`. Validator compares per-member
    `@variables$rowwise` against a new `@rowwise` slot on
    `survey_collection`. `as_survey_collection()` and `add_survey()`
    propagate rowwise state from the collection to members
    (analogous to `.propagate_or_match()` for groups).
  - **B — Hard invariant via surveytidy entry-point checks only.**
    surveytidy wraps or augments `as_survey_collection()` /
    `add_survey()` to enforce uniformity. surveycore class validator
    is unchanged; direct surveycore construction is a hole.
  - **C — Soft invariant: detect at consumption + warn.** Mixed
    state is allowed to exist on the collection. The single
    collection-layer consumer of rowwise (`mutate.survey_collection`)
    runs a pre-check before dispatch and emits
    `surveytidy_warning_collection_rowwise_mixed` once when state is
    non-uniform, then dispatches normally.
- **Decision:** C — soft invariant.
- **Rationale:**
  1. **Cross-package ownership.** `@groups` is enforceable in the
     surveycore class validator because surveycore owns `@groups`.
     Rowwise lives in `@variables$rowwise`, which is a surveytidy
     concept — the surveycore class doesn't (and shouldn't) know
     about it. Option A inverts the package boundary by either
     putting a `@rowwise` slot on `survey_collection` (duplicate
     state on top of the per-member key, with sync risk) or having
     surveycore peek at a `@variables` key it owns nothing about.
     Option B leaves direct surveycore construction unprotected,
     which defeats the point of an "invariant."
  2. **Blast radius is one verb.** `@groups` is load-bearing for
     every `get_*()` analysis call; mixed `@groups` would corrupt
     stratified estimation across the entire dispatcher. Mixed
     rowwise affects only `mutate.survey_collection` — it would
     produce divergent evaluation semantics within one collection-
     level `mutate()` call, but no other verb consumes rowwise
     state. A targeted warning at the one site that matters
     gets ~95% of the safety of a hard invariant for a fraction
     of the cost.
  3. **The dispatcher path already produces uniform state.** The
     only way mixed state can arise in normal usage is the
     atypical "build a collection from already-rowwise members"
     path. The warning catches that case at the moment it would
     cause confusion (the next `mutate()` call) without imposing
     enforcement on every other entry point.
  4. **`is_rowwise.survey_collection` is the right predicate.**
     Returning `FALSE` on a mixed collection is a feature (it tells
     the user one or more members fell out of rowwise mode) — a
     hard invariant would make a third "partially rowwise" state
     unrepresentable, which is the wrong contract for a soft
     concept.

### Outcome

The spec and impl plan now contain:

- **Spec §IV.10** — new "Soft uniformity invariant" subsection that
  documents the cross-package boundary as the architectural reason,
  describes the construction-vs-consumption asymmetry, and points
  forward to §IV.5 for the warning's home.
- **Spec §IV.5** — new "Rowwise mixed-state pre-check" paragraph
  describing the `vapply(coll@surveys, is_rowwise, logical(1))`
  check, the `surveytidy_warning_collection_rowwise_mixed` class,
  the once-per-call multiplicity (not per-member), and the
  fall-through-to-dispatch semantics.
- **Impl plan PR 2a** — five new TDD steps (22a–22e) implement
  and test the pre-check inside `mutate.survey_collection`. The
  fixture builds a mixed collection by calling `rowwise()` on a
  single member before `as_survey_collection()`, so the test does
  not depend on `rowwise.survey_collection` (PR 2b). Closure tasks
  add the new warning class row to `plans/error-messages.md`.
- **Impl plan PR 2b** — Notes section cross-references PR 2a
  for the mixed-state warning; `rowwise.survey_collection` itself
  produces uniform state by construction and is unchanged by this
  decision.
- **`plans/error-messages.md`** — new warning class
  `surveytidy_warning_collection_rowwise_mixed` registered against
  `R/mutate.R`.

No surveycore changes are required. `survey_collection`'s class
definition, validator, and `add_survey()` propagation logic remain
exactly as shipped.

---

## 2026-04-28 — Implementation plan resolve: 5 plan-review issues

### Context

Resolved 5 open issues from `plans/plan-review-survey-collection.md`
(Pass 2). Two REQUIRED, three SUGGESTION; no blocking issues.

### Questions & Decisions

**Q: Issue 15 — `R/rowwise.R` is a merge-conflict hotspot between PRs 2b and 2c.**
- Options considered:
  - **A — Pre-allocate two labelled placeholder blocks in `R/rowwise.R` from PR 1:** mirrors the resolved `R/zzz.R` pattern; PRs 2b and 2c insert into non-overlapping regions.
  - **B — Move `is_rowwise.survey_collection` into `R/group-by.R`:** breaks the verb-file-locality rule (`survey_base` rowwise lives in `R/rowwise.R`).
  - **C — Serialize PR 2c after PR 2b:** removes parallelism between PRs 2b and 2c.
  - **D — Do nothing:** accept rebase tax at integration.
- **Decision:** A. PR 1 now pre-allocates `# ── rowwise.survey_collection (PR 2b) ──` and `# ── is_rowwise.survey_collection (PR 2c) ──` placeholder blocks in `R/rowwise.R`; PRs 2b and 2c reference the blocks in their file lists.
- **Rationale:** symmetric with the established `R/zzz.R` solution (Pass 1 Issue 3); preserves PR 2b/2c parallelism at near-zero cost.

**Q: Issue 17 — Task 11 `rename_with` fixture cannot trigger partial resolution as written.**
- Options considered:
  - **A — Type member A's `psu` as factor via `attr<-` bypass + `S7::validate()`:** matches the spec's worked example; introduces fixture asymmetry.
  - **B — Use `.cols = "psu"` (explicit string) on a different fixture:** requires its own bypass setup; less aligned with the spec example.
  - **D — Do nothing:** ship `surveytidy_error_collection_rename_group_partial` without coverage of its primary justification.
- **Decision:** A. PR 2b Task 11 now types member A's `psu` as factor before the `rename_with(.cols = where(is.factor))` call; assertions explicitly state the per-member resolution (A: includes `psu`; B/C: empty) and the dispatcher raises `surveytidy_error_collection_rename_group_partial`.
- **Rationale:** minimal fixture change; presupposed by the spec's worked example. Ensures the pre-flight error class ships with effective regression coverage.

**Q: Issue 16 — PR 1 acceptance criteria omit half of the §IX.4 dispatcher tests.**
- Options considered:
  - **A — Enumerate all §IX.4 bullets as a checklist:** complete reviewer checklist; cheap.
  - **B — Do nothing:** rely on reviewers to cross-reference the spec.
- **Decision:** A. PR 1 acceptance criteria now enumerate every §IX.4 bullet as a checklist.
- **Rationale:** acceptance criteria are the reviewer's checklist; making them complete prevents partial approvals.

**Q: Issue 18 — Spec §IX.5 and §X disagree on coverage target.**
- Options considered:
  - **A — Reconcile in spec:** change §IX.5 to match §X (≥98% overall; ≥95% per new file); add closing-notes pointer in plan.
  - **B — Tighten plan to ≥98% per new file:** matches §IX.5 literally; risks PR rejection on natural 96–97% coverage.
  - **C — Do nothing:** plan and spec disagree silently.
- **Decision:** A. Spec §IX.5 updated to mirror §X. Plan closing notes record the reconciliation. Per-PR coverage targets unchanged.
- **Rationale:** §X's reading (98% overall + 95% per file) is the engineering-realistic floor consistent with `testing-standards.md`. §IX.5 was the looser intent mis-stated.

**Q: Issue 19 — Cross-verb integration test composition is under-specified.**
- Options considered:
  - **A — Prescribe an exact pipeline:** rigid; may not reflect realistic flow.
  - **B — Require one verb from each of PRs 2a/2b/2c/2d + dual invariants + snapshot:** preserves implementer flexibility while guaranteeing coverage.
  - **C — Do nothing:** integration test may not actually integrate every verb-family PR.
- **Decision:** B. PR 4 Task 10 now requires the pipeline to include at least one verb from each of PRs 2a, 2b, 2c, 2d; assertions must include `test_collection_invariants(result)`, per-member `test_invariants()`, and a `print()` snapshot.
- **Rationale:** keeps the implementer free to shape a coherent pipeline while making cross-PR coverage non-optional.

### Outcome

Implementation plan is approved. Two file-list and one task changes
in PR 1; one task tightening in PR 2b; one acceptance-criteria
expansion in PR 1; one spec edit in §IX.5 plus a plan closing-notes
note; one task tightening in PR 4. Ready to hand off to `/r-implement`
starting with PR 1.

---
