# Add or modify columns of a survey design object

Delegates to
[`dplyr::mutate()`](https://dplyr.tidyverse.org/reference/mutate.html)
on `@data`, then:

- Re-attaches any design variables dropped by `.keep = "none"` or
  `.keep = "used"`.

- Appends newly created columns to `@variables$visible_vars` when it is
  set.

- Records the transformation expression for new columns in
  `@metadata@transformations`.

- Respects `@groups` set by
  [`dplyr::group_by()`](https://dplyr.tidyverse.org/reference/group_by.html)
  — pass `.by = NULL` (the default) and grouping from
  [`group_by()`](https://dplyr.tidyverse.org/reference/group_by.html) is
  applied automatically.

## Usage

``` r
# S3 method for class 'survey_base'
mutate(
  .data,
  ...,
  .by = NULL,
  .keep = c("all", "used", "unused", "none"),
  .before = NULL,
  .after = NULL
)
```

## Arguments

- .data:

  A survey design object.

- ...:

  \<[`data-masking`](https://rlang.r-lib.org/reference/args_data_masking.html)\>
  Name-value pairs. The name gives the new column name; the value is an
  expression evaluated against `@data`.

- .by:

  Not used directly — use
  [`dplyr::group_by()`](https://dplyr.tidyverse.org/reference/group_by.html)
  instead. If `@groups` is set and `.by` is `NULL`, `@groups` is used as
  the effective grouping.

- .keep:

  Which columns to retain. One of `"all"` (default), `"used"`,
  `"unused"`, or `"none"`. Design variables are always re-attached
  regardless of `.keep`.

- .before, .after:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Optionally position new columns before or after an existing one.

## Value

The survey object with updated `@data`, `@variables$visible_vars`, and
`@metadata@transformations`.

## Detecting design variable modification

If the left-hand side of a mutation names a design variable (e.g.,
`mutate(d, wt = wt * 2)`), a `surveytidy_warning_mutate_design_var`
warning is issued. Detection is name-based —
[`across()`](https://dplyr.tidyverse.org/reference/across.html) calls
that happen to modify design variables will **not** trigger the warning.

## See also

[`dplyr::rename()`](https://dplyr.tidyverse.org/reference/rename.html)
to rename columns,
[`dplyr::select()`](https://dplyr.tidyverse.org/reference/select.html)
to drop columns

Other modification:
[`rename.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/rename.survey_base.md)

## Examples

``` r
library(dplyr)
df <- data.frame(y = rnorm(100), wt = runif(100, 1, 5),
                 g = sample(c("A","B"), 100, TRUE))
d  <- surveycore::as_survey(df, weights = wt)

# Add a new column
d2 <- mutate(d, y_sq = y^2)

# Grouped mutate
d3 <- d |>
  group_by(g) |>
  mutate(g_mean = mean(y))
```
