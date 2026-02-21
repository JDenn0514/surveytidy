# Phase 0.5 Formal Specification: surveytidy dplyr/tidyr Verbs

**Version:** 1.1
**Date:** 2026-02-21
**Status:** Approved — implementation in progress

This document is the authoritative specification for surveytidy Phase 0.5.
Every verb's signature, behavior contract, error/warning classes, and
implementation notes are defined here. Implementation must satisfy every
contract listed; the quality gates in Section 7 define "done."

**Changelog from v1.0:**
- Move `dplyr_reconstruct.survey_base` to `R/utils.R` (was `01-filter.R`)
- Defer `rename_with()` to a follow-up branch after `feature/rename`
- Fix `select()` `visible_vars` rule: show all user-selected cols including design vars
- Add grouped mutate: `@groups` respected when `.by = NULL`
- Clarify `relocate()`: `@data` order is irrelevant; only `visible_vars` matters
- Implement full partial `ungroup()` matching dplyr semantics
- Fix all `intersect(.protected_cols(), names(@data))` calls for pre-filter safety
- Add `surveytidy_warning_slice_sample_weight_by` for `slice_sample(weight_by =)`
- Delegate `group_by()` resolution to `dplyr::group_by() → group_vars()`
- Name-based design-var change detection in `mutate()`
- `mutate()` updates `visible_vars`: adds new cols, removes dropped cols
- Add `visible_vars` consistency to `test_invariants()` (all listed cols must be in `@data`)
- `test-pipeline.R` starts on `feature/select`, grows incrementally
- Add `@groups` propagation and `visible_vars` consistency to per-verb test checklist
- Clarify `@variables$domain` quosures are audit-only; domain column is authoritative
- Add three-part domain assertion for `select()` tests
- Add exact row-association assertion pattern for `arrange()` tests
- Add three-way combined test case for `rename()` (design var + `visible_vars` + `@data`)

---

## 1. Scope and Goals

### 1.1 What Phase 0.5 Delivers

A complete set of dplyr and tidyr verbs that work with `surveycore` survey
design objects (`survey_taylor`, `survey_replicate`, `survey_twophase`),
preserving the survey design and metadata automatically.

**Priority 1 — Core verbs (must ship):**
`filter`, `select`, `relocate`, `pull`, `glimpse`, `mutate`, `rename`,
`arrange`, `slice_*` (6 functions), `group_by`, `ungroup`

**Priority 2 — Utility verbs (must ship):**
`subset` (physical row removal with warning)

**Priority 3 — Tidyr verbs (stretch goals):**
`drop_na`

**Deferred to follow-up branches:**
`rename_with` — deferred after `feature/rename`; will use `.apply_rename_map()`
internal helper shared with `rename()`.

### 1.2 Out of Scope (Deferred)

| Deferred | Why |
|----------|-----|
| `rename_with()` | Deferred to follow-up branch; requires `.apply_rename_map()` refactor |
| `*_join()` verbs | Complex design-merge semantics; Phase 3 |
| `bind_rows()` / `bind_cols()` | Phase 3 |
| `pivot_longer()` / `pivot_wider()` | Phase 3 |
| `distinct()` | Phase 3 |
| `summarise()` | Produces estimates — Phase 1 scope |
| `group_by()` + `summarise()` pipeline | Phase 1 scope |
| Grouped estimation via `@groups` | Phase 1 reads `@groups`; Phase 0.5 sets it |
| `separate_*()` / `unite()` | Stretch beyond `drop_na` |

### 1.3 What "Complete" Means

All verbs are implemented, fully tested, and the package passes every quality
gate in Section 7. The `feature/group-by` branch ships the final integration
tests in `test-pipeline.R` (which starts on `feature/select`).

---

## 2. Shared Contracts

These rules apply to **every verb** without exception.

### 2.1 The Five Formal Invariants

Every verb must produce a result that passes `test_invariants()`:

1. `x@data` is a non-null `data.frame` with at least 1 row.
2. `x@data` has at least 1 column with no duplicate column names.
3. All `@variables` keys are always present (never delete a key; set to `NULL`
   if inapplicable). Exception: `"domain"` key is absent until first
   `filter()` call.
4. All column names referenced in `@variables` exist in `x@data`. Design
   variables cannot be removed.
5. `x@metadata` is a `survey_metadata` object (never `NULL`).

**Invariant 6 (new):** Every column name in `@variables$visible_vars` exists
in `x@data`. If `visible_vars` is non-`NULL`, `setdiff(visible_vars, names(x@data))`
must be empty.

`test_invariants()` in `helper-test-data.R` must be updated to check
Invariant 6.

### 2.2 Protected Columns

`.protected_cols(design)` (in `R/utils.R`) returns all column names that must
always remain in `@data`:

```r
.protected_cols <- function(design) {
  c(
    surveycore::.get_design_vars_flat(design),  # ids, weights, strata, fpc, etc.
    surveycore::SURVEYCORE_DOMAIN_COL           # "..surveycore_domain.."
  )
}
```

No verb may remove a protected column from `@data`. Every verb that performs
column selection must call `.protected_cols()` to compute this set.

**Important:** The domain column (`..surveycore_domain..`) may not yet exist
in `@data` if no `filter()` has been called. Always use:

```r
protected <- intersect(.protected_cols(.data), names(.data@data))
```

rather than `.protected_cols(.data)` directly.

### 2.3 `@groups` Propagation Rule

Every verb must pass `@groups` through unchanged **unless** it is `group_by()`
or `ungroup()`. Verbs that manipulate rows or columns must not touch `@groups`.

```r
# Correct pattern for verbs that don't manage grouping:
result@groups <- .data@groups
```

### 2.4 `@metadata` Propagation Rules

| Operation | `@metadata` contract |
|-----------|----------------------|
| Row changes (arrange, filter, subset) | Preserve as-is — metadata is per-variable, not per-row |
| Column removed by select() | Delete all metadata for that column name across all slots |
| Column renamed by rename() | Rename the key in all metadata slots |
| New column added by mutate() | No action required (no pre-existing metadata) |
| Design variable modified by mutate() | Warn; do not alter metadata |

Metadata slot operations use surveycore internals:
- Key rename: `surveycore:::.rename_metadata_keys(design, old, new)`
- Key delete: use `surveycore:::.delete_metadata_col(design, col)` if available.
  If surveycore does not export this helper, delete manually across all known
  slots: `@metadata@variable_labels[[col]] <- NULL` etc. File a surveycore
  issue to add the helper before implementing `select()`.

### 2.5 `visible_vars` Contract

`@variables$visible_vars` controls which columns `print()` shows.

| State | Meaning |
|-------|---------|
| `NULL` | Show all columns in `@data` (default after construction) |
| `character(0)` | **Not a valid state.** Normalise to `NULL`. |
| `character(n)` | Show only these columns in `print()` |

**Who sets `visible_vars`:**
- `select()` — sets it to the user's explicit selection (see Section 3.2)
- `mutate()` — adds newly created columns; removes columns dropped by `.keep`
- `rename()` — updates column names within `visible_vars`

**Who must NOT modify `visible_vars`:**
All other verbs (`filter`, `relocate`, `arrange`, `slice_*`, `group_by`,
`ungroup`, `subset`) must pass `visible_vars` through unchanged.

### 2.6 `@variables$domain` Quosures Are Audit-Only

`filter()` stores accumulated conditions in `@variables$domain` (a list of
quosures, e.g., `age > 65`). These quosures are for **audit and display
purposes only**.

The domain column in `@data[[SURVEYCORE_DOMAIN_COL]]` is the **authoritative
source of truth** for domain membership. Phase 1 code must always read from
`@data[[SURVEYCORE_DOMAIN_COL]]`, never by re-evaluating `@variables$domain`
quosures.

After row-reordering operations (`arrange`, `slice_*`), the domain column
moves correctly with the rows (it is just another `@data` column). No update
to `@variables$domain` is needed or correct.

After mutation operations (`mutate`), the domain column reflects the domain
state at the time `filter()` was called — not the current column values.
Re-evaluating quosures would give a different answer if the underlying data
was mutated.

### 2.7 Dispatch Pattern

All methods are plain R functions registered as S3 methods in `.onLoad()` via
`registerS3method("verb", "surveycore::survey_base", verb.survey_base, envir = asNamespace("pkg"))`.

Functions are named `verb.survey_base` with `#' @noRd` (not `@export`).
`subset.survey_base` is the exception: it uses `#' @export` and is registered
via `S3method(subset, survey_base)` in NAMESPACE (base R generic).

---

## 3. Verb Specifications

### 3.1 `filter()` ✅ Complete

**File:** `R/01-filter.R`

**Signature:** `filter.survey_base(.data, ..., .by = NULL, .preserve = FALSE)`

**Behavior:**
1. Reject non-`NULL` `.by` → `surveycore_error_filter_by_unsupported`.
2. Evaluate each condition in `...` against `@data` (for loop, not lapply —
   ensures error context shows `filter()` not `FUN()`).
3. Validate each result is `is.logical()` → `surveytidy_error_filter_non_logical`.
4. Map `NA` results to `FALSE` (outside domain).
5. AND all conditions together → `domain_mask`.
6. If domain column exists in `@data`, AND with existing mask (chained filters).
7. If `!any(domain_mask)` → warn `surveycore_warning_empty_domain`.
8. Write `domain_mask` to `@data[[SURVEYCORE_DOMAIN_COL]]`.
9. Accumulate conditions: `@variables$domain <- c(@variables$domain, conditions)`.
10. Return `.data` (unchanged nrow).

**Note on `.by`:** Rejected with a typed error. Use `group_by()` instead.

**Note on `@variables$domain`:** The accumulated quosures in `@variables$domain`
are for audit and display only. See Section 2.6. Do not use them to reconstruct
domain membership — use `@data[[SURVEYCORE_DOMAIN_COL]]`.

---

### 3.2 `select()` and `dplyr_reconstruct()`

**File:** `R/02-select.R`

#### `select.survey_base`

**Signature:** `select.survey_base(.data, ...)`

**Behavior:**
1. Resolve user's selection: `user_pos <- tidyselect::eval_select(rlang::expr(c(...)), .data@data)`.
2. Compute protected cols already in data: `protected <- intersect(.protected_cols(.data), names(.data@data))`.
3. User-selected names: `user_cols <- names(user_pos)`.
4. Visible columns: `visible <- user_cols`. All user-selected columns are visible,
   including design variables if the user explicitly selected them. Design variables
   are not automatically hidden — the user's explicit selection is the truth.
5. Final data cols: `final_cols <- union(user_cols, protected)` (order: user's
   order first, then any protected cols not already in `user_cols` appended).
6. Removed cols: `dropped <- setdiff(names(.data@data), final_cols)`.
7. `@data <- @data[, final_cols, drop = FALSE]`.
8. Delete metadata for `dropped` cols. Use `surveycore:::.delete_metadata_col()`
   if available; otherwise delete manually across all `@metadata` slots
   (`variable_labels`, `value_labels`, `question_prefaces`, `notes`,
   `transformations`). See Section 2.4.
9. Normalise `visible_vars`:
   ```r
   @variables$visible_vars <- if (
     length(visible) == 0L || setequal(visible, final_cols)
   ) NULL else visible
   ```
   `final_cols` is the variable defined in step 5 (`union(user_cols, protected)`).
   Using it explicitly avoids ambiguity — `names(.data@data)` after step 7 equals
   `final_cols`, but referencing `final_cols` directly makes that clear to the
   implementor. `NULL` means "show all" — normalise to it when the selection is
   empty or the user selected every column in `@data` (including all protected ones,
   as with `everything()`).
10. Return `.data`.

**Edge cases:**
- Negative selection (`select(-y3)`): tidyselect resolves this; apply same contract.
- `everything()`: resolves to all cols; `visible_vars` normalises to `NULL`.
- User selects only design variables: `visible` = those design vars; if that
  equals `names(.data@data)`, normalise to `NULL`.
- Domain column (`..surveycore_domain..`) always preserved if present (it is
  in `protected`).
- **`select()` before any `filter()`:** domain col does not yet exist in `@data`.
  The `intersect()` in step 2 handles this — domain col is simply absent from
  `protected`, and it will not be in `final_cols` until it is created.

**Required test assertions (three-part domain survival):**

```r
d2 <- filter(d, y1 > 0)
d3 <- select(d2, y1, y2)

# 1. Domain col is still in @data
expect_true(SURVEYCORE_DOMAIN_COL %in% names(d3@data))

# 2. Domain col values are unchanged (same TRUE/FALSE per row)
expect_identical(d3@data[[SURVEYCORE_DOMAIN_COL]],
                 d2@data[[SURVEYCORE_DOMAIN_COL]])

# 3. Domain col is NOT in visible_vars (user didn't select it)
expect_false(SURVEYCORE_DOMAIN_COL %in% (d3@variables$visible_vars %||% character(0)))
```

#### `dplyr_reconstruct.survey_base`

**File:** `R/utils.R` (moved from `R/01-filter.R`)

Called by dplyr for complex operations (joins, `across()`, `slice`, etc.).

**Behavior:**
1. Check design variables: `missing_vars <- setdiff(surveycore::.get_design_vars_flat(template), names(data))`.
   If any are missing → abort `surveycore_error_design_var_removed`.
2. Clean up `visible_vars`: if dplyr removed any non-design columns that `visible_vars`
   referenced, those references must be dropped to preserve Invariant 6:
   ```r
   if (!is.null(template@variables$visible_vars)) {
     vv <- intersect(template@variables$visible_vars, names(data))
     template@variables$visible_vars <- if (length(vv) == 0L) NULL else vv
   }
   ```
3. `template@data <- data`.
4. Return `template`.

This step is the safety net for complex dplyr pipelines that route through
`dplyr_reconstruct()`. The `visible_vars` cleanup handles cases where dplyr
internally removes non-design columns (e.g., via `.keep = "none"` mutations
routed through dplyr's internal machinery) before calling reconstruct.

---

### 3.3 `relocate()`

**File:** `R/02-select.R`

**Signature:** `relocate.survey_base(.data, ..., .before = NULL, .after = NULL)`

**Behavior:**
- When `visible_vars` is **set**: resolve the user's column selection against
  `visible_vars` and reorder `visible_vars` to match the requested order.
  `@data` column order is **not changed** — `visible_vars` is the canonical
  display order, and `@data` ordering is irrelevant for display.
- When `visible_vars` is **NULL**: call `dplyr::relocate(.data@data, ..., .before = .before, .after = .after)`
  on `@data` directly and assign the result back. Protected columns that the
  user did not mention retain their existing relative order.

In both cases, `@variables$visible_vars` controls what `print()` shows.
`@data` column order has no display meaning.

---

### 3.4 `pull()`

**File:** `R/02-select.R`

**Signature:** `pull.survey_base(.data, var = -1, name = NULL, ...)`

**Behavior:**
1. Delegate to `dplyr::pull(.data@data, var = {{ var }}, name = {{ name }}, ...)`.
   The `{{ }}` embrace operator is correct here — `dplyr::pull()` accepts
   tidy-eval expressions and handles the forwarding.
2. Return the resulting vector directly (not a survey object).

`pull()` is a terminal operation — the result is never a survey design. No
invariant checks apply (the return type is not a survey object). No
`@groups` or `@metadata` considerations apply. Pulling a design variable
(e.g., `pull(d, wt)`) is valid and returns the weight vector.

---

### 3.5 `glimpse()`

**File:** `R/02-select.R`

**Signature:** `glimpse.survey_base(x, width = NULL, ...)`

**Behavior:**
1. If `x@variables$visible_vars` is non-`NULL`, call
   `dplyr::glimpse(x@data[, x@variables$visible_vars, drop = FALSE], width, ...)`.
2. Otherwise call `dplyr::glimpse(x@data, width, ...)`.
3. Return `invisible(x)` (matches dplyr's `glimpse()` return contract).

---

### 3.6 `mutate()`

**File:** `R/03-mutate.R`

**Signature:**
`mutate.survey_base(.data, ..., .by = NULL, .keep = c("all","used","unused","none"), .before = NULL, .after = NULL)`

**Behavior:**

**Step 1 — Grouped mutate:** Determine the effective `.by` grouping.
```r
effective_by <- if (is.null(.by) && length(.data@groups) > 0L) {
  dplyr::all_of(.data@groups)
} else {
  .by
}
```
When `.by` is `NULL` and `@groups` is non-empty, pass `@groups` as the
effective grouping — this makes `group_by(d, region) |> mutate(z = mean(x))`
work identically to dplyr.

**Step 2 — Detect design variable modification (name-based):**
```r
mutations     <- rlang::quos(...)
mutated_names <- names(mutations)
protected     <- intersect(.protected_cols(.data), names(.data@data))
changed_design <- intersect(mutated_names, protected)
if (length(changed_design) > 0L) {
  cli::cli_warn(
    c(
      "!" = "mutate() modified design variable(s): {.field {changed_design}}.",
      "i" = "The survey design has been updated to reflect the new values.",
      "v" = paste0(
        "Use {.fn update_design} if you intend to modify design variables. ",
        "Modifying them via {.fn mutate} may produce unexpected variance estimates."
      )
    ),
    class = "surveytidy_warning_mutate_design_var"
  )
}
```
**Note:** This detection is name-based. `across()` expressions that modify
design variables will NOT trigger this warning, because the LHS of an `across()`
call is not a named expression. This limitation is known and accepted for
Phase 0.5. A spec note will document it in the `mutate()` roxygen.

**Step 3 — Run the mutation:**
```r
new_data <- dplyr::mutate(
  .data@data, ...,
  .by = effective_by, .keep = .keep, .before = .before, .after = .after
)
```

**Step 4 — Re-attach protected columns dropped by `.keep`:**
```r
protected_in_data <- intersect(.protected_cols(.data), names(.data@data))
missing <- setdiff(protected_in_data, names(new_data))
if (length(missing) > 0L) {
  new_data <- cbind(new_data, .data@data[, missing, drop = FALSE])
}
```
Column order after `cbind()` is implementation-defined — survey objects are
identified by column name, not position.

**Step 5 — Update `visible_vars`:**
```r
new_cols     <- setdiff(names(new_data), names(.data@data))
if (!is.null(.data@variables$visible_vars)) {
  vv <- .data@variables$visible_vars
  vv <- intersect(vv, names(new_data))  # remove cols dropped by .keep
  vv <- c(vv, new_cols)                  # add newly created cols
  .data@variables$visible_vars <- if (length(vv) == 0L) NULL else vv
}
# If visible_vars is NULL, stays NULL (all cols visible, including new ones)
```

**Step 6 — Track new column transformations in `@metadata`:**
```r
for (col in new_cols) {
  q <- mutations[[col]]
  if (!is.null(q)) {
    .data@metadata@transformations[[col]] <- rlang::quo_text(q)
  }
  # If q is NULL (e.g., col was created by across() or a multi-column expression),
  # skip silently — no entry is recorded for that column.
}
```

**Note on partial tracking:** Transformation recording is name-based. Only
explicitly-named mutations (e.g., `mutate(d, z = y1 * 2)`) are tracked — the
quosure for `z` is available as `mutations[["z"]]`. Columns created by `across()`
or other multi-output expressions are **not** tracked because there is no
per-column quosure entry in `mutations`. This limitation must be documented in
the `mutate()` roxygen.

**Step 7:** Set `@data <- new_data`. Return `.data`.

---

### 3.7 `rename()`

**File:** `R/04-rename.R`

#### `rename.survey_base`

**Signature:** `rename.survey_base(.data, ...)`

**Behavior:**
1. Resolve the renaming map: `map <- tidyselect::eval_rename(rlang::expr(c(...)), .data@data)`.
   Result is a named integer vector from tidyselect; extract names:
   `new_names <- names(map); old_names <- names(.data@data)[map]`.
2. If any `old_name` is in `intersect(.protected_cols(.data), names(.data@data))` →
   warn `surveytidy_warning_rename_design_var`.
3. Rename columns in `@data`:
   `names(.data@data)[match(old_names, names(.data@data))] <- new_names`.
4. Update `@variables` for any renamed design variable:
   `surveycore:::.update_design_var_names(.data, setNames(old_names, new_names))`.
5. Update `@metadata` keys:
   For each renamed pair, call `surveycore:::.rename_metadata_keys(.data@metadata, old, new)`.
6. Update `visible_vars`: replace any occurrence of an old name with the new name:
   ```r
   vv <- .data@variables$visible_vars
   for (i in seq_along(old_names)) {
     vv[vv == old_names[[i]]] <- new_names[[i]]
   }
   .data@variables$visible_vars <- vv
   ```
7. Return `.data`.

**Required three-way combined test (design var + `visible_vars`):**

```r
d2 <- select(d, y1, wt)            # visible_vars = c("y1", "wt"); wt is weight col
d3 <- rename(d2, weight = wt)      # rename the weight column

# 1. @data has "weight", not "wt"
expect_true("weight" %in% names(d3@data))
expect_false("wt" %in% names(d3@data))

# 2. @variables$weights updated
expect_identical(d3@variables$weights, "weight")

# 3. visible_vars updated
expect_identical(d3@variables$visible_vars, c("y1", "weight"))
```

#### `rename_with()` — DEFERRED

`rename_with()` is deferred to a follow-up branch after `feature/rename`.
It will share renaming logic with `rename()` via an extracted
`.apply_rename_map(design, old_names, new_names)` internal helper. This
helper will be introduced when `rename_with()` is implemented, refactoring
`rename()` at the same time to call it.

---

### 3.8 `arrange()`

**File:** `R/05-arrange.R`

**Signature:** `arrange.survey_base(.data, ..., .by_group = FALSE)`

**Behavior:**
1. Handle `.by_group = TRUE` by prepending `@groups` to the sort order:
   ```r
   if (isTRUE(.by_group) && length(.data@groups) > 0L) {
     new_data <- dplyr::arrange(
       .data@data,
       dplyr::across(dplyr::all_of(.data@groups)),
       ...
     )
   } else {
     new_data <- dplyr::arrange(.data@data, ..., .by_group = .by_group)
   }
   ```
   Since `@groups` is stored on the survey object (not as a `grouped_df`
   attribute on `@data`), dplyr's native `.by_group = TRUE` would silently
   do nothing — `@data` has no grouping attribute for dplyr to read. This
   step implements the correct behavior explicitly.
2. Set `@data <- new_data`.
3. Return `.data`.

**Domain column after `arrange()`:** The domain column moves correctly with
the rows — it is just another column in `@data`. No update to
`@variables$domain` is needed. See Section 2.6 for why quosures are not
re-evaluated.

**Required test — exact row-association assertion:**

```r
d2 <- filter(d, y1 > mean(d@data$y1))
domain_col <- surveycore::SURVEYCORE_DOMAIN_COL

original_domain <- d2@data[[domain_col]]
original_y1     <- d2@data[["y1"]]

d3 <- arrange(d2, y1)

sorted_order <- order(original_y1)
expect_identical(d3@data[[domain_col]], original_domain[sorted_order])
```

No metadata updates needed (metadata is per-variable, not per-row).

---

### 3.9 `slice_*()` Family

**File:** `R/05-arrange.R`

Six functions: `slice`, `slice_head`, `slice_tail`, `slice_min`, `slice_max`,
`slice_sample`.

**All six share the same contract:**
1. Warn: `.warn_physical_subset(fn_name)` → `surveycore_warning_physical_subset`.
2. Apply the corresponding dplyr function to `@data`:
   `new_data <- dplyr::slice_*(data@data, ...)`.
3. If `nrow(new_data) == 0L` → abort `surveytidy_error_subset_empty_result`.
4. Set `@data <- new_data`.
5. Return `.data`.

**`slice_sample()` additional check:** If `weight_by` is provided,
warn `surveytidy_warning_slice_sample_weight_by`:

```r
if (!is.null(list(...)$weight_by)) {
  cli::cli_warn(
    c(
      "!" = "{.fn slice_sample} was called with {.arg weight_by} on a survey object.",
      "i" = paste0(
        "The {.arg weight_by} column samples rows proportional to its values, ",
        "independently of the survey design weights."
      ),
      "v" = "If you intend probability-proportional sampling, use the survey design weights instead."
    ),
    class = "surveytidy_warning_slice_sample_weight_by"
  )
}
```

**Implementation:** Use a factory function to avoid DRY violations. For
`slice_sample`, extend the factory to accept an optional `check_fn`:

```r
.make_slice_method <- function(fn_name, dplyr_fn, check_fn = NULL) {
  function(.data, ...) {
    .warn_physical_subset(fn_name)
    if (!is.null(check_fn)) check_fn(...)
    new_data <- dplyr_fn(.data@data, ...)
    if (nrow(new_data) == 0L) {
      cli::cli_abort(
        c(
          "x" = "{.fn {fn_name}} produced 0 rows.",
          "i" = "Survey objects require at least 1 row.",
          "v" = "Use {.fn filter} for domain estimation (keeps all rows)."
        ),
        class = "surveytidy_error_subset_empty_result"
      )
    }
    .data@data <- new_data
    .data
  }
}

.check_slice_sample_weight_by <- function(...) {
  if (!is.null(list(...)$weight_by)) {
    cli::cli_warn(
      c(
        "!" = "{.fn slice_sample} was called with {.arg weight_by} on a survey object.",
        "i" = paste0(
          "The {.arg weight_by} column samples rows proportional to its values, ",
          "independently of the survey design weights."
        ),
        "v" = "If you intend probability-proportional sampling, use the survey design weights instead."
      ),
      class = "surveytidy_warning_slice_sample_weight_by"
    )
  }
}

slice.survey_base        <- .make_slice_method("slice",        dplyr::slice)
slice_head.survey_base   <- .make_slice_method("slice_head",   dplyr::slice_head)
slice_tail.survey_base   <- .make_slice_method("slice_tail",   dplyr::slice_tail)
slice_min.survey_base    <- .make_slice_method("slice_min",    dplyr::slice_min)
slice_max.survey_base    <- .make_slice_method("slice_max",    dplyr::slice_max)
slice_sample.survey_base <- .make_slice_method(
  "slice_sample", dplyr::slice_sample, check_fn = .check_slice_sample_weight_by
)
```

All six must be registered in `.onLoad()` via `registerS3method()`.

---

### 3.10 `group_by()`

**File:** `R/06-group-by.R`

**Signature:** `group_by.survey_base(.data, ..., .add = FALSE, .drop = dplyr::group_by_drop_default(.data))`

**Behavior:**
1. Delegate grouping resolution to dplyr to guarantee identical semantics:
   ```r
   grouped <- dplyr::group_by(.data@data, ...)
   group_names <- dplyr::group_vars(grouped)
   ```
   This handles all dplyr edge cases: bare column names, computed expressions,
   tidy-select helpers, and any future dplyr `group_by()` extensions.
   The `grouped_df` object is not stored — it is used only to extract column names.
2. Apply `.add` logic:
   - `.add = FALSE` (default): `@groups <- group_names`.
   - `.add = TRUE`: `@groups <- unique(c(.data@groups, group_names))`.
3. Return `.data`.

**Important:** `group_by()` does **not** add dplyr's `grouped_df` attribute to
`@data`. Grouping is stored exclusively in `@groups`. `mutate()` reads `@groups`
and passes it as `.by` to dplyr internally (see Section 3.6). Analysis functions
in Phase 1 will read `@groups` to perform stratified estimation.

---

### 3.11 `ungroup()`

**File:** `R/06-group-by.R`

**Signature:** `ungroup.survey_base(x, ...)`

**Behavior:** Matches dplyr's `ungroup()` semantics exactly.

```r
ungroup.survey_base <- function(x, ...) {
  if (...length() == 0L) {
    # No arguments: remove ALL groups
    x@groups <- character(0)
  } else {
    # Column arguments: partial ungroup — remove only specified columns
    pos      <- tidyselect::eval_select(rlang::expr(c(...)), x@data)
    to_remove <- names(pos)
    x@groups <- setdiff(x@groups, to_remove)
  }
  x
}
```

`ungroup(d)` clears all groups. `ungroup(d, col1, col2)` removes only
`col1` and `col2` from `@groups`, leaving other groups intact.

---

### 3.12 `subset()` ✅ Complete

**File:** `R/01-filter.R`

**Signature:** `subset.survey_base(x, condition, ...)`

**Behavior:**
1. Warn: `.warn_physical_subset("subset")`.
2. Evaluate `condition` against `x@data`.
3. Map `NA` results to `FALSE`.
4. If `!any(keep_mask)` → abort `surveytidy_error_subset_empty_result`.
5. `x@data <- x@data[keep_mask, , drop = FALSE]`.
6. Return `x`.

---

### 3.13 `drop_na()` [Stretch Goal]

**File:** `R/07-tidyr.R`

**Signature:** `drop_na.survey_base(data, ...)`

**Behavior:**
1. Warn: `.warn_physical_subset("drop_na")`.
2. If `...` is empty, identify rows with `NA` in any column of `@data`.
   If `...` specifies columns, identify rows with `NA` in those columns only.
   Use `tidyselect::eval_select()` to resolve column specification.
3. `keep_mask <- !rowSums(is.na(.data@data[, target_cols, drop = FALSE])) > 0`.
4. If `!any(keep_mask)` → abort `surveytidy_error_subset_empty_result`.
5. `data@data <- data@data[keep_mask, , drop = FALSE]`.
6. Return `data`.

---

## 4. Error and Warning Class Registry

All classes thrown by surveytidy code.

| # | Class | Level | Thrown by | Message summary |
|---|-------|-------|-----------|-----------------|
| 1 | `surveycore_error_filter_by_unsupported` | ERROR | `filter()` | `.by` is not supported; use `group_by()` |
| 2 | `surveytidy_error_filter_non_logical` | ERROR | `filter()` | Condition {i} returned `{class}`, not logical |
| 3 | `surveycore_warning_empty_domain` | WARN | `filter()` | 0 rows match — empty domain |
| 4 | `surveycore_warning_physical_subset` | WARN | `subset()`, `slice_*()`, `drop_na()` | Physically removes rows; use `filter()` |
| 5 | `surveytidy_error_subset_empty_result` | ERROR | `subset()`, `slice_*()`, `drop_na()` | Condition matched 0 rows |
| 6 | `surveycore_error_design_var_removed` | ERROR | `dplyr_reconstruct()` | Required design variables removed |
| 7 | `surveytidy_warning_mutate_design_var` | WARN | `mutate()` | Design variable name found on LHS of mutation |
| 8 | `surveytidy_warning_rename_design_var` | WARN | `rename()` | Design variable renamed; `@variables` updated |
| 9 | `surveytidy_warning_slice_sample_weight_by` | WARN | `slice_sample()` | `weight_by` used independently of survey weights |

### 4.1 Message Templates

**Class 7 — `surveytidy_warning_mutate_design_var`:**
```r
cli::cli_warn(
  c(
    "!" = "mutate() modified design variable(s): {.field {changed_design}}.",
    "i" = "The survey design has been updated to reflect the new values.",
    "v" = paste0(
      "Use {.fn update_design} if you intend to modify design variables. ",
      "Modifying them via {.fn mutate} may produce unexpected variance estimates."
    )
  ),
  class = "surveytidy_warning_mutate_design_var"
)
```

**Class 8 — `surveytidy_warning_rename_design_var`:**
```r
cli::cli_warn(
  c(
    "!" = "rename() renamed design variable(s): {.field {old_names[is_design]}}.",
    "i" = "The survey design has been updated to use the new name(s)."
  ),
  class = "surveytidy_warning_rename_design_var"
)
```

**Class 9 — `surveytidy_warning_slice_sample_weight_by`:**
```r
cli::cli_warn(
  c(
    "!" = "{.fn slice_sample} was called with {.arg weight_by} on a survey object.",
    "i" = paste0(
      "The {.arg weight_by} column samples rows proportional to its values, ",
      "independently of the survey design weights."
    ),
    "v" = "If you intend probability-proportional sampling, use the survey design weights instead."
  ),
  class = "surveytidy_warning_slice_sample_weight_by"
)
```

### 4.2 Test Coverage Map

| Test file | Covers classes |
|-----------|----------------|
| `test-filter.R` | 1, 2, 3, 4 (subset), 5 (subset), 6 |
| `test-select.R` | — |
| `test-mutate.R` | 7 |
| `test-rename.R` | 8 |
| `test-arrange.R` | 4 (slice_*), 5 (slice_*), 9 |
| `test-group-by.R` | — |
| `test-tidyr.R` | 4 (drop_na), 5 (drop_na) |

---

## 5. Testing Requirements

### 5.1 Per-Verb Test Checklist

Every verb test file must include all of the following:

**Happy path:**
- [ ] Returns the same survey class (use loop over `make_all_designs()`)
- [ ] `test_invariants(result)` passes for all three design types
- [ ] Core behavior is correct (e.g., `select()` actually removes the right columns)

**Design preservation:**
- [ ] All design variables still present in `@data` after the operation
- [ ] `@groups` unchanged (unless the verb is `group_by()`/`ungroup()`)
- [ ] `@variables$visible_vars` unchanged (unless the verb explicitly manages it)
- [ ] `@metadata` preserved for columns that weren't affected

**Error paths:**
- [ ] Every error class from the registry: `expect_error(class = "...")`
- [ ] Every error class: `expect_snapshot(error = TRUE, ...)` (generates/compares text)

**Warning paths:**
- [ ] Every warning class: `expect_warning(class = "...")`
- [ ] Every warning class: `expect_snapshot({ invisible(fn(...)) })` (captures warning only)

**Edge cases (required for each verb):**

| Verb | Required edge cases |
|------|---------------------|
| `filter()` | Chained AND; NA→FALSE; no conditions; empty domain; non-logical condition types: numeric (snapshot), character (class check), factor (class check) |
| `select()` | Negative selection; `everything()` (normalises to NULL visible_vars); design-var-only selection; domain column survival (three-part assertion: in `@data`, values unchanged, NOT in `visible_vars`); `select()` before any `filter()` (no domain col yet) |
| `relocate()` | With `visible_vars` set (only visible_vars reordered, @data unchanged); without `visible_vars` (operates on @data directly) |
| `pull()` | Pull a design variable (returns vector, not error); pull with `name =` argument; pull a non-existent column (`expect_error()`, no class check — dplyr's error is accepted) |
| `glimpse()` | With `visible_vars = NULL` — all columns shown, returns `invisible(x)`; after `select(d, y1, y2)` — only `y1`, `y2` shown (not design vars) |
| `mutate()` | `across()`; `.keep = "none"` (design vars re-attached; visible_vars updated); `.keep = "used"` (design vars re-attached); modify a design var by name (warns); new col added to visible_vars when visible_vars is set; `group_by(d, g) |> mutate(z = mean(x))` works grouped |
| `rename()` | Rename a design variable (warns, updates `@variables`); rename a col in `visible_vars` (updates `visible_vars`); three-way combined test (design var + `visible_vars` simultaneously, per Section 3.7) |
| `arrange()` | Domain column values stay correctly row-associated after sort (use exact sorted-order assertion from Section 3.8); `visible_vars` unchanged |
| `slice_*()` | All 6 functions; 0-row result; `slice_sample(weight_by =)` warns |
| `group_by()` | `.add = TRUE`; bare column names; computed expressions (`cut(age, breaks)`) |
| `ungroup()` | Full ungroup (no args); partial ungroup (removes specified cols from `@groups`); no-op on already-ungrouped object |

### 5.2 Integration Tests (`test-pipeline.R`)

**Created on `feature/select` (first version) and grown incrementally.**
Each branch adds at least one integration test. By `feature/group-by`, all
6 tests exist.

| Test | Earliest branch |
|------|----------------|
| 1. **Domain survival:** `filter()` domain column persists through `select()` | `feature/select` |
| 2. **`visible_vars` propagation:** `select()` state persists through `mutate()`, `arrange()`, `rename()` | `feature/rename` |
| 3. **`@groups` survival:** `group_by()` state persists through `filter()`, `select()`, `mutate()`, `arrange()` | `feature/group-by` |
| 4. **Filter chaining:** `d |> filter(A) |> filter(B)` equals `d |> filter(A, B)` for domain column values | `feature/select` |
| 5. **Metadata through pipeline:** Variable label set before pipeline is present after `select() |> rename() |> mutate()` | `feature/rename` |
| 6. **Full Phase 1 prep pipeline:** `d |> filter(A) |> select(x, y) |> group_by(g) |> arrange(x)` — result has correct class, invariants pass, `@groups` and domain intact | `feature/group-by` |

### 5.3 Coverage Target

- **Target:** ≥98% line coverage
- **Blocking:** PRs that drop coverage below 95% are blocked by CI
- `# nocov` blocks require a comment explaining why the branch is unreachable

### 5.4 Snapshot Policy

Snapshots live in `tests/testthat/_snaps/`. They are committed to version control.
Snapshot failures block PRs. Update via `testthat::snapshot_review()` (never
`snapshot_accept()` blindly). Each snapshot change must be reviewed individually.

---

## 6. Implementation Plan

### 6.1 Branch Order

Dependencies flow left → right. Each branch merges to `main` before the next starts.

```
feature/filter ✅
  └── feature/select       (select, relocate, pull, glimpse; test-pipeline.R v1)
        └── feature/mutate  (mutate)
              └── feature/rename   (rename; test-pipeline.R v2)
                    └── feature/arrange  (arrange, slice_*)
                          └── feature/group-by  (group_by, ungroup; test-pipeline.R v3 — all 6 tests)
                                └── feature/rename-with  (rename_with; .apply_rename_map refactor) [follow-up]
                                      └── feature/tidyr  (drop_na) [stretch]
```

### 6.2 Per-Branch Deliverables

| Branch | R files | Test files | `.onLoad()` registrations |
|--------|---------|-----------|--------------------------|
| `feature/select` | `R/02-select.R` (+ move `dplyr_reconstruct` to `R/utils.R`) | `tests/testthat/test-select.R`, `tests/testthat/test-pipeline.R` (tests 1, 4) | select, relocate, pull, glimpse, dplyr_reconstruct |
| `feature/mutate` | `R/03-mutate.R` | `tests/testthat/test-mutate.R` | mutate |
| `feature/rename` | `R/04-rename.R` | `tests/testthat/test-rename.R` (+ `test-pipeline.R` tests 2, 5) | rename |
| `feature/arrange` | `R/05-arrange.R` | `tests/testthat/test-arrange.R` | arrange, slice (×6) |
| `feature/group-by` | `R/06-group-by.R` | `tests/testthat/test-group-by.R` (+ `test-pipeline.R` tests 3, 6) | group_by, ungroup |
| `feature/rename-with` | `R/04-rename.R` (refactor) | update `tests/testthat/test-rename.R` | rename_with |
| `feature/tidyr` | `R/07-tidyr.R` | `tests/testthat/test-tidyr.R` | drop_na |

**`feature/select` also:** Move `dplyr_reconstruct.survey_base` from
`R/01-filter.R` to `R/utils.R`. Update `.onLoad()` registration accordingly.
Update `test-wiring.R` if it references the old location.

### 6.3 Pre-Implementation Checklist (Each Branch)

Before writing any code on a new branch:

- [ ] Read `plans/phase-0.5-formal-specification.md` (this file) for the verb contract
- [ ] Read `../survey-standards/.claude/rules/` (code-style, testing-standards, r-package-conventions)
- [ ] Read `plans/claude-decisions-phase-0.5.md` for architectural decisions
- [ ] Confirm `NAMESPACE` and `.onLoad()` registrations are in sync
- [ ] Check whether `surveycore:::.delete_metadata_col()` exists before implementing `select()`

### 6.4 Pre-Merge Checklist (Each Branch)

Before opening a PR:

- [ ] `devtools::test()` → 0 failures, 0 warnings
- [ ] `devtools::check()` → 0 errors, 0 warnings, ≤2 notes
- [ ] `devtools::document()` run; NAMESPACE committed
- [ ] All snapshot tests generated and reviewed
- [ ] All three design types tested (taylor, replicate, twophase)
- [ ] `test_invariants()` called in every test that returns a survey object
- [ ] `@groups` propagation verified (unchanged through verb unless group_by/ungroup)
- [ ] `visible_vars` consistency verified (all listed cols exist in `@data`)
- [ ] Changelog entry added (`changelog/phase-0.5/`)
- [ ] Decisions log updated if any architectural question arose

---

## 7. Quality Gates (Phase 0.5 Exit Criteria)

Phase 0.5 is **complete** when all of the following pass on `main`:

### 7.1 Build

- [ ] `devtools::check()` → 0 errors, 0 warnings, ≤2 notes (pre-approved: hidden files, non-standard dirs)
- [ ] `devtools::document()` → NAMESPACE and `man/` are up to date
- [ ] Package installs cleanly on macOS, Ubuntu, Windows (CI matrix)

### 7.2 Tests

- [ ] `devtools::test()` → 0 failures, 0 warnings, 0 skips
- [ ] Line coverage ≥ 98%
- [ ] `test-pipeline.R` exists and all 6 integration tests pass
- [ ] Snapshot files committed and up to date
- [ ] `test_invariants()` updated to check Invariant 6 (visible_vars consistency)

### 7.3 Implementation Completeness

- [ ] All Priority 1 verbs implemented and tested: `filter`, `select`, `relocate`,
  `pull`, `glimpse`, `mutate`, `rename`, `arrange`, `slice` (×6),
  `group_by`, `ungroup`
- [ ] All Priority 2 verbs: `subset`
- [ ] `R/utils.R` contains `.protected_cols()`, `.warn_physical_subset()`, and `dplyr_reconstruct.survey_base()`
- [ ] `.onLoad()` registers all Priority 1 + 2 verbs
- [ ] All 9 error/warning classes in Section 4 have test coverage (class + snapshot)

### 7.4 Documentation

- [ ] Every exported function has `@return` and a runnable `@examples` block
- [ ] `mutate()` roxygen includes a note: "`across()` expressions that modify design
  variables will not trigger the `surveytidy_warning_mutate_design_var` warning —
  only explicitly-named column assignments are detected."
- [ ] `filter()` roxygen includes a note about `@variables$domain` quosures being
  audit-only; domain column is authoritative.
- [ ] `surveytidy-package.R` has all `@importFrom` stubs for registered verbs
- [ ] `plans/claude-decisions-phase-0.5.md` reflects all architectural decisions made during implementation

### 7.5 Version

- [ ] `DESCRIPTION` version bumped to `0.2.0`
- [ ] `NEWS.md` updated with Phase 0.5 entries
- [ ] Git tag `v0.2.0` created on `main` after all gates pass

---

## Appendix A: `@variables` Structure Reference

### `survey_taylor`

```r
list(
  ids            = NULL | character,  # PSU column name(s)
  weights        = character,         # weight column name (required)
  strata         = NULL | character,  # stratum column name
  fpc            = NULL | character,  # FPC column name
  nest           = logical,
  probs_provided = logical,
  visible_vars   = NULL | character,  # set by select(); updated by mutate() and rename()
  domain         = NULL | list        # accumulated filter() quosures (audit-only)
)
```

### `survey_replicate`

```r
list(
  weights      = character,
  repweights   = character,           # vector of replicate weight col names
  type         = character,
  scale        = numeric,
  rscales      = NULL | numeric,
  fpc          = NULL | character,
  fpctype      = character,
  mse          = logical,
  visible_vars = NULL | character,
  domain       = NULL | list
)
```

### `survey_twophase`

```r
list(
  phase1 = list(ids, weights, strata, fpc, nest, probs_provided, visible_vars),
  phase2 = list(ids, strata, probs, fpc),
  subset = character,
  method = character,
  domain = NULL | list
)
```

---

## Appendix B: surveycore Internal Functions Used by surveytidy

| Function | Access | Purpose |
|----------|--------|---------|
| `surveycore::SURVEYCORE_DOMAIN_COL` | `::` | The constant `"..surveycore_domain.."` |
| `surveycore::.get_design_vars_flat(design)` | `::` | Flat char vec of all design col names; handles all three design types including twophase |
| `surveycore:::.update_design_var_names(design, old, new)` | `:::` | Rename a col in `@variables` |
| `surveycore:::.rename_metadata_keys(metadata, old, new)` | `:::` | Rename a key in all `@metadata` slots |
| `surveycore:::.delete_metadata_col(design, col)` | `:::` | Delete a col from all `@metadata` slots (verify exists before using; file issue if not) |

`:::` usage is limited to these functions. All are stable internals unlikely to
change; if they do, only `R/04-rename.R` and `R/02-select.R` are affected.
