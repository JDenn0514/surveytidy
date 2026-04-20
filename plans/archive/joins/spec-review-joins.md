## Spec Review: joins — Pass 1 (2026-04-16)

### New Issues

#### Section: §II — Shared Internal Helpers

---

**Issue 1: `.check_join_col_conflict` called without `by` in `left_join` and `bind_cols` — key column dropped, join breaks**
Severity: BLOCKING
Violates: Contract completeness (Lens 3); code-style.md argument-passing convention

The §II helper table defines `.check_join_col_conflict(x, y, by)` with this note: "Columns listed in `by` are **excluded** from the conflict check — they are match keys, not new columns being added, so they pose no threat to design variable integrity."

But §III Behavior Rules Step 2 calls `.check_join_col_conflict(x, y)` (no `by`), and §V Behavior Rules Step 2 calls `.check_join_col_conflict(x, dplyr::bind_cols(...))` (no `by` at all — bind_cols has no key). Only §VI (inner_join) passes `by`.

Concrete failure path for `left_join`: if a user calls `left_join(design, y, by = "strata_col")` where `strata_col` is both the join key AND happens to share a name with a design variable (e.g., a stratum identifier that the user joins on for lookup), `.check_join_col_conflict(x, y)` sees `strata_col` in `y` matching a design variable and drops it. The join then fails because the key column is gone from `y`. The spec's own guard would break the operation.

Options:
- **[A]** Fix all call sites to pass `by` consistently: `left_join` passes `by`, `bind_cols` passes `by = character(0)` (no keys). Update §III Step 2 and §V Step 2. — Effort: low, Risk: low, Impact: spec is internally consistent
- **[B]** Remove `by` from the helper signature and always check ALL y columns (excluding `by` logic entirely). — Effort: low, Risk: medium (legitimate key-as-design-var case unhandled), Impact: narrower guard that could warn incorrectly
- **[C] Do nothing** — implementer follows §VI and passes `by`, then follows §III literally and doesn't. Two different behaviors in production.

**Recommendation: A** — the spec defines the right behavior; it just doesn't apply it consistently to left_join and bind_cols.

---

**Issue 2: `inner_join` domain-aware mode — row expansion check absent from Step 6 (left_join step), contradicting helper table**
Severity: BLOCKING
Violates: Contract completeness (Lens 3); engineering-preferences.md §1 (explicit over clever)

The §II helper table lists `.check_join_row_expansion` as "Used by: `left_join`, `inner_join`". This implies domain-aware inner_join must call the helper somewhere. But §VI domain-aware behavior rules Step 6 says only: "`dplyr::left_join(x@data, y, ...)` to add y's columns to all rows (NAs for unmatched). Apply suffix rename repair..." — no row expansion check.

Concrete failure path: user calls `inner_join(design, y, by = "id")` where `y` has duplicate `id` values. Step 3 computes the match mask — which correctly collapses duplicates to a single `TRUE` per survey row. But Step 6's `dplyr::left_join(x@data, y)` expands `x@data` (duplicate keys in `y` produce multiple output rows for each survey row). Row count increases. The domain-aware mode returns a survey object with more rows than respondents, corrupting variance estimation — with no error and no warning.

Test 23d in the test plan says "inner_join [domain-aware] — duplicate keys in y collapse to single TRUE per survey row." This test verifies mask behavior but does NOT verify that the subsequent left_join step cannot expand rows.

Options:
- **[A]** Add `.check_join_row_expansion` call to Step 6, before writing the join result back to `x@data`. Document it explicitly in the behavior rules. Update test 23d to verify the error fires. — Effort: low, Risk: low, Impact: prevents silent design corruption
- **[B]** Deduplicate `y` on the join key before the left_join step (collapse y to distinct keys). — Effort: medium, Risk: medium (changes dplyr semantics — user's y is silently modified), Impact: avoids the expansion
- **[C] Do nothing** — implementer notices the mismatch between helper table and behavior rules, picks one, guesses wrong half the time.

**Recommendation: A** — the spec already says `.check_join_row_expansion` is used by `inner_join`; it just needs to say WHERE.

---

#### Section: §IV — `semi_join` / `anti_join` (Open GAPs)

---

**Issue 3: GAP-3 (verbosity) still open — spec says "Decision must be logged before implementation"**
Severity: REQUIRED
Violates: spec itself (§IV Step 5 says "Decision must be logged before implementation"); HARD-GATE

§IV Step 5 says: "Decision must be logged before implementation. Current lean: **silent** (consistent with `filter()`), but this must be confirmed." The spec has been at Stage 3 without resolving this.

The decision is not architecturally complex — it is a one-line judgment. But the spec's own HARD-GATE says all GAPs must be in `plans/decisions-joins.md` before implementation.

Options:
- **[A]** Resolve in Stage 4: log the decision (silent, consistent with `filter()`), update §IV Step 5 to remove the open qualifier. — Effort: low, Risk: none, Impact: spec implementable
- **[B]** Remove the step entirely (no verbosity, no logging needed). — Effort: low, Risk: low (silent behavior is implicit), Impact: slightly weaker spec traceability
- **[C] Do nothing** — GAP-3 remains open; HARD-GATE violated.

**Recommendation: A** — the lean is obvious; log it and close it.

---

**Issue 4: GAP-4 (masking implementation) deferred as "implementation detail" — implementer has no authoritative guidance**
Severity: REQUIRED
Violates: engineering-preferences.md §4 (handle edge cases, not fewer); explicit over clever

The spec notes that the `rbind/duplicated` approach sketched in §IV is "a sketch" and the "reliable approach" is the row-index column technique. But it defers the exact code to implementation: "The exact implementation must be decided and documented before the code is written."

If the exact implementation must be decided before the code is written, that decision belongs in the spec — not in the implementer's head. The row-index approach needs to specify:
1. What column name to use for the temporary index
2. Whether to use row numbers (`seq_len(nrow(x@data))`) or row names
3. How to handle the case where `x@data` already has a column with that name
4. How to clean up the temporary column after the join

This is 4 sub-decisions left open. Labeling them an "implementation detail" means Stage 3 passes the buck to implementation.

Options:
- **[A]** In Stage 4, fully specify the row-index approach: prescribed column name (e.g., `"..surveytidy_row_index.."`), collision handling, cleanup step. Add to §IV Step 2 as the authoritative approach. — Effort: medium, Risk: low, Impact: implementer has unambiguous instructions
- **[B]** Accept the sketch and allow implementer to choose, with the constraint that test 12 (duplicate keys collapse to single TRUE) must pass. — Effort: low, Risk: medium (test 12 doesn't test all sub-cases), Impact: less predictable implementation
- **[C] Do nothing** — GAP-4 remains; implementer improvises.

**Recommendation: A** — if the spec says the decision must be made first, the spec must make it.

---

**Issue 5: `anti_join` duplicate key behavior unspecified and untested**
Severity: REQUIRED
Violates: testing-standards.md (all edge cases explicitly defined); Lens 4 — Edge Cases

Test 12 specifies for `semi_join`: "duplicate keys in y collapse to single TRUE (no row expansion)." There is no equivalent test or spec statement for `anti_join`. The spec only mentions the collapse requirement in §IV Step 2 as a note in the `semi_join` sketch. The `anti_join` mask inversion (`!new_mask`) is defined in Step 3, but the spec never states what happens when `y` has duplicate keys that match a survey row.

The behavior is likely "collapse to single FALSE per row" (same logic, inverted), but "likely" is not a spec. An implementer testing `anti_join` with duplicate keys would have no expectation to assert against.

Options:
- **[A]** Add an explicit spec statement in §IV: "For `anti_join`, duplicate keys in `y` that match a survey row collapse to a single `FALSE` in the mask." Add test (e.g., test 14b or after test 17): "anti_join() — duplicate keys in y collapse to single FALSE per survey row." — Effort: low, Risk: none, Impact: full symmetry with semi_join test 12
- **[B]** Add a footnote to Step 2 that the duplicate-collapse requirement applies to both functions. — Effort: low, Risk: low (slightly less explicit), Impact: covers the gap at spec level but leaves test gap
- **[C] Do nothing** — anti_join duplicate key behavior is silent spec territory.

**Recommendation: A** — the symmetry with semi_join makes this a one-line spec addition and a one-block test.

---

#### Section: §XII — Testing

---

**Issue 6: `@variables$domain` sentinel not asserted in any test block**
Severity: REQUIRED
Violates: testing-standards.md §2 (happy path must include all output changes); Lens 2 — Test Completeness

The output contracts for `semi_join`, `anti_join`, and `inner_join` (domain-aware) all specify that a structured sentinel is appended to `@variables$domain`. The test plan has:

- Tests 9–16 (semi_join, anti_join): no assertion that `@variables$domain` contains the sentinel
- Tests 23–23d (inner_join domain-aware): no assertion on sentinel

All three sections describe this output change in their contract. None of the test numbers assert it. A passing test suite could be completely silent about whether the sentinel was written.

Options:
- **[A]** Add an assertion to test 9 (semi_join happy path), test 14 (anti_join happy path), and test 23 (inner_join domain-aware happy path) that `@variables$domain` contains the sentinel with correct `type` and `keys` values. — Effort: low, Risk: none, Impact: contract tested end-to-end
- **[B]** Add a new dedicated test block for `@variables$domain` sentinel behavior separate from the happy-path tests. — Effort: low, Risk: none, Impact: clearer test separation
- **[C] Do nothing** — sentinel is unverified; could be silently omitted in implementation.

**Recommendation: A** — inline assertions in the existing happy path blocks; keep test count manageable.

---

**Issue 7: @groups preservation tested only for `left_join` (test 8) — four other functions untested**
Severity: REQUIRED
Violates: testing-standards.md §2 (all output changes must be tested); Lens 2 — Test Completeness

§XI explicitly states that `@groups` is preserved from `x` for all five non-error functions. Test 8 verifies this for `left_join`. But there are no equivalent tests for:
- `semi_join` — no test asserting `@groups` preserved after the join
- `anti_join` — same
- `bind_cols` — same
- `inner_join` (either mode) — same

`@groups` preservation is a contract, not an assumption. If an implementation accidentally clears `@groups` in `semi_join`, no test would catch it.

Options:
- **[A]** Add `@groups` preservation assertions to test 9 (semi_join), test 14 (anti_join), test 18 (bind_cols), test 23 (inner_join). One-line assertion each: `expect_identical(result@groups, d@groups)`. — Effort: low, Risk: none, Impact: full contract coverage
- **[B]** Add a single parametrized `@groups` preservation test at the end of §XII that loops over all five functions. — Effort: low, Risk: low (slightly harder to scan), Impact: same coverage
- **[C] Do nothing** — @groups contract tested for 1 of 5 functions.

**Recommendation: A** — inline with existing test blocks is the surveytidy pattern; no need for a separate parametrized block.

---

**Issue 8: "New columns get no metadata labels" tested nowhere**
Severity: REQUIRED
Violates: testing-standards.md §2 (all output changes must be tested); Lens 2 — Test Completeness

`@metadata` output contracts for `left_join` (§III), `inner_join` domain-aware (§VI), and `bind_cols` (§V) all specify: "New columns from `y` get no labels in `@metadata@variable_labels`." No test block verifies this. An implementation that accidentally copies labels would pass all existing tests.

Options:
- **[A]** Add an assertion to tests 1 (left_join), 18 (bind_cols), and 23 (inner_join domain-aware): check that the new column name is absent from `result@metadata@variable_labels`. — Effort: low, Risk: none, Impact: metadata contract verified
- **[B]** Add a dedicated metadata test block for each function. — Effort: medium, Risk: none, Impact: cleaner separation but more test blocks
- **[C] Do nothing** — metadata contract untested.

**Recommendation: A** — one assertion per happy-path block, matching the surveytidy pattern of inline contract assertions.

---

#### Section: §V — `bind_cols` (Contract Gap)

---

**Issue 9: `@variables$domain` sentinel: Phase 1 consumption contract unspecified — mixed-type list breaks any consumer**
Severity: REQUIRED
Violates: engineering-preferences.md §5 (explicit over clever); Lens 5 — Engineering Level

`@variables$domain` currently stores a list of quosures (from `filter()` calls). The spec (GAP-5 decision) adds a new type of entry: `list(type = "semi_join", keys = ...)`. This makes `@variables$domain` a mixed-type list: some elements are `rlang::quosure` objects, others are plain lists with `type` and `keys` fields.

No Phase 1 spec defines how `@variables$domain` is read. Any Phase 1 code that iterates over `@variables$domain` and calls `rlang::eval_tidy()` on each element would fail when it encounters a `list(type = ...)` struct. The sentinel protects Phase 1 from missing the restriction — but only if Phase 1 knows to check the type before evaluating.

The spec says "Authoritative domain state remains the `..surveycore_domain..` column in `@data`." If that's true, Phase 1 reads the column directly and never needs `@variables$domain`. If Phase 1 also reads `@variables$domain` (the case the sentinel is designed to help), it needs a type-dispatch contract that doesn't exist.

Options:
- **[A]** Add a contract to the spec: "Each element of `@variables$domain` is either a `rlang::quosure` (from `filter()`) or a named list with keys `type` (character) and `keys` (character vector). Consumers must check `rlang::is_quosure(entry)` before evaluating." Document this in §IV and §VI output contracts. — Effort: low, Risk: low, Impact: future-proofs Phase 1 and makes the sentinel design explicit
- **[B]** Use a typed S3 wrapper for the sentinel (`structure(list(...), class = "surveytidy_join_domain")`) so `is.quosure()` returns `FALSE` and `inherits(x, "surveytidy_join_domain")` returns `TRUE`. — Effort: medium, Risk: low, Impact: cleaner dispatch; self-documenting
- **[C] Do nothing** — Phase 1 inherits a mixed-type list with no contract; the first Phase 1 implementation will encounter it cold.

**Recommendation: A** — the spec needs to define the contract for the mixed list, even if it's one sentence. Option B is cleaner but is additional scope.

---

#### Section: §II / §III / §VI — DRY

---

**Issue 10: Suffix rename repair logic unnamed — DRY violation across §III (Step 4b) and §VI (Step 6)**
Severity: SUGGESTION
Violates: engineering-preferences.md §1 (DRY — flag repetition aggressively); Lens 1

§III Step 4b describes the suffix rename repair logic in full detail (detect suffix-renamed x columns; build rename map; apply to `@metadata` keys and `visible_vars`). §VI Step 6 says "Apply suffix rename repair (same logic as §III Step 4b)." Two callers reference the same multi-step logic.

Per engineering-preferences.md §1: "Repeated patterns in 2+ functions → extract a shared internal helper." The spec should name a fourth helper (e.g., `.repair_suffix_renames(x, old_x_cols, suffix)`) in the §II helper table, and reference it in both §III Step 4b and §VI Step 6.

Options:
- **[A]** Add `.repair_suffix_renames(x, old_x_cols, suffix)` to the §II helper table with signature, return value, and call sites. Update §III Step 4b and §VI Step 6 to reference it by name. — Effort: low, Risk: none, Impact: unambiguous implementation guide
- **[B]** Leave "same logic as §III Step 4b" — implementer will extract naturally. — Effort: none, Risk: low, Impact: slightly weaker spec DRY
- **[C] Do nothing** — same as B.

**Recommendation: A** — the spec already has a helper table; add the fourth entry now.

---

#### Section: §XII — Test Plan Miscellany

---

**Issue 11: Test 27 missing — numbering gap in test plan**
Severity: SUGGESTION
Violates: Clarity (Lens 2 — completeness)

The test plan jumps from test 26 to test 28. There is no test 27. Either a test was deleted and the list not renumbered, or a test is unintentionally missing.

Options:
- **[A]** Review what test 27 was intended to cover; assign it or renumber 28–31 to 27–30 and update the cross-design requirement note. — Effort: low, Risk: none, Impact: cleaner test plan
- **[B]** Leave the gap — the test numbers are labels, not sequential counts. — Effort: none, Risk: low (confusing for reviewers), Impact: minor
- **[C] Do nothing** — same as B.

**Recommendation: A** — renumber or fill the gap before implementation to avoid confusion.

---

**Issue 12: `right_join` / `full_join` snapshot tests do not verify the `{fn}` placeholder**
Severity: SUGGESTION
Violates: Lens 2 — Test Completeness (error message contract)

§VII specifies that the `{fn}` placeholder in `surveytidy_error_join_adds_rows` is filled with `"right_join"` or `"full_join"` depending on which function was called. The test plan has:
- Test 28: `right_join()` — always errors (class check only)
- Test 29: `full_join()` — always errors (class check only)

Both use the same error class (`surveytidy_error_join_adds_rows`). Without snapshots, nothing verifies that `right_join` produces a message mentioning "right_join" and `full_join` produces one mentioning "full_join". The dual error pattern (class + snapshot) is required for all user-facing errors per `testing-surveytidy.md`.

Options:
- **[A]** Add snapshot tests (`expect_snapshot(error = TRUE, ...)`) for both test 28 and test 29, producing two distinct snapshot files. — Effort: low, Risk: none, Impact: {fn} placeholder verified
- **[B]** Leave class-only tests — the {fn} mechanism is implementation detail. — Effort: none, Risk: low (text not pinned), Impact: message drift undetected
- **[C] Do nothing** — same as B.

**Recommendation: A** — `testing-surveytidy.md` requires dual pattern for all user-facing errors; these are user-facing errors.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 2 |
| REQUIRED | 7 |
| SUGGESTION | 3 |

**Total issues:** 12

**Overall assessment:** The spec is well-structured and the methodology lock is sound. The two blocking issues are concrete spec defects: a call-site inconsistency in `.check_join_col_conflict` that would silently break joins on design-variable key columns, and a missing row-expansion guard in the domain-aware `inner_join` path that the spec's own helper table implies should be there. The required issues are primarily test-plan gaps (untested output contracts) and two open GAPs that must be logged before implementation. None of the required issues require architectural changes to the spec — they are additions or clarifications. Resolve Issues 1–2 before any code is written.

---

## Spec Review: joins — Pass 2 (2026-04-16)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | `.check_join_col_conflict` called without `by` in `left_join` and `bind_cols` | ✅ Resolved |
| 2 | `inner_join` domain-aware mode — row expansion check absent from Step 6 | ✅ Resolved |
| 3 | GAP-3 (verbosity) still open | ✅ Resolved |
| 4 | GAP-4 (masking implementation) deferred — row-index approach fully specified | ✅ Resolved |
| 5 | `anti_join` duplicate key behavior unspecified and untested | ✅ Resolved |
| 6 | `@variables$domain` sentinel not asserted in any test block | ✅ Resolved |
| 7 | `@groups` preservation tested only for `left_join` | ✅ Resolved |
| 8 | "New columns get no metadata labels" tested nowhere | ✅ Resolved |
| 9 | `@variables$domain` sentinel: Phase 1 consumption contract unspecified | ✅ Resolved |
| 10 | Suffix rename repair logic unnamed — DRY violation | ✅ Resolved |
| 11 | Test 27 missing — numbering gap in test plan | ✅ Resolved |
| 12 | `right_join` / `full_join` snapshot tests do not verify the `{fn}` placeholder | ✅ Resolved |

All 12 Pass 1 issues are resolved in v0.3. The spec is internally consistent on every point raised in Pass 1.

### New Issues

#### Section: §VI — `inner_join` (domain-aware behavior rules)

---

**Issue 13: `inner_join` domain-aware behavior rules missing explicit step for sentinel update**
Severity: REQUIRED
Violates: Contract completeness (Lens 3); testing-surveytidy.md (output contract must be fully specified in behavior rules)

The output contract for domain-aware `inner_join` explicitly states: "`@variables$domain` — a typed S3 sentinel (class `'surveytidy_join_domain'`, via `.new_join_domain_sentinel('inner_join', resolved_by)`) is appended to record the join-based domain restriction." The helper table lists `.new_join_domain_sentinel` as used by `inner_join` (domain-aware).

But §VI domain-aware behavior rules list Steps 1–6 with no step for appending the sentinel. `semi_join` and `anti_join` behavior rules DO include Step 6: "Update `@variables$domain`." `inner_join` domain-aware does not. An implementer following the behavior rules step-by-step would produce a result where the sentinel is missing from `@variables$domain`, contradicting the output contract and breaking test 23's assertion on the sentinel.

Options:
- **[A]** Add a Step 7 to §VI domain-aware behavior rules: "Append sentinel to `@variables$domain`. Call `.new_join_domain_sentinel('inner_join', resolved_by)` and append to `@variables$domain`." — Effort: low, Risk: none, Impact: behavior rules match the output contract
- **[B]** Add a cross-reference: "Update `@variables$domain` per §IV Step 6 pattern." — Effort: low, Risk: low (slightly weaker), Impact: avoids duplication
- **[C] Do nothing** — implementer must reconcile output contract vs. behavior rules independently.

**Recommendation: A** — the behavior rules are the implementation guide; omitting a step that the output contract requires is a spec defect.

---

#### Section: §V — `bind_cols` (structural guard ordering defect)

---

**Issue 14: `bind_cols` Step 4 uses `...` directly — conflict-cleaned frame is discarded**
Severity: REQUIRED
Violates: engineering-preferences.md §1 (DRY — flag repetition); Lens 3 — Contract Completeness

§V Step 2 calls `.check_join_col_conflict(x, dplyr::bind_cols(...), by = character(0))` to get a cleaned combined frame with conflicting design-variable columns dropped. The helper returns cleaned `y`. But §V Step 4 says: `x@data <- dplyr::bind_cols(x@data, ..., .name_repair = .name_repair)` — it binds the **original** `...`, not the cleaned frame returned by Step 2.

This means even a correct implementation of Step 2 (capturing the cleaned return value) cannot fix Step 4: Step 4 re-introduces the conflicting columns that Step 2 dropped. The conflict guard warning fires, but the columns are bound anyway. A design variable from `y` would appear in `x@data` alongside the original, suffixed — corrupting the design variable name.

Note: for `left_join` and `inner_join`, the analogous guard in Step 2 says "drop the conflicting columns from `y` before proceeding. The join continues with the cleaned `y`" — this implies `y` must be reassigned to the return value. But `bind_cols` Step 4 structurally cannot use the return value of Step 2 because Step 4 references `...` (the original varargs), not a named variable.

Options:
- **[A]** Restructure §V Steps 2–4: explicitly name the cleaned frame. Step 2: `cleaned_y <- .check_join_col_conflict(x, dplyr::bind_cols(...), by = character(0))`. Step 3: check `nrow(cleaned_y) == nrow(x@data)`. Step 4: `x@data <- dplyr::bind_cols(x@data, cleaned_y, .name_repair = .name_repair)`. — Effort: low, Risk: low, Impact: guard is structurally sound
- **[B]** Change Step 2 to check each element of `...` for conflicts individually, dropping offending columns per element, then proceed with the cleaned elements. — Effort: medium, Risk: medium (complex iteration), Impact: more granular but harder to specify
- **[C] Do nothing** — the conflict guard warns but never cleans; conflicting design-variable columns are always bound.

**Recommendation: A** — naming the return value explicitly is the minimal fix; it also models the correct `y <- .check_join_col_conflict(...)` pattern for `left_join` and `inner_join` implementers.

---

#### Section: §IV — `semi_join` / `anti_join` (test plan gap)

---

**Issue 15: `surveytidy_error_reserved_col_name` has no test**
Severity: REQUIRED
Violates: testing-standards.md §2 ("every error class gets a test"); testing-surveytidy.md (dual pattern for all user-facing errors)

§IV Step 2 specifies: "If `'..surveytidy_row_index..'` already exists in `names(x@data)`, error with `surveytidy_error_reserved_col_name`." This error class is in the §IV error table. But scanning the entire test plan (§XII tests 1–30 + cross-design requirements), there is no test for this error. A passing test suite would not verify this guard exists.

Options:
- **[A]** Add test (e.g., test 13b) for `semi_join` and one for `anti_join`: construct a design where `x@data` already contains `"..surveytidy_row_index.."`, call `semi_join()`/`anti_join()`, and assert `surveytidy_error_reserved_col_name` with dual pattern (class check + snapshot). — Effort: low, Risk: none, Impact: all error classes tested
- **[B]** Add a single parametrized test that calls both `semi_join` and `anti_join` with the reserved column present. — Effort: low, Risk: none, Impact: same coverage, fewer test blocks
- **[C] Do nothing** — error class is spec'd but never verified.

**Recommendation: A** — surveytidy.md requires dual pattern for all user-facing errors; this is a user-facing error with no test.

---

#### Section: §III / §VI — DRY (return-value capture pattern)

---

**Issue 16: `.check_join_col_conflict` return-value capture not shown in `left_join` or `inner_join` behavior rules**
Severity: SUGGESTION
Violates: engineering-preferences.md §5 (explicit over clever); Lens 1 — DRY

The helper table defines `.check_join_col_conflict(x, y, by)` as returning cleaned `y`. The behavior rules for `left_join` Step 2 say "drop the conflicting columns from `y` before proceeding. The join continues with the cleaned `y`" — but no assignment is shown. In R, functions don't mutate arguments; the return value must be captured (`y <- .check_join_col_conflict(x, y, by)`). An implementer not capturing the return value would have a guard that warns but doesn't clean.

Same omission in `inner_join` domain-aware Step 2 ("Warn + drop conflicting columns from `y` before proceeding") and `inner_join` physical mode Step 3.

Separately, `bind_cols` Step 2 is structurally fixed by Issue 14. This suggestion covers the `left_join` and `inner_join` call sites only.

Options:
- **[A]** In §III Step 2 and §VI Step 2 (domain-aware) and Step 3 (physical), show the explicit assignment: "`y <- .check_join_col_conflict(x, y, by)`. Subsequent steps use the cleaned `y`." — Effort: low, Risk: none, Impact: unambiguous for implementers
- **[B]** Add a note in the §II helper table: "Callers must capture the return value: `y <- .check_join_col_conflict(...)`." — Effort: low, Risk: low (one place, easy to miss), Impact: covers all three call sites
- **[C] Do nothing** — skilled implementers infer the capture from the return type; R semantics make mutation-by-argument impossible.

**Recommendation: A** — the spec aims to be implementation-grade; showing the capture removes ambiguity at three call sites.

---

#### Section: §VIII — `bind_rows` (dispatch gap)

---

**Issue 17: `bind_rows` survey-in-non-first-position unaddressed — guard will not fire**
Severity: SUGGESTION
Violates: engineering-preferences.md §4 (handle more edge cases, not fewer); Lens 4 — Edge Cases

`bind_rows.survey_base(x, ...)` is dispatched when `x` is a survey object. But `dplyr::bind_rows(df, survey)` — where the survey is in `...`, not as `x` — dispatches based on `class(df)` (a plain data frame). The S3 method for `survey_base` never fires. The call completes silently, producing an invalid plain data frame with NA design variables merged in.

GAP-6 already acknowledges that the dispatch mechanism may not work even for `x`-as-survey. But GAP-6 focuses on whether `registerS3method` intercepts when `x` is first; neither GAP-6 nor the main spec addresses the case where the survey is NOT first.

Options:
- **[A]** Acknowledge this limitation in §VIII: "If the survey object is passed as a non-first argument to `bind_rows()`, S3 dispatch will not intercept the call. This edge case is out of scope for this spec; document the limitation in roxygen `@details`." — Effort: low, Risk: none, Impact: limitation is documented, not silently ignored
- **[B]** Intercept via `dplyr_reconstruct.survey_base` or a `vctrs` method to catch the case where a survey appears in `...`. — Effort: high, Risk: high (complex dispatch intercept), Impact: comprehensive protection
- **[C] Do nothing** — unspecified; GAP-6 partially covers it.

**Recommendation: A** — acknowledge and document the limitation rather than leaving it as a silent gap.

---

#### Section: §XII — Test Plan (missing edge case assertions)

---

**Issue 18: `visible_vars` not tested for `semi_join` / `anti_join` applied to a design with `visible_vars` set**
Severity: SUGGESTION
Violates: testing-standards.md §2 (all output changes tested); Lens 2 — Test Completeness

§XI specifies `visible_vars` is "Unchanged" for `semi_join` and `anti_join`. §XII's test plan has no test verifying this for either function. A `semi_join` implementation that accidentally resets `visible_vars` to `NULL` would pass all tests.

The symmetric test for `left_join` (tests 2 and 3: `visible_vars` extended when set; unchanged when NULL) exists. The equivalent for `semi_join`/`anti_join` does not.

Options:
- **[A]** Add an inline assertion to test 9 (semi_join happy path) and test 14 (anti_join happy path): when called on a design with `visible_vars` set, assert `result@variables$visible_vars` is identical to the original. — Effort: low, Risk: none, Impact: contract tested
- **[B]** Add standalone test blocks (e.g., test 9b / test 14b). — Effort: low, Risk: none, Impact: cleaner separation
- **[C] Do nothing** — `visible_vars` preservation untested for two functions.

**Recommendation: A** — inline assertions stay compact and follow the surveytidy pattern.

---

**Issue 19: `inner_join` physical mode: `visible_vars` unchanged assertion absent from test 24**
Severity: SUGGESTION
Violates: testing-standards.md §2 (all output changes tested); Lens 2 — Test Completeness

§VI physical-mode output contract: "`visible_vars` column list is unchanged (row op)." §XII test 24 ("inner_join(.domain_aware=FALSE) — removes unmatched rows + warns") has no assertion that `visible_vars` is unchanged after physical row removal. An implementation that clears `visible_vars` on physical subset (as `subset.survey_base` does not, but a hasty implementer might) would pass all tests.

Options:
- **[A]** Add one inline assertion to test 24: `expect_identical(result@variables$visible_vars, d@variables$visible_vars)`, where `d` was created with a `select()` call first. — Effort: low, Risk: none, Impact: physical-mode `visible_vars` contract tested
- **[B]** Dedicated test 24e for visible_vars under physical mode. — Effort: low, Risk: none, Impact: cleaner separation
- **[C] Do nothing** — physical mode `visible_vars` contract untested.

**Recommendation: A** — one assertion; no new test block needed.

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 3 |
| SUGGESTION | 5 |

**Total new issues:** 8

**Overall assessment:** The spec is in strong shape after Stage 4 resolution — all 12 Pass 1 issues are cleanly addressed, the helper table is internally consistent, and the test plan is substantially more complete. Three required issues remain: a missing behavior-rule step in `inner_join` domain-aware mode (the sentinel update), a structural defect in `bind_cols` where the conflict-cleaned frame is discarded before Step 4, and an untested error class (`surveytidy_error_reserved_col_name`). None requires architectural changes. The five suggestions address documentation clarity and minor test completeness gaps. Resolve the three REQUIRED issues before handing off to implementation.
