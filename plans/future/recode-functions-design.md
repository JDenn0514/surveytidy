# Plan: Survey-Aware Value Recoding Functions

## Context

Phase 0.5 is complete — all core dplyr/tidyr verbs are implemented. This phase adds
**survey-aware vector-level recoding functions** that wrap dplyr's value-transformation
utilities (`case_when`, `replace_when`, `if_else`, `na_if`, `recode_values`,
`replace_values`) with integrated `@metadata` management.

**Problem being solved**: When a researcher recodes a variable, the current workflow
requires three separate steps:
```r
d2 <- mutate(d, age_cat = case_when(age < 18 ~ "minor", .default = "adult"))
d3 <- set_var_label(d2, age_cat, "Age category")
d4 <- set_val_labels(d3, age_cat, c("Minor" = "minor", "Adult" = "adult"))
```
These functions collapse that into one call inside `mutate()`.

**What's NOT changing**: These functions are vector-level — they're called inside
`mutate()` exactly like `dplyr::case_when()`. No new table-level verbs.

---

## Pre-Implementation Checks (Verified 2026-02-25)

- dplyr 1.2.0 is installed locally
- `recode_values()`, `replace_values()`, `replace_when()` all exist in dplyr 1.2.0
- haven 2.5.5 is installed locally

**Note before implementing**: Verify these functions exist in the dplyr version on CI
runners (currently pinned to `dplyr (>= 1.1.0)` in DESCRIPTION). If `recode_values()`,
`replace_values()`, and `replace_when()` are development-only in dplyr < 1.2.0, the
version pin must be bumped to `(>= 1.2.0)`.

---

## Architecture

### How metadata flows from vector function → @metadata

1. Survey-aware vector functions return a `haven::labelled()` vector when `.label` or
   `.value_labels` is specified (or when the input carries labels that should be
   updated, as with `na_if_survey()`).
2. After calling `dplyr::mutate()`, `mutate.survey_base()` scans newly created/modified
   columns for `haven::labelled` vectors and extracts their metadata into `@metadata`.
3. Haven attrs are then stripped from `@data` columns (keeping `@data` as plain vectors,
   consistent with surveytidy's existing design).

### How label-aware recoding works (.use_labels = TRUE)

surveycore strips haven label attrs from columns — `@data` stores plain vectors. So
inside `dplyr::mutate()`, columns don't normally carry their labels. To enable
`recode_values_survey(gender, .use_labels = TRUE)`:

`mutate.survey_base()` adds a **pre-attachment step** before calling `dplyr::mutate()`:
- Scan `@metadata@value_labels` and `@metadata@variable_labels`
- Temporarily attach those as `labels` / `label` attrs on the corresponding `@data` columns
- Pass the augmented data to `dplyr::mutate()`

The vector function (e.g. `recode_values_survey()`) reads `attr(x, "labels")` to
build the recode map automatically.

After mutation, the post-detection step runs (see above), then haven attrs are stripped.

---

## Implementation

### Step 1: Add haven to DESCRIPTION

```
Imports:
    haven (>= 2.5.0),   # haven::labelled()
    ...
```

### Step 2: Enhance mutate.survey_base() — R/mutate.R

Add three helpers (internal, defined in `R/utils.R` since they may be shared):

```r
# Temporarily attach @metadata label attrs to @data columns
.attach_label_attrs <- function(data, metadata) { ... }

# Detect haven_labelled vectors in data and extract into @metadata
.extract_labelled_outputs <- function(data, metadata, new_cols) { ... }

# Strip haven label attrs from @data columns (keep @data as plain vectors)
.strip_label_attrs <- function(data) { ... }
```

Revised `mutate.survey_base()` flow:

```
1. Warn on weight column modification [existing]
2. [NEW] Pre-attach label attrs: augmented_data <- .attach_label_attrs(@data, @metadata)
3. Call dplyr::mutate(augmented_data, ...)           [existing, but on augmented_data]
4. [NEW] Extract: update @metadata from haven_labelled outputs
5. [NEW] Strip: remove haven attrs from @data columns
6. Update visible_vars                                [existing]
7. Record transformations in @metadata@transformations [existing]
```

### Step 3: New file R/recode.R — 6 survey-aware vector functions

**Function naming decision**: Use `_survey` suffix (not `_lbl`). These are exported
from a package called surveytidy; `_survey` makes namespace origin clear. The concern
that `_survey` implies table-level is addressed by documentation.

**Function signatures**:

```r
case_when_survey(
  ...,
  .default = NULL, .unmatched = "default", .ptype = NULL, .size = NULL,
  .label = NULL, .value_labels = NULL, .factor = FALSE
)
# → wraps dplyr::case_when(); returns haven_labelled if .label/.value_labels set;
#   returns factor if .factor = TRUE (levels from formula order, or .value_labels names)

replace_when_survey(
  x, ...,
  .label = NULL, .value_labels = NULL
)
# → wraps dplyr::replace_when(); updates labels for replaced values;
#   no .factor (type-stable, like replace_values)

if_else_survey(
  condition, true, false, missing = NULL, ...,
  ptype = NULL,
  .label = NULL, .value_labels = NULL
)
# → wraps dplyr::if_else(); .value_labels must be explicit (true/false may differ);
#   no .factor (binary results rarely need factor)

na_if_survey(
  x, y,
  .update_labels = TRUE
)
# → wraps dplyr::na_if(); if .update_labels = TRUE AND x has labels (from pre-attachment),
#   automatically removes the entry for y from value labels in output;
#   always returns haven_labelled if input had labels

recode_values_survey(
  x, ...,
  from = NULL, to = NULL,
  default = NULL, unmatched = "default", ptype = NULL,
  .label = NULL, .value_labels = NULL, .factor = FALSE, .use_labels = FALSE
)
# → wraps dplyr::recode_values();
#   .use_labels = TRUE: reads attr(x, "labels") to build from→to map automatically
#                       (labels names become the new values; original codes become from)
#   returns haven_labelled if .label/.value_labels set;
#   returns factor if .factor = TRUE

replace_values_survey(
  x, ...,
  from = NULL, to = NULL,
  .label = NULL, .value_labels = NULL
)
# → wraps dplyr::replace_values(); type-stable; no .factor;
#   merges .value_labels with retained labels from x
```

**Internal helpers in R/recode.R** (used only by these functions):

```r
.wrap_labelled(x, label, value_labels)
# Wraps x in haven::labelled() if label or value_labels is non-NULL; else returns x

.factor_from_result(x, value_labels, formula_values)
# Creates factor from x; levels = names(value_labels) if provided, else formula_values in order
```

### Step 4: Registration — R/zzz.R

No new S3 registrations needed. These are plain exported functions, not dispatch methods.

### Step 5: New test file — tests/testthat/test-recode.R

Test sections:
```
1. mutate.survey_base() pre-attachment: labels attrs available inside mutate
2. mutate.survey_base() post-detection: haven_labelled outputs → @metadata
3. case_when_survey(): happy path, .label, .value_labels, .factor, all 3 design types
4. replace_when_survey(): happy path, label inheritance
5. if_else_survey(): happy path, .label, .value_labels
6. na_if_survey(): label removal (.update_labels = TRUE/FALSE)
7. recode_values_survey(): happy path, .use_labels = TRUE, .factor
8. replace_values_survey(): happy path, .value_labels merge
9. Error paths: invalid conditions (delegated to dplyr), label type mismatches
10. Domain preservation: domain column survives through all recoding
```

---

## Open Decisions

### Factor design: `.factor = FALSE` argument vs `*_fct()` variants

**`.factor = FALSE` argument (what the plan uses)**:
```r
recode_values_survey(x, 1 ~ "Minor", 2 ~ "Adult", .factor = TRUE)
```
Pros: One function; follows dplyr arg convention; discoverable.
Cons: When `.factor = TRUE`, `.value_labels` changes meaning slightly.

**Level ordering when `.factor = TRUE`**:
- If `.value_labels` supplied: levels = `names(.value_labels)` in specified order
- If no `.value_labels`: levels = unique values of result in formula appearance order

**Separate `*_fct()` variants (alternative)**:
```r
recode_values_fct <- function(x, ...) recode_values_survey(x, ..., .factor = TRUE)
```
Can be added later as thin wrappers without cost.

---

## Files to Create / Modify

| File | Change |
|------|--------|
| `DESCRIPTION` | Add `haven (>= 2.5.0)` to Imports |
| `R/mutate.R` | Add pre-attachment, post-detection, strip steps |
| `R/utils.R` | Add `.attach_label_attrs()`, `.extract_labelled_outputs()`, `.strip_label_attrs()` |
| `R/recode.R` | **New file**: 6 survey-aware vector functions + internal helpers |
| `R/surveytidy-package.R` | Add `@importFrom haven labelled` if needed |
| `tests/testthat/test-recode.R` | **New test file**: full coverage of all 6 functions |
| `plans/error-messages.md` | Add any new error/warning classes |

---

## Verification Script

```r
# 1. Load package
devtools::load_all()

# 2. Create design
library(dplyr)
df <- data.frame(id = 1:10, age = c(15, 25, 35, 12, 67, 45, 18, 22, 9, 55),
                 wt = rep(1, 10), psu = rep(1:2, 5), strata = rep("A", 10))
d <- surveycore::as_survey(df, weights = wt, ids = psu, strata = strata)

# 3. Test case_when_survey
d2 <- mutate(d, age_cat = case_when_survey(
  age < 18 ~ "minor",
  .default = "adult",
  .label = "Age category",
  .value_labels = c("Minor" = "minor", "Adult" = "adult")
))
stopifnot(!is.null(d2@metadata@variable_labels$age_cat))     # label extracted
stopifnot(!is.null(d2@metadata@value_labels$age_cat))        # value labels extracted
stopifnot(!inherits(d2@data$age_cat, "haven_labelled"))      # attr stripped from @data

# 4. Test .use_labels
d_lab <- surveycore::set_val_labels(d, age, c("Teen" = 15L, "Young Adult" = 25L))
d3 <- mutate(d_lab, age_str = recode_values_survey(age, .use_labels = TRUE))
stopifnot(d3@data$age_str[d3@data$age == 15] == "Teen")

# 5. Test na_if_survey label removal
d_gender <- surveycore::set_val_labels(d, id, c("Male" = 1L, "Female" = 2L, "Unknown" = 9L))
d4 <- mutate(d_gender, id2 = na_if_survey(id, 9L))
stopifnot(is.null(d4@metadata@value_labels$id2[["Unknown"]]))  # 9L removed from labels

# 6. Run tests
devtools::test()

# 7. R CMD check
devtools::check()
```
