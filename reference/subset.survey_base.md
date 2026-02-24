# Physically remove rows from a survey design object

[`subset()`](https://rdrr.io/r/base/subset.html) physically removes rows
from a
[`survey_base`](https://jdenn0514.github.io/surveycore/reference/survey_base.html)
object where `condition` evaluates to `FALSE`. **This changes the survey
design.** Unless the design was explicitly built for the subset
population, variance estimates will be incorrect.

For subpopulation analyses, use
[`filter()`](https://dplyr.tidyverse.org/reference/filter.html) instead.
[`filter()`](https://dplyr.tidyverse.org/reference/filter.html) marks
rows as in or out of the domain without removing them, leaving the full
design intact for variance estimation.

[`subset()`](https://rdrr.io/r/base/subset.html) always emits a
`surveycore_warning_physical_subset` warning as a reminder of the
statistical implications.

## Usage

``` r
# S3 method for class 'survey_base'
subset(x, condition, ...)
```

## Arguments

- x:

  A
  [`survey_base`](https://jdenn0514.github.io/surveycore/reference/survey_base.html)
  object.

- condition:

  A logical expression evaluated against the survey data. Rows where
  `condition` is `FALSE` or `NA` are removed.

- ...:

  Ignored. Included for compatibility with the base
  [`subset()`](https://rdrr.io/r/base/subset.html) generic.

## Value

An object of the same type as `x` with only matching rows retained.
Always issues `surveycore_warning_physical_subset`.

## See also

[`filter()`](https://dplyr.tidyverse.org/reference/filter.html) for
domain-aware row marking (preferred for subpopulation analyses)

## Examples

``` r
library(surveytidy)
library(surveycore)
d <- as_survey(pew_npors_2025, weights = weight, strata = stratum)

# Physical row removal — always issues a warning
subset(d, agecat >= 3)
#> Warning: ! `subset()` physically removes rows from the survey data.
#> ℹ This is different from `filter()`, which preserves all rows for correct
#>   variance estimation.
#> ✔ Use `filter()` for subpopulation analyses instead.
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 3143
#> 
#> # A tibble: 3,143 × 65
#>    respid  mode language languageinitial stratum interview_start interview_end
#>     <dbl> <dbl>    <dbl>           <dbl>   <dbl> <date>          <date>       
#>  1   1470     2        1              NA      10 2025-05-27      2025-05-27   
#>  2   2374     2        1              NA       7 2025-05-01      2025-05-01   
#>  3   1177     3        1              10       5 2025-03-04      2025-03-04   
#>  4   9849     1        1               9       9 2025-02-22      2025-02-22   
#>  5   8178     3        1               9      10 2025-03-10      2025-03-10   
#>  6   3682     1        1               9       4 2025-02-27      2025-02-27   
#>  7   6999     2        1              NA      10 2025-05-12      2025-05-12   
#>  8   9945     2        1              NA      10 2025-05-09      2025-05-09   
#>  9  18470     2        1              NA      10 2025-05-08      2025-05-08   
#> 10  18634     2        1              NA      10 2025-05-02      2025-05-02   
#> # ℹ 3,133 more rows
#> # ℹ 58 more variables: econ1mod <dbl>, econ1bmod <dbl>, comtype2 <dbl>,
#> #   unity <dbl>, crimesafe <dbl>, govprotct <dbl>, moregunimpact <dbl>,
#> #   fin_sit <dbl>, vet1 <dbl>, vol12_cps <dbl>, eminuse <dbl>, intmob <dbl>,
#> #   intfreq <dbl>, intfreq_collapsed <dbl>, home4nw2 <dbl>, bbhome <dbl>,
#> #   smuse_fb <dbl>, smuse_yt <dbl>, smuse_x <dbl>, smuse_ig <dbl>,
#> #   smuse_sc <dbl>, smuse_wa <dbl>, smuse_tt <dbl>, smuse_rd <dbl>, …
```
