# Add columns from a data frame to a survey design

`left_join()` adds columns from a plain data frame `y` to a survey
design object `x`, matching on keys defined by `by`. All rows of `x` are
preserved (left join semantics). Rows with no match in `y` receive `NA`
for the new columns.

## Usage

``` r
# S3 method for class 'survey_collection'
left_join(x, y, ..., .if_missing_var = NULL)

left_join(
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

  A plain data frame with lookup columns. Must not be a survey object.
  Must not have column names matching any design variable in `x` (those
  are dropped with a warning).

- ...:

  Additional arguments forwarded to
  [`dplyr::left_join()`](https://dplyr.tidyverse.org/reference/mutate-joins.html).

- .if_missing_var:

  Per-call override of `collection@if_missing_var`. One of `"error"` or
  `"skip"`, or `NULL` (the default) to inherit the collection's stored
  value. See
  [`surveycore::set_collection_if_missing_var()`](https://jdenn0514.github.io/surveycore/reference/set_collection_if_missing_var.html).

- by:

  A character vector of column names or a
  [`dplyr::join_by()`](https://dplyr.tidyverse.org/reference/join_by.html)
  specification. `NULL` uses all common column names.

- copy:

  Forwarded to
  [`dplyr::left_join()`](https://dplyr.tidyverse.org/reference/mutate-joins.html).

- suffix:

  A character vector of length 2 appended to deduplicate column names
  shared between `x` and `y`. Forwarded to
  [`dplyr::left_join()`](https://dplyr.tidyverse.org/reference/mutate-joins.html).

- keep:

  Forwarded to
  [`dplyr::left_join()`](https://dplyr.tidyverse.org/reference/mutate-joins.html).

## Value

A survey design object of the same type as `x` with new columns from `y`
appended to `@data`. `visible_vars` is updated if it was set.

## Details

### Design integrity

`y` must be a plain data frame, not a survey object. If `y` has column
names that match any design variable in `x` (weights, strata, PSU, FPC,
replicate weights, or the domain column), those columns are dropped from
`y` with a warning before joining. Join keys in `by` are excluded from
this check.

### Row count

`left_join()` errors if `y` has duplicate keys that would expand `x`
beyond its original row count. Duplicate respondent rows corrupt
variance estimation. Deduplicate `y` with
[`dplyr::distinct()`](https://dplyr.tidyverse.org/reference/distinct.html)
before joining.

### Metadata

New columns from `y` receive no variable labels in `@metadata`. If a
column in `x@data` is suffix-renamed because `y` has a non-design column
with the same name, the corresponding `@metadata@variable_labels` key is
updated to the new suffixed name.

## Survey collections

When called on a
[`surveycore::survey_collection`](https://jdenn0514.github.io/surveycore/reference/survey_collection.html),
`left_join()` errors unconditionally with class
`surveytidy_error_collection_verb_unsupported`. The semantics for
joining a plain data frame onto a multi-survey container are still being
designed. Apply the join inside a per-survey pipeline before
constructing the collection.

## See also

Other joins:
[`bind_cols()`](https://jdenn0514.github.io/surveytidy/reference/bind_cols.md),
[`bind_rows()`](https://jdenn0514.github.io/surveytidy/reference/bind_rows.md),
[`inner_join`](https://jdenn0514.github.io/surveytidy/reference/inner_join.md),
[`right_join`](https://jdenn0514.github.io/surveytidy/reference/right_join.md),
[`semi_join`](https://jdenn0514.github.io/surveytidy/reference/semi_join.md)

## Examples

``` r
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

# add a lookup column from a plain data frame
lookup <- data.frame(y1 = 1:5, label = letters[1:5])
left_join(d, lookup, by = "y1")
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
