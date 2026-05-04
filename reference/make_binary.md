# Convert a dichotomous variable to a numeric 0/1 indicator

`make_binary()` converts a variable that can be collapsed to exactly two
levels (via
[`make_dicho()`](https://jdenn0514.github.io/surveytidy/reference/make_dicho.md))
into an integer vector of 0s and 1s. By default, the first level maps to
`1L` and the second to `0L`. Use `flip_values = TRUE` to reverse the
mapping.

When called inside
[`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md),
metadata is recorded in `@metadata@transformations[[col]]`.

## Usage

``` r
make_binary(
  x,
  flip_values = FALSE,
  .exclude = NULL,
  .label = NULL,
  .description = NULL
)
```

## Arguments

- x:

  Vector. Same types as
  [`make_factor()`](https://jdenn0514.github.io/surveytidy/reference/make_factor.md).
  Must yield exactly 2 levels (after `.exclude`) or error.

- flip_values:

  `logical(1)`. If `TRUE`, map the first level to `0L` and the second to
  `1L`. Default maps first level to `1L`.

- .exclude:

  `character` or `NULL`. Passed directly to
  [`make_dicho()`](https://jdenn0514.github.io/surveytidy/reference/make_dicho.md).
  Level names to set to `NA` before encoding.

- .label:

  `character(1)` or `NULL`. Variable label override. Falls back to
  `attr(x, "label")` then the column name.

- .description:

  `character(1)` or `NULL`. Transformation description.

## Value

An integer vector with values `0L`, `1L`, or `NA_integer_`.

## See also

Other transformation:
[`make_dicho()`](https://jdenn0514.github.io/surveytidy/reference/make_dicho.md),
[`make_factor()`](https://jdenn0514.github.io/surveytidy/reference/make_factor.md),
[`make_flip()`](https://jdenn0514.github.io/surveytidy/reference/make_flip.md),
[`make_rev()`](https://jdenn0514.github.io/surveytidy/reference/make_rev.md),
[`row_means()`](https://jdenn0514.github.io/surveytidy/reference/row_means.md),
[`row_sums()`](https://jdenn0514.github.io/surveytidy/reference/row_sums.md)

## Examples

``` r
# build a 2-level factor with one NA
x <- factor(
  c("Agree", "Disagree", "Agree", NA),
  levels = c("Agree", "Disagree")
)

# encode as a 0/1 integer indicator
make_binary(x)
#> [1]  1  0  1 NA
#> attr(,"label")
#> [1] "x"
#> attr(,"labels")
#>    Agree Disagree 
#>        1        0 
#> attr(,"surveytidy_recode")
#> attr(,"surveytidy_recode")$fn
#> [1] "make_binary"
#> 
#> attr(,"surveytidy_recode")$var
#> [1] "x"
#> 
#> attr(,"surveytidy_recode")$description
#> NULL
#> 
```
