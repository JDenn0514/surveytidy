# Reverse the numeric values of a scale variable

`make_rev()` reverses the direction of a numeric scale variable using
the formula `min(x) + max(x) - x`. This preserves the scale range: a 1-4
scale reversed stays a 1-4 scale; a 2-5 scale reversed stays a 2-5
scale.

Value labels are remapped: each label's numeric value becomes
`min + max - old_value`, so the label string stays tied to its original
concept at its new position.

When called inside
[`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md),
metadata is recorded in `@metadata@transformations[[col]]`.

## Usage

``` r
make_rev(x, .label = NULL, .description = NULL)
```

## Arguments

- x:

  A numeric vector. `typeof(x)` must be `"double"` or `"integer"`.

- .label:

  `character(1)` or `NULL`. Variable label override. If `NULL`, inherits
  from `attr(x, "label")`; if that is also `NULL`, falls back to the
  column name.

- .description:

  `character(1)` or `NULL`. Transformation description.

## Value

A numeric vector (same [`typeof()`](https://rdrr.io/r/base/typeof.html)
as `x`) with reversed values.

## See also

Other transformation:
[`make_binary()`](https://jdenn0514.github.io/surveytidy/reference/make_binary.md),
[`make_dicho()`](https://jdenn0514.github.io/surveytidy/reference/make_dicho.md),
[`make_factor()`](https://jdenn0514.github.io/surveytidy/reference/make_factor.md),
[`make_flip()`](https://jdenn0514.github.io/surveytidy/reference/make_flip.md),
[`row_means()`](https://jdenn0514.github.io/surveytidy/reference/row_means.md),
[`row_sums()`](https://jdenn0514.github.io/surveytidy/reference/row_sums.md)

## Examples

``` r
# reverse a 1-4 numeric scale: 1 swaps with 4, 2 swaps with 3
x <- c(1, 2, 3, 4)
make_rev(x)
#> [1] 4 3 2 1
#> attr(,"label")
#> [1] "x"
#> attr(,"surveytidy_recode")
#> attr(,"surveytidy_recode")$fn
#> [1] "make_rev"
#> 
#> attr(,"surveytidy_recode")$var
#> [1] "x"
#> 
#> attr(,"surveytidy_recode")$description
#> NULL
#> 
```
