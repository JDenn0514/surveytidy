---
Version: 0.4
Date: 2026-03-16
Status: Stage 4 resolved — ready for implementation
---

# Spec: Transformation Functions

## Feature branch: `feature/transformation`

---

## Document Purpose

This is the source of truth for the `transformation` feature. It governs the
design, contracts, error handling, and test plan for five vector-level
convenience functions — `make_factor()`, `make_dicho()`, `make_binary()`,
`make_rev()`, and `make_flip()` — that handle the most common survey variable
transformations: type conversion, scale collapsing, binary indicator creation,
scale reversal, and valence flipping.

These functions are **not dplyr verbs**. They operate on plain R vectors and
integrate with `mutate.survey_base()` via the existing `surveytidy_recode`
attribute protocol. No new `mutate()` machinery is required.

All implementation decisions not covered here defer to:
- `code-style.md` (style, error structure, argument order)
- `r-package-conventions.md` (roxygen2, NAMESPACE, `::` usage)
- `testing-standards.md` + `testing-surveytidy.md` (coverage, invariants)

---

## I. Scope

### Delivered

| Function | Purpose |
|----------|---------|
| `make_factor(x, ...)` | Convert labelled/numeric/character to R factor using value labels |
| `make_dicho(x, ...)` | Collapse a multi-level factor to 2 levels by stripping the first qualifier word |
| `make_binary(x, ...)` | Convert a dichotomous variable to numeric 0/1 |
| `make_rev(x, ...)` | Reverse the numeric values of a scale variable |
| `make_flip(x, label, ...)` | Flip the semantic valence of a variable (keep values, reverse label associations) |

### Not Delivered (Deferred)

| Item | Reason |
|------|--------|
| `make_dicho()` explicit grouping (`group1 =` / `group2 =`) | Deferred; add only if requested after release |
| `.exclude` marking rows out-of-domain in `@variables` | Deferred; requires recode-layer integration; set to `NA` instead |
| Factor output `.value_labels` passthrough on `make_dicho()` / `make_binary()` | Deferred until recode-functions layer ships |
| `simplify_response()` (general N-level collapse) | Deferred; requires explicit user-supplied groupings to be safe |

### Design Support Matrix

Not applicable. These are vector-level functions, not dplyr verbs. They
operate on plain R vectors and work identically inside `mutate()` for all
three design types (`survey_taylor`, `survey_replicate`, `survey_twophase`).

---

## II. Architecture

### File Organization

```
R/
├── transform.R          # All 5 functions + inline helpers (used only here)
tests/testthat/
├── test-transform.R     # All tests for this feature
plans/
├── spec-transform.md    # This file
├── error-messages.md    # Add new error/warning classes before coding
```

### Shared Internal Helpers

The following helpers are scoped to `R/transform.R`. They are defined before
their first call site, prefixed with `.`, and never exported.

| Helper | Signature | Purpose |
|--------|-----------|---------|
| `.strip_first_word(label)` | `(label)` → character(1) | Remove first word from a multi-word label string; return unchanged if single word |
| `.set_recode_attrs(result, label, labels, fn, var, description)` | → result | Set `attr(result, "label")`, `attr(result, "labels")`, and `attr(result, "surveytidy_recode")` on result |

Note: `attr(x, "labels", exact = TRUE)` and `attr(x, "label", exact = TRUE)`
are inlined directly at call sites — do NOT abstract them into helper
functions.

**`.strip_first_word()` behavior:**
- Multi-word label: remove first whitespace-delimited token using
  `sub("^\\S+\\s+", "", label)`, then capitalize the first character of the
  result.
- Single-word label: return unchanged (no whitespace → no stripping).
- Comparison is case-insensitive for the overall collapse logic; individual
  stripped stems are title-cased (first character uppercased).

**Variable name capture — inlined in every user-facing function:**

```r
# Must be called early in the function body, before x is evaluated/modified.
# enquo(x) captures the unevaluated promise; cur_column() handles across().
var_name  <- tryCatch(
  dplyr::cur_column(),
  error = function(e) rlang::as_label(rlang::enquo(x))
)
```

This is intentionally NOT abstracted into a helper: `rlang::enquo(x)` must be
called in the user-facing function's frame while `x` is still an unevaluated
promise. Abstracting breaks the scoping.

**`surveytidy_recode` attribute structure:**

```r
list(
  fn          = "make_factor",   # hardcoded string per function
  var         = var_name,        # column name; correct inside across() and direct calls
  description = .description     # user-supplied string or NULL
)
```

Set via `.set_recode_attrs()` at the end of every function, on every code path.

**Transformation record format:**

When `mutate.survey_base()` step 8 detects a `surveytidy_recode` attr on a
result column, it builds and stores:

```r
@metadata@transformations[[col]] <- list(
  fn          = attr(result, "surveytidy_recode")$fn,
  source_cols = attr(result, "surveytidy_recode")$var,
  expr        = deparse(rlang::quo_squash(quo)),
  output_type = if (is.factor(new_data[[col]])) "factor" else "vector",
  description = attr(result, "surveytidy_recode")$description
)
```

`fn` and `source_cols` come from the `surveytidy_recode` attr: `fn` is
hardcoded in the function body (immune to aliasing via `my_fn <- make_factor`),
and `var` captures the actual input column name via `cur_column()` — which is
correct inside `across()` where quosure `all.vars()` would return `.x`. `expr`
and `output_type` are derived by `mutate()` from the quosure and the result
respectively. `description` is the user-supplied string or `NULL`.

This format applies to all 5 transform functions. Each function's output
contract refers to it as "the transformation record."

---

## III. `make_factor()`

### Signature

```r
make_factor(x, ordered = FALSE, drop_levels = TRUE, force = FALSE,
            na.rm = FALSE, .label = NULL, .description = NULL)
```

### Argument Table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | vector | — | Input: `haven_labelled`, plain numeric with `"labels"` attr, R factor, or character. |
| `ordered` | `logical(1)` | `FALSE` | If `TRUE`, returns an ordered factor. |
| `drop_levels` | `logical(1)` | `TRUE` | If `TRUE`, remove levels for values not observed in `x`. |
| `force` | `logical(1)` | `FALSE` | If `TRUE`, coerce numeric `x` without labels to a factor via `as.factor()`, issuing `surveytidy_warning_make_factor_forced`. If `FALSE`, error instead. |
| `na.rm` | `logical(1)` | `FALSE` | If `TRUE`, values in `attr(x, "na_values")` and `attr(x, "na_range")` are converted to `NA` instead of factor levels. |
| `.label` | `character(1)` or `NULL` | `NULL` | Variable label override. If `NULL`, inherits from `attr(x, "label")`; if that is also `NULL`, falls back to `var_name`. |
| `.description` | `character(1)` or `NULL` | `NULL` | Transformation description stored in `surveytidy_recode`. |

Argument order follows `code-style.md`: `x` → optional scalar controls →
optional metadata args.

### Output Contract

Returns an R factor (ordered if `ordered = TRUE`).

| Attribute on result | Value |
|---------------------|-------|
| `levels(result)` | Value label strings for observed values; all label strings if `drop_levels = FALSE` |
| `attr(result, "label")` | `.label` if non-NULL; else `attr(x, "label")`; else `var_name` |
| `attr(result, "labels")` | `NULL` — factors encode values as levels |
| `attr(result, "surveytidy_recode")` | `list(fn, var, call, description)` — always set |

`@metadata` changes (via `mutate()` post-detection):
- `@metadata@variable_labels[[col]]` ← `attr(result, "label")`
- `@metadata@value_labels[[col]]` ← `NULL`
- `@metadata@transformations[[col]]` ← structured recode record

### Level Ordering

- **Numeric / haven_labelled**: levels ordered by numeric value (ascending) as
  defined in `attr(x, "labels")`.
- **Character**: alphabetical (base `factor()` default).
- **Factor pass-through**: levels preserved in existing order.

### Argument Validation

Before input dispatch:
- `.label` and `.description` validated by `.validate_label_args()`. Raises
  `surveytidy_error_make_factor_bad_arg` if either is non-NULL and not
  `character(1)`.
- `ordered`, `drop_levels`, `force`, and `na.rm` must each be `logical(1)`.
  Failure raises `surveytidy_error_make_factor_bad_arg`.

### Behavior Rules

1. **Input dispatch** (checked in this order):
   - If `is.factor(x)`: pass through. Apply `ordered`, `drop_levels`, `.label`,
     `.description`. No label-completeness check.
   - If `is.character(x)`: convert via `factor(x)` (alphabetical levels). `na.rm`
     ignored. No label-completeness check.
   - If `typeof(x) %in% c("double", "integer")`:
     - Read `labels_attr <- attr(x, "labels", exact = TRUE)`.
     - If `labels_attr` is `NULL` and `force = FALSE`: error
       `surveytidy_error_make_factor_no_labels`.
     - If `labels_attr` is `NULL` and `force = TRUE`: warn
       `surveytidy_warning_make_factor_forced`, coerce via `as.factor(x)`,
       call `.set_recode_attrs(result, ...)`, then return. (Skips the
       label-completeness check — `labels_attr` is `NULL`, so there are no
       labels to check.)
     - If `na.rm = TRUE`: apply `attr(x, "na_values")` and `attr(x, "na_range")`
       before completeness check.
     - Error if any observed non-NA value lacks a label entry:
       `surveytidy_error_make_factor_incomplete_labels`.
     - Build factor: values → labels, levels ordered by numeric value.
   - Otherwise: error `surveytidy_error_make_factor_unsupported_type`.

2. **`drop_levels`**: Applied after building initial levels for all input
   types. With `drop_levels = TRUE`, removes levels with no observed values
   in `x`. For numeric/haven_labelled input with `na.rm = FALSE`, special
   missing values (`na_values`/`na_range`) that have label entries count as
   observed — they produce factor levels and survive `drop_levels = TRUE`. For
   factor pass-through, removes existing empty levels when `drop_levels = TRUE`.

3. **`na.rm` application order**: `attr(x, "na_values")` and
   `attr(x, "na_range")` exclusions are applied before the
   label-completeness check when `na.rm = TRUE`. With `na.rm = FALSE`, these
   values remain in `x` as regular non-NA values; if they have label entries
   they participate in level building and produce factor levels. Special
   missing values without label entries do not trigger
   `surveytidy_error_make_factor_incomplete_labels`.

4. **Label completeness**: Plain R `NA` values (where `is.na(x)` is `TRUE`
   and the value is not a haven special missing) never require a label and
   never produce factor levels.

   **Edge case — all-plain-NA input**: If all values are plain R `NA` and
   `drop_levels = TRUE`, the result is a 0-level factor. No warning is
   issued; this is defined behavior. Downstream functions requiring ≥ 2
   levels (e.g., `make_dicho()`) will error at that layer.

### Error Table

| Class | Trigger | Message template |
|-------|---------|-----------------|
| `surveytidy_error_make_factor_bad_arg` | `.label`/`.description` not `character(1)`, or `ordered`/`drop_levels`/`force`/`na.rm` not `logical(1)` | `"x" = "{.arg {arg_name}} must be {expected_type}."` `"i" = "Got {.cls {class(val)}} of length {length(val)}."` |
| `surveytidy_error_make_factor_unsupported_type` | `x` is not numeric, haven_labelled, factor, or character | `"x" = "{.arg x} must be a labelled numeric, factor, or character vector."` `"i" = "Got class {.cls {class(x)}}."` |
| `surveytidy_error_make_factor_no_labels` | `x` is numeric, `attr(x, "labels")` is `NULL`, and `force = FALSE` | `"x" = "{.arg x} has no value labels."` `"i" = "Numeric input requires a {.code labels} attribute to determine factor levels."` `"v" = "Set {.arg force = TRUE} to coerce via {.fn as.factor}, or attach labels first."` |
| `surveytidy_error_make_factor_incomplete_labels` | One or more non-NA observed values lack a label entry | `"x" = "{.arg x} contains {n} value{?s} with no label: {.val {unlabelled_vals}}."` `"i" = "Every observed value must have a label entry."` `"v" = "Add the missing labels or use {.fn na_if} to convert those values to {.code NA} first."` |

### Warning Table

| Class | Trigger | Message template |
|-------|---------|-----------------|
| `surveytidy_warning_make_factor_forced` | `x` is numeric without labels and `force = TRUE` | `"!" = "{.arg x} has no value labels — coercing to factor via {.fn as.factor}."` `"i" = "Set {.arg force = FALSE} to error instead."` |

---

## IV. `make_dicho()`

### Signature

```r
make_dicho(x, flip_levels = FALSE, .exclude = NULL,
           .label = NULL, .description = NULL)
```

### Argument Table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | vector | — | Input: same types as `make_factor()`. |
| `flip_levels` | `logical(1)` | `FALSE` | If `TRUE`, reverse the order of the two output levels. |
| `.exclude` | `character` or `NULL` | `NULL` | Level name(s) to set to `NA` before collapsing. Intended for middle categories and "don't know" / "refused" responses. |
| `.label` | `character(1)` or `NULL` | `NULL` | Variable label override. Falls back to `attr(x, "label")` then `var_name`. |
| `.description` | `character(1)` or `NULL` | `NULL` | Transformation description. |

### Argument Validation

Before input normalization:
- `.label` and `.description` validated by `.validate_label_args()`. Raises
  `surveytidy_error_transform_bad_arg` if either is non-NULL and not
  `character(1)`.
- `flip_levels` must be `logical(1)`. Failure raises
  `surveytidy_error_transform_bad_arg`.

### Output Contract

Returns a 2-level R factor.

| Attribute on result | Value |
|---------------------|-------|
| `levels(result)` | 2 title-cased stem strings, possibly reversed by `flip_levels` |
| `attr(result, "label")` | `.label` if non-NULL; else `attr(x, "label")`; else `var_name` |
| `attr(result, "labels")` | `NULL` |
| `attr(result, "surveytidy_recode")` | `list(fn, var, call, description)` — always set |

`@metadata` changes (via `mutate()` post-detection): same as `make_factor()`.

### Behavior Rules

1. **Input normalization**: Call `make_factor(x)` internally unless `x` is
   already a factor. `.label` and `.description` are NOT passed to the internal
   `make_factor()` call; they are applied at the end.

2. **`.exclude` application** (before collapse): For each name in `.exclude`:
   - If the name matches a level of the factor, set those rows to `NA` and
     remove the level from the factor's level set.
   - If the name does NOT match any level, issue
     `surveytidy_warning_make_dicho_unknown_exclude`.

3. **Check minimum levels**: If fewer than 2 levels remain after `.exclude`,
   error `surveytidy_error_make_dicho_too_few_levels`.

4. **First-word collapse via `.strip_first_word()`**:
   - For each remaining level label, call `.strip_first_word()`.
   - `.strip_first_word()` removes the first whitespace-delimited word from
     multi-word labels; single-word labels are returned unchanged.
   - Capitalizes the first character of each stripped result.
   - Collect unique stems across all remaining levels (case-insensitive
     deduplication).
   - If the number of unique stems is not exactly 2: error
     `surveytidy_error_make_dicho_collapse_ambiguous`.
   - Map each original level to its stem. Group rows by stem.
   - Output levels are the 2 title-cased stems, in the order they first appear
     among the original levels (preserving original label order, not
     alphabetical).

5. **`flip_levels`**: Calls `factor(result, levels = rev(levels(result)))` on
   the final 2-level factor.

**Note on 2-level inputs**: If `x` already has exactly 2 levels (after
`.exclude`), `.strip_first_word()` still runs — single-word labels return
unchanged, so `c("Agree", "Disagree")` → 2 unique stems → correct output.
There is no short-circuit.

### Error Table

| Class | Trigger | Message template |
|-------|---------|-----------------|
| `surveytidy_error_make_dicho_too_few_levels` | Fewer than 2 levels remain after `.exclude` | `"x" = "Fewer than 2 levels remain after applying {.arg .exclude}."` `"i" = "{length(.exclude)} level{?s} excluded; {n_remaining} level{?s} remain."` `"v" = "Remove entries from {.arg .exclude} or check that {.arg x} has sufficient levels."` |
| `surveytidy_error_make_dicho_collapse_ambiguous` | First-word stripping does not yield exactly 2 unique stems | `"x" = "First-word stripping produced {n_stems} stem{?s}, not 2: {.val {stems}}."` `"i" = "Automatic collapse requires exactly 2 unique stems after removing first-word prefixes."` `"v" = "Use {.arg .exclude} to remove middle categories, or manually recode to 2 groups before calling {.fn make_dicho}."` |

### Warning Table

| Class | Trigger | Message template |
|-------|---------|-----------------|
| `surveytidy_warning_make_dicho_unknown_exclude` | A name in `.exclude` is not a level of `x` | `"!" = "{sum(unknown)} level{?s} in {.arg .exclude} not found in {.arg x}: {.val {unknown}}."` `"i" = "Spelling must match exactly. Current levels: {.val {levels(x_factor)}}."` |

---

## V. `make_binary()`

### Signature

```r
make_binary(x, flip_values = FALSE, .exclude = NULL,
            .label = NULL, .description = NULL)
```

### Argument Table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | vector | — | Input: same types as `make_factor()`. Must yield exactly 2 levels (after `.exclude`) or error. |
| `flip_values` | `logical(1)` | `FALSE` | If `TRUE`, map first level → 0 and second level → 1. Default maps first level → 1, second → 0. |
| `.exclude` | `character` or `NULL` | `NULL` | Passed directly to `make_dicho()`. Level names to set to `NA` before encoding. |
| `.label` | `character(1)` or `NULL` | `NULL` | Variable label override. Falls back to `attr(x, "label")` then `var_name`. |
| `.description` | `character(1)` or `NULL` | `NULL` | Transformation description. |

### Argument Validation

Before calling `make_dicho()`:
- `.label` and `.description` validated by `.validate_label_args()`. Raises
  `surveytidy_error_transform_bad_arg` if either is non-NULL and not
  `character(1)`.
- `flip_values` must be `logical(1)`. Failure raises
  `surveytidy_error_transform_bad_arg`.

### Output Contract

Returns an integer vector (0 or 1).

| Attribute on result | Value |
|---------------------|-------|
| Base values | `1L` for first level (or second if `flip_values = TRUE`); `0L` for other; `NA_integer_` for `NA` |
| `attr(result, "label")` | `.label` if non-NULL; else `attr(x, "label")`; else `var_name` |
| `attr(result, "labels")` | `c("{level1_name}" = 1L, "{level2_name}" = 0L)` — or flipped if `flip_values = TRUE` |
| `attr(result, "surveytidy_recode")` | `list(fn, var, call, description)` — always set |

`@metadata` changes (via `mutate()` post-detection):
- `@metadata@variable_labels[[col]]` ← `attr(result, "label")`
- `@metadata@value_labels[[col]]` ← from `attr(result, "labels")`
- `@metadata@transformations[[col]]` ← structured recode record

### Behavior Rules

1. **Implementation**: Calls `make_dicho(x, .exclude = .exclude)` internally.
   Any errors from `make_dicho()` propagate unchanged.

2. **Encoding**:
   - Default (`flip_values = FALSE`): `result <- 2L - as.integer(dicho)`
     (level 1 → 1L, level 2 → 0L).
   - `flip_values = TRUE`: `result <- as.integer(dicho) - 1L`
     (level 1 → 0L, level 2 → 1L).

3. **`attr(result, "labels")`**: Named integer vector derived from the level
   names of the `make_dicho()` output.

4. **NA propagation**: `NA` → `NA_integer_`.

### Error Table

All errors are raised inside `make_dicho()` and propagate without wrapping.
`make_binary()` itself raises no additional errors.

---

## VI. `make_rev()`

### Signature

```r
make_rev(x, .label = NULL, .description = NULL)
```

### Argument Table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | numeric vector | — | `typeof(x)` must be `"double"` or `"integer"`. |
| `.label` | `character(1)` or `NULL` | `NULL` | Variable label override. If `NULL`, inherits from `attr(x, "label")`; if that is also `NULL`, falls back to `var_name`. |
| `.description` | `character(1)` or `NULL` | `NULL` | Transformation description. |

### Argument Validation

Before the type check:
- `.label` and `.description` validated by `.validate_label_args()`. Raises
  `surveytidy_error_transform_bad_arg` if either is non-NULL and not
  `character(1)`.

### Output Contract

Returns a numeric vector (same `typeof()` as `x`) with reversed values.

| Attribute on result | Value |
|---------------------|-------|
| Values | `min(x, na.rm=TRUE) + max(x, na.rm=TRUE) - x` (NA → NA) |
| `attr(result, "label")` | `.label` if non-NULL; else `attr(x, "label")`; else `var_name` |
| `attr(result, "labels")` | Remapped: each entry's value becomes `m - old_value`; strings unchanged |
| `attr(result, "surveytidy_recode")` | `list(fn, var, call, description)` — always set |

`@metadata` changes (via `mutate()` post-detection):
- `@metadata@variable_labels[[col]]` ← `attr(result, "label")`
- `@metadata@value_labels[[col]]` ← remapped labels (or `NULL`)
- `@metadata@transformations[[col]]` ← structured recode record

### Behavior Rules

1. **Type check**: Error if `typeof(x)` is not `"double"` or `"integer"`
   (`surveytidy_error_make_rev_not_numeric`). Use `typeof()`, not `is.numeric()`.

2. **All-NA short-circuit**: If all values are `NA`, return all-NA vector with
   same `typeof(x)`. Preserve `attr(x, "labels")` unchanged. Issue
   `surveytidy_warning_make_rev_all_na`. Do NOT compute `min`/`max`.

3. **Reversal formula**: `result <- min(x, na.rm = TRUE) + max(x, na.rm = TRUE) - x`.
   Preserves scale range (a 2–5 scale reversed stays 2–5).

4. **Label remapping** (if `attr(x, "labels")` non-NULL and not all-NA):
   - Let `m <- min(x, na.rm = TRUE) + max(x, na.rm = TRUE)`.
   - New label value for each entry: `m - old_value`.
   - Label strings are unchanged — "Strongly Agree" stays tied to the value
     that previously meant "Strongly Agree".
   - Sort result label vector by new numeric value (ascending).

### Error Table

| Class | Trigger | Message template |
|-------|---------|-----------------|
| `surveytidy_error_make_rev_not_numeric` | `typeof(x)` is not `"double"` or `"integer"` | `"x" = "{.arg x} must be a numeric vector (double or integer)."` `"i" = "Got type {.val {typeof(x)}} with class {.cls {class(x)}}."` `"v" = "Use {.fn make_factor} for factor or character inputs."` |

### Warning Table

| Class | Trigger | Message template |
|-------|---------|-----------------|
| `surveytidy_warning_make_rev_all_na` | All values in `x` are `NA` | `"!" = "{.arg x} contains only {.code NA} values — reversal is a no-op."` |

---

## VII. `make_flip()`

### Signature

```r
make_flip(x, label, .description = NULL)
```

### Argument Table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | numeric vector | — | `typeof(x)` must be `"double"` or `"integer"`. |
| `label` | `character(1)` | — | **Required.** New variable label describing the flipped semantic meaning (e.g., `"I dislike the color blue"`). |
| `.description` | `character(1)` or `NULL` | `NULL` | Transformation description. |

**`label` is required with no default.** If missing, error
`surveytidy_error_make_flip_missing_label` with a message explaining that
flipping semantic valence always requires a new variable label.

### Argument Validation

Before the type check:
- `label` validated via Behavior Rule 2 (`surveytidy_error_make_flip_missing_label`).
- `.description` validated by `.validate_label_args()`. Raises
  `surveytidy_error_transform_bad_arg` if non-NULL and not `character(1)`.

### Conceptual distinction from `make_rev()`

| | `make_rev()` | `make_flip()` |
|---|---|---|
| Numeric values | Changed (`min + max - x`) | **Unchanged** |
| Value label strings | Unchanged (strings stay tied to concept) | **Reversed** (strings swap numeric positions) |
| Variable label | Inherited / overridable | **Required** (new label required) |
| Use case | Reverse scale direction for scoring | Flip question polarity for composite scoring |

Example with `x = c(1, 2, 3, 4)` and labels `c("Strongly agree"=1, "Agree"=2, "Disagree"=3, "Strongly disagree"=4)`:
- `make_rev(x)`: values become `c(4, 3, 2, 1)`; label "Strongly agree" is now at value 4
- `make_flip(x, "I disagree with...")`: values stay `c(1, 2, 3, 4)`; "Strongly disagree" is now at value 1

### Output Contract

Returns a numeric vector (same `typeof()` as `x`). Values are **unchanged**.

| Attribute on result | Value |
|---------------------|-------|
| Base values | Same as `x` — unchanged |
| `attr(result, "label")` | `label` argument (the required new label) |
| `attr(result, "labels")` | Reversed label associations: `setNames(unname(labels_attr), rev(names(labels_attr)))`; `NULL` if input had no labels attr |
| `attr(result, "surveytidy_recode")` | `list(fn, var, call, description)` — always set |

`@metadata` changes (via `mutate()` post-detection):
- `@metadata@variable_labels[[col]]` ← `label` (the new label)
- `@metadata@value_labels[[col]]` ← reversed labels (or `NULL`)
- `@metadata@transformations[[col]]` ← structured recode record

### Label Reversal Mechanics

Given `labels_attr = c("Strongly agree"=1, "Agree"=2, "Disagree"=3, "Strongly disagree"=4)`:

```r
# Keep values (1, 2, 3, 4); reverse which strings are attached to them
setNames(unname(labels_attr), rev(names(labels_attr)))
# → c("Strongly disagree"=1, "Disagree"=2, "Agree"=3, "Strongly agree"=4)
```

The result is naturally sorted by ascending value (since values are unchanged).
No explicit sort needed.

If `attr(x, "labels")` is `NULL`: set `attr(result, "labels") <- NULL`. Only
the variable label changes.

### Behavior Rules

1. **Type check**: Error if `typeof(x)` is not `"double"` or `"integer"`
   (`surveytidy_error_make_flip_not_numeric`). Use `typeof()`, not `is.numeric()`.

2. **`label` check**: Error if `label` is missing OR not `character(1)`
   (`surveytidy_error_make_flip_missing_label`).

3. **Value preservation**: Do NOT modify `x` values. Only manipulate attributes.

4. **No all-NA special case**: Since values do not change, an all-NA input
   produces an all-NA output with reversed label strings. No warning needed.

### Error Table

| Class | Trigger | Message template |
|-------|---------|-----------------|
| `surveytidy_error_make_flip_not_numeric` | `typeof(x)` is not `"double"` or `"integer"` | `"x" = "{.arg x} must be a numeric vector (double or integer)."` `"i" = "Got type {.val {typeof(x)}} with class {.cls {class(x)}}."` `"v" = "Use {.fn make_factor} for factor or character inputs."` |
| `surveytidy_error_make_flip_missing_label` | `label` is missing or not `character(1)` | `"x" = "{.arg label} is required."` `"i" = "{.fn make_flip} reverses the semantic meaning of a variable — a new variable label is needed to document the change."` `"v" = "Supply a string describing the flipped meaning, e.g. {.val \"I dislike the color blue\"}."` |

---

## VIII. Error and Warning Classes (New)

Add ALL of these to `plans/error-messages.md` before writing any source code.

### Errors

| Class | Source file | Trigger |
|-------|-------------|---------|
| `surveytidy_error_make_factor_bad_arg` | `R/transform.R` | `.label`/`.description` not `character(1)`, or logical args not `logical(1)` |
| `surveytidy_error_make_factor_unsupported_type` | `R/transform.R` | `x` is not numeric, haven_labelled, factor, or character |
| `surveytidy_error_make_factor_no_labels` | `R/transform.R` | `x` is numeric/haven_labelled, `attr(x, "labels")` is `NULL`, `force = FALSE` |
| `surveytidy_error_make_factor_incomplete_labels` | `R/transform.R` | One or more non-NA observed values lack a label entry |
| `surveytidy_error_make_dicho_too_few_levels` | `R/transform.R` | Fewer than 2 levels remain after `.exclude` |
| `surveytidy_error_make_dicho_collapse_ambiguous` | `R/transform.R` | First-word stripping does not yield exactly 2 unique stems |
| `surveytidy_error_make_rev_not_numeric` | `R/transform.R` | `typeof(x)` is not `"double"` or `"integer"` |
| `surveytidy_error_make_flip_not_numeric` | `R/transform.R` | `typeof(x)` is not `"double"` or `"integer"` |
| `surveytidy_error_make_flip_missing_label` | `R/transform.R` | `label` is missing or not `character(1)` |
| `surveytidy_error_transform_bad_arg` | `R/transform.R` | `.label`/`.description` not `character(1)`, or boolean flag args not `logical(1)`, in `make_dicho()`, `make_binary()`, `make_rev()`, or `make_flip()` |

### Warnings

| Class | Source file | Trigger |
|-------|-------------|---------|
| `surveytidy_warning_make_factor_forced` | `R/transform.R` | `force = TRUE` coerces numeric without labels via `as.factor()` |
| `surveytidy_warning_make_dicho_unknown_exclude` | `R/transform.R` | A name in `.exclude` not found in levels of `x` |
| `surveytidy_warning_make_rev_all_na` | `R/transform.R` | All values in `x` are `NA` |

---

## IX. Testing

### File

`tests/testthat/test-transform.R`

### Test Sections

```
# 1.  make_factor() — happy path: haven_labelled input
# 2.  make_factor() — happy path: plain numeric with labels attr
# 3.  make_factor() — happy path: factor pass-through (levels/order preserved)
# 3a. make_factor() — ordered = TRUE on factor pass-through returns ordered factor
# 3b. make_factor() — ordered = FALSE on an ordered factor removes ordered class
# 4.  make_factor() — happy path: character input (alphabetical levels)
# 5.  make_factor() — drop_levels = FALSE includes unobserved levels
# 6.  make_factor() — ordered = TRUE returns ordered factor
# 7.  make_factor() — na.rm = TRUE converts na_values to NA before levelling
# 8.  make_factor() — na.rm = TRUE with na_range
# 9.  make_factor() — .label overrides inherited variable label attr
# 10. make_factor() — .description sets surveytidy_recode attr
# 11. make_factor() — variable label inherited from attr(x, "label") when .label = NULL
# 11b.make_factor() — label falls back to var_name when no attr(x, "label") and .label = NULL
# 12. make_factor() — error: unsupported type (list, logical)
# 12b.make_factor() — error: bad arg type (ordered = "yes", drop_levels = 2L)
# 13. make_factor() — error: no labels (plain numeric without labels, force = FALSE)
# 14. make_factor() — error: incomplete labels (one value missing a label)
# 14b.make_factor() — force = TRUE: numeric without labels warns and coerces
# 14c.make_factor() — force = TRUE: warning class is surveytidy_warning_make_factor_forced
#
# 15. make_dicho()  — happy path: 4-level Likert auto-collapses to 2
# 16. make_dicho()  — already 2-level factor: stems are single words, pass through
# 17. make_dicho()  — .exclude sets middle level to NA
# 18. make_dicho()  — .exclude: excluded rows become NA in the 2-level factor result
# 19. make_dicho()  — flip_levels reverses level order
# 20. make_dicho()  — warning: unknown .exclude level
# 21. make_dicho()  — error: too few levels after .exclude
# 22. make_dicho()  — error: collapse ambiguous (4 distinct stems, no shared first word)
# 23. make_dicho()  — single-word labels pass through unchanged (no stripping)
# 24. make_dicho()  — non-standard first words stripped correctly ("Always agree" → "Agree")
# 25. make_dicho()  — level order preserved from original labels attr, not alphabetical
# 26. make_dicho()  — .label and .description set attrs on result
# 26b.make_dicho()  — label falls back to var_name when no attr(x, "label") and .label = NULL
# 26c.make_dicho()  — error: bad arg type (.label = 123)
# 26d.make_dicho()  — error: bad arg type (flip_levels = "yes")
#
# 27. make_binary() — basic 0/1 mapping: first level → 1, second → 0
# 28. make_binary() — flip_values reverses mapping: first level → 0
# 29. make_binary() — .exclude passed through to make_dicho
# 30. make_binary() — NA propagates correctly to NA_integer_
# 31. make_binary() — attr(result, "labels") reflects the 0/1 mapping
# 32. make_binary() — .label and .description set attrs on result
# 32b.make_binary() — label falls back to var_name when no attr(x, "label") and .label = NULL
# 32c.make_binary() — error: bad arg type (.label = 123)
# 32d.make_binary() — error: bad arg type (flip_values = "yes")
#
# 33. make_rev()    — reverses 1–4 scale correctly
# 34. make_rev()    — remaps value labels: strings stay tied to concept
# 35. make_rev()    — .label overrides inherited variable label
# 35b.make_rev()    — label falls back to var_name when no attr(x, "label") and .label = NULL
# 36. make_rev()    — all-NA input returns all-NA + warning
# 37. make_rev()    — error: non-numeric input (factor, character)
# 38. make_rev()    — NA values in input remain NA in output
# 39. make_rev()    — .description sets surveytidy_recode attr
# 39b.make_rev()    — error: bad arg type (.label = 123)
# 40. make_rev()    — sorted labels after reversal (ascending by new value)
# 41. make_rev()    — 2–5 scale: range preserved (not shifted to 1–4)
#
# 42. make_flip()   — values unchanged, label strings reversed
# 43. make_flip()   — variable label set to required label arg
# 44. make_flip()   — attr(result, "labels") has reversed string-to-value mapping
# 45. make_flip()   — input with no value labels: only variable label changes
# 46. make_flip()   — error: non-numeric input
# 47. make_flip()   — error: label missing
# 48. make_flip()   — error: label not character(1) (e.g. numeric, NULL)
# 49. make_flip()   — .description sets surveytidy_recode attr
# 49b.make_flip()   — error: bad arg type (.description = 123)
# 50. make_flip()   — all-NA input: values unchanged, labels reversed, no warning
#
# 51. surveytidy_recode — var field captures column name via cur_column() in across()
# 52. surveytidy_recode — var field falls back to symbol name in direct call
# 53. surveytidy_recode — fn field matches function name for all 5 functions
#
# 54. Integration   — make_factor() |> make_dicho() pipeline
# 55. Integration   — make_factor() |> make_rev() pipeline is an error (factor input)
# 56. Integration   — inside mutate(): @metadata updated correctly for all 5 fns
# 57. Integration   — inside mutate(): @data stripped of haven attrs after call
# 58. Integration   — inside mutate() on all 3 design types (taylor, replicate, twophase)
# 58b.Integration   — domain column preserved after make_factor() inside mutate() on a
#                     filtered design; fold into the loop for test 58
# 59. Integration   — across() workflow: multiple columns, correct var_name per column
```

### Integration Test Requirements

Tests 54–55 are vector-level pipelines that do not produce survey design
objects — `test_invariants()` is not applicable for those tests.

For tests 56–59 (which call `mutate()` on a survey design object),
`test_invariants(result)` **must be the first assertion** inside the loop
body.

### Error Testing Pattern

Every error test uses the dual pattern:
```r
expect_error(..., class = "surveytidy_error_*")
expect_snapshot(error = TRUE, ...)
```

Every warning test uses:
```r
expect_warning(result <- ..., class = "surveytidy_warning_*")
```

### Test Data

- Unit tests: inline vectors.
- Integration tests: `make_all_designs(seed = 42)` with three-design loop.
- Edge case data (all-NA, single-value, 2-row): inline.

---

## X. Quality Gates

All items must be verifiable before the PR is opened.

- [ ] `R CMD check`: 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::test()`: 0 failures, 0 skips
- [ ] Line coverage ≥ 98% on `R/transform.R` (covr)
- [ ] All 10 new error classes in `plans/error-messages.md` (9 function-specific + `surveytidy_error_transform_bad_arg`)
- [ ] All 3 new warning classes in `plans/error-messages.md`
- [ ] Every error class has a `class = "..."` test
- [ ] Every error class has a `expect_snapshot(error = TRUE, ...)` test
- [ ] Every warning class has a `class = "..."` test
- [ ] `devtools::document()` run; NAMESPACE and `man/` files committed
- [ ] All 5 functions have `@examples` that run during `R CMD check`; any example using `mutate()` must begin with `library(dplyr)` — dplyr is in Imports but not re-exported
- [ ] `@family transformation` on all 5 functions
- [ ] `air format R/transform.R` run before commit
- [ ] Integration tests pass on all 3 design types
- [ ] `attr(result, "surveytidy_recode")` set on every code path through every function
- [ ] `surveytidy_recode$var` correctly captures column name in `across()` workflow (test 59)
- [ ] `mutate.survey_base()` step 8 updated to read `surveytidy_recode$fn` and
      `surveytidy_recode$var` from the attr (see §XI and Transformation Record
      Format in §II)
- [ ] Phase 0.6 recode functions (`R/recode.R`) updated to set `fn` and `var` in
      their `surveytidy_recode` attrs using `list(fn, var, description)` (drop
      `call`); single-input functions (`na_if`, `replace_when`, `replace_values`,
      `recode_values`) set `var` via `cur_column()`; multi-input functions
      (`case_when`, `if_else`) set `var = NULL` and rely on mutate's quosure
      `all.vars()` fallback

---

## XI. Integration Contracts

### With `mutate.survey_base()`

Integration via the existing `surveytidy_recode` attribute protocol. **One
change to `mutate.R` is required**: step 8 must be updated to read
`surveytidy_recode$fn` and `surveytidy_recode$var` from the attr rather than
deriving them from the quosure (see Transformation Record Format in §II).
Columns whose result lacks a `surveytidy_recode` attr are unaffected.

The `surveytidy_recode` structure `list(fn, var, description)` is
backward-compatible: `mutate()` detects the attribute's presence, not its
internal keys.

### With `haven`

Transform functions do NOT create `haven_labelled` objects — they set raw
attrs on plain vectors. `haven` is not called directly.

### With `recode_values()` / Phase 0.6 recode functions

No runtime dependency. The Phase 0.6 recode functions will be updated
separately to use the same expanded `surveytidy_recode` structure for
consistency.

### With `dplyr::across()`

All 5 functions are designed for use inside `across()`:

```r
data |>
  mutate(
    across(c(q1:q5), make_dicho,   .names = "{col}_f2"),
    across(c(q1:q5), make_binary,  .names = "{col}_b"),
    across(c(q6:q8), make_rev,     .names = "{col}_rev")
  )
```

`dplyr::cur_column()` is used inside each function to capture the correct
column name for `surveytidy_recode$var` when called via `across()`.

---

## XII. Open Questions

1. **Qualifier list expansion (future)**: If users encounter first-word
   stripping producing wrong stems for multi-word qualifiers (e.g., "A little
   agree" → "Little agree" instead of "Agree"), a more sophisticated stripping
   approach can be added in a future release. For now, `.exclude` is the
   recommended workaround.

2. **`make_rev()` `.label` default**: Intentional that `.label = NULL` inherits
   the existing variable label (and falls back to `var_name` if none). Callers
   who want to mark a reversed item should supply a new `.label`.

3. **`make_flip()` with no value labels**: When `attr(x, "labels")` is `NULL`,
   only the variable label changes. Confirm this is the right behavior for
   unlabelled numeric vectors used with `make_flip()`.
