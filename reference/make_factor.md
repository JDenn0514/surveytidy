# Convert a vector to a factor using value labels

`make_factor()` converts a labelled numeric, factor, or character vector
to an R factor. For labelled numeric input (e.g., from haven or with a
`"labels"` attribute), factor levels are derived from the value labels.
For factor input, levels are preserved. For character input, levels are
set alphabetically.

When called inside
[`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md),
metadata is recorded in `@metadata@transformations[[col]]`.

## Usage

``` r
make_factor(
  x,
  ordered = FALSE,
  drop_levels = TRUE,
  force = FALSE,
  na.rm = FALSE,
  .label = NULL,
  .description = NULL
)
```

## Arguments

- x:

  Vector to convert. Must be a labelled numeric, plain numeric with a
  `"labels"` attribute, R factor, or character vector.

- ordered:

  `logical(1)`. If `TRUE`, returns an ordered factor.

- drop_levels:

  `logical(1)`. If `TRUE` (the default), removes levels with no observed
  values in `x`.

- force:

  `logical(1)`. If `TRUE`, coerce a numeric `x` without value labels via
  [`as.factor()`](https://rdrr.io/r/base/factor.html), issuing a
  `surveytidy_warning_make_factor_forced` warning. If `FALSE` (the
  default), error instead.

- na.rm:

  `logical(1)`. If `TRUE`, values in `attr(x, "na_values")` and
  `attr(x, "na_range")` are converted to `NA` before building factor
  levels, so they do not produce factor levels. Ignored for factor and
  character input.

- .label:

  `character(1)` or `NULL`. Variable label override. If `NULL`, inherits
  from `attr(x, "label")`; if that is also `NULL`, falls back to the
  column name.

- .description:

  `character(1)` or `NULL`. Transformation description stored in
  `surveytidy_recode`.

## Value

An R factor (ordered if `ordered = TRUE`).

## See also

Other transformation:
[`make_binary()`](https://jdenn0514.github.io/surveytidy/reference/make_binary.md),
[`make_dicho()`](https://jdenn0514.github.io/surveytidy/reference/make_dicho.md),
[`make_flip()`](https://jdenn0514.github.io/surveytidy/reference/make_flip.md),
[`make_rev()`](https://jdenn0514.github.io/surveytidy/reference/make_rev.md)

## Examples

``` r
library(dplyr)
d <- surveycore::as_survey(
  data.frame(x = c(1, 2, 1, 2), wt = c(1, 1, 1, 1)),
  weights = wt
)
#> Warning: ! No `ids` or `strata` specified.
#> ℹ Creating a <survey_srs> design (equal-probability SRS).
#> ✔ Use `as_survey_srs()` to create SRS designs without this warning.
x <- c(1, 2, 1, 2)
attr(x, "labels") <- c("Yes" = 1, "No" = 2)
make_factor(x)
#>   1   2   1   2 
#> Yes  No Yes  No 
#> attr(,"label")
#> [1] x
#> attr(,"surveytidy_recode")
#> attr(,"surveytidy_recode")$fn
#> [1] make_factor
#> 
#> attr(,"surveytidy_recode")$var
#> [1] x
#> 
#> attr(,"surveytidy_recode")$description
#> NULL
#> 
#> Levels: Yes No
```
