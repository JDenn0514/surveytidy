# Test whether a survey design has active grouping

Returns `TRUE` if the design has one or more grouping columns set via
[`group_by()`](https://dplyr.tidyverse.org/reference/group_by.html).
Returns `FALSE` for ungrouped or rowwise (but not grouped) designs.

## Usage

``` r
is_grouped(design)
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
[`is_rowwise()`](https://jdenn0514.github.io/surveytidy/reference/is_rowwise.md),
[`rowwise.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/rowwise.survey_base.md)

## Examples

``` r
library(surveytidy)
library(surveycore)
library(dplyr)
d <- as_survey(pew_npors_2025, weights = weight, strata = stratum)

is_grouped(d)                   # FALSE
#> [1] FALSE
is_grouped(group_by(d, gender)) # TRUE
#> [1] TRUE
is_grouped(rowwise(d))          # FALSE (rowwise != grouped)
#> [1] FALSE
```
