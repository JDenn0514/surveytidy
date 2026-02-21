# Group and ungroup a survey design object

- [`group_by()`](https://dplyr.tidyverse.org/reference/group_by.html)
  stores grouping column names in `@groups`. Unlike dplyr, **no
  `grouped_df` attribute** is attached to `@data` — grouping is kept on
  the survey object itself. Phase 1 estimation functions and
  [`dplyr::mutate()`](https://dplyr.tidyverse.org/reference/mutate.html)
  read `@groups` to apply grouped calculations.

- [`ungroup()`](https://dplyr.tidyverse.org/reference/group_by.html)
  with no arguments removes all groups. With column arguments it
  performs a **partial ungroup**, removing only the named columns from
  `@groups`.

## Usage

``` r
# S3 method for class 'survey_base'
group_by(.data, ..., .add = FALSE, .drop = dplyr::group_by_drop_default(.data))

# S3 method for class 'survey_base'
ungroup(x, ...)
```

## Arguments

- .data:

  A survey design object.

- ...:

  \<[`data-masking`](https://rlang.r-lib.org/reference/args_data_masking.html)\>
  Variables to group by. Computed expressions (e.g., `cut(age, breaks)`)
  are supported.

- .add:

  Logical. If `TRUE`, add to existing groups rather than replacing them.

- .drop:

  Passed to
  [`dplyr::group_by_drop_default()`](https://dplyr.tidyverse.org/reference/group_by_drop_default.html).

- x:

  A survey design object (for
  [`ungroup()`](https://dplyr.tidyverse.org/reference/group_by.html)).

## Value

The survey object with `@groups` updated.

## Functions

- `ungroup(survey_base)`: Remove grouping variables.

## Examples

``` r
library(dplyr)
df <- data.frame(y = rnorm(100), wt = runif(100, 1, 5),
                 region = sample(c("N","S","E","W"), 100, TRUE))
d  <- surveycore::as_survey(df, weights = wt)

# Group and then compute group means via mutate()
d2 <- d |>
  group_by(region) |>
  mutate(region_mean = mean(y))

# Partial ungroup
d3 <- group_by(d, region)
d4 <- ungroup(d3)          # remove all groups
```
