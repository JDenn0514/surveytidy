# Domain-aware semi- and anti-join for survey designs

`semi_join()` marks rows as in-domain when they have a match in `y`.
`anti_join()` marks rows as in-domain when they do NOT have a match in
`y`. Neither function removes rows or adds new columns — they are
implemented as domain operations, exactly like
[`filter()`](https://jdenn0514.github.io/surveytidy/reference/filter.md).

## Usage

``` r
# S3 method for class 'survey_collection'
semi_join(x, y, ..., .if_missing_var = NULL)

# S3 method for class 'survey_collection'
anti_join(x, y, ..., .if_missing_var = NULL)

semi_join(x, y, by = NULL, copy = FALSE, ...)

anti_join(x, y, by = NULL, copy = FALSE, ...)
```

## Arguments

- x:

  A
  [`survey_base`](https://jdenn0514.github.io/surveycore/reference/survey_base.html)
  object.

- y:

  A plain data frame. Must not be a survey object.

- ...:

  Additional arguments forwarded to the underlying dplyr function.

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

  Forwarded to the underlying dplyr function.

## Value

A survey design object of the same type as `x` with the domain column
(`..surveycore_domain..`) updated. Row count unchanged. No new columns
added.

## Details

### Domain awareness

Unlike standard
[`dplyr::semi_join()`](https://dplyr.tidyverse.org/reference/filter-joins.html)
and
[`dplyr::anti_join()`](https://dplyr.tidyverse.org/reference/filter-joins.html),
these implementations never physically remove rows. Instead, unmatched
(or matched, for `anti_join`) rows are marked `FALSE` in the
`..surveycore_domain..` column of `@data`, exactly as
[`filter()`](https://jdenn0514.github.io/surveytidy/reference/filter.md)
does. This preserves variance estimation validity.

### Chaining

Multiple calls accumulate via AND: a row must satisfy every condition
from every
[`filter()`](https://jdenn0514.github.io/surveytidy/reference/filter.md),
`semi_join()`, and `anti_join()` call to remain in-domain.

### Duplicate keys in y

Duplicate keys in `y` collapse to a single `TRUE` (for `semi_join`) or a
single `FALSE` (for `anti_join`) per survey row. Row expansion is not
possible with these functions.

### @variables\$domain sentinel

A typed S3 sentinel of class `"surveytidy_join_domain"` is appended to
`@variables$domain`. Phase 1 consumers can use
`inherits(entry, "surveytidy_join_domain")` to distinguish join
sentinels from quosures.

## Survey collections

When called on a
[`surveycore::survey_collection`](https://jdenn0514.github.io/surveycore/reference/survey_collection.html),
`semi_join()` errors unconditionally with class
`surveytidy_error_collection_verb_unsupported`. The semantics for
joining a plain data frame onto a multi-survey container are still being
designed. Apply the join inside a per-survey pipeline before
constructing the collection.

When called on a
[`surveycore::survey_collection`](https://jdenn0514.github.io/surveycore/reference/survey_collection.html),
`anti_join()` errors unconditionally with class
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
[`right_join`](https://jdenn0514.github.io/surveytidy/reference/right_join.md)

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
keepers <- data.frame(y1 = c(1, 3, 5))

# semi_join: rows matching keepers stay in-domain
semi_join(d, keepers, by = "y1")
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 5
#> Domain: 3 of 5 rows
#> 
#> # A tibble: 5 × 6
#>   psu   strata   fpc    wt    y1 ..surveycore_domain..
#>   <chr> <chr>  <dbl> <dbl> <int> <lgl>                
#> 1 psu_1 s1       100     1     1 TRUE                 
#> 2 psu_2 s1       100     1     2 FALSE                
#> 3 psu_3 s1       100     1     3 TRUE                 
#> 4 psu_4 s1       100     1     4 FALSE                
#> 5 psu_5 s1       100     1     5 TRUE                 

# anti_join: rows matching keepers are marked out-of-domain
anti_join(d, keepers, by = "y1")
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 5
#> Domain: 2 of 5 rows
#> 
#> # A tibble: 5 × 6
#>   psu   strata   fpc    wt    y1 ..surveycore_domain..
#>   <chr> <chr>  <dbl> <dbl> <int> <lgl>                
#> 1 psu_1 s1       100     1     1 FALSE                
#> 2 psu_2 s1       100     1     2 TRUE                 
#> 3 psu_3 s1       100     1     3 FALSE                
#> 4 psu_4 s1       100     1     4 TRUE                 
#> 5 psu_5 s1       100     1     5 FALSE                
```
