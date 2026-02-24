# Plan Review: Phase dedup-rename-rowwise

**Reviewed against:** `plans/implementation-plan-dedup-rename-rowwise.md` and `plans/spec-dedup-rename-rowwise.md`
**Review date:** 2026-02-24

---

## Section: PR Map (Header)

**Issue 1: False inter-PR merge ordering claim**
Severity: REQUIRED
Violates: github-strategy.md — PR dependency fields must be accurate

The plan header states: *"PRs may be developed in parallel but must be merged in
order due to the `rename_with` dependency on `.apply_rename_map()`."* This is
factually wrong. `.apply_rename_map()` is defined and consumed within PR 2 — it
is an **intra-PR dependency**, not an inter-PR one. All three PRs are genuinely
independent and can be merged in any order.

An implementer reading this will believe PR 1 must merge before PR 2 must merge
before PR 3, and may block themselves unnecessarily or waste time enforcing a
non-existent ordering.

The Sequencing section at the bottom contradicts the header by correctly stating
"All three PRs can be developed independently in parallel." The contradiction
needs to be resolved.

Options:
- **[A]** Remove the false claim from the header; update to: "PRs are independent
  and may be merged in any order. See Sequencing section for suggested order."
  — Effort: low, Risk: none, Impact: removes implementer confusion
- **[B]** Keep the header language but add a clarifying note that the dependency
  is intra-PR — Effort: low, Risk: low, Impact: partial fix
- **[C] Do nothing** — implementer may unnecessarily wait for PR 1 to merge
  before starting PR 2 review

**Recommendation: A** — the contradiction should be fully resolved, not patched.

---

## Section: PR 1 — `distinct()`

**Issue 2: "Dual pattern" language incorrectly applied to a warning**
Severity: REQUIRED
Violates: testing-surveytidy.md — error dual pattern (`expect_error(class=)` +
`expect_snapshot(error=TRUE)`) applies to errors only; warnings use
`expect_warning(class=)`

The acceptance criterion reads:
> `surveytidy_warning_distinct_design_var` issued when `...` includes a
> protected column (**tested with dual pattern**)

`surveytidy_warning_distinct_design_var` is a **warning**, not an error.
The testing standard defines the dual pattern only for errors. An implementer
who follows this criterion literally will write `expect_snapshot(error = TRUE,
...)` on a warning call, which will fail because the call does not error.

The correct assertion is `expect_warning(class = "surveytidy_warning_distinct_design_var")`.

Options:
- **[A]** Replace "tested with dual pattern" with "tested with
  `expect_warning(class = \"surveytidy_warning_distinct_design_var\")`" —
  Effort: low, Risk: none, Impact: prevents test implementation error
- **[B]** Add a note clarifying that "dual pattern" here means class= + snapshot
  but uses `expect_snapshot(warning = TRUE)` — Effort: low, Risk: medium,
  Impact: partial fix but non-standard
- **[C] Do nothing** — CI will fail; implementer will need to debug

**Recommendation: A** — use the exact assertion pattern from the testing standard.

No other issues in PR 1.

---

## Section: PR 2 — `rename_with()` + `.apply_rename_map()` refactor

**Issue 3: rename() @groups behavior after refactor has no dedicated test coverage**
Severity: REQUIRED
Violates: testing-surveytidy.md — every behavioral change must have a
corresponding test

The refactor of `rename.survey_base()` to delegate to `.apply_rename_map()`
introduces two new behaviors for the existing `rename()` verb (spec §IV.1):

1. **@groups update** — renaming a grouped column now updates `@groups` with
   the new name. Current `rename()` never touches `@groups`.
2. **Domain column protection** — renaming the domain column is now blocked
   (was: warned but allowed).

The spec's test plan (§VI.3) puts all `@groups` staleness tests under the
`rename_with()` section. The "rename.R refactor regression" section only says:

> `rename(d, new = old)` still works identically after `.apply_rename_map()`
> extraction (confirm no behavioral change)

But there **are** behavioral changes to `rename()`. An implementer following
the spec's test plan strictly will not write a test for `rename()` @groups
behavior. The plan's acceptance criterion `@groups updated when renamed column
is in @groups (tested)` is ambiguous — it does not say whether this refers to
`rename()`, `rename_with()`, or both.

Both verbs share the helper, so both verbs need `@groups` staleness coverage.

Options:
- **[A]** Add a dedicated test assertion in the "rename.R refactor regression"
  section of `test-rename.R` for `rename()` + @groups behavior:
  `rename(group_by(d, y1), z = y1)` → `result@groups == "z"`. State this
  explicitly in the PR 2 acceptance criteria as a separate checkbox.
  — Effort: low, Risk: none, Impact: closes the coverage gap for rename()
- **[B]** Clarify the acceptance criterion to read "both rename() and
  rename_with() update @groups when a renamed column is in @groups (each
  tested separately)" — Effort: low, Risk: low, Impact: prevents ambiguity
- **[C] Do nothing** — rename() @groups behavior remains untested; behavioral
  regression will not be caught

**Recommendation: A** — the spec should be updated to add a test, and the
acceptance criterion should name both verbs explicitly.

---

## Section: PR 3 — `rowwise()`, mutate routing, predicates, group_by fix

**Issue 4: mutate ungroup-after-rowwise-mutation instruction is ambiguous**
Severity: REQUIRED
Violates: engineering-preferences.md — explicit over clever; implementation
notes must be unambiguous

The plan states (Notes section for PR 3):
> "After the `dplyr::mutate(base_data, ...)` call in the rowwise branch, add:
> `new_data <- dplyr::ungroup(new_data)`"

The existing `mutate.survey_base()` has **one** `rlang::inject(dplyr::mutate(...))`
call that is shared across all execution paths — it is not structured as separate
per-branch calls. All three execution paths (rowwise / grouped / plain) flow into
the same inject call. After the inject call, the result is a single `new_data`.

The phrase "in the rowwise branch" implies a conditional guard, but there is no
explicit `if (is_rowwise) { ... }` structure around the inject call. An implementer
may reasonably read "after the mutate call in the rowwise branch" as "just after
the inject() call, without any guard" — which would ungroup ALL mutations, not just
rowwise ones. `dplyr::ungroup()` on a plain `tbl_df` is a no-op, so this would not
break correctness, but it is unnecessary overhead and creates a latent coupling.

The plan should specify the exact conditional guard required:

```r
new_data <- rlang::inject(dplyr::mutate(base_data, ...))
if (is_rowwise) {
  new_data <- dplyr::ungroup(new_data)
}
```

Options:
- **[A]** Add the explicit `if (is_rowwise)` conditional to the Notes section,
  making clear that `dplyr::ungroup()` is applied only when `is_rowwise == TRUE`
  — Effort: low, Risk: none, Impact: prevents ambiguous implementation
- **[B]** Restructure the mutate pseudocode to show the full inject call in
  context with the conditional guard in place — Effort: medium, Risk: none,
  Impact: maximally clear
- **[C] Do nothing** — implementer may apply ungroup unconditionally (no
  correctness bug, but unspecified behavior)

**Recommendation: A** — add the explicit conditional.

---

## Section: Sequencing and Merge Order

**Issue 5: Merge conflict risk in reexports.R and zzz.R not addressed**
Severity: SUGGESTION
Violates: github-strategy.md — PR workflow

All three PRs modify `R/reexports.R` and `R/zzz.R`. When developed in parallel
and merged sequentially, PRs 2 and 3 will encounter merge conflicts in these files
(PR 1 will have changed them before PRs 2 and 3 are merged). Standard GitHub Flow
requires rebasing each branch onto main before merge.

The plan does not mention this requirement anywhere. An implementer who opens all
three PRs simultaneously and merges them without rebasing will have CI failures
on PRs 2 and 3 due to conflicts.

Options:
- **[A]** Add a note to the Sequencing section: "Before merging PRs 2 and 3,
  rebase onto main to resolve merge conflicts in `R/reexports.R` and `R/zzz.R`."
  — Effort: low, Risk: none, Impact: prevents avoidable CI failures
- **[B] Do nothing** — standard developer practice; merge conflicts are expected
  and handled normally

**Recommendation: A** — explicitly noting this saves implementer time.

---

## Section: Pre-Implementation Checklist

**Issue 6: Per-PR line coverage floor missing from acceptance criteria**
Severity: SUGGESTION
Violates: testing-standards.md — "PRs that drop coverage below 95% are blocked by CI"

Every PR's acceptance criteria list `devtools::test()` pass but do not include
a per-PR coverage floor. The plan defers all coverage verification to a single
`covr::package_coverage()` call after all three PRs are merged.

CI blocks PRs below 95% per testing-standards.md. An implementer who writes
insufficient tests on PR 1 will learn this at CI time, not from reading the plan.
Making the per-PR expectation explicit prevents late surprises.

Options:
- **[A]** Add to each PR's acceptance criteria: "Line coverage does not drop
  below 95% (CI enforced)" — Effort: low, Risk: none, Impact: sets expectations
- **[B] Do nothing** — CI enforces it anyway

**Recommendation: A** — alignment with the published standard is worth stating
explicitly.

---

## Section: PR 3 — File Completeness

**Issue 7: test-group-by.R omission from PR 3 file list creates ambiguity**
Severity: SUGGESTION
Violates: testing-surveytidy.md file-mapping convention (R/group-by.R →
tests/testthat/test-group-by.R)

PR 3 modifies `R/group-by.R` with two new behavioral changes: `group_by()` `.add
= TRUE` rowwise-exit logic and `ungroup()` rowwise key clearing. The spec's test
plan (§VI.4 Sections 3 and 4) deliberately places these tests in `test-rowwise.R`,
not `test-group-by.R`. This is a valid design choice — the behavior is only
meaningful in the rowwise context.

However, the plan's file list for PR 3 does not mention `test-group-by.R` at all,
leaving it unclear whether the omission is intentional or an oversight. An
implementer following the file-mapping rule might also write tests in
`test-group-by.R`, or conversely might wonder why group-by behaviors are tested
in `test-rowwise.R`.

Options:
- **[A]** Add a note to the PR 3 file list: "`tests/testthat/test-group-by.R` —
  NOT modified; new group_by/ungroup rowwise behaviors tested in test-rowwise.R
  per spec §VI.4. Existing tests must still pass." — Effort: low, Risk: none,
  Impact: removes ambiguity
- **[B] Do nothing** — spec §VI.4 is the authoritative test plan; implementer
  can reference it

**Recommendation: A** — one sentence prevents confusion without changing scope.

---

## Summary

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 4 |
| SUGGESTION | 3 |

**Total issues:** 7

**Overall assessment:** The plan is well-structured and spec-complete — all three
deliverables are covered, the file lists are accurate, and the implementation
notes contain the right technical detail. Four required fixes are needed before
coding starts: the misleading merge-ordering claim in the header, the incorrect
"dual pattern" language for a warning test, an explicit coverage gap for rename()
@groups behavior post-refactor, and an ambiguous mutate ungroup instruction that
could produce an unconditional application of `dplyr::ungroup()`. None of these
will cause incorrect code if the implementer is careful, but all four will cause
confusion or missing test coverage if they are not resolved.
