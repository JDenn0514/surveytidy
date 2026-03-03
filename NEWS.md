# surveytidy 0.2.0

## New verbs

* `filter_out()` — the complement of `filter()`. Marks rows matching the
  condition as out-of-domain while leaving all other rows in-domain. Like
  `filter()`, no rows are removed. Chains with `filter()` via AND-accumulation
  on the domain column. `filter_out(d, group == "control")` is often clearer
  than `filter(d, group != "control")` for exclusion use-cases.

* `distinct()` — removes duplicate rows while always retaining all columns
  (design variables are never dropped). With no column arguments, deduplicates
  on non-design columns only (survey-safe default). Always issues
  `surveycore_warning_physical_subset`.

* `rename_with()` — function-based column renaming. Applies `.fn` to columns
  selected by `.cols` and propagates renames to `@variables`, `@metadata`,
  `@groups`, and `visible_vars`. Validates `.fn` output and errors with
  `surveytidy_error_rename_fn_bad_output` for non-character, wrong-length, or
  duplicate output.

* `rowwise()` — enables row-by-row computation in `mutate()` (e.g.,
  `max(c_across(...))`). Rowwise state is stored in `@variables$rowwise` —
  never in `@groups`, keeping those clean for estimation functions. `group_by()`
  and `ungroup()` exit rowwise mode, mirroring dplyr behaviour.

## New predicates

* `is_rowwise()` — returns `TRUE` when the survey object is in rowwise mode.
* `is_grouped()` — returns `TRUE` when `@groups` is non-empty.
* `group_vars()` — returns the current grouping column names from `@groups`.

## Verb support for `survey_result` objects

* `filter()`, `arrange()`, `mutate()`, `slice()`, `slice_head()`,
  `slice_tail()`, `slice_min()`, `slice_max()`, `slice_sample()`, and
  `drop_na()` are now registered for `survey_result` objects (the S3 base class
  for surveycore analysis outputs: `survey_means`, `survey_freqs`,
  `survey_totals`, `survey_quantiles`, `survey_corr`, `survey_ratios`).
  Previously, applying dplyr verbs to these objects could silently strip the
  class and `.meta` attribute. Now both are preserved, and `mutate()` keeps
  `meta$group` coherent when `.keep` drops grouping columns.

* `select()`, `rename()`, and `rename_with()` are now registered for
  `survey_result` objects with active `.meta` updates. `select()` prunes stale
  `meta$group` entries when grouping columns are dropped and handles inline
  renames (`select(r, grp = group)`). `rename()` and `rename_with()` propagate
  column renames to all `.meta` key references (`$group`, `$x`,
  `$numerator$name`, `$denominator$name`). `rename_with()` errors with
  `surveytidy_error_rename_fn_bad_output` if `.fn` returns non-character,
  wrong-length, `NA`, or duplicate names.

## Bug fixes

* `drop_na()` now performs domain-aware filtering instead of physically removing
  rows. Previously, `drop_na()` removed rows with `NA` values, changing which
  units contributed to variance estimation and producing incorrect standard
  errors. It now marks incomplete rows as out-of-domain — equivalent to the
  corresponding `filter(!is.na(col1), ...)` chain — giving correct variance
  estimates for downstream analyses.

* `filter()`: the `.by` unsupported-argument error was mis-classified as a
  `surveycore_error_*`; corrected to `surveytidy_error_filter_by_unsupported`.

## Improvements

* `rename()` and `rename_with()` now update `@groups` when a grouped column is
  renamed, and correctly update twophase design variable references
  (`@variables$phase1`, `@variables$phase2`, `@variables$subset`). The domain
  column (`..surveycore_domain..`) is silently protected from renaming.

* `filter()` and `filter_out()` support `if_any()` and `if_all()` in
  conditions.

## Documentation

* Roxygen documentation standardised across all verb files to mirror the
  dplyr/tidyr reference style, with `@details` subsections for
  surveytidy-specific behaviour and examples using `nhanes_2017`.

* Rd files consolidated from per-method (e.g., `arrange.survey_base.Rd`) to
  per-verb (e.g., `arrange.Rd`), fixing the "S3 methods shown with full name"
  R CMD check NOTE.

---

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

* `drop_na()` — domain-aware NA handling. Marks rows with `NA` in specified
  columns (or any column) as out-of-domain without removing them. Equivalent
  to `filter(!is.na(col1), !is.na(col2), ...)` and gives correct variance
  estimates for downstream analyses. Successive `drop_na()` calls AND their
  conditions together.

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
