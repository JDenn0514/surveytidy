# Collapse a multi-level factor to two levels

`make_dicho()` converts a variable to a two-level factor by stripping
the first qualifier word from each level label and grouping the
resulting stems. For example, a 4-level Likert scale with labels
`c("Strongly agree", "Agree", "Disagree", "Strongly disagree")`
collapses to `c("Agree", "Disagree")` by removing the qualifier
"Strongly".

When called inside
[`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md),
metadata is recorded in `@metadata@transformations[[col]]`.

## Usage

``` r
make_dicho(
  x,
  flip_levels = FALSE,
  .exclude = NULL,
  .label = NULL,
  .description = NULL
)
```

## Arguments

- x:

  Vector. Same types as
  [`make_factor()`](https://jdenn0514.github.io/surveytidy/reference/make_factor.md).

- flip_levels:

  `logical(1)`. If `TRUE`, reverse the order of the two output levels.

- .exclude:

  `character` or `NULL`. Level name(s) to set to `NA` before collapsing.
  Intended for middle categories and "don't know"/"refused".

- .label:

  `character(1)` or `NULL`. Variable label override. Falls back to
  `attr(x, "label")` then the column name.

- .description:

  `character(1)` or `NULL`. Transformation description.

## Value

A 2-level R factor.

## See also

Other transformation:
[`make_binary()`](https://jdenn0514.github.io/surveytidy/reference/make_binary.md),
[`make_factor()`](https://jdenn0514.github.io/surveytidy/reference/make_factor.md),
[`make_flip()`](https://jdenn0514.github.io/surveytidy/reference/make_flip.md),
[`make_rev()`](https://jdenn0514.github.io/surveytidy/reference/make_rev.md)

## Examples

``` r
library(dplyr)
x <- factor(
  c("Always agree", "Sometimes agree", "Sometimes disagree", "Always disagree"),
  levels = c("Always agree", "Sometimes agree", "Sometimes disagree",
             "Always disagree")
)
make_dicho(x)
#>       Always agree    Sometimes agree Sometimes disagree    Always disagree 
#>              Agree              Agree           Disagree           Disagree 
#> attr(,"label")
#> [1] x
#> attr(,"surveytidy_recode")
#> attr(,"surveytidy_recode")$fn
#> [1] make_dicho
#> 
#> attr(,"surveytidy_recode")$var
#> [1] x
#> 
#> attr(,"surveytidy_recode")$description
#> NULL
#> 
#> Levels: Agree Disagree
```
