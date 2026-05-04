# Unsupported joins for survey designs

`right_join()` and `full_join()` error unconditionally for survey design
objects because they can add rows from `y` that have no match in the
survey. Those new rows would have `NA` for all design variables
(weights, strata, PSU), producing an invalid design object.

## Usage

``` r
# S3 method for class 'survey_collection'
right_join(x, y, ..., .if_missing_var = NULL)

# S3 method for class 'survey_collection'
full_join(x, y, ..., .if_missing_var = NULL)

right_join(
  x,
  y,
  by = NULL,
  copy = FALSE,
  suffix = c(".x", ".y"),
  ...,
  keep = NULL
)

full_join(
  x,
  y,
  by = NULL,
  copy = FALSE,
  suffix = c(".x", ".y"),
  ...,
  keep = NULL
)
```

## Arguments

- x:

  A
  [`survey_base`](https://jdenn0514.github.io/surveycore/reference/survey_base.html)
  object.

- y:

  A data frame or survey object.

- ...:

  Additional arguments (ignored; the function always errors).

- .if_missing_var:

  Per-call override of `collection@if_missing_var`. One of `"error"` or
  `"skip"`, or `NULL` (the default) to inherit the collection's stored
  value. See
  [`surveycore::set_collection_if_missing_var()`](https://jdenn0514.github.io/surveycore/reference/set_collection_if_missing_var.html).

- by:

  Ignored — the function always errors.

- copy:

  Ignored — the function always errors.

- suffix:

  Ignored — the function always errors.

- keep:

  Ignored — the function always errors.

## Value

Never returns — always throws an error.

## Details

Use
[`left_join()`](https://jdenn0514.github.io/surveytidy/reference/left_join.md)
to add lookup columns from `y`. Use
[`filter()`](https://jdenn0514.github.io/surveytidy/reference/filter.md)
or
[`semi_join()`](https://jdenn0514.github.io/surveytidy/reference/semi_join.md)
to restrict the survey domain.

## Survey collections

When called on a
[`surveycore::survey_collection`](https://jdenn0514.github.io/surveycore/reference/survey_collection.html),
`right_join()` errors unconditionally with class
`surveytidy_error_collection_verb_unsupported`. The semantics for
joining a plain data frame onto a multi-survey container are still being
designed. Apply the join inside a per-survey pipeline before
constructing the collection.

When called on a
[`surveycore::survey_collection`](https://jdenn0514.github.io/surveycore/reference/survey_collection.html),
`full_join()` errors unconditionally with class
`surveytidy_error_collection_verb_unsupported`. The semantics for
joining a plain data frame onto a multi-survey container are still being
designed. Apply the join inside a per-survey pipeline before
constructing the collection.

## See also

Other joins:
[`bind_cols()`](https://jdenn0514.github.io/surveytidy/reference/bind_cols.md),
[`bind_rows()`](https://jdenn0514.github.io/surveytidy/reference/bind_rows.md),
[`inner_join`](https://jdenn0514.github.io/surveytidy/reference/inner_join.md),
[`left_join`](https://jdenn0514.github.io/surveytidy/reference/left_join.md),
[`semi_join`](https://jdenn0514.github.io/surveytidy/reference/semi_join.md)

## Examples

``` r
# create a tiny survey object and a lookup table with an extra row
d <- surveycore::as_survey(
  data.frame(wt = c(1, 1), y1 = c(1, 2)),
  weights = wt
)
lookup <- data.frame(y1 = c(1, 2, 3), label = c("a", "b", "c"))

# right_join() and full_join() always error on a survey object — they would
# add rows with NA design variables, producing an invalid design
tryCatch(
  right_join(d, lookup, by = "y1"),
  error = function(e) message(conditionMessage(e))
)
#> ✖ `right_join()` would add rows from `y` that have no match in the
#>   survey.
#> ℹ New rows would have `NA` for all design variables (weights, strata, PSU),
#>   producing an invalid design object.
#> ✔ Use `left_join()` to add lookup columns from `y`, or `filter()` /
#>   `semi_join()` to restrict the survey domain.

tryCatch(
  full_join(d, lookup, by = "y1"),
  error = function(e) message(conditionMessage(e))
)
#> ✖ `full_join()` would add rows from `y` that have no match in the
#>   survey.
#> ℹ New rows would have `NA` for all design variables (weights, strata, PSU),
#>   producing an invalid design object.
#> ✔ Use `left_join()` to add lookup columns from `y`, or `filter()` /
#>   `semi_join()` to restrict the survey domain.

# the recommended alternative: use left_join() to add lookup columns
# without changing the row set
left_join(d, lookup, by = "y1")
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 2
#> 
#> # A tibble: 2 × 3
#>      wt    y1 label
#>   <dbl> <dbl> <chr>
#> 1     1     1 a    
#> 2     1     2 b    
```
