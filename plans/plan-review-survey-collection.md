# Plan Review: Phase 0.7 — `survey_collection` Verb Dispatch

## Plan Review: Phase 0.7 — Pass 1 (2026-04-27)

### New Issues

#### Section: PR Map / Cross-PR

**Issue 1: PR 2c dependency rationale does not match its own scope**
Severity: REQUIRED
Violates Lens 2 — Dependency Ordering.

PR 2c declares `Depends on: PR 2b (so rename.survey_collection is on develop
when group-rename tests run)`. PR 2c's task list, acceptance criteria, and
notes mention no group-rename tests — those live entirely in PR 2b
(tasks 9–12). PR 2c's tests cover `group_by`, `ungroup`, `group_vars`, and
`is_rowwise` only. The stated dependency rationale is therefore false, which
makes it impossible for the implementer to evaluate whether the serial
ordering is actually load-bearing.

The likely real reason is task 15 (`is_rowwise` test "constructed via
per-member `rowwise()` call before `as_survey_collection`") — but per-member
`rowwise()` resolves to `rowwise.survey_base`/`rowwise.survey_result`, which
already exist on `develop`. Even that does not require PR 2b.

Options:
- **[A]** Replace the stated rationale with the actual one, OR drop the
  dependency and let PR 2c run parallel with PRs 2a/2b/2d (depending on
  PR 1 only).
- **[B]** If `is_rowwise` tests really do require `rowwise.survey_collection`
  on develop (they don't, per the existing per-member dispatch), state that.
- **[C] Do nothing** — implementer is left guessing whether the serial
  ordering is required and may break it without realizing.

**Recommendation: A** — verify by reading PR 2c's tests; either correct the
rationale or move PR 2c to depend on PR 1 only.

---

**Issue 2: `visible_vars` preservation is not asserted on non-select verbs**
Severity: REQUIRED
Violates Lens 4 — Spec Coverage.

Spec §IX.3 and `testing-surveytidy.md` both mandate: "After verbs other than
`select`/`relocate`, an existing `visible_vars` is preserved unchanged on
every member." This is a documented invariant and a regression risk
(`dplyr_reconstruct` paths historically drop `visible_vars`).

The plan does not list this assertion in the acceptance criteria or task
breakdown for any of:
- PR 2a: filter, filter_out, mutate, arrange, drop_na
- PR 2c: group_by, ungroup
- PR 2d: slice / slice_head / slice_tail / slice_min / slice_max / slice_sample

Options:
- **[A]** Add an explicit acceptance-criterion bullet to PRs 2a, 2c, 2d:
  "After applying the verb to a collection where every member has
  `visible_vars = c('y1','y2')`, every member still has the same
  `visible_vars`." Add a corresponding task line ("Write visible_vars
  preservation test").
- **[B]** Add it as a single dispatcher-level test in PR 1 instead, since
  the dispatcher is the layer that loops over members.
- **[C] Do nothing** — the invariant is in the spec but nothing in the plan
  forces a regression test. Coverage may pass and the invariant break.

**Recommendation: A** — per-verb tests are needed because not every verb
goes through the standard dispatcher (pull/glimpse don't), and per-verb
gives clearer failure attribution.

---

**Issue 3: `R/zzz.R` is a merge-conflict hotspot across PRs 2a/2b/2d**
Severity: REQUIRED
Violates Lens 2 — Dependency Ordering.

PRs 2a, 2b, and 2d all run in parallel after PR 1 and all modify `R/zzz.R`
to add `registerS3method()` calls. PR 1 task 41 mentions adding "the
placeholder comment block" (singular) to `R/zzz.R`. Three branches
inserting into the same comment block guarantees three-way merge conflicts
at integration time.

Options:
- **[A]** PR 1 pre-allocates four labelled placeholder blocks in `R/zzz.R`,
  one per verb-family PR (`# data-mask verbs`, `# tidyselect verbs`,
  `# grouping verbs`, `# slice verbs`), so each PR inserts inside its own
  block and conflict surface is zero.
- **[B]** Serialize the verb-family PRs (2a → 2b → 2d) instead of running
  parallel; conflicts disappear at the cost of throughput.
- **[C] Do nothing** — accept the rebase tax. Implementer rebases each
  PR onto whichever sibling lands first; manageable but wastes time.

**Recommendation: A** — pre-allocated blocks are nearly free in PR 1 and
eliminate the conflict surface entirely.

---

**Issue 4: `rowwise.survey_collection` has no test file ownership**
Severity: REQUIRED
Violates Lens 5 — File Completeness.

`rowwise.survey_collection` is *implemented* in PR 2b (per the file list:
`R/rowwise.R — MODIFIED: add rowwise.survey_collection`), but PR 2b's test
files list does not include `test-collection-rowwise.R` or any rowwise
coverage. Spec §IX.1 maps rowwise tests to `test-collection-group-by.R`,
which is a PR 2c file — but PR 2c only tests `is_rowwise`, not `rowwise`
itself.

This means rowwise.survey_collection ships with no dedicated tests in
either the implementing PR (2b) or the file-owning PR (2c).

Options:
- **[A]** PR 2b creates `test-collection-rowwise.R` and tests
  `rowwise.survey_collection` directly there. PR 2c's
  `test-collection-group-by.R` covers only the four grouping methods.
- **[B]** PR 2b adds rowwise tests inline in `test-collection-group-by.R`
  before that file exists, then PR 2c extends it. This crosses file
  ownership and conflicts with PR 2c's "NEW" status.
- **[C] Do nothing** — rowwise lands untested in PR 2b; PR 2c never adds
  the missing tests.

**Recommendation: A** — own the test file in the same PR that ships the
method. Update spec §IX.1's file mapping and PR 2b's file list to match.

---

**Issue 5: Test-file ambiguity for arrange/slice**
Severity: REQUIRED
Violates Lens 5 — File Completeness.

PR 2a creates `tests/testthat/test-collection-arrange-slice.R` ("arrange
portion only; slice rows added in PR 2d"). PR 2d's file list says
`tests/testthat/test-collection-arrange-slice.R — MODIFIED: ... rename to
test-collection-slice.R if cleaner`. The "if cleaner" leaves the final
filename undecided, creating two possible end states and two different
git-history shapes.

Options:
- **[A]** PR 2a creates `test-collection-arrange.R` (arrange only). PR 2d
  creates `test-collection-slice.R` (new file). Each PR owns one file;
  no rename, no ambiguity.
- **[B]** Commit to the combined name `test-collection-arrange-slice.R`
  in both PRs and remove the rename clause.
- **[C] Do nothing** — implementer picks at PR 2d time, possibly
  contradicting the spec's §IX.1 file map.

**Recommendation: A** — one PR, one new file is the cleaner default and
matches the per-verb test-file convention used by the rest of the package.

---

#### Section: PR 1 — Dispatcher

**Issue 6: PR 1 task 24 references "Issue 3" without locating it**
Severity: SUGGESTION
Violates Lens 3 — Acceptance Criteria.

Task 24: "Write a failing test that the pre-check sentinel class chain is
... NOT `inherits(cnd, 'rlang_error')` (Issue 3)." The bare "Issue 3"
reference is ambiguous — the decisions log has multiple sessions with
overlapping numbering (methodology-lock, spec-review Pass 1, Pass 2). Future
implementers will have to grep to find which Issue 3 is meant.

Options:
- **[A]** Replace with `(decisions-survey-collection.md, methodology-review
  Issue 12)` or whichever is correct.
- **[B] Do nothing** — solvable by grep, but takes implementer time.

**Recommendation: A** — fully qualified references are cheap.

---

**Issue 7: `.derive_member_seed()` placement contradicts code-style helper rule**
Severity: SUGGESTION
Violates Lens 1 — code-style.md helper-placement rule.

`code-style.md` §4 states: "Helper used in exactly 1 source file → defined
at the top of that file, before its first call site. Helper used in 2+
source files → `R/utils.R`." `.derive_member_seed()` is consumed only by
`slice_sample.survey_collection` (R/slice.R, PR 2d) per spec §II.3.3 — a
single call site. PR 1 places it in `R/utils.R`.

Options:
- **[A]** Define `.derive_member_seed()` at the top of `R/slice.R` in PR 2d
  rather than in PR 1. PR 1 ships only the `.sc_*` wrappers in utils.R.
- **[B]** Keep it in utils.R and document the deviation: "kept with other
  collection-internal helpers because it ships in PR 1 ahead of its call
  site." Note the deviation in PR 1 notes.
- **[C] Do nothing** — the deviation is silent and may surface as a
  reviewer nit later.

**Recommendation: B** — moving to slice.R splits PR 1's "infrastructure"
boundary awkwardly. Document the deviation in PR 1's Notes section so it's
explicit.

---

#### Section: PR 2a — Data-mask verbs

**Issue 8: `drop_na` detection-mode footnote is contradictory then corrected**
Severity: SUGGESTION
Violates Lens 5 — clarity.

PR 2a Notes: "`drop_na` lives in `R/drop-na.R` and uses tidyselect for
column args — the spec at §II.4 says it uses `.detect_missing = 'class_catch'`.
Treat `drop_na` as the tidyselect verb in this PR: pass `'class_catch'` for
it. ... **Correction:** the spec puts `drop_na` in the data-mask PR (§XII
PR 2a) but uses class-catch detection."

The "Correction" reads like a self-edit left in the doc. The acceptance
criteria above use language like "data-mask verbs (with `.detect_missing =
'pre_check'`)" but `drop_na` uses class-catch. A reader skimming acceptance
criteria will think `drop_na`'s test must trigger the pre-check sentinel
path; it actually must trigger the class-catch path.

Options:
- **[A]** Rewrite the note as a single coherent paragraph; remove the
  "Correction:" framing. State plainly: "`drop_na` is the only verb in
  this PR using `class_catch` detection (per spec §II.4); its missing-var
  tests must trigger `vctrs_error_subscript_oob`, not the pre-check
  sentinel." Update task 18 to make this explicit for `drop_na`.
- **[B] Do nothing** — the note is technically accurate even if confusing.

**Recommendation: A** — coherence cost is one paragraph; ambiguity cost
is one wrong test.

---

#### Section: PR 2b — Tidyselect verbs

**Issue 9: PR 2b task 11 sets `coll@groups = 'psu'` directly, violating S7 G1**
Severity: REQUIRED
Violates Lens 3 — Acceptance Criteria (test setup must be runnable).

Task 11: "use `make_test_collection()` (subclass-mixed). Set
`coll@groups = 'psu'`. Call `rename_with(coll, toupper, .cols = where(is.factor))`."

S7 runs the class validator after every `@<-` assignment. The G1 invariant
requires `coll@groups == every member's @groups`. `make_test_collection()`
returns a collection with `coll@groups = character(0)` and every member's
`@groups = character(0)`. The assignment `coll@groups <- "psu"` would fail
G1 immediately because no member has been updated.

Either: (a) use `attr(coll, "groups") <- "psu"` plus per-member update via
`attr<-` (the bypass pattern documented in CLAUDE.md for rename), or
(b) call `group_by(coll, psu)` — but `group_by.survey_collection` is in
PR 2c and not yet on PR 2b's branch, so not available.

Options:
- **[A]** Replace task 11's setup with the explicit `attr<-` bypass:
  "Construct a grouped fixture by `attr(coll, 'groups') <- 'psu'` and a
  per-member loop that does the same; then call `S7::validate(coll)` to
  confirm validity."
- **[B]** Construct the grouped fixture via per-member `dplyr::group_by`
  before passing to `as_survey_collection()` — that path runs the
  member-level group_by (which exists on develop) and the collection
  constructor sees consistent `@groups`.
- **[C] Do nothing** — implementer hits the validator failure mid-test
  and either shortcuts the assertion or invents a workaround.

**Recommendation: B** — uses only develop-stable APIs; matches the same
"build via inline construction" idiom the plan uses elsewhere.

---

**Issue 10: V9 distinct test "build via inline construction" lacks the recipe**
Severity: SUGGESTION
Violates Lens 3 — Acceptance Criteria (verifiable means buildable).

Task 14: "make_test_collection() where two members literally share an
identical row (build via inline construction); after
distinct.survey_collection(coll), that row appears in BOTH members' @data
(no cross-survey collapse)."

`make_test_collection()` produces seeded random data — there's no parameter
to force shared rows. "Inline construction" is a hint, not an instruction.
The implementer has to invent the fixture (manually edit one member's
`@data` after the fact, build a custom collection, etc.).

Options:
- **[A]** Spell out the recipe: "Construct three plain data.frames where
  rows 1 and 2 of df1 are identical to row 1 of df2. Build three
  `survey_taylor` objects via `surveycore::as_survey()`; pass to
  `surveycore::as_survey_collection()`. After `distinct(coll)`, member 1
  has 1 row, member 2 has 1 row (each member's internal duplicates
  collapsed); the cross-member duplicate is preserved across members."
- **[B] Do nothing** — implementer figures it out, possibly testing the
  wrong scenario.

**Recommendation: A** — V9 is the load-bearing semantics of distinct on
collections; an under-specified test for V9 is risky.

---

**Issue 11: PR 2c task 7 G1b safety net is hand-wavy**
Severity: SUGGESTION
Violates Lens 3 — Acceptance Criteria.

Task 7 (PR 2c): "Write a failing test that G1b safety net fires when
grouping by a column missing on one member under `.if_missing_var = 'skip'`
— either the dropped member is the one missing the col (no G1b violation)
or the validator catches it. Carefully construct."

"Carefully construct" doesn't tell the implementer which scenario to
build. If skipping drops the offending member, G1b is satisfied (no
violation, nothing to test). If skipping somehow leaves the offending
member, G1b fires. The test must construct the latter case, which is
delicate.

Options:
- **[A]** Spell out the scenario explicitly: "Build a collection where
  members A, B, C all have column `region`, but only member B has
  column `state`. Group by `region` (succeeds for all). Group by
  `state` under `.if_missing_var = 'skip'`: A and C are skipped, B
  remains; G1b is satisfied (B has @groups = 'state', collection has
  @groups = 'state'). Now test: group by `c(state, missing_col)` —
  every member is skipped → empty-result error fires before G1b is
  reached. Document that G1b is structurally unreachable through normal
  dispatch and the safety net is defense-in-depth."
- **[B] Do nothing** — implementer writes a trivial test and the safety
  net never gets exercised.

**Recommendation: A** — defense-in-depth tests should exercise the actual
defense.

---

#### Section: PR 2d — Slice verbs

**Issue 12: PR 2d task 7 "signature is conditional" is misleading**
Severity: SUGGESTION
Violates Lens 5 — clarity.

Task 7 (PR 2d slice_sample): "signature is conditional. When
`weight_by = NULL`, `.if_missing_var` is omitted. When `weight_by` is
non-NULL, `.detect_missing = 'pre_check'`."

R function signatures are static — they cannot vary by argument value at
runtime. The spec §III.2 must mean either: (a) `.if_missing_var` is in the
signature but ignored when `weight_by = NULL`, or (b) some
internal-dispatch dynamism. The plan task should say which.

Options:
- **[A]** Rewrite as: "Signature includes `.if_missing_var` but the
  argument is only consulted when `weight_by` is non-NULL. When
  `weight_by = NULL`, `.detect_missing` is fixed to `'none'` (no
  data-mask path); when non-NULL, `.detect_missing = 'pre_check'` and
  `.if_missing_var` is honored."
- **[B] Do nothing** — implementer reads spec §III.2 directly.

**Recommendation: A** — paraphrase the spec accurately or drop the task
text and reference the spec directly.

---

#### Section: PR 3 — Collapsing verbs

**Issue 13: PR 3 task 2 "Build the dispatcher call manually" misleads**
Severity: SUGGESTION
Violates Lens 5 — clarity.

Task 2: "Build the dispatcher call manually since `pull` is collapsing —
do NOT use the standard `.dispatch_verb_over_collection` for the rebuild
step (no collection output)."

The first clause says "build the dispatcher call manually." The second
clause says "do NOT use the dispatcher." These are contradictory — `pull`
does not call the dispatcher at all; it iterates per-member with its own
class-catch handler (per spec §V.1 and the PR Notes section).

Options:
- **[A]** Rewrite: "`pull` does NOT use `.dispatch_verb_over_collection`.
  Iterate per-member directly, replicating the class-catch handler
  inline. Collect results via `vctrs::vec_c()`. The duplicated handler
  is acceptable per `engineering-preferences.md` §3 (see PR Notes)."
- **[B] Do nothing** — solvable by reading the Notes section, but the
  task as written is internally contradictory.

**Recommendation: A** — clean up the task wording.

---

#### Section: PR 4 — Joins, re-exports, polish

**Issue 14: `print.survey_collection` regression check is manual-only**
Severity: SUGGESTION
Violates Lens 3 — Acceptance Criteria.

Task 11 (PR 4): "Manually verify `print.survey_collection` shows `@id`,
`@if_missing_var`, and `@groups` after a verb pipeline. Add a note in the
test file (no automated assertion — visual check)."

A manual check has zero regression value. Future verb additions or
constructor changes can silently break print rendering and CI won't
notice.

Options:
- **[A]** Add `expect_snapshot(print(coll))` after the pipeline, alongside
  the dual-invariant assertion. Snapshot the rendered output; updates
  go through `snapshot_review()` like every other surveytidy snapshot.
- **[B]** Add a structured assertion: capture print output via
  `capture.output()` and `expect_match()` against literal strings for
  `coll@id`, `coll@if_missing_var`, `coll@groups`. Less brittle than
  full snapshot.
- **[C] Do nothing** — visual check only; rendering regressions slip
  through.

**Recommendation: A** — snapshot is the standard surveytidy pattern for
print output and integrates with existing tooling.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 5 |
| SUGGESTION | 9 |

**Total issues:** 14

**Overall assessment:** The plan is structurally sound — PR boundaries
match the verb-family architecture in the spec, every spec function has a
PR, and the TDD task breakdown is granular enough for `r-implement`. The
five REQUIRED issues are all clarification or wiring fixes (dependency
rationale, missing test coverage assertion, merge-conflict surface, file
ownership for rowwise tests, test-file naming) — none of them require
spec changes or rearchitecting. After resolving them in Stage 3, the plan
is ready to implement.

---

## Plan Review: Phase 0.7 — Pass 2 (2026-04-28)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | PR 2c dependency rationale does not match its own scope | ✅ Resolved (PR 2c now `Depends on: PR 1` only) |
| 2 | `visible_vars` preservation not asserted on non-select verbs | ✅ Resolved (PRs 2a, 2c, 2d each add explicit acceptance criterion + task) |
| 3 | `R/zzz.R` is a merge-conflict hotspot across PRs 2a/2b/2d | ✅ Resolved (PR 1 task 38 pre-allocates four labelled blocks) |
| 4 | `rowwise.survey_collection` has no test file ownership | ✅ Resolved (PR 2b creates `test-collection-rowwise.R`) |
| 5 | Test-file ambiguity for arrange/slice | ✅ Resolved (PR 2a creates `test-collection-arrange.R`, PR 2d creates `test-collection-slice.R`) |
| 6 | PR 1 task references "Issue 3" without locating it | ✅ Resolved (now reads "decisions-survey-collection.md, 2026-04-27 Stage 3 spec-review resolution, Q: Issue 3") |
| 7 | `.derive_member_seed()` placement contradicts code-style helper rule | ✅ Resolved (now at top of `R/slice.R` in PR 2d) |
| 8 | `drop_na` detection-mode footnote is contradictory then corrected | ✅ Resolved (Notes section now coherent; "Correction:" framing removed) |
| 9 | PR 2b task 11 sets `coll@groups = 'psu'` directly, violating S7 G1 | ✅ Resolved (now uses per-member `dplyr::group_by` + `as_survey_collection` recipe) |
| 10 | V9 distinct test "build via inline construction" lacks the recipe | ✅ Resolved (task 14 spells out the three-data.frame recipe explicitly) |
| 11 | PR 2c task 7 G1b safety net is hand-wavy | ✅ Resolved (now Part 1 / Part 2 with concrete `attr<-` bypass recipe) |
| 12 | PR 2d task 7 "signature is conditional" is misleading | ✅ Resolved (task 9 now describes runtime branching on `is.null(weight_by)` correctly) |
| 13 | PR 3 task 2 "Build the dispatcher call manually" misleads | ✅ Resolved (task 2 now plainly says `pull` does NOT use the dispatcher and iterates per-member directly) |
| 14 | `print.survey_collection` regression check is manual-only | ✅ Resolved (PR 4 task 11 now uses `expect_snapshot(print(coll))`) |

All 14 prior issues resolved.

### New Issues

#### Section: PR Map / Cross-PR

**Issue 15: `R/rowwise.R` is a merge-conflict hotspot between PRs 2b and 2c**
Severity: REQUIRED
Violates Lens 2 — Dependency Ordering (and same root cause as resolved
Pass 1 Issue 3 for `R/zzz.R`).

PR 2b's file list includes `R/rowwise.R — MODIFIED: add rowwise.survey_collection`
(line 422). PR 2c's file list includes `R/rowwise.R — MODIFIED: add
is_rowwise.survey_collection one-liner` (lines 648–649). Both PRs depend
on PR 1 only and run in parallel. Both insert new function definitions
into the same source file. This will produce a merge conflict at
integration time — the same defect Pass 1 Issue 3 identified for
`R/zzz.R` and which was solved by pre-allocating named placeholder
blocks in PR 1.

Pass 1 Issue 3's resolution explicitly listed `R/zzz.R` and assumed
verb-family files (`R/filter.R`, `R/select.R`, etc.) would not collide
because each PR owns its own verbs. `R/rowwise.R` is the exception:
both `rowwise.survey_collection` (a dispatching verb, PR 2b) and
`is_rowwise.survey_collection` (a non-dispatching one-liner, PR 2c)
live in `R/rowwise.R`.

Options:
- **[A]** PR 1 also pre-allocates two labelled placeholder blocks in
  `R/rowwise.R`: `# ── rowwise.survey_collection (PR 2b) ──` and
  `# ── is_rowwise.survey_collection (PR 2c) ──`. Each PR inserts inside
  its own block. Symmetric with the `R/zzz.R` solution; near-zero cost.
- **[B]** Move `is_rowwise.survey_collection` into `R/group-by.R`
  (where the rest of PR 2c's verbs already live) — all four PR 2c
  methods would then share one file. Update PR 2c's file list and
  spec §II.1 to match. Trade-off: violates §II.1's "each verb lives
  where its survey_base sibling already lives" rule, since the
  `survey_base` rowwise method is in `R/rowwise.R`.
- **[C]** Serialize PR 2c after PR 2b (change PR 2c's `Depends on:`
  to `PR 1, PR 2b`). Removes parallelism; cost is throughput.
- **[D] Do nothing** — accept the rebase tax. Implementer rebases
  whichever PR lands second.

**Recommendation: A** — directly mirrors the established Pass 1
solution for `R/zzz.R`. Add the pre-allocated blocks to PR 1's task
list (alongside the existing `R/zzz.R` block setup) and reference
them from PRs 2b and 2c's file lists.

---

#### Section: PR 1 — Dispatcher

**Issue 16: PR 1 acceptance criteria omit half of the §IX.4 dispatcher tests**
Severity: SUGGESTION
Violates Lens 3 — Acceptance Criteria.

PR 1's "covers every §IX.4 bullet" criterion (lines 52–55) explicitly
lists only four items: env-aware pre-check substeps, internal `@groups`
regression catch, sentinel class chain pin, typed
`surveytidy_message_collection_skipped_surveys`. Spec §IX.4 contains
seven bullets:

1. Names and order preserved (and skipped removed without reordering)
2. `@groups` sync correctness when a per-member verb updates `@groups`
3. Re-raise with `parent = cnd` produces a chain visible via
   `rlang::cnd_chain()`
4. Dispatcher does not call `surveycore::.dispatch_over_collection()`
5. Env-aware pre-check substeps (5 sub-bullets)
6. Internal `@groups` regression catch
7. Sentinel class chain
8. Typed skipped-surveys message

Items 1–4 are not in the acceptance-criteria summary. Tasks 33–35 do
exercise items 3 and 4, but the acceptance bullet should match the
spec verbatim or list every bullet — otherwise a reviewer scanning the
checklist could approve a PR missing items 1, 2, and 3.

Options:
- **[A]** Rewrite the bullet to enumerate all seven §IX.4 items, or
  replace with "covers all 7 bullets in spec §IX.4 (verify by
  checklist)" and add the 7-item checklist underneath.
- **[B] Do nothing** — the "every §IX.4 bullet" wording is technically
  a catchall; reviewers can cross-reference the spec.

**Recommendation: A** — acceptance criteria are the reviewer's
checklist; making them complete is cheap.

---

#### Section: PR 2b — Tidyselect verbs

**Issue 17: Task 11 `rename_with` fixture cannot trigger partial resolution as written**
Severity: REQUIRED
Violates Lens 3 — Acceptance Criteria (test fixture must be runnable
as described).

Task 11 (lines 534–547) instructs the implementer to call
`rename_with(coll, toupper, .cols = where(is.factor))` and asserts:
"On members where `psu` resolves as factor, the rename map includes
`psu`; on members where it doesn't, the rename is partial."

But the recipe constructs members via `make_test_collection`-style
helpers (`make_survey_data` → `as_survey`). `make_survey_data` produces
`psu` as `paste0("psu_", psu_index)` (character) — see
`tests/testthat/helper-test-data.R` line 81. There are no factor
columns in the default fixture: every column is numeric, character,
or logical. `where(is.factor)` therefore selects nothing on every
member, the rename map is empty for every member, and the partial-
rename scenario the task is supposed to test never triggers. The
"failing pre-flight test" will instead pass with no partial-rename,
masking a regression in the helper.

Options:
- **[A]** Add an explicit step before `group_by`: convert `psu` to
  a factor in member A only (e.g., `m1@data$psu <- factor(m1@data$psu)`
  via the `attr<-` bypass + `S7::validate()` pattern). Members B and C
  retain character `psu`. Then `where(is.factor)` resolves to `psu` in
  A but not B/C, triggering the partial-rename scenario.
- **[B]** Rewrite the test to use `.cols = "psu"` (explicit string)
  on a fixture where one member's `psu` was renamed away after
  construction. Requires its own bypass setup.
- **[C]** Use a different `.cols` predicate where `make_survey_data`
  produces heterogeneity naturally — but the helper produces uniform
  columns across members, so this option does not exist without
  fixture modification.
- **[D] Do nothing** — the test runs but does not exercise the
  intended scenario; the pre-flight error class
  `surveytidy_error_collection_rename_group_partial` ships with no
  effective test coverage of its primary justification (per spec §IV.4
  reachability note).

**Recommendation: A** — minimal fixture change; matches the spec's
example ("`.cols = where(is.factor)` could resolve to `psu` in member
A (factor-typed) and not in member B (numeric)") which presupposes
the implementer creates the asymmetric typing.

---

#### Section: Cross-spec consistency

**Issue 18: Coverage target in plan does not match spec §IX.5**
Severity: SUGGESTION
Violates Lens 4 — Spec Coverage.

Spec §IX.5 (line 1516) states: "98%+ line coverage on every new file."
Spec §X (line 1533) states: "≥98% line coverage; ≥95% on every new
file." These two spec sections contradict each other.

The plan adopts the §X reading: PR 1 sets ≥98% on `R/collection-dispatch.R`;
PRs 2a/2b/2c/2d/3/4 set ≥95% on each modified file. A reviewer applying
§IX.5 strictly would reject those PRs.

This is primarily a spec-internal inconsistency, not a plan defect, but
it surfaces in the plan because the plan must pick one target. Either
the spec needs reconciliation (likely: §IX.5 is the looser intent
mis-stated; §X is correct), or the plan should adopt the stricter §IX.5.

Options:
- **[A]** Reconcile in the spec — change §IX.5 to "98%+ overall;
  ≥95% on each new file" (matching §X). The plan stays as written.
- **[B]** Tighten the plan to ≥98% per new file (matches §IX.5 as
  literally written). Risks PR rejection if a verb file's natural
  coverage lands at 96–97% due to one defensive branch.
- **[C] Do nothing** — plan and spec disagree silently; reviewer
  applies whichever is convenient.

**Recommendation: A** — acceptable for the plan, but flag to the
spec author for reconciliation. Add a one-line note in the plan's
"Closing notes" section pointing to the resolution.

---

#### Section: PR 4 — Joins, re-exports, polish

**Issue 19: Cross-verb integration test composition is under-specified**
Severity: SUGGESTION
Violates Lens 3 — Acceptance Criteria.

PR 4 task 10: "build `make_test_collection()`, pipe through 4–5
verbs from different families (e.g., `coll |> filter(...) |>
select(...) |> group_by(...) |> mutate(...)`), assert the final
collection is well-formed."

The example uses 4 verbs from 4 different family PRs (filter→2a,
select→2b, group_by→2c, mutate→2a), which is good — but several
gaps remain:

1. No slice-family verb is in the example pipeline, so PR 2d is not
   integration-tested here. The "4–5 verbs from different families"
   wording could be read as not requiring a slice variant.
2. No `pull` or `glimpse` (PR 3) is integration-tested in this
   pipeline (collapsing verbs end the pipeline; reasonable to defer
   them but should be explicit).
3. No `rename` is in the pipeline — the group-rename pre-flight in
   PR 2b would not be exercised in the integration test.
4. Task 10 leaves "well-formed" undefined; task 11 fills that with a
   snapshot of `print()`, but the dual-invariant assertion
   (`test_collection_invariants` + per-member `test_invariants`) is
   not explicitly required even though the plan's Closing Notes
   section calls this out as non-negotiable.

Options:
- **[A]** Specify the pipeline as: `make_test_collection() |>
  filter(y1 > 50) |> select(y1, y2, group) |> group_by(group) |>
  mutate(y_sum = y1 + y2) |> rename(yA = y1) |> slice_head(n = 5) |>
  ungroup()`. This touches every verb-family PR (2a/2b/2c/2d) and
  PR 4's joins (test separately). The dual-invariant assertion is
  required by the test_that block.
- **[B]** Keep the freedom but require: "the pipeline must include
  at least one verb from each of PRs 2a, 2b, 2c, 2d; assert dual
  invariants and snapshot."
- **[C] Do nothing** — the implementer picks; the integration test
  may not actually integrate every PR.

**Recommendation: B** — keeps flexibility for the implementer to
shape a coherent pipeline while guaranteeing every verb-family PR
is covered. Add to acceptance criteria.

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 2 |
| SUGGESTION | 3 |

**Total issues:** 5

**Overall assessment:** All 14 Pass 1 issues are resolved with
substantive concrete fixes — the plan is materially better than at
Pass 1. The two new REQUIRED issues are localized: a parallel-PR
merge-conflict surface in `R/rowwise.R` (mirroring the resolved Pass 1
`R/zzz.R` issue) and a fixture defect in PR 2b task 11 where the
partial-rename scenario the test claims to exercise cannot actually
trigger on the default helper data. Both are mechanical fixes — adding
two placeholder blocks in PR 1 and inserting one factor-conversion
step in the test recipe. The three suggestions are quality-of-checklist
improvements (acceptance-criteria completeness, coverage-target
reconciliation, integration-test pipeline composition). None of these
require spec changes or rearchitecting; the plan is ready to implement
once the two REQUIRED issues are addressed.

