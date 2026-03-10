# Changelog

## surveytidy 0.3.0

### New features

#### Survey-aware recoding functions

Six vector-level recoding functions are now available. Each shadows its
dplyr equivalent and adds optional arguments for attaching variable
labels, value labels, and transformation notes directly inside
[`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md).
Without any of those arguments, output is identical to dplyr.

- [`case_when()`](https://jdenn0514.github.io/surveytidy/reference/case_when.md)
  — a survey-aware
  [`dplyr::case_when()`](https://dplyr.tidyverse.org/reference/case-and-replace-when.html).
  Evaluates a sequence of `condition ~ value` formulas and uses the
  first match for each element. Use this to create an entirely new
  vector from conditions. Accepts `.label` to set a variable label,
  `.value_labels` to attach a named vector of value labels,
  `.factor = TRUE` to return an ordered factor (levels follow formula
  order), and `.description` to record a plain-language note about the
  transformation.

- [`if_else()`](https://jdenn0514.github.io/surveytidy/reference/if_else.md)
  — a survey-aware
  [`dplyr::if_else()`](https://dplyr.tidyverse.org/reference/if_else.html).
  Applies a single binary condition element-wise
  (`true`/`false`/`missing`). Stricter than base
  [`ifelse()`](https://rdrr.io/r/base/ifelse.html): `true`, `false`, and
  `missing` are cast to a common type. Accepts `.label`,
  `.value_labels`, and `.description`.

- [`na_if()`](https://jdenn0514.github.io/surveytidy/reference/na_if.md)
  — a survey-aware
  [`dplyr::na_if()`](https://dplyr.tidyverse.org/reference/na_if.html).
  Converts specific values to `NA`. Unlike dplyr’s scalar-only `y`, this
  version accepts a vector `y` and replaces all matching values in a
  single call. When the input carries value labels, they are inherited
  automatically; `.update_labels = TRUE` (the default) removes label
  entries for the NA’d values, while `.update_labels = FALSE` retains
  them (useful for documenting what was set to missing). Also accepts
  `.description`.

- [`recode_values()`](https://jdenn0514.github.io/surveytidy/reference/recode_values.md)
  — a survey-aware
  [`dplyr::recode_values()`](https://dplyr.tidyverse.org/reference/recode-and-replace-values.html).
  Replaces values found in `from` with the corresponding value from
  `to`; values not in `from` are kept unchanged or trigger an error
  (`.unmatched = "error"`). Intended for full remapping of every value
  in a vector. Set `.use_labels = TRUE` to build the `from`/`to` map
  automatically from the input’s existing value labels (codes become
  `from`; label strings become `to`). Also accepts `.label`,
  `.value_labels`, `.factor`, and `.description`.

- [`replace_values()`](https://jdenn0514.github.io/surveytidy/reference/replace_values.md)
  — a survey-aware
  [`dplyr::replace_values()`](https://dplyr.tidyverse.org/reference/recode-and-replace-values.html).
  Replaces values found in `from` with the corresponding value from
  `to`; all other values are left unchanged. Use this for partial
  in-place replacement of specific values in an existing vector.
  Automatically inherits both the variable label and value labels from
  the input; supply `.label` or `.value_labels` to override. Also
  accepts `.description`.

- [`replace_when()`](https://jdenn0514.github.io/surveytidy/reference/replace_when.md)
  — a survey-aware
  [`dplyr::replace_when()`](https://dplyr.tidyverse.org/reference/case-and-replace-when.html).
  Like
  [`case_when()`](https://jdenn0514.github.io/surveytidy/reference/case_when.md)
  but for partial in-place updates: evaluates `condition ~ value`
  formulas and replaces only matching elements, leaving all others at
  their original value. Automatically inherits labels from the input;
  supply `.label` or `.value_labels` to override. Also accepts
  `.description`.

#### Shared label arguments

All six functions support a common set of label arguments that propagate
into `@metadata` when used inside
[`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md):

- `.label` — a character string stored in `@metadata@variable_labels` as
  the human-readable variable label for the new column.
- `.value_labels` — a named vector stored in `@metadata@value_labels`,
  where names are label strings and values are the corresponding data
  values.
- `.description` — a plain-language string stored in
  `@metadata@transformations` describing how the variable was derived.

[`case_when()`](https://jdenn0514.github.io/surveytidy/reference/case_when.md)
and
[`recode_values()`](https://jdenn0514.github.io/surveytidy/reference/recode_values.md)
also accept `.factor = TRUE`, which returns an ordered factor instead of
a character vector (levels follow formula or `to` order respectively).
`.factor` and `.label` cannot be combined.

#### `mutate()` enhancements

[`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md)
now coordinates label propagation automatically: it pre-attaches label
attributes from `@metadata` before the inner dplyr call so recode
functions can see existing labels, reads the label output back from
recoded columns, and writes it into `@metadata` — all without extra user
steps. The weight-column warning has also been split into two distinct
classes: `surveytidy_warning_mutate_weight_col` for the weight column
and `surveytidy_warning_mutate_structural_var` for strata, PSU, FPC, and
replicate weights.

------------------------------------------------------------------------

## surveytidy 0.2.1

### Website & branding

- Added package hex logo.
- Updated pkgdown site colours to a teal theme.
- `README` now displays the hex logo.
- `LICENSE.md` updated to credit third-party hex sticker icon (Freepik /
  Flaticon, CC BY 3.0).
- `DESCRIPTION` author entry updated with current email, ORCID, and
  copyright-holder (`cph`) role.

### Infrastructure

- Added a hotfix-sync check to the CI strategy and `merge-main` skill to
  detect commits on `main` that have not been merged back to `develop`.
- Archived planning documents for the `survey-result` and
  dedup-rename-rowwise phases.

------------------------------------------------------------------------

## surveytidy 0.2.0

### New verbs

- [`filter_out()`](https://dplyr.tidyverse.org/reference/filter.html) —
  the complement of
  [`filter()`](https://jdenn0514.github.io/surveytidy/reference/filter.md).
  Marks rows matching the condition as out-of-domain while leaving all
  other rows in-domain. Like
  [`filter()`](https://jdenn0514.github.io/surveytidy/reference/filter.md),
  no rows are removed. Chains with
  [`filter()`](https://jdenn0514.github.io/surveytidy/reference/filter.md)
  via AND-accumulation on the domain column.
  `filter_out(d, group == "control")` is often clearer than
  `filter(d, group != "control")` for exclusion use-cases.

- [`distinct()`](https://jdenn0514.github.io/surveytidy/reference/distinct.md)
  — removes duplicate rows while always retaining all columns (design
  variables are never dropped). With no column arguments, deduplicates
  on non-design columns only (survey-safe default). Always issues
  `surveycore_warning_physical_subset`.

- [`rename_with()`](https://dplyr.tidyverse.org/reference/rename.html) —
  function-based column renaming. Applies `.fn` to columns selected by
  `.cols` and propagates renames to `@variables`, `@metadata`,
  `@groups`, and `visible_vars`. Validates `.fn` output and errors with
  `surveytidy_error_rename_fn_bad_output` for non-character,
  wrong-length, or duplicate output.

- [`rowwise()`](https://jdenn0514.github.io/surveytidy/reference/rowwise.md)
  — enables row-by-row computation in
  [`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md)
  (e.g., `max(c_across(...))`). Rowwise state is stored in
  `@variables$rowwise` — never in `@groups`, keeping those clean for
  estimation functions.
  [`group_by()`](https://jdenn0514.github.io/surveytidy/reference/group_by.md)
  and [`ungroup()`](https://dplyr.tidyverse.org/reference/group_by.html)
  exit rowwise mode, mirroring dplyr behaviour.

### New predicates

- [`is_rowwise()`](https://jdenn0514.github.io/surveytidy/reference/is_rowwise.md)
  — returns `TRUE` when the survey object is in rowwise mode.
- [`is_grouped()`](https://jdenn0514.github.io/surveytidy/reference/is_grouped.md)
  — returns `TRUE` when `@groups` is non-empty.
- [`group_vars()`](https://dplyr.tidyverse.org/reference/group_data.html)
  — returns the current grouping column names from `@groups`.

### Verb support for `survey_result` objects

- [`filter()`](https://jdenn0514.github.io/surveytidy/reference/filter.md),
  [`arrange()`](https://jdenn0514.github.io/surveytidy/reference/arrange.md),
  [`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md),
  [`slice()`](https://jdenn0514.github.io/surveytidy/reference/slice.md),
  [`slice_head()`](https://dplyr.tidyverse.org/reference/slice.html),
  [`slice_tail()`](https://dplyr.tidyverse.org/reference/slice.html),
  [`slice_min()`](https://dplyr.tidyverse.org/reference/slice.html),
  [`slice_max()`](https://dplyr.tidyverse.org/reference/slice.html),
  [`slice_sample()`](https://dplyr.tidyverse.org/reference/slice.html),
  and
  [`drop_na()`](https://jdenn0514.github.io/surveytidy/reference/drop_na.md)
  are now registered for `survey_result` objects (the S3 base class for
  surveycore analysis outputs: `survey_means`, `survey_freqs`,
  `survey_totals`, `survey_quantiles`, `survey_corr`, `survey_ratios`).
  Previously, applying dplyr verbs to these objects could silently strip
  the class and `.meta` attribute. Now both are preserved, and
  [`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md)
  keeps `meta$group` coherent when `.keep` drops grouping columns.

- [`select()`](https://jdenn0514.github.io/surveytidy/reference/select.md),
  [`rename()`](https://jdenn0514.github.io/surveytidy/reference/rename.md),
  and
  [`rename_with()`](https://dplyr.tidyverse.org/reference/rename.html)
  are now registered for `survey_result` objects with active `.meta`
  updates.
  [`select()`](https://jdenn0514.github.io/surveytidy/reference/select.md)
  prunes stale `meta$group` entries when grouping columns are dropped
  and handles inline renames (`select(r, grp = group)`).
  [`rename()`](https://jdenn0514.github.io/surveytidy/reference/rename.md)
  and
  [`rename_with()`](https://dplyr.tidyverse.org/reference/rename.html)
  propagate column renames to all `.meta` key references (`$group`,
  `$x`, `$numerator$name`, `$denominator$name`).
  [`rename_with()`](https://dplyr.tidyverse.org/reference/rename.html)
  errors with `surveytidy_error_rename_fn_bad_output` if `.fn` returns
  non-character, wrong-length, `NA`, or duplicate names.

### Bug fixes

- [`drop_na()`](https://jdenn0514.github.io/surveytidy/reference/drop_na.md)
  now performs domain-aware filtering instead of physically removing
  rows. Previously,
  [`drop_na()`](https://jdenn0514.github.io/surveytidy/reference/drop_na.md)
  removed rows with `NA` values, changing which units contributed to
  variance estimation and producing incorrect standard errors. It now
  marks incomplete rows as out-of-domain — equivalent to the
  corresponding `filter(!is.na(col1), ...)` chain — giving correct
  variance estimates for downstream analyses.

- [`filter()`](https://jdenn0514.github.io/surveytidy/reference/filter.md):
  the `.by` unsupported-argument error was mis-classified as a
  `surveycore_error_*`; corrected to
  `surveytidy_error_filter_by_unsupported`.

### Improvements

- [`rename()`](https://jdenn0514.github.io/surveytidy/reference/rename.md)
  and
  [`rename_with()`](https://dplyr.tidyverse.org/reference/rename.html)
  now update `@groups` when a grouped column is renamed, and correctly
  update twophase design variable references (`@variables$phase1`,
  `@variables$phase2`, `@variables$subset`). The domain column
  (`..surveycore_domain..`) is silently protected from renaming.

- [`filter()`](https://jdenn0514.github.io/surveytidy/reference/filter.md)
  and
  [`filter_out()`](https://dplyr.tidyverse.org/reference/filter.html)
  support
  [`if_any()`](https://dplyr.tidyverse.org/reference/across.html) and
  [`if_all()`](https://dplyr.tidyverse.org/reference/across.html) in
  conditions.

### Documentation

- Roxygen documentation standardised across all verb files to mirror the
  dplyr/tidyr reference style, with `@details` subsections for
  surveytidy-specific behaviour and examples using `nhanes_2017`.

- Rd files consolidated from per-method (e.g., `arrange.survey_base.Rd`)
  to per-verb (e.g., `arrange.Rd`), fixing the “S3 methods shown with
  full name” R CMD check NOTE.

------------------------------------------------------------------------

## surveytidy 0.1.0

First release. Implements a complete set of dplyr and tidyr verbs for
survey design objects created with the `surveycore` package.

### New verbs

- [`filter()`](https://jdenn0514.github.io/surveytidy/reference/filter.md)
  — domain-aware filtering. Marks rows in-domain rather than removing
  them, preserving correct variance estimation for subpopulation
  analyses. Chained
  [`filter()`](https://jdenn0514.github.io/surveytidy/reference/filter.md)
  calls AND their conditions together.

- [`select()`](https://jdenn0514.github.io/surveytidy/reference/select.md)
  — column selection. Physically removes non-selected columns while
  always retaining design variables (weights, strata, PSU, FPC,
  replicate weights). Sets `@variables$visible_vars` so
  [`print()`](https://rdrr.io/r/base/print.html) hides design columns
  the user did not explicitly request.

- [`relocate()`](https://jdenn0514.github.io/surveytidy/reference/relocate.md)
  — column reordering. Reorders `visible_vars` when a prior
  [`select()`](https://jdenn0514.github.io/surveytidy/reference/select.md)
  has been called; reorders `@data` directly otherwise.

- [`pull()`](https://jdenn0514.github.io/surveytidy/reference/pull.md) —
  extract a column as a plain vector (terminal operation).

- [`glimpse()`](https://jdenn0514.github.io/surveytidy/reference/glimpse.md)
  — concise column summary, respecting `visible_vars`.

- [`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md)
  — add or modify columns. Re-attaches design variables dropped by
  `.keep = "none"` or `.keep = "used"`. Issues
  `surveytidy_warning_mutate_design_var` when a mutation’s left-hand
  side names a design variable. Respects `@groups` set by
  [`group_by()`](https://jdenn0514.github.io/surveytidy/reference/group_by.md).

- [`rename()`](https://jdenn0514.github.io/surveytidy/reference/rename.md)
  — rename columns. Automatically keeps `@variables` (design
  specification) and `@metadata` (variable labels, value labels, etc.)
  in sync with the new column names. Issues
  `surveytidy_warning_rename_design_var` when a design variable is
  renamed.

- [`arrange()`](https://jdenn0514.github.io/surveytidy/reference/arrange.md)
  — row sorting. The domain column moves correctly with the rows after
  sorting. Supports `.by_group = TRUE` using `@groups`.

- [`slice()`](https://jdenn0514.github.io/surveytidy/reference/slice.md),
  [`slice_head()`](https://dplyr.tidyverse.org/reference/slice.html),
  [`slice_tail()`](https://dplyr.tidyverse.org/reference/slice.html),
  [`slice_min()`](https://dplyr.tidyverse.org/reference/slice.html),
  [`slice_max()`](https://dplyr.tidyverse.org/reference/slice.html),
  [`slice_sample()`](https://dplyr.tidyverse.org/reference/slice.html) —
  physical row selection with a `surveycore_warning_physical_subset`
  warning. `slice_sample(weight_by = )` additionally issues
  `surveytidy_warning_slice_sample_weight_by` to flag that the
  `weight_by` column is independent of the survey design weights.

- [`group_by()`](https://jdenn0514.github.io/surveytidy/reference/group_by.md)
  — store grouping columns in `@groups`. Does not attach a `grouped_df`
  attribute to `@data`; grouping is kept on the survey object. Supports
  `.add = TRUE` for incremental grouping and computed expressions (e.g.,
  `group_by(d, above_median = y1 > median(y1))`).

- [`ungroup()`](https://dplyr.tidyverse.org/reference/group_by.html) —
  remove all groups (no arguments) or remove specific columns from
  `@groups` (partial ungroup).

- [`drop_na()`](https://jdenn0514.github.io/surveytidy/reference/drop_na.md)
  — domain-aware NA handling. Marks rows with `NA` in specified columns
  (or any column) as out-of-domain without removing them. Equivalent to
  `filter(!is.na(col1), !is.na(col2), ...)` and gives correct variance
  estimates for downstream analyses. Successive
  [`drop_na()`](https://jdenn0514.github.io/surveytidy/reference/drop_na.md)
  calls AND their conditions together.

- [`subset()`](https://rdrr.io/r/base/subset.html) — physical row
  removal with `surveycore_warning_physical_subset`. Prefer
  [`filter()`](https://jdenn0514.github.io/surveytidy/reference/filter.md)
  for subpopulation analyses.

### Statistical design

The key design decision in surveytidy is that
**[`filter()`](https://jdenn0514.github.io/surveytidy/reference/filter.md)
never removes rows**. Removing rows from a survey design changes which
units contribute to variance estimation and produces incorrect standard
errors for subpopulation statistics.
[`filter()`](https://jdenn0514.github.io/surveytidy/reference/filter.md)
instead writes a logical domain column (`..surveycore_domain..`) to
`@data`. Phase 1 estimation functions will read this column to restrict
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
