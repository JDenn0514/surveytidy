# Flip the semantic valence of a variable

`make_flip()` reverses the label string associations of a numeric
variable without changing its values. This is used to flip the polarity
of a survey item for composite scoring - for example, converting "I like
the color blue" to "I dislike the color blue" without changing the
underlying numeric codes.

Unlike
[`make_rev()`](https://jdenn0514.github.io/surveytidy/reference/make_rev.md),
which changes numeric values and keeps label strings in place,
`make_flip()` keeps values unchanged and reverses which label strings
are attached to which values.

A new variable label is **required** because flipping always changes the
semantic meaning of the variable.

When called inside
[`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md),
metadata is recorded in `@metadata@transformations[[col]]`.

## Usage

``` r
make_flip(x, label, .description = NULL)
```

## Arguments

- x:

  A numeric vector. `typeof(x)` must be `"double"` or `"integer"`.

- label:

  `character(1)`. **Required.** New variable label describing the
  flipped semantic meaning.

- .description:

  `character(1)` or `NULL`. Transformation description.

## Value

A numeric vector (same [`typeof()`](https://rdrr.io/r/base/typeof.html)
as `x`). Values are unchanged.

## See also

Other transformation:
[`make_binary()`](https://jdenn0514.github.io/surveytidy/reference/make_binary.md),
[`make_dicho()`](https://jdenn0514.github.io/surveytidy/reference/make_dicho.md),
[`make_factor()`](https://jdenn0514.github.io/surveytidy/reference/make_factor.md),
[`make_rev()`](https://jdenn0514.github.io/surveytidy/reference/make_rev.md)

## Examples

``` r
x <- c(1, 2, 3, 4)
attr(x, "labels") <- c("Strongly agree" = 1, "Agree" = 2,
                        "Disagree" = 3, "Strongly disagree" = 4)
make_flip(x, "I dislike the color blue")
#> [1] 1 2 3 4
#> attr(,"labels")
#> Strongly disagree          Disagree             Agree    Strongly agree 
#>                 1                 2                 3                 4 
#> attr(,"label")
#> [1] "I dislike the color blue"
#> attr(,"surveytidy_recode")
#> attr(,"surveytidy_recode")$fn
#> [1] "make_flip"
#> 
#> attr(,"surveytidy_recode")$var
#> [1] "x"
#> 
#> attr(,"surveytidy_recode")$description
#> NULL
#> 
```
