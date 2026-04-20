---
Version: 0.1
Date: 2026-03-16
Status: Stage 1 draft — not reviewed
---

# Spec: Factor Manipulation Functions

## Feature branch: `feature/factor`

---

## Document Purpose

This is the source of truth for the `factor` feature. It governs the
design, contracts, error handling, and test plan for nine vector-level
functions that mirror the `forcats` package API — `fct_relevel()`,
`fct_recode()`, `fct_collapse()`, `fct_rev()`, `fct_drop()`,
`fct_na_value_to_level()`, `fct_reorder()`, `fct_infreq()`,
`fct_inorder()`, `fct_lump_n()`, and `fct_lump_prop()` — extended to
preserve the `label` attribute, update `labels` when relevant, and
record transformations via the `surveytidy_recode` attribute protocol.

These functions are **not dplyr verbs**. They operate on plain R vectors
(factors) and integrate with `mutate.survey_base()` via the existing
`surveytidy_recode` attribute protocol. No new `mutate()` machinery is
required.

The primary value-add over bare `forcats::fct_*()` is attribute
preservation: `forcats` strips the `label` attribute during most
operations. surveytidy's variants preserve it (or accept an override) and
record the transformation in `@metadata@transformations[[col]]` when used
inside `mutate()`.

All implementation decisions not covered here defer to:
- `code-style.md` (style, error structure, argument order)
- `r-package-conventions.md` (roxygen2, NAMESPACE, `::` usage)
- `testing-standards.md` + `testing-surveytidy.md` (coverage, invariants)

---

## I. Scope

### Delivered

| Function | Purpose |
|----------|---------|
| `fct_relevel(x, ..., after = NULL, .label, .description)` | Reorder factor levels manually |
| `fct_recode(x, ..., .label, .description)` | Rename factor levels |
| `fct_collapse(x, ..., other_level = NULL, .label, .description)` | Collapse multiple levels into groups |
| `fct_rev(x, .label, .description)` | Reverse factor level order |
| `fct_drop(x, only = NULL, .label, .description)` | Drop unused (or specified) factor levels |
| `fct_na_value_to_level(x, level = "(Missing)", .label, .description)` | Convert NA to an explicit factor level |
| `fct_reorder(x, y, .f = median, .desc = FALSE, .na_rm = TRUE, .label, .description)` | Reorder levels by a numeric summary of another variable |
| `fct_infreq(x, w = NULL, ordered = NA, .label, .description)` | Order levels by frequency |
| `fct_inorder(x, ordered = NA, .label, .description)` | Order levels by first appearance |
| `fct_lump_n(x, n, w = NULL, other_level = "Other", ties.method = "min", .label, .description)` | Keep top-n levels; lump rest into "Other" |
| `fct_lump_prop(x, prop, w = NULL, other_level = "Other", .label, .description)` | Keep levels above a proportion threshold; lump rest |

### Not Delivered (Deferred)

| Item | Reason |
|------|--------|
| `fct_lump_min()` | Less common than `n`/`prop`; add on request |
| `fct_lump_lowfreq()` | Niche use case; add on request |
| `fct_anon()` | Anonymisation not a survey analysis need |
| `fct_expand()` | Adding hypothetical levels rarely needed in survey work |
| `fct_cross()` | Creates interaction factor; out of scope for this phase |
| `fct_match()` | Utility predicate; not a transformation function |
| Labelled numeric input auto-coercion (in functions other than `fct_relevel`) | Keep each function focused on factors; use `make_factor()` first |

### Design Support

All functions are **pure vector operations** — they are design-agnostic.
They work identically regardless of whether the surrounding survey design
is `survey_taylor`, `survey_replicate`, `survey_twophase`, or
`survey_nonprob`. The design type matrix used for verb tests does not
apply here; tests use `make_all_designs()` solely to exercise the
`mutate.survey_base()` pathway, not the functions themselves.

---

## II. Architecture

### File Organization

```
R/
└── factor.R          # all eleven fct_* functions + file-local helpers
```

```
tests/testthat/
└── test-factor.R     # all tests for fct_* functions
```

### Helpers

#### `.set_recode_attrs()` — promote to `R/utils.R`

This helper is currently file-local in `R/transform.R`. `factor.R` will
be the second call site, so it must move to `R/utils.R` per the
single-file-only rule in `code-style.md`.

Signature (unchanged):
```r
.set_recode_attrs(result, label, labels, fn, var, description)
```

Arguments:
- `result` — the output vector
- `label` — `character(1)` or `NULL` — variable label
- `labels` — named vector or `NULL` — value labels (`NULL` for factor output)
- `fn` — `character(1)` — function name for the transformation log
- `var` — `character(1)` or `NULL` — column name (from `cur_column()`)
- `description` — `character(1)` or `NULL` — user-supplied description

The move is a pure refactor: no behavior change in `transform.R`.

#### `.coerce_to_factor()` — file-local in `factor.R`

All `fct_*` functions accept factor input. For non-factor input they call
this helper, which delegates to `make_factor(x, force = TRUE)` so that
character and unlabelled numeric vectors are accepted without requiring
the user to call `make_factor()` first.

```r
.coerce_to_factor <- function(x, arg = "x") {
  if (is.factor(x)) return(x)
  make_factor(x, force = TRUE)
}
```

Errors from `make_factor()` propagate unchanged (e.g.,
`surveytidy_error_make_factor_unsupported_type` for list input).

#### `.effective_label()` — file-local in `factor.R`

Shared label resolution used by all `fct_*` functions:

```r
.effective_label <- function(x, label, var_name) {
  if (!is.null(label)) label
  else attr(x, "label", exact = TRUE) %||% var_name
}
```

#### `.validate_fct_args()` — file-local in `factor.R`

Validates `.label` and `.description` for all `fct_*` functions. Raises
`surveytidy_error_fct_bad_arg` when either is not `character(1)` or
`NULL`.

```r
.validate_fct_args <- function(label, description) { ... }
```

### Implementation Strategy

Two approaches are viable:

**Option A — Wrap `forcats`:** Each surveytidy function calls the
corresponding `forcats::fct_*()` internally, then restores the `label`
attribute and sets `surveytidy_recode`. This adds `forcats` to `Imports`
but requires less implementation code and inherits forcats' test coverage.

**Option B — Implement directly:** Each function performs the factor
operation itself using base R. No new dependency; full control; same
pattern as `transform.R`.

> ⚠️ GAP: The implementation strategy (wrap forcats vs. implement
> directly) is undecided. This must be resolved before coding begins.
> Key questions: (1) Is `forcats` already a transitive dependency via
> tidyverse? (2) Is adding an explicit `forcats` `Imports` entry
> acceptable? Lean toward Option A if `forcats` is acceptable as a
> dependency; it reduces maintenance surface.

---

## III. `fct_relevel()`

### Signature

```r
fct_relevel(x, ..., after = NULL, .label = NULL, .description = NULL)
```

### Argument Table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | factor or coercible | — | Input vector. Non-factors are coerced via `.coerce_to_factor()`. |
| `...` | character | — | Level names to move. If unnamed, treated as a character vector of levels to place at position `after`. |
| `after` | integer(1) or NULL | `NULL` | Position to insert after. `NULL` means move to front (position 0). `Inf` or a value >= total levels moves to end. |
| `.label` | character(1) or NULL | `NULL` | Variable label override. Inherited from `attr(x, "label")` then column name. |
| `.description` | character(1) or NULL | `NULL` | Transformation description for `surveytidy_recode`. |

### Output Contract

| Property | Value |
|----------|-------|
| Return type | R factor |
| `levels()` | Reordered per `...` and `after`; all original levels present |
| `attr(result, "label")` | `.label` if supplied; else `attr(x, "label")`; else column name |
| `attr(result, "labels")` | `NULL` |
| `attr(result, "surveytidy_recode")` | `list(fn = "fct_relevel", var = <col>, description = .description)` |

### Behavior Rules

1. Levels listed in `...` that are not in `levels(x)` produce
   `surveytidy_warning_fct_relevel_unknown_levels`. They are silently
   ignored in the reordering (matching forcats behavior).
2. Duplicate level names in `...` are silently deduplicated.
3. `after = NULL` is equivalent to `after = 0` (move to front).
4. `after = Inf` or `after >= length(levels(x))` moves to end.
5. Non-factor input is coerced via `.coerce_to_factor()` before
   reordering.

### Error / Warning Table

| Class | Trigger | Severity |
|-------|---------|----------|
| `surveytidy_warning_fct_relevel_unknown_levels` | Level name(s) in `...` not found in `levels(x)` | Warning |
| `surveytidy_error_fct_bad_arg` | `.label` or `.description` not `character(1)` or `NULL` | Error |

---

## IV. `fct_recode()`

### Signature

```r
fct_recode(x, ..., .label = NULL, .description = NULL)
```

### Argument Table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | factor or coercible | — | Input vector. |
| `...` | named character pairs | — | `new_name = "old_name"` pairs. Use `NULL` as the new name to drop a level (matching values become `NA`). |
| `.label` | character(1) or NULL | `NULL` | Variable label override. |
| `.description` | character(1) or NULL | `NULL` | Transformation description. |

### Output Contract

| Property | Value |
|----------|-------|
| Return type | R factor |
| `levels()` | Original levels with specified ones renamed; `NULL`-mapped levels removed |
| `attr(result, "label")` | `.label` or inherited |
| `attr(result, "labels")` | `NULL` |
| `attr(result, "surveytidy_recode")` | `list(fn = "fct_recode", var = <col>, description = .description)` |

### Behavior Rules

1. Old names (RHS values in `...`) not in `levels(x)` → error
   `surveytidy_error_fct_recode_unknown_levels`. Unlike forcats (which
   warns), we error because a missing old name is almost certainly a
   typo.
2. A `new_name = NULL` mapping drops the level: values that match the
   old level are set to `NA` and the level is removed.
3. Renaming to an existing level (creating duplicates) → error
   `surveytidy_error_fct_recode_duplicate_levels`.
4. `...` must be fully named (no positional arguments after first) — the
   `new = "old"` convention requires names.

### Error / Warning Table

| Class | Trigger | Severity |
|-------|---------|----------|
| `surveytidy_error_fct_recode_unknown_levels` | Old level name(s) in `...` not found in `levels(x)` | Error |
| `surveytidy_error_fct_recode_duplicate_levels` | Renaming would produce duplicate level names | Error |
| `surveytidy_error_fct_bad_arg` | `.label` or `.description` not `character(1)` or `NULL` | Error |

---

## V. `fct_collapse()`

### Signature

```r
fct_collapse(x, ..., other_level = NULL, .label = NULL, .description = NULL)
```

### Argument Table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | factor or coercible | — | Input vector. |
| `...` | named character vectors | — | `new_level = c("old1", "old2")` pairs mapping old levels to a new consolidated level. |
| `other_level` | character(1) or NULL | `NULL` | If non-NULL, all levels not mentioned in `...` are collapsed into this level. |
| `.label` | character(1) or NULL | `NULL` | Variable label override. |
| `.description` | character(1) or NULL | `NULL` | Transformation description. |

### Output Contract

| Property | Value |
|----------|-------|
| Return type | R factor |
| `levels()` | Keys from `...`, plus `other_level` if specified, in order they appear in `...` |
| `attr(result, "label")` | `.label` or inherited |
| `attr(result, "labels")` | `NULL` |
| `attr(result, "surveytidy_recode")` | `list(fn = "fct_collapse", var = <col>, description = .description)` |

### Behavior Rules

1. Old level names in the RHS of `...` that are not in `levels(x)` →
   `surveytidy_warning_fct_collapse_unknown_levels` (warning, not error;
   matches forcats behavior for defensive use).
2. The same old level name appearing in multiple `...` groups → error
   `surveytidy_error_fct_collapse_overlap`.
3. `other_level` name conflicts with a key in `...` → error
   `surveytidy_error_fct_collapse_other_conflicts`.
4. If `other_level = NULL` and not all levels are covered by `...`, the
   uncovered levels are kept unchanged.
5. Level ordering in the output follows the order of `...` keys; uncovered
   levels come after in their original order; `other_level` comes last.

### Error / Warning Table

| Class | Trigger | Severity |
|-------|---------|----------|
| `surveytidy_warning_fct_collapse_unknown_levels` | Old level name(s) in `...` not in `levels(x)` | Warning |
| `surveytidy_error_fct_collapse_overlap` | Same old level appears in two or more output groups | Error |
| `surveytidy_error_fct_collapse_other_conflicts` | `other_level` name matches a key in `...` | Error |
| `surveytidy_error_fct_bad_arg` | `.label` or `.description` not `character(1)` or `NULL` | Error |

---

## VI. `fct_rev()`

### Signature

```r
fct_rev(x, .label = NULL, .description = NULL)
```

### Argument Table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | factor or coercible | — | Input vector. |
| `.label` | character(1) or NULL | `NULL` | Variable label override. |
| `.description` | character(1) or NULL | `NULL` | Transformation description. |

### Output Contract

| Property | Value |
|----------|-------|
| Return type | R factor |
| `levels()` | Original levels in reversed order |
| `attr(result, "label")` | `.label` or inherited |
| `attr(result, "labels")` | `NULL` |
| `attr(result, "surveytidy_recode")` | `list(fn = "fct_rev", var = <col>, description = .description)` |

### Behavior Rules

1. Single-level factors are reversed trivially (no-op on levels; no
   warning).
2. Non-factor input coerced via `.coerce_to_factor()`.

### Error / Warning Table

| Class | Trigger | Severity |
|-------|---------|----------|
| `surveytidy_error_fct_bad_arg` | `.label` or `.description` not `character(1)` or `NULL` | Error |

---

## VII. `fct_drop()`

### Signature

```r
fct_drop(x, only = NULL, .label = NULL, .description = NULL)
```

### Argument Table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | factor or coercible | — | Input vector. |
| `only` | character or NULL | `NULL` | If `NULL`, drops all unused levels. If a character vector, drops only those levels (even if they appear in data). |
| `.label` | character(1) or NULL | `NULL` | Variable label override. |
| `.description` | character(1) or NULL | `NULL` | Transformation description. |

### Output Contract

| Property | Value |
|----------|-------|
| Return type | R factor |
| `levels()` | Original levels minus the dropped ones |
| `attr(result, "label")` | `.label` or inherited |
| `attr(result, "labels")` | `NULL` |
| `attr(result, "surveytidy_recode")` | `list(fn = "fct_drop", var = <col>, description = .description)` |

### Behavior Rules

1. `only = NULL`: drops all levels with zero observed occurrences (base
   `droplevels()` behavior).
2. `only` names not in `levels(x)` → `surveytidy_warning_fct_drop_unknown_only`.
3. Dropping a level that has observed values sets those values to `NA`
   silently. This is intentional (matches forcats behavior); no warning
   is issued.
4. Dropping all levels (result has 0 levels) →
   `surveytidy_error_fct_drop_all_levels`.

### Error / Warning Table

| Class | Trigger | Severity |
|-------|---------|----------|
| `surveytidy_warning_fct_drop_unknown_only` | Level name(s) in `only` not found in `levels(x)` | Warning |
| `surveytidy_error_fct_drop_all_levels` | Dropping specified levels would leave 0 levels | Error |
| `surveytidy_error_fct_bad_arg` | `.label` or `.description` not `character(1)` or `NULL` | Error |

---

## VIII. `fct_na_value_to_level()`

### Signature

```r
fct_na_value_to_level(x, level = "(Missing)", .label = NULL, .description = NULL)
```

### Argument Table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | factor or coercible | — | Input vector. |
| `level` | character(1) | `"(Missing)"` | Name to assign to the new level that replaces `NA`. |
| `.label` | character(1) or NULL | `NULL` | Variable label override. |
| `.description` | character(1) or NULL | `NULL` | Transformation description. |

### Output Contract

| Property | Value |
|----------|-------|
| Return type | R factor |
| `levels()` | Original levels plus `level` appended at the end |
| `attr(result, "label")` | `.label` or inherited |
| `attr(result, "labels")` | `NULL` |
| `attr(result, "surveytidy_recode")` | `list(fn = "fct_na_value_to_level", var = <col>, description = .description)` |

### Behavior Rules

1. If `x` contains no `NA` values, the `level` is still added as a valid
   (empty) level. No warning. This matches forcats behavior.
2. `level` already exists in `levels(x)` → error
   `surveytidy_error_fct_na_value_to_level_level_exists`.
3. The new level is appended **last** in the level order.
4. `level` must be `character(1)` (non-NULL, non-NA, length 1) → error
   `surveytidy_error_fct_bad_arg` if violated.

### Error / Warning Table

| Class | Trigger | Severity |
|-------|---------|----------|
| `surveytidy_error_fct_na_value_to_level_level_exists` | `level` already exists in `levels(x)` | Error |
| `surveytidy_error_fct_bad_arg` | `.label` or `.description` not `character(1)` or `NULL`, or `level` not `character(1)` | Error |

---

## IX. `fct_reorder()`

### Signature

```r
fct_reorder(x, y, .f = median, .desc = FALSE, .na_rm = TRUE, .label = NULL, .description = NULL)
```

### Argument Table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | factor or coercible | — | Input factor. Levels are reordered by the summary of `y` within each level. |
| `y` | numeric vector | — | Numeric variable used to compute the summary. Must be the same length as `x`. |
| `.f` | function | `median` | Summary function applied to `y` within each level of `x`. Must return a length-1 numeric. |
| `.desc` | logical(1) | `FALSE` | If `TRUE`, order by descending summary value. |
| `.na_rm` | logical(1) | `TRUE` | Passed as `na.rm` to `.f` if `.f` accepts it. If `.f` does not accept `na.rm`, this argument is ignored. |
| `.label` | character(1) or NULL | `NULL` | Variable label override. |
| `.description` | character(1) or NULL | `NULL` | Transformation description. |

### Output Contract

| Property | Value |
|----------|-------|
| Return type | R factor |
| `levels()` | Original levels sorted by `.f(y[x == level])`, ascending unless `.desc = TRUE` |
| `attr(result, "label")` | `.label` or inherited |
| `attr(result, "labels")` | `NULL` |
| `attr(result, "surveytidy_recode")` | `list(fn = "fct_reorder", var = <col>, description = .description)` |

### Behavior Rules

1. `length(y) != length(x)` → error `surveytidy_error_fct_reorder_length_mismatch`.
2. `y` not numeric → error `surveytidy_error_fct_reorder_y_not_numeric`.
3. `.f` must return a single numeric value per level; if `.f` returns a
   non-numeric or length != 1 value for any level, raise
   `surveytidy_error_fct_reorder_f_bad_return`.
4. Levels where all `y` values are `NA` (and `.na_rm = TRUE`) produce
   `NA` summary → those levels sort last in ascending or first in
   descending order (ties broken by original level order).
5. `.f` is called with `na.rm = .na_rm` if `.f` formally accepts
   `na.rm`; otherwise called without it.

### Error / Warning Table

| Class | Trigger | Severity |
|-------|---------|----------|
| `surveytidy_error_fct_reorder_length_mismatch` | `length(y) != length(x)` | Error |
| `surveytidy_error_fct_reorder_y_not_numeric` | `y` is not numeric | Error |
| `surveytidy_error_fct_reorder_f_bad_return` | `.f` returns non-numeric or non-scalar for any level | Error |
| `surveytidy_error_fct_bad_arg` | `.label` or `.description` not `character(1)` or `NULL` | Error |

---

## X. `fct_infreq()` and `fct_inorder()`

### `fct_infreq()` Signature

```r
fct_infreq(x, w = NULL, ordered = NA, .label = NULL, .description = NULL)
```

### `fct_inorder()` Signature

```r
fct_inorder(x, ordered = NA, .label = NULL, .description = NULL)
```

### Argument Table — `fct_infreq()`

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | factor or coercible | — | Input vector. |
| `w` | numeric or NULL | `NULL` | Optional weight vector (same length as `x`). If supplied, frequency is the sum of weights per level. |
| `ordered` | logical(1) or NA | `NA` | If `TRUE`/`FALSE`, set the ordered attribute. If `NA`, preserve existing. |
| `.label` | character(1) or NULL | `NULL` | Variable label override. |
| `.description` | character(1) or NULL | `NULL` | Transformation description. |

### Argument Table — `fct_inorder()`

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | factor or coercible | — | Input vector. |
| `ordered` | logical(1) or NA | `NA` | If `TRUE`/`FALSE`, set the ordered attribute. If `NA`, preserve existing. |
| `.label` | character(1) or NULL | `NULL` | Variable label override. |
| `.description` | character(1) or NULL | `NULL` | Transformation description. |

### Output Contract

| Property | `fct_infreq()` | `fct_inorder()` |
|----------|---------------|-----------------|
| Return type | R factor | R factor |
| `levels()` | Ordered most-to-least frequent | Ordered by first appearance in `x` |
| `attr(result, "label")` | `.label` or inherited | `.label` or inherited |
| `attr(result, "labels")` | `NULL` | `NULL` |
| `attr(result, "surveytidy_recode")` | `fn = "fct_infreq"` | `fn = "fct_inorder"` |

### Behavior Rules

1. **`fct_infreq()`**: Ties in frequency are broken by original level order.
2. **`fct_infreq()` with `w`**: `length(w) != length(x)` → error
   `surveytidy_error_fct_infreq_weight_length_mismatch`.
3. **`fct_infreq()` with `w`**: Negative weight values → error
   `surveytidy_error_fct_infreq_negative_weights`.
4. **`fct_inorder()`**: First appearance is determined by the first non-NA
   value of each level in `x` (ignoring `NA` values of `x`).
5. **Both**: `ordered = NA` preserves `is.ordered(x)`; `ordered = TRUE`
   sets the ordered flag; `ordered = FALSE` clears it.
6. **Both**: `w = NULL` in `fct_infreq()` counts each occurrence equally.

### Error / Warning Table

| Class | Trigger | Severity |
|-------|---------|----------|
| `surveytidy_error_fct_infreq_weight_length_mismatch` | `length(w) != length(x)` | Error |
| `surveytidy_error_fct_infreq_negative_weights` | Any value in `w` is negative | Error |
| `surveytidy_error_fct_bad_arg` | `.label` or `.description` not `character(1)` or `NULL` | Error |

---

## XI. `fct_lump_n()` and `fct_lump_prop()`

### `fct_lump_n()` Signature

```r
fct_lump_n(
  x,
  n,
  w = NULL,
  other_level = "Other",
  ties.method = c("min", "average", "first", "last", "random", "max"),
  .label = NULL,
  .description = NULL
)
```

### `fct_lump_prop()` Signature

```r
fct_lump_prop(x, prop, w = NULL, other_level = "Other", .label = NULL, .description = NULL)
```

### Argument Table — `fct_lump_n()`

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | factor or coercible | — | Input vector. |
| `n` | integer(1) | — | If positive, keep the top `n` levels by frequency; lump the rest. If negative, keep all but the top `|n|` levels. |
| `w` | numeric or NULL | `NULL` | Optional weight vector. |
| `other_level` | character(1) | `"Other"` | Name for the lumped level. |
| `ties.method` | character(1) | `"min"` | How to break ties in frequency ranking. Passed to `rank()`. |
| `.label` | character(1) or NULL | `NULL` | Variable label override. |
| `.description` | character(1) or NULL | `NULL` | Transformation description. |

### Argument Table — `fct_lump_prop()`

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | factor or coercible | — | Input vector. |
| `prop` | numeric(1) | — | Proportion threshold. If positive, keep levels with proportion >= `prop`. If negative, keep levels with proportion <= `|prop|`. |
| `w` | numeric or NULL | `NULL` | Optional weight vector. Proportions are computed over weighted counts. |
| `other_level` | character(1) | `"Other"` | Name for the lumped level. |
| `.label` | character(1) or NULL | `NULL` | Variable label override. |
| `.description` | character(1) or NULL | `NULL` | Transformation description. |

### Output Contract

| Property | `fct_lump_n()` | `fct_lump_prop()` |
|----------|---------------|------------------|
| Return type | R factor | R factor |
| `levels()` | Top-n levels + `other_level` | Above-threshold levels + `other_level` |
| `attr(result, "label")` | `.label` or inherited | `.label` or inherited |
| `attr(result, "labels")` | `NULL` | `NULL` |
| `attr(result, "surveytidy_recode")` | `fn = "fct_lump_n"` | `fn = "fct_lump_prop"` |

### Behavior Rules

1. **All lumped**: If all levels would be lumped (no level survives), the
   result is a factor with a single `other_level` level. Issue
   `surveytidy_warning_fct_lump_all_other`.
2. **No lumping needed**: If no levels would be lumped, return `x`
   unchanged (with `label` and `surveytidy_recode` attributes set). No
   warning.
3. **`other_level` already exists in `levels(x)`**: The existing level is
   merged with the lumped levels → `surveytidy_warning_fct_lump_other_exists`.
4. **`fct_lump_n()` — `n` is not an integer(1)**: error
   `surveytidy_error_fct_lump_bad_n`.
5. **`fct_lump_prop()` — `|prop| >= 1`**: error
   `surveytidy_error_fct_lump_bad_prop`.
6. **`w` negative values**: error `surveytidy_error_fct_lump_negative_weights`.
7. **`w` length mismatch**: error `surveytidy_error_fct_lump_weight_length_mismatch`.
8. **Level order in output**: Surviving levels retain their original order;
   `other_level` is appended last.

### Error / Warning Table

| Class | Trigger | Severity |
|-------|---------|----------|
| `surveytidy_warning_fct_lump_all_other` | All levels would be lumped | Warning |
| `surveytidy_warning_fct_lump_other_exists` | `other_level` name already exists in `levels(x)` | Warning |
| `surveytidy_error_fct_lump_bad_n` | `n` is not a non-zero integer(1) | Error |
| `surveytidy_error_fct_lump_bad_prop` | `|prop| >= 1` or `prop` is not numeric(1) | Error |
| `surveytidy_error_fct_lump_negative_weights` | Any value in `w` is negative | Error |
| `surveytidy_error_fct_lump_weight_length_mismatch` | `length(w) != length(x)` | Error |
| `surveytidy_error_fct_bad_arg` | `.label` or `.description` not `character(1)` or `NULL` | Error |

---

## XII. Testing Plan

### File: `tests/testthat/test-factor.R`

#### Sections

```
# 1. Shared helpers (.coerce_to_factor, .effective_label, .validate_fct_args)
# 2. fct_relevel() — level reordering + unknown-levels warning
# 3. fct_recode() — level renaming + NULL-drop + duplicate error + unknown error
# 4. fct_collapse() — grouping + other_level + overlap error + unknown warning
# 5. fct_rev() — level reversal + single-level no-op
# 6. fct_drop() — unused levels + only= arg + all-levels error
# 7. fct_na_value_to_level() — NA → level + no-NA case + level-exists error
# 8. fct_reorder() — level reorder by summary + .desc + length mismatch error
# 9. fct_infreq() + fct_inorder() — frequency/appearance ordering + w= + ordered=
# 10. fct_lump_n() + fct_lump_prop() — lumping + edge cases (all-other, no-lump)
# 11. surveytidy_recode attribute protocol — all fns set correct attrs
# 12. mutate() integration — attrs recorded in @metadata@transformations
# 13. label inheritance — attr(x, "label") preserved; .label overrides
# 14. Non-factor input coercion — character, unlabelled numeric via .coerce_to_factor
```

#### `test_invariants()` usage

Functions in this file are **not** dplyr verbs. However, the
`mutate()` integration tests (#12) create survey objects and must call
`test_invariants(result)` after any `mutate()` call.

#### Key test patterns

**Attribute preservation:**
```r
test_that("fct_relevel() preserves attr(x, 'label')", {
  x <- factor(c("A", "B", "C"))
  attr(x, "label") <- "Category"
  result <- fct_relevel(x, "C")
  expect_identical(attr(result, "label"), "Category")
})
```

**`surveytidy_recode` attribute:**
```r
test_that("fct_rev() sets surveytidy_recode attr", {
  x <- factor(c("A", "B"))
  result <- fct_rev(x)
  recode <- attr(result, "surveytidy_recode")
  expect_identical(recode$fn, "fct_rev")
})
```

**`mutate()` integration test (cross-design loop):**
```r
test_that("fct_relevel() inside mutate() updates @metadata@transformations", {
  designs <- make_all_designs(seed = 42)
  for (d in designs) {
    result <- dplyr::mutate(d, group = fct_relevel(group, "B"))
    test_invariants(result)
    tm <- result@metadata@transformations[["group"]]
    expect_identical(tm$fn, "fct_relevel")
  }
})
```

**Error class test (dual pattern):**
```r
test_that("fct_recode() errors on unknown old level name", {
  x <- factor(c("A", "B"))
  expect_error(
    fct_recode(x, C = "Z"),
    class = "surveytidy_error_fct_recode_unknown_levels"
  )
  expect_snapshot(error = TRUE, fct_recode(x, C = "Z"))
})
```

---

## XIII. Quality Gates

"Done" means all of the following pass:

- [ ] `devtools::test()` passes: 0 failures, 0 warnings, 0 skips
- [ ] Line coverage on `R/factor.R` ≥ 98%
- [ ] `devtools::check()` passes: 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] Every error class in section XIII is listed in `plans/error-messages.md`
- [ ] Every error class has both `expect_error(class =)` and `expect_snapshot(error = TRUE)` tests
- [ ] `.set_recode_attrs()` is moved to `R/utils.R` with no behavior change;
  `R/transform.R` continues to pass its full test suite
- [ ] All `@examples` blocks run without error under `R CMD check`
  (each example starts with `library(dplyr)`)
- [ ] `air format R/factor.R` produces no diff

---

## XIV. Integration

### surveycore

No surveycore API changes required. These functions work on plain R
vectors and do not interact with survey design internals.

### `mutate.survey_base()` — existing protocol

Integration works through the existing `surveytidy_recode` attribute
mechanism in `mutate.survey_base()` (Steps 5a, 5b, 8 in `R/mutate.R`):

1. `mutate()` calls the `fct_*` function, which sets `surveytidy_recode`
   on the result vector.
2. `mutate()` reads `attr(new_data[[col]], "surveytidy_recode")` after
   the mutation.
3. The transformation is recorded in
   `@metadata@transformations[[col]]`.

No changes to `mutate.survey_base()` are needed.

### `transform.R` — refactor only

`.set_recode_attrs()` moves from `R/transform.R` to `R/utils.R`. The
function signature and behavior do not change. `transform.R` calls
`.set_recode_attrs()` exactly as before; the only change is the location
of the definition.

### `plans/error-messages.md`

The following new classes must be registered before any source code is
written:

**Errors:**
- `surveytidy_error_fct_bad_arg`
- `surveytidy_error_fct_recode_unknown_levels`
- `surveytidy_error_fct_recode_duplicate_levels`
- `surveytidy_error_fct_collapse_overlap`
- `surveytidy_error_fct_collapse_other_conflicts`
- `surveytidy_error_fct_drop_all_levels`
- `surveytidy_error_fct_na_value_to_level_level_exists`
- `surveytidy_error_fct_reorder_length_mismatch`
- `surveytidy_error_fct_reorder_y_not_numeric`
- `surveytidy_error_fct_reorder_f_bad_return`
- `surveytidy_error_fct_infreq_weight_length_mismatch`
- `surveytidy_error_fct_infreq_negative_weights`
- `surveytidy_error_fct_lump_bad_n`
- `surveytidy_error_fct_lump_bad_prop`
- `surveytidy_error_fct_lump_negative_weights`
- `surveytidy_error_fct_lump_weight_length_mismatch`

**Warnings:**
- `surveytidy_warning_fct_relevel_unknown_levels`
- `surveytidy_warning_fct_collapse_unknown_levels`
- `surveytidy_warning_fct_drop_unknown_only`
- `surveytidy_warning_fct_lump_all_other`
- `surveytidy_warning_fct_lump_other_exists`
