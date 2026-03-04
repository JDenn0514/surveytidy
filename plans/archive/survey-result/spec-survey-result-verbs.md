# Spec: dplyr/tidyr Verb Support for `survey_result` Objects

**Version:** 0.2
**Date:** 2026-03-02
**Status:** Stage 3 — Pass 2 issue resolution in progress
**Spec file:** `plans/spec-survey-result-verbs.md`
**Implementation plan (prior draft):** `plans/implementation-plan-survey-result-verbs.md`

---

## Document Purpose

This document is the source of truth for the design of dplyr/tidyr verb
methods for `survey_result` objects. It governs implementation, tests, and PR
review. Any deviation from this spec requires an explicit decision log entry.

`survey_result` objects are S3 tibble subclasses returned by surveycore
analysis functions (`get_means()`, `get_freqs()`, `get_totals()`,
`get_quantiles()`, `get_corr()`, `get_ratios()`). Without verb methods,
applying dplyr verbs to these objects silently strips both the custom class
and the `.meta` attribute, losing provenance and metadata. This feature
restores that invariant: class and `.meta` survive every supported
dplyr/tidyr operation, with active meta updates for column-touching verbs.

Code style, `::` usage, roxygen2 conventions, and NAMESPACE hygiene are
governed by `code-style.md` and `r-package-conventions.md`. This spec does not
repeat those rules; it only documents decisions specific to this feature.

---

## I. Scope

### What this feature delivers

Thirteen S3 verb methods registered for the `"survey_result"` class, split
across two PRs:

**PR 1 — Passthrough verbs** (`feature/survey-result-passthrough`):

| Method | Registered namespace | Behavior category |
|--------|---------------------|-------------------|
| `filter.survey_result` | dplyr | Passthrough |
| `arrange.survey_result` | dplyr | Passthrough |
| `mutate.survey_result` | dplyr | Passthrough |
| `slice.survey_result` | dplyr | Passthrough |
| `slice_head.survey_result` | dplyr | Passthrough |
| `slice_tail.survey_result` | dplyr | Passthrough |
| `slice_min.survey_result` | dplyr | Passthrough |
| `slice_max.survey_result` | dplyr | Passthrough |
| `slice_sample.survey_result` | dplyr | Passthrough |
| `drop_na.survey_result` | tidyr | Passthrough |

PR 1 also delivers all test infrastructure (`make_survey_result()`,
`test_result_invariants()`, `test_result_meta_coherent()`).

**PR 2 — Meta-updating verbs** (`feature/survey-result-meta`):

| Method | Registered namespace | Behavior category |
|--------|---------------------|-------------------|
| `select.survey_result` | dplyr | Meta-updating |
| `rename.survey_result` | dplyr | Meta-updating |
| `rename_with.survey_result` | dplyr | Meta-updating |

### What this feature does NOT deliver

- `group_by()` / `ungroup()` for `survey_result` — result tibbles have no
  `@groups` slot; grouped re-estimation is out of scope
- `rowwise()`, `distinct()`, `*_join()` for `survey_result`
- Any changes to how surveycore analysis functions produce estimates
- Updating `n_respondents` after row-removal operations (intentional —
  see Section III.1)
- New error or warning classes (see Section VIII)

### Design type coverage

`survey_result` objects carry a `design_type` field in `.meta`. All thirteen
methods are design-type-agnostic — they operate on the tibble output, not the
underlying survey design. All design types (`"taylor"`, `"replicate"`,
`"twophase"`, `"srs"`, `"calibrated"`) are supported without special-casing.

---

## II. Architecture

### Class hierarchy

All six surveycore result classes share this structure:

```
c("<subclass>", "survey_result", "tbl_df", "tbl", "data.frame")
```

Where `<subclass>` is one of: `survey_means`, `survey_freqs`,
`survey_totals`, `survey_quantiles`, `survey_corr`, `survey_ratios`.

All methods are registered for `"survey_result"` (the shared base class).
S3 dispatch walks `survey_freqs → survey_result → tbl_df`, so one
registration per verb covers all six subclasses automatically.

### `.meta` attribute structure

Every `survey_result` carries a `.meta` attribute (a named list). Read via
`surveycore::meta(result)`. Written via `attr(result, ".meta") <- new_meta`
(no setter is exported by surveycore).

**Always-present keys:**

| Key | Type | Description |
|-----|------|-------------|
| `design_type` | `character(1)` | One of `"taylor"`, `"replicate"`, `"twophase"`, `"srs"`, `"calibrated"` |
| `n_respondents` | `integer(1)` | Row count of the survey design that produced this result. Fixed — never updated by verb operations. |
| `conf_level` | `numeric(1)` | Confidence level used for interval columns (e.g., `0.95`) |
| `call` | `call` | Matched call to the original `get_*()` function |
| `group` | `list` | Named list; each name is a grouping column present in the result tibble; each value has `variable_label`, `question_preface`, `value_labels` sub-keys |
| `x` | `list` or `NULL` | Named list; each name is a focal variable column in the result tibble; same sub-key structure as `group` entries. Set to `NULL` by `select()` when all focal columns are dropped. |

**Function-specific keys (optional, absent when not applicable):**

| Key | Present in | Type | Description |
|-----|-----------|------|-------------|
| `probs` | `get_quantiles()` results | `numeric` vector | Quantile probabilities |
| `method` | `get_corr()` results | `character(1)` | Correlation method (e.g., `"pearson"`) |
| `numerator` | `get_ratios()` results | `list` with `$name` | Numerator variable metadata; `$name` is the column name |
| `denominator` | `get_ratios()` results | `list` with `$name` | Denominator variable metadata; `$name` is the column name |

**Meta coherence invariant:** every name in `meta$group` and every name in
`meta$x` must be the name of a column present in the result tibble.

### File organization

```
R/
  verbs-survey-result.R     # NEW — all 13 verb implementations
                            #       + .apply_result_rename_map()
                            #       + .prune_result_meta()
                            #       + .restore_survey_result() (inline helpers)
  zzz.R                     # EXTEND — add registerS3method() calls
                            #           for all 13 verbs

tests/testthat/
  helper-test-data.R        # EXTEND — add make_survey_result(),
                            #           test_result_invariants(),
                            #           test_result_meta_coherent()
  test-verbs-survey-result.R  # NEW — all tests
```

### Shared helper signatures (all three defined inline at the top of `R/verbs-survey-result.R`)

**`.apply_result_rename_map(result, rename_map)`**

`rename_map` is a named character vector: `c(old_name = "new_name")`.

Atomically updates:
1. Tibble column names (`names(result)`)
2. `meta$group` keys — any key matching an old name is renamed to the new name
3. `meta$x` keys — same
4. `meta$numerator$name` — updated if the current value is an old name
5. `meta$denominator$name` — updated if the current value is an old name

Does NOT update: `meta$n_respondents`, `meta$call`, `meta$design_type`,
`meta$conf_level`, `meta$probs`, `meta$method`.

Returns: `result` with updated column names and `.meta`, original class
preserved.

**`.prune_result_meta(meta, kept_cols)`**

`kept_cols` is a character vector of column names remaining after a select.

Updates:
1. `meta$group` — removes entries whose name is not in `kept_cols`
2. `meta$x` — removes entries whose name is not in `kept_cols`; sets
   `meta$x <- NULL` if no entries remain
3. `meta$numerator` — set to `NULL` if `meta$numerator$name` is not in `kept_cols`
4. `meta$denominator` — set to `NULL` if `meta$denominator$name` is not in `kept_cols`

Does NOT update: `meta$n_respondents`, `meta$call`, `meta$design_type`,
`meta$conf_level`, `meta$probs`, `meta$method`.

Returns: the updated `meta` list.

**`.restore_survey_result(result, old_class, old_meta)`**

Restores class and `.meta` to a tibble returned by `NextMethod()`. Used as the
final step in every passthrough verb body.

```r
.restore_survey_result <- function(result, old_class, old_meta) {
  attr(result, ".meta") <- old_meta
  class(result) <- old_class
  result
}
```

---

## III. Passthrough verbs

### III.1 Passthrough pattern and invariants

All ten passthrough verbs share this pattern, using `.restore_survey_result()`:

```r
verb.survey_result <- function(.data, ...) {
  old_class <- class(.data)
  old_meta  <- attr(.data, ".meta")
  NextMethod() |> .restore_survey_result(old_class, old_meta)
}
```

**Why `NextMethod()` works:** dplyr's `UseMethod("filter")` (etc.) sets
`.Generic` and `.Class` correctly on dispatch. `NextMethod()` calls
`filter.tbl_df` (or the tidyr equivalent for `drop_na`), which returns a plain
`tbl_df`. The original class vector is then restored.

**No `dplyr_reconstruct.survey_result` method is needed.** The passthrough
pattern captures class and `.meta` before `NextMethod()` and restores them
after. `dplyr_reconstruct` would only be needed if dplyr were responsible for
the reconstruction — it is not, because we do it explicitly in each method.
Do not add a `dplyr_reconstruct.survey_result` method; it would be unused and
could interfere with the `.meta` restoration.

**`n_respondents` is not updated.** It reflects the row count of the original
survey design that produced the estimates — not the number of rows in the
result tibble after any subsequent filtering. This is a deliberate design
decision: `n_respondents` is provenance metadata about the estimation context,
not a row counter.

**No `surveycore_warning_physical_subset` is issued.** That warning exists to
flag semantically incorrect row removal from survey design objects, where
removing rows corrupts variance estimation. `survey_result` objects are plain
result tibbles; row removal has no design implications and requires no warning.

### III.2 `filter.survey_result`

**Signature:**
```r
filter.survey_result <- function(.data, ..., .by = NULL, .preserve = FALSE)
```

**Argument table:**

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `.data` | `survey_result` | required | The result tibble |
| `...` | data-masking | required | Row-selection conditions |
| `.by` | tidy-select | `NULL` | Passed to `NextMethod()` |
| `.preserve` | `logical(1)` | `FALSE` | Passed to `NextMethod()` |

**Output contract:**
All passthrough invariants from III.1 apply (class, `.meta`, and columns unchanged).
- Rows: subset to rows satisfying `...`

**Error conditions:** None specific to this method. All errors come from
`filter.tbl_df`.

### III.3 `arrange.survey_result`

**Signature:**
```r
arrange.survey_result <- function(.data, ..., .by_group = FALSE)
```

**Argument table:**

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `.data` | `survey_result` | required | The result tibble |
| `...` | data-masking | required | Ordering expressions |
| `.by_group` | `logical(1)` | `FALSE` | Passed to `NextMethod()` |

**Output contract:**
All passthrough invariants from III.1 apply (class, `.meta`, and columns unchanged).
- Rows: reordered; count unchanged

### III.4 `mutate.survey_result`

**Signature:**
```r
mutate.survey_result <- function(
  .data,
  ...,
  .keep = c("all", "used", "unused", "none"),
  .before = NULL,
  .after = NULL
)
```

**Argument table:**

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `.data` | `survey_result` | required | The result tibble |
| `...` | data-masking | required | Column expressions |
| `.keep` | `character(1)` | `"all"` | Passed to `NextMethod()` |
| `.before` | tidy-select | `NULL` | Passed to `NextMethod()` |
| `.after` | tidy-select | `NULL` | Passed to `NextMethod()` |

**Output contract:**
All passthrough invariants from III.1 apply (class and columns unchanged).
- `.meta`: see Behavior note below — meta is pruned, not preserved verbatim
- Rows: unchanged
- Columns: new/modified columns as specified by `...`

**Behavior note:**

- **Overwriting a meta-referenced column's values** (e.g., `mutate(r, group = toupper(group))`):
  `.meta` is preserved verbatim. The coherence invariant holds because the
  column name is still present. No warning is issued — this is deliberate
  data manipulation on a post-estimation output.

- **Dropping meta-referenced columns via `.keep`** (e.g., `.keep = "none"`,
  `"used"`, or `"unused"`): After `NextMethod()`, the implementation calls
  `.prune_result_meta()` to remove meta entries for any columns that are no
  longer present. The coherence invariant is actively maintained.

**Implementation approach (mutate diverges from pure passthrough):**

```r
mutate.survey_result <- function(.data, ..., .keep = c("all", "used", "unused", "none"),
                                  .before = NULL, .after = NULL) {
  old_class <- class(.data)
  old_meta  <- attr(.data, ".meta")
  result    <- NextMethod() |> .restore_survey_result(old_class, old_meta)
  # Prune meta for columns dropped by .keep (maintains coherence invariant)
  new_meta <- .prune_result_meta(attr(result, ".meta"), names(result))
  attr(result, ".meta") <- new_meta
  result
}
```

Note: `.prune_result_meta()` is a no-op when `.keep = "all"` (no columns
are dropped), so there is no overhead for the common case.

### III.5 Slice variants

All six slice variants use the passthrough pattern. Each passes all arguments
through to `NextMethod()`.

**`slice.survey_result`**
```r
slice.survey_result <- function(.data, ..., .by = NULL)
```

**`slice_head.survey_result`**
```r
slice_head.survey_result <- function(.data, n, prop, ..., by = NULL)
```

**`slice_tail.survey_result`**
```r
slice_tail.survey_result <- function(.data, n, prop, ..., by = NULL)
```

**`slice_min.survey_result`**
```r
slice_min.survey_result <- function(
  .data,
  order_by,
  n,
  prop,
  ...,
  with_ties = TRUE,
  na_rm = FALSE,
  by = NULL
)
```

**`slice_max.survey_result`**
```r
slice_max.survey_result <- function(
  .data,
  order_by,
  n,
  prop,
  ...,
  with_ties = TRUE,
  na_rm = FALSE,
  by = NULL
)
```

**`slice_sample.survey_result`**
```r
slice_sample.survey_result <- function(
  .data,
  n,
  prop,
  ...,
  weight_by = NULL,
  replace = FALSE,
  by = NULL
)
```

**Output contract (all slice variants):**
All passthrough invariants from III.1 apply (class, `.meta`, and columns unchanged).
- Rows: subset as defined by the variant; may produce 0-row result

**No `surveytidy_error_subset_empty_result` is thrown.** That error guards
survey design objects (a 0-row design cannot estimate anything). A 0-row
result tibble is a valid filtered result and is returned without error.

### III.6 `drop_na.survey_result`

**Signature:**
```r
drop_na.survey_result <- function(data, ...)
```

**Argument name note:** tidyr's `drop_na` generic uses `data` (not `.data`).
Using the same name matches the tidyr convention and makes the signature
readable alongside other tidyr methods. `NextMethod()` forwards arguments by
position, so the name does not affect dispatch.

**Argument table:**

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `survey_result` | required | The result tibble |
| `...` | tidy-select | (all cols) | Columns to check for NAs. If empty, all columns are checked. |

**Output contract:**
All passthrough invariants from III.1 apply (class, `.meta`, and columns unchanged).
- Rows: rows with NA in specified columns removed

**No `surveycore_warning_empty_domain` is issued.** That warning is for
domain operations on survey design objects. Result tibbles have no domain
concept.

---

## IV. Meta-updating verbs

### IV.1 `select.survey_result`

**Signature:**
```r
select.survey_result <- function(.data, ...)
```

**Argument table:**

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `.data` | `survey_result` | required | The result tibble |
| `...` | tidy-select | required | Column selection |

**Output contract:**
- Class: identical to `class(.data)`
- `.meta$group`: entries for dropped columns removed; entries for kept
  columns unchanged (including sub-keys)
- `.meta$x`: entries for dropped columns removed; set to `NULL` if all
  focal columns dropped
- All other `.meta` keys: unchanged
- Rows: unchanged
- Columns: only selected columns remain

**Rename-in-select behavior:** dplyr's `select()` supports in-place renaming
(`select(r, grp = group)`). `eval_select` returns output names that differ
from original names in that case. The implementation detects this and applies
the rename map via `.apply_result_rename_map()` before pruning, so metadata
for renamed columns is preserved (with the new name) rather than silently
dropped.

**Implementation approach:**
0. `tbl <- tibble::as_tibble(.data)`; `old_class <- class(.data)`
1. Resolve selection: `selected_cols <- tidyselect::eval_select(rlang::expr(c(...)), tbl)` — named integer vector (`output_name = position`)
2. Compute name arrays: `original_names <- names(tbl)[unname(selected_cols)]`; `output_names <- names(selected_cols)`
3. Detect and apply inline renames:
   ```r
   rename_mask <- original_names != output_names
   if (any(rename_mask)) {
     rename_map <- stats::setNames(
       output_names[rename_mask], original_names[rename_mask]
     )
     .data <- .apply_result_rename_map(.data, rename_map)
   }
   ```
4. Subset tibble to selected columns (using `output_names`): `result <- .data[, output_names, drop = FALSE]`
5. Prune meta: `new_meta <- .prune_result_meta(attr(.data, ".meta"), output_names)`
6. Assign and restore: `attr(result, ".meta") <- new_meta`; `class(result) <- old_class`

**Zero-column select:** `select(r, dplyr::starts_with("zzz"))` when no
columns match returns a 0-column tibble (dplyr's standard behavior).
`tidyselect::eval_select()` returns `integer(0)` in this case.
`.prune_result_meta()` produces `meta$group = list()` and `meta$x = NULL`
(all column references dropped). `test_result_invariants()` still passes
— a 0-column tibble is a valid tibble. No special handling is needed.

**Error conditions:** None specific. tidy-select handles invalid column
references.

### IV.2 `rename.survey_result`

**Signature:**
```r
rename.survey_result <- function(.data, ...)
```

**Argument table:**

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `.data` | `survey_result` | required | The result tibble |
| `...` | tidy-select | required | Column renaming (`new_name = old_name`) |

**Output contract:**
- Class: identical to `class(.data)`
- `.meta$group` keys: keys matching old names updated to new names
- `.meta$x` keys: keys matching old names updated to new names
- `.meta$numerator$name`: updated if old value matches a renamed column
- `.meta$denominator$name`: updated if old value matches a renamed column
- All other `.meta` keys: unchanged
- Rows: unchanged
- Columns: renamed as specified; all columns preserved

_`rename_map` format: see Section II helper signatures._

**Identity rename note:** `rename(r, col = col)` produces an empty or
self-referential map from `eval_rename`. `.apply_result_rename_map()` with
an empty map is a no-op — column names and `.meta` are unchanged.

**Implementation approach:**
0. `tbl <- tibble::as_tibble(.data)`
1. Build rename map:
   ```r
   map <- tidyselect::eval_rename(rlang::expr(c(...)), tbl)
   rename_map <- stats::setNames(names(map), names(tbl)[map])
   ```
2. Delegate: `.apply_result_rename_map(.data, rename_map)`

**Error conditions:** None specific. tidy-select handles invalid column
references.

### IV.3 `rename_with.survey_result`

**Signature:**
```r
rename_with.survey_result <- function(.data, .fn, .cols = dplyr::everything(), ...)
```

**Argument table:**

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `.data` | `survey_result` | required | The result tibble |
| `.fn` | `function` | required | A function mapping a character vector of column names to a character vector of the same length |
| `.cols` | tidy-select | `dplyr::everything()` | Columns to rename |
| `...` | (any) | (none) | Additional arguments passed to `.fn` |

**Output contract:**
- Class: identical to `class(.data)`
- All column name references in `.meta` updated for renamed columns
  (same update set as `rename.survey_result`)
- Rows: unchanged
- Columns: renamed columns get new names; all columns preserved

**Implementation approach:**
0. `tbl <- tibble::as_tibble(.data)`
1. Resolve `.cols` to column positions: `tidyselect::eval_select(rlang::enquo(.cols), tbl)`
2. Extract old names: `names(resolved_cols)`
3. Apply: `new_names <- .fn(old_names, ...)`
4. Validate output: length must equal `length(old_names)`, type must be
   `character`, no `NA` values, no duplicate names when merged back into
   full column list
5. Build rename_map: `stats::setNames(new_names, old_names)` — see Section II
   for format convention
6. Delegate: `.apply_result_rename_map(.data, rename_map)`

**Error conditions:**

| Class | Trigger | Message template |
|-------|---------|-----------------|
| `surveytidy_error_rename_fn_bad_output` | `.fn` returns a vector of different length than its input, a non-character vector, contains `NA` values, or introduces duplicate column names across the full column list | `"{.arg .fn} must return a character vector the same length as its input with no NA or duplicate names."` |

Uses the existing error class from `plans/error-messages.md`. No new class
needed.

---

## V. Test infrastructure

### `make_survey_result(type, design, seed)` — extend `tests/testthat/helper-test-data.R`

```r
make_survey_result <- function(
  type   = c("means", "freqs", "ratios"),
  design = c("taylor", "replicate", "twophase"),
  seed   = 42L
)
```

Builds a full survey design via `make_survey_data()` + the appropriate
`surveycore::as_survey*()` constructor, then calls the appropriate surveycore
analysis function.

**`type` → analysis function mapping:**

| `type` | Calls | Subclass | Key `.meta` characteristics |
|--------|-------|----------|-----------------------------|
| `"means"` | `surveycore::get_means(d, x = y1, group = group)` | `survey_means` | `$group` has key `"group"`, `$x` has key `"y1"` |
| `"freqs"` | `surveycore::get_freqs(d, x = group)` | `survey_freqs` | `$group` is empty `list()`, `$x` has key `"group"` |
| `"ratios"` | `surveycore::get_ratios(d, numerator = y1, denominator = y2)` | `survey_ratios` | `$numerator$name == "y1"`, `$denominator$name == "y2"`, `$group` is empty `list()` |

**`design` → survey constructor mapping:**

| `design` | Constructor | Data source |
|----------|-------------|-------------|
| `"taylor"` | `surveycore::as_survey(df, ids = psu, strata = strata, weights = wt, fpc = fpc, nest = TRUE)` | `make_survey_data()` |
| `"replicate"` | Uses replicate-weights design from `make_all_designs()` | `make_survey_data()` with replicate weights |
| `"twophase"` | Uses twophase design from `make_all_designs()` | `make_survey_data()` with phase2_ind |

**Coverage requirement:** The passthrough verb test sections (Section VI, PR 1 test 1) must include at least one test block per `design` type. The meta-updating verb test sections (PR 2) use `"taylor"` only — meta update logic is design-type-agnostic by construction. Design types `"srs"` and `"calibrated"` are out of scope for these fixtures given their distinct setup requirements.

### `test_result_invariants(result, expected_class)` — extend `tests/testthat/helper-test-data.R`

Called as the **first assertion** in every test block that operates on a
`survey_result`.

Asserts:
1. `inherits(result, expected_class)` — specific subclass preserved
2. `inherits(result, "survey_result")` — base class preserved
3. `tibble::is_tibble(result)` — tibble structure intact
4. `!is.null(surveycore::meta(result))` — `.meta` present
5. `is.list(surveycore::meta(result))` — `.meta` is a list
6. All required keys present in `.meta`:
   `c("design_type", "conf_level", "call", "group", "n_respondents")`
7. `is.list(meta$group)` — `$group` is a named list
8. `is.integer(meta$n_respondents)` — `$n_respondents` is integer

### `test_result_meta_coherent(result)` — extend `tests/testthat/helper-test-data.R`

Called after any meta-updating verb operation to assert the meta coherence
invariant.

```r
test_result_meta_coherent <- function(result) {
  m    <- surveycore::meta(result)
  cols <- names(result)
  for (g in names(m$group)) {
    testthat::expect_true(
      g %in% cols,
      label = paste("group col", g, "exists in result")
    )
  }
  if (!is.null(m$x)) {
    for (v in names(m$x)) {
      testthat::expect_true(
        v %in% cols,
        label = paste("x col", v, "exists in result")
      )
    }
  }
  if (!is.null(m$numerator)) {
    testthat::expect_true(
      m$numerator$name %in% cols,
      label = paste("numerator col", m$numerator$name, "exists in result")
    )
  }
  if (!is.null(m$denominator)) {
    testthat::expect_true(
      m$denominator$name %in% cols,
      label = paste("denominator col", m$denominator$name, "exists in result")
    )
  }
  invisible(result)
}
```

---

## VI. Testing

### Test file: `tests/testthat/test-verbs-survey-result.R`

All blocks follow the standard pattern from `testing-surveytidy.md`:
`test_result_invariants()` is the first assertion in every block. Error-path
blocks (block 12) are exempt because no result is returned. All other blocks
call `test_result_invariants()` as the first assertion.

#### PR 1 test sections

**1. Passthrough — class and meta preserved (all types × all designs)**

For each passthrough verb (`filter`, `arrange`, `mutate`, `slice`,
`slice_head`, `slice_tail`, `slice_min`, `slice_max`, `slice_sample`,
`drop_na`): one `test_that()` block per verb, containing a loop over all
three result types (`"means"`, `"freqs"`, `"ratios"`) AND all three design
types (`"taylor"`, `"replicate"`, `"twophase"`). Within each iteration:
- `test_result_invariants(result_after, expected_subclass)` passes
- `surveycore::meta(result_after)` is identical to `surveycore::meta(result_before)`

**2. Row-changing passthrough — correct counts**

For `filter`, `slice_head`, `slice_tail`:
- `nrow(result_after) < nrow(result_before)` (for non-trivial filters)
- Class and `.meta` still preserved
- 0-row result is valid; class and meta preserved

**3. `mutate()` — new column not tracked in meta**

- `mutate(result_means, sig = se < 0.1)` produces `sig` column
- `.meta` is unchanged

**3b. `mutate(.keep = "none")` — meta coherence maintained after column drops**

- `mutate(result_means, sig = se < 0.1, .keep = "none")` — only `sig` column remains
- `length(meta(r)$group) == 0L` (group column dropped, entry pruned)
- `is.null(meta(r)$x)` is `TRUE` (focal column dropped)
- `test_result_invariants(r, "survey_means")` passes
- `test_result_meta_coherent(r)` passes

**3c. `mutate(.keep = "used")` — meta coherence maintained after column drops**

- `mutate(result_means, sig = se < 0.1, .keep = "used")` — only `se` and `sig` remain
- `length(meta(r)$group) == 0L` (group column dropped, entry pruned)
- `is.null(meta(r)$x)` is `TRUE` (focal column dropped)
- `test_result_invariants(r, "survey_means")` passes
- `test_result_meta_coherent(r)` passes

**4. `n_respondents` is not updated after filter**

- `filter(result_means, mean > 0)` → `nrow(filtered) < nrow(result_means)`
- `surveycore::meta(filtered)$n_respondents` equals
  `surveycore::meta(result_means)$n_respondents`

#### PR 2 test sections

**5. `rename()` — group key updated**

- `rename(result_means, grp = group)`
- `"grp" %in% names(meta(r)$group)` is `TRUE`
- `"group" %in% names(meta(r)$group)` is `FALSE`
- `test_result_meta_coherent(r)` passes

**6. `rename()` — x key updated**

- `rename(result_means, outcome = y1)`
- `"outcome" %in% names(meta(r)$x)` is `TRUE`
- `"y1" %in% names(meta(r)$x)` is `FALSE`
- `test_result_meta_coherent(r)` passes

**7. `rename()` — non-meta column rename leaves meta unchanged**

- Rename a column not in `$group` or `$x` (e.g., a `mean` → `estimate` or
  `se` → `std_error`)
- `surveycore::meta(r)` is identical to `surveycore::meta(result_before)`

**8. `rename()` — ratios numerator name updated**

- `rename(result_ratios, numer = y1)`
- `surveycore::meta(r)$numerator$name == "numer"`

**9. `rename()` — ratios denominator name updated**

- `rename(result_ratios, denom = y2)`
- `surveycore::meta(r)$denominator$name == "denom"`

**10. `rename_with()` — applies `.fn` to selected columns and updates meta**

- `rename_with(result_means, toupper)` — all column names upper-cased
- Group and x keys in meta also upper-cased
- `test_result_meta_coherent(r)` passes

**11. `rename_with()` — `.cols` limits scope of rename**

- `rename_with(result_means, toupper, .cols = c(mean, se))` — only `mean` and
  `se` upper-cased
- Meta group key `"group"` unchanged (not in `.cols`); meta x key `"y1"`
  unchanged (not in `.cols`)
- `test_result_meta_coherent(r)` passes

**12. `rename_with()` — invalid `.fn` output triggers error (parameterized, dual pattern)**

```r
bad_fns <- list(
  "non-character output" = function(x) seq_along(x),
  "wrong-length output"  = function(x) x[1],
  "NA in output"         = function(x) { x[1] <- NA_character_; x },
  "duplicate names"      = function(x) rep(x[1], length(x))
)
for (label in names(bad_fns)) {
  fn <- bad_fns[[label]]
  expect_error(
    rename_with(result_means, fn),
    class = "surveytidy_error_rename_fn_bad_output"
  )
  expect_snapshot(error = TRUE, rename_with(result_means, fn))
}
```

Each loop iteration generates one snapshot entry keyed by `label`.

**13. `select()` — group entry removed when group col dropped**

- `select(result_means, mean, se)` — drops `group` column
- `length(meta(r)$group) == 0L`
- `test_result_meta_coherent(r)` passes

**14. `select()` — x set to NULL when all focal cols dropped**

- `select(result_means, group)` — drops `y1` (and all estimate columns)
- `is.null(meta(r)$x)` is `TRUE`
- `test_result_meta_coherent(r)` passes

**15. `select()` — kept group column preserves meta sub-key; dropped focal column nulls meta$x**

- `select(result_means, group, mean, se)` — `y1` (focal) absent from selection;
  `group` (grouping var) is kept
- `meta(r)$group$group` is identical to `meta(result_means)$group$group`
- `expect_true(is.null(meta(r)$x))` — `y1` was the only focal column; now dropped

**16. `select()` — non-group, non-x column removal does not affect group/x meta**

- `select(result_means, -se)` — drops `se`; `group` and `y1` focal still present
- `meta(r)$group` identical to `meta(result_means)$group`
- `meta(r)$x` identical to `meta(result_means)$x`

**16b. `select()` with inline rename syntax — meta preserved under new name**

- `select(result_means, grp = group)` — renames `group` to `grp` while keeping only that column
- `"grp" %in% names(meta(r)$group)` is `TRUE`
- `"group" %in% names(meta(r)$group)` is `FALSE`
- `test_result_meta_coherent(r)` passes

**17. `rename()` on `result_freqs` — updates `$x` key (empty `$group` path)**

`result_freqs` has `$group = list()` (empty) and `$x = list(group = ...)` (focal variable named `"group"`).

- `rename(result_freqs, grp = group)` — renames the `"group"` column
- `"grp" %in% names(meta(r)$x)` is `TRUE`
- `"group" %in% names(meta(r)$x)` is `FALSE`
- `length(meta(r)$group) == 0L` (empty group list unchanged)
- `test_result_meta_coherent(r)` passes

**18. `select()` on `result_freqs` — sets `$x` to NULL when focal col dropped**

- `select(result_freqs, mean, se)` — drops `"group"` column (the only `$x` key)
- `is.null(meta(r)$x)` is `TRUE`
- `length(meta(r)$group) == 0L` (empty group list unchanged)
- `test_result_meta_coherent(r)` passes

**19. Chained meta-updating verbs — rename then select**

- `result_means |> rename(grp = group) |> select(grp, y1, mean)`
- `"grp" %in% names(meta(r)$group)` is `TRUE`
- `"group" %in% names(meta(r)$group)` is `FALSE`
- `"y1" %in% names(meta(r)$x)` is `TRUE`
- `test_result_invariants(r, "survey_means")` passes
- `test_result_meta_coherent(r)` passes

**20. `rename_with()` — `.cols` resolving to zero columns is a no-op**

- `rename_with(result_means, toupper, .cols = dplyr::starts_with("zzz"))`
- Column names unchanged
- `surveycore::meta(r)` identical to `surveycore::meta(result_means)`
- `test_result_invariants(r, "survey_means")` passes

**21. `rename()` — identity rename is a no-op**

- `rename(result_means, group = group)`
- Column names unchanged
- `surveycore::meta(r)` identical to `surveycore::meta(result_means)`
- `test_result_invariants(r, "survey_means")` passes

**22. `rename_with()` — `...` forwarded to `.fn` (EDGE-4)**

- `rename_with(result_means, gsub, pattern = "mean", replacement = "avg")`
- Column previously named `"mean"` is now named `"avg"`
- `"avg" %in% names(meta(r)$x)` is `TRUE` (if `"mean"` was an x key)
- `test_result_invariants(r, "survey_means")` passes
- `test_result_meta_coherent(r)` passes

**23. `drop_na()` — primary happy path: rows with NAs are dropped (EDGE-5)**

- Construct `result_means` and inject `NA` into at least one estimate column
  for a subset of rows (e.g., `result_means$se[1] <- NA_real_`)
- `drop_na(result_with_na, se)` — drops rows where `se` is `NA`
- `nrow(result_after) < nrow(result_with_na)` is `TRUE`
- `inherits(result_after, "survey_means")` is `TRUE`
- `surveycore::meta(result_after)` is identical to `surveycore::meta(result_with_na)`
- `test_result_invariants(result_after, "survey_means")` passes

**24. `filter()` — `.by` argument forwarded to `NextMethod()` (EDGE-6)**

- `filter(result_means, mean > 0, .by = group)`
- Class preserved: `inherits(r, "survey_means")` is `TRUE`
- `.meta` unchanged: `surveycore::meta(r)` identical to input meta
- `test_result_invariants(r, "survey_means")` passes

**25. `slice_min()` / `slice_max()` — non-default arguments preserve class and meta (EDGE-7)**

- `slice_min(result_means, order_by = mean, n = 2, with_ties = FALSE)` —
  exactly 2 rows returned (no tie expansion); class and meta preserved
- `slice_max(result_means, order_by = mean, n = 2, na_rm = TRUE)` —
  rows with `NA` in `mean` excluded before ranking; class and meta preserved
- For each: `test_result_invariants(r, "survey_means")` passes;
  `surveycore::meta(r)` identical to input meta

**26. `slice_sample(replace = TRUE)` — over-sampling preserves class and meta (EDGE-8)**

- `slice_sample(result_means, n = nrow(result_means) + 1, replace = TRUE)` —
  result has more rows than input (replacement sampling); duplicate rows expected
- `inherits(r, "survey_means")` is `TRUE`
- `surveycore::meta(r)` identical to `surveycore::meta(result_means)`
- `test_result_invariants(r, "survey_means")` passes

**27. `select()` of zero columns — degenerate result is valid (EDGE-9)**

- `select(result_means, dplyr::starts_with("zzz"))` — no columns match; dplyr
  returns a 0-column tibble with all rows intact
- `ncol(r) == 0L` is `TRUE`
- `length(meta(r)$group) == 0L` is `TRUE` (`group` column dropped)
- `is.null(meta(r)$x)` is `TRUE` (all focal columns dropped)
- `test_result_invariants(r, "survey_means")` passes (0-column tibble is valid)

#### Edge cases

| Case | Verb | Expected behavior |
|------|------|-------------------|
| `filter()` yields 0 rows | `filter` | 0-row tibble with class and meta preserved |
| `slice_head(n = 0)` | `slice_head` | 0-row tibble with class and meta preserved |
| `select()` selects all columns | `select` | All meta unchanged; class preserved |
| `rename()` renames a column not in any meta field | `rename` | Meta unchanged |
| `rename_with(identity)` | `rename_with` | No change; meta unchanged |
| `drop_na()` with no NAs in result | `drop_na` | All rows preserved; meta unchanged |

---

## VII. `R/zzz.R` additions

A new labeled section is added after the existing `# ── feature/drop-na` block:

```r
# ── survey_result verbs (PR 1 — passthrough) ────────────────────────────

registerS3method(
  "filter", "survey_result",
  get("filter.survey_result", envir = ns), envir = asNamespace("dplyr")
)
registerS3method(
  "arrange", "survey_result",
  get("arrange.survey_result", envir = ns), envir = asNamespace("dplyr")
)
registerS3method(
  "mutate", "survey_result",
  get("mutate.survey_result", envir = ns), envir = asNamespace("dplyr")
)
registerS3method(
  "slice", "survey_result",
  get("slice.survey_result", envir = ns), envir = asNamespace("dplyr")
)
registerS3method(
  "slice_head", "survey_result",
  get("slice_head.survey_result", envir = ns), envir = asNamespace("dplyr")
)
registerS3method(
  "slice_tail", "survey_result",
  get("slice_tail.survey_result", envir = ns), envir = asNamespace("dplyr")
)
registerS3method(
  "slice_min", "survey_result",
  get("slice_min.survey_result", envir = ns), envir = asNamespace("dplyr")
)
registerS3method(
  "slice_max", "survey_result",
  get("slice_max.survey_result", envir = ns), envir = asNamespace("dplyr")
)
registerS3method(
  "slice_sample", "survey_result",
  get("slice_sample.survey_result", envir = ns), envir = asNamespace("dplyr")
)
registerS3method(
  "drop_na", "survey_result",
  get("drop_na.survey_result", envir = ns), envir = asNamespace("tidyr")
)

# ── survey_result verbs (PR 2 — meta-updating) ──────────────────────────

registerS3method(
  "select", "survey_result",
  get("select.survey_result", envir = ns), envir = asNamespace("dplyr")
)
registerS3method(
  "rename", "survey_result",
  get("rename.survey_result", envir = ns), envir = asNamespace("dplyr")
)
registerS3method(
  "rename_with", "survey_result",
  get("rename_with.survey_result", envir = ns), envir = asNamespace("dplyr")
)
```

---

## VIII. Error and warning classes

No new classes are added by this feature.

The existing `surveytidy_error_rename_fn_bad_output` (already in
`plans/error-messages.md`) is reused for `rename_with.survey_result`.
`plans/error-messages.md` does not need updating.

---

## IX. Quality Gates

All items must be verifiable before a PR is opened.

**PR 1:**
- [ ] `devtools::load_all()` — no errors; all 10 passthrough verbs registered
- [ ] `devtools::test(filter = "verbs-survey-result")` — all tests pass
- [ ] `devtools::test()` — no regressions in existing tests
- [ ] `devtools::check()` — 0 errors, 0 warnings, ≤2 notes
- [ ] Every passthrough verb tested with all 3 result types (`"means"`,
      `"freqs"`, `"ratios"`)
- [ ] `test_result_invariants()` is the first assertion in every test block
- [ ] Snapshot committed for `filter()` 0-row edge case if dplyr issues a
      message

**PR 2:**
- [ ] All three meta-updating verbs registered and functional
- [ ] `test_result_meta_coherent()` called after every meta-updating verb test
- [ ] Snapshot committed for `surveytidy_error_rename_fn_bad_output` from
      `rename_with.survey_result`
- [ ] `plans/error-messages.md` — confirm no new classes added; update source
      file column for `surveytidy_error_rename_fn_bad_output` to include
      `R/verbs-survey-result.R`

---

## X. Integration

### surveycore dependencies

| surveycore export | Used for |
|-------------------|----------|
| `surveycore::meta(result)` | Read `.meta` in tests and implementations |
| `surveycore::get_means(d, x, group)` | Build `"means"` test fixtures |
| `surveycore::get_freqs(d, x)` | Build `"freqs"` test fixtures |
| `surveycore::get_ratios(d, numerator, denominator)` | Build `"ratios"` test fixtures |
| `surveycore::as_survey(df, ...)` | Build survey design for test fixtures |

`meta<-` is NOT exported by surveycore. Direct `attr(result, ".meta") <- m`
is the only write mechanism. If surveycore exports a `meta<-` setter in a
future version, the implementations in `R/verbs-survey-result.R` should be
updated to use it.

### Interaction with `survey_base` verbs

`survey_result` and `survey_base` are completely separate class hierarchies.
Their verb methods do not interact. A user cannot pipe a `survey_base` object
into a `survey_result` verb or vice versa — dplyr dispatch routes each to its
appropriate method.

### Out-of-scope verbs on `survey_result` objects

Verbs not implemented in this feature (e.g., `group_by()`, `rowwise()`,
`distinct()`) fall through to the tibble dispatch and silently drop the class
and `.meta` attribute. This is the pre-existing behavior that this feature
is fixing for the in-scope verbs only. The out-of-scope behavior is unchanged
and documented here as a known limitation.

### dplyr/tidyr version requirements

No version change required. `NextMethod()` behavior with dplyr's
`UseMethod()` dispatch is consistent across `dplyr >= 1.1.0`. The
`tidyselect::eval_select()` and `tidyselect::eval_rename()` API used here
is stable across `tidyselect >= 1.2.0`.

