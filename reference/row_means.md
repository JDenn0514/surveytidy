# Compute row-wise means across selected columns

`row_means()` computes the mean of each row across a tidyselect-selected
set of numeric columns. It is designed for use inside
[`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md)
on survey design objects. When called inside
[`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md),
the transformation is recorded in `@metadata@transformations[[col]]`.

## Usage

``` r
row_means(.cols, na.rm = FALSE, .label = NULL, .description = NULL)
```

## Arguments

- .cols:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Columns to average across, evaluated via
  [`dplyr::pick()`](https://dplyr.tidyverse.org/reference/pick.html).
  Typical values: `c(a, b, c)`, `starts_with("y")`, `where(is.numeric)`.
  Must resolve to at least one column, and all selected columns must be
  numeric.

- na.rm:

  `logical(1)`. If `TRUE`, `NA` values are excluded before computing the
  mean. If all values in a row are `NA` and `na.rm = TRUE`, the result
  is `NaN` (matching base R
  [`rowMeans()`](https://rdrr.io/r/base/colSums.html) behavior). Default
  `FALSE`.

- .label:

  `character(1)` or `NULL`. Variable label stored in
  `@metadata@variable_labels[[col]]` after
  [`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md).
  If `NULL`, falls back to the output column name from
  [`dplyr::cur_column()`](https://dplyr.tidyverse.org/reference/context.html).

- .description:

  `character(1)` or `NULL`. Plain-language description of the
  transformation stored in
  `@metadata@transformations[[col]]$description` after
  [`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md).

## Value

A `double` vector of length equal to the number of rows in the current
data context.

## See also

Other transformation:
[`make_binary()`](https://jdenn0514.github.io/surveytidy/reference/make_binary.md),
[`make_dicho()`](https://jdenn0514.github.io/surveytidy/reference/make_dicho.md),
[`make_factor()`](https://jdenn0514.github.io/surveytidy/reference/make_factor.md),
[`make_flip()`](https://jdenn0514.github.io/surveytidy/reference/make_flip.md),
[`make_rev()`](https://jdenn0514.github.io/surveytidy/reference/make_rev.md),
[`row_sums()`](https://jdenn0514.github.io/surveytidy/reference/row_sums.md)

## Examples

``` r
# create a dummy survey object
d <- surveycore::as_survey(
  data.frame(
    y1 = c(1, 2, 3),
    y2 = c(4, 5, 6),
    wt = c(1, 1, 1)
  ),
  weights = wt
)

# use a vector of columns to create the score
mutate(d, score = row_means(c(y1, y2)))
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 3
#> 
#> # A tibble: 3 × 4
#>      y1    y2    wt score
#>   <dbl> <dbl> <dbl> <dbl>
#> 1     1     4     1   2.5
#> 2     2     5     1   3.5
#> 3     3     6     1   4.5

# use tidy-select for columns and add a label
d |>
  mutate(
    score = row_means(
      tidyselect::starts_with("y"),
      na.rm = TRUE,
      .label = "Score"
    )
  )
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 3
#> 
#> # A tibble: 3 × 4
#>      y1    y2    wt score
#>   <dbl> <dbl> <dbl> <dbl>
#> 1     1     4     1   2.5
#> 2     2     5     1   3.5
#> 3     3     6     1   4.5
```
