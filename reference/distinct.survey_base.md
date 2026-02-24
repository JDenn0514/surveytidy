# Remove duplicate rows from a survey design object

[`distinct()`](https://dplyr.tidyverse.org/reference/distinct.html)
**physically removes duplicate rows** from a survey design object,
always issuing `surveycore_warning_physical_subset`. Unlike
[`dplyr::distinct()`](https://dplyr.tidyverse.org/reference/distinct.html),
all columns in `@data` are retained regardless of which columns are
specified in `...` — design variables must never be lost from the survey
object.

For subpopulation analyses, use
[`filter()`](https://dplyr.tidyverse.org/reference/filter.html) instead
— it marks rows out-of-domain without removing them, preserving valid
variance estimation.

## Usage

``` r
distinct.survey_base(.data, ..., .keep_all = FALSE)
```

## Arguments

- .data:

  A
  [`survey_base`](https://jdenn0514.github.io/surveycore/reference/survey_base.html)
  object.

- ...:

  \<[`data-masking`](https://rlang.r-lib.org/reference/args_data_masking.html)\>
  Optional columns used to determine uniqueness. If empty, all
  non-design columns are used. Note: `.keep_all` is always `TRUE`
  regardless of what is specified here.

- .keep_all:

  Accepted for interface compatibility; **has no effect**. The survey
  implementation always retains all columns in `@data`.

## Value

An object of the same class as `.data` with the following properties:

- Rows physically reduced to distinct subset (fewer rows possible).

- All columns in `@data` are retained (`.keep_all = TRUE` always).

- `@variables$visible_vars` is unchanged — distinct is a pure row
  operation.

- `@metadata` is unchanged.

- `@groups` is unchanged.

- Always issues `surveycore_warning_physical_subset`.

## Details

### Column retention

[`distinct()`](https://dplyr.tidyverse.org/reference/distinct.html)
always behaves as if `.keep_all = TRUE`. Specifying columns in `...`
controls which columns determine uniqueness — it does **not** control
which columns appear in the result. This is a deliberate divergence from
`dplyr::distinct(df, x, y)` which by default drops all columns except
`x` and `y`.

### Default deduplication (empty `...`)

When `...` is empty, deduplication uses all non-design columns. Design
variables (strata, PSU, weights, FPC) are excluded from the uniqueness
check — deduplicating on them would produce meaningless or
survey-corrupting results.

### Design variable warning

If `...` includes a design variable,
`surveytidy_warning_distinct_design_var` is issued before the operation.
The operation still proceeds after the warning — the user is assumed to
know what they are doing.

## See also

[`filter()`](https://dplyr.tidyverse.org/reference/filter.html) for
domain-aware row marking (preferred for subpopulation analyses)

Other row operations:
[`drop_na.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/drop_na.survey_base.md),
[`slice.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/slice.survey_base.md)

## Examples

``` r
library(surveytidy)
library(dplyr)
#> 
#> Attaching package: ‘dplyr’
#> The following objects are masked from ‘package:stats’:
#> 
#>     filter, lag
#> The following objects are masked from ‘package:base’:
#> 
#>     intersect, setdiff, setequal, union
library(surveycore)
d <- as_survey(pew_npors_2025, weights = weight, strata = stratum)

# Deduplicate on all non-design columns (issues physical-subset warning)
distinct(d)
#> Warning: ! `distinct()` physically removes rows from the survey data.
#> ℹ This is different from `filter()`, which preserves all rows for correct
#>   variance estimation.
#> ✔ Use `filter()` for subpopulation analyses instead.
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

# Deduplicate by one column (all other columns still retained)
distinct(d, cregion)
#> Warning: ! `distinct()` physically removes rows from the survey data.
#> ℹ This is different from `filter()`, which preserves all rows for correct
#>   variance estimation.
#> ✔ Use `filter()` for subpopulation analyses instead.
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 4
#> 
#> # A tibble: 4 × 65
#>   respid  mode language languageinitial stratum interview_start interview_end
#>    <dbl> <dbl>    <dbl>           <dbl>   <dbl> <date>          <date>       
#> 1   1470     2        1              NA      10 2025-05-27      2025-05-27   
#> 2  15459     2        1              NA      10 2025-05-05      2025-05-05   
#> 3   9849     1        1               9       9 2025-02-22      2025-02-22   
#> 4   3682     1        1               9       4 2025-02-27      2025-02-27   
#> # ℹ 58 more variables: econ1mod <dbl>, econ1bmod <dbl>, comtype2 <dbl>,
#> #   unity <dbl>, crimesafe <dbl>, govprotct <dbl>, moregunimpact <dbl>,
#> #   fin_sit <dbl>, vet1 <dbl>, vol12_cps <dbl>, eminuse <dbl>, intmob <dbl>,
#> #   intfreq <dbl>, intfreq_collapsed <dbl>, home4nw2 <dbl>, bbhome <dbl>,
#> #   smuse_fb <dbl>, smuse_yt <dbl>, smuse_x <dbl>, smuse_ig <dbl>,
#> #   smuse_sc <dbl>, smuse_wa <dbl>, smuse_tt <dbl>, smuse_rd <dbl>,
#> #   smuse_bsk <dbl>, smuse_th <dbl>, smuse_ts <dbl>, radio <dbl>, …
```
