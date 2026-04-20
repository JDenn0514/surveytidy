## Plan Review: rowstats — Pass 1 (2026-04-15)

_First pass; no prior issues to carry forward._

---

### New Issues

#### Section: PR Map

No issues found. Two PRs, correct granularity — PR 1 is a pure refactor with
no behavioral change; PR 2 is the feature. They are sequenced correctly (PR 1
must land before PR 2 begins). No bundling of unrelated work. Size is
appropriate (PR 2: 1 new file + 1 modified file + 1 test file).

---

#### Section: PR 1 — Move shared helpers to `R/utils.R`

**Issue 1: Acceptance criteria missing "Changelog entry" criterion**
Severity: REQUIRED
Violates `github-strategy.md`: "Changelog entry format (required before every PR)"

The acceptance criteria checklist for PR 1 has seven checkboxes — none of them
is "Changelog entry written and committed on this branch." Task 1.4 does mention
writing the entry, but the acceptance criteria is the authoritative pass/fail
gate used by `/r-implement` and the final PR reviewer. An item in the task list
but absent from the acceptance criteria will be missed on a fast pass.

PR 2's acceptance criteria correctly includes the changelog item. PR 1 should
match.

Options:
- **[A] Add "Changelog entry written and committed on this branch" to the PR 1
  acceptance criteria checklist** — Effort: trivial, Risk: none, Impact: gate
  is complete and consistent with PR 2.
- **[B] Add `changelog/` to the PR 1 files section only** — Effort: trivial,
  but the acceptance criteria still lacks the check.
- **[C] Do nothing** — Task 1.4 covers it, but the acceptance criteria is
  incomplete as a standalone gate.

**Recommendation: A** — One checkbox; consistent with PR 2 and every other PR
in this codebase.

---

**Issue 2: `R/transform.R` section comment on line 17 not addressed by Task 1.1 / 1.2**
Severity: SUGGESTION
Violates engineering-preferences.md §5 (explicit over clever — document what
you changed)

`transform.R` line 17 contains the section header:

```r
#  internal helpers (used only in transform.R)
```

After moving `.validate_transform_args()` and `.set_recode_attrs()`, only
`.strip_first_word()` remains in this section. The comment "used only in
transform.R" would still be accurate for `.strip_first_word()`, but the section
label as a whole is now misleading — two of the three original "internal helpers"
have moved out. Task 1.1 step 3 and Task 1.2 step 3 update the "Functions
defined here" list in the file header, but the section comment on line 17 is not
mentioned.

Options:
- **[A] Add an explicit instruction in Task 1.1 step 2** — "Also delete or
  update the `# internal helpers (used only in transform.R)` section header
  comment on line 17." Effort: trivial, Risk: none.
- **[B] Do nothing** — The comment remains technically accurate for
  `.strip_first_word()` (still only used in transform.R) so it is not actively
  wrong.

**Recommendation: A** — A one-line deletion (or update to `# internal helpers`)
is better than leaving a comment that formerly introduced two functions now in
utils.R.

---

#### Section: PR 2 — Implement `row_means()`, `row_sums()`, and design-var warning

**Issue 3: Acceptance criteria specifies `air format R/rowstats.R` but omits `R/mutate.R`**
Severity: REQUIRED
Violates `code-style.md` §6: "Run `air format .` before opening a PR. Do not
commit air-reformatted files in the same commit as functional changes."

The acceptance criteria includes:
> "air format R/rowstats.R has been run"

But PR 2 also modifies `R/mutate.R` (Step 8 addition). The `air format`
criterion should cover all files changed in the PR. Formatting only
`R/rowstats.R` leaves the `mutate.R` changes potentially unformatted and
inconsistent.

Options:
- **[A] Change the criterion to `air format R/rowstats.R R/mutate.R has been
  run`** — precisely targets only the files changed in this PR. Effort:
  trivial, Risk: none.
- **[B] Change to `air format . has been run`** — broader; also covers any
  test file formatting. Effort: trivial, Risk: none.
- **[C] Do nothing** — `devtools::check()` doesn't enforce formatting, so CI
  won't catch this. Unformatted `mutate.R` changes could pass the acceptance
  gate.

**Recommendation: A** — Precise and matches the pattern used elsewhere in the
codebase (`air format R/rowstats.R` style is already established).

---

**Issue 4: Task 2.2 / Task 2.5 — "Every test should show FAIL (not ERROR or SKIP)" is incorrect**
Severity: SUGGESTION
Violates accuracy of TDD instructions; creates confusion for the implementer

Task 2.2 and Task 2.5 both state:

> "Every test should show FAIL (not ERROR or SKIP)."

In testthat 3, calling a non-existent function inside `test_that()` causes the
test to **ERROR**, not FAIL. `expect_error(row_means(...), class = "some_class")`
will FAIL (wrong error class), but tests 1–10 that just call `row_means()` and
assert on the result will ERROR.

The `expect_snapshot(error = TRUE, ...)` assertion is more problematic: on its
**first run**, testthat creates a new snapshot file containing whatever error was
produced (including the "could not find function" error). The test **passes** on
first run. An implementer who reads "every test should show FAIL" will be
confused when the snapshot tests pass.

Options:
- **[A] Replace the instruction with accurate language**: "Tests 1–10 will
  ERROR (not FAIL) — `row_means()` does not exist yet. Tests 25–26 will
  have mixed behavior: `expect_error(class=)` will FAIL (wrong error class);
  `expect_snapshot(error=TRUE)` will create an incorrect snapshot on first run
  and PASS. After implementing `row_means()`, run
  `testthat::snapshot_review()` to update any snapshots created during the
  red phase before proceeding." Effort: low, Risk: none.
- **[B] Simplify to "Confirm that no test passes for the intended reason"** —
  shorter, but still imprecise.
- **[C] Do nothing** — An experienced implementer will recognize the ERROR vs
  FAIL distinction. The snapshot issue is a real footgun.

**Recommendation: A** — Accurate TDD instructions prevent wasted debugging time.
The snapshot-creates-bad-snapshot trap is non-obvious and worth calling out
explicitly.

---

**Issue 5: Test 16 bundles three behaviors where tests 5–8 keep them separate**
Severity: SUGGESTION
Violates `testing-standards.md` §1: "One observable behavior per `test_that()`
block"

Tests 5–8 cover row_means() metadata in four separate blocks:
- Test 5: `.label` stored in `@metadata@variable_labels`
- Test 6: `.label = NULL` falls back to column name
- Test 7: `.description` stored in `@metadata@transformations`
- Test 8: `source_cols` in `@metadata@transformations` matches selected cols

Test 16 covers all three equivalent behaviors for `row_sums()` in a single
block: "metadata recording (.label, .description, source_cols)."

This asymmetry makes row_sums() metadata less visible in the test output and
harder to debug when a single assertion fails inside the combined block.

Options:
- **[A] Split test 16 into three tests (16a: .label, 16b: .description, 16c:
  source_cols)** — matches the row_means() pattern and satisfies
  testing-standards. Renumber or use labeled subtests. Effort: low.
- **[B] Explicitly note the intentional asymmetry** — add a comment in the
  test file: "row_sums() metadata is tested as one block (rather than 4) since
  the behavior is identical to row_means() and separately covered there."
  Effort: trivial, but still violates the one-behavior rule.
- **[C] Do nothing** — The spec lists test 16 as a single entry; plan follows
  the spec.

**Recommendation: A** — Three tests match the row_means() pattern and cost
nothing extra. Option B makes the rule violation intentional but still wrong.

---

### Spec Coverage Check

All 28 spec test cases (§VII) are mapped to plan tasks:

| Tests | Plan Task |
|-------|-----------|
| 1–11, 25–26 | Task 2.1 (write), Task 2.2 (confirm red), Task 2.3 (green) |
| 12–17, 27–28 | Task 2.4 (write), Task 2.5 (confirm red), Task 2.6 (green) |
| 18–24 | Task 2.7 (write, with 18–20, 24 expected green; 21–23 expected red) |

All 5 new error classes and 1 new warning class are covered by acceptance
criteria and test requirements. `plans/error-messages.md` is already updated
(confirmed by reading the file — all 6 classes present). No spec behavior is
absent from the plan.

---

### File Completeness Check

**PR 1:**
- `R/utils.R` ✓
- `R/transform.R` ✓
- `changelog/` — listed in Task 1.4 but absent from the files section ✓ (minor; cross-referenced by Issue 1 above)

**PR 2:**
- `R/rowstats.R` ✓
- `R/mutate.R` ✓
- `tests/testthat/test-rowstats.R` ✓
- `changelog/` ✓
- NAMESPACE + man/ via `devtools::document()` criterion ✓
- `plans/error-messages.md` — already done, noted in Quality Gate ✓

---

### Dependency Ordering Check

- PR 1 has no dependencies — correct, it is a pure code move
- PR 2 depends on PR 1 — correct; `.validate_transform_args()` and
  `.set_recode_attrs()` must be in `R/utils.R` before `R/rowstats.R` calls them
- CI state after PR 1: verified by Task 1.3 (`devtools::test()` + `devtools::check()`)
- No circular dependencies

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 2 |
| SUGGESTION | 3 |

**Total issues:** 5

**Overall assessment:** The plan is nearly ready to implement. No blocking gaps —
the TDD ordering is correct, all 28 tests are mapped to tasks, the PR boundary is
appropriate, and the acceptance criteria are comprehensive except for two
omissions. Two REQUIRED fixes: add the changelog criterion to PR 1, and extend
the `air format` criterion in PR 2 to cover `R/mutate.R`. Three suggestions are
quality improvements (accurate TDD instructions, consistent test granularity,
inline comment cleanup) that are worth addressing before coding starts but won't
block a correct implementation.
