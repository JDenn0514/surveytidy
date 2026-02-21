# Rename columns of a survey design object

Renames columns in `@data` and automatically keeps the survey design in
sync:

- `@variables` — design variable column names (weights, strata, PSU,
  FPC, replicate weights) are updated to the new names.

- `@metadata` — variable labels, value labels, question prefaces, notes,
  and transformation records are re-keyed.

- `@variables$visible_vars` — any occurrence of the old name is replaced
  with the new name.

Renaming a design variable is allowed and issues
`surveytidy_warning_rename_design_var` to confirm the design was
updated.

## Usage

``` r
# S3 method for class 'survey_base'
rename(.data, ...)
```

## Arguments

- .data:

  A survey design object.

- ...:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Use `new_name = old_name` pairs to rename columns.

## Value

The survey object with updated column names, `@variables`, and
`@metadata`.

## See also

[`dplyr::mutate()`](https://dplyr.tidyverse.org/reference/mutate.html)
to add columns,
[`dplyr::select()`](https://dplyr.tidyverse.org/reference/select.html)
to drop columns

Other modification:
[`mutate.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/mutate.survey_base.md)

## Examples

``` r
library(dplyr)
df <- data.frame(y1 = rnorm(50), y2 = rnorm(50),
                 wt = runif(50, 1, 5))
d  <- surveycore::as_survey(df, weights = wt)

# Rename an outcome column
d2 <- rename(d, outcome = y1)

# Rename a design variable (warns and updates @variables$weights)
d3 <- rename(d, weight = wt)
#> Warning: ! rename() renamed design variable(s): wt.
#> ℹ The survey design has been updated to use the new name(s).
d3@variables$weights  # "weight"
#> [1] "weight"
```
