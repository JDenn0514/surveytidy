# Domain-aware inner join for survey designs

`inner_join()` has two modes controlled by `.domain_aware` (default
`TRUE`):

**Domain-aware mode (`.domain_aware = TRUE`, default):** Unmatched rows
are marked `FALSE` in the domain column (exactly like
[`filter()`](https://jdenn0514.github.io/surveytidy/reference/filter.md)
or
[`semi_join()`](https://jdenn0514.github.io/surveytidy/reference/semi_join.md)),
and `y`'s columns are added to all rows (with `NA` for unmatched rows).
All rows remain in `@data`. Row count is unchanged. This is the
survey-correct default.

**Physical mode (`.domain_aware = FALSE`):** Unmatched rows are
physically removed, exactly like base R `inner_join`. Emits
`surveycore_warning_physical_subset`. Errors for `survey_twophase`
designs.

## Usage

``` r
# S3 method for class 'survey_collection'
inner_join(x, y, ..., .if_missing_var = NULL)

inner_join(
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

- suffix:

  A character vector of length 2. Forwarded to the underlying dplyr
  function for handling shared column names.

- keep:

  Forwarded to the underlying dplyr function.

## Value

A survey design object of the same type as `x`.

- Domain-aware mode (`.domain_aware = TRUE`): row count unchanged;
  `..surveycore_domain..` updated; new columns from `y` appended.

- Physical mode (`.domain_aware = FALSE`): row count reduced to matched
  rows; new columns from `y` appended.

## Details

### Choosing a mode

The domain-aware default preserves variance estimation validity. The
[`nrow()`](https://rdrr.io/r/base/nrow.html) behaviour (count stays the
same) is consistent with
[`filter()`](https://jdenn0514.github.io/surveytidy/reference/filter.md)
and
[`semi_join()`](https://jdenn0514.github.io/surveytidy/reference/semi_join.md)
precedents in surveytidy.

Physical mode (`.domain_aware = FALSE`) is appropriate only when you
explicitly want to reduce the design to a specific subpopulation. For
replicate designs (BRR, jackknife), physical row removal can corrupt
half-sample or pairing structure, producing numerically wrong variance
estimates. Domain-aware mode is recommended for replicate designs.

### Duplicate keys

Duplicate keys in `y` that would expand the row count are an error in
both modes. Deduplicate `y` with
[`dplyr::distinct()`](https://dplyr.tidyverse.org/reference/distinct.html)
before joining.

### The `.domain_aware` argument (survey-specific extension)

The surveytidy method adds one argument not present in the dplyr
generic: `.domain_aware = TRUE` (default) performs domain-aware joining;
set `.domain_aware = FALSE` for physical row removal (emits
`surveycore_warning_physical_subset`; errors for `survey_twophase`).

## Survey collections

When called on a
[`surveycore::survey_collection`](https://jdenn0514.github.io/surveycore/reference/survey_collection.html),
`inner_join()` errors unconditionally with class
`surveytidy_error_collection_verb_unsupported`. The semantics for
joining a plain data frame onto a multi-survey container are still being
designed. Apply the join inside a per-survey pipeline before
constructing the collection.

## See also

Other joins:
[`bind_cols()`](https://jdenn0514.github.io/surveytidy/reference/bind_cols.md),
[`bind_rows()`](https://jdenn0514.github.io/surveytidy/reference/bind_rows.md),
[`left_join`](https://jdenn0514.github.io/surveytidy/reference/left_join.md),
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
lookup <- data.frame(y1 = 1:3, label = letters[1:3])

# domain-aware: marks rows 4 and 5 as out-of-domain
inner_join(d, lookup, by = "y1")
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 5
#> Domain: 3 of 5 rows
#> 
#> # A tibble: 5 × 7
#>   psu   strata   fpc    wt    y1 ..surveycore_domain.. label
#>   <chr> <chr>  <dbl> <dbl> <int> <lgl>                 <chr>
#> 1 psu_1 s1       100     1     1 TRUE                  a    
#> 2 psu_2 s1       100     1     2 TRUE                  b    
#> 3 psu_3 s1       100     1     3 TRUE                  c    
#> 4 psu_4 s1       100     1     4 FALSE                 NA   
#> 5 psu_5 s1       100     1     5 FALSE                 NA   

# physical: removes rows 4 and 5
inner_join(d, lookup, by = "y1", .domain_aware = FALSE)
#> Warning: ! `inner_join()` physically removed 2 rows from the survey design.
#> ℹ Physical row removal can bias variance estimation.
#> ℹ Use `.domain_aware = TRUE` (the default) to mark rows as out-of-domain
#>   without removing them.
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 3
#> 
#> # A tibble: 3 × 6
#>   psu   strata   fpc    wt    y1 label
#>   <chr> <chr>  <dbl> <dbl> <int> <chr>
#> 1 psu_1 s1       100     1     1 a    
#> 2 psu_2 s1       100     1     2 b    
#> 3 psu_3 s1       100     1     3 c    
```
