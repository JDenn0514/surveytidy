## Plan Review: feature/joins — Pass 1 (2026-04-16)

### Section: PR Map

No issues found.

---

### Section: Phase 0 — Pre-implementation

**Issue 1: Task 1 description says "7 new classes" but 8 are needed**
Severity: REQUIRED

Task 1 explicitly lists only the 7 classes from §XV, then a separate "Implementation
Notes" section at the bottom of the plan says `surveytidy_error_reserved_col_name`
"must be added in Task 1 alongside the 7 other new classes." The task description
itself doesn't include this 8th class — it's buried 400 lines away. An implementer
who only reads Task 1 will miss it, and the pre-flight `error-class-auditor` will
block the PR.

The 8th class (`surveytidy_error_reserved_col_name`, source: `R/joins.R`, trigger:
`"..surveytidy_row_index.."` already in `names(x@data)`) comes from §IV, not §XV,
so it's easy to miss on a spec pass.

Options:
- **[A]** Move the class into Task 1's explicit "Errors to add" list and remove the
  redundant mention from Implementation Notes. — Effort: low, Risk: low, Impact:
  implementer can't miss it; error-class-auditor passes.
- **[B]** Leave the split location but add a `⚠️ Note: 8 classes total` callout
  to Task 1. — Effort: low, Risk: medium (easy to overlook a footnote).
- **[C] Do nothing** — Implementation Notes say to check, but the task description
  says "7 new classes" → implementer trusts the task count.

**Recommendation: A** — Task 1 must be self-contained; the error class belongs in
the error list, not a footnote.

---

### Section: Phase 1 — `left_join`

**Issue 2: S3 registration deferred to Phase 6 breaks the TDD red-green cycle in Phases 1–5**
Severity: BLOCKING

Every Phase 1–5 "confirm pass" task calls `devtools::test("test-joins")` and expects
the tests to pass via dplyr dispatch (e.g., `dplyr::left_join(d, y)`). But dplyr's
`UseMethod` only dispatches to `left_join.survey_base` if
`registerS3method("left_join", "surveycore::survey_base", ..., envir = asNamespace("dplyr"))`
has been called in `.onLoad()`. That registration is deferred to Phase 6 Task 23.

Consequences:
- Task 3 "confirm fail (expected: 'could not find function')" — wrong expectation.
  `dplyr::left_join` exists; without registration dplyr falls through to its default
  path, which calls the existing `dplyr_reconstruct.survey_base`. Some tests
  accidentally pass via that path without ever touching `left_join.survey_base`.
- Tasks 5, 9, 13, 17, 21 "confirm pass" — cannot be trusted because the tests may
  green through `dplyr_reconstruct` rather than the implemented method. The TDD cycle
  does not verify the actual method.
- Phase 6 Task 23 would then only be wiring up methods already "passing" tests — at
  which point nothing signals whether the registration is correct.

This is confirmed by examining `test-filter.R`: all tests call
`dplyr::filter(designs[[nm]], ...)` — they test through dplyr dispatch, not by
calling `filter.survey_base` directly. The joins tests will follow the same pattern.

Options:
- **[A]** Move each `registerS3method` call to the end of its corresponding
  implementation task. After Task 4 (implement `left_join`), add the `left_join`
  registration to `zzz.R` as part of the same task. Repeat for each phase. Phase 6
  becomes redundant and can be removed or reduced to a reexports-only step. —
  Effort: low (distribute existing steps), Risk: low, Impact: TDD red-green cycle
  works correctly end-to-end.
- **[B]** Change all Phase 1–5 tests to call the method directly
  (`left_join.survey_base(d, y)`) instead of via dplyr dispatch, and verify dispatch
  separately in Phase 6. — Effort: medium, Risk: medium (method-direct tests are
  weaker; they don't verify the full dispatch path), Impact: TDD cycle works but
  integration is weaker.
- **[C] Do nothing** — Phases 1–5 may pass via `dplyr_reconstruct` path; Phase 6
  wires up registration without any failing tests to confirm it's needed.

**Recommendation: A** — Move each registration to the task that implements the
corresponding function. The pattern is: implement → register → test. Phase 6 becomes
a documentation/reexports-only phase.

---

**Issue 3: `anti_join` domain AND formula — plan pre-negates mask in Step 2, then spec Step 3 also negates (double-negation bug)**
Severity: REQUIRED

The plan's Task 8 code block shows:
```r
new_mask <- seq_len(nrow(x@data)) %in% matched[["..surveytidy_row_index.."]]
# For anti_join: new_mask <- !new_mask
```
After this, `new_mask` for anti_join = `!(... %in% ...)` = TRUE for rows **not** in y.

The spec §IV Step 3 then shows:
```r
new_domain <- existing & !new_mask  # anti_join
```

Applied to the plan's pre-negated `new_mask`, this gives `existing & (rows IN y)` —
the **opposite** of the intended behavior. Anti_join would mark matched rows as
in-domain and unmatched rows as out-of-domain, reversing the entire semantic.

The spec's Step 3 formula is correct **only if** `new_mask` is not pre-negated
(TRUE = in y for both functions). The spec §IV Step 2 code block shows the negated
version as commentary ("For anti_join, the mask is negated in Step 3"), but the
phrase "in Step 3" means the negation happens in Step 3 via `!new_mask`. The plan
misreads this as "pre-negate before Step 3."

Options:
- **[A]** Remove the `# For anti_join: new_mask <- !new_mask` line from Task 8's
  code block. Keep Step 3 formula `existing & !new_mask` for anti_join unchanged
  (matches spec exactly). Both functions build `new_mask = ... %in% ...`; only the
  domain AND step differs. — Effort: low, Risk: low, Impact: correct behavior,
  matches spec.
- **[B]** Keep the pre-negation, change the domain AND formula for anti_join to
  `existing & new_mask` (remove the `!`). Both produce the same result but via
  different paths. — Effort: low, Risk: low, Impact: correct behavior, diverges
  slightly from spec wording.
- **[C] Do nothing** — implementer follows plan's pre-negation + spec's `!new_mask`
  → double-negation → anti_join has inverted behavior → all anti_join tests fail.

**Recommendation: A** — Align with spec exactly. Remove the pre-negation comment
from Task 8 and add a note that `new_mask` is always `... %in% ...` (TRUE = matched
by y) for both functions; the negation for anti_join happens in the domain AND step.

---

### Section: Phase 2 — `semi_join` + `anti_join`

**Issue 4: `inner_join` domain-aware mode uses the same row-index approach — missing reserved col name test**
Severity: REQUIRED

Spec §VI domain-aware Step 3 states: "Use the same row-index approach specified in
§IV (semi_join behavior rules Step 2) to determine which rows in x@data have a match
in y." §IV Step 2 explicitly requires the reserved col name guard: "If
`..surveytidy_row_index..` already exists in `names(x@data)`, error with
`surveytidy_error_reserved_col_name`."

The plan adds tests 13b (semi_join) and 13c (anti_join) for this error class but has
no corresponding test for inner_join domain-aware mode. Since the spec explicitly
cross-references the §IV row-index procedure (including its guard), the error is
reachable via inner_join too.

`testing-surveytidy.md` requires the dual pattern for all user-facing errors. The
acceptance criteria say "All user-facing errors tested with dual pattern" — this
error class, triggered by inner_join, is untested.

Options:
- **[A]** Add test 23e: `inner_join()` [domain-aware] with `x@data` containing
  `"..surveytidy_row_index.."` → `surveytidy_error_reserved_col_name`; dual pattern.
  Insert into Task 14's test template. — Effort: low, Risk: low, Impact: complete
  error coverage; acceptance criterion satisfied.
- **[B]** Annotate that inner_join re-uses semi_join's guard function and the guard
  is already covered by tests 13b/13c (indirect coverage via shared helper). —
  Effort: low, Risk: medium (the guard fires in the inner_join call frame, not
  semi_join's; snapshot may differ).
- **[C] Do nothing** — error class has a reachable code path in inner_join that is
  never tested; coverage of `R/joins.R` < 98%.

**Recommendation: A** — Add test 23e; it's a one-block dual-pattern test and closes
the coverage gap.

---

### Section: Phase 3 — `bind_cols`

No new issues found.

---

### Section: Phase 4 — `inner_join`

No additional issues beyond Issue 4 above.

---

### Section: Phase 5 — `right_join`, `full_join`, `bind_rows`

**Issue 5: Test 30 missing dual-pattern annotation**
Severity: REQUIRED

Tests 27, 28, and 29 in Task 18's template explicitly say "Dual pattern." Test 30
("All survey × survey combinations → `surveytidy_error_join_survey_to_survey`") does
not. Every test in this section triggers `surveytidy_error_join_survey_to_survey`,
which is a user-facing error class. `testing-surveytidy.md` and the acceptance
criteria both require the dual pattern for all user-facing errors.

Options:
- **[A]** Add "Dual pattern" to the test 30 comment block in Task 18. — Effort:
  trivial, Risk: none, Impact: acceptance criterion satisfied.
- **[B]** Document test 30 as an explicit exception (one class, multiple call sites;
  class already snapshotted in test 6 — deduplicate). — Effort: low, Risk: low
  (snapshots are per-function call site, not per-class; a test 6 snapshot of
  `left_join(d, survey)` does not cover `right_join(d, survey)` etc.).
- **[C] Do nothing** — test 30 passes `expect_error(class=)` but never snapshots;
  any message regression goes undetected.

**Recommendation: A** — trivial fix; brings test 30 in line with 27–29.

---

### Section: Phase 6 — Wire up S3 registration and re-exports

This section becomes redundant for the registration block if Issue 2 (BLOCKING) is
resolved by moving registrations into Phases 1–5. The re-exports step (Task 24) and
the `@name`/`@rdname` roxygen pattern remain correct and should be retained.

---

### Section: Phase 7 — Final quality checks

No issues found.

---

### Section: Acceptance Criteria

**Issue 6: Edge cases from spec §XII edge case table not covered by tests 1–30**
Severity: REQUIRED

Spec §XII lists an explicit edge case table. Two entries have no test:

1. **`y` has 0 rows** — for `left_join`: "no new rows; all survey rows kept." No
   test verifies that an empty `y` does not trigger the row-expansion guard (zero-row
   `y` has no duplicate keys, so no error; result should be the original survey with
   all NAs for new columns). For `semi_join`: test 11 covers "all rows unmatched"
   but uses a non-matching `y` with rows; an empty `y` (0 rows) is a distinct edge
   case that may exercise different code paths.
2. **`y` has 0 columns** — for `left_join` and `bind_cols`: "no new columns; survey
   unchanged." No test verifies that joining with a column-free frame is a no-op.

`engineering-preferences.md` says "Handle more edge cases, not fewer."
`testing-standards.md` says "When unsure whether an edge case needs a test, write
the test."

Options:
- **[A]** Add test sections 31–32 (or inline within existing test blocks) covering
  0-row `y` for `left_join`/`semi_join`/`anti_join`, and 0-column `y` for
  `left_join`/`bind_cols`. — Effort: low, Risk: none, Impact: spec §XII fully
  exercised; potential regression surface closed.
- **[B]** Add a comment to the plan acknowledging the spec edge cases and explicitly
  marking them as out-of-scope for this PR, with a follow-up issue filed. — Effort:
  low, Risk: low if these behaviors are trivially correct; Risk: medium if any guard
  fires unexpectedly on empty inputs.
- **[C] Do nothing** — edge cases exist in the spec, are not tested; coverage may
  still hit 98% (the happy path runs those code paths), but zero-row/zero-col
  behavior is never explicitly verified.

**Recommendation: A** — these are one-line constructions
(`y <- data.frame(id = integer(0))`) and each takes a single `test_that` block;
the spec lists them explicitly.

---

### Section: Implementation Notes

**Issue 7: "Dual pattern for the warning" terminology in test 4 is ambiguous**
Severity: SUGGESTION

Task 2's test template says:
`# 4. left_join() — design variable column in y → warns + dropped — Dual pattern for the warning`

"Dual pattern" in `testing-surveytidy.md` is defined for errors (`expect_error(class=)`
+ `expect_snapshot(error=TRUE)`). The testing standard for warnings is:
`expect_warning(class = ...)` only. There is no established "dual pattern for
warnings."

The term creates uncertainty about whether an implementer should also add
`expect_snapshot(warning = TRUE, ...)` for test 4.

Options:
- **[A]** Replace "Dual pattern for the warning" with:
  `expect_warning(class = "surveytidy_warning_join_col_conflict")` and assert that
  the returned design has the conflicting column dropped (verifying the "warn + drop"
  behavior). — Effort: trivial, Risk: none, Impact: implementer knows exactly what
  to write.
- **[B]** Extend the testing standard to define a "dual pattern for warnings" (add
  `expect_snapshot(warning=TRUE)` requirement) and update the plan accordingly. —
  Effort: medium (requires testing-standards.md update), Risk: scope creep.
- **[C] Do nothing** — ambiguity about warning testing for this feature; inconsistent
  implementations likely.

**Recommendation: A** — replace the loose term with the precise assertion.

---

**Issue 8: `.check_join_row_expansion` signature extension decision not in an explicit task**
Severity: SUGGESTION

The Implementation Notes say to extend the helper signature to
`(original_nrow, new_nrow, by_label = NULL)` and "log this in `decisions-joins.md`."
No task in the plan performs this log step. The `decisions-joins.md` file has been
maintained carefully through Stages 2–4; this extension is an implementation-level
decision that belongs there.

Options:
- **[A]** Add one sentence to Task 10 (the first task that uses
  `.check_join_row_expansion` in Phase 3): "Note the signature extension
  `(original_nrow, new_nrow, by_label = NULL)` in `decisions-joins.md`." — Effort:
  trivial, Risk: none, Impact: decisions log is complete; future phases can
  reference it.
- **[B]** Leave it in Implementation Notes; it's already discoverable. — Effort:
  none, Risk: low (easy to forget; decisions log ends up incomplete).

**Recommendation: A** — one sentence; keeps `decisions-joins.md` as the
authoritative log of all spec deviations.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 5 |
| SUGGESTION | 2 |

**Total issues: 8**

**Overall assessment:** The plan has one critical structural flaw — S3 registration
deferred to Phase 6 breaks the TDD cycle for all five preceding implementation
phases, meaning "confirm pass" tasks cannot be trusted. Fix Issue 2 first. Issue 3
(anti_join double-negation bug) would produce silently inverted behavior that tests
would catch, but catching it after implementation is more costly than fixing the plan
now. Five total blocking/required issues must be resolved before implementation
starts.

---

## Plan Review: feature/joins — Pass 2 (2026-04-17)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | Task 1 says "7 classes" but 8 are needed | ⚠️ Still open |
| 2 | S3 registration deferred to Phase 6 breaks TDD red-green cycle | ⚠️ Still open |
| 3 | anti_join double-negation bug in Task 8 code block | ⚠️ Still open |
| 4 | inner_join domain-aware missing reserved col name test | ⚠️ Still open |
| 5 | Test 30 missing dual-pattern annotation | ⚠️ Still open |
| 6 | Spec §XII edge cases (0-row y, 0-col y) not covered | ⚠️ Still open |
| 7 | "Dual pattern for the warning" terminology in test 4 is ambiguous | ⚠️ Still open |
| 8 | `.check_join_row_expansion` signature extension not in explicit task | ⚠️ Still open |

### New Issues

#### Section: Phase 4 — `inner_join`

**Issue 9: Test 23d description contradicts domain-aware Step 6 row expansion guard**
Severity: BLOCKING
Violates spec internal consistency (§VI Step 6 vs. §XII test 23d).

The plan's test 23d says:
```
# 23d. inner_join() [domain-aware] — duplicate keys in y collapse to single
#      TRUE per survey row (same as semi_join; row count unchanged)
```

"Row count unchanged" implies a successful join with no error. But the plan's own
Task 16 Step 6 says:

> "guard row expansion; ... .check_join_row_expansion(nrow(x@data), nrow(result)) before writing the result back"

And the spec's §VI domain-aware Step 6 says explicitly:

> "If y has duplicate keys, this left_join can expand x@data the same way it does
> in left_join.survey_base; this guard prevents silent row multiplication even in
> domain-aware mode. Error class: surveytidy_error_join_row_expansion."

The spec's own error table (§VI) lists `surveytidy_error_join_row_expansion` with
trigger "Duplicate keys in y would expand row count" and mode "**Both modes**."

The conflict: in domain-aware mode, the MATCH MASK step (Step 3, using
`dplyr::semi_join`) correctly collapses duplicates to a single TRUE per x row.
But Step 6 then runs `dplyr::left_join(x@data, y, ...)` with the original (still
duplicate-keyed) y. That left_join WOULD expand rows. The guard fires. Error.

An implementer writing test 23d as described ("row count unchanged") would:
1. Write a test expecting success with unchanged row count.
2. Implement faithfully per Task 16 Step 6 (with the guard).
3. The guard fires → test fails with a row-expansion error the test doesn't expect.

The implementer is stuck: the test says "no error" but the spec steps say "guard fires."

This conflict originates in the spec (§XII test 23d vs. §VI Step 6 text) and was
carried into the plan without resolution.

Two coherent resolutions:

Options:
- **[A]** Change test 23d to expect `surveytidy_error_join_row_expansion` (dual
  pattern). This makes test 23d the domain-aware equivalent of test 24d, and the
  plan is internally consistent: duplicate keys in y → row expansion error in BOTH
  modes. — Effort: low, Risk: low, Impact: consistent with §VI and both error table
  entries.
- **[B]** Add a deduplication step before the left_join in domain-aware mode (e.g.,
  `y_distinct <- dplyr::distinct(y, across(resolved_by))`) so the match mask and
  the left_join use the same deduplicated y. Row count stays unchanged; test 23d
  as written is correct. This requires a spec amendment to §VI Step 6 and removing
  "Both modes" from the §VI error table. — Effort: medium (spec edit + implementation
  change), Risk: medium (adds a silent y-deduplication step not currently in spec).
- **[C] Do nothing** — implementer hits this inconsistency mid-implementation,
  must guess the intent, and may choose the wrong path.

**Recommendation: A** — "Error on duplicate keys, both modes" is already the
declared contract (§VI error table). Changing test 23d to match that contract
requires one line. Option B would change the contract silently, violating
explicit-over-clever.

---

#### Section: Phase 5 — `right_join`, `full_join`, `bind_rows`

No new issues beyond prior Pass 1 items.

---

#### Section: Phase 4 (continued) — Acceptance Criteria

**Issue 10: `@groups` preservation check missing from test 24 acceptance criteria**
Severity: SUGGESTION
The acceptance criteria list "@groups preservation asserted in tests 8, 9, 14, 18, 23."
Test 24 (inner_join physical mode — the happy-path test for that mode) is absent from
this list. The spec §XI table says "@groups: Preserved from x" for inner_join physical
mode. There is no reason to exempt test 24 from the @groups assertion.

Options:
- **[A]** Add test 24 to the `@groups` acceptance criterion: "…tests 8, 9, 14, 18,
  23, 24." — Effort: trivial, Risk: none, Impact: complete @groups coverage.
- **[B]** Leave as-is; @groups is already covered in domain-aware mode (test 23),
  and physical mode's @groups handling is the same code path. — Effort: none,
  Risk: low (regression in @groups for physical mode would go undetected).

**Recommendation: A** — one-word change; closes the gap.

---

#### Section: Phase 4 — Task 14 test template

**Issue 11: Test 26 warning annotation absent (same underlying issue as Pass 1 Issue 7 for test 4)**
Severity: SUGGESTION
Test 26 in Task 14's template says:
```
# 26. inner_join() — design variable column in y → warns + dropped (both modes)
```
No explicit assertion annotation. Like test 4 (Issue 7, Pass 1) and test 21, an
implementer must know from `testing-surveytidy.md` that the right assertion is
`expect_warning(class = "surveytidy_warning_join_col_conflict")`.

Issue 7 covers test 4; this is the same pattern for test 26. (Test 21 is identical
but is in a different phase — it has no annotation either.)

Options:
- **[A]** Add the explicit assertion to the comment for tests 21 and 26:
  `expect_warning(class = "surveytidy_warning_join_col_conflict")` — same fix
  as recommended for test 4 in Issue 7. — Effort: trivial.
- **[B]** Rely on `testing-surveytidy.md` standard being sufficient. — Effort: none,
  Risk: low (ambiguous; some implementers may add a snapshot for warnings, others won't).

**Recommendation: A** — resolves all three warning-test annotation gaps (4, 21, 26)
in Stage 3 when Issue 7 is fixed.

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 0 |
| SUGGESTION | 2 |

**Total new issues:** 3

**Overall assessment:** The plan is unchanged from Pass 1 — all 8 prior issues remain
open. One new blocking issue (Issue 9) was found: test 23d description directly
contradicts the domain-aware Step 6 row expansion guard, and cannot be implemented
consistently without resolving which behavior is intended. Recommendation A (error on
duplicate keys in both modes) is the only option consistent with the spec's own error
table. The two new suggestions (Issues 10–11) are trivial to resolve in Stage 3.
**No implementation should start until all blocking and required issues are resolved.**
