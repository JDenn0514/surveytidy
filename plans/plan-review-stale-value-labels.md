## Plan Review: stale-value-labels — Pass 1 (2026-05-01)

### New Issues

#### Section: Overview

No issues.

---

#### Section: PR Map

**Issue 1: changelog path assumes a `fix/` subdirectory that does not exist**
Severity: REQUIRED
Rule: `github-strategy.md` — PR template requires a changelog entry; existing
changelog uses phase-named subdirectories, not `fix/`.

The plan lists `changelog/fix/stale-value-labels.md`. The `changelog/`
directory contains subdirectories named by phase (`phase-0.5`, `phase-0.6`,
etc.). There is no `fix/` subdirectory. Creating `changelog/fix/` would be
inconsistent with the established convention; using the wrong path means the
changelog entry is silently misplaced (or the directory creation adds noise to
the PR).

Options:
- **[A]** Change the path to `changelog/phase-dedup-rename-rowwise/stale-value-labels.md`
  (or whatever active phase directory applies to `develop` right now) — Effort:
  low, Risk: low, Impact: consistency with all prior changelog entries.
- **[B]** Create `changelog/fix/` as a new convention for ad-hoc bugfixes —
  Effort: low, Risk: medium (introduces a second convention with no prior
  precedent), Impact: unclear; makes the directory structure inconsistent.
- **[C] Do nothing** — implementer creates a `fix/` directory; changelog is
  structurally isolated from the rest; future readers cannot find it by
  browsing phase directories.

**Recommendation: A** — Match the established phase-directory convention.
Determine the correct active phase subdirectory before implementing.

---

#### Section: PR 1 — Prune stale inherited value labels

**Issue 2: `test-utils.R` is the correct home for new `.merge_value_labels()` unit tests, but the plan does not mention it**
Severity: REQUIRED
Rule: `testing-standards.md` §1 — "Every source file in `R/` has a corresponding
test file in `tests/testthat/`"; `testing-standards.md` §2 — "Private function
testing: default indirect; direct only when necessary."

`.merge_value_labels()` is a private helper in `R/utils.R`. The plan says to
add tests to `test-replace-when.R` and `test-replace-values.R`, but the
`result_values` pruning branch is a NEW code path inside the helper itself, and
`test-utils.R` already has a direct-test section for `.merge_value_labels()` at
line 90 (four existing blocks covering the four prior branches). The new
`result_values` parameter adds two new branches in the helper that can and
should be tested directly:

1. `result_values = NULL` → no pruning (backward-compatible default)
2. `result_values` non-NULL with a stale base entry → entry pruned before merge
3. `result_values` non-NULL but every base entry still present → nothing pruned
4. Pruning reduces `base_labels` to length 0 → `NULL` sentinel, correct early-return

The plan specifies only integration-level tests (via `replace_when()` /
`replace_values()` inside `mutate()`). Those are necessary but not sufficient:
they do not cover the `result_values = NULL` backward-compatibility path, nor
the edge case where base is pruned to empty.

If the direct unit tests are omitted, the branches in `.merge_value_labels()`
are covered only indirectly by the integration tests, and coverage for the
`NULL` default path (no pruning, no behavior change) may be missed entirely.

Options:
- **[A]** Add a `# ── .merge_value_labels() with result_values ──` section to
  `tests/testthat/test-utils.R` covering (i) `result_values = NULL` default,
  (ii) pruning of a stale base entry, (iii) no pruning when all values retained,
  (iv) pruning to empty returns `NULL`. Keep the three integration-level blocks
  the plan already specifies in `test-recode.R` (they serve a different purpose:
  verifying the end-to-end caller wiring). — Effort: low, Risk: low, Impact:
  fills coverage for helper branches.
- **[B]** Rely solely on the integration-level tests in `test-recode.R` and omit
  direct helper tests — Effort: zero extra, Risk: medium (coverage gap in
  `.merge_value_labels()` branches; `result_values = NULL` path specifically
  untested), Impact: potential coverage drop below 98%.
- **[C] Do nothing** — same as B.

**Recommendation: A** — Direct unit tests for the helper belong alongside the
four existing tests in `test-utils.R`; add the file to the PR's file list.

---

**Issue 3: The integration test file listed in the plan (`test-replace-when.R`,
`test-replace-values.R`) does not exist — tests will live in `test-recode.R`**
Severity: BLOCKING
Rule: `testing-surveytidy.md` — File Mapping table maps `R/replace-when.R` and
`R/replace-values.R` to `tests/testthat/test-replace-when.R` and
`tests/testthat/test-replace-values.R`. However, these files do **not exist**.
All existing tests for `replace_when()` and `replace_values()` live in
`tests/testthat/test-recode.R` (sections 4 and 8 respectively). Running
`devtools::test()` will not pick up tests from files that do not exist; creating
brand-new test files mid-PR also inflates the PR scope and violates the
principle that every new test file requires its own R source counterpart at that
level of granularity.

The plan instructs the implementer to add tests to `test-replace-when.R` and
`test-replace-values.R` — both of which do not exist. If the implementer creates
them, they become parallel test homes for functions already tested in
`test-recode.R`, splitting coverage for the same functions across two files.
If the implementer looks for the files and cannot find them, the tests may be
skipped entirely.

Options:
- **[A]** Correct the plan to add the new test blocks to
  `tests/testthat/test-recode.R` (sections 4 and 8, which already cover
  `replace_when()` and `replace_values()`). Update the Files list in PR 1 to
  reference `tests/testthat/test-recode.R` instead of the non-existent files.
  — Effort: low, Risk: low, Impact: consistent with established test layout.
- **[B]** Create `test-replace-when.R` and `test-replace-values.R` as new
  standalone files — Effort: medium (new files need proper headers, section
  scaffolding, and reconciliation with coverage already in `test-recode.R`),
  Risk: medium (duplicated or split coverage; CI may show unexpected gaps),
  Impact: structural refactor bundled into a bug-fix PR.
- **[C] Do nothing** — implementer creates the missing files or skips tests;
  either outcome is wrong.

**Recommendation: A** — Add the new blocks to `test-recode.R` in the existing
sections for each function.

---

**Issue 4: Acceptance criteria missing the 98%+ line coverage requirement**
Severity: REQUIRED
Rule: `testing-standards.md` §2 — "PRs that drop coverage below 95% are
blocked by CI. 98%+ line coverage is the project target."

The acceptance criteria list seven behavioral checks and the standard
`devtools::check()` / `devtools::document()` checks, but do not include any
statement about line coverage. Given that this PR modifies a shared utility
helper (`.merge_value_labels()`) and adds new branches to it, the coverage
requirement should be explicit so the implementer knows to verify it with
`covr::package_coverage()`.

Options:
- **[A]** Add `- [ ] Line coverage ≥98% verified with covr::package_coverage()`
  to the acceptance criteria — Effort: trivial, Risk: none, Impact: makes
  coverage requirement visible; prevents merging with an undetected gap.
- **[B]** Rely on CI to block if coverage drops below 95% — Effort: none,
  Risk: low (CI catches the floor, not the target), Impact: the implementer may
  not run coverage locally and only discover a gap after pushing.
- **[C] Do nothing** — acceptable, CI is the backstop.

**Recommendation: A** — Explicit criteria are better than implicit CI gates;
consistent with how other implementation plans in this codebase are written.

---

**Issue 5: No test for the backward-compatibility path (`result_values = NULL`
default means no pruning)**
Severity: REQUIRED
Rule: `engineering-preferences.md` §4 — "Handle more edge cases, not fewer."
Rule: `testing-standards.md` §2 — "Every error condition and edge case in the
spec gets a test."

The Overview explicitly states: "`NULL` default means no pruning
(backward-compatible)". This is a named design decision. The plan's test
section does not include any test block that calls `.merge_value_labels()` with
the new parameter absent (or explicitly `NULL`) and asserts that the existing
behavior is unchanged. If the default-path code is accidentally wrong (e.g., an
off-by-one in the guard condition), no test will catch it.

This gap is related to Issue 2 (direct unit tests in `test-utils.R`), but is
worth calling out independently: even if only integration tests are written, a
backward-compat test should exist at the integration level — e.g., calling
`replace_when()` on a labelled vector with a condition that does NOT eliminate
any value, and asserting that all inherited labels survive unchanged.

Options:
- **[A]** Add an explicit backward-compatibility test block:
  `"replace_when() preserves all inherited labels when no value is eliminated"`
  — run on a labelled vector where the replacement does not collapse any value
  (e.g., `x == 99 ~ 0` on data with no 99s), assert all original labels present
  — Effort: low, Risk: low, Impact: validates the NULL-default guard.
- **[B]** Treat the existing `"replace_when() .value_labels merges with x labels"`
  test in `test-recode.R` (line 307) as sufficient — Effort: none, Risk: medium
  (existing test does not exercise the `result_values` code path at all; it
  predates the fix and passes regardless of whether pruning is implemented
  correctly), Impact: coverage gap for new code.
- **[C] Do nothing** — backward compat untested.

**Recommendation: A** — A backward-compat regression test is cheap and protects
against future accidental pruning of labels that should be preserved.

---

**Issue 6: The pruning-block placement instruction in the Notes may silently
break the `result_values = NULL` + `override_labels = NULL` case**
Severity: BLOCKING
Rule: `engineering-preferences.md` §5 — "Explicit over clever"; §4 — "Handle
more edge cases, not fewer."

The plan instructs placing the pruning block "at the top of the function,
before the three early-return `NULL` checks." The pruning block's guard is:

```r
if (!is.null(base_labels) && !is.null(result_values)) {
  base_labels <- base_labels[unname(base_labels) %in% result_values]
  if (length(base_labels) == 0L) base_labels <- NULL
}
```

This guard correctly skips pruning when `base_labels` is already `NULL`. The
overall placement and logic are correct as analyzed. **However**, there is an
ambiguity: the plan uses `result_values` (not `unique(result_values)`) in the
pruning expression, but the callers pass `unique(result)`. The helper itself
receives the already-unique vector. That is fine — but it means the helper's
comment should NOT say "calls `unique()` internally"; the plan's Notes section
says nothing about this, which is consistent. No bug here.

**Real concern**: the proposed expression is `unname(base_labels) %in%
result_values`. `base_labels` is a named vector where **values** are the data
codes and **names** are the label strings. `unname(base_labels)` gives the
numeric codes. This is correct: we are checking whether the code still appears
in the result. However, the plan does not mention the case where `base_labels`
values contain `NA` and `result_values` does not contain `NA`. The plan's NA
section says "No special-casing needed" based on the behavior of `NA %in% NA`
being `TRUE`. This is correct for the case when `NA` IS in the result. But:

When `NA` is in `base_labels` values (i.e., a "tagged missing" label for `NA`)
and `NA` is NOT in `result_values`, the expression `NA %in% result_values`
evaluates to `FALSE`, so the NA-labelled entry is pruned. This is the correct
behavior — the value `NA` has been eliminated from the result — but the plan
does not include a test for this case.

The plan's NA section only describes the "NA IS in result → label preserved"
scenario. The complementary "NA is NOT in result → label pruned" scenario is
equally important to test and is not covered.

Options:
- **[A]** Add a test block:
  `"replace_when() prunes inherited NA-value label when NA no longer appears in result"`:
  build a labelled vector with an `NA`-coded label entry; apply a replacement
  that eliminates all NAs (e.g., `is.na(x) ~ 0`); assert the NA label entry
  is absent from the output. — Effort: low, Risk: low, Impact: validates the
  `NA %in% result_values` FALSE branch.
- **[B]** Leave the NA-pruning case untested — Effort: none, Risk: medium
  (if the `%in%` behavior for NA were ever changed by R or the code were
  refactored, this edge case would break silently), Impact: coverage gap.
- **[C] Do nothing** — same as B.

**Recommendation: A** — The NA-is-not-in-result case is a real edge case in
survey data (tagged missings are common) and deserves an explicit test.

---

**Issue 7: The "user-supplied label for absent value is NOT pruned" test uses
value `99` which is not in the design helper's data; the test may not actually
demonstrate the contract it claims**
Severity: SUGGESTION
Rule: `testing-standards.md` §4 — "Edge case data: inline in tests"; "If the
edge case needs exact specific values to trigger, write those values directly."

The plan specifies:

> Run `replace_when(x, x == 4 ~ 3, .value_labels = c("Ghost" = 99))` — Assert
> `"Ghost" = 99` is present in the output labels.

The test demonstrates that a user-supplied label for value `99` survives when
`99` does not appear in the result. This is correct behavior: user-supplied
labels are never pruned. However, the test description says this validates the
"never prune user-supplied entries" contract. The test works, but it is slightly
misleading: `99` is also absent from the INPUT `x`, so one could argue the test
is checking "ghost label for a value that was never in the data" rather than
"ghost label for a value that was eliminated by the replacement." A stronger
test would use a value that exists in the input but is entirely replaced (e.g.,
`.value_labels = c("Something else" = 4)` where `4` is in the input but
replaced to `3`), so the distinction between "pruned because eliminated" and
"not pruned because user-supplied" is explicit.

Options:
- **[A]** Change the user-supplied label test to use a value that EXISTS in the
  input but is eliminated by the replacement (e.g., `c("Something else" = 4)`)
  so the test unambiguously demonstrates that user-supplied labels survive even
  when the value they label is eliminated from the result. — Effort: trivial,
  Risk: none, Impact: clearer test intent.
- **[B]** Keep `99` as the ghost value — the contract is still tested correctly
  (user-supplied labels are not pruned regardless of whether the value exists),
  but the explanation is less sharp. — Effort: none, Risk: none (test is still
  valid), Impact: minor documentation quality issue.
- **[C] Do nothing** — same as B.

**Recommendation: A** — A value that was in the data and then eliminated makes
the "NOT pruned despite elimination" contract more vivid and harder to misread.

---

**Issue 8: No `test_invariants()` call in the new test blocks**
Severity: REQUIRED
Rule: `testing-surveytidy.md` — "`test_invariants(result)` required as the
FIRST assertion in every verb test block."

The plan specifies three test blocks per function, all of which call recode
functions inside `mutate()` on survey design objects. The plan does not mention
calling `test_invariants(result)` in any of these blocks. The existing
`replace_when()` and `replace_values()` tests in `test-recode.R` consistently
call `test_invariants(result)` after every `mutate()` result (see lines 273,
291, 303, 321). The new blocks must follow the same pattern.

Options:
- **[A]** Add `test_invariants(result)` as the first assertion after building
  `result` in each of the six new test blocks (three for `replace_when()`,
  three for `replace_values()`). — Effort: trivial, Risk: none, Impact: aligns
  with required testing standard.
- **[B]** Omit `test_invariants()` from the new blocks — Effort: none, Risk:
  medium (if a future change breaks structural invariants, these blocks will not
  catch it), Impact: inconsistent with every other test in `test-recode.R`.
- **[C] Do nothing** — same as B.

**Recommendation: A** — Required by `testing-surveytidy.md`; no reason to
deviate.

---

**Issue 9: Plan does not specify cross-design testing (all 3 design types) for
the new test blocks**
Severity: REQUIRED
Rule: `testing-surveytidy.md` — "Every verb tested with all three design types.
Use `make_all_designs()` and loop over the result. NEVER write a verb test that
only covers one design type."

The plan describes each test block as running a single call like
`replace_when(x, x == 4 ~ 3)` without specifying whether the test uses a loop
over `make_all_designs()`. Looking at the existing pattern in `test-recode.R`
(section 4 at line 266), every `replace_when()` and `replace_values()` test
block uses `make_all_designs(seed = 42)` and a `for (d in designs)` loop. The
new blocks must follow this pattern.

If the new blocks test only one design type (e.g., only `taylor`), the fix
could silently fail for replicate or twophase designs.

Options:
- **[A]** Update the plan's test case descriptions to explicitly require
  `make_all_designs(seed = 42)` + `for (d in designs)` loop, and assert the
  pruning/preservation behavior for each design type. — Effort: trivial, Risk:
  none, Impact: consistent with all existing tests for these functions.
- **[B]** Leave the plan silent on design-type looping and rely on the
  implementer knowing the convention — Effort: none, Risk: medium (convention
  may be missed; the fix could work for taylor but fail for replicate), Impact:
  coverage gap across design types.
- **[C] Do nothing** — same as B.

**Recommendation: A** — The convention is required and should be explicit in
the plan.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 2 |
| REQUIRED | 5 |
| SUGGESTION | 1 |

**Total issues:** 8

**Overall assessment:** The core implementation logic is correct and well-reasoned,
but the plan has two blocking issues (the test files it references do not exist,
and the NA-pruning edge case has an untested complementary scenario) plus five
required gaps around test completeness (no `test_invariants()`, no cross-design
looping, no backward-compat test, no `test-utils.R` direct-unit coverage, and
missing the coverage-target acceptance criterion) — all resolvable before coding
starts.
