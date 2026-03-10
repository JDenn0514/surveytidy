# feature-recode: Survey-Aware Recoding Functions (Phase 0.6)

**Branch:** `feature/recode`
**Status:** Complete — `devtools::check()` passing (0 errors, 0 warnings, 1 pre-approved note)

---

## What Changed

### New exported functions (6)

Six vector-level recoding functions that shadow or wrap their dplyr equivalents.
When called with surveytidy label arguments, they propagate label metadata into
and out of `@metadata` via `mutate.survey_base()`. Without those arguments,
output is identical to dplyr.

| Function | Wraps | Surveytidy additions |
|---|---|---|
| `case_when()` | `dplyr::case_when()` | `.label`, `.value_labels`, `.factor`, `.description` |
| `replace_when()` | `dplyr::replace_when()` | label inheritance from `x`; `.label`, `.value_labels`, `.description` |
| `if_else()` | `dplyr::if_else()` | `.label`, `.value_labels`, `.description` |
| `na_if()` | `dplyr::na_if()` | vector `y`; `.update_labels`, `.description` |
| `recode_values()` | `dplyr::recode_values()` | `.label`, `.value_labels`, `.factor`, `.use_labels`, `.description` |
| `replace_values()` | `dplyr::replace_values()` | label inheritance from `x`; `.label`, `.value_labels`, `.description` |

### Modified: `mutate.survey_base()` (R/mutate.R)

Three new steps added around the inner `dplyr::mutate()` call:

- **Pre-attachment** (step 2): copies label attrs from `@metadata` into the
  data frame so recode functions can read `attr(x, "labels")` / `attr(x, "label")`
- **Post-detection** (step 4): reads the `surveytidy_recode` sentinel attribute
  from mutated columns and writes labels back to `@metadata`
- **Strip** (step 5b): removes all haven attrs and the sentinel attr before
  storing data in `@data`

Also split the single weight-column warning into two classes:
`surveytidy_warning_mutate_weight_col` (weight column) and
`surveytidy_warning_mutate_structural_var` (strata/PSU/FPC/repweights).

### New helpers (R/utils.R)

- `.attach_label_attrs()` — pre-attachment (used by mutate only)
- `.extract_labelled_outputs()` — post-detection (used by mutate only)
- `.strip_label_attrs()` — strip pass (used by mutate only)
- `.validate_label_args()` — validates `.label`, `.value_labels`, `.description`
- `.wrap_labelled()` — wraps result in `haven::labelled()` + sets sentinel attr
- `.factor_from_result()` — converts result to factor with correct level order
- `.merge_value_labels()` — merges inherited + override labels; deduplicates by value

### File organization

Each recode function was given its own `.R` file (previously all in `R/recode.R`).
The 4 internal helpers shared across 2+ files moved to `R/utils.R`.

### New test file: `tests/testthat/test-recode.R`

12 test sections, 3535+ assertions covering:
- All 6 functions across happy paths, error paths, edge cases
- Label propagation through `mutate.survey_base()`
- `.update_labels = TRUE/FALSE` for `na_if()`
- `.use_labels = TRUE` for `recode_values()`
- Factor output for `case_when()` and `recode_values()`
- Invariant 7: no `surveytidy_recode` attr in `@data` after mutate

---

## New Error / Warning Classes

| Class | Thrown by |
|---|---|
| `surveytidy_error_recode_label_not_scalar` | `.validate_label_args()` |
| `surveytidy_error_recode_value_labels_unnamed` | `.validate_label_args()` |
| `surveytidy_error_recode_description_not_scalar` | `.validate_label_args()` |
| `surveytidy_error_recode_factor_with_label` | `case_when()`, `recode_values()` |
| `surveytidy_error_recode_use_labels_no_attrs` | `recode_values()` |
| `surveytidy_error_recode_from_to_missing` | `recode_values()` |
| `surveytidy_error_recode_unmatched_values` | `recode_values()` |
| `surveytidy_warning_mutate_weight_col` | `mutate.survey_base()` |
| `surveytidy_warning_mutate_structural_var` | `mutate.survey_base()` |

---

## DESCRIPTION changes

- Added `haven (>= 2.5.0)` to Imports
- Bumped `dplyr` minimum to `(>= 1.2.0)` (required for `recode_values()`, `replace_values()`, `replace_when()`)
