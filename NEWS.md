# surveytidy 0.1.0

First release. Implements a complete set of dplyr and tidyr verbs for survey
design objects created with the `surveycore` package.

## New verbs

* `filter()` — domain-aware filtering. Marks rows in-domain rather than
  removing them, preserving correct variance estimation for subpopulation
  analyses. Chained `filter()` calls AND their conditions together.

* `select()` — column selection. Physically removes non-selected columns while
  always retaining design variables (weights, strata, PSU, FPC, replicate
  weights). Sets `@variables$visible_vars` so `print()` hides design columns
  the user did not explicitly request.

* `relocate()` — column reordering. Reorders `visible_vars` when a prior
  `select()` has been called; reorders `@data` directly otherwise.

* `pull()` — extract a column as a plain vector (terminal operation).

* `glimpse()` — concise column summary, respecting `visible_vars`.

* `mutate()` — add or modify columns. Re-attaches design variables dropped by
  `.keep = "none"` or `.keep = "used"`. Issues
  `surveytidy_warning_mutate_design_var` when a mutation's left-hand side names
  a design variable. Respects `@groups` set by `group_by()`.

* `rename()` — rename columns. Automatically keeps `@variables` (design
  specification) and `@metadata` (variable labels, value labels, etc.) in sync
  with the new column names. Issues `surveytidy_warning_rename_design_var` when
  a design variable is renamed.

* `arrange()` — row sorting. The domain column moves correctly with the rows
  after sorting. Supports `.by_group = TRUE` using `@groups`.

* `slice()`, `slice_head()`, `slice_tail()`, `slice_min()`, `slice_max()`,
  `slice_sample()` — physical row selection with a
  `surveycore_warning_physical_subset` warning. `slice_sample(weight_by = )`
  additionally issues `surveytidy_warning_slice_sample_weight_by` to flag that
  the `weight_by` column is independent of the survey design weights.

* `group_by()` — store grouping columns in `@groups`. Does not attach a
  `grouped_df` attribute to `@data`; grouping is kept on the survey object.
  Supports `.add = TRUE` for incremental grouping and computed expressions
  (e.g., `group_by(d, above_median = y1 > median(y1))`).

* `ungroup()` — remove all groups (no arguments) or remove specific columns
  from `@groups` (partial ungroup).

* `drop_na()` — physical row removal for rows with `NA` in specified columns
  (or any column). Issues `surveycore_warning_physical_subset`.

* `subset()` — physical row removal with `surveycore_warning_physical_subset`.
  Prefer `filter()` for subpopulation analyses.

## Statistical design

The key design decision in surveytidy is that **`filter()` never removes rows**.
Removing rows from a survey design changes which units contribute to variance
estimation and produces incorrect standard errors for subpopulation statistics.
`filter()` instead writes a logical domain column (`..surveycore_domain..`) to
`@data`. Phase 1 estimation functions will read this column to restrict
calculations to the domain while retaining all rows for variance estimation.

## Infrastructure

* `dplyr_reconstruct.survey_base()` ensures complex dplyr pipelines (joins,
  `across()`, internal slice operations) return survey objects rather than
  plain tibbles. Errors with `surveycore_error_design_var_removed` if a
  pipeline drops a design variable.

* Invariant 6 added to `test_invariants()`: every column name listed in
  `@variables$visible_vars` must exist in `@data`.
