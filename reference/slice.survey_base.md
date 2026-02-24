# Physically select rows of a survey design object

[`slice()`](https://dplyr.tidyverse.org/reference/slice.html),
[`slice_head()`](https://dplyr.tidyverse.org/reference/slice.html),
[`slice_tail()`](https://dplyr.tidyverse.org/reference/slice.html),
[`slice_min()`](https://dplyr.tidyverse.org/reference/slice.html),
[`slice_max()`](https://dplyr.tidyverse.org/reference/slice.html), and
[`slice_sample()`](https://dplyr.tidyverse.org/reference/slice.html)
**physically remove rows** from a survey design object. For
subpopulation analyses, use
[`filter()`](https://dplyr.tidyverse.org/reference/filter.html) instead
— it marks rows as out-of-domain without removing them, preserving valid
variance estimation.

All slice functions always issue `surveycore_warning_physical_subset`
and error if the result would have 0 rows.

## Usage

``` r
slice.survey_base(.data, ...)

slice_head.survey_base(.data, ...)

slice_tail.survey_base(.data, ...)

slice_min.survey_base(.data, ...)

slice_max.survey_base(.data, ...)

slice_sample.survey_base(.data, ...)
```

## Arguments

- .data:

  A
  [`survey_base`](https://jdenn0514.github.io/surveycore/reference/survey_base.html)
  object.

- ...:

  Passed to the corresponding `dplyr::slice_*()` function.

## Value

An object of the same type as `.data` with the following properties:

- A subset of rows is retained; unselected rows are permanently removed.

- Columns and survey design attributes are unchanged.

- Always issues `surveycore_warning_physical_subset`.

## Details

### Physical subsetting

Unlike [`filter()`](https://dplyr.tidyverse.org/reference/filter.html),
slice functions actually remove rows. This changes the survey design —
unless the design was explicitly built for the subset population,
variance estimates may be incorrect.

### [`slice_sample()`](https://dplyr.tidyverse.org/reference/slice.html) and survey weights

`slice_sample(weight_by = )` samples rows proportional to a column's
values, independently of the survey design weights. A
`surveytidy_warning_slice_sample_weight_by` warning is issued as a
reminder. If you intend probability-proportional sampling, use the
design weights directly.

## Functions

- `slice_head.survey_base()`: Select first `n` rows.

- `slice_tail.survey_base()`: Select last `n` rows.

- `slice_min.survey_base()`: Select rows with the smallest values.

- `slice_max.survey_base()`: Select rows with the largest values.

- `slice_sample.survey_base()`: Randomly sample rows.

## See also

[`filter()`](https://dplyr.tidyverse.org/reference/filter.html) for
domain-aware row marking (preferred for subpopulation analyses),
[`arrange()`](https://dplyr.tidyverse.org/reference/arrange.html) for
row sorting

Other row operations:
[`distinct.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/distinct.survey_base.md),
[`drop_na.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/drop_na.survey_base.md)

## Examples

``` r
library(surveytidy)
library(surveycore)
d <- as_survey(pew_npors_2025, weights = weight, strata = stratum)

# First 10 rows (issues a physical subset warning)
slice_head(d, n = 10)
#> Warning: ! `slice_head()` physically removes rows from the survey data.
#> ℹ This is different from `filter()`, which preserves all rows for correct
#>   variance estimation.
#> ✔ Use `filter()` for subpopulation analyses instead.
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 10
#> 
#> # A tibble: 10 × 65
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
#> # ℹ 58 more variables: econ1mod <dbl>, econ1bmod <dbl>, comtype2 <dbl>,
#> #   unity <dbl>, crimesafe <dbl>, govprotct <dbl>, moregunimpact <dbl>,
#> #   fin_sit <dbl>, vet1 <dbl>, vol12_cps <dbl>, eminuse <dbl>, intmob <dbl>,
#> #   intfreq <dbl>, intfreq_collapsed <dbl>, home4nw2 <dbl>, bbhome <dbl>,
#> #   smuse_fb <dbl>, smuse_yt <dbl>, smuse_x <dbl>, smuse_ig <dbl>,
#> #   smuse_sc <dbl>, smuse_wa <dbl>, smuse_tt <dbl>, smuse_rd <dbl>,
#> #   smuse_bsk <dbl>, smuse_th <dbl>, smuse_ts <dbl>, radio <dbl>, …

# Rows with the 5 lowest survey weights
slice_min(d, order_by = weight, n = 5)
#> Warning: ! `slice_min()` physically removes rows from the survey data.
#> ℹ This is different from `filter()`, which preserves all rows for correct
#>   variance estimation.
#> ✔ Use `filter()` for subpopulation analyses instead.
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 51
#> 
#> # A tibble: 51 × 65
#>    respid  mode language languageinitial stratum interview_start interview_end
#>     <dbl> <dbl>    <dbl>           <dbl>   <dbl> <date>          <date>       
#>  1   3716     1        1               9       1 2025-02-25      2025-02-25   
#>  2     80     1        1               9       1 2025-03-12      2025-03-12   
#>  3  13195     1        1               9       7 2025-02-24      2025-02-24   
#>  4  12549     1        1               9       9 2025-03-30      2025-03-30   
#>  5  18538     1        1               9       8 2025-03-06      2025-03-06   
#>  6  12391     2        1              NA       7 2025-05-05      2025-05-05   
#>  7   2656     1        1               9       1 2025-03-08      2025-03-08   
#>  8   5702     1        1               9       1 2025-03-10      2025-03-10   
#>  9   7131     1        1               9       2 2025-03-04      2025-03-04   
#> 10   6278     1        1               9       7 2025-03-01      2025-03-01   
#> # ℹ 41 more rows
#> # ℹ 58 more variables: econ1mod <dbl>, econ1bmod <dbl>, comtype2 <dbl>,
#> #   unity <dbl>, crimesafe <dbl>, govprotct <dbl>, moregunimpact <dbl>,
#> #   fin_sit <dbl>, vet1 <dbl>, vol12_cps <dbl>, eminuse <dbl>, intmob <dbl>,
#> #   intfreq <dbl>, intfreq_collapsed <dbl>, home4nw2 <dbl>, bbhome <dbl>,
#> #   smuse_fb <dbl>, smuse_yt <dbl>, smuse_x <dbl>, smuse_ig <dbl>,
#> #   smuse_sc <dbl>, smuse_wa <dbl>, smuse_tt <dbl>, smuse_rd <dbl>, …

# Random sample of 50 rows
slice_sample(d, n = 50)
#> Warning: ! `slice_sample()` physically removes rows from the survey data.
#> ℹ This is different from `filter()`, which preserves all rows for correct
#>   variance estimation.
#> ✔ Use `filter()` for subpopulation analyses instead.
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 50
#> 
#> # A tibble: 50 × 65
#>    respid  mode language languageinitial stratum interview_start interview_end
#>     <dbl> <dbl>    <dbl>           <dbl>   <dbl> <date>          <date>       
#>  1   4447     2        1              NA      10 2025-05-05      2025-05-05   
#>  2  10054     1        1               9      10 2025-02-23      2025-02-23   
#>  3   4907     1        1               9      10 2025-02-08      2025-02-08   
#>  4  10520     1        1               9      10 2025-02-24      2025-02-24   
#>  5   2483     1        1               9      10 2025-02-25      2025-02-25   
#>  6  13027     2        1              NA      10 2025-05-27      2025-05-27   
#>  7   2065     3        1               9      10 2025-02-26      2025-02-26   
#>  8  14010     2        1              NA      10 2025-05-12      2025-05-12   
#>  9   1782     2        1              NA       7 2025-05-12      2025-05-12   
#> 10  10245     2        1              NA      10 2025-05-23      2025-05-23   
#> # ℹ 40 more rows
#> # ℹ 58 more variables: econ1mod <dbl>, econ1bmod <dbl>, comtype2 <dbl>,
#> #   unity <dbl>, crimesafe <dbl>, govprotct <dbl>, moregunimpact <dbl>,
#> #   fin_sit <dbl>, vet1 <dbl>, vol12_cps <dbl>, eminuse <dbl>, intmob <dbl>,
#> #   intfreq <dbl>, intfreq_collapsed <dbl>, home4nw2 <dbl>, bbhome <dbl>,
#> #   smuse_fb <dbl>, smuse_yt <dbl>, smuse_x <dbl>, smuse_ig <dbl>,
#> #   smuse_sc <dbl>, smuse_wa <dbl>, smuse_tt <dbl>, smuse_rd <dbl>, …
```
