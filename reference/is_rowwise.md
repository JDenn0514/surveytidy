# Test whether a survey design is in rowwise mode

Returns `TRUE` if the design was created (or passed through)
[`rowwise()`](https://dplyr.tidyverse.org/reference/rowwise.html). Use
this predicate in estimation functions to detect and handle (or
disallow) rowwise mode.

## Usage

``` r
is_rowwise(design)
```

## Arguments

- design:

  A
  [`survey_base`](https://jdenn0514.github.io/surveycore/reference/survey_base.html)
  object.

## Value

A scalar logical.

## See also

Other grouping:
[`group_by.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/group_by.survey_base.md),
[`is_grouped()`](https://jdenn0514.github.io/surveytidy/reference/is_grouped.md),
[`rowwise.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/rowwise.survey_base.md)

## Examples

``` r
library(surveytidy)
library(surveycore)
d <- as_survey(pew_npors_2025, weights = weight, strata = stratum)

is_rowwise(d)           # FALSE
#> [1] FALSE
is_rowwise(rowwise(d))  # TRUE
#> [1] TRUE
```
