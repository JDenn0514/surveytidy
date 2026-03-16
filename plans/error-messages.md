# surveytidy Error and Warning Classes

This is the canonical registry of all `cli_abort()` and `cli_warn()` error
and warning classes in surveytidy. **Update this file before adding any new
class to source code.** The quality gate for every feature branch checks that
this file is in sync.

Naming convention:
- Errors: `surveytidy_error_{snake_case_condition}`
- Warnings: `surveytidy_warning_{snake_case_condition}`
- Classes reused from surveycore: `surveycore_{error|warning}_{condition}`

---

## Errors

| Class | Source file | Trigger |
|-------|-------------|---------|
| `surveytidy_error_filter_by_unsupported` | `R/filter.R` | `.by` argument passed to `filter()` — not supported; use `group_by()` instead |
| `surveytidy_error_subset_empty_result` | `R/filter.R`, `R/slice.R` | `subset()` or `slice_*()` produces a 0-row result |
| `surveycore_error_design_var_removed` | `R/utils.R` | `dplyr_reconstruct()` detects that a required design variable was removed from `@data` |
| `surveytidy_error_rename_fn_bad_output` | `R/rename.R`, `R/verbs-survey-result.R` | `.fn` in `rename_with()` returns a vector of the wrong length, duplicate names, or non-character output |
| `surveytidy_error_recode_label_not_scalar` | `R/recode.R` | `.label` is not NULL and not a character(1) |
| `surveytidy_error_recode_value_labels_unnamed` | `R/recode.R` | `.value_labels` is not NULL and has no names |
| `surveytidy_error_recode_factor_with_label` | `R/recode.R` | `.factor = TRUE` and `.label` is non-NULL |
| `surveytidy_error_recode_use_labels_no_attrs` | `R/recode.R` | `.use_labels = TRUE` but `attr(x, "labels")` is NULL |
| `surveytidy_error_recode_unmatched_values` | `R/recode.R` | `.unmatched = "error"` and unmatched values exist in `recode_values()` |
| `surveytidy_error_recode_from_to_missing` | `R/recode.R` | `from` is NULL and `.use_labels = FALSE` in `recode_values()` |
| `surveytidy_error_recode_description_not_scalar` | `R/recode.R` | `.description` is not NULL and not a character(1) |
| `surveytidy_error_na_if_update_labels_not_scalar` | `R/na-if.R` | `.update_labels` is not a single non-NA logical value |
| `surveytidy_error_make_factor_bad_arg` | `R/transform.R` | `.label`/`.description` not `character(1)`, or `ordered`/`drop_levels`/`force`/`na.rm` not `logical(1)` |
| `surveytidy_error_make_factor_unsupported_type` | `R/transform.R` | `x` not numeric, haven_labelled, factor, or character |
| `surveytidy_error_make_factor_no_labels` | `R/transform.R` | `x` is numeric/haven_labelled, `attr(x, "labels")` is NULL, `force = FALSE` |
| `surveytidy_error_make_factor_incomplete_labels` | `R/transform.R` | One or more non-NA observed values lack a label entry |
| `surveytidy_error_make_dicho_too_few_levels` | `R/transform.R` | Fewer than 2 levels remain after `.exclude` |
| `surveytidy_error_make_dicho_collapse_ambiguous` | `R/transform.R` | First-word stripping does not yield exactly 2 unique stems |
| `surveytidy_error_make_rev_not_numeric` | `R/transform.R` | `typeof(x)` not `"double"` or `"integer"` |
| `surveytidy_error_make_flip_not_numeric` | `R/transform.R` | `typeof(x)` not `"double"` or `"integer"` |
| `surveytidy_error_make_flip_missing_label` | `R/transform.R` | `label` missing or not `character(1)` |
| `surveytidy_error_transform_bad_arg` | `R/transform.R` | `.label`/`.description` not `character(1)`, or boolean flag not `logical(1)`, in `make_dicho()`, `make_binary()`, `make_rev()`, or `make_flip()` |

---

## Warnings

| Class | Source file | Trigger |
|-------|-------------|---------|
| `surveycore_warning_empty_domain` | `R/filter.R`, `R/drop-na.R` | `filter()` or `drop_na()` produces an all-FALSE domain column (no in-domain rows) |
| `surveycore_warning_physical_subset` | `R/utils.R` | Any operation that physically removes rows: `subset()`, `distinct()`, `slice_*()` |
| `surveytidy_warning_mutate_weight_col` | `R/mutate.R` | `mutate()` modifies a weight column (replaces `surveytidy_warning_mutate_design_var`) |
| `surveytidy_warning_mutate_structural_var` | `R/mutate.R` | `mutate()` modifies a structural design variable (strata, PSU, FPC, or repweights) |
| `surveytidy_warning_rename_design_var` | `R/rename.R` | `rename()` or `rename_with()` renames a protected design variable or the domain column |
| `surveytidy_warning_slice_sample_weight_by` | `R/slice.R` | `weight_by` argument passed to `slice_sample()` |
| `surveytidy_warning_distinct_design_var` | `R/distinct.R` | `distinct()` called with a design variable in `...` — deduplicating by design variables may corrupt variance estimation |
| `surveytidy_warning_make_factor_forced` | `R/transform.R` | `force = TRUE` coerces numeric without labels via `as.factor()` |
| `surveytidy_warning_make_dicho_unknown_exclude` | `R/transform.R` | A name in `.exclude` not found in levels of `x` |
| `surveytidy_warning_make_rev_all_na` | `R/transform.R` | All values in `x` are `NA` |
