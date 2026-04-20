## Methodology Review: rowstats — Pass 1 (2026-04-15)

### Scope Assessment

`row_means()` and `row_sums()` are plain R functions called inside `mutate()`.
They do not implement a verb directly. Stage 2 applies because:

- `@metadata@variable_labels` and `@metadata@transformations` are written via
  the `surveytidy_recode` attribute protocol (Lens 5).
- `.cols` evaluates against the full `@data` context, which includes design
  variable columns — a potential Design Variable Integrity concern (Lens 3).

All five lenses applied; lenses 1, 2, and 4 have no issues.

---

### New Issues

#### Lens 1 — Domain Semantics

No issues found.

The spec explicitly states in §III Output contract: "`@variables`, `@groups`,
the domain column, and `visible_vars` are all unchanged by `row_means()` itself
— `mutate()` manages these per its existing logic." The same statement appears
for `row_sums()`. Test #18 further confirms domain preservation is a required
test. The domain semantics are entirely delegated to `mutate.survey_base()`,
which already handles them correctly. No gaps.

---

#### Lens 2 — Row Universe Integrity

No issues found.

`row_means()` and `row_sums()` return a `double` vector of length `nrow` of the
current data context. Row count and row order are unchanged. No physical
subsetting occurs.

---

#### Lens 3 — Design Variable Integrity

**Issue 1: No check or warning when design variable columns are included in `.cols`**
Severity: REQUIRED
Lens: 3 — Design Variable Integrity
Resolution type: JUDGMENT CALL

The spec defines `.cols` as a tidyselect expression evaluated via
`dplyr::pick({{ .cols }})` in the current `@data` context. `@data` contains
all design variable columns — weights, strata IDs, PSU IDs, FPC, and replicate
weights. A user who writes `row_means(where(is.numeric))` or
`row_sums(starts_with(""))` can silently include numeric design variables
(weights, FPC, numeric strata codes) in the row aggregation. The result is
arithmetically well-formed (no error) but methodologically meaningless — a
weighted mean that averages survey responses together with sampling weights.

The spec does not address this case in any behavior rule, error class, or
GAP. The GAP list covers non-numeric columns (GAP-2) and zero columns (GAP-3)
but not design-variable inclusion. There is no warning class defined for this
scenario in the error table (§III).

Concrete failure modes:
- `mutate(d, score = row_means(where(is.numeric)))` — silently includes `wt`
  and any numeric strata/PSU codes in the mean.
- `mutate(d, score = row_sums(starts_with("y")))` where a weight column is
  named `"yt_wt"` — silently included with no feedback.

The `mutate.survey_base()` already warns (`surveytidy_warning_mutate_weight_col`)
when a design variable column is **written to**. This spec has no analogous
warning for when a design variable column is **read as an input** to `row_means()`
or `row_sums()`.

Options:
- **[A] Warn with a new class** — After resolving `.cols` to `source_cols`,
  intersect `source_cols` with `surveycore::.get_design_vars_flat(context)`
  and emit `surveytidy_warning_rowstats_includes_design_var` if any overlap is
  found. Lists the offending column names. The computation proceeds. Effort:
  low (one intersect call + warn), Risk: low (additive, no behavioral change),
  Impact: users get a clear signal when they accidentally include design vars.
- **[B] Error with a new class** — Same detection logic but throw
  `surveytidy_error_rowstats_includes_design_var` instead of warning. Effort:
  low, Risk: low, Impact: stricter — prevents the computation entirely.
- **[C] Document explicitly that no check is performed** — Add a behavior rule
  stating that `.cols` may include design variables and the user is responsible.
  Effort: minimal, Risk: low, Impact: silent wrong behavior persists but is now
  documented.

**Recommendation: A** — A warning is consistent with `mutate.survey_base()`'s
pattern of warning (not erroring) on design variable involvement. It allows
the rare intentional use case to proceed while surfacing accidental inclusion.
A hard error (B) would be overly restrictive since no design variable is being
modified. Silent documentation-only (C) is insufficient given how easy it is
to trigger with `where(is.numeric)`.

---

**Issue 2: Spec does not document that `.cols` resolves against the full `@data` context including design variables**
Severity: SUGGESTION
Lens: 3 — Design Variable Integrity
Resolution type: UNAMBIGUOUS

The spec describes `.cols` as "evaluated via `dplyr::pick()`" and lists typical
values (`c(a, b, c)`, `starts_with("y")`, `where(is.numeric)`) in the argument
table. It does not note that the resolution context includes all columns in
`@data`, including design variables. This is particularly important for
`where(is.numeric)`, which will match weight and FPC columns without any visual
cue in the code.

This is a user-education gap that independent of Issue 1's resolution (even if
a warning is added, users should understand what columns are in scope).

Fix: Add to §III Behavior Rule 1 and §IV Behavior Rule 1 a note that
`dplyr::pick()` evaluates in the full `@data` context, which includes design
variable columns (weights, strata, PSU IDs, FPC, repweights). Advise users to
use targeted selectors (e.g., `starts_with("y")`, explicit `c(y1, y2, y3)`)
rather than `where(is.numeric)` unless they intend to include all numeric
columns.

---

#### Lens 4 — Variance Estimation Validity

No issues found.

`row_means()` and `row_sums()` do not modify `@variables`, so the variance
estimator's references to weight/strata/PSU column names remain intact.
The output column is a new data column added via `mutate()`; it carries no
design-variable semantics. If Issue 1 is resolved with a warning, the
downstream variance estimator is unaffected since the design structure is
preserved regardless of what values appear in the output column.

---

#### Lens 5 — Structural Transformation Validity

No issues found.

The spec carefully defines what gets written to `@metadata`:

- `@metadata@variable_labels[[col]]` — set to `effective_label`
- `@metadata@transformations[[col]]` — structured list with `fn`,
  `source_cols`, `expr`, `output_type`, `description`

The spec explicitly states that `@variables`, `@groups`, the domain column, and
`visible_vars` are unchanged by these functions — `mutate()` manages them.

The `surveytidy_recode` attribute protocol matches what `mutate.survey_base()`
reads at Steps 5a and 8. `source_cols` is correctly resolved to a character
vector of column names (not the unevaluated tidyselect expression) inside the
function, so the metadata records the actual columns used, not the selector.

The `effective_label` fallback via `tryCatch(dplyr::cur_column(), error = function(e) NULL)`
is correct: inside `mutate()`, `cur_column()` returns the output column name;
outside, the tryCatch returns NULL without crashing.

---

### Summary (Pass 1)

| Severity   | Count |
|------------|-------|
| BLOCKING   | 0     |
| REQUIRED   | 1     |
| SUGGESTION | 1     |

**Total issues:** 2

**Overall assessment:** The core methodology of `row_means()` and `row_sums()` is
sound — domain semantics, row universe integrity, and variance structure are all
correctly preserved via delegation to `mutate.survey_base()`. The single
REQUIRED issue is that `.cols` resolves against the full `@data` context
(including design variables), and the spec neither warns users nor emits any
signal when design variable columns are accidentally included in the aggregation.
This is the kind of silent wrong behavior that passes all tests — a user
computing `row_means(where(is.numeric))` gets a plausible-looking numeric column
with no indication it contains a mix of survey responses and sampling weights.
The spec must decide whether to warn or error on this case.
