# Changelog

## surveytidy 0.1.0

First release. Implements a complete set of dplyr and tidyr verbs for
survey design objects created with the `surveycore` package.

### New verbs

- [`filter()`](https://dplyr.tidyverse.org/reference/filter.html) —
  domain-aware filtering. Marks rows in-domain rather than removing
  them, preserving correct variance estimation for subpopulation
  analyses. Chained
  [`filter()`](https://dplyr.tidyverse.org/reference/filter.html) calls
  AND their conditions together.

- [`select()`](https://dplyr.tidyverse.org/reference/select.html) —
  column selection. Physically removes non-selected columns while always
  retaining design variables (weights, strata, PSU, FPC, replicate
  weights). Sets `@variables$visible_vars` so
  [`print()`](https://rdrr.io/r/base/print.html) hides design columns
  the user did not explicitly request.

- [`relocate()`](https://dplyr.tidyverse.org/reference/relocate.html) —
  column reordering. Reorders `visible_vars` when a prior
  [`select()`](https://dplyr.tidyverse.org/reference/select.html) has
  been called; reorders `@data` directly otherwise.

- [`pull()`](https://dplyr.tidyverse.org/reference/pull.html) — extract
  a column as a plain vector (terminal operation).

- [`glimpse()`](https://pillar.r-lib.org/reference/glimpse.html) —
  concise column summary, respecting `visible_vars`.

- [`mutate()`](https://dplyr.tidyverse.org/reference/mutate.html) — add
  or modify columns. Re-attaches design variables dropped by
  `.keep = "none"` or `.keep = "used"`. Issues
  `surveytidy_warning_mutate_design_var` when a mutation’s left-hand
  side names a design variable. Respects `@groups` set by
  [`group_by()`](https://dplyr.tidyverse.org/reference/group_by.html).

- [`rename()`](https://dplyr.tidyverse.org/reference/rename.html) —
  rename columns. Automatically keeps `@variables` (design
  specification) and `@metadata` (variable labels, value labels, etc.)
  in sync with the new column names. Issues
  `surveytidy_warning_rename_design_var` when a design variable is
  renamed.

- [`arrange()`](https://dplyr.tidyverse.org/reference/arrange.html) —
  row sorting. The domain column moves correctly with the rows after
  sorting. Supports `.by_group = TRUE` using `@groups`.

- [`slice()`](https://dplyr.tidyverse.org/reference/slice.html),
  [`slice_head()`](https://dplyr.tidyverse.org/reference/slice.html),
  [`slice_tail()`](https://dplyr.tidyverse.org/reference/slice.html),
  [`slice_min()`](https://dplyr.tidyverse.org/reference/slice.html),
  [`slice_max()`](https://dplyr.tidyverse.org/reference/slice.html),
  [`slice_sample()`](https://dplyr.tidyverse.org/reference/slice.html) —
  physical row selection with a `surveycore_warning_physical_subset`
  warning. `slice_sample(weight_by = )` additionally issues
  `surveytidy_warning_slice_sample_weight_by` to flag that the
  `weight_by` column is independent of the survey design weights.

- [`group_by()`](https://dplyr.tidyverse.org/reference/group_by.html) —
  store grouping columns in `@groups`. Does not attach a `grouped_df`
  attribute to `@data`; grouping is kept on the survey object. Supports
  `.add = TRUE` for incremental grouping and computed expressions (e.g.,
  `group_by(d, above_median = y1 > median(y1))`).

- [`ungroup()`](https://dplyr.tidyverse.org/reference/group_by.html) —
  remove all groups (no arguments) or remove specific columns from
  `@groups` (partial ungroup).

- [`drop_na()`](https://tidyr.tidyverse.org/reference/drop_na.html) —
  physical row removal for rows with `NA` in specified columns (or any
  column). Issues `surveycore_warning_physical_subset`.

- [`subset()`](https://rdrr.io/r/base/subset.html) — physical row
  removal with `surveycore_warning_physical_subset`. Prefer
  [`filter()`](https://dplyr.tidyverse.org/reference/filter.html) for
  subpopulation analyses.

### Statistical design

The key design decision in surveytidy is that
**[`filter()`](https://dplyr.tidyverse.org/reference/filter.html) never
removes rows**. Removing rows from a survey design changes which units
contribute to variance estimation and produces incorrect standard errors
for subpopulation statistics.
[`filter()`](https://dplyr.tidyverse.org/reference/filter.html) instead
writes a logical domain column (`..surveycore_domain..`) to `@data`.
Phase 1 estimation functions will read this column to restrict
calculations to the domain while retaining all rows for variance
estimation.

### Infrastructure

- `dplyr_reconstruct.survey_base()` ensures complex dplyr pipelines
  (joins,
  [`across()`](https://dplyr.tidyverse.org/reference/across.html),
  internal slice operations) return survey objects rather than plain
  tibbles. Errors with `surveycore_error_design_var_removed` if a
  pipeline drops a design variable.

- Invariant 6 added to `test_invariants()`: every column name listed in
  `@variables$visible_vars` must exist in `@data`.
