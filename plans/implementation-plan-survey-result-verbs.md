# Implementation Plan: dplyr/tidyr Verb Support for `survey_result` Objects

**Spec:** `plans/spec-survey-result-verbs.md` (v0.2 — all Pass 1 and Pass 2 issues resolved)
**Decisions log:** `plans/claude-decisions-survey-result-verbs.md`
**Date:** 2026-03-02

## Overview

This plan delivers 13 S3 verb methods for the `survey_result` base class, split
across two PRs. PR 1 ships 10 passthrough verbs plus all shared test infrastructure.
PR 2 ships 3 meta-updating verbs (`select`, `rename`, `rename_with`). Both PRs write
to a single new source file (`R/verbs-survey-result.R`) and a single new test file.
No new error/warning classes are introduced.

---

## PR Map

- [x] PR 1: `feature/survey-result-passthrough` — passthrough verbs + full test infrastructure
- [x] PR 2: `feature/survey-result-meta` — meta-updating verbs (`select`, `rename`, `rename_with`)

---

## PR 1: Passthrough Verbs + Test Infrastructure

**Branch:** `feature/survey-result-passthrough`
**Depends on:** none

### Files

- `R/verbs-survey-result.R` — new file; all three inline helpers +
  10 passthrough verb implementations
- `R/zzz.R` — extend `.onLoad()` with `registerS3method()` calls for all 10 passthrough methods
- `tests/testthat/helper-test-data.R` — extend with `make_survey_result()`,
  `test_result_invariants()`, and `test_result_meta_coherent()`
- `tests/testthat/test-verbs-survey-result.R` — new file; PR 1 test sections (see below)
- `NEWS.md` — add changelog bullet

### Acceptance criteria

- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] `devtools::load_all()` — no errors; all 10 passthrough verbs registered
- [ ] Test section 1: every passthrough verb loops over all 3 result types (`"means"`, `"freqs"`, `"ratios"`) × all 3 design types (`"taylor"`, `"replicate"`, `"twophase"`)
- [ ] Test section 2: row-changing verbs (`filter`, `slice_head`, `slice_tail`) show correct row counts including 0-row edge case
- [ ] Test sections 3 / 3b / 3c: `mutate()` happy path + `.keep = "none"` and `.keep = "used"` meta coherence
- [ ] Test section 4: `n_respondents` unchanged after `filter()`
- [ ] Test sections 23–26: `drop_na()` primary happy path, `filter(.by)`, `slice_min`/`slice_max` non-default args, `slice_sample(replace = TRUE)` over-sampling
- [ ] Test section 29: `drop_na()` with no NAs — all rows preserved; class and meta identical
- [ ] `test_result_invariants()` is the first assertion in every non-error test block
- [ ] `test_result_meta_coherent()` called after meta-coherence-sensitive blocks (3b, 3c)
- [ ] No snapshot committed unless dplyr issues a message for the 0-row `filter()` edge case (per spec Section IX)
- [ ] Changelog entry: `NEWS.md` bullet added for passthrough verbs

### Implementation notes

**Three inline helpers — defined at the top of `R/verbs-survey-result.R`**

All three live at file scope (not inside any verb function) because all call
sites are within this one file (code-style.md §4):

```r
.restore_survey_result <- function(result, old_class, old_meta) {
  attr(result, ".meta") <- old_meta
  class(result) <- old_class
  result
}

.prune_result_meta <- function(meta, kept_cols) {
  meta$group <- meta$group[names(meta$group) %in% kept_cols]
  if (!is.null(meta$x)) {
    meta$x <- meta$x[names(meta$x) %in% kept_cols]
    if (length(meta$x) == 0L) meta$x <- NULL
  }
  if (!is.null(meta$numerator) &&
      !is.null(meta$numerator$name) &&
      !meta$numerator$name %in% kept_cols) {
    meta$numerator <- NULL
  }
  if (!is.null(meta$denominator) &&
      !is.null(meta$denominator$name) &&
      !meta$denominator$name %in% kept_cols) {
    meta$denominator <- NULL
  }
  meta
}

.apply_result_rename_map <- function(result, rename_map) {
  if (length(rename_map) == 0L) return(result)
  old_names <- names(rename_map)
  new_names <- unname(rename_map)

  # 1. Rename tibble columns
  col_pos <- match(old_names, names(result))
  names(result)[col_pos[!is.na(col_pos)]] <- new_names[!is.na(col_pos)]

  # 2. Update .meta
  m <- attr(result, ".meta")

  # group keys
  for (i in seq_along(old_names)) {
    idx <- match(old_names[i], names(m$group))
    if (!is.na(idx)) names(m$group)[idx] <- new_names[i]
  }

  # x keys
  if (!is.null(m$x)) {
    for (i in seq_along(old_names)) {
      idx <- match(old_names[i], names(m$x))
      if (!is.na(idx)) names(m$x)[idx] <- new_names[i]
    }
  }

  # numerator / denominator names (get_ratios results only)
  if (!is.null(m$numerator$name) && m$numerator$name %in% old_names)
    m$numerator$name <- new_names[match(m$numerator$name, old_names)]
  if (!is.null(m$denominator$name) && m$denominator$name %in% old_names)
    m$denominator$name <- new_names[match(m$denominator$name, old_names)]

  attr(result, ".meta") <- m
  result
}
```

**Passthrough verb pattern — 8 verbs (all except `drop_na`)**

```r
verb.survey_result <- function(.data, ...) {
  old_class <- class(.data)
  old_meta  <- attr(.data, ".meta")
  NextMethod() |> .restore_survey_result(old_class, old_meta)
}
```

Each verb declaration must match the generic's full signature (including all
named arguments) so `NextMethod()` can forward them correctly. See spec
Sections III.2–III.6 for exact signatures for each verb.

**`mutate.survey_result` diverges from pure passthrough**

After `.restore_survey_result()`, call `.prune_result_meta()` to maintain
meta coherence when `.keep` drops columns. This is a no-op for the common
case (`.keep = "all"`):

```r
mutate.survey_result <- function(
  .data, ...,
  .keep = c("all", "used", "unused", "none"),
  .before = NULL,
  .after = NULL
) {
  old_class <- class(.data)
  old_meta  <- attr(.data, ".meta")
  result    <- NextMethod() |> .restore_survey_result(old_class, old_meta)
  new_meta  <- .prune_result_meta(attr(result, ".meta"), names(result))
  attr(result, ".meta") <- new_meta
  result
}
```

**`drop_na.survey_result` uses `data`, not `.data`**

tidyr's generic uses `data` as the argument name. Match it:

```r
drop_na.survey_result <- function(data, ...) {
  old_class <- class(data)
  old_meta  <- attr(data, ".meta")
  NextMethod() |> .restore_survey_result(old_class, old_meta)
}
```

**Do NOT add `dplyr_reconstruct.survey_result`**

The passthrough pattern captures and restores class + `.meta` explicitly.
A `dplyr_reconstruct` method would be unused and could interfere with `.meta`
restoration. See spec Section III.1 for the rationale.

**`zzz.R` additions — add after the existing `# ── feature/drop-na` block**

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
```

Registering against `"survey_result"` (not per-subclass) covers all six result
subclasses automatically via the dispatch chain
`survey_freqs → survey_result → tbl_df`.

**`helper-test-data.R` additions**

Add all three test helpers in PR 1; `test_result_meta_coherent()` is also
exercised by PR 1 sections 3b and 3c — all infrastructure belongs together:

`make_survey_result(type, design, seed)` — full signature:
```r
make_survey_result <- function(
  type   = c("means", "freqs", "ratios"),
  design = c("taylor", "replicate", "twophase"),
  seed   = 42L
)
```

Build via `make_survey_data()` + `surveycore::as_survey*()` constructor, then
call the appropriate surveycore analysis function. See spec Section V for the
complete `type → function` and `design → constructor` mapping.

For `"replicate"` and `"twophase"` designs, delegate to `make_all_designs()`
(already defined in the helper file) to reuse the existing constructor logic.

`test_result_invariants(result, expected_class)` — asserts all 8 invariants
from spec Section V. Called as the **first** assertion in every non-error
test block.

`test_result_meta_coherent(result)` — body is specified verbatim in spec
Section V. Checks `$group`, `$x`, `$numerator`, and `$denominator` references
against actual column names.

**PR 1 test sections to implement**

In `tests/testthat/test-verbs-survey-result.R`:

- Section 1: one `test_that()` block per verb, inner loop over all 3 types
  × all 3 designs — meta identical before/after. Use `paste0("survey_", type)`
  to derive `expected_class` from the `type` loop variable.
- Section 2: `filter`, `slice_head`, `slice_tail` row counts; 0-row edge case
- Section 3: `mutate()` adds column; meta unchanged
- Section 3b: `mutate(.keep = "none")` — only new col remains; group/x entries pruned
- Section 3c: `mutate(.keep = "used")` — only `se` and new col; group/x entries pruned
- Section 4: `n_respondents` unchanged after `filter()`
- Section 23: inject NAs into fixture; `drop_na(result, se)`; rows drop; meta preserved
- Section 24: `filter(result_means, mean > 0, .by = group)`; class/meta preserved
- Section 25: `slice_min(..., with_ties = FALSE)` and `slice_max(..., na_rm = TRUE)`
- Section 26: `slice_sample(result_means, n = nrow(...) + 1, replace = TRUE)`
- Section 29: `drop_na(result_means)` with no NAs injected — all rows preserved; class and meta identical

---

## PR 2: Meta-Updating Verbs

**Branch:** `feature/survey-result-meta`
**Depends on:** PR 1

### Files

- `R/verbs-survey-result.R` — extend with `select`, `rename`, `rename_with` implementations
- `R/zzz.R` — extend with `registerS3method()` calls for `select`, `rename`, `rename_with`
- `tests/testthat/test-verbs-survey-result.R` — extend with PR 2 test sections
- `plans/error-messages.md` — update source file column for
  `surveytidy_error_rename_fn_bad_output` to add `R/verbs-survey-result.R`
- `NEWS.md` — add changelog bullet

### Acceptance criteria

- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] `devtools::load_all()` — all 13 verbs (PR 1 + PR 2) registered
- [ ] `test_result_meta_coherent()` called after every meta-updating verb test block
- [ ] Test sections 5–9: all `rename()` cases (group key, x key, non-meta col, numerator, denominator)
- [ ] Test sections 10–11: `rename_with()` happy paths (all cols, scoped `.cols`)
- [ ] Test section 12: parameterized error loop for all four bad-`.fn` triggers with snapshot
- [ ] Test sections 13–16b: `select()` cases including rename-in-select (16b)
- [ ] Test sections 17–18: `result_freqs` with empty `$group` list path
- [ ] Test section 19: chained `rename() |> select()` integration
- [ ] Test sections 20–22: zero-match `.cols`, identity rename, `...` forwarding to `.fn`
- [ ] Test section 27: zero-column `select()` degenerate result
- [ ] Test section 28: `select(everything())` — all meta unchanged, class preserved
- [ ] Snapshot committed for `surveytidy_error_rename_fn_bad_output` from `rename_with.survey_result`
- [ ] `plans/error-messages.md` source file column updated
- [ ] Changelog entry: `NEWS.md` bullet added for meta-updating verbs

### Implementation notes

**`select.survey_result` — full implementation steps**

Step 0: `tbl <- tibble::as_tibble(.data)`; `old_class <- class(.data)`

Step 1: Resolve selection:
```r
selected_cols <- tidyselect::eval_select(rlang::expr(c(...)), tbl)
```
Returns a named integer vector: output column name → position in `tbl`.

Step 2: Extract names:
```r
original_names <- names(tbl)[unname(selected_cols)]
output_names   <- names(selected_cols)
```

Step 3: Detect and apply any inline renames (e.g., `select(r, grp = group)`):
```r
rename_mask <- original_names != output_names
if (any(rename_mask)) {
  rename_map <- stats::setNames(
    output_names[rename_mask], original_names[rename_mask]
  )
  .data <- .apply_result_rename_map(.data, rename_map)
}
```

Step 4: Subset to selected columns:
```r
result <- .data[, output_names, drop = FALSE]
```

Step 5: Prune meta for dropped columns:
```r
new_meta <- .prune_result_meta(attr(.data, ".meta"), output_names)
```

Step 6: Assign and restore:
```r
attr(result, ".meta") <- new_meta
class(result) <- old_class
result
```

Zero-column edge case: `tidyselect::eval_select()` returns `integer(0)`;
`.prune_result_meta()` produces `meta$group = list()` and `meta$x = NULL`;
`test_result_invariants()` still passes. No special handling needed.

**`rename.survey_result`**

Step 0: `tbl <- tibble::as_tibble(.data)`

Step 1: Build rename map:
```r
map        <- tidyselect::eval_rename(rlang::expr(c(...)), tbl)
rename_map <- stats::setNames(names(map), names(tbl)[map])
```
`eval_rename` returns a named integer vector (new name → column position).
`names(tbl)[map]` extracts the old names at those positions.
`setNames(new_names, old_names)` → `c(old_name = "new_name")` format.

Step 2: Delegate:
```r
.apply_result_rename_map(.data, rename_map)
```

Identity rename (`rename(r, col = col)`) produces an empty or self-referential
map; `.apply_result_rename_map()` with `length(rename_map) == 0L` returns
`.data` unchanged. This is the documented no-op case.

**`rename_with.survey_result`**

Step 0: `tbl <- tibble::as_tibble(.data)`

Step 1: Resolve `.cols`:
```r
resolved_cols <- tidyselect::eval_select(rlang::enquo(.cols), tbl)
```

Step 2: Extract old names: `old_names <- names(resolved_cols)`

If `length(old_names) == 0L`, skip to step 6 (return `.data` unchanged).

Step 3: Apply `.fn`:
```r
new_names <- .fn(old_names, ...)
```

Step 4: Validate output — all four checks required:
```r
if (!is.character(new_names) ||
    length(new_names) != length(old_names) ||
    anyNA(new_names) ||
    anyDuplicated(replace(names(tbl), match(old_names, names(tbl)), new_names)) > 0L) {
  cli::cli_abort(
    c(
      "x" = "{.arg .fn} must return a character vector the same length as
             its input with no {.code NA} or duplicate names.",
      "i" = "Got class {.cls {class(new_names)}} of length {length(new_names)}."
    ),
    class = "surveytidy_error_rename_fn_bad_output"
  )
}
```

The duplicate-names check (`anyDuplicated`) must be performed against the
**full column list** — merge the renamed values back into all column names
before checking. The inline check above does this via `replace()`.

Step 5: Build rename map:
```r
rename_map <- stats::setNames(new_names, old_names)
```

Step 6: Delegate:
```r
.apply_result_rename_map(.data, rename_map)
```

**`zzz.R` additions for PR 2**

```r
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

**Test section 12 — parameterized error loop**

```r
test_that("rename_with.survey_result errors for all invalid .fn outputs", {
  result_means <- make_survey_result(type = "means")
  bad_fns <- list(
    "non-character output" = function(x) seq_along(x),
    "wrong-length output"  = function(x) x[1],
    "NA in output"         = function(x) { x[1] <- NA_character_; x },
    "duplicate names"      = function(x) rep(x[1], length(x))
  )
  for (label in names(bad_fns)) {
    fn <- bad_fns[[label]]
    expect_error(
      dplyr::rename_with(result_means, fn),
      class = "surveytidy_error_rename_fn_bad_output"
    )
    expect_snapshot(error = TRUE, dplyr::rename_with(result_means, fn))
  }
})
```

Four snapshot entries will be committed to `tests/testthat/_snaps/`, each
keyed by `label`.

**`plans/error-messages.md` update**

In the `surveytidy_error_rename_fn_bad_output` row, add `R/verbs-survey-result.R`
to the source file column (it was previously only in `R/rename.R` or wherever
`rename_with.survey_base` lives).

**PR 2 test sections to implement**

- Section 5: `rename(result_means, grp = group)` — `"grp"` in group keys
- Section 6: `rename(result_means, outcome = y1)` — `"outcome"` in x keys
- Section 7: rename non-meta col (`se → std_error`) — meta unchanged
- Section 8: `rename(result_ratios, numer = y1)` — numerator$name updated
- Section 9: `rename(result_ratios, denom = y2)` — denominator$name updated
- Section 10: `rename_with(result_means, toupper)` — all names + meta keys uppercased
- Section 11: `rename_with(result_means, toupper, .cols = c(mean, se))` — group/x keys unchanged
- Section 12: parameterized error loop (see above)
- Section 13: `select(result_means, mean, se)` — group entry removed
- Section 14: `select(result_means, group)` — `meta$x` set to NULL
- Section 15: `select(result_means, group, mean, se)` — group sub-keys preserved; `meta$x` NULL (y1 dropped)
- Section 16: `select(result_means, -se)` — group and x meta unchanged
- Section 16b: `select(result_means, grp = group)` — meta$group key updated to `"grp"`
- Section 17: `rename(result_freqs, grp = group)` — x key updated; empty group list unchanged
- Section 18: `select(result_freqs, mean, se)` — meta$x NULL; empty group list unchanged
- Section 19: `result_means |> rename(grp = group) |> select(grp, y1, mean)`
- Section 20: `rename_with(result_means, toupper, .cols = dplyr::starts_with("zzz"))` — no-op
- Section 21: `rename(result_means, group = group)` — identity rename no-op
- Section 22: `rename_with(result_means, gsub, pattern = "mean", replacement = "avg")`
- Section 27: `select(result_means, dplyr::starts_with("zzz"))` — 0-column result valid
- Section 28: `select(result_means, dplyr::everything())` — all columns kept; meta identical to input

---

## Quality Gate Checklist (both PRs)

Before opening either PR:

- [ ] `devtools::load_all()` — no errors
- [ ] `devtools::test(filter = "verbs-survey-result")` — all tests pass
- [ ] `devtools::test()` — no regressions in existing tests
- [ ] `devtools::check()` — 0 errors, 0 warnings, ≤2 notes
- [ ] `covr::package_coverage()` or equivalent — `verbs-survey-result` coverage ≥ 95%
