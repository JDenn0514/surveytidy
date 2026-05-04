# surveytidy Spec: `row_means()` and `row_sums()`

**Version:** 0.3 (implementation-ready)
**Date:** 2026-04-15
**Status:** All GAPs resolved, all spec-review issues closed — ready for `/implementation-workflow`

---

## Document Purpose

This document is the authoritative specification for `row_means()` and
`row_sums()`, two row-aggregate transformation functions for surveytidy. They
follow the same `surveytidy_recode` attribute protocol used by `make_factor()`,
`make_rev()`, and the six recode functions — integrating with
`mutate.survey_base()` to record transformations in `@metadata`.

Both functions are **not** dplyr verbs. They are plain R functions designed to
be called inside `mutate()`. They use `dplyr::pick()` to resolve tidyselect
column selections and `rowMeans()`/`rowSums()` for computation.

All decisions in this document supersede any prior informal discussion.
Implementation must not begin until Stage 2 (methodology review) and Stage 3
(spec review) are complete and all GAPs are resolved.

---

## I. Scope

### What this spec delivers

| Item | Description |
|------|-------------|
| `row_means()` | Row-wise column mean across tidyselect-selected columns; records transformation in `@metadata` |
| `row_sums()` | Row-wise column sum across tidyselect-selected columns; records transformation in `@metadata` |

### What this spec does NOT deliver

- Any row operation on non-numeric columns
- Design-variable-aware or weighted row operations — these are plain arithmetic,
  not survey estimators
- Dplyr verbs (no `filter`, `select`, or `arrange` analogue)
- Any estimation function (no `svymean`, no survey inference)
- `row_min()`, `row_max()`, `row_sd()`, or other row statistics (future work)

### Design support

`row_means()` and `row_sums()` are called inside `mutate()`, which already
handles all three design types (`survey_taylor`, `survey_replicate`,
`survey_twophase`). No per-design branching is needed in these functions.

---

## II. Architecture

### New file

```
R/rowstats.R
```

Contains both `row_means()` and `row_sums()`. The two functions are similar
enough to share a file but different enough in output semantics (mean vs. sum,
NaN vs. 0 for all-NA) to remain separate functions.

**Tests:**
```
tests/testthat/test-rowstats.R
```

### Integration with `mutate.survey_base()`

These functions use the existing `surveytidy_recode` attribute protocol:

1. The function sets `attr(result, "label")` for the variable label.
2. The function sets `attr(result, "surveytidy_recode")` with `fn`, `var`
   (character vector of source column names), and `description`.
3. `mutate.survey_base()` Step 5a captures the `surveytidy_recode` attr before
   stripping.
4. `mutate.survey_base()` Step 8 records the transformation in
   `@metadata@transformations[[col]]`.

No changes to `mutate.survey_base()` are required. The existing code at Step 8
already handles a character vector for `source_cols`:

```r
source_cols <- if (!is.null(recode_var)) {
  recode_var   # used as-is — already a character vector for row_means/row_sums
} else {
  setdiff(all.vars(rlang::quo_squash(q)), col)
}
```

### Move `.validate_transform_args()` to `R/utils.R`

`.validate_transform_args()` is currently defined in `R/transform.R` with the
comment "used only in transform.R". With `R/rowstats.R` adding a second call
site, it must move to `R/utils.R` per the 2+ source files rule in
`code-style.md`.

This is a pure code move — no behavioral change, no new tests needed. Existing
`transform.R` tests continue to pass unchanged.

`na.rm` validation uses an inline `cli_abort()` call in each function before
`.validate_transform_args()` is called for `.label` and `.description`. This
matches the pattern used by `make_rev()` and `make_flip()` for their unique
arguments.

### Shared internal helper: `.set_recode_attrs()`

**GAP-1 resolved:** `.set_recode_attrs()` moves to `R/utils.R`. It has 8
existing call sites in `transform.R` and gains 2 new call sites in
`rowstats.R` (3 source files total), which satisfies the 2+ source files rule
in `code-style.md`. This is a pure code move — no behavioral change, and
`transform.R` tests continue to pass unchanged.

---

## III. `row_means()`

### Signature

```r
row_means(.cols, na.rm = FALSE, .label = NULL, .description = NULL)
```

### Argument table

Argument order follows `code-style.md`: required tidy-select → optional
scalar → optional scalar.

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `.cols` | tidyselect expression | (required) | Columns to average across, evaluated via `dplyr::pick()`. Typical values: `c(a, b, c)`, `starts_with("y")`, `where(is.numeric)`. Must resolve to at least one numeric column. |
| `na.rm` | `logical(1)` | `FALSE` | If `TRUE`, excludes `NA` before computing the mean. `NA` or non-scalar logical errors. |
| `.label` | `character(1)` or `NULL` | `NULL` | Variable label stored in `@metadata@variable_labels[[col]]` after `mutate()`. If `NULL`, falls back to the output column name from `dplyr::cur_column()`; if that is also unavailable (called outside `mutate()`), the label is `NULL`. |
| `.description` | `character(1)` or `NULL` | `NULL` | Plain-language description of the transformation stored in `@metadata@transformations[[col]]$description` after `mutate()`. |

### Output contract

Returns a `double` vector of length `nrow` of the current data context.

Attributes set on the returned vector (before `mutate.survey_base()` strips them):

| Attribute | Value |
|-----------|-------|
| `"label"` | `effective_label` (character scalar or NULL) |
| `"surveytidy_recode"` | `list(fn = "row_means", var = source_cols, description = .description)` where `source_cols` is a character vector of resolved column names |

`@data` changes: the output column is added (or replaced) by `mutate()` as
normal. No direct `@data` writes in `row_means()` itself.

`@metadata` changes after `mutate()` processes the result:

| Slot | Change |
|------|--------|
| `@metadata@variable_labels[[col]]` | Set to `effective_label` (may be NULL, which clears any existing label). In practice, `effective_label` is never NULL when `mutate.survey_base()` processes the recode attr — calling outside `mutate()` errors first at `dplyr::pick()`. |
| `@metadata@transformations[[col]]` | Structured list: `fn = "row_means"`, `source_cols` (char vec), `expr` (deparsed quosure), `output_type = "vector"`, `description` |

`@variables`, `@groups`, the domain column, and `visible_vars` are all
unchanged by `row_means()` itself — `mutate()` manages these per its existing
logic.

### Behavior rules

1. **Column resolution**: `.cols` is forwarded to `dplyr::pick({{ .cols }})`.
   This evaluates the tidyselect expression in the current data context.
   `dplyr::pick()` is only callable within a dplyr data context (i.e., inside
   `mutate()` or another dplyr verb). If called outside a dplyr context,
   `dplyr::pick()` itself will throw a clear error — `row_means()` does not
   suppress or rethrow this.

   The resolution context is the full `@data` data frame, which includes **all**
   design variable columns (weights, strata codes, PSU IDs, FPC, replicate
   weights). `where(is.numeric)` will silently match numeric design variables
   without any visual cue in the code. Prefer targeted selectors such as
   `starts_with("y")` or an explicit `c(y1, y2, y3)` unless every numeric
   column in `@data` is intentionally included.

2. **`na.rm = FALSE` (default)**: Any `NA` value in a row produces `NA` for
   that row, matching base R `rowMeans()` behavior.

3. **`na.rm = TRUE`**: `NA` values are excluded per row before computing the
   mean. If **all** values in a row are `NA`, the result is `NaN` (matching
   base R `rowMeans()` — the mean of an empty set is NaN). No warning is issued
   for all-NA rows.

4. **Effective label**: `effective_label <- .label %||% tryCatch(dplyr::cur_column(), error = function(e) NULL)`.
   The fallback captures the output column name when called inside `mutate(d, score = row_means(...))`.

5. **Source columns in `surveytidy_recode`**: `source_cols` is always the character
   vector of resolved column names from `names(dplyr::pick({{ .cols }}))`. This
   feeds into `@metadata@transformations[[col]]$source_cols`. Column names are
   returned in data-frame column order (i.e., the order they appear in `@data`),
   regardless of the order specified in the selector. For example,
   `row_means(c(y3, y1, y2))` produces `source_cols = c("y1", "y2", "y3")`
   if that is the column order in `@data`.

6. **Non-numeric columns**: **GAP-2 resolved — pre-validate.** After
   `dplyr::pick()`, `row_means()` checks that every selected column is numeric
   using `vapply(df, is.numeric, logical(1))`. If any column is not numeric,
   it throws `surveytidy_error_row_means_non_numeric`, naming the offending
   columns. The base R `rowMeans()` error does **not** propagate.

7. **Zero columns selected**: **GAP-3 resolved — error.** After `dplyr::pick()`,
   if the resulting data frame has 0 columns (`ncol(df) == 0`), `row_means()`
   throws `surveytidy_error_row_means_zero_cols` before calling `rowMeans()`.
   This prevents the confusing base R NaN-with-warning output.

8. **Design variable check**: After `mutate.survey_base()` captures the
   `surveytidy_recode` attribute at Step 5a, it intersects `source_cols`
   (i.e., `recode_attr$var`) with the flat vector of design variable column
   names obtained from `.survey_design_var_names(.data)` (the existing wrapper
   in `R/utils.R`). If any overlap is found and
   `recode_attr$fn %in% c("row_means", "row_sums")`,
   `mutate.survey_base()` emits `surveytidy_warning_rowstats_includes_design_var`
   listing the offending columns. The computation and metadata recording then
   proceed — the warning does not halt the function.

   This check lives in `mutate.survey_base()` rather than in `row_means()` itself
   because `row_means()` has no access to the survey design object's variable
   registry — only `mutate.survey_base()` holds `x`.

### Error table

| Class | Trigger | Message template |
|-------|---------|-----------------|
| `surveytidy_error_rowstats_bad_arg` | `na.rm` is not a single non-NA `logical(1)` | `"x"`: "`na.rm` must be a single non-NA logical value." / `"i"`: "Got class `X` of length `N`." |
| `surveytidy_error_rowstats_bad_arg` | `.label` not `character(1)` or `NULL` | `"x"`: "`.label` must be a single character string or NULL." / `"i"`: "Got class `X` of length `N`." |
| `surveytidy_error_rowstats_bad_arg` | `.description` not `character(1)` or `NULL` | `"x"`: "`.description` must be a single character string or NULL." / `"i"`: "Got class `X` of length `N`." |
| `surveytidy_error_row_means_non_numeric` | Any selected column is not numeric (checked after `dplyr::pick()`) | `"x"`: "{N} selected column{?s} {?is/are} not numeric: {.field col1}, {.field col2}." / `"i"`: "`row_means()` requires all columns to be numeric." |
| `surveytidy_error_row_means_zero_cols` | `dplyr::pick()` returns a 0-column data frame | `"x"`: "`.cols` matched 0 columns." / `"i"`: "`row_means()` requires at least one numeric column." |

### Warning table

| Class | Trigger | Message template |
|-------|---------|-----------------|
| `surveytidy_warning_rowstats_includes_design_var` | `source_cols` overlaps with design variable column names (checked by `mutate.survey_base()` at Step 8) | `"!"`: "`.cols` includes {N} design variable column{?s}: {.field col1}, {.field col2}." / `"i"`: "Row aggregation across design variables produces methodologically meaningless results." / `"i"`: "Use a targeted selector such as {.code starts_with(\"y\")} to restrict to substantive columns." |

---

## IV. `row_sums()`

### Signature

```r
row_sums(.cols, na.rm = FALSE, .label = NULL, .description = NULL)
```

### Argument table

Identical structure to `row_means()`.

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `.cols` | tidyselect expression | (required) | Columns to sum across, evaluated via `dplyr::pick()`. |
| `na.rm` | `logical(1)` | `FALSE` | If `TRUE`, excludes `NA` before summing. |
| `.label` | `character(1)` or `NULL` | `NULL` | Variable label stored in `@metadata@variable_labels[[col]]` after `mutate()`. |
| `.description` | `character(1)` or `NULL` | `NULL` | Transformation description stored in `@metadata@transformations[[col]]$description`. |

### Output contract

Returns a `double` vector of length `nrow` of the current data context. Same
attribute protocol as `row_means()`, with `fn = "row_sums"` in the
`surveytidy_recode` list.

`@metadata` changes after `mutate()`:

| Slot | Change |
|------|--------|
| `@metadata@variable_labels[[col]]` | Set to `effective_label` |
| `@metadata@transformations[[col]]` | `fn = "row_sums"`, `source_cols`, `expr`, `output_type = "vector"`, `description` |

### Behavior rules

Rules 1, 2, 4, 5, 6, 8 from `row_means()` apply identically, substituting
`rowSums` for `rowMeans`. In Rule 8, `recode_attr$fn == "row_sums"` is the
trigger condition checked by `mutate.survey_base()`.

**Rule 3 (all-NA row with `na.rm = TRUE`)**: Returns `0` for all-NA rows,
matching base R `rowSums()` behavior (sum of an empty set is 0). No warning is
issued for all-NA rows.

**Rule 7 (zero columns)**: **GAP-5 resolved — also error.** After
`dplyr::pick()`, if `ncol(df) == 0`, `row_sums()` throws
`surveytidy_error_row_sums_zero_cols`. This makes both functions consistent at
the zero-column boundary.

### Error table

| Class | Trigger | Message template |
|-------|---------|-----------------|
| `surveytidy_error_rowstats_bad_arg` | `na.rm` not `logical(1)` or `.label`/`.description` not `character(1)` or `NULL` | Same pattern as `row_means()`. |
| `surveytidy_error_row_sums_non_numeric` | Any selected column is not numeric (checked after `dplyr::pick()`) | `"x"`: "{N} selected column{?s} {?is/are} not numeric: {.field col1}, {.field col2}." / `"i"`: "`row_sums()` requires all columns to be numeric." |
| `surveytidy_error_row_sums_zero_cols` | `dplyr::pick()` returns a 0-column data frame | `"x"`: "`.cols` matched 0 columns." / `"i"`: "`row_sums()` requires at least one numeric column." |

### Warning table

| Class | Trigger | Message template |
|-------|---------|-----------------|
| `surveytidy_warning_rowstats_includes_design_var` | Same as `row_means()` — see §III Warning table. |

---

## V. Naming: `row_means` / `row_sums` vs. `rowMeans` / `rowSums`

The functions are named `row_means()` and `row_sums()` (snake_case) to match
tidyverse naming conventions and to clearly distinguish them from base R's
`rowMeans()`/`rowSums()` (camelCase). The names also parallel each other and
existing surveytidy naming (`make_factor`, `make_rev`, etc.).

These names do not conflict with any existing dplyr, tidyr, or surveytidy
exports.

---

## VI. Export Policy

Both `row_means()` and `row_sums()` are exported user-facing functions. They
get `@export` roxygen tags, full argument documentation, and runnable
`@examples` blocks per `r-package-conventions.md`.

Both belong to `@family transformation` (same family as `make_factor()`,
`make_rev()`, etc.).

---

## VII. Testing

### Test file

```
tests/testthat/test-rowstats.R
```

### Test sections (template)

```
# 1. row_means() — happy path: correct numeric result (all 3 design types)
# 2. row_means() — na.rm = FALSE: NA propagates when any value is NA
# 3. row_means() — na.rm = TRUE: partial NA gives mean of non-NA values
# 4. row_means() — na.rm = TRUE: all-NA row gives NaN
# 5. row_means() — .label stored in @metadata@variable_labels after mutate()
# 6. row_means() — .label = NULL falls back to column name
# 7. row_means() — .description stored in @metadata@transformations after mutate()
# 8. row_means() — source_cols in @metadata@transformations matches selected cols
# 9. row_means() — tidyselect helpers (starts_with, where(is.numeric))
# 10. row_means() — explicit column list c(y1, y2, y3)
# 11. row_means() — bad .label / .description / na.rm → surveytidy_error_rowstats_bad_arg
# 12. row_sums() — happy path: correct numeric result (all 3 design types)
# 13. row_sums() — na.rm = FALSE: NA propagates
# 14. row_sums() — na.rm = TRUE: partial NA gives sum of non-NA values
# 15. row_sums() — na.rm = TRUE: all-NA row gives 0 (not NaN)
# 16. row_sums() — metadata recording (.label, .description, source_cols)
# 17. row_sums() — bad args → surveytidy_error_rowstats_bad_arg
# 18. Both — domain column preserved through mutate() wrapping
# 19. Both — visible_vars updated correctly after mutate() wrapping
# 20. Both — single column selected (degenerate case)
# 21. row_means() — where(is.numeric) includes a design var → surveytidy_warning_rowstats_includes_design_var
# 22. row_sums() — explicit column list that includes a weight column → surveytidy_warning_rowstats_includes_design_var
# 23. Both — warning fires but @metadata@transformations still records all source_cols (including the design var column)
# 24. Both — called outside mutate() → dplyr::pick() error propagates (expect_error() without class; error is dplyr's)
# 25. row_means() — non-numeric column selected → surveytidy_error_row_means_non_numeric (dual pattern)
# 26. row_means() — 0 columns matched → surveytidy_error_row_means_zero_cols (dual pattern)
# 27. row_sums() — non-numeric column selected → surveytidy_error_row_sums_non_numeric (dual pattern)
# 28. row_sums() — 0 columns matched → surveytidy_error_row_sums_zero_cols (dual pattern)
```

Tests 11 and 17 must use the dual pattern: `expect_error(class = "surveytidy_error_rowstats_bad_arg")`
plus `expect_snapshot(error = TRUE, ...)` for each trigger case, per `testing-surveytidy.md`.

### Required `test_invariants()` calls

Every `test_that()` block that creates or transforms a survey object must call
`test_invariants(result)` as its **first** assertion. See `testing-surveytidy.md`.
In tests 1–23, `test_invariants()` is called on the result of
`mutate(d, col = row_means(...))` — the survey object — not on the raw
`row_means()` return value (a plain vector, which would fail the check).

### Numeric assertions

Use `expect_equal()` for floating-point results (not `expect_identical()`).
Verify against manual `rowMeans()`/`rowSums()` calls on the same data.

### Data source

Use `make_all_designs(seed = N)` for cross-design tests. Use inline data frames
for edge cases (all-NA rows, single column, etc.) per `testing-surveytidy.md`.

### Edge case table

| Edge case | Expected behavior |
|-----------|------------------|
| All values in all rows non-NA | Correct numeric result |
| Some rows have partial NA, `na.rm = FALSE` | `NA` for those rows |
| Some rows have partial NA, `na.rm = TRUE` | Mean/sum of non-NA values |
| All values in a row are NA, `na.rm = TRUE` | `NaN` (means) or `0` (sums) |
| Single column selected | Result equals that column's values |
| `.label = "My label"` | `@metadata@variable_labels[[col]] == "My label"` |
| `.description` set | `@metadata@transformations[[col]]$description == .description` |
| `starts_with()` selects columns | Source cols correctly recorded |
| `where(is.numeric)` selects columns | Source cols correctly recorded |
| `c(y1, y2)` explicit list | Source cols correctly recorded |
| `.cols` includes a design variable column | `surveytidy_warning_rowstats_includes_design_var` emitted; computation and metadata recording proceed normally |

---

## VIII. Quality Gates

All of the following must be true before the feature branch may be merged:

- [ ] `devtools::check()`: 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::test()`: 0 failures, 0 skips
- [ ] Coverage ≥ 98% on `R/rowstats.R`
- [ ] All GAPs (GAP-1 through GAP-5) resolved and logged in `plans/decisions-rowstats.md`
- [ ] `plans/error-messages.md` updated with: `surveytidy_warning_rowstats_includes_design_var`, `surveytidy_error_row_means_non_numeric`, `surveytidy_error_row_means_zero_cols`, `surveytidy_error_row_sums_non_numeric`, `surveytidy_error_row_sums_zero_cols`
- [ ] `.validate_transform_args()` moved to `R/utils.R` (and any other shared helpers)
- [ ] `R/rowstats.R` formatted with `air format R/rowstats.R`
- [ ] All `@examples` run without error under `R CMD check`
- [ ] Metadata round-trip verified: calling `row_means()`/`row_sums()` inside
  `mutate()` and then inspecting `@metadata@transformations` gives the expected
  structured list with `fn`, `source_cols`, `description`

---

## IX. Integration Contracts

### With `mutate.survey_base()` (one small addition required)

`mutate.survey_base()` already handles `surveytidy_recode` attrs in Steps 5a
and 8. One addition to `mutate.R` is required: at Step 8, after reading
`recode_attr$var` (the resolved `source_cols`), check whether `recode_attr$fn`
is `"row_means"` or `"row_sums"`. If so, intersect `source_cols` with
`.survey_design_var_names(.data)` (the existing wrapper in `R/utils.R`). If any overlap exists, emit
`surveytidy_warning_rowstats_includes_design_var` (§III Warning table) before
proceeding with metadata recording.

The existing contract remains: `recode_attr$var` must be a character vector of
source column names, which is satisfied.

### With `dplyr::pick()`

`dplyr::pick()` is available in dplyr ≥ 1.1.0. surveytidy already requires
`dplyr (>= 1.1.0)` in DESCRIPTION. No version bump needed.

`dplyr::pick()` uses `...`, so the forwarding pattern is:
```r
df <- dplyr::pick({{ .cols }})
```
The `{{ }}` (embrace) operator forwards the tidyselect expression in `.cols`
to `dplyr::pick()`'s `...`.

### With `R/utils.R`

`.validate_transform_args()` moves from `R/transform.R` to `R/utils.R`.
`.set_recode_attrs()` may also move depending on GAP-1 resolution. Both are
pure code moves — no behavioral change.

---

## X. GAPs Summary — All Resolved (Stage 4, 2026-04-15)

| # | Section | Decision |
|---|---------|---------|
| GAP-1 | II (Architecture) | `.set_recode_attrs()` moves to `R/utils.R` (2+ source files rule). Pure code move — no behavioral change. |
| GAP-2 | III, Rule 6 | Pre-validate numeric columns in `row_means()`. Throw `surveytidy_error_row_means_non_numeric` naming offending columns. |
| GAP-3 | III, Rule 7 | Error on zero columns for `row_means()`. Throw `surveytidy_error_row_means_zero_cols`. |
| GAP-4 | III, Error table | Four new error classes added: `surveytidy_error_row_means_non_numeric`, `surveytidy_error_row_means_zero_cols`, `surveytidy_error_row_sums_non_numeric`, `surveytidy_error_row_sums_zero_cols`. |
| GAP-5 | IV, Rule 7 | `row_sums()` also errors on zero columns for consistency. Throw `surveytidy_error_row_sums_zero_cols`. |
