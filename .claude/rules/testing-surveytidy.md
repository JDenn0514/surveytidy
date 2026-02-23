# surveytidy Testing: Package-Specific Standards

**Version:** 1.0
**Created:** February 2025
**Status:** Decided — do not re-litigate without updating this document

Extends [testing-standards.md](testing-standards.md). Read that document
first; this file covers only what is specific to surveytidy.

---

## Quick Reference

| Decision | Choice |
|----------|--------|
| Invariant checks | `test_invariants(design)` required as **first** assertion in every verb test block |
| All design types | Every verb tested with all three: taylor, replicate, twophase (via `make_all_designs()`) |
| Error testing | Dual: `expect_error(class=)` + `expect_snapshot(error=TRUE)` for all user-facing errors |
| Domain preservation | Assert domain column present and correct after every verb operation |
| Synthetic data | `make_all_designs(seed = N)` in `helper-test-data.R` |

---

## File Mapping

| Source file | Test file |
|-------------|-----------|
| `R/filter.R` | `tests/testthat/test-filter.R` |
| `R/select.R` | `tests/testthat/test-select.R` |
| `R/mutate.R` | `tests/testthat/test-mutate.R` |
| `R/rename.R` | `tests/testthat/test-rename.R` |
| `R/arrange.R` | `tests/testthat/test-arrange.R` (includes slice_*) |
| `R/group-by.R` | `tests/testthat/test-group-by.R` |
| `R/drop-na.R` | `tests/testthat/test-tidyr.R` |
| `R/utils.R` | (covered inline by other test files) |

---

## `test_invariants()` — required in every verb test block

Every `test_that()` block that creates or transforms a survey object must call
`test_invariants(design)` as its **first** assertion.

```r
test_that("filter() marks rows in domain without removing them", {
  designs <- make_all_designs(seed = 42)
  for (d in designs) {
    result <- dplyr::filter(d, y1 > 50)
    test_invariants(result)   # always first
    # ... further assertions
  }
})
```

`test_invariants()` is defined in `tests/testthat/helper-test-data.R` and
asserts all Phase 0.5 invariants:

1. `@data` is a data.frame
2. `@data` has >= 1 row
3. `@data` has no duplicate column names
4. All design variables exist in `@data` and are atomic
5. Weights are numeric and positive
6. Every column in `visible_vars` exists in `@data`

---

## Cross-Design Testing (REQUIRED for every verb)

Every verb must be tested with all three design types. Use `make_all_designs()`
and loop over the result:

```r
test_that("select() hides non-selected columns from print", {
  designs <- make_all_designs(seed = 42)
  for (d in designs) {
    result <- dplyr::select(d, y1, y2)
    test_invariants(result)
    expect_identical(result@variables$visible_vars, c("y1", "y2"))
  }
})
```

**Never write a verb test that only covers one design type.** The loop is
the minimum requirement. Add design-specific assertions inside the loop
when behavior differs by design type.

---

## Error Testing Pattern

All surveytidy errors are user-facing (there are no S7 class validators like
in surveycore). Use the **dual pattern** for every error test:

```r
test_that("filter() errors on non-logical condition", {
  designs <- make_all_designs(seed = 42)
  d <- designs$taylor

  # 1. Typed class check
  expect_error(
    dplyr::filter(d, y1 + 1),   # y1 + 1 is numeric, not logical
    class = "surveytidy_error_filter_non_logical"
  )

  # 2. Snapshot — verifies CLI message text
  expect_snapshot(error = TRUE, dplyr::filter(d, y1 + 1))
})
```

For warnings (e.g., empty domain after filter):

```r
test_that("filter() warns when result domain is empty", {
  d <- make_all_designs(seed = 42)$taylor

  expect_warning(
    result <- dplyr::filter(d, y1 > 9999),
    class = "surveycore_warning_empty_domain"
  )

  test_invariants(result)
  expect_true(all(!result@data[["..surveycore_domain.."]]))
})
```

---

## Domain Column Assertions

For `filter()` and any verb that should preserve the domain column:

```r
# After filter(), assert domain column exists and has correct type
expect_true(
  surveycore::SURVEYCORE_DOMAIN_COL %in% names(result@data)
)
expect_true(is.logical(result@data[[surveycore::SURVEYCORE_DOMAIN_COL]]))

# For accumulated filters (chaining), assert AND logic
d2 <- dplyr::filter(d1, y1 > 40)
d3 <- dplyr::filter(d2, y2 > 0)
expect_true(all(
  d3@data[[surveycore::SURVEYCORE_DOMAIN_COL]] ==
  (d1@data$y1 > 40 & d1@data$y2 > 0)
))

# Verbs other than filter() should preserve an existing domain column
d_filtered <- dplyr::filter(d, y1 > 40)
d_selected  <- dplyr::select(d_filtered, y1, y2)
expect_identical(
  d_selected@data[[surveycore::SURVEYCORE_DOMAIN_COL]],
  d_filtered@data[[surveycore::SURVEYCORE_DOMAIN_COL]]
)
```

---

## `visible_vars` Assertions

Assert `@variables$visible_vars` state for `select()` and verbs that may
affect it:

```r
# After select(): visible_vars is set to user selection
result <- dplyr::select(d, y1, y2)
expect_identical(result@variables$visible_vars, c("y1", "y2"))

# After select() choosing only design vars: visible_vars is NULL
result_dv <- dplyr::select(d, psu, strata)
expect_null(result_dv@variables$visible_vars)

# After other verbs (filter, mutate, etc.): visible_vars is unchanged
d_with_vv <- dplyr::select(d, y1, y2)
result <- dplyr::filter(d_with_vv, y1 > 40)
expect_identical(result@variables$visible_vars, c("y1", "y2"))
```

---

## `@groups` Assertions

Assert `@groups` state for `group_by()` and `ungroup()`:

```r
test_that("group_by() sets @groups to the specified columns", {
  d <- make_all_designs(seed = 42)$taylor
  result <- dplyr::group_by(d, group)
  test_invariants(result)
  expect_identical(result@groups, "group")
})

test_that("ungroup() clears @groups", {
  d <- dplyr::group_by(make_all_designs(seed = 42)$taylor, group)
  result <- dplyr::ungroup(d)
  test_invariants(result)
  expect_identical(result@groups, character(0))
})
```

---

## `make_all_designs()` and `make_survey_data()`

Both are defined in `tests/testthat/helper-test-data.R` (self-contained copy;
does not depend on surveycore's test helpers being installed).

```r
# make_all_designs: returns a named list of three designed objects
designs <- make_all_designs(seed = 42)
# designs$taylor    — survey_taylor
# designs$replicate — survey_replicate (BRR)
# designs$twophase  — survey_twophase

# make_survey_data: returns a plain data.frame
df <- make_survey_data(n = 200, n_psu = 20, n_strata = 4, seed = 123)
# Columns: psu, strata, fpc, wt, y1, y2, y3, group
# For design = "replicate": adds repwt_1, ..., repwt_R
# For design = "twophase": adds phase2_ind (logical)
```

**Data policy:**

| Test type | Data source |
|-----------|-------------|
| Verb unit tests (class, properties, error conditions) | `make_all_designs()` |
| Edge case data (1-row, all-NA, etc.) | Inline in tests |
| Numerical accuracy (future Phase 1) | Real datasets |

---

## Test File Section Templates

### `test-filter.R`
```
# 1. Happy paths — domain column created/updated for all 3 design types
# 2. Filter accumulation — chained filters AND the masks
# 3. Error paths — non-logical condition, .by= unsupported
# 4. Edge cases — all FALSE domain, single-row data, NA in condition
# 5. Domain column preservation through subsequent verbs
```

### `test-select.R`
```
# 1. Happy paths — visible_vars set correctly; design vars preserved in @data
# 2. select() with only design vars → visible_vars = NULL
# 3. Metadata removal — @metadata keys for dropped columns removed
# 4. Error paths — (none expected; tidy-select handles errors)
# 5. Edge cases — select everything, relocate, pull
```

### `test-mutate.R`
```
# 1. Happy paths — new column added; @data updated; @variables unchanged
# 2. Weight column mutation — warn with surveytidy_warning_mutate_weight_col
# 3. Error paths — (none expected beyond weight warning)
# 4. Edge cases — mutate existing column, mutate with across()
```

### `test-rename.R`
```
# 1. Happy paths — column renamed in @data, @variables, @metadata
# 2. Rename design variable — warns (surveytidy_warning_rename_design_var)
# 3. @variables keys updated — old key replaced with new column name
# 4. @metadata keys updated — old key replaced with new column name
# 5. Error paths — (none expected; tidy-select handles column not found)
```

### `test-arrange.R`
```
# 1. arrange() — happy paths for all 3 design types
# 2. arrange() — domain column preserved
# 3. slice_head(), slice_tail(), slice_sample(), slice_min(), slice_max()
# 4. Physical subsetting warning on all slice_* variants
```

### `test-group-by.R`
```
# 1. group_by() — @groups set correctly for all 3 design types
# 2. ungroup() — @groups cleared
# 3. add_tally() / count() behavior (if supported)
# 4. Error paths — grouping by non-existent column
```

### `test-tidyr.R`
```
# 1. drop_na() — domain-aware: marks rows with NA in specified cols as out-of-domain
# 2. drop_na() — no cols specified: marks rows with ANY NA as out-of-domain
# 3. drop_na() — accumulates with existing domain (AND logic)
# 4. Error paths / edge cases
```
