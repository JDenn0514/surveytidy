# Compute row-wise on a survey design object

`rowwise()` enables row-by-row computation in
[`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md).
Each row is treated as an independent group, so expressions like
`mutate(d, row_max = max(dplyr::c_across(tidyselect::starts_with("y"))))`
compute the maximum across columns for each row independently.

Use [`ungroup()`](https://dplyr.tidyverse.org/reference/group_by.html)
or
[`group_by()`](https://jdenn0514.github.io/surveytidy/reference/group_by.md)
to exit rowwise mode.

## Usage

``` r
rowwise(data, ...)

# S3 method for class 'survey_base'
rowwise(data, ...)

# S3 method for class 'survey_collection'
rowwise(data, ..., .if_missing_var = NULL)
```

## Arguments

- data:

  A
  [`survey_base`](https://jdenn0514.github.io/surveycore/reference/survey_base.html)
  object.

- ...:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Optional id columns that identify each row (used with
  [`dplyr::c_across()`](https://dplyr.tidyverse.org/reference/c_across.html)).
  Commonly omitted.

- .if_missing_var:

  Per-call override of `collection@if_missing_var`. One of `"error"` or
  `"skip"`, or `NULL` (the default) to inherit the collection's stored
  value. See
  [`surveycore::set_collection_if_missing_var()`](https://jdenn0514.github.io/surveycore/reference/set_collection_if_missing_var.html).

## Value

`data` with `@variables$rowwise = TRUE` and `@variables$rowwise_id_cols`
set. All other properties are unchanged.

## Details

### Storage

Rowwise mode is stored in `@variables$rowwise` (logical `TRUE`) and
`@variables$rowwise_id_cols` (character vector of id column names).
`@groups` is **not** modified — rowwise mode is independent of grouping.

### Exiting rowwise mode

- `ungroup(d)` — exits rowwise mode and removes all groups.

- `group_by(d, ...)` — exits rowwise mode and sets new groups.

- `group_by(d, ..., .add = TRUE)` — promotes id columns to groups, then
  appends the new groups, then exits rowwise mode.

### mutate() behaviour

[`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md)
detects rowwise mode and routes internally through
`dplyr::rowwise(@data)` before calling
[`dplyr::mutate()`](https://dplyr.tidyverse.org/reference/mutate.html).
The `rowwise_df` class is stripped from `@data` after mutation so
subsequent operations are not accidentally rowwise.

## Survey collections

When applied to a `survey_collection`, `rowwise()` is dispatched to each
member independently — every member receives `@variables$rowwise = TRUE`
and the same `@variables$rowwise_id_cols`. The collection has no rowwise
marker; rowwise state lives entirely per-member. `@groups`, `@id`, and
`@if_missing_var` on the collection are unchanged.

Construction-time uniformity is by-construction: every member is rowwise
after the call. Mixed rowwise state across members is detected later by
[`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md)
(see §IV.5 of the survey-collection spec) and warned about rather than
blocked.

## See also

Other grouping:
[`group_by`](https://jdenn0514.github.io/surveytidy/reference/group_by.md),
[`is_grouped()`](https://jdenn0514.github.io/surveytidy/reference/is_grouped.md),
[`is_rowwise()`](https://jdenn0514.github.io/surveytidy/reference/is_rowwise.md)

## Examples

``` r
# create a survey object from the bundled NPORS dataset
d <- surveycore::as_survey(
  surveycore::pew_npors_2025,
  weights = weight,
  strata = stratum
)

# row-wise max across several columns
d |>
  rowwise() |>
  mutate(
    row_max = max(dplyr::c_across(tidyselect::starts_with("econ")), na.rm = TRUE)
  )
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 5022
#> 
#> # A tibble: 5,022 × 66
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
#> # ℹ 59 more variables: econ1mod <dbl>, econ1bmod <dbl>, comtype2 <dbl>,
#> #   unity <dbl>, crimesafe <dbl>, govprotct <dbl>, moregunimpact <dbl>,
#> #   fin_sit <dbl>, vet1 <dbl>, vol12_cps <dbl>, eminuse <dbl>, intmob <dbl>,
#> #   intfreq <dbl>, intfreq_collapsed <dbl>, home4nw2 <dbl>, bbhome <dbl>,
#> #   smuse_fb <dbl>, smuse_yt <dbl>, smuse_x <dbl>, smuse_ig <dbl>,
#> #   smuse_sc <dbl>, smuse_wa <dbl>, smuse_tt <dbl>, smuse_rd <dbl>, …

# exit rowwise mode
d |>
  rowwise() |>
  ungroup()
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 5022
#> 
#> # A tibble: 5,022 × 65
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
#> # ℹ 58 more variables: econ1mod <dbl>, econ1bmod <dbl>, comtype2 <dbl>,
#> #   unity <dbl>, crimesafe <dbl>, govprotct <dbl>, moregunimpact <dbl>,
#> #   fin_sit <dbl>, vet1 <dbl>, vol12_cps <dbl>, eminuse <dbl>, intmob <dbl>,
#> #   intfreq <dbl>, intfreq_collapsed <dbl>, home4nw2 <dbl>, bbhome <dbl>,
#> #   smuse_fb <dbl>, smuse_yt <dbl>, smuse_x <dbl>, smuse_ig <dbl>,
#> #   smuse_sc <dbl>, smuse_wa <dbl>, smuse_tt <dbl>, smuse_rd <dbl>, …
```
