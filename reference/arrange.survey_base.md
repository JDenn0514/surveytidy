# Sort rows of a survey design object

[`arrange()`](https://dplyr.tidyverse.org/reference/arrange.html) sorts
rows in `@data`. The domain column moves with the rows — no update to
`@variables$domain` is needed. Supports `.by_group = TRUE` using
`@groups` set by
[`dplyr::group_by()`](https://dplyr.tidyverse.org/reference/group_by.html).

For physically removing rows, see
[`dplyr::slice()`](https://dplyr.tidyverse.org/reference/slice.html).
Prefer
[`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html)
for subpopulation analyses.

## Usage

``` r
# S3 method for class 'survey_base'
arrange(.data, ..., .by_group = FALSE)
```

## Arguments

- .data:

  A survey design object.

- ...:

  \<[`data-masking`](https://rlang.r-lib.org/reference/args_data_masking.html)\>
  Variables or expressions to sort by.

- .by_group:

  Logical. If `TRUE` and `@groups` is set, rows are sorted by the
  grouping variables first, then by `...`.

## Value

The survey object with rows reordered.

## See also

[`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html)
for domain-aware row marking (preferred),
[`dplyr::slice()`](https://dplyr.tidyverse.org/reference/slice.html) for
physical row selection

Other row operations:
[`drop_na.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/drop_na.survey_base.md),
[`slice.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/slice.survey_base.md)

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
```
