# Remove rows containing missing values from a survey design object

Physically removes rows where the specified columns contain `NA`. If no
columns are specified, any `NA` in any column triggers removal. Always
issues `surveycore_warning_physical_subset`. Errors if all rows would be
removed.

Prefer
[`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html)
with `!is.na(col)` for subpopulation analyses — it keeps all rows and
gives correct variance estimates.

## Usage

``` r
# S3 method for class 'survey_base'
drop_na(data, ...)
```

## Arguments

- data:

  A survey design object.

- ...:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Columns to inspect for `NA`. If empty, all columns are checked.

## Value

The survey object with rows containing `NA` in the selected columns
removed.

## See also

[`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html)
for domain-aware row marking (preferred)

Other row operations:
[`arrange.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/arrange.survey_base.md)

## Examples

``` r
library(tidyr)
df <- data.frame(y = c(rnorm(99), NA), wt = runif(100, 1, 5))
d  <- surveycore::as_survey(df, weights = wt)

# Remove rows with NA in y
d2 <- suppressWarnings(drop_na(d, y))
nrow(d2@data)  # 99
#> [1] 99
```
