## Spec Review: rowstats — Pass 1 (2026-04-15)

_First pass; no prior issues to carry forward._

---

### New Issues

#### Section I — Scope

No issues found.

---

#### Section II — Architecture

**Issue 1: `.validate_transform_args()` does not validate `na.rm` — spec is silent on the gap**
Severity: REQUIRED
Violates engineering-preferences.md §5 (explicit over clever) and testing-standards.md §2 (all error paths tested)

The spec states `.validate_transform_args(label, description, error_class)` will be
moved to `utils.R` and called by `row_means()` / `row_sums()`. But the existing
function only validates `.label` and `.description`. `na.rm` has its own entry in the
error table (`surveytidy_error_rowstats_bad_arg` | "`na.rm` is not a single non-NA
`logical(1)`") and must be validated separately.

The spec says nothing about how `na.rm` validation is wired — whether inline before
calling `.validate_transform_args()` (the natural pattern, consistent with how
`make_rev()` validates its unique args before calling the shared helper), or whether
`.validate_transform_args()` is extended. An implementer reading only this spec would
not know which approach is intended.

Options:
- **[A] State explicitly that `na.rm` is validated inline** — add one sentence to §II:
  "`na.rm` is validated with an inline `cli_abort()` call before `.validate_transform_args()`
  is called for `.label` and `.description`." Effort: minimal, Risk: low, Impact: removes
  ambiguity without changing the design.
- **[B] Extend `.validate_transform_args()` to accept an optional `na.rm` parameter** —
  more DRY, but changes a shared function already used by 8 call sites in `transform.R`.
  Effort: low, Risk: medium (touches existing function, could break transform tests).
- **[C] Do nothing** — implementer infers the inline approach; risk of inconsistency is low
  but present.

**Recommendation: A** — Inline `na.rm` validation is the established pattern (see
`make_rev()`, `make_flip()`). Making it explicit costs nothing and removes the only
ambiguity in the validation section.

---

#### Section III — `row_means()`

**Issue 2: `surveycore::.get_design_vars_flat(x)` in §IX will generate an R CMD check note**
Severity: REQUIRED
Violates r-package-conventions.md (R CMD check: 0 warnings, ≤2 pre-approved notes)

§IX Integration Contracts states: "intersect `source_cols` with
`surveycore::.get_design_vars_flat(x)`". Using `:::` generates:

```
Unexported objects imported by ':::' calls: 'surveycore:::.get_design_vars_flat'
```

This is **not** one of the two pre-approved notes. The codebase already has an established
workaround: `.survey_design_var_names()` in `R/utils.R` (see `utils.R:43–49` and its
use in `mutate.R:140`). The spec must specify `.survey_design_var_names(x)` instead of
`surveycore::.get_design_vars_flat(x)` in §IX.

Note: The warning detection lives in `mutate.survey_base()` which has access to `.data`
(the survey object), so `.survey_design_var_names(.data)` is the correct call.

Options:
- **[A] Replace `surveycore::.get_design_vars_flat(x)` with `.survey_design_var_names(x)`
  in §IX** — Effort: minimal (one-line spec edit), Risk: none, Impact: prevents an R CMD
  check NOTE that would block the PR.
- **[B] Do nothing** — The implementer may catch it during `devtools::check()`, but the
  spec is actively misleading.

**Recommendation: A** — Straightforward fix; the codebase already has the right abstraction.

**Issue 3: Error message `"x"` bullet for `na.rm` is missing "non-NA"**
Severity: REQUIRED
Violates code-style.md §3 (message language: `"x"` bullet must accurately describe the
failing condition)

The error table entry:

> `"x"`: "`na.rm` must be a single logical value."

The trigger condition is "`na.rm` is not a single **non-NA** `logical(1)`." When
`na.rm = NA` (class logical, length 1), the check fires but the message says only "single
logical value" — `NA` IS logical and IS length 1. The message would be factually wrong
for the `NA` case.

The correct `"x"` bullet: `` "`na.rm` must be a single non-NA logical value." ``

Options:
- **[A] Fix the message template in the spec error table** — change to "single non-NA
  logical value." Effort: trivial, Risk: none, Impact: accurate error message.
- **[B] Do nothing** — the `NA` case produces a message that doesn't explain why it failed.

**Recommendation: A** — Trivial fix; the `NA` case is a real trigger scenario.

**Issue 4: Test plan does not specify the dual error pattern**
Severity: REQUIRED
Violates testing-surveytidy.md §"Error Testing Pattern" (dual: `expect_error(class=)` +
`expect_snapshot(error=TRUE)`)

Tests 11 and 17 are described only as:

> `# 11. row_means() — bad .label / .description / na.rm → surveytidy_error_rowstats_bad_arg`
> `# 17. row_sums() — bad args → surveytidy_error_rowstats_bad_arg`

The testing standard requires BOTH assertions for every user-facing error:

```r
expect_error(..., class = "surveytidy_error_rowstats_bad_arg")
expect_snapshot(error = TRUE, ...)
```

Without an explicit call-out in the spec, an implementer may write only the typed
`expect_error()` and skip the snapshot — producing incomplete test coverage that will
pass CI but miss message text regressions.

Options:
- **[A] Add one sentence to §VII** — "Tests 11 and 17 must use the dual pattern:
  `expect_error(class=)` plus `expect_snapshot(error=TRUE)` for each trigger case, per
  `testing-surveytidy.md`." Effort: minimal, Risk: none.
- **[B] Do nothing** — Testing standard already covers this; the spec need not repeat it.

**Recommendation: A** — The testing standard is authoritative, but the spec's own test
section is incomplete without this note. Every other test spec in this codebase that
lists error tests explicitly calls out the dual pattern. Consistency matters here.

---

#### Section III / VII — Edge Cases

**Issue 5: No test for calling `row_means()` / `row_sums()` outside a dplyr context**
Severity: SUGGESTION
Violates engineering-preferences.md §4 (handle more edge cases, not fewer)

§III Behavior Rule 1 documents: "If called outside a dplyr context, `dplyr::pick()`
itself will throw a clear error — `row_means()` does not suppress or rethrow this."
This is a deliberate design decision. The test plan has 23 entries but none verify this
out-of-context behavior. Without a test, the decision is stated but unverified.

Options:
- **[A] Add a test** — `# 24. row_means() / row_sums() — called outside mutate() →
  dplyr::pick() error propagates`. Use `expect_error()` without a class (since the
  error class is dplyr's, not ours). Effort: low, Risk: none, Impact: spec decision
  is verified, not just documented.
- **[B] Add a comment in the test plan** — Note that the out-of-context case is tested
  by dplyr itself and we rely on that. Effort: trivial, Impact: acknowledges the gap
  without adding a test.
- **[C] Do nothing** — the behavior rule is clear enough.

**Recommendation: A** — One `expect_error()` call is cheap. The spec explicitly states
what should happen; a test should confirm it.

**Issue 6: `source_cols` column order is unspecified**
Severity: SUGGESTION
Violates engineering-preferences.md §5 (explicit over clever)

§III Behavior Rule 5 says: "`source_cols` is always the character vector of resolved
column names from `names(dplyr::pick({{ .cols }}))`. " `dplyr::pick()` returns columns
in data-frame column order — not the user's selector order. So:

```r
mutate(d, score = row_means(c(y3, y1, y2)))
# source_cols = c("y1", "y2", "y3")  ← data-frame order, not selector order
```

The test plan includes "explicit column list `c(y1, y2, y3)`" for `starts_with()`
and `where()` (tests 8–10) but only checks that the correct columns are recorded, not
their order. If an implementer relies on `names(pick(...))` naturally (it returns
data-frame order), this is fine — but since no test pins order, a future change could
silently alter `@metadata@transformations[[col]]$source_cols` ordering.

Options:
- **[A] Add a note to Behavior Rule 5** — "Column names are returned in data-frame
  column order (i.e., the order they appear in `@data`), regardless of the order
  specified in the selector." Effort: trivial, Risk: none.
- **[B] Do nothing** — the existing implementation will be data-frame order by default.

**Recommendation: A** — One sentence; prevents confusion during implementation and review.

---

#### Section IV — `row_sums()`

No issues found. `row_sums()` correctly mirrors `row_means()` with the `rowSums`-specific
behavior (0 vs NaN for all-NA rows) properly distinguished.

---

#### Section VII — Testing

**Issue 7: `test_invariants()` required on every block — applies to row agg results too**
Severity: SUGGESTION
Violates testing-surveytidy.md §"`test_invariants()` — required in every verb test block"

The spec states (correctly): "Every `test_that()` block that creates or transforms a
survey object must call `test_invariants(result)` as its **first** assertion." But tests
1–23 all go through `mutate()`, which returns a survey object. The spec should confirm
that `test_invariants()` is called on the result of the `mutate()` call in every block —
not just in the final result after the computation — since `mutate()` is what actually
modifies the survey object.

This is more of a clarification than a gap, but it is worth stating explicitly since an
implementer might call `test_invariants()` on the raw `row_means()` return value (a plain
vector, which would fail the check) rather than on the `mutate()` result.

Options:
- **[A] Add a clarifying note** — "In tests 1–23, `test_invariants()` is called on the
  result of `mutate(d, col = row_means(...))`, not on the raw `row_means()` return value."
  Effort: trivial, Impact: prevents a subtle testing mistake.
- **[B] Do nothing** — the testing standard is clear enough.

**Recommendation: A** — Trivial; prevents one specific mistake that would produce
misleading test failures.

---

#### Section VIII — Quality Gates

No issues found. The gate list is thorough and correctly captures all post-GAP-resolution
requirements.

---

#### Section IX — Integration Contracts

_(Issue 2 above covers the `surveycore:::` usage in this section.)_

**Issue 8: `effective_label = NULL` scenario is unreachable via public API**
Severity: SUGGESTION
Violates engineering-preferences.md §5 (explicit over clever — document assumptions)

§III Behavior Rule 4 states: "`effective_label` may be NULL, which clears any existing
label." But:

- If called inside `mutate()`: `dplyr::cur_column()` succeeds and returns the output
  column name (a string), so `effective_label` is always non-NULL.
- If called outside `mutate()`: `dplyr::pick()` throws before `effective_label` is ever
  used, so the NULL branch is unreachable.

The "may be NULL, which clears any existing label" statement is misleading — it implies a
valid call path where effective_label is NULL and the recode attr is captured by
`mutate.survey_base()`. In practice, `effective_label` is always a string when the attr
reaches `mutate.survey_base()`.

Options:
- **[A] Revise the wording** — Change "may be NULL, which clears any existing label" to
  "will be the output column name when called inside `mutate()`. If called outside a
  dplyr context, `dplyr::pick()` errors before the label is used." Effort: trivial.
- **[B] Add a note** — Keep the current text but add: "In practice, `effective_label` is
  never NULL when `mutate.survey_base()` processes the recode attr, since calling outside
  `mutate()` errors first." Effort: trivial.
- **[C] Do nothing** — The "may be NULL" path is harmless even if unreachable.

**Recommendation: B** — A clarifying note is better than silence on a potentially
confusing edge case.

---

### Open GAPs Status

The spec lists GAP-1 through GAP-5, all deferred to Stage 4. This is correct procedure.
The following observations apply:

- **GAP-1** (`.set_recode_attrs()` — move or inline): The function is 4 lines with
  8 call sites in `transform.R`. Moving it risks churn; duplicating inline is clean for
  2 new call sites. The spec is right to defer, but the decision should happen before
  implementation begins.
- **GAP-2 / GAP-3** (non-numeric columns / zero columns): Both are closely related.
  Resolving GAP-2 first is advisable since non-numeric already errors via `rowMeans()`;
  the question is only message quality.
- **GAP-4 / GAP-5** are directly dependent on GAP-2/3 resolutions. All four should be
  resolved in a single Stage 4 pass.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 4 |
| SUGGESTION | 4 |

**Total issues:** 8

**Overall assessment:** The spec is nearly implementable. No blocking gaps — the
methodology is sound, the attribute protocol is correctly integrated, and the GAP
structure is appropriate for deferred decisions. The four REQUIRED issues are: (1) the
`:::` reference in §IX that will produce an R CMD check NOTE, (2) the missing "non-NA"
in the `na.rm` error message, (3) the unspecified `na.rm` validation mechanism relative
to `.validate_transform_args()`, and (4) the absent dual-pattern specification in the
test plan. All are small fixes. The four SUGGESTION items are clarifications that improve
precision without changing design. Resolve the REQUIRED issues in Stage 4 before opening
an implementation plan.
