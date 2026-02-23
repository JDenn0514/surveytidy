# Mark rows with missing values as out-of-domain in a survey design object

Marks rows where the specified columns contain `NA` as out-of-domain,
without removing them. If no columns are specified, any `NA` in any
column marks the row out-of-domain.

This is equivalent to `filter(!is.na(col1), !is.na(col2), ...)` and
gives correct variance estimates for downstream analyses. Successive
`drop_na()` calls AND their conditions together.

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
marked out-of-domain. Row count is **unchanged**.

## See also

[`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html)
for domain-aware row marking

Other row operations:
[`arrange.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/arrange.survey_base.md),
[`slice.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/slice.survey_base.md)

## Examples

``` r
library(tidyr)
df <- data.frame(y = c(rnorm(99), NA), wt = runif(100, 1, 5))
d  <- surveycore::as_survey(df, weights = wt)

# Mark rows with NA in y as out-of-domain
d2 <- drop_na(d, y)
nrow(d2@data)  # still 100
#> [1] 100
d2@data[[surveycore::SURVEYCORE_DOMAIN_COL]]  # FALSE for the last row
#>   [1]  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE
#>  [13]  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE
#>  [25]  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE
#>  [37]  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE
#>  [49]  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE
#>  [61]  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE
#>  [73]  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE
#>  [85]  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE  TRUE
#>  [97]  TRUE  TRUE  TRUE FALSE
```
