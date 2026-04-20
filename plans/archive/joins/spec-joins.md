# surveytidy Spec: Join Functions

**Version:** 0.3 (Stage 4 complete)
**Date:** 2026-04-16
**Status:** All stages complete — ready for implementation

---

## Document Purpose

This document is the authoritative specification for the eight dplyr join
functions in surveytidy: `left_join`, `inner_join`, `right_join`, `full_join`,
`semi_join`, `anti_join`, `bind_cols`, and `bind_rows`. It supersedes the
informal design notes in `plans/future/joins-design.md`.

All decisions in this document supersede any prior informal discussion.
Implementation must not begin until Stage 2 (methodology review) and Stage 3
(spec review) are complete and all GAPs are resolved.

---

## I. Scope

### What this spec delivers

| Item | Description |
|------|-------------|
| `left_join.survey_base` | Add lookup columns from a data frame; all survey rows preserved |
| `semi_join.survey_base` | Domain-aware filter: keep rows that match `y`; no new columns |
| `anti_join.survey_base` | Domain-aware filter: keep rows that do NOT match `y`; no new columns |
| `bind_cols.survey_base` | Append columns from a data frame by position; no key matching |
| `inner_join.survey_base` | Domain-aware by default (`.domain_aware = TRUE`): marks unmatched rows out-of-domain and adds `y` columns (NAs for unmatched rows). Physical subset with `.domain_aware = FALSE`: removes unmatched rows + warns. |
| `right_join.survey_base` | Error — would add rows with NA design variables |
| `full_join.survey_base` | Error — would add rows with NA design variables |
| `bind_rows` | Error — stacking surveys requires re-specifying the design |

### What this spec does NOT deliver

- Any join producing estimation results (Phase 1 scope)
- Survey × survey joins (error for all functions; see §IV)
- `bind_rows` on plain data frames (dplyr handles that; surveytidy only
  intercepts the case where at least one argument is a survey object)
- Joins on `survey_result` objects (out of scope; survey_result is an output
  type, not an input to joins)

### Design support matrix

| Function | `survey_taylor` | `survey_replicate` | `survey_twophase` |
|---|---|---|---|
| `left_join` | Supported | Supported | Supported |
| `semi_join` | Supported (domain-aware) | Supported | Supported |
| `anti_join` | Supported (domain-aware) | Supported | Supported |
| `bind_cols` | Supported | Supported | Supported |
| `inner_join` | Domain-aware by default (`.domain_aware = TRUE`); physical subset + warn with `.domain_aware = FALSE` | Same as taylor | **Error** — twophase only (see §VI) |
| `right_join` | Error | Error | Error |
| `full_join` | Error | Error | Error |
| `bind_rows` | Error | Error | Error |

---

## II. Architecture

### New file

```
R/joins.R
```

Contains all eight join method implementations. `bind_rows` and `bind_cols`
are included here rather than a separate file because the file size is
expected to be manageable and the implementations are tightly related to the
join error/guard logic.

### Test file

```
tests/testthat/test-joins.R
```

### S3 registration (in `R/zzz.R`)

Each join function requires a `registerS3method()` call in `.onLoad()` under a
`# ── feature/joins ──` comment block, following the established pattern in
`R/zzz.R`. The registrations use `asNamespace("dplyr")` as the envir for all
eight functions — dplyr owns all eight generics.

```r
# ── feature/joins ────────────────────────────────────────────────────────────

registerS3method(
  "left_join",
  "surveycore::survey_base",
  get("left_join.survey_base", envir = ns),
  envir = asNamespace("dplyr")
)
# ... (same pattern for inner_join, right_join, full_join,
#      semi_join, anti_join, bind_cols, bind_rows)
```

`bind_rows` is a dplyr generic. `bind_cols` is also a dplyr generic. Both use
`asNamespace("dplyr")`.

### `dplyr_reconstruct.survey_base` interaction

The existing `dplyr_reconstruct.survey_base` (in `R/utils.R`) is the backstop
for complex dplyr pipelines. The explicit join method implementations are the
primary entry point. When dplyr internally calls `dplyr_reconstruct` after a
join (for pipeline chaining), it fires the backstop — which errors if design
variables are removed.

For `left_join.survey_base`, row-expansion detection must happen **before**
delegating to dplyr — otherwise `dplyr_reconstruct` fires and would succeed
(it only checks for removed columns, not for extra rows).

### Shared internal helpers

| Helper | Signature | Location | Used by |
|--------|-----------|----------|---------|
| `.check_join_y_type(y)` | `(y) → invisible(TRUE)` or error | `R/joins.R` (top of file) | `left_join`, `inner_join`, `right_join`, `full_join`, `semi_join`, `anti_join`, `bind_cols` |
| `.check_join_col_conflict(x, y, by)` | `(x, y, by) → y (data frame, possibly subset)`. Always returns `y`. If no design-variable conflict: returns `y` unchanged. If conflict: emits `surveytidy_warning_join_col_conflict`, drops conflicting columns from `y`, returns cleaned `y`. Columns listed in `by` are **excluded** from the conflict check — they are match keys, not new columns being added, so they pose no threat to design variable integrity. | `R/joins.R` | `left_join`, `inner_join`, `bind_cols` |
| `.check_join_row_expansion(original_nrow, new_nrow)` | `(int, int) → invisible(TRUE)` or error | `R/joins.R` | `left_join`, `inner_join` |
| `.new_join_domain_sentinel(type, keys)` | `(character(1), character) → S3 object of class "surveytidy_join_domain"`. Constructs `structure(list(type = type, keys = keys), class = "surveytidy_join_domain")`. Phase 1 consumers use `inherits(x, "surveytidy_join_domain")` to dispatch vs. quosures. | `R/joins.R` | `semi_join`, `anti_join`, `inner_join` (domain-aware) |
| `.repair_suffix_renames(x, old_x_cols, suffix)` | `(survey_base, character, character(2)) → survey_base`. Detects columns in `old_x_cols` that were suffix-renamed by a join (absent in `names(x@data)` but their suffixed version is present). Builds a rename map (old → new) and applies it to `@metadata@variable_labels` keys and `@variables$visible_vars` entries. Returns the modified survey object. | `R/joins.R` | `left_join` (Step 4b), `inner_join` domain-aware (Step 6) |

> ⚠️ **GAP-1:** If these helpers are ever needed by 2+ source files they
> must move to `R/utils.R` per `code-style.md`. At this scope all three are
> single-file, so they stay in `R/joins.R`.

---

## III. `left_join.survey_base`

### Signature

```r
left_join.survey_base(x, y, by = NULL, copy = FALSE, suffix = c(".x", ".y"),
                       ..., keep = NULL)
```

### Argument table

Argument order follows `code-style.md`. All arguments after `x` are forwarded
to `dplyr::left_join()`.

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | `survey_base` | (required) | The survey design object. |
| `y` | `data.frame` | (required) | A plain data frame with lookup columns. Must not be a survey object. Must not have column names that match any design variable in `x`. |
| `by` | character or `dplyr::join_by()` or `NULL` | `NULL` | Join key specification, forwarded to `dplyr::left_join()`. `NULL` uses common column names. |
| `copy` | `logical(1)` | `FALSE` | Forwarded to `dplyr::left_join()`. |
| `suffix` | `character(2)` | `c(".x", ".y")` | Forwarded to `dplyr::left_join()`. |
| `...` | | | Additional arguments forwarded to `dplyr::left_join()`. |
| `keep` | `logical(1)` or `NULL` | `NULL` | Forwarded to `dplyr::left_join()`. |

### Output contract

`@data`: All original rows preserved. New columns from `y` appended.
Design variable columns are unchanged (guaranteed by `.check_join_col_conflict`).
The domain column is unchanged (left join cannot affect domain membership).

`@variables`: Unchanged, except `visible_vars` — if it was set, the new
columns from `y` are appended to it so they appear in `print()` output.

`@metadata`: New columns from `y` get no labels in
`@metadata@variable_labels` (metadata comes from surveycore's haven import;
externally joined data doesn't carry SPSS/Stata labels). If a column in
`x@data` is suffix-renamed by the join (because `y` had a non-design column
with the same name), the corresponding `@metadata@variable_labels` key is
renamed to match the suffixed column name (see Behavior Step 4b).
`@metadata@transformations` is unchanged.

`@groups`: Preserved from `x` (unchanged).

### Behavior rules

1. **Guard: y must not be a survey object.**  
   Check with `S7::S7_inherits(y, surveycore::survey_base)` before any
   operation. Error: `surveytidy_error_join_survey_to_survey`.

2. **Guard: y must not have columns that match design variables.**  
   `y <- .check_join_col_conflict(x, y, by)`. If conflicts exist, emit
   `surveytidy_warning_join_col_conflict` naming the conflicting columns, then
   drop the conflicting columns from `y` before proceeding. Subsequent steps use
   the cleaned `y`. (Columns listed in `by` are excluded from the check —
   they are join keys, not new columns being added.)

3. **Guard: row count must not expand.**  
   Run `dplyr::left_join(x@data, y, ...)` on the raw data first (storing the
   result). Compare `nrow(result)` to `nrow(x@data)`. If the row count
   increased, error with `surveytidy_error_join_row_expansion` before
   constructing the returned survey object.

   > **GAP-2 resolved:** Row expansion errors. A phantom duplicate row means
   > the same respondent appears multiple times, corrupting variance estimation
   > regardless of intent. If a user has a legitimate long-format use case,
   > they must deduplicate `y` before joining.

4. **Join and reconstruct.**  
   Capture `old_x_cols <- names(x@data)` before joining. Use
   `dplyr::left_join(x@data, y, by = by, copy = copy, suffix = suffix,
   ..., keep = keep)` on `x@data`. Store the result.

4b. **Detect and repair suffix renames.**  
    Copy `result` back into `x@data`. Then call
    `.repair_suffix_renames(x, old_x_cols, suffix)` to update any
    `@metadata@variable_labels` keys and `@variables$visible_vars` entries
    for columns that were suffix-renamed by the join. Design variable columns
    are never in the rename map because `.check_join_col_conflict()` already
    drops conflicting columns from `y` — design variable names are stable.
    Assign the return value back to `x`.

5. **Update `visible_vars`.**  
   After the join (and after Step 4b), if `x@variables$visible_vars` is
   non-NULL, append the names of the new columns from `y` (i.e.,
   columns in `names(result)` that are not in `old_x_cols` and not
   suffix-renamed versions of existing columns) to
   `x@variables$visible_vars`.

6. **Domain column.**  
   No changes to `..surveycore_domain..`. Left join preserves all original
   rows.

### Error and warning table

| Class | Trigger | Message template |
|-------|---------|-----------------|
| `surveytidy_error_join_survey_to_survey` | `y` is a survey object | `"x"`: "`y` is a survey design object, not a data frame." / `"i"`: "Joining two survey objects requires manual reconciliation of design specifications." / `"v"`: "Extract `y@data` to join the underlying data, then re-specify the design with `surveycore::as_survey()`." |
| `surveytidy_warning_join_col_conflict` | `y` has column names matching design variables in `x` | `"!"`: "`y` has {N} column{?s} with the same name{?s} as design variable{?s}: {.field col1}, {.field col2}." / `"i"`: "These column{?s} {?has/have} been dropped from `y` before joining to protect the survey design." / `"i"`: "Use `dplyr::rename()` on `y` to resolve before joining." |
| `surveytidy_error_join_row_expansion` | `left_join` would increase `nrow(x@data)` (duplicate keys in `y`) | `"x"`: "`left_join()` would expand `x` from {old_n} to {new_n} rows because `y` has duplicate keys." / `"i"`: "Duplicate respondent rows corrupt variance estimation." / `"v"`: "Use `dplyr::distinct(y, {key_col})` to deduplicate `y` before joining." |

---

## IV. `semi_join.survey_base` and `anti_join.survey_base`

### Rationale

`semi_join` keeps survey rows that have a match in `y`. `anti_join` keeps rows
that do NOT have a match. Rather than physically removing rows (which would
bias variance estimation), both are implemented as **domain-aware operations**:
unmatched rows are marked `FALSE` in `..surveycore_domain..`, exactly as
`filter()` does.

### Signatures

```r
semi_join.survey_base(x, y, by = NULL, copy = FALSE, ...)
anti_join.survey_base(x, y, by = NULL, copy = FALSE, ...)
```

### Argument table (both functions)

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | `survey_base` | (required) | The survey design object. |
| `y` | `data.frame` | (required) | A plain data frame. Must not be a survey object. |
| `by` | character or `dplyr::join_by()` or `NULL` | `NULL` | Join key specification forwarded to dplyr. |
| `copy` | `logical(1)` | `FALSE` | Forwarded to dplyr. |
| `...` | | | Additional arguments forwarded to dplyr. |

### Output contract

`@data`: All rows present. Row count unchanged. No new columns added.
`..surveycore_domain..` updated (ANDed with the new match mask).

`@variables`: `visible_vars` unchanged (no new columns). `@variables$domain`
— a typed S3 sentinel (class `"surveytidy_join_domain"`, created by
`.new_join_domain_sentinel(type, keys)`) is appended to record the join-based
domain restriction. Phase 1 consumers check `inherits(entry, "surveytidy_join_domain")`
to distinguish sentinels from quosures before calling `rlang::eval_tidy()`.

`@metadata`: Unchanged.

`@groups`: Preserved from `x`.

### Behavior rules (both functions)

1. **Guard: y must not be a survey object.**  
   Same check as `left_join`, same error class.

2. **Compute match mask (row-index approach).**  
   Determine which rows in `x@data` have a match in `y` using a temporary
   row-index column. This approach correctly handles duplicate keys in `y`
   (each survey row can appear at most once in the result) and avoids the
   unreliable `rbind/duplicated` pattern.

   **Reserved column name:** `"..surveytidy_row_index.."`. If
   `"..surveytidy_row_index.."` already exists in `names(x@data)`, error with
   `surveytidy_error_reserved_col_name`.

   **Procedure:**

   ```r
   # 1. Add temporary row index to a copy of x@data (never to x@data itself)
   x_temp <- x@data
   x_temp[["..surveytidy_row_index.."]] <- seq_len(nrow(x@data))

   # 2. Run semi_join on the temp copy to get matched rows (with index)
   matched <- dplyr::semi_join(x_temp, y, by = by, copy = copy, ...)

   # 3. Build the logical mask from matched row indices
   #    (semi_join deduplicates, so each index appears at most once)
   new_mask <- seq_len(nrow(x@data)) %in% matched[["..surveytidy_row_index.."]]

   # 4. No cleanup needed — x_temp is not written back; x@data is unchanged
   ```

   For `anti_join`, the mask is negated in Step 3:
   ```r
   new_mask <- !(seq_len(nrow(x@data)) %in% matched[["..surveytidy_row_index.."]])
   ```

   **Duplicate keys in `y`** collapse to a single `TRUE` per survey row for
   `semi_join` because `dplyr::semi_join` deduplicates by design — verified by
   test 12. For `anti_join`, duplicate keys in `y` that match a survey row
   collapse to a single `FALSE` in the mask (the same row-index approach
   ensures each survey row appears at most once in `matched`, so
   `!(... %in% matched[...])` is `FALSE` for exactly those rows) — verified
   by test 12b.

   **GAP-4 resolved.**

3. **AND with existing domain.**  
   Retrieve the existing domain column:
   ```r
   existing <- x@data[[surveycore::SURVEYCORE_DOMAIN_COL]]
   if (is.null(existing)) existing <- rep(TRUE, nrow(x@data))
   new_domain <- existing & new_mask   # semi_join
   new_domain <- existing & !new_mask  # anti_join
   ```
   Write back to `x@data[[surveycore::SURVEYCORE_DOMAIN_COL]]`.

4. **Empty domain check.**  
   If `all(!new_domain)`, emit `surveycore_warning_empty_domain`.

5. **Verbosity.**  
   Silent. No informational message is emitted. Consistent with `filter()`,
   which marks rows out-of-domain without messaging. **GAP-3 resolved.**

6. **Update `@variables$domain`.**  
   Append a typed S3 sentinel to `@variables$domain` to record that a
   join-based domain restriction was applied. Use the internal helper
   `.new_join_domain_sentinel(type, keys)`:

   ```r
   # For semi_join:
   .new_join_domain_sentinel("semi_join", resolved_by)
   # For anti_join:
   .new_join_domain_sentinel("anti_join", resolved_by)
   ```

   Where `resolved_by` is the character vector of key column names resolved
   from the `by` argument (or the common column names if `by = NULL`).

   The sentinel class `"surveytidy_join_domain"` lets Phase 1 consumers
   distinguish join sentinels from quosures without calling `rlang::eval_tidy()`
   on them: `inherits(entry, "surveytidy_join_domain")` returns `TRUE`; plain
   quosures return `FALSE`. The authoritative domain state remains the
   `..surveycore_domain..` column in `@data`. **GAP-5 resolved.**

### Error and warning table

| Class | Trigger | Message template |
|-------|---------|-----------------|
| `surveytidy_error_join_survey_to_survey` | `y` is a survey object | Same message as `left_join`. |
| `surveytidy_error_reserved_col_name` | `x@data` already contains `"..surveytidy_row_index.."` | `"x"`: "`x@data` contains a reserved internal column `"..surveytidy_row_index.."` that conflicts with masking logic." / `"i"`: "This column name is reserved for internal use by surveytidy." / `"v"`: "Rename the column in your data before passing it to `semi_join()` or `anti_join()`." |
| `surveycore_warning_empty_domain` | All rows out-of-domain after the join | Re-used from surveycore; emitted by the existing `.warn_empty_domain()` helper if one exists, otherwise via inline `cli_warn()`. |

---

## V. `bind_cols.survey_base`

### Rationale

Adds columns from a data frame (or named list) to the survey's `@data` by
row position. Semantically equivalent to an implicit row-index `left_join`.

### Signature

```r
bind_cols.survey_base(x, ..., .name_repair = "unique")
```

### Argument table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | `survey_base` | (required) | The survey design object; always the first argument. |
| `...` | `data.frame` or named list | (required) | One or more plain data frames to bind as new columns. Must not be survey objects. |
| `.name_repair` | `character(1)` | `"unique"` | Forwarded to `dplyr::bind_cols()` for handling duplicate column names. |

### Output contract

`@data`: All rows present (row count unchanged). New columns from `...`
appended in position order.

`@variables`: If `visible_vars` was non-NULL, append the names of new columns
(same logic as `left_join`). Other keys unchanged.

`@metadata`: New columns get no labels (same as `left_join`).

`@groups`: Preserved from `x`.

### Behavior rules

1. **Guard: none of `...` may be a survey object.**  
   Check each element of `list(...)` with `S7::S7_inherits(., surveycore::survey_base)`.
   Error: `surveytidy_error_join_survey_to_survey`.

2. **Guard: column conflict with design variables.**  
   `cleaned_y <- .check_join_col_conflict(x, dplyr::bind_cols(...), by = character(0))`.
   (`bind_cols` has no join keys, so all new columns are subject to the conflict
   check.) Warn + drop conflicting columns. Subsequent steps use `cleaned_y`,
   not the original `...`.

3. **Guard: row count must match exactly.**  
   Verify that `nrow(cleaned_y) == nrow(x@data)`. If not, error with
   `surveytidy_error_bind_cols_row_mismatch`.

4. **Bind and reconstruct.**  
   `x@data <- dplyr::bind_cols(x@data, cleaned_y, .name_repair = .name_repair)`.
   Update `visible_vars` as in `left_join` Step 5.

### Error and warning table

| Class | Trigger | Message template |
|-------|---------|-----------------|
| `surveytidy_error_join_survey_to_survey` | Any element of `...` is a survey object | `"x"`: "Survey objects cannot be combined with `bind_cols()`." / `"i"`: "One or more objects in `...` is a survey design object." / `"v"`: "Extract `@data` from each survey object and bind the raw data frames instead." |
| `surveytidy_warning_join_col_conflict` | Any new column name matches a design variable | Same message template as in `left_join`. |
| `surveytidy_error_bind_cols_row_mismatch` | `nrow(...)` ≠ `nrow(x@data)` | `"x"`: "`bind_cols()` requires all inputs to have the same number of rows." / `"i"`: "`x` has {nrow(x)} row{?s}; the new data has {nrow(y)} row{?s}." / `"v"`: "Ensure the data frame you are binding has exactly {nrow(x)} row{?s} before calling `bind_cols()`." |

---

## VI. `inner_join.survey_base`

### Rationale

`inner_join` has two modes, controlled by the `.domain_aware` argument
(default `TRUE`):

**Domain-aware mode (`.domain_aware = TRUE`, default):** Implemented
internally as a `semi_join` (to compute the match mask and update the domain
column) followed by a `left_join` (to add `y`'s columns to all rows). All
rows remain in `@data`. Unmatched rows are marked `FALSE` in
`..surveycore_domain..` and receive `NA` for the new `y` columns — exactly
as `filter()` marks rows out-of-domain. Row count is unchanged. This is the
survey-correct default: variance estimation remains valid. The `nrow()`
surprise (count stays the same) is consistent with `filter()` and `semi_join()`
precedents in surveytidy.

**Physical mode (`.domain_aware = FALSE`):** Unmatched rows are physically
removed, exactly like base R `inner_join`. Emits
`surveycore_warning_physical_subset`. Errors for `survey_twophase` designs.
Appropriate only when the user explicitly wants to reduce the design to a
specific subpopulation and understands the variance implications.

**Replicate design warning (physical mode):** For `survey_replicate` designs
(BRR, jackknife), physical row removal can corrupt half-sample or pairing
structure, producing numerically wrong variance estimates without triggering
an error. When `.domain_aware = FALSE` on a replicate design,
`surveycore_warning_physical_subset` is the only protection. The `@details`
section of the roxygen docs should recommend domain-aware mode for replicate
designs.

### Signature

```r
inner_join.survey_base(x, y, by = NULL, copy = FALSE, suffix = c(".x", ".y"),
                        ..., keep = NULL, .domain_aware = TRUE)
```

### Argument table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | `survey_base` | (required) | The survey design object. |
| `y` | `data.frame` | (required) | A plain data frame. Must not be a survey object. |
| `by` | character or `dplyr::join_by()` or `NULL` | `NULL` | Join key specification, forwarded to dplyr. |
| `copy` | `logical(1)` | `FALSE` | Forwarded to dplyr. |
| `suffix` | `character(2)` | `c(".x", ".y")` | Forwarded to dplyr. Used in the `left_join` step of domain-aware mode. |
| `...` | | | Additional arguments forwarded to dplyr. |
| `keep` | `logical(1)` or `NULL` | `NULL` | Forwarded to dplyr. |
| `.domain_aware` | `logical(1)` | `TRUE` | If `TRUE` (default): mark unmatched rows out-of-domain and add `y` columns with `NA` for unmatched rows; row count unchanged. If `FALSE`: physically remove unmatched rows and emit `surveycore_warning_physical_subset`; errors for twophase designs. |

### Output contract — domain-aware mode (`.domain_aware = TRUE`)

`@data`: All original rows preserved. Row count unchanged. New columns from
`y` appended; unmatched rows receive `NA` for those columns.
`..surveycore_domain..` updated: ANDed with the match mask (unmatched rows
become `FALSE`). Existing domain values for matched rows are preserved.

`@variables`: `visible_vars` — if set, new columns from `y` are appended.
`@variables$domain` — a typed S3 sentinel (class `"surveytidy_join_domain"`,
via `.new_join_domain_sentinel("inner_join", resolved_by)`) is appended to
record the join-based domain restriction, consistent with the `semi_join`/
`anti_join` sentinel pattern.

`@metadata`: New columns from `y` get no labels. Unchanged otherwise.

`@groups`: Preserved from `x`.

### Output contract — physical mode (`.domain_aware = FALSE`)

`@data`: Rows without a match in `y` are physically removed. Row count ≤
`nrow(x)`. The domain column (`..surveycore_domain..`) — if it existed —
survives for remaining rows with values unchanged. Removed rows are gone.

`@variables`: Unchanged. `visible_vars` column list is unchanged (row op).
`@variables$domain` is unchanged — reflects only prior `filter()` conditions.

`@metadata`: Unchanged.

`@groups`: Preserved from `x`.

### Behavior rules — domain-aware mode (`.domain_aware = TRUE`)

1. **Guard: y must not be a survey object.** Same as `left_join`.

2. **Guard: column conflict.** `y <- .check_join_col_conflict(x, y, by)`.
   Warn + drop conflicting columns from `y` before proceeding. Subsequent steps
   use the cleaned `y`.

3. **Compute match mask.**  
   Use the same row-index approach specified in §IV (semi_join behavior rules
   Step 2) to determine which rows in `x@data` have a match in `y`.

4. **AND with existing domain.**  
   Retrieve existing domain column (defaulting to all `TRUE` if absent).
   `new_domain <- existing & match_mask`. Write back to
   `x@data[[surveycore::SURVEYCORE_DOMAIN_COL]]`.

5. **Empty domain check.**  
   If `all(!new_domain)`, emit `surveycore_warning_empty_domain`.

6. **Left join for new columns.**  
   Capture `old_x_cols <- names(x@data)`. Run
   `dplyr::left_join(x@data, y, by = by, copy = copy, suffix = suffix,
   ..., keep = keep)` to add `y`'s columns to all rows (NAs for unmatched).
   **Guard: row count must not expand.** Call
   `.check_join_row_expansion(nrow(x@data), nrow(result))` before writing
   the result back. If `y` has duplicate keys, this left_join can expand
   `x@data` the same way it does in `left_join.survey_base`; this guard
   prevents silent row multiplication even in domain-aware mode. Error class:
   `surveytidy_error_join_row_expansion`.
   Call `.repair_suffix_renames(x, old_x_cols, suffix)` to update any
   `@metadata@variable_labels` keys and `@variables$visible_vars` entries
   for suffix-renamed columns. Update `visible_vars` if set (append new
   columns from `y`).

7. **Update `@variables$domain` sentinel.**  
   Call `.new_join_domain_sentinel('inner_join', resolved_by)` and append
   the result to `x@variables$domain`.

### Behavior rules — physical mode (`.domain_aware = FALSE`)

1. **Guard: y must not be a survey object.** Same as `left_join`.

2. **Guard: twophase designs.** If
   `S7::S7_inherits(x, surveycore::survey_twophase)`, error with
   `surveytidy_error_join_twophase_row_removal`. Physical row removal can
   orphan phase 2 rows or corrupt the phase 1 sample frame.

3. **Guard: column conflict.** Same as `left_join` — `y <- .check_join_col_conflict(x, y, by)`,
   warn + drop conflicting columns. Subsequent steps use the cleaned `y`.

4. **Guard: row count must not expand.**  
   Run `dplyr::inner_join(x@data, y, ...)` on the raw data first (storing
   the result). Compare `nrow(result)` to `nrow(x@data)`. If the row count
   **increased**, error with `surveytidy_error_join_row_expansion`.
   Duplicate keys in `y` can expand `inner_join` output the same way they
   do for `left_join`. This guard fires before the physical-subset warning.

5. **Join.**  
   The result is already computed from Step 4. Physical rows without a
   match in `y` are absent from the result.

6. **Warn.**  
   Issue `surveycore_warning_physical_subset` with the specific message
   referencing `inner_join`.

7. **Empty result.**  
   If `nrow(result) == 0`, error with `surveytidy_error_subset_empty_result`
   (re-used from `R/filter.R` / `R/slice.R`).

### Error and warning table

| Class | Trigger | Mode |
|-------|---------|------|
| `surveytidy_error_join_survey_to_survey` | `y` is a survey object | Both |
| `surveytidy_warning_join_col_conflict` | `y` has design-variable column names | Both |
| `surveycore_warning_empty_domain` | All rows out-of-domain after join | Domain-aware only |
| `surveytidy_error_join_row_expansion` | Duplicate keys in `y` would expand row count | Both modes |
| `surveytidy_error_join_twophase_row_removal` | `x` is `survey_twophase` and physical mode requested | Physical only — `"x"`: "`inner_join(.domain_aware = FALSE)` cannot physically remove rows from a two-phase design." / `"i"`: "Removing rows from a two-phase design can orphan phase 2 rows or corrupt the phase 1 sample frame." / `"v"`: "Use `.domain_aware = TRUE` (the default) or `semi_join()` for domain-aware filtering." |
| `surveycore_warning_physical_subset` | Physical mode: join removes rows | Physical only — `"!"`: "`inner_join()` physically removed {removed_n} row{?s} from the survey design." / `"i"`: "Physical row removal can bias variance estimation." / `"i"`: "Use `.domain_aware = TRUE` (the default) to mark rows as out-of-domain without removing them." |
| `surveytidy_error_subset_empty_result` | All rows removed after physical join | Physical only |

---

## VII. `right_join.survey_base` and `full_join.survey_base`

Both functions error unconditionally (when `x` is a survey object) because
they can add rows from `y` that have no survey match. Those new rows would
have `NA` for all design variables, producing an invalid design object.

### Signatures

```r
right_join.survey_base(x, y, ...)
full_join.survey_base(x, y, ...)
```

### Behavior

Both methods check that `y` is not a survey object (same guard as elsewhere),
then error immediately with `surveytidy_error_join_adds_rows`.

### Error table

| Class | Trigger | Message template |
|-------|---------|-----------------|
| `surveytidy_error_join_survey_to_survey` | `y` is a survey object | Same as `left_join`. |
| `surveytidy_error_join_adds_rows` | Any call to `right_join` or `full_join` on a survey | `"x"`: "`{fn}()` would add rows from `y` that have no match in the survey." / `"i"`: "New rows would have `NA` for all design variables (weights, strata, PSU), producing an invalid design object." / `"v"`: "Use `left_join()` to add lookup columns from `y`, or `filter()` / `semi_join()` to restrict the survey domain." |

The `{fn}` placeholder is filled by the calling function name
(`"right_join"` or `"full_join"`).

---

## VIII. `bind_rows` (survey object involved)

`bind_rows` errors unconditionally whenever at least one argument is a survey
object. The combined object would require a new design specification (e.g., a
new survey-wave stratum). There is no valid default behavior.

### Behavior

`bind_rows.survey_base(x, ...)` checks `S7::S7_inherits(x, surveycore::survey_base)`
and errors with `surveytidy_error_bind_rows_survey`.

> ⚠️ **GAP-6:** dplyr's `bind_rows()` generic has a different dispatch
> mechanism than other join functions. It uses `vctrs::vec_rbind()` internally
> in recent dplyr versions. Verify that registering
> `registerS3method("bind_rows", "surveycore::survey_base", ...)` is sufficient
> to intercept the call when `x` is the first argument. If not, the alternative
> is to intercept via `dplyr_reconstruct` or via a `.onLoad` hook on the
> generic. This must be verified during implementation.

> ⚠️ **Known limitation:** If the survey object is passed as a **non-first**
> argument (e.g., `dplyr::bind_rows(df, survey)`), S3 dispatch is based on
> `class(df)` (a plain data frame) and `bind_rows.survey_base` will not be
> called. The call completes silently, producing an invalid plain data frame
> with NA design variables merged in. This case is out of scope for this spec.
> Document the limitation in the roxygen `@details` section with a note that
> the survey object must always be the first argument to `bind_rows()`.

### Error table

| Class | Trigger | Message template |
|-------|---------|-----------------|
| `surveytidy_error_bind_rows_survey` | Any call to `bind_rows()` with a survey object | `"x"`: "`bind_rows()` cannot stack survey design objects." / `"i"`: "Stacking two surveys changes the design — the combined object requires a new design specification." / `"v"`: "Extract `@data` from each survey object with `survey_data()`, bind the raw data frames with `dplyr::bind_rows()`, then re-specify the combined design with `surveycore::as_survey()`." |

---

## IX. Survey × Survey Joins

All join functions error when both `x` and `y` are survey objects. The one
narrow exception (joining two surveys over the same sample to combine variable
sets) requires manual validation that surveytidy cannot perform automatically.

**Guard placement:** Every join function checks `y` with
`S7::S7_inherits(y, surveycore::survey_base)` as its **first** action.

Error class: `surveytidy_error_join_survey_to_survey` (same class for all
eight functions; message can vary by function).

---

## X. Twophase Edge Cases

`survey_twophase` has a two-tier row structure: all rows in `@data`, but only
`subset == TRUE` rows are in phase 2. This creates stricter requirements:

| Function | Twophase behavior |
|---|---|
| `left_join` | Safe — no rows added or removed |
| `semi_join` | Safe — domain mask only, same as taylor/replicate |
| `anti_join` | Safe — domain mask only |
| `bind_cols` | Safe — no rows added or removed |
| `inner_join` | Domain-aware mode (`.domain_aware = TRUE`, default): safe — same as taylor/replicate, domain mask only. Physical mode (`.domain_aware = FALSE`): **Error** (`surveytidy_error_join_twophase_row_removal`) — physical row removal can orphan phase2 rows or corrupt the phase1 sample frame |
| `right_join` | Error (same as for all designs) |
| `full_join` | Error (same as for all designs) |
| `bind_rows` | Error (same as for all designs) |

The twophase check for `inner_join` must come **after** the survey-to-survey
check and **before** the join itself.

---

## XI. Metadata, `visible_vars`, and `@groups` Handling

| Property | `left_join` | `inner_join` (domain-aware, default) | `inner_join` (physical, `.domain_aware=FALSE`) | `semi_join` / `anti_join` | `bind_cols` |
|---|---|---|---|---|---|
| `@metadata@variable_labels` | New cols get no labels; existing keys for suffix-renamed cols updated to new name | New cols get no labels; suffix-renamed keys updated (same as left_join) | Unchanged | Unchanged | New cols get no labels |
| `@metadata@transformations` | Unchanged | Unchanged | Unchanged | Unchanged | Unchanged |
| `visible_vars` | Append new col names if set; update any suffix-renamed col names | Append new col names if set | No change (row op) | Unchanged | Append new col names if set |
| `@groups` | Preserved from `x` | Preserved from `x` | Preserved from `x` | Preserved from `x` | Preserved from `x` |
| `..surveycore_domain..` | Unchanged | Updated (ANDed with match mask) | Surviving rows keep prior domain values; removed rows gone | Updated (ANDed with mask) | Unchanged |

---

## XII. Testing

### Test file

```
tests/testthat/test-joins.R
```

### Test sections (template)

```
# 1.  left_join() — adds columns from y; survey rows preserved (3 designs)
#     Assert: new column names absent from result@metadata@variable_labels
# 2.  left_join() — visible_vars extended when set
# 3.  left_join() — visible_vars unchanged when NULL
# 4.  left_join() — design variable column in y → warns + dropped
# 5.  left_join() — duplicate keys in y → row expansion error
# 6.  left_join() — y is a survey → error
# 7.  left_join() — domain column preserved unchanged
# 7b. left_join() — suffix rename: @metadata key and visible_vars entry updated when x and y share a non-design column name
# 8.  left_join() — @groups preserved

# 9.  semi_join() — marks unmatched rows as out-of-domain; no new cols (3 designs)
#     Assert: @variables$domain sentinel appended (type = "semi_join", keys = resolved_by)
#     Assert: @groups preserved
#     Assert: when called on a design with visible_vars set, result@variables$visible_vars is identical to original
# 10. semi_join() — ANDs with existing domain
# 11. semi_join() — all rows unmatched → surveycore_warning_empty_domain
# 12. semi_join() — duplicate keys in y collapse to single TRUE (no row expansion)
# 12b. anti_join() — duplicate keys in y collapse to single FALSE per survey row
# 13. semi_join() — y is a survey → error
# 13b. semi_join() — x@data already has "..surveytidy_row_index.." → surveytidy_error_reserved_col_name
#      Dual pattern: expect_error(class=) + expect_snapshot(error=TRUE)
# 13c. anti_join() — x@data already has "..surveytidy_row_index.." → surveytidy_error_reserved_col_name
#      Dual pattern: expect_error(class=) + expect_snapshot(error=TRUE)

# 14. anti_join() — marks matched rows as out-of-domain; no new cols (3 designs)
#     Assert: @variables$domain sentinel appended (type = "anti_join", keys = resolved_by)
#     Assert: @groups preserved
#     Assert: when called on a design with visible_vars set, result@variables$visible_vars is identical to original
# 15. anti_join() — ANDs with existing domain
# 16. anti_join() — all rows matched → surveycore_warning_empty_domain
# 17. anti_join() — y is a survey → error

# 18. bind_cols() — adds columns by position; row count unchanged (3 designs)
#     Assert: @groups preserved
#     Assert: new column names absent from result@metadata@variable_labels
# 19. bind_cols() — visible_vars extended when set
# 20. bind_cols() — row mismatch → error
# 21. bind_cols() — design variable column in ... → warns + dropped
# 22. bind_cols() — ... contains a survey → error

# 23. inner_join() [domain-aware, default] — unmatched rows out-of-domain; new cols appended; row count unchanged (3 designs)
#     Assert: @variables$domain sentinel appended (type = "inner_join", keys = resolved_by)
#     Assert: @groups preserved
#     Assert: new column names absent from result@metadata@variable_labels
# 23b. inner_join() [domain-aware] — ANDs with existing domain
# 23c. inner_join() [domain-aware] — all rows unmatched → surveycore_warning_empty_domain
# 23d. inner_join() [domain-aware] — duplicate keys in y collapse to single TRUE per survey row

# 24. inner_join(.domain_aware=FALSE) — removes unmatched rows + warns (taylor, replicate)
#     Assert: result@variables$visible_vars is identical to original (use d created with select() first)
# 24b. inner_join(.domain_aware=FALSE) — twophase → error (surveytidy_error_join_twophase_row_removal)
# 24c. inner_join(.domain_aware=FALSE) — all rows removed → surveytidy_error_subset_empty_result
# 24d. inner_join(.domain_aware=FALSE) — duplicate keys in y → surveytidy_error_join_row_expansion

# 25. inner_join() — y is a survey → error (both modes)
# 26. inner_join() — design variable column in y → warns + dropped (both modes)

# 27. right_join() — always errors (surveytidy_error_join_adds_rows)
#     Dual pattern: expect_error(class=) + expect_snapshot(error=TRUE)
#     Snapshot verifies {fn} = "right_join" in the message
# 28. full_join()  — always errors (surveytidy_error_join_adds_rows)
#     Dual pattern: expect_error(class=) + expect_snapshot(error=TRUE)
#     Snapshot verifies {fn} = "full_join" in the message

# 29. bind_rows()  — always errors (surveytidy_error_bind_rows_survey)

# 30. All survey × survey combinations → surveytidy_error_join_survey_to_survey
#     (one test per function, or parametrized loop)
```

### Cross-design loop requirement

Tests 1–8, 9–13, 14–17, 18–22, 23–24d must loop over all three designs via
`make_all_designs()`. Exceptions:
- Tests 24b (twophase-specific error for physical mode) uses only `designs$twophase`.
- Tests 25–26 (error-only behaviors) do not require cross-design looping.
- Tests 27–30 (error-only) do not require cross-design looping — a single
  design is sufficient to verify the error behavior.

### `test_invariants()` requirement

Every test block that produces a survey object (not an error) must call
`test_invariants(result)` as its **first** assertion, per
`testing-surveytidy.md`.

### Dual error pattern

All user-facing errors use the dual pattern per `testing-surveytidy.md`:

```r
# 1. typed class check
expect_error(left_join(d, y_dup), class = "surveytidy_error_join_row_expansion")
# 2. snapshot
expect_snapshot(error = TRUE, left_join(d, y_dup))
```

### Edge case table

| Edge case | Expected behavior |
|-----------|------------------|
| `y` has 0 rows | `left_join`: no new rows; all survey rows kept. `semi_join`: all rows out-of-domain (empty domain warning). `anti_join`: no rows removed from domain. |
| `y` has 0 columns | `left_join`: no new columns; survey unchanged. `bind_cols`: same. |
| `by` explicitly provided | Forwarded correctly to dplyr. |
| `by` = `NULL` (common column inference) | Forwarded correctly; common column used as key. |
| Duplicate keys in `y` for `semi_join` | Collapses to single `TRUE` per survey row — no domain expansion. |
| Duplicate keys in `y` for `anti_join` | Collapses to single `FALSE` per survey row — symmetric with `semi_join`. |
| Domain column already exists before `semi_join` | ANDed correctly with existing domain. |
| `visible_vars` is `NULL` before join | Stays `NULL` after join (do not create it from scratch). |
| `visible_vars` is set before join | New columns appended. |
| Survey has `@groups` set | `@groups` preserved through all joins. |

---

## XIII. Quality Gates

All of the following must be true before the feature branch may be merged:

- [ ] `devtools::check()`: 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::test()`: 0 failures, 0 skips
- [ ] Coverage ≥ 98% on `R/joins.R`
- [ ] All GAPs (GAP-1 through GAP-6) resolved and logged in `plans/decisions-joins.md`
- [ ] `plans/error-messages.md` updated with all new error and warning classes
  from §III–VIII
- [ ] `R/zzz.R` updated with `registerS3method()` calls for all eight functions
- [ ] `R/joins.R` formatted with `air format R/joins.R`
- [ ] All `@examples` run without error under `R CMD check` (each example
  block begins with `library(dplyr)` per CLAUDE.md)
- [ ] `bind_rows` dispatch mechanism verified (GAP-6)

---

## XIV. Integration Contracts

### With `dplyr`

All eight functions are dplyr generics. Methods are registered in `.onLoad()`
with `asNamespace("dplyr")` as the envir. surveytidy requires `dplyr (>= 1.1.0)`
in DESCRIPTION; no version bump needed.

### With `surveycore`

- `surveycore::survey_base` — used in `S7::S7_inherits()` guards
- `surveycore::survey_twophase` — used in the `inner_join` twophase guard
- `surveycore::SURVEYCORE_DOMAIN_COL` — domain column name constant
- `surveycore::.get_design_vars_flat(design)` — flat vector of design column
  names; used in `.check_join_col_conflict()` to identify protected columns

### With `R/utils.R`

- `dplyr_reconstruct.survey_base` (already defined) — backstop for pipeline
  chaining; no changes required
- `.warn_physical_subset()` (if this helper exists in utils.R) — used by
  `inner_join` to emit the physical-subset warning consistently

---

## XV. New Error and Warning Classes

All classes below must be added to `plans/error-messages.md` before
implementation. Source file will be `R/joins.R` for all.

| Class | Trigger |
|-------|---------|
| `surveytidy_error_join_survey_to_survey` | `y` is a survey object in any join |
| `surveytidy_error_join_adds_rows` | `right_join` or `full_join` on a survey |
| `surveytidy_error_join_row_expansion` | `left_join` or `inner_join(.domain_aware = FALSE)` where `y` has duplicate keys → row count would increase |
| `surveytidy_error_join_twophase_row_removal` | `inner_join` on a `survey_twophase` |
| `surveytidy_error_bind_rows_survey` | `bind_rows` with a survey on either side |
| `surveytidy_error_bind_cols_row_mismatch` | `bind_cols` where row counts differ |
| `surveytidy_warning_join_col_conflict` | `y` has column names matching design variables |

Re-used classes (no new entry needed):
- `surveycore_warning_physical_subset` — `inner_join(.domain_aware = FALSE)` physical removal
- `surveycore_warning_empty_domain` — `semi_join`, `anti_join`, or `inner_join(.domain_aware = TRUE)` empties domain
- `surveytidy_error_subset_empty_result` — `inner_join(.domain_aware = FALSE)` removes all rows

---

## XVI. GAPs Summary

| # | Section | Question | Status |
|---|---------|----------|--------|
| GAP-1 | §VI | `inner_join`: physical subset (Option A) vs. domain-aware (Option B)? | **Resolved** — two-mode design: default domain-aware (`.domain_aware = TRUE`); physical subset opt-in via `.domain_aware = FALSE` |
| GAP-2 | §III | `left_join` one-to-many keys: error (current plan) or warn + allow? | **Resolved** — error |
| GAP-3 | §IV | `semi_join`/`anti_join`: emit informational message or stay silent? | **Resolved** — silent, consistent with `filter()` |
| GAP-4 | §IV | Masking implementation: reliable row-index approach to be specified | **Resolved** — row-index column `"..surveytidy_row_index.."` approach fully specified in §IV Step 2 |
| GAP-5 | §IV | `@variables$domain` after `semi_join`/`anti_join`: update or leave as-is? | **Resolved** — append typed S3 sentinel (`class = "surveytidy_join_domain"`) via `.new_join_domain_sentinel(type, keys)` |
| GAP-6 | §VIII | `bind_rows` dispatch: does `registerS3method` intercept correctly? | **Open** — implementation detail; verify during implementation |
