# Exclude rows from a survey domain

The complement of
[`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html).
[`filter_out()`](https://dplyr.tidyverse.org/reference/filter.html)
marks rows **matching** the condition as out-of-domain while leaving all
other rows in-domain. Like
[`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html),
it **never removes rows** from the survey object.

`filter_out(.data, cond)` is equivalent to `filter(.data, !cond)` but
reads more naturally when the intent is exclusion.

Chained calls accumulate via AND: rows must satisfy all prior in-domain
conditions and none of the exclusion conditions to remain in-domain.

## Usage

``` r
# S3 method for class 'survey_base'
filter_out(.data, ..., .by = NULL, .preserve = FALSE)
```

## Arguments

- .data:

  A `survey_taylor`, `survey_replicate`, or `survey_twophase` object
  created by
  [`surveycore::as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.html).

- ...:

  \<[`data-masking`](https://rlang.r-lib.org/reference/args_data_masking.html)\>
  Logical conditions evaluated against `@data`. Rows where **all**
  conditions are `TRUE` are marked as out-of-domain. `NA` results are
  treated as `FALSE` (the row stays in-domain).

- .by:

  Not supported for survey objects. Use
  [`dplyr::group_by()`](https://dplyr.tidyverse.org/reference/group_by.html)
  instead.

- .preserve:

  Ignored (included for compatibility with the dplyr generic signature).

## Value

The survey object with an updated `..surveycore_domain..` column in
`@data`. Row count is **unchanged**.

## See also

[`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html)
for including rows in the domain

Other filtering:
[`filter.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/filter.survey_base.md)

## Examples

``` r
library(dplyr)
df <- data.frame(y = rnorm(100), x = runif(100),
                 wt = runif(100, 1, 5), g = sample(c("A","B"), 100, TRUE))
d <- surveycore::as_survey(df, weights = wt)

# Exclude negative y values
d_out <- filter_out(d, y < 0)

# Equivalent to negating the condition in filter()
d_inv <- filter(d, !(y < 0))
identical(d_out@data[[surveycore::SURVEYCORE_DOMAIN_COL]],
          d_inv@data[[surveycore::SURVEYCORE_DOMAIN_COL]])
#> [1] TRUE

# Chain with filter() — only x > 0.5 rows that are NOT in group B
d_chain <- filter(d, x > 0.5) |> filter_out(g == "B")
```
