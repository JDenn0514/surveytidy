# Append columns to a survey design by position

`bind_cols()` appends columns from one or more plain data frames to a
survey design object, matching by row position. This is equivalent to an
implicit row-index
[`left_join()`](https://jdenn0514.github.io/surveytidy/reference/left_join.md).
All rows are preserved; row count is unchanged.

When `x` is not a survey object, this function delegates to
[`dplyr::bind_cols()`](https://dplyr.tidyverse.org/reference/bind_cols.html)
transparently.

## Usage

``` r
bind_cols(x, ..., .name_repair = "unique")
```

## Arguments

- x:

  A
  [`survey_base`](https://jdenn0514.github.io/surveycore/reference/survey_base.html)
  object, or any object accepted by
  [`dplyr::bind_cols()`](https://dplyr.tidyverse.org/reference/bind_cols.html).

- ...:

  One or more plain data frames or named lists. When `x` is a survey
  object, none of the objects may be survey objects.

- .name_repair:

  Forwarded to
  [`dplyr::bind_cols()`](https://dplyr.tidyverse.org/reference/bind_cols.html).

## Value

When `x` is a survey object: a survey design object of the same type as
`x` with new columns appended to `@data`. `visible_vars` is updated if
it was set. When `x` is not a survey object: the result of
[`dplyr::bind_cols()`](https://dplyr.tidyverse.org/reference/bind_cols.html).

## Details

### Design integrity

None of the objects in `...` may be a survey object. If any new column
name matches a design variable in `x`, that column is dropped with a
warning. All inputs in `...` must have exactly the same number of rows
as `x`.

### Dispatch note

[`dplyr::bind_cols()`](https://dplyr.tidyverse.org/reference/bind_cols.html)
uses
[`vctrs::vec_cbind()`](https://vctrs.r-lib.org/reference/vec_bind.html)
internally and does not dispatch via S3 on `x`. surveytidy provides its
own `bind_cols()` that intercepts survey objects before delegating to
dplyr.

## See also

Other joins:
[`bind_rows()`](https://jdenn0514.github.io/surveytidy/reference/bind_rows.md),
[`inner_join`](https://jdenn0514.github.io/surveytidy/reference/inner_join.md),
[`left_join`](https://jdenn0514.github.io/surveytidy/reference/left_join.md),
[`right_join`](https://jdenn0514.github.io/surveytidy/reference/right_join.md),
[`semi_join`](https://jdenn0514.github.io/surveytidy/reference/semi_join.md)

## Examples

``` r
library(surveytidy)

# create a small survey object
df <- data.frame(
  psu = paste0("psu_", 1:5),
  strata = "s1",
  fpc = 100,
  wt = 1,
  y1 = 1:5
)
d <- surveycore::as_survey(
  df,
  ids = psu,
  weights = wt,
  strata = strata,
  fpc = fpc,
  nest = TRUE
)
#> Warning: ! `strata` (strata) has only 1 unique value — stratification has no effect

# append a new column by row position
extra <- data.frame(label = letters[1:5])
bind_cols(d, extra)
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 5
#> 
#> # A tibble: 5 × 6
#>   psu   strata   fpc    wt    y1 label
#>   <chr> <chr>  <dbl> <dbl> <int> <chr>
#> 1 psu_1 s1       100     1     1 a    
#> 2 psu_2 s1       100     1     2 b    
#> 3 psu_3 s1       100     1     3 c    
#> 4 psu_4 s1       100     1     4 d    
#> 5 psu_5 s1       100     1     5 e    
```
