# Filter survey data using domain estimation

Mark rows as in-domain without removing them. Unlike
[`base::subset()`](https://rdrr.io/r/base/subset.html) or a plain
data-frame filter,
[`filter()`](https://dplyr.tidyverse.org/reference/filter.html) **never
removes rows** from the survey object. Instead it writes a logical
column `..surveycore_domain..` to `@data`. Variance estimation therefore
uses all rows — the full design is intact — while analysis is restricted
to the domain.

Chained [`filter()`](https://dplyr.tidyverse.org/reference/filter.html)
calls AND their conditions together: `filter(d, A) |> filter(d, B)` is
identical to `filter(d, A, B)`.

Physically removes rows from the survey data where `condition` evaluates
to `FALSE`. Unlike
[`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html),
this changes the underlying design and can bias variance estimates.

## Usage

``` r
# S3 method for class 'survey_base'
filter(.data, ..., .by = NULL, .preserve = FALSE)

# S3 method for class 'survey_base'
subset(x, condition, ...)
```

## Arguments

- .data:

  A `survey_taylor`, `survey_replicate`, or `survey_twophase` object
  created by
  [`surveycore::as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.html).

- ...:

  Ignored (for compatibility with the base
  [`subset()`](https://rdrr.io/r/base/subset.html) signature).

- .by:

  Not supported for survey objects. Use
  [`dplyr::group_by()`](https://dplyr.tidyverse.org/reference/group_by.html)
  instead.

- .preserve:

  Ignored (included for compatibility with the dplyr generic signature).

- x:

  A survey design object.

- condition:

  A logical expression evaluated against `x@data`.

## Value

The survey object with an updated `..surveycore_domain..` column in
`@data`. Row count is **unchanged**.

A survey object of the same class with only matching rows retained.

## Details

For subpopulation analyses, use
[`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html)
instead. Only use [`subset()`](https://rdrr.io/r/base/subset.html) when
you have explicitly built the survey design for the subset population.

## Functions

- `subset(survey_base)`: Physically remove rows (use sparingly). Always
  issues `surveycore_warning_physical_subset`. Prefer
  [`filter()`](https://dplyr.tidyverse.org/reference/filter.html) for
  subpopulation analyses.

## Domain estimation vs. physical subsetting

[`filter()`](https://dplyr.tidyverse.org/reference/filter.html) is the
correct tool for subpopulation analyses. Physically removing rows (via
[`base::subset()`](https://rdrr.io/r/base/subset.html),
[`subset()`](https://rdrr.io/r/base/subset.html), or
[`dplyr::slice()`](https://dplyr.tidyverse.org/reference/slice.html))
changes which units contribute to variance estimation and yields
incorrect standard errors. See Thomas Lumley's note for details:
<https://notstatschat.rbind.io/2021/07/22/subsets-and-subpopulations-in-survey-inference>

## See also

[`subset()`](https://rdrr.io/r/base/subset.html) for physical row
removal (with a warning)

Other filtering:
[`filter_out.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/filter_out.survey_base.md)

## Examples

``` r
library(dplyr)
df <- data.frame(y = rnorm(100), x = runif(100),
                 wt = runif(100, 1, 5), g = sample(c("A","B"), 100, TRUE))
d  <- surveycore::as_survey(df, weights = wt)

# Single condition
d_pos <- filter(d, y > 0)

# Multiple conditions (AND-ed)
d_sub <- filter(d, y > 0, g == "A")

# Chained filters produce the same domain column
d_chain <- filter(d, y > 0) |> filter(g == "A")
identical(d_sub@data[[surveycore::SURVEYCORE_DOMAIN_COL]],
          d_chain@data[[surveycore::SURVEYCORE_DOMAIN_COL]])
#> [1] TRUE

# Multi-column helpers: if_any() and if_all()
df2 <- data.frame(a = c(1,2,NA,4), b = c(NA,2,3,4), wt = rep(1,4))
d2  <- surveycore::as_survey(df2, weights = wt)
d_any <- filter(d2, if_any(c(a, b), ~ !is.na(.x)))
d_all <- filter(d2, if_all(c(a, b), ~ !is.na(.x)))
```
