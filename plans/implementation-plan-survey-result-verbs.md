# Implementation Plan: dplyr/tidyr Verb Support for `survey_result` Objects

## Context

All six surveycore analysis functions (`get_freqs()`, `get_means()`, `get_totals()`,
`get_quantiles()`, `get_corr()`, `get_ratios()`) return S3 tibble subclasses with this
class hierarchy:

```r
c("survey_freqs", "survey_result", "tbl_df", "tbl", "data.frame")
```

A `.meta` attribute (accessed via `surveycore::meta()`) carries structured metadata:
always-present keys (`design_type`, `n_respondents`, `conf_level`, `call`, `group`, `x`)
plus function-specific keys (`probs`, `method`, `numerator`/`denominator`).

When users apply dplyr verbs to these result objects, the default tibble dispatch
silently drops both the custom class and `.meta`. This PR series adds `survey_result`
methods that preserve class and `.meta`, with active meta updates for column-touching verbs.

Key constraint: surveycore exports only `meta()` getter — no `meta<-` setter.
We use `attr(result, ".meta") <- new_meta` directly (same pattern `select.survey_base`
uses for `@metadata`).

---

## Critical Files

| File | Action |
|------|--------|
| `R/zzz.R` | Add `registerS3method()` calls for all `survey_result` methods |
| `R/verbs-survey-result.R` | **New file** — all verb implementations |
| `R/utils.R` | Add `.apply_result_rename_map()` and `.prune_result_meta()` helpers |
| `tests/testthat/helper-test-data.R` | Add `make_survey_result()` and `test_result_invariants()` |
| `tests/testthat/test-verbs-survey-result.R` | **New file** — all tests |
| `plans/error-messages.md` | No new errors/warnings needed |

---

## Key Architecture Decisions

### 1. S3 dispatch via `registerS3method()` (same as existing pattern)

`survey_result` is a plain S3 class (not S7), so standard dispatch would work, but
for consistency with the existing `survey_base` pattern, all methods are registered via
`registerS3method()` in `.onLoad()`.

### 2. Class + meta preservation pattern (passthrough verbs)

For row-only verbs (filter, arrange, mutate, slice_*, drop_na) the `.meta` is preserved
verbatim. The pattern:

```r
filter.survey_result <- function(.data, ..., .by = NULL, .preserve = FALSE) {
  old_class <- class(.data)
  old_meta  <- attr(.data, ".meta")
  result    <- NextMethod()            # calls filter.tbl_df
  attr(result, ".meta") <- old_meta
  class(result) <- old_class
  result
}
```

`NextMethod()` works here because dplyr's `UseMethod("filter")` sets `.Generic`/.Class
correctly when the method is dispatched.

### 3. Shared rename helper: `.apply_result_rename_map()`

Analogous to `.apply_rename_map()` in `R/rename.R`. Handles:
- Tibble column rename (via `names()` assignment)
- `$group` list key rename
- `$x` list key rename
- `$numerator$name` / `$denominator$name` update (ratios only)

```r
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
    if (old_names[i] %in% names(m$group))
      names(m$group)[names(m$group) == old_names[i]] <- new_names[i]
  }

  # x keys
  if (!is.null(m$x)) {
    for (i in seq_along(old_names)) {
      if (old_names[i] %in% names(m$x))
        names(m$x)[names(m$x) == old_names[i]] <- new_names[i]
    }
  }

  # numerator / denominator names (get_ratios)
  if (!is.null(m$numerator$name) && m$numerator$name %in% names(rename_map))
    m$numerator$name <- rename_map[[m$numerator$name]]
  if (!is.null(m$denominator$name) && m$denominator$name %in% names(rename_map))
    m$denominator$name <- rename_map[[m$denominator$name]]

  attr(result, ".meta") <- m
  result
}
```

### 4. Shared select helper: `.prune_result_meta()`

Removes stale meta references when columns are dropped:

```r
.prune_result_meta <- function(meta, kept_cols) {
  # Remove group entries for dropped group columns
  meta$group <- meta$group[names(meta$group) %in% kept_cols]

  # Remove x entries for dropped focal columns; NULL if all focal cols dropped
  if (!is.null(meta$x)) {
    meta$x <- meta$x[names(meta$x) %in% kept_cols]
    if (length(meta$x) == 0L) meta$x <- NULL
  }

  meta
}
```

---

## PR 1: `feature/survey-result-passthrough`

**Scope**: passthrough verbs + test infrastructure.

### Files Changed

**`R/verbs-survey-result.R`** (new file) — passthrough implementations:

Verbs: `filter`, `arrange`, `mutate`, `slice`, `slice_head`, `slice_tail`,
`slice_min`, `slice_max`, `slice_sample`, `drop_na`.

All follow the same pattern (using `NextMethod()` to call into the tbl_df dispatch,
then restoring class and `.meta`). Roxygen docs note that `.meta` is preserved verbatim
and `n_respondents` is not updated.

**`R/utils.R`**: add `.apply_result_rename_map()` and `.prune_result_meta()` helpers
(used in PR 2; defined here to keep utils self-contained).

**`R/zzz.R`**: add a new `# ── survey_result verbs ─────────` section with
`registerS3method()` calls for all 10 passthrough methods (dplyr verbs → dplyr ns,
`drop_na` → tidyr ns).

**`tests/testthat/helper-test-data.R`**: add two helpers:

```r
make_survey_result <- function(type = c("means", "freqs", "ratios"), seed = 42) {
  type <- match.arg(type)
  df <- make_survey_data(seed = seed)
  d  <- surveycore::as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  switch(type,
    means  = surveycore::get_means(d, x = y1, group = group),
    freqs  = surveycore::get_freqs(d, x = group),
    ratios = surveycore::get_ratios(d, numerator = y1, denominator = y2)
  )
}

test_result_invariants <- function(result, expected_class) {
  # mirrors surveycore's version; copied here so tests are self-contained
  testthat::expect_true(inherits(result, expected_class))
  testthat::expect_true(inherits(result, "survey_result"))
  testthat::expect_true(tibble::is_tibble(result))
  m <- surveycore::meta(result)
  testthat::expect_false(is.null(m))
  testthat::expect_type(m, "list")
  required <- c("design_type", "conf_level", "call", "group", "n_respondents")
  testthat::expect_true(all(required %in% names(m)))
  testthat::expect_type(m$group, "list")
  testthat::expect_type(m$n_respondents, "integer")
  invisible(result)
}
```

**`tests/testthat/test-verbs-survey-result.R`** (new file):
- Happy paths for each passthrough verb across `means`, `freqs`, `ratios` result types
- Assert class and `.meta` survive every operation unchanged
- Assert row counts change correctly for filter/slice
- Assert `n_respondents` is NOT updated after filter

### Example test block

```r
test_that("filter.survey_result preserves class and meta unchanged", {
  result <- make_survey_result(type = "means")
  filtered <- dplyr::filter(result, mean > 0)

  test_result_invariants(filtered, "survey_means")
  expect_identical(
    surveycore::meta(filtered),
    surveycore::meta(result)
  )
  expect_lt(nrow(filtered), nrow(result))
})
```

---

## PR 2: `feature/survey-result-meta`

**Scope**: column-touching verbs that actively update `.meta`.

### Files Changed

**`R/verbs-survey-result.R`** (extend): add `select`, `rename`, `rename_with` implementations.

**`R/zzz.R`**: add `registerS3method()` calls for `select`, `rename`, `rename_with`.

**`tests/testthat/test-verbs-survey-result.R`** (extend): meta-coherence test blocks.

### `select.survey_result` implementation sketch

```r
select.survey_result <- function(.data, ...) {
  old_class <- class(.data)
  old_meta  <- attr(.data, ".meta")

  # Resolve selection; apply to underlying tibble
  pos    <- tidyselect::eval_select(rlang::expr(c(...)), tibble::as_tibble(.data))
  result <- tibble::as_tibble(.data)[, names(pos), drop = FALSE]

  # Prune meta for dropped columns
  new_meta <- .prune_result_meta(old_meta, names(pos))
  attr(result, ".meta") <- new_meta
  class(result) <- old_class
  result
}
```

### `rename.survey_result` implementation sketch

```r
rename.survey_result <- function(.data, ...) {
  map <- tidyselect::eval_rename(rlang::expr(c(...)), tibble::as_tibble(.data))
  rename_map <- stats::setNames(names(map), names(tibble::as_tibble(.data))[map])
  .apply_result_rename_map(.data, rename_map)
}
```

### `rename_with.survey_result` implementation sketch

Mirrors `rename_with.survey_base`: resolve `.cols`, apply `.fn`, validate output,
build `rename_map`, delegate to `.apply_result_rename_map()`.

### Meta-coherence test helper

```r
# Assert that all column-name references in .meta actually exist in the result
test_result_meta_coherent <- function(result) {
  m    <- surveycore::meta(result)
  cols <- names(result)
  for (g in names(m$group)) {
    testthat::expect_true(g %in% cols, label = paste("group col", g, "in result"))
  }
  if (!is.null(m$x)) {
    for (v in names(m$x)) {
      testthat::expect_true(v %in% cols, label = paste("x col", v, "in result"))
    }
  }
  invisible(result)
}
```

### Example test blocks

```r
test_that("rename.survey_result updates group column key in meta", {
  result  <- make_survey_result(type = "means")  # has $group$group
  renamed <- dplyr::rename(result, grp = group)

  test_result_invariants(renamed, "survey_means")
  test_result_meta_coherent(renamed)
  m <- surveycore::meta(renamed)
  expect_true("grp" %in% names(m$group))
  expect_false("group" %in% names(m$group))
})

test_that("select.survey_result removes group entry from meta when group col dropped", {
  result   <- make_survey_result(type = "means")   # has $group$group
  selected <- dplyr::select(result, mean, se)

  test_result_invariants(selected, "survey_means")
  m <- surveycore::meta(selected)
  expect_length(m$group, 0L)   # group was dropped
})

test_that("select.survey_result sets x to NULL when focal col dropped", {
  result   <- make_survey_result(type = "means")   # has $x$y1
  selected <- dplyr::select(result, group)

  test_result_invariants(selected, "survey_means")
  m <- surveycore::meta(selected)
  expect_null(m$x)
})
```

---

## Registration Pattern (`R/zzz.R` additions)

All methods registered for `"survey_result"` (not per-subclass). S3 dispatch
walks `survey_freqs → survey_result → tbl_df`, so one registration covers all
six result subclasses automatically.

Each verb gets an individual `registerS3method()` call (matching the existing
`survey_base` style — no for-loops):

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

## Verification

1. `devtools::load_all()` — no errors on load
2. `devtools::test()` — all tests pass (confirm class + meta survive all passthrough verbs; confirm meta updated correctly by select/rename)
3. `devtools::check()` — 0 errors, 0 warnings, ≤2 notes
4. Spot-check interactively:
   ```r
   library(surveytidy); library(surveycore)
   d <- as_survey(pew_npors_2025, weights = weight, strata = stratum)
   r <- get_means(d, x = agecat, group = gender)
   r2 <- dplyr::rename(r, sex = gender)
   meta(r2)$group   # should have "sex" key, not "gender"
   r3 <- dplyr::select(r, sex, mean, se)
   meta(r3)$group   # should have "sex" key (preserved, not dropped)
   ```
