# Plan Review: survey-result-verbs — Pass 1 (2026-03-02)

---

### New Issues

#### Section: PR Map

No issues found.

---

#### Section: PR 1 — Passthrough Verbs + Test Infrastructure

---

**Issue 1: Test sections 23–26 placement contradicts spec**
Severity: REQUIRED
Violates spec Section VI (PR test section structure)

The spec (`plans/spec-survey-result-verbs.md` Section VI) places test sections
23–26 (drop_na primary happy path, filter `.by`, slice_min/max non-default args,
slice_sample over-sampling) under **PR 2 test sections**. The implementation plan
lists them as PR 1 acceptance criteria:

> "- [ ] Test sections 23–26: `drop_na()` primary happy path, `filter(.by)`,
> `slice_min`/`slice_max` non-default args, `slice_sample(replace = TRUE)`
> over-sampling"

This is a real tension: architecturally, testing PR 1 verbs' edge cases in PR 1
is the correct engineering decision — you want full edge case coverage in the
same PR that delivers the verbs. But the spec disagrees. This deviation is not
documented in `plans/claude-decisions-survey-result-verbs.md`.

Options:
- **[A] Document the deviation** — Add a decision entry to the decisions log
  noting that tests 23–26 are moved to PR 1 for architectural completeness;
  update the plan's PR 1 Files section to confirm this is intentional.
  Effort: low, Risk: low, Impact: eliminates implementer confusion.
- **[B] Reverse to match the spec** — Move sections 23–26 to PR 2 acceptance
  criteria (matching the spec). PR 1 ships with less edge case coverage.
  Effort: low, Risk: low, Impact: spec-plan consistency but leaves PR 1
  edge cases untested until PR 2.
- **[C] Do nothing** — The implementer encounters contradicting spec/plan and
  must guess.

**Recommendation: A** — The plan's decision (tests in PR 1) is the right
engineering call; it just needs to be documented as an explicit deviation.

---

**Issue 2: Internal contradiction — `test_result_meta_coherent()` PR 1 usage**
Severity: REQUIRED
Internal plan inconsistency

The plan's Implementation Notes section says:

> "Add all three test helpers in PR 1, even though `test_result_meta_coherent()`
> is **only exercised by PR 2 tests** — all infrastructure belongs together"

But the plan's PR 1 acceptance criteria directly contradicts this:

> "- [ ] `test_result_meta_coherent()` called after meta-coherence-sensitive
> blocks (3b, 3c)"

The spec confirms this contradiction: spec Section VI sections 3b and 3c
explicitly call `test_result_meta_coherent(r)` — so it IS exercised by PR 1
tests. The implementation notes are wrong. An implementer reading the notes
might believe `test_result_meta_coherent()` is untested in PR 1 and may
inadvertently skip those assertions in sections 3b/3c.

Options:
- **[A] Fix the implementation notes** — Change "only exercised by PR 2 tests"
  to "also exercised by PR 1 sections 3b and 3c."
  Effort: low, Risk: low, Impact: eliminates conflicting guidance.
- **[B] Do nothing** — Implementer may skip PR 1 meta-coherence assertions.

**Recommendation: A** — One-sentence fix; high clarity value.

---

**Issue 3: 98%/95% line coverage criterion absent from both PRs**
Severity: REQUIRED
Violates `testing-standards.md` ("PRs blocked below 95%")

Neither PR's acceptance criteria mention the line coverage requirement. The
`testing-standards.md` standard is: 98%+ target; PRs blocked below 95%.
Without an explicit criterion, the implementer has no gate to check coverage
before opening a PR. Given that this file (`R/verbs-survey-result.R`) is new
with all new helpers and all thirteen verb implementations, coverage must be
verified.

Options:
- **[A] Add coverage criterion to both PRs** — Add:
  `- [ ] devtools::test(filter = "verbs-survey-result") coverage ≥ 95%`
  (or equivalent `covr::package_coverage()` check).
  Effort: low, Risk: low, Impact: enforces the project-wide standard.
- **[B] Do nothing** — Coverage may drop below 95% without detection before
  the PR is opened; CI will catch it but wasted round-trip.

**Recommendation: A** — Standard criterion; zero implementation impact.

---

**Issue 4: Missing edge case test — "select() selects all columns"**
Severity: REQUIRED
Violates spec Section VI edge case table

The spec's edge case table (Section VI) lists:

> `| select() selects all columns | select | All meta unchanged; class preserved |`

No corresponding test section exists in the plan's PR 2 test sections (5–27).
The closest is section 16 (`select(result_means, -se)` which keeps most columns)
and section 19 (chained rename + select), but neither explicitly tests selecting
all columns with no pruning. For `select.survey_result`, this case exercises the
code path where `.prune_result_meta()` should be a no-op — confirming no
spurious meta modifications occur.

Options:
- **[A] Add a test section** — Add "Section 28: `select(result_means, everything())`
  — all columns kept; meta identical to input." One `test_that()` block.
  Effort: low, Risk: low, Impact: closes spec coverage gap.
- **[B] Do nothing** — Edge case from spec table untested; potential regression
  risk for "all columns selected" path.

**Recommendation: A** — Directly specified in the spec's edge case table.

---

**Issue 5: Missing edge case test — "drop_na() with no NAs in result"**
Severity: REQUIRED
Violates spec Section VI edge case table

The spec's edge case table lists:

> `| drop_na() with no NAs in result | drop_na | All rows preserved; meta unchanged |`

Section 23 covers the NA-injection happy path (actual NAs present). The
no-NA baseline (the function is a no-op when called on clean data) is not
covered. This is the other half of `drop_na()` correctness: it must pass
through cleanly when there is nothing to drop.

Options:
- **[A] Add a test section** — Extend section 23 or add "Section 29:
  `drop_na(result_means)` with no NAs injected — all rows preserved; class
  and meta identical." One assertion block.
  Effort: low, Risk: low, Impact: closes spec coverage gap.
- **[B] Do nothing** — Edge case from spec table untested; no-op path uncovered.

**Recommendation: A** — Directly specified in the spec's edge case table.

---

**Issue 6: `NEWS.md` missing from Files lists in both PRs**
Severity: REQUIRED
Violates Lens 5 (File Completeness)

Both PRs include this acceptance criterion:
- PR 1: `- [ ] Changelog entry: NEWS.md bullet added for passthrough verbs`
- PR 2: `- [ ] Changelog entry: NEWS.md bullet added for meta-updating verbs`

But `NEWS.md` is not listed in the **Files** sections of either PR. The Files
sections are the authoritative list of everything an implementer will touch.
When `NEWS.md` is listed only as a criterion (not as a file), the implementer
may forget to stage it for commit.

Options:
- **[A] Add `NEWS.md` to both Files sections** — One line in each PR's Files list:
  `- NEWS.md — add changelog bullet.`
  Effort: low, Risk: low, Impact: complete file inventory.
- **[B] Do nothing** — NEWS.md may be left unstaged; CI will pass but the
  changelog will be missing from the commit.

**Recommendation: A** — Files sections should list every file touched.

---

#### Section: PR 2 — Meta-Updating Verbs

No new issues beyond those already listed above (coverage criterion #3 applies
here too; edge case tests #4 and #5 are PR 2 sections that are missing).

---

#### Section: Implementation Notes

---

**Issue 7 (Suggestion): "All 9 non-mutate passthrough verbs" wording is ambiguous**
Severity: SUGGESTION

The plan says:

> "Passthrough verb pattern — all 9 non-mutate passthrough verbs"

Then separately says:

> "**`drop_na.survey_result` uses `data`, not `.data`**"

These two statements imply `drop_na` is both in the "all 9" group AND a special
case. The intent is: 8 verbs follow the exact pattern shown; `drop_na` deviates
only in argument name. Saying "all 9 use this pattern" then immediately carving
out an exception is confusing.

Options:
- **[A] Clarify wording** — Change heading to "Passthrough verb pattern — 8
  verbs (all except `drop_na`)"; keep the `drop_na` note as-is.
- **[B] Do nothing** — Minor confusion; implementer should catch it when reading
  both sections.

**Recommendation: A** — One-word fix; eliminates a potential misread.

---

**Issue 8 (Suggestion): Conditional snapshot criterion from spec not acknowledged**
Severity: SUGGESTION

The spec's PR 1 quality gate (Section IX) says:

> "Snapshot committed for `filter()` 0-row edge case **if dplyr issues a message**"

The plan's PR 1 acceptance criteria says:

> "- [ ] No snapshot committed (PR 1 has no error-path tests requiring snapshots)"

The plan's blanket no-snapshot rule silently overrides the spec's conditional
snapshot gate. The implementer should know to check whether dplyr 1.1.x+ issues
any message for a 0-row filter result, and commit a snapshot if so.

Options:
- **[A] Acknowledge the conditional** — Replace the no-snapshot criterion with:
  "No snapshot committed unless dplyr issues a message for the 0-row `filter()`
  edge case (per spec IX)."
- **[B] Do nothing** — If dplyr does issue a message, the implementer will miss
  it and the snapshot won't be committed.

**Recommendation: A** — Low effort; matches the spec's intent.

---

**Issue 9 (Suggestion): Spec Section VIII vs. Section IX ambiguity on `plans/error-messages.md`**
Severity: SUGGESTION

The spec contains a minor internal contradiction:

- **Section VIII:** "plans/error-messages.md does not need updating."
- **Section IX (Quality Gates):** "plans/error-messages.md — confirm no new
  classes added; update source file column for `surveytidy_error_rename_fn_bad_output`
  to include `R/verbs-survey-result.R`."

The implementation plan correctly follows Section IX (updates the source file
column). But an implementer may notice the contradiction when reading the spec
alongside the plan. Adding a one-sentence note in the decisions log would
prevent confusion.

Options:
- **[A] Add note to decisions log** — Clarify: "Section VIII says 'does not need
  updating' meaning no new error class row; Section IX correctly requires updating
  the source file column for the existing `surveytidy_error_rename_fn_bad_output`
  row. The plan follows Section IX."
- **[B] Do nothing** — Minor; implementer reads the plan and acts on the explicit
  acceptance criteria.

**Recommendation: A** — Low effort; preempts a spec-reading question.

---

**Issue 10 (Suggestion): `expected_class` derivation in section 1 loop not shown**
Severity: SUGGESTION

The plan describes the section 1 cross-type × cross-design loop and says
`test_result_invariants(result_after, expected_subclass)` must pass. But it
does not show how `expected_subclass` is derived from the `type` loop variable
(`"means"` → `"survey_means"`, `"freqs"` → `"survey_freqs"`, `"ratios"` →
`"survey_ratios"`). The spec does not show this mapping either.

This is a small implementer friction point. The mapping is obvious in
hindsight but not stated anywhere in the plan or spec.

Options:
- **[A] Add the mapping to the section 1 test description** — One sentence:
  "Use `paste0("survey_", type)` to derive `expected_class` from `type`."
- **[B] Do nothing** — Implementer infers the obvious mapping.

**Recommendation: A** — One line in the Implementation Notes; eliminates any
pause during implementation.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 6 |
| SUGGESTION | 4 |

**Total issues:** 10

**Overall assessment:** The plan is well-structured and closely mirrors the
finalized spec. Five of the six required issues are low-effort fixes (missing
criterion, missing file in file list, missing edge case tests). The most
substantive required issue is the undocumented deviation in test sections 23–26
placement (PR 1 vs. PR 2) — the plan's call is the right engineering decision
but needs a decision log entry. No blocking issues exist; the plan can be
implemented after the required fixes are addressed.
