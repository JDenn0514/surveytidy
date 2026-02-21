# Sort rows and physically select rows of a survey design object

- `arrange()` sorts rows in `@data`. The domain column moves with the
  rows — no update to `@variables$domain` is needed. Supports
  `.by_group = TRUE` using `@groups` set by
  [`dplyr::group_by()`](https://dplyr.tidyverse.org/reference/group_by.html).

- `slice()`, `slice_head()`, `slice_tail()`, `slice_min()`,
  `slice_max()`, and `slice_sample()` **physically remove rows** and
  always issue `surveycore_warning_physical_subset`. They error if the
  result would have 0 rows. Prefer
  [`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html)
  for subpopulation analyses.

- `slice_sample(weight_by = )` additionally warns with
  `surveytidy_warning_slice_sample_weight_by` because the `weight_by`
  column is independent of the survey design weights.

## Usage

``` r
# S3 method for class 'survey_base'
arrange(.data, ..., .by_group = FALSE)

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

  For [`arrange()`](https://dplyr.tidyverse.org/reference/arrange.html):
  \<[`data-masking`](https://rlang.r-lib.org/reference/args_data_masking.html)\>
  variables or expressions to sort by. For `slice_*()`: passed to the
  corresponding `dplyr::slice_*()` function.

- .by_group:

  Logical. If `TRUE` and `@groups` is set, rows are sorted by the
  grouping variables first, then by `...`.

## Value

The survey object with rows reordered
([`arrange()`](https://dplyr.tidyverse.org/reference/arrange.html)) or a
physical subset of rows (`slice_*()`).

## Functions

- `slice(survey_base)`: Select rows by position.

- `slice_head(survey_base)`: Select first `n` rows.

- `slice_tail(survey_base)`: Select last `n` rows.

- `slice_min(survey_base)`: Select rows with the smallest values.

- `slice_max(survey_base)`: Select rows with the largest values.

- `slice_sample(survey_base)`: Randomly sample rows.

## See also

[`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html)
for domain-aware row marking (preferred)

Other row operations:
[`drop_na.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/drop_na.survey_base.md)

## Examples

``` r
library(dplyr)
#> 
#> Attaching package: ‘dplyr’
#> The following objects are masked from ‘package:stats’:
#> 
#>     filter, lag
#> The following objects are masked from ‘package:base’:
#> 
#>     intersect, setdiff, setequal, union
df <- data.frame(y = rnorm(100), wt = runif(100, 1, 5),
                 g = sample(c("A","B"), 100, TRUE))
d  <- surveycore::as_survey(df, weights = wt)

# Sort rows
d2 <- arrange(d, y)
d3 <- arrange(d, desc(y))

# Physical row selection (issues warning)
d4 <- suppressWarnings(slice_head(d, n = 20))
```
