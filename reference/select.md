# Keep or drop columns using their names and types

`select()` keeps the named columns and drops all others, using the
[tidyselect
mini-language](https://tidyselect.r-lib.org/reference/language.html) to
describe column sets. Design variables (weights, strata, PSU, FPC,
replicate weights) are **always retained** even when not explicitly
selected — they are required for variance estimation. After `select()`,
[`print()`](https://rdrr.io/r/base/print.html) shows only the columns
you selected; design variables remain in the object but are hidden from
display.

`select()` is irreversible: dropped columns are permanently removed from
the survey object and cannot be recovered within the same pipeline.

## Usage

``` r
select(.data, ...)

# S3 method for class 'survey_base'
select(.data, ...)

# S3 method for class 'survey_result'
select(.data, ...)

# S3 method for class 'survey_collection'
select(.data, ..., .if_missing_var = NULL)
```

## Arguments

- .data:

  A
  [`survey_base`](https://jdenn0514.github.io/surveycore/reference/survey_base.html)
  object, or a `survey_result` object returned by a surveycore
  estimation function.

- ...:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  One or more unquoted column names or tidy-select expressions.

- .if_missing_var:

  Per-call override of `collection@if_missing_var`. One of `"error"` or
  `"skip"`, or `NULL` (the default) to inherit the collection's stored
  value. See
  [`surveycore::set_collection_if_missing_var()`](https://jdenn0514.github.io/surveycore/reference/set_collection_if_missing_var.html).

## Value

An object of the same type as `.data` with the following properties:

- Rows are not modified.

- Non-selected, non-design columns are permanently removed.

- Design variables are always retained.

- Survey design attributes are preserved.

## Details

### Design variable preservation

Regardless of what you select, the following are always kept in the
survey object: weights, strata, PSUs, FPC columns, replicate weights,
and the domain column (if set by
[`filter()`](https://jdenn0514.github.io/surveytidy/reference/filter.md)).
They are hidden from [`print()`](https://rdrr.io/r/base/print.html)
output but remain available for variance estimation.

### Metadata

Variable labels, value labels, and other metadata for dropped columns
are removed. Metadata for retained columns is preserved.

## Survey collections

When applied to a `survey_collection`, `select()` is dispatched to each
member independently. Each member resolves its own tidyselect expression
against its own `@data`, so members may end up with different visible
columns when the selection is partial (e.g.,
[`any_of()`](https://tidyselect.r-lib.org/reference/all_of.html) against
a heterogeneous collection). Per-member design variables are always
retained.

Before dispatching, `select.survey_collection` resolves the selection
against the first member's `@data` and raises
`surveytidy_error_collection_select_group_removed` if any column in
`coll@groups` would be removed. Group columns must remain in every
member; silently dropping them would violate the surveycore class
validator (G1b). Use
[`ungroup()`](https://dplyr.tidyverse.org/reference/group_by.html) first
if you intend to remove a group column.

`relocate.survey_collection` is **not** subject to this pre-flight —
[`dplyr::relocate`](https://dplyr.tidyverse.org/reference/relocate.html)
only reorders columns and never drops them.

## See also

[`relocate()`](https://jdenn0514.github.io/surveytidy/reference/relocate.md)
to reorder columns,
[`rename()`](https://jdenn0514.github.io/surveytidy/reference/rename.md)
to rename them,
[`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md)
to add new ones

Other selecting:
[`glimpse.survey_collection()`](https://jdenn0514.github.io/surveytidy/reference/glimpse.md),
[`pull.survey_collection()`](https://jdenn0514.github.io/surveytidy/reference/pull.md),
[`relocate`](https://jdenn0514.github.io/surveytidy/reference/relocate.md)

## Examples

``` r
library(surveytidy)
library(surveycore)

# create a survey design from the pew_npors_2025 example dataset
d <- as_survey(pew_npors_2025, weights = weight, strata = stratum)

# select by name
select(d, gender, agecat)
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 5022
#> 
#> # A tibble: 5,022 × 2
#>    gender agecat
#>     <dbl>  <dbl>
#>  1      2      4
#>  2      1      4
#>  3      2      4
#>  4      1      2
#>  5      1      4
#>  6      1      4
#>  7      1      3
#>  8      2      4
#>  9      2      3
#> 10      2      2
#> # ℹ 5,012 more rows
#> 
#> ℹ Design variables preserved but hidden: weight and stratum.
#> ℹ Use `print(x, full = TRUE)` to show all variables.

# select by name pattern
select(d, tidyselect::starts_with("smuse_"))
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 5022
#> 
#> # A tibble: 5,022 × 11
#>    smuse_fb smuse_yt smuse_x smuse_ig smuse_sc smuse_wa smuse_tt smuse_rd
#>       <dbl>    <dbl>   <dbl>    <dbl>    <dbl>    <dbl>    <dbl>    <dbl>
#>  1        2        1       2        2        2        2        2        1
#>  2        1        1       2        1        2        2        1        2
#>  3        1        1       1        1        2        1        2        2
#>  4        2        1       2        2        2        2        2        2
#>  5        1        1       1        1        1        2        2        2
#>  6       NA       NA      NA       NA       NA       NA       NA       NA
#>  7        1        1       2        1        2        1        2        2
#>  8        1        2       1        2        2        2        2        2
#>  9        1        1       2        2        1        2        2        2
#> 10        1        1       2        1        1        1        2        2
#> # ℹ 5,012 more rows
#> # ℹ 3 more variables: smuse_bsk <dbl>, smuse_th <dbl>, smuse_ts <dbl>
#> 
#> ℹ Design variables preserved but hidden: weight and stratum.
#> ℹ Use `print(x, full = TRUE)` to show all variables.

# select by type
select(d, tidyselect::where(is.numeric))
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 5022
#> 
#> # A tibble: 5,022 × 63
#>    respid  mode language languageinitial stratum econ1mod econ1bmod comtype2
#>     <dbl> <dbl>    <dbl>           <dbl>   <dbl>    <dbl>     <dbl>    <dbl>
#>  1   1470     2        1              NA      10        4         2        3
#>  2   2374     2        1              NA       7        3         2        1
#>  3   1177     3        1              10       5        2         1        3
#>  4  15459     2        1              NA      10        3         3        3
#>  5   9849     1        1               9       9        2         1        2
#>  6   8178     3        1               9      10        2         2        1
#>  7   3682     1        1               9       4        3         2        1
#>  8   6999     2        1              NA      10        3         3        3
#>  9   9945     2        1              NA      10        3         2        3
#> 10   1901     1        1               9      10        1         1        2
#> # ℹ 5,012 more rows
#> # ℹ 55 more variables: unity <dbl>, crimesafe <dbl>, govprotct <dbl>,
#> #   moregunimpact <dbl>, fin_sit <dbl>, vet1 <dbl>, vol12_cps <dbl>,
#> #   eminuse <dbl>, intmob <dbl>, intfreq <dbl>, intfreq_collapsed <dbl>,
#> #   home4nw2 <dbl>, bbhome <dbl>, smuse_fb <dbl>, smuse_yt <dbl>,
#> #   smuse_x <dbl>, smuse_ig <dbl>, smuse_sc <dbl>, smuse_wa <dbl>,
#> #   smuse_tt <dbl>, smuse_rd <dbl>, smuse_bsk <dbl>, smuse_th <dbl>, …

# drop columns with !
select(d, !tidyselect::starts_with("smuse_"))
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 5022
#> 
#> # A tibble: 5,022 × 54
#>    respid  mode language languageinitial stratum interview_start interview_end
#>     <dbl> <dbl>    <dbl>           <dbl>   <dbl> <date>          <date>       
#>  1   1470     2        1              NA      10 2025-05-27      2025-05-27   
#>  2   2374     2        1              NA       7 2025-05-01      2025-05-01   
#>  3   1177     3        1              10       5 2025-03-04      2025-03-04   
#>  4  15459     2        1              NA      10 2025-05-05      2025-05-05   
#>  5   9849     1        1               9       9 2025-02-22      2025-02-22   
#>  6   8178     3        1               9      10 2025-03-10      2025-03-10   
#>  7   3682     1        1               9       4 2025-02-27      2025-02-27   
#>  8   6999     2        1              NA      10 2025-05-12      2025-05-12   
#>  9   9945     2        1              NA      10 2025-05-09      2025-05-09   
#> 10   1901     1        1               9      10 2025-03-01      2025-03-01   
#> # ℹ 5,012 more rows
#> # ℹ 47 more variables: econ1mod <dbl>, econ1bmod <dbl>, comtype2 <dbl>,
#> #   unity <dbl>, crimesafe <dbl>, govprotct <dbl>, moregunimpact <dbl>,
#> #   fin_sit <dbl>, vet1 <dbl>, vol12_cps <dbl>, eminuse <dbl>, intmob <dbl>,
#> #   intfreq <dbl>, intfreq_collapsed <dbl>, home4nw2 <dbl>, bbhome <dbl>,
#> #   radio <dbl>, device1a <dbl>, smart2 <dbl>, nhisll <dbl>, relig <dbl>,
#> #   religcat1 <dbl>, born <dbl>, attendper <dbl>, attendonline2 <dbl>, …
```
