# Changelog

## surveytidy 0.6.0

### New features

#### survey_collection support

Collection-aware methods for all standard dplyr/tidyr verbs are now
dispatched per-survey when called on a `survey_collection`. The result
is a new `survey_collection` whose `@id`, `@if_missing_var`, and
`@groups` properties are preserved.

- Data-masking verbs:
  [`filter()`](https://jdenn0514.github.io/surveytidy/reference/filter.md),
  [`filter_out()`](https://dplyr.tidyverse.org/reference/filter.html),
  [`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md),
  [`arrange()`](https://jdenn0514.github.io/surveytidy/reference/arrange.md)
- Tidyselect verbs:
  [`select()`](https://jdenn0514.github.io/surveytidy/reference/select.md),
  [`relocate()`](https://jdenn0514.github.io/surveytidy/reference/relocate.md),
  [`rename()`](https://jdenn0514.github.io/surveytidy/reference/rename.md),
  [`rename_with()`](https://dplyr.tidyverse.org/reference/rename.html),
  [`drop_na()`](https://jdenn0514.github.io/surveytidy/reference/drop_na.md),
  [`distinct()`](https://jdenn0514.github.io/surveytidy/reference/distinct.md),
  [`rowwise()`](https://jdenn0514.github.io/surveytidy/reference/rowwise.md)
- Grouping verbs:
  [`group_by()`](https://jdenn0514.github.io/surveytidy/reference/group_by.md),
  [`ungroup()`](https://dplyr.tidyverse.org/reference/group_by.html),
  [`group_vars()`](https://dplyr.tidyverse.org/reference/group_data.html),
  [`is_rowwise()`](https://jdenn0514.github.io/surveytidy/reference/is_rowwise.md)
- Slicing verbs:
  [`slice()`](https://jdenn0514.github.io/surveytidy/reference/slice.md),
  [`slice_head()`](https://dplyr.tidyverse.org/reference/slice.html),
  [`slice_tail()`](https://dplyr.tidyverse.org/reference/slice.html),
  [`slice_min()`](https://dplyr.tidyverse.org/reference/slice.html),
  [`slice_max()`](https://dplyr.tidyverse.org/reference/slice.html),
  [`slice_sample()`](https://dplyr.tidyverse.org/reference/slice.html)
- Collapsing verbs:
  [`pull()`](https://jdenn0514.github.io/surveytidy/reference/pull.md)
  (returns a vector via
  [`vctrs::vec_c()`](https://vctrs.r-lib.org/reference/vec_c.html)),
  [`glimpse()`](https://jdenn0514.github.io/surveytidy/reference/glimpse.md)
  (default mode binds members; `.by_survey = TRUE` per-member)

The `.if_missing_var` argument on each verb (`"error"` (default) or
`"skip"`) lets you override the collection’s stored missing-variable
behaviour for a single call. Skipped surveys are reported via the typed
message class `surveytidy_message_collection_skipped_surveys`.

The 6 join verbs
([`left_join()`](https://jdenn0514.github.io/surveytidy/reference/left_join.md),
[`right_join()`](https://jdenn0514.github.io/surveytidy/reference/right_join.md),
[`inner_join()`](https://jdenn0514.github.io/surveytidy/reference/inner_join.md),
[`full_join()`](https://jdenn0514.github.io/surveytidy/reference/right_join.md),
[`semi_join()`](https://jdenn0514.github.io/surveytidy/reference/semi_join.md),
[`anti_join()`](https://jdenn0514.github.io/surveytidy/reference/semi_join.md))
error with `surveytidy_error_collection_verb_unsupported` when called on
a `survey_collection`. Apply joins inside a per-survey pipeline before
constructing the collection.

#### surveycore re-exports

[`library(surveytidy)`](https://jdenn0514.github.io/surveytidy/) is now
sufficient to use the collection construction and setter API. The
following surveycore symbols are re-exported:

- [`as_survey_collection()`](https://jdenn0514.github.io/surveycore/reference/as_survey_collection.html)
- [`set_collection_id()`](https://jdenn0514.github.io/surveycore/reference/set_collection_id.html)
- [`set_collection_if_missing_var()`](https://jdenn0514.github.io/surveycore/reference/set_collection_if_missing_var.html)
- [`add_survey()`](https://jdenn0514.github.io/surveycore/reference/add_survey.html)
- [`remove_survey()`](https://jdenn0514.github.io/surveycore/reference/remove_survey.html)

### Bug fixes

- [`replace_when()`](https://jdenn0514.github.io/surveytidy/reference/replace_when.md)
  and
  [`replace_values()`](https://jdenn0514.github.io/surveytidy/reference/replace_values.md)
  no longer retain stale value labels for values absent from the recoded
  result. Previously, collapsing or replacing values left label entries
  (e.g. `"High" = 4`) attached to a vector that contained no such
  values. User-supplied `.value_labels` are always preserved.

### New error / warning / message classes

- `surveytidy_error_collection_verb_emptied`
- `surveytidy_error_collection_verb_failed`
- `surveytidy_error_collection_by_unsupported`
- `surveytidy_error_collection_select_group_removed`
- `surveytidy_error_collection_rename_group_partial`
- `surveytidy_error_collection_slice_zero`
- `surveytidy_error_collection_pull_incompatible_types`
- `surveytidy_error_collection_glimpse_id_collision`
- `surveytidy_error_collection_verb_unsupported`
- `surveytidy_warning_collection_rowwise_mixed`
- `surveytidy_message_collection_skipped_surveys`

### Dependency changes

- Adds `vctrs (>= 0.6.0)` to `Imports` (used by `pull.survey_collection`
  and `glimpse.survey_collection`).
- Bumps `surveycore` minimum-version pin to `(>= 0.8.2)`.

------------------------------------------------------------------------

## surveytidy 0.5.0

### New features

#### Survey-aware join functions

Eight join and binding functions are now available for combining survey
design objects with plain data frames. All join functions protect design
variable columns (weights, strata, PSU, etc.) from being overwritten by
`y` and append a typed sentinel to `@variables$domain` for traceability
by Phase 1 estimation functions.

- [`left_join()`](https://jdenn0514.github.io/surveytidy/reference/left_join.md)
  — appends lookup columns from `y` without removing any rows. Errors if
  duplicate keys in `y` would expand rows.

- [`inner_join()`](https://jdenn0514.github.io/surveytidy/reference/inner_join.md)
  — two modes: domain-aware (`.domain_aware = TRUE`, default) marks
  unmatched rows out-of-domain without removing them; physical mode
  (`.domain_aware = FALSE`) removes rows and issues a warning. Physical
  mode is not supported for `survey_twophase` designs.

- [`semi_join()`](https://jdenn0514.github.io/surveytidy/reference/semi_join.md)
  — marks rows matching `y` as in-domain; unmatched rows are marked
  out-of-domain. No rows are physically removed.

- [`anti_join()`](https://jdenn0514.github.io/surveytidy/reference/semi_join.md)
  — inverse of
  [`semi_join()`](https://jdenn0514.github.io/surveytidy/reference/semi_join.md);
  marks rows that do NOT match `y` as in-domain.

- [`right_join()`](https://jdenn0514.github.io/surveytidy/reference/right_join.md)
  and
  [`full_join()`](https://jdenn0514.github.io/surveytidy/reference/right_join.md)
  — always error when called on a survey object. Both would add rows
  with `NA` design variable values, which would invalidate variance
  estimation.

- [`bind_cols()`](https://jdenn0514.github.io/surveytidy/reference/bind_cols.md)
  — appends columns from `...` to a survey object. Validates that all
  inputs have the same row count. Passes through to
  [`dplyr::bind_cols()`](https://dplyr.tidyverse.org/reference/bind_cols.html)
  for non-survey inputs.

- [`bind_rows()`](https://jdenn0514.github.io/surveytidy/reference/bind_rows.md)
  — always errors when called with a survey object. Combining two survey
  designs has undefined variance structure. Passes through to
  [`dplyr::bind_rows()`](https://dplyr.tidyverse.org/reference/bind_rows.html)
  for non-survey inputs.

#### Row statistic helpers

Two helper functions are now available for computing row-wise statistics
inside
[`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md).
Both propagate metadata automatically and accept `.label` and
`.description` to document the new variable in a single step.

- [`row_means()`](https://jdenn0514.github.io/surveytidy/reference/row_means.md)
  — computes the row mean across selected columns. Accepts `na.rm` to
  control `NA` handling. Issues a warning if any selected column is a
  design variable.

- [`row_sums()`](https://jdenn0514.github.io/surveytidy/reference/row_sums.md)
  — computes the row sum across selected columns. Accepts `na.rm` to
  control `NA` handling. Issues a warning if any selected column is a
  design variable.

### Bug fixes

- [`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md)
  — transformation metadata is now correctly written back to the design
  object. Previously, `[[<-` assignment on S7 properties silently
  failed; the fix uses `S7::prop<-()` to sync all six metadata
  properties correctly
  ([\#25](https://github.com/JDenn0514/surveytidy/issues/25)).

------------------------------------------------------------------------

## surveytidy 0.4.0

### New features

#### Survey-aware transformation functions

Five vector-level transformation functions are now available for
converting, collapsing, and reversing variables inside
[`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md).
All five propagate value labels automatically and accept `.label` and
`.description` arguments to attach metadata in a single step.

- [`make_factor()`](https://jdenn0514.github.io/surveytidy/reference/make_factor.md)
  — converts labelled, numeric, character, or factor vectors to an R
  `factor`. Levels are ordered by the numeric value of each value label.
  Accepts `ordered`, `drop_levels`, `force`, and `na.rm` to control
  level creation.

- [`make_dicho()`](https://jdenn0514.github.io/surveytidy/reference/make_dicho.md)
  — collapses a multi-level factor to two levels by stripping the first
  word of each label and merging labels that reduce to the same stem.
  Accepts `.exclude` to keep specific levels as `NA`, and `flip_levels`
  to reverse the resulting order.

- [`make_binary()`](https://jdenn0514.github.io/surveytidy/reference/make_binary.md)
  — converts a dichotomous variable to a 0/1 integer. Thin wrapper
  around
  [`make_dicho()`](https://jdenn0514.github.io/surveytidy/reference/make_dicho.md);
  accepts `flip_values` to control which level maps to 1.

- [`make_rev()`](https://jdenn0514.github.io/surveytidy/reference/make_rev.md)
  — reverses a numeric scale using `min + max - x` and remaps value
  labels to match. Issues a warning when all values are `NA`.

- [`make_flip()`](https://jdenn0514.github.io/surveytidy/reference/make_flip.md)
  — reverses the semantic valence of a variable by reversing the label
  strings while keeping the underlying values unchanged. Requires a
  `label` argument to document the new meaning.

------------------------------------------------------------------------

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
