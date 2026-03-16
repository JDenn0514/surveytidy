## Methodology Review: transform — Pass 1 (2026-03-13)

### Scope Assessment

These are pure vector-level functions, not dplyr verbs. Checking Stage 2 trigger
conditions:

| Trigger | Applies? | Reason |
|---------|----------|--------|
| Creates/reads/modifies domain column | ❌ | These functions never touch `..surveycore_domain..` |
| Could change row count | ❌ | All four functions return a vector of `length(x)` |
| Could affect design variable columns | ⚠️ Indirect | Can be called inside `mutate()` on any column including design vars |
| Changes `@variables`, `@metadata`, `@groups`, `visible_vars` | ✅ | All four output contracts describe `@metadata` changes via `mutate()` post-detection |
| Shape-changing operation | ❌ | No joins, nest, pivot |

**Stage 2 is applicable** on two grounds: (1) the functions modify `@metadata` via the
`mutate()` protocol (Lens 5), and (2) they can be applied to design variable columns
inside `mutate()` with uncertain protection (Lens 3 Sub-lens B).

---

### New Issues

#### Lens 1 — Domain Semantics

No issues found. These functions operate on plain R vectors and never interact with the
domain column. Domain column pass-through is entirely the responsibility of the existing
`mutate.survey_base()` protocol; the spec correctly does not address it.

---

#### Lens 2 — Row Universe Integrity

Not applicable. All four functions return vectors of the same length as input (`length(x)`).
No rows are added, removed, or reordered.

---

#### Lens 3 — Design Variable Integrity

**Issue 1: Transform functions applied to non-weight design variable columns — spec claims existing `mutate()` protection is sufficient without verifying it**
Severity: REQUIRED
Lens: 3 — Design Variable Integrity (Sub-lens B)
Resolution type: JUDGMENT CALL

Section X.I states: "No new hooks or `mutate()` machinery are required." This claim is
accurate for the transform functions themselves — they are pure vector functions with no
awareness of the survey design. But the claim implies the *existing* `mutate.survey_base()`
protection covers the full risk surface. It does not.

Per `CLAUDE.md` and `plans/error-messages.md`, the only design-variable warning in
`mutate.survey_base()` is `surveytidy_warning_mutate_weight_col` — a **weight-column-only**
warning. There is no corresponding protection for `ids` (PSU/cluster), `strata`, or `fpc`
columns.

Concrete failure scenarios:

- `mutate(d, strata = make_factor(strata))` — strata column becomes an R factor; the
  variance estimator may behave unexpectedly with a factor strata column; no warning is
  issued.
- `mutate(d, psu = make_rev(psu))` — PSU IDs are numerically reversed; the clustering
  structure is completely scrambled; no warning is issued.
- `mutate(d, fpc = make_rev(fpc))` — finite population correction values are inverted;
  variance estimates are wrong; no warning is issued.

The transform spec cannot fix this (the functions are pure vector operations with no
design context). But the spec should acknowledge the gap and specify whether resolution
belongs here (via a note) or in the `mutate.R` spec (via extending the warning to all
design variables).

Options:
- **[A]** Add a note to Section X.I acknowledging the limitation: "The existing
  `mutate.survey_base()` warning covers weight columns only. Applying transform functions
  to strata, PSU, or FPC columns inside `mutate()` is not warned against; this is a known
  limitation of the current `mutate.survey_base()` implementation." — Effort: low,
  Risk: low, Impact: sets accurate expectations without touching the transform code
- **[B]** Extend `mutate.survey_base()` warnings to all design variable column types
  (open a separate issue/spec for `mutate.R`) — Effort: medium, Risk: low,
  Impact: closes the gap entirely but out of scope for this spec
- **[C] Do nothing** — spec makes an unsupported adequacy claim; strata/PSU/FPC
  transforms are silently dangerous

**Recommendation: A** — The transform spec cannot fix `mutate.survey_base()`, but it
should not make an accuracy claim it cannot verify. A note corrects the record and
creates a clear action item for the `mutate.R` spec.

---

#### Lens 4 — Variance Estimation Validity

No issues found. `@metadata` changes (variable labels, value labels, transformation log)
are cosmetic/descriptive — the variance estimator uses column values directly, not
`@metadata`. Any indirect risk flows from Lens 3 above.

---

#### Lens 5 — Structural Transformation Validity

**Issue 2: `make_rev()` all-NA path — label remapping behavior is unspecified; typeof() contract is broken for integer input**
Severity: REQUIRED
Lens: 5 — Structural Transformation Validity
Resolution type: UNAMBIGUOUS

The spec defines the all-NA case via behavior rule 4: "Return all-`NA` vector with same
type. Issue `surveytidy_warning_make_rev_all_na`." But it does not specify:

1. **Label attribute behavior**: Behavior rule 3 (label remapping) runs independently
   from rule 4. An implementer following the rule order would compute
   `m <- min(x, na.rm=TRUE) + max(x, na.rm=TRUE)` → `Inf + (-Inf)` → `NaN`, then
   compute `NaN - old_value` → `NaN` for every label entry. The function returns an
   all-NA vector but with `attr(result, "labels")` = `c("Label A" = NaN, ...)`.
   `mutate()` post-detection then writes these NaN-valued labels to
   `@metadata@value_labels[[col]]`. A downstream `make_factor()` call on this column
   reads the NaN labels and fires `surveytidy_error_make_factor_incomplete_labels` for
   every observed value — a cryptic error with no apparent cause.

2. **`typeof()` contract broken for integer input**: For an all-NA integer vector,
   `min(x, na.rm=TRUE)` = `Inf` (double). The formula `Inf + (-Inf) - NA_integer_` =
   `NA_real_` (double). Rule 4 says "same type" but the formula produces the wrong type.
   The rule ordering implies the formula runs first and the type check is never applied.

**Correct fix** (UNAMBIGUOUS):
- Add an explicit early-return check: if `all(is.na(x))`, skip label remapping entirely
  and return `vector(typeof(x), length(x)) * NA` (or equivalent — an all-NA vector with
  the same `typeof()` as `x`). Preserve `attr(x, "labels")` unchanged on this early-return
  path.
- Rewrite behavior rule 3 to include: "Skipped when all values in `x` are `NA` (see rule 4)."
- Rewrite behavior rule 4 to include: "Short-circuit before computing `min`/`max`. Preserve
  `attr(x, 'labels', exact = TRUE)` unchanged on the result."

Options:
- **[A]** Apply the fix above — add early-return before formula, preserve labels unchanged,
  return correct typeof. — Effort: low, Risk: low, Impact: closes two bugs in one pass
- **[B] Do nothing** — implementer produces NaN labels and wrong typeof for all-NA integer
  input; downstream `make_factor()` fails cryptically

**Recommendation: A** — The all-NA path is explicitly called out as a special case; the
spec just needs to fully specify it.

---

**Issue 3: `make_binary()` `@metadata` description says "same as `make_factor()`" but immediately contradicts it**
Severity: SUGGESTION
Lens: 5 — Structural Transformation Validity
Resolution type: UNAMBIGUOUS

Section V (`make_binary()`) states:

> `@metadata` changes (via `mutate()` post-detection): same as `make_factor()`.
> Because `attr(result, "labels")` is non-NULL, `@metadata@value_labels[[col]]`
> is set to the binary mapping.

`make_factor()` clears `@metadata@value_labels[[col]]` to `NULL`. `make_binary()` sets it to
the binary mapping. These are opposites. The phrase "same as `make_factor()`" is false for
the value_labels entry. An implementer who reads the first sentence before the second could
implement the wrong behavior.

**Correct fix** (UNAMBIGUOUS): Remove the "same as `make_factor()`" shorthand. Replace with
explicit entries covering all three metadata fields:

```
`@metadata` changes (via `mutate()` post-detection):
- `@metadata@variable_labels[[col]]` ← `attr(result, "label")`
- `@metadata@value_labels[[col]]`    ← `c("{level1_name}" = 1L, "{level2_name}" = 0L)` (from `attr(result, "labels")`)
- `@metadata@transformations[[col]]` ← structured recode record with `description`
```

Options:
- **[A]** Replace the shorthand with explicit entries — Effort: low, Risk: low,
  Impact: eliminates the contradicting description
- **[B] Do nothing** — the second sentence partially overrides the first; a careful
  reader will figure it out, but a skimming implementer will get `value_labels = NULL`

**Recommendation: A** — One sentence fix; no ambiguity in what the right answer is.

---

## Summary (Pass 1)

| Severity | Count |
|----------|-------|
| BLOCKING | 0 |
| REQUIRED | 2 |
| SUGGESTION | 1 |

**Total issues:** 3

**Overall assessment:** The domain and row-universe methodology is sound — these are pure
vector functions that correctly delegate survey concerns to the existing `mutate()` protocol.
Two targeted fixes are needed before coding: `make_rev()`'s all-NA path is underspecified in
two distinct ways (label remapping runs when it shouldn't, typeof contract broken for integer
input), and the spec makes an overstated claim about design variable protection in
`mutate.survey_base()` that should be narrowed to what is actually true.
