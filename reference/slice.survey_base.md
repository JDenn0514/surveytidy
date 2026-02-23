# Physically select rows of a survey design object

[`slice()`](https://dplyr.tidyverse.org/reference/slice.html),
[`slice_head()`](https://dplyr.tidyverse.org/reference/slice.html),
[`slice_tail()`](https://dplyr.tidyverse.org/reference/slice.html),
[`slice_min()`](https://dplyr.tidyverse.org/reference/slice.html),
[`slice_max()`](https://dplyr.tidyverse.org/reference/slice.html), and
[`slice_sample()`](https://dplyr.tidyverse.org/reference/slice.html)
**physically remove rows** and always issue
`surveycore_warning_physical_subset`. They error if the result would
have 0 rows. Prefer
[`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html)
for subpopulation analyses.

`slice_sample(weight_by = )` additionally warns with
`surveytidy_warning_slice_sample_weight_by` because the `weight_by`
column is independent of the survey design weights.

## Usage

``` r
# S3 method for class 'survey_base'
slice(.data, ...)

# S3 method for class 'survey_base'
slice_head(.data, ...)

# S3 method for class 'survey_base'
slice_tail(.data, ...)

# S3 method for class 'survey_base'
slice_min(.data, ...)

# S3 method for class 'survey_base'
slice_max(.data, ...)

# S3 method for class 'survey_base'
slice_sample(.data, ...)
```

## Arguments

- .data:

  A survey design object.

- ...:

  Passed to the corresponding `dplyr::slice_*()` function.

## Value

A physical subset of the survey object's rows.

## Functions

- `slice_head(survey_base)`: Select first `n` rows.

- `slice_tail(survey_base)`: Select last `n` rows.

- `slice_min(survey_base)`: Select rows with the smallest values.

- `slice_max(survey_base)`: Select rows with the largest values.

- `slice_sample(survey_base)`: Randomly sample rows.

## See also

[`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html)
for domain-aware row marking (preferred),
[`dplyr::arrange()`](https://dplyr.tidyverse.org/reference/arrange.html)
for row sorting

Other row operations:
[`arrange.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/arrange.survey_base.md),
[`drop_na.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/drop_na.survey_base.md)

## Examples

``` r
library(dplyr)
df <- data.frame(y = rnorm(100), wt = runif(100, 1, 5))
d  <- surveycore::as_survey(df, weights = wt)

# Physical row selection (issues warning)
d2 <- suppressWarnings(slice_head(d, n = 20))
```
