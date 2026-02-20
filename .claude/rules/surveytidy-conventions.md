# surveytidy R Package Conventions

**Version:** 1.0
**Created:** February 2025
**Status:** Detailed examples and guidance specific to surveytidy

This document extends the **generic R package conventions** (in `../survey-standards/.claude/rules/r-package-conventions.md`) with surveytidy-specific examples and detailed guidance.

**Read the generic conventions first, then this document for context.**

---

## Quick Reference (surveytidy-specific)

| Decision | Choice | Example |
|----------|--------|---------|
| Verb dispatch | S3 via `registerS3method()` | Not S7 methods; registered in `.onLoad()` |
| Method names | `verb.survey_base` | `filter.survey_base`, `select.survey_base` |
| Entry points | dplyr verb functions | `filter()`, `select()`, `mutate()`, etc. |
| `@seealso` | Not used | dplyr verbs don't link to each other |
| `@family` groups | By verb type | `filtering`, `selecting`, `modification`, etc. |
| Return values | Survey object (invisibly or visible) | Always return modified `x` |
| Data column tracking | Domain + visible_vars | Special columns for filtering and display |

---

## 1. Documentation Examples for surveytidy

### dplyr Verb Documentation

Each dplyr verb gets documentation that explains how it works **with survey objects**:

```r
#' Filter survey data (domain-aware)
#'
#' @description
#' `filter()` marks rows in or out of the survey domain without removing them.
#' This preserves the variance estimation validity of the design. Contrast with
#' [base::subset()], which physically removes rows and issues a warning.
#'
#' Internally, `filter()` creates or updates the domain column
#' (`..surveycore_domain..`) to track domain membership for each row. Multiple
#' `filter()` calls AND the conditions together.
#'
#' @param .data A survey design object (from [surveycore::as_survey()], etc.)
#'
#' @param ... <[`data-masking`][rlang::args_data_masking]> Logical conditions
#'   to define the survey domain. Can use column names and computed expressions.
#'   Multiple conditions are combined with `&`.
#'
#' @details
#'
#' ## Domain Estimation vs Physical Subsetting
#'
#' **Domain estimation** (`filter()`): Marks rows in/out of domain.
#' - Preserves all rows (for variance calculation)
#' - Variance estimators treat out-of-domain rows as zero-weight
#' - Chained filters AND their conditions
#'
#' **Physical subsetting** (`subset()`): Actually removes rows.
#' - Issues `surveycore_warning_physical_subset`
#' - Cannot be reversed (information lost)
#' - Only use when you know what you're doing
#'
#' @return A modified survey object with updated domain column.
#'
#' @examples
#' # Create a design
#' d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtmec2yr,
#'                strata = sdmvstra, nest = TRUE)
#'
#' # Filter to adults (domain-aware)
#' adults <- d |> filter(ridageyr >= 18)
#'
#' # Multiple conditions (combined with &)
#' adult_females <- d |>
#'   filter(ridageyr >= 18) |>
#'   filter(riagendr == 2)
#'
#' @export
filter.survey_base <- function(.data, ...) {
  # implementation
}
```

### `@family` groups for surveytidy

```r
#' @family filtering
filter.survey_base <- function(...) { ... }

#' @family selecting
select.survey_base <- function(...) { ... }

#' @family modification
mutate.survey_base <- function(...) { ... }
```

### `@return` for dplyr verbs

All dplyr verbs return the modified survey object:

```r
#' @return `.data` with the filter applied (domain marked, rows preserved).
#'
#' @return `.data` with selected columns only (other columns hidden from print).
#'
#' @return `.data` with new/modified columns added.
```

---

## 2. Naming Conventions (surveytidy-specific)

### Function names
- **dplyr verbs**: `filter()`, `select()`, `mutate()`, `rename()`, `arrange()`, `group_by()`, `ungroup()`
- **tidyr verbs**: `drop_na()`, `separate()`, `separate_rows()`, `unite()`
- **Helper function**: `dplyr_reconstruct.survey_base()` (internal)

### Method registration (not S7)

surveytidy uses S3 method registration to hook into dplyr's dispatch:

```r
# NOT S7::method() — that's for surveycore!
# These are plain functions registered as S3 methods:

filter.survey_base <- function(.data, ...) {
  # implementation
}

select.survey_base <- function(.data, ...) {
  # implementation
}

# Registration happens in R/00-zzz.R:
registerS3method("filter", "surveycore::survey_base", filter.survey_base)
registerS3method("select", "surveycore::survey_base", select.survey_base)
```

This works because we register with dplyr's namespace, not our own.

---

## 3. Special Columns (surveytidy-specific)

### Domain Column

All survey objects may have a domain column for tracking in-domain rows:

- **Name**: `"..surveycore_domain.."` (use `surveycore::SURVEYCORE_DOMAIN_COL`)
- **Type**: logical column in `@data`
- **Content**: `TRUE` for in-domain rows, `FALSE` for out-of-domain
- **Lifecycle**: Created by first `filter()` call, updated by subsequent calls

```r
# After filter(d, age > 65):
# d@data[["..surveycore_domain.."]] contains TRUE/FALSE for each row
```

### visible_vars

Controls which columns `print()` shows:

- **Key**: `@variables$visible_vars`
- **Type**: character vector of column names (or `NULL` for all)
- **Set by**: `select()` verb
- **Behavior**: Only affects printing, not actual data

```r
# After select(d, age, income, health):
# d@variables$visible_vars <- c("age", "income", "health")
# print(d) hides other columns but they're still in d@data
```

### @groups (Phase 0.5)

Populated by `group_by()`, used by Phase 1 estimation functions:

- **Key**: `@groups`
- **Type**: character vector of column names (or empty for no grouping)
- **Set by**: `group_by()`
- **Cleared by**: `ungroup()`
- **Used by**: Phase 1 estimation functions for stratified analysis

```r
# After group_by(d, region, state):
# d@groups <- c("region", "state")
```

---

## 4. dplyr_reconstruct() Pattern

For complex operations (joins, `across()`, `slice()`), dplyr calls `dplyr_reconstruct()` to rebuild your object:

```r
#' Reconstruct survey object after dplyr operations
#'
#' @param data Modified data.frame from dplyr verb
#' @param template Original survey object (used as template)
#' @return Reconstructed survey object with `data` and original template metadata
#' @keywords internal
#' @noRd
dplyr_reconstruct.survey_base <- function(data, template) {
  # Check that design variables still exist
  if (!all(unlist(template@variables[c("ids", "weights", "strata", "fpc")]) %in% names(data))) {
    cli::cli_abort(
      c("x" = "Required design variables were removed."),
      class = "surveycore_error_design_var_removed"
    )
  }

  # Rebuild the survey class with new data but same metadata
  new_class <- class(template)[1]  # e.g., "survey_taylor"
  do.call(new_class, list(data = data, variables = template@variables, metadata = template@metadata))
}
```

---

## 5. Return Value Visibility (surveytidy-specific)

All dplyr verbs return **the modified survey object**:

```r
# filter() — always return the modified survey object
filter.survey_base <- function(.data, ...) {
  # ... process conditions ...
  modified_data  # visible return (user wants to see what was filtered)
}

# mutate() — same pattern
mutate.survey_base <- function(.data, ...) {
  # ... add columns ...
  modified_data  # visible return
}
```

No function should return invisibly (contrast with surveycore setters like `set_var_label()`).

---

## 6. Export Policy (surveytidy-specific)

### What to export
- All dplyr verbs: `filter()`, `select()`, `mutate()`, `rename()`, `arrange()`
- All tidyr verbs: `drop_na()`, `separate()`, `unite()`
- Grouping verbs: `group_by()`, `ungroup()`
- Utility functions: `glimpse()`, `pull()`

### What NOT to export
- Method implementations: `filter.survey_base()` is not exported (dplyr uses it internally)
- Internal reconstruction: `dplyr_reconstruct.survey_base()` (internal helper)
- Internal utilities: `.resolve_tidy_select()`, etc.

```r
# Do NOT export method implementations (dplyr finds them automatically)
# filter.survey_base <- function(...) { ... }  # NO @export tag

# DO export the generic verb (if not already from dplyr)
# But dplyr already exports filter(), select(), etc., so surveytidy re-exports:

#' @importFrom dplyr filter select mutate rename arrange group_by ungroup
#' @export
#' @describeIn dplyr dplyr verbs for survey objects
filter

#' @export
select
```

Actually, surveytidy likely just `@importFrom dplyr` the verbs in the package documentation:

```r
# In surveytidy-package.R
#' @importFrom dplyr filter select mutate rename arrange group_by ungroup
#' @keywords internal
"_PACKAGE"
```

---

## 7. Documentation Checklist for surveytidy

Before committing any roxygen2 changes:

- [ ] `devtools::document()` has been run
- [ ] `NAMESPACE` file has been updated
- [ ] All exported dplyr verbs have clear `@description` of survey behavior
- [ ] All `@examples` are runnable and demonstrate survey-specific behavior
- [ ] `dplyr_reconstruct.survey_base()` has `@keywords internal` + `@noRd`
- [ ] No `@seealso` on verbs (dplyr handles cross-linking)
- [ ] `@family` tags group verbs by type (filtering, selecting, modification)
- [ ] No `@importFrom` tags anywhere (use `::`)
- [ ] All external calls use `::`
- [ ] `R CMD check` passes with 0 errors, 0 warnings, ≤2 notes

---

## 8. Survey-Aware Behavior Examples

When implementing verbs, remember that surveys are special:

### filter() is not subset()
```r
# filter() — domain estimation
d_filtered <- filter(d, age > 65)
# Result: d_filtered has ALL original rows, but domain column updated
# Variance estimation treats out-of-domain rows as zero-weight

# subset() — physical subsetting
d_subset <- subset(d, age > 65)
# Result: d_subset has ONLY rows with age > 65; others removed permanently
# Issues surveycore_warning_physical_subset
```

### select() hides, doesn't remove
```r
# select() — hides columns
d_selected <- select(d, age, income, health)
# Result: Only age, income, health are printed; other columns still in @data
# Updated @variables$visible_vars

# The domain column is always preserved (even if not explicitly selected)
```

### mutate() updates metadata if design vars are modified
```r
# mutate() — adds new column
d_mutated <- mutate(d, age_group = cut(age, breaks = c(0, 18, 65, Inf)))
# Result: New column added; @variables and @metadata unchanged

# BUT: if user modifies a design variable (strata, ids, etc.),
# mutate() should warn and update @variables accordingly
```

---

## Reference

**Generic conventions (all packages):**
`../survey-standards/.claude/rules/r-package-conventions.md`

**surveytidy architecture:**
`CLAUDE.md` in this directory

**surveycore classes & structure:**
`../surveycore/CLAUDE.md`
