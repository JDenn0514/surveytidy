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
| `surveytidy_error_recode_from_to_missing` | `R/recode-values.R` | No formulas in `...`, `from = NULL`, and `.use_labels = FALSE` in `recode_values()` |
| `surveytidy_error_recode_use_labels_with_formulas` | `R/recode-values.R` | Both formulas in `...` and `.use_labels = TRUE` in `recode_values()` |
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
| `surveytidy_error_join_survey_to_survey` | `R/joins.R` | `y` is a survey object in any join |
| `surveytidy_error_join_adds_rows` | `R/joins.R` | `right_join` or `full_join` called on a survey (would add rows with NA design variables) |
| `surveytidy_error_join_row_expansion` | `R/joins.R` | Duplicate keys in `y` would expand row count (left_join or inner_join) |
| `surveytidy_error_join_twophase_row_removal` | `R/joins.R` | Physical `inner_join(.domain_aware = FALSE)` called on a `survey_twophase` object |
| `surveytidy_error_bind_rows_survey` | `R/joins.R` | `bind_rows()` called with a survey object |
| `surveytidy_error_bind_cols_row_mismatch` | `R/joins.R` | Row counts differ between `x` and `...` in `bind_cols()` |
| `surveytidy_error_reserved_col_name` | `R/joins.R` | `"..surveytidy_row_index.."` already in `names(x@data)` when `semi_join`, `anti_join`, or `inner_join` (domain-aware) is called |
| `surveytidy_error_collection_verb_emptied` | `R/collection-dispatch.R` | Verb result is an empty collection (e.g., every member skipped via `.if_missing_var = "skip"`). Message identifies the verb and reports whether `.if_missing_var` came from per-call or stored property. |
| `surveytidy_error_collection_verb_failed` | `R/collection-dispatch.R` | Per-survey verb application errored under `.if_missing_var = "error"`. Re-raises with `parent = cnd` so the original error chain is preserved. |
| `surveytidy_error_collection_by_unsupported` | `R/filter.R`, `R/mutate.R`, `R/slice.R` | Per-call `.by` (or `by` for `slice_min`/`slice_max`/`slice_sample`) was supplied to a verb dispatched on a `survey_collection`. Raised before dispatch. Names the verb and points users to `group_by` on the collection or `coll@groups`. |
| `surveytidy_error_collection_select_group_removed` | `R/select.R` | `select.survey_collection` resolved its tidyselect against the first member's `@data` and the resulting selection would drop one or more columns listed in `coll@groups`. Raised before dispatch. Names the missing group columns and points users to `ungroup()` first. |
| `surveytidy_error_collection_rename_group_partial` | `R/rename.R` | `rename.survey_collection` or `rename_with.survey_collection` produced a rename map whose `old_name` is listed in `coll@groups` but the column is absent from one or more members. Raised before dispatch (would otherwise leave members with inconsistent group columns). Names the affected group column and the members where it is missing. |
| `surveytidy_error_collection_slice_zero` | `R/slice.R` | `slice.survey_collection`, `slice_head.survey_collection`, `slice_tail.survey_collection`, `slice_min.survey_collection`, `slice_max.survey_collection`, or `slice_sample.survey_collection` was called with arguments that would produce 0 rows on every member (e.g., `slice_head(n = 0)`, literal `slice(integer(0))`). Raised BEFORE any member is touched; identifies the slice verb. The per-survey verb's empty-result error (`surveytidy_error_subset_empty_result`) would otherwise surface a misleading "single member is invalid" message at member rebuild time. |
| `surveytidy_error_collection_verb_unsupported` | `R/joins.R` | Join verb dispatched on a `survey_collection` (`left_join`, `right_join`, `inner_join`, `full_join`, `semi_join`, `anti_join`). Names the verb. The semantics of joining a plain data frame onto a multi-survey container are still being designed; users are pointed at applying the join inside a per-survey pipeline before constructing the collection. |
| `surveytidy_pre_check_missing_var` | `R/collection-dispatch.R` | **Internal — not part of public condition API.** Typed condition synthesized by the dispatcher's pre-check path when a data-masking quosure references a name unresolved in both the quosure's enclosing env and the survey's `@data`. Class chain: `c("surveytidy_pre_check_missing_var", "error", "condition")` (deliberately omits `"rlang_error"`). Fields: `$missing_vars` (chr), `$survey_name` (chr), `$quosure`. Stable for `parent`-chain testing; not exported. |
| `surveytidy_error_collection_pull_incompatible_types` | `R/collection-pull-glimpse.R` | `pull.survey_collection` combined per-survey vectors via `vctrs::vec_c()` and the call raised `vctrs_error_incompatible_type`. Re-raised with `parent = cnd` so the original vctrs error chain is preserved. Names the column and the surveys whose types disagreed. No auto-coercion (contrast with `glimpse`'s footer-renderer behaviour). |
| `surveytidy_error_collection_glimpse_id_collision` | `R/collection-pull-glimpse.R` | `glimpse.survey_collection` (default mode) detected that `coll@id` matches a column name in at least one member's `@data`. Raised BEFORE `bind_rows()` because the prepended id column would collide with the existing column. Names the colliding column and the members where it occurs. Mirrors `surveycore_error_collection_id_collision` for verb-side collisions introduced after construction (e.g., user calling `mutate(coll, .survey = ...)`). |

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
| `surveytidy_warning_join_col_conflict` | `R/joins.R` | `y` has column names matching design variable names in `x` (dropped before joining) |
| `surveytidy_warning_collection_rowwise_mixed` | `R/mutate.R` | `mutate.survey_collection` detects that `is_rowwise()` is not uniform across `coll@surveys` (some members are rowwise, others are not). Soft invariant — fires once per `mutate()` call before per-member dispatch; per-member rowwise/non-rowwise semantics still apply for that call. |

---

## Messages

Typed messages emitted via `cli::cli_inform()`. Registered as classes for
handler consistency (`expect_message(class = …)`); not errors or warnings.

| Class | Source file | Trigger |
|-------|-------------|---------|
| `surveytidy_message_collection_skipped_surveys` | `R/collection-dispatch.R` | Informational message from the collection dispatcher listing surveys that were skipped under `.if_missing_var = "skip"` because they were missing a referenced variable. Mirrors `surveycore_message_collection_skipped_surveys` from the analysis dispatcher. |
