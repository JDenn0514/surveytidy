# Formal Specification: Deduplication, Programmatic Renaming, and Row-Wise Operations

**Version:** 1.0
**Date:** 2026-02-24
**Status:** Approved — ready for implementation

This document is the authoritative specification for the surveytidy phase that
adds `distinct()`, `rename_with()`, and `rowwise()` to the verb surface. Every
verb's signature, behavior contract, error/warning classes, and implementation
notes are defined here. Implementation must satisfy every contract listed; the
quality gates in Section VII define "done."

---

## I. Scope

### I.1 What This Phase Delivers

| Verb | File | Description |
|------|------|-------------|
| `distinct()` | `R/distinct.R` | Physical row deduplication with physical-subset warning |
| `rename_with()` | `R/rename.R` | Function-based column renaming; shares helper with `rename()` |
| `rowwise()` | `R/rowwise.R` | Row-wise computation mode; stored in `@variables$rowwise` |

**Internal refactor (shipped with `rename_with`):**
Extract `.apply_rename_map(design, rename_map)` from `rename.survey_base()` so
`rename()` and `rename_with()` share the atomic-update logic. No behavioral
change to `rename()`.

**`mutate()` change (shipped with `rowwise`):**
`mutate.survey_base()` updated to detect `@variables$rowwise` and route to
`dplyr::rowwise()` for row-by-row computation.

### I.2 Out of Scope

| Deferred | Reason |
|----------|--------|
| `summarise()` / `reframe()` | Phase 1: requires survey-weighted estimation |
| `count()` / `tally()` | Phase 1 scope |
| `add_row()` / `bind_rows()` | Design-merge semantics: future phase |
| `*_join()` verbs | Future phase |
| `rowwise()` + `summarise()` pipeline | `summarise()` deferred; rowwise only powers `mutate()` here |
| Vector recoding functions (`if_else`, `case_when`, etc.) | Future phase requiring metadata design |
| Survey-specific recoding (`make_dicho`, `make_factor`) | Depends on vector function metadata design |

### I.3 Design Support Matrix

All three verbs must work with all three design types.

| Verb | `survey_taylor` | `survey_replicate` | `survey_twophase` |
|------|:---:|:---:|:---:|
| `distinct()` | ✓ | ✓ | ✓ |
| `rename_with()` | ✓ | ✓ | ✓ |
| `rowwise()` | ✓ | ✓ | ✓ |

### I.4 What "Complete" Means

All verbs implemented, fully tested, and the package passes every quality gate
in Section VII. The `rowwise` branch ships mutate() changes alongside the new
verb.

---

## II. Architecture

### II.1 File Organisation

```
R/
  distinct.R         # NEW — distinct.survey_base()
  rename.R           # MODIFIED — extract .apply_rename_map(); add rename_with.survey_base()
  rowwise.R          # NEW — rowwise.survey_base(); is_rowwise(); is_grouped()
  mutate.R           # MODIFIED — detect @variables$rowwise; route to dplyr::rowwise()
  group-by.R         # MODIFIED — group_vars.survey_base(); group_by() rowwise-exit logic
  reexports.R        # MODIFIED — add dplyr::distinct, dplyr::rename_with, dplyr::rowwise, dplyr::group_vars
  zzz.R              # MODIFIED — register distinct, rename_with, rowwise, group_vars
  utils.R            # .apply_rename_map() lives in rename.R (used only there)

tests/testthat/
  test-distinct.R    # NEW
  test-rename.R      # MODIFIED — add rename_with() test blocks
  test-rowwise.R     # NEW — rowwise() + mutate() rowwise behaviour
```

### II.2 Inherited Shared Contracts

The following contracts from Phase 0.5 apply to every verb without exception.
They are not repeated here; this spec references them by section.

| Contract | Phase 0.5 ref |
|----------|--------------|
| Five formal invariants + `test_invariants()` | §2.1 |
| Protected columns (`.protected_cols()`) | §2.2 |
| `@groups` propagation | §2.3 |
| `@metadata` propagation rules | §2.4 |
| `visible_vars` contract | §2.5 |
| `@variables$domain` quosures are audit-only | §2.6 |
| S3 dispatch pattern (`registerS3method`) | §2.7 |

### II.3 New Shared Helper: `.apply_rename_map()`

Extracted from the current `rename.survey_base()` implementation. Lives in
`R/rename.R` (used by both `rename()` and `rename_with()` in the same file).

**Signature:**
```r
.apply_rename_map <- function(.data, rename_map)
```

**Arguments:**
- `.data` — survey_base object
- `rename_map` — named character vector; `names` are old column names, `values`
  are new column names (same convention as the existing `rename.survey_base()`
  internal `rename_map`)

**Contract:**
1. Warns with `surveytidy_warning_rename_design_var` if any old name is a
   protected column. The message does not name the calling function (shared
   helper called by both `rename()` and `rename_with()`). Template:
   ```r
   cli::cli_warn(
     c(
       "!" = "Renamed design variable{?s} {.field {design_cols}}.",
       "i" = "The survey design has been updated to track the new name{?s}."
     ),
     class = "surveytidy_warning_rename_design_var"
   )
   ```
   where `design_cols` is the subset of renamed columns that are protected.
   The existing `_snaps/rename.md` snapshot will change because the current
   message text includes `"rename()"`. Update the snapshot on the
   `feature/rename-with` branch.
1.5. **Domain column is never renamed.** If `SURVEYCORE_DOMAIN_COL`
   (`"..surveycore_domain.."`) appears in the rename map, it is silently
   removed from the map before any renaming occurs, and
   `surveytidy_warning_rename_design_var` is issued. The domain column has a
   fixed identity used by `filter()` and estimation; renaming it would silently
   break those verbs. This differs from regular design variables (strata, PSU,
   weights), which are warned about but still renamed because users may
   legitimately rename their own columns.
2. Atomically updates `@data` column names, `@variables` (via
   `.sc_update_design_var_names()`), `@metadata` (via
   `.sc_rename_metadata_keys()`), and `visible_vars` within `@variables`.
3. Calls `S7::validate(.data)` once at the end.
4. Returns the modified `.data` object.

**What does NOT change:** `@variables` (design spec keys unrelated to rename) — passed through unchanged.

**Additional update (bullet 2.5):** If any renamed column appears in `@groups`, the old name is replaced with the new name in `@groups`. This keeps `@groups` consistent with the renamed column names in `@data`.

### II.4 Rowwise State Storage

Rowwise mode is stored in two keys of `@variables` — the same free-form list
that holds `domain`, `visible_vars`, and other surveytidy-managed metadata.
No surveycore changes are required.

| Key | Type | Meaning |
|-----|------|---------|
| `@variables$rowwise` | logical `TRUE` | Present and `TRUE` when the design is in rowwise mode; `NULL` otherwise |
| `@variables$rowwise_id_cols` | character vector | Id columns passed to `rowwise()` via `...`; `character(0)` if none were given |

Both keys are absent (NULL) by default. `rowwise()` sets them; `ungroup()`
(full ungroup) and `group_by()` clear them when exiting rowwise mode.

`@groups` is **never** modified by `rowwise()`. It continues to hold only
real grouping column names. This means `group_vars()`, `is_grouped()`, and
`arrange(.by_group = TRUE)` require no changes — they read `@groups` directly
without any sentinel-stripping logic.

---

## III. `distinct()`

### III.1 Signature and Arguments

```r
distinct.survey_base(.data, ..., .keep_all = FALSE)
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `.data` | `survey_base` | — | Survey design object |
| `...` | data-masking | — | Columns used to determine uniqueness. If empty, all non-design columns are used. |
| `.keep_all` | logical scalar | `FALSE` | Accepted for interface compatibility; **has no effect** — the survey implementation always retains all columns in `@data`. See §III.3. |

### III.2 Output Contract

| Property | Change |
|----------|--------|
| Rows | Physically reduced to distinct subset; fewer rows possible |
| `@data` columns | **Unchanged** — all columns retained regardless of `...` or `.keep_all` |
| `@variables$visible_vars` | **Unchanged** — distinct is a pure row operation |
| `@variables` (design spec) | Unchanged |
| `@metadata` | Unchanged — row operation; per Phase 0.5 §2.4 |
| `@groups` | Unchanged — passed through |
| Warning | Always issues `surveycore_warning_physical_subset` |
| Return value | Visibly returned (consistent with all dplyr verbs) |

### III.3 Behavior Rules

1. **Always warns** with `surveycore_warning_physical_subset` before performing
   the operation.

2. **Pure row operation.** `distinct()` decides which rows to keep; it never
   changes which columns exist in `@data` or which columns are shown via
   `visible_vars`. This differs from `dplyr::distinct(df, x, y)` which by
   default returns only `x` and `y` — see design note below.

3. **Internal call:** Always calls with `.keep_all = TRUE` so that design
   variables are never lost. When `...` is non-empty, the call is:
   ```r
   dplyr::distinct(.data@data, ..., .keep_all = TRUE)
   ```
   When `...` is **empty**, deduplicate on non-design columns only:
   ```r
   non_design <- setdiff(names(.data@data), .protected_cols(.data))
   dplyr::distinct(.data@data, dplyr::across(dplyr::all_of(non_design)), .keep_all = TRUE)
   ```
   This ensures the default (`distinct(d)`) deduplicates on substantive
   variables, not on design variables (strata, PSU, weights) that would
   produce meaningless or survey-corrupting deduplication. The `.keep_all = FALSE`
   user argument is silently ignored in both paths.

4. **Column specification in `...`:** Controls which columns determine
   uniqueness — it does NOT control which columns appear in the result. This
   is a deliberate divergence from base dplyr's `.keep_all = FALSE` behaviour.

5. **Warns when `...` resolves to include protected columns.** If any column
   in `...` is a design variable (strata, PSU, weights, FPC, repweights, or
   the domain column), issue `surveytidy_warning_distinct_design_var` before
   performing the operation. Deduplicating by a design variable may silently
   corrupt variance estimation (e.g. `distinct(d, strata)` removes PSUs
   needed for SE calculation). The operation still proceeds after the warning.

6. **`@groups` passed through unchanged** (Phase 0.5 §2.3).

7. **Domain column preserved** — because `@data` columns are unchanged,
   `..surveycore_domain..` (if present) survives unchanged.

Note: `distinct(d, x, y)` retains all columns in `@data` (not just `x` and
`y`) and does not update `visible_vars`. This is a deliberate divergence from
`dplyr::distinct(df, x, y)` — `distinct()` is a pure row operation; it does
not touch column display state.

### III.4 Error and Warning Table

| Class | Type | Trigger |
|-------|------|---------|
| `surveycore_warning_physical_subset` | warning | Always — issued before row removal |
| `surveytidy_warning_distinct_design_var` | warning | Any column in `...` is a protected design variable |

No new error classes. A 0-row result after `distinct()` is impossible from a
non-empty input (at minimum, one row is always the unique representative of
itself).

**Message templates:**
```r
# Always issued
.warn_physical_subset("distinct")

# When ... resolves to include a design variable
cli::cli_warn(
  c(
    "!" = "Deduplicating by design variable{?s} {.field {design_vars}} may corrupt variance estimation.",
    "i" = "Design variables define the sampling structure; removing rows that share design variable values can invalidate standard error calculations.",
    "i" = "Use {.code distinct(d)} without specifying design variables, or use {.fn subset} if physical row removal is intentional."
  ),
  class = "surveytidy_warning_distinct_design_var"
)
```

---

## IV. `rename_with()`

### IV.1 rename.R Refactor — Prerequisites

Before adding `rename_with()`, extract `.apply_rename_map()` from
`rename.survey_base()`. The current atomic-update block (Steps 3–6 in
`rename.survey_base()`) becomes the body of `.apply_rename_map()`.

After refactor, `rename.survey_base()` is:

```r
rename.survey_base <- function(.data, ...) {
  map <- tidyselect::eval_rename(rlang::expr(c(...)), .data@data)
  new_names  <- names(map)
  old_names  <- names(.data@data)[map]
  rename_map <- stats::setNames(new_names, old_names)
  .apply_rename_map(.data, rename_map)
}
```

**Behavioral changes introduced by this refactor (not present in current `rename.survey_base()`):**

1. **`@groups` update (new behaviour):** `.apply_rename_map()` replaces renamed
   column names in `@groups` (§II.3 bullet 2.5). Current `rename()` never
   touches `@groups`. After refactor, renaming a grouped column also updates
   `@groups`.

2. **Domain column protection (new behaviour):** `.apply_rename_map()` removes
   `SURVEYCORE_DOMAIN_COL` from the rename map and warns
   (`surveytidy_warning_rename_design_var`) if the user attempts to rename it
   (§II.3 bullet 1.5). Current `rename()` would warn but still rename the
   domain column. After refactor, the rename is blocked.

3. **Warning message text change (snapshot regression):** The current warning
   is issued inside `rename.survey_base()` and uses `"rename()"` in the
   message text. After refactor, the warning is issued inside
   `.apply_rename_map()` — a shared helper that cannot hardcode `"rename()"`.
   This changes the warning text, which will break the existing
   `_snaps/rename.md` snapshot in CI. The snapshot must be reviewed and
   updated as part of the `feature/rename-with` branch before merge.

Must have passing tests (including updated snapshots) before `rename_with()`
is implemented on the same branch.

### IV.2 Signature and Arguments

```r
rename_with.survey_base(.data, .fn, .cols = dplyr::everything(), ...)
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `.data` | `survey_base` | — | Survey design object |
| `.fn` | function | — | A function applied to selected column names. Must accept a character vector and return a character vector of the same length. |
| `.cols` | tidy-select | `dplyr::everything()` | Columns whose names `.fn` will transform. Defaults to all columns. |
| `...` | — | — | Additional arguments passed to `.fn`. |

### IV.3 Output Contract

| Property | Change |
|----------|--------|
| Rows | Unchanged |
| `@data` columns | Renamed per `.fn(.cols)` |
| `@variables` (design spec) | Updated if renamed cols are design variables |
| `@metadata` | Keys renamed across all slots |
| `@variables$visible_vars` | Old names replaced with new names |
| `@groups` | Old names replaced with new names if any renamed col was in `@groups` |
| Warning | `surveytidy_warning_rename_design_var` if any renamed col is a design var |
| Return value | Visibly returned (consistent with all dplyr verbs) |

### IV.4 Behavior Rules

1. **Resolve `.cols`** using `tidyselect::eval_select(rlang::expr(.cols), .data@data)`.
   This returns a named integer vector where names are the selected column names
   and values are their positions. Extract `old_names <- names(selected)`.
   Note: `eval_rename()` is used by `rename()` for `new = old` syntax and must
   not be used here — `.cols` is a selection expression, not a rename spec.

2. **Apply `.fn`** to the resolved column name vector using:
   ```r
   .fn       <- rlang::as_function(.fn)   # supports bare fns, ~formula, \(x) lambdas
   new_names <- rlang::exec(.fn, old_names, !!!rlang::list2(...))
   ```
   `rlang::as_function()` converts formula/lambda syntax so users can write
   `rename_with(d, ~ toupper(.))` or `rename_with(d, \(x) toupper(x))` as well
   as bare functions. `rlang::exec()` with `!!!rlang::list2(...)` forwards any
   additional `...` arguments to `.fn` (e.g. `rename_with(d, str_replace, pattern = "y", replacement = "Y")`).

2.5. The result `new_names` must be a character vector of the same length as
   `old_names`, with no duplicates and no conflicts with existing (non-renamed)
   column names. Validation is in Rule 6.

3. **Build `rename_map`**: `stats::setNames(new_names, old_names)`.

4. **Delegate to `.apply_rename_map(.data, rename_map)`** for the atomic update.

5. **`@groups` updated when renamed cols are in `@groups`.** `.apply_rename_map()` replaces any old name that appears in `@groups` with its new name. This also fixes the same latent bug in `rename()`, which shares the helper.

6. **Error on bad `.fn` output**: raise `surveytidy_error_rename_fn_bad_output`
   if any of the following are true:
   - `.fn` returns a non-character vector (`!is.character(new_names)`)
   - `.fn` returns a vector of the wrong length (`length(new_names) != length(old_names)`)
   - `.fn` returns duplicate names (`anyDuplicated(new_names) > 0`)
   - `.fn` returns names that conflict with existing non-renamed column names

### IV.5 Error and Warning Table

| Class | Type | Trigger | Message template |
|-------|------|---------|-----------------|
| `surveytidy_warning_rename_design_var` | warning | Any renamed column is a protected design variable | (reuses existing class from `rename()`) |
| `surveytidy_error_rename_fn_bad_output` | error | `.fn` returns non-character output, wrong-length vector, duplicate names, or names conflicting with existing columns | `"x"` = `.fn` must return a character vector of the same length as its input with no duplicates.; `"i"` = Context-specific: class of output, length mismatch, or duplicate/conflicting name.; `"v"` = Check that `.fn` returns a plain character vector and handles all column names uniformly. |

---

## V. `rowwise()`

### V.1 Signature and Arguments

```r
rowwise.survey_base(data, ...)
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `survey_base` | — | Survey design object. Note: dplyr uses `data` (not `.data`) for `rowwise()`. |
| `...` | tidy-select | — | Optional id columns: columns that identify rows for use with `dplyr::c_across()`. Commonly omitted. |

### V.2 Storage: `@variables$rowwise`

Rowwise mode is stored in `@variables`, not in `@groups` (see §II.4):

- When `rowwise(data)` is called with no `...`:
  - `data@variables$rowwise <- TRUE`
  - `data@variables$rowwise_id_cols <- character(0)`
- When `rowwise(data, id1, id2)` is called:
  - `data@variables$rowwise <- TRUE`
  - `data@variables$rowwise_id_cols <- c("id1", "id2")`
- `@groups` is **unchanged** — `rowwise()` never touches `@groups`.

**Detection:** `isTRUE(.data@variables$rowwise)`

**Exit via `ungroup()` (full):** `ungroup(data)` clears `@groups` (existing
behaviour) AND clears `@variables$rowwise` and `@variables$rowwise_id_cols`
by setting them to `NULL`.

**Exit via `ungroup()` (partial):** `ungroup(data, some_col)` removes
`some_col` from `@groups` but does NOT clear `@variables$rowwise` — rowwise
mode persists. This matches dplyr's `ungroup(rowwise_df, some_col)`.

**Exit via `group_by(.add = FALSE)`:** `group_by(data, ...)` (default)
replaces `@groups` with the new groups AND clears `@variables$rowwise` and
`@variables$rowwise_id_cols`. Existing `group_by()` replaces `@groups`;
the only new behaviour is clearing the rowwise keys.

**Exit via `group_by(.add = TRUE)`:** Mirrors dplyr exactly. dplyr's
`group_by(.add = TRUE)` on a `rowwise_df` promotes the rowwise id columns
to regular group keys, then appends the new groups. For surveytidy:
```r
# If currently rowwise, promote id_cols → @groups first, then add new groups
base_groups <- .data@variables$rowwise_id_cols %||% character(0)
.data@variables$rowwise          <- NULL
.data@variables$rowwise_id_cols  <- NULL
.data@groups <- unique(c(base_groups, group_names))
```
Example: `rowwise(d, id) |> group_by(region, .add = TRUE)` →
`@groups = c("id", "region")`, rowwise keys cleared.

If not in rowwise mode, `.add = TRUE` behaves as before:
`@groups <- unique(c(.data@groups, group_names))`.

### V.3 Output Contract

| Property | Change |
|----------|--------|
| Rows | Unchanged |
| `@data` columns | Unchanged |
| `@variables` | `@variables$rowwise` set to `TRUE`; `@variables$rowwise_id_cols` set to resolved id_cols (or `character(0)`) |
| `@metadata` | Unchanged |
| `@groups` | **Unchanged** — `rowwise()` does not modify `@groups` |
| Return value | Modified survey object (visibly returned) |

### V.4 Behavior Rules

1. **Resolve id_cols** from `...` using `tidyselect::eval_select(rlang::expr(c(...)), data@data)`.
   If `...` is empty, `id_cols` is `character(0)`.

2. **Set `@variables$rowwise <- TRUE`** and
   **`@variables$rowwise_id_cols <- id_cols`**. This replaces any existing
   rowwise state. `@groups` is NOT modified — calling `rowwise()` on a
   grouped design does not clear the groups. Rowwise and grouped modes are
   treated as independent; however, `mutate()` checks rowwise first.

3. **Returns visibly** (consistent with all dplyr verbs, per Phase 0.5 §return
   visibility).

4. **Does not validate id_cols** against design variables — any column (including
   design vars) is allowed as an id column, matching dplyr's permissive behaviour.

### V.5 Required Changes to `mutate.survey_base()`

`mutate.survey_base()` currently determines grouping via:

```r
effective_by <- if (is.null(.by) && length(.data@groups) > 0L) {
  .data@groups
} else {
  .by
}
```

This must be updated to detect rowwise mode and exclude the sentinel from
`effective_by`. The new logic:

```r
is_rowwise  <- isTRUE(.data@variables$rowwise)
id_cols     <- .data@variables$rowwise_id_cols %||% character(0)
group_names <- .data@groups

if (is_rowwise) {
  # Route to dplyr::rowwise() — effective_by is not used in this branch
  effective_by <- NULL
  base_data <- if (length(id_cols) > 0L) {
    dplyr::rowwise(.data@data, dplyr::all_of(id_cols))
  } else {
    dplyr::rowwise(.data@data)
  }
} else if (is.null(.by) && length(group_names) > 0L) {
  base_data    <- .data@data
  effective_by <- group_names
} else {
  base_data    <- .data@data
  effective_by <- .by
}
```

**Critical change to the `dplyr::mutate()` call:** The existing line that reads
`dplyr::mutate(.data@data, ...)` must be changed to `dplyr::mutate(base_data, ...)`.
In the rowwise branch, `base_data` is the rowwise-wrapped data frame; using
`.data@data` directly would discard the rowwise grouping and produce wrong results.

**Strip `rowwise_df` after mutation (Issue 23 fix):** `dplyr::mutate()` on a
`rowwise_df` returns a `rowwise_df`. If this class is not stripped before
assigning back to `@data`, every subsequent `dplyr::mutate(.data@data, ...)`
in the package will behave row-wise — even after `ungroup()` has cleared
`@variables$rowwise`. Immediately after the `dplyr::mutate(base_data, ...)` call
in the rowwise branch, add:
```r
new_data <- dplyr::ungroup(new_data)
```
This strips the `rowwise_df` class, leaving a plain `tbl_df` / `data.frame`
with the new column appended.

All other `mutate.survey_base()` logic (protected column re-attachment, `.keep`,
`visible_vars` update, `@metadata` update) continues as-is, operating on the
result of `dplyr::mutate(base_data, ...)`.

### V.6 Error and Warning Table

| Class | Type | Trigger |
|-------|------|---------|
| (none new) | — | Column-not-found in `...` is handled by tidyselect with its own error |

No new error or warning classes for `rowwise()`.

### V.7 Public Predicates and Group Accessor

Three exported functions shipped with this phase to support Phase 1 estimation
and user code. All three depend on `ROWWISE_SENTINEL` and live in `R/rowwise.R`
(for `is_rowwise` and `is_grouped`) and `R/group-by.R` (for `group_vars`).

#### `is_rowwise(design)`

```r
is_rowwise <- function(design) {
  isTRUE(design@variables$rowwise)
}
```

| Field | Value |
|-------|-------|
| Signature | `is_rowwise(design)` |
| Returns | Scalar logical |
| Location | `R/rowwise.R` |
| Exported | Yes (`@export`) |

#### `is_grouped(design)`

Returns `TRUE` if the design has real group columns in `@groups`. Because
`@groups` never contains a sentinel, no filtering is required.

```r
is_grouped <- function(design) {
  length(design@groups) > 0L
}
```

| Field | Value |
|-------|-------|
| Signature | `is_grouped(design)` |
| Returns | Scalar logical |
| Location | `R/rowwise.R` |
| Exported | Yes (`@export`) |

Note: a rowwise design with no id cols returns `is_rowwise() = TRUE`,
`is_grouped() = FALSE`. A grouped design returns `is_grouped() = TRUE`,
`is_rowwise() = FALSE`.

#### `group_vars.survey_base(x)`

dplyr generic that returns the real grouping column names. Because `@groups`
contains only real column names (no sentinel), this is a direct read with no
filtering. Phase 1 uses this to get the columns to stratify estimation over.
Registered in `.onLoad()` alongside other dplyr S3 methods.

```r
group_vars.survey_base <- function(x) {
  x@groups
}
```

| Field | Value |
|-------|-------|
| Signature | `group_vars.survey_base(x)` |
| Returns | Character vector (length 0 if no groups) |
| Location | `R/group-by.R` |
| Exported | No — registered via `registerS3method("group_vars", "surveycore::survey_base", ...)` in `zzz.R` |

---

## VI. Testing

### VI.1 Overall Standards

All tests follow `testing-surveytidy.md` standards. Specific requirements:

- `test_invariants(result)` is the **first** assertion in every `test_that()` block.
- Every verb is tested with all three design types via `make_all_designs(seed = N)`.
- Cross-design testing uses a `for (d in designs)` loop.
- Domain column preservation asserted for every verb.
- Error tests use the dual pattern: `expect_error(class=)` + `expect_snapshot(error=TRUE)`.
- Warning tests use `expect_warning()` wrapping the call.

### VI.2 `test-distinct.R`

**Section 1 — Happy path (all three designs):**
- `distinct(d)` reduces rows when duplicates exist; `test_invariants()` passes
- `distinct(d)` on a design with no duplicates returns same row count
- `distinct(d, col1, col2)` deduplicates by specified columns; all columns retained

**Section 2 — Warning is always issued:**
- Every `distinct()` call issues `surveycore_warning_physical_subset`

**Section 3 — Column contract:**
- `names(result@data)` equals `names(original@data)` — no columns removed
- `result@variables$visible_vars` equals original `visible_vars` — not updated
- `expect_identical(result@metadata, original@metadata)` — full metadata object unchanged after `distinct()`

**Section 4 — Domain preservation:**
- Domain column (`SURVEYCORE_DOMAIN_COL`) survives unchanged after `distinct()`
- `distinct()` applied to filtered design preserves domain column

**Section 5 — `@groups` propagation:**
- `@groups` is unchanged after `distinct()` (group-by state passes through)

**Section 6 — Edge cases:**
- Single-row data: `distinct()` returns the one row, issues warning
- All-identical rows: result has exactly 1 row
- Inline edge case data (never add parameters to `make_all_designs()`)

### VI.3 `test-rename.R` (additions for `rename_with()`)

**Section: rename_with() happy paths:**
For each design in `make_all_designs(seed = 42)`:
- `rename_with(d, toupper)` — all non-design columns uppercased; design vars
  uppercased too with `surveytidy_warning_rename_design_var`
- `rename_with(d, toupper, .cols = starts_with("y"))` — only matching cols renamed
- Metadata keys updated for renamed columns
- `visible_vars` old names replaced with new names
- Domain column (`SURVEYCORE_DOMAIN_COL`) is present and unchanged in
  `result@data` after `rename_with(d_filtered, toupper, .cols = starts_with("y"))`
  (filtered design; `.cols` does not include the domain column)

**Section: rename_with() — design var warning:**
For each design in `make_all_designs(seed = 42)`:
- `rename_with(d, toupper)` warns with `surveytidy_warning_rename_design_var`
  when `.cols` resolves to include design variables
- `rename_with(d, toupper, .cols = starts_with("y"))` does NOT warn when
  `.cols` excludes design variables
- `rename_with(d, toupper)` (or any call where `.cols` includes the domain
  column) warns with `surveytidy_warning_rename_design_var` AND leaves
  `SURVEYCORE_DOMAIN_COL` unchanged in `result@data`

**Section: rename_with() — error cases (dual pattern: `expect_error(class=)` + `expect_snapshot(error=TRUE)`):**
For each design in `make_all_designs(seed = 42)`:
- `.fn` returning a non-character vector (e.g. `\(x) seq_along(x)`) → `surveytidy_error_rename_fn_bad_output`
- `.fn` returning wrong-length vector (e.g. `\(x) x[1]`) → `surveytidy_error_rename_fn_bad_output`
- `.fn` returning duplicate names (e.g. `\(x) rep("y1", length(x))`) → `surveytidy_error_rename_fn_bad_output`
- `.fn` returning a name conflicting with an existing non-renamed column (e.g. when `.cols = starts_with("y1")`, `.fn = \(x) "y2"` conflicts with the existing `y2` column) → `surveytidy_error_rename_fn_bad_output`

**Section: rename_with() — @groups staleness:**
For each design in `make_all_designs(seed = 42)`:
- Renaming a column that is in `@groups` updates `@groups` accordingly

**Section: rename.R refactor regression (snapshot-free sanity check):**
For each design in `make_all_designs(seed = 42)`:
- `rename(d, new = old)` still works identically after `.apply_rename_map()`
  extraction (confirm no behavioral change)

### VI.4 `test-rowwise.R`

**Section 1 — rowwise() sets @variables$rowwise correctly (all three designs):**
For each design in `make_all_designs(seed = 42)`:
- `rowwise(d)` → `isTRUE(result@variables$rowwise)`; `result@variables$rowwise_id_cols == character(0)`; `result@groups` unchanged (equals `d@groups`)
- `rowwise(d, group)` (using the `"group"` column from `make_all_designs()`) → `isTRUE(result@variables$rowwise)`; `result@variables$rowwise_id_cols == "group"`
- `test_invariants()` passes after `rowwise()`
- `is_rowwise(rowwise(d))` → `TRUE`
- `is_rowwise(d)` (plain design) → `FALSE`
- `is_grouped(rowwise(d))` → `FALSE` (no real groups)
- `is_grouped(group_by(d, group))` → `TRUE`; `is_rowwise(group_by(d, group))` → `FALSE`
- `group_vars(rowwise(d))` → `character(0)`
- `group_vars(rowwise(d, group))` → `character(0)` (id_cols are in `@variables$rowwise_id_cols`, not `@groups`)
- `group_vars(group_by(d, group))` → `"group"`
- `group_vars(d)` (plain design) → `character(0)`

**Section 2 — rowwise() + mutate() row-wise computation:**
For each design in `make_all_designs(seed = 42)`:
- `test_invariants(result)` is the first assertion
- `rowwise(d) |> mutate(row_max = max(c_across(starts_with("y"))))` → each
  row independently computes max; result is correct row-by-row
- Result has same row count as input
- Design vars preserved in result
- Domain column (`SURVEYCORE_DOMAIN_COL`) is present and unchanged in
  `result@data` (assert using a filtered design so the domain column exists)
- **Vectorization regression test:** `rowwise(d) |> mutate(row_max = max(c_across(starts_with("y")))) |> ungroup() |> mutate(y_mean = mean(y1))` → `y_mean` is the same value in every row (overall mean, vectorized); NOT row-by-row. This verifies that `dplyr::ungroup()` in §V.5 correctly strips the `rowwise_df` class from `@data` so subsequent mutations are vectorized.

**Section 3 — ungroup() exits rowwise mode:**
For each design in `make_all_designs(seed = 42)`:
- `test_invariants(result)` is the first assertion
- `rowwise(d) |> ungroup()` → `is_rowwise(result) == FALSE`; `result@variables$rowwise` is `NULL`; `result@variables$rowwise_id_cols` is `NULL`
- After full ungroup, `mutate()` is no longer row-wise
- **Partial ungroup:** `rowwise(d, group) |> ungroup(group)` → `is_rowwise(result) == TRUE`; `result@variables$rowwise_id_cols == "group"` (partial ungroup targets `@groups`, not `@variables$rowwise_id_cols`); rowwise mode persists; subsequent `mutate()` is still row-wise

**Section 4 — group_by() exits rowwise mode:**
For each design in `make_all_designs(seed = 42)`:
- `test_invariants(result)` is the first assertion
- `rowwise(d) |> group_by(group)` (`.add = FALSE`, default) → `is_rowwise(result) == FALSE`; `result@variables$rowwise` is `NULL`; `result@groups == "group"`
- `rowwise(d) |> group_by(group, .add = TRUE)` → `is_rowwise(result) == FALSE`; `@variables$rowwise` cleared; no id cols to promote; `@groups == "group"`
- `rowwise(d, group) |> group_by(group, .add = TRUE)` → `is_rowwise(result) == FALSE`; id col `"group"` promoted to `@groups`; new group `"group"` appended (deduped); `@groups == "group"` (mirrors dplyr Case 3)
- After any `group_by()`, `mutate()` is no longer row-wise

**Section 5 — rowwise state propagation through other verbs:**
For each design in `make_all_designs(seed = 42)`:
- `test_invariants(result)` is the first assertion
- `rowwise(d) |> filter(y1 > 0)` → `is_rowwise(result) == TRUE`; `@variables$rowwise` preserved
- `rowwise(d) |> select(y1, y2)` → `is_rowwise(result) == TRUE`; `@variables$rowwise` preserved
- `rowwise(d) |> arrange(y1)` → `is_rowwise(result) == TRUE`; `@variables$rowwise` preserved (verifies that `arrange()` does not break rowwise state; no `.by_group = TRUE` issue since `@groups` is unmodified)

**Section 6 — Edge cases:**
For each design in `make_all_designs(seed = 42)`:
- `test_invariants(result)` is the first assertion
- `rowwise(d)` when `@groups` already has groups → `@groups` unchanged; `@variables$rowwise` set (rowwise and grouped are independent; `mutate()` checks rowwise first)
- `rowwise(d)` with non-existent column → tidyselect error (no special handling)

---

## VII. Quality Gates

A branch is ready to merge when ALL of the following pass:

- [ ] `devtools::check()` — 0 errors, 0 warnings, ≤ 2 pre-approved notes
- [ ] `devtools::document()` run; `NAMESPACE` and `man/` in sync with source
- [ ] `devtools::test()` — all tests pass; no skipped tests without justification
- [ ] `covr::package_coverage()` ≥ 98% line coverage
- [ ] `plans/error-messages.md` exists and is up to date (file created as part of this phase's pre-implementation setup)
- [ ] All new and modified R files formatted with `air format .`
- [ ] `R/zzz.R` updated with `registerS3method()` calls for all new verbs
- [ ] Snapshot tests committed and passing (no stale snapshots)
- [ ] All three design types (`survey_taylor`, `survey_replicate`,
     `survey_twophase`) pass in cross-design loops for each new verb

Per-branch specifics:

**`feature/distinct`:**
- [ ] `R/reexports.R` updated with `dplyr::distinct` re-export
- [ ] `distinct.survey_base()` implemented and documented (`@noRd`)
- [ ] `test-distinct.R` covers all six sections in §VI.2
- [ ] `surveycore_warning_physical_subset` issued on every call (tested)
- [ ] `surveytidy_warning_distinct_design_var` issued when `...` includes a design variable (tested)
- [ ] `plans/error-messages.md` updated with `surveytidy_warning_distinct_design_var`

**`feature/rename-with`:**
- [ ] `R/reexports.R` updated with `dplyr::rename_with` re-export
- [ ] `.apply_rename_map()` extracted; `rename.survey_base()` passes regression tests
- [ ] `rename_with.survey_base()` implemented and documented
- [ ] `@groups` updated by `.apply_rename_map()` when renamed cols are in `@groups`
- [ ] `surveytidy_error_rename_fn_bad_output` in error table and tested (dual pattern)
- [ ] `plans/error-messages.md` updated

**`feature/rowwise`:**
- [ ] `R/reexports.R` updated with `dplyr::rowwise` and `dplyr::group_vars` re-exports
- [ ] `rowwise.survey_base()` implemented and documented
- [ ] `is_rowwise(design)` exported from `R/rowwise.R`; tested in §VI.4 Section 1
- [ ] `is_grouped(design)` exported from `R/rowwise.R`; tested in §VI.4 Section 1
- [ ] `group_vars.survey_base()` implemented in `R/group-by.R`; registered in `zzz.R`; tested in §VI.4 Section 1
- [ ] `group_by.survey_base()` `.add = TRUE` sentinel-stripping logic added per §V.2; tested in §VI.4 Section 4
- [ ] `mutate.survey_base()` updated per §V.5; existing mutate tests still pass
- [ ] `test-rowwise.R` covers all sections in §VI.4

---

## VIII. Integration Contracts

### With surveycore

| Contract | Notes |
|----------|-------|
| `surveycore::SURVEYCORE_DOMAIN_COL` | Used in `distinct()` to confirm domain column preservation |
| `surveycore::.get_design_vars_flat()` | Used by `.protected_cols()` (unchanged) |
| `.sc_update_design_var_names()` wrapper | Used by `.apply_rename_map()` |
| `.sc_rename_metadata_keys()` wrapper | Used by `.apply_rename_map()` |

### With Phase 0.5 verbs

| Verb | Interaction |
|------|-------------|
| `rename()` | Refactored to share `.apply_rename_map()`; no behavioral change |
| `mutate()` | Updated to detect rowwise sentinel; existing grouped-mutate path unchanged |
| `filter()` | Domain column preserved by `distinct()` |
| `group_by()` | Replaces rowwise sentinel (existing behavior; no change required) |
| `ungroup()` | Exits rowwise mode (existing behavior; no change required) |

### With Phase 1 (estimation functions)

| Contract | Notes |
|----------|-------|
| `@variables$rowwise` convention | Phase 1 must use `is_rowwise()` and `is_grouped()` predicates, not read `@groups` or `@variables$rowwise` directly. |
| `surveytidy::is_rowwise(design)` | Phase 1 uses this to detect rowwise mode and error/warn appropriately |
| `surveytidy::is_grouped(design)` | Phase 1 uses this to branch between ungrouped and grouped estimation paths |
| `surveytidy::group_vars(design)` | Phase 1 uses this to get the actual grouping column names for stratified estimation; sentinel is automatically excluded |
