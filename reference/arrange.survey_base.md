# Order rows using column values

[`arrange()`](https://dplyr.tidyverse.org/reference/arrange.html) orders
the rows of a
[`survey_base`](https://jdenn0514.github.io/surveycore/reference/survey_base.html)
object by the values of selected columns.

Unlike most other verbs,
[`arrange()`](https://dplyr.tidyverse.org/reference/arrange.html)
largely ignores grouping — use `.by_group = TRUE` to sort by grouping
variables first.

## Usage

``` r
arrange.survey_base(.data, ..., .by_group = FALSE, .locale = NULL)
```

## Arguments

- .data:

  A
  [`survey_base`](https://jdenn0514.github.io/surveycore/reference/survey_base.html)
  object.

- ...:

  \<[`data-masking`](https://rlang.r-lib.org/reference/args_data_masking.html)\>
  Variables, or functions of variables. Use
  [`dplyr::desc()`](https://dplyr.tidyverse.org/reference/desc.html) to
  sort a variable in descending order.

- .by_group:

  If `TRUE`, sorts first by the grouping variables set by
  [`group_by()`](https://dplyr.tidyverse.org/reference/group_by.html).

- .locale:

  The locale to use for ordering strings. If `NULL`, uses the `"C"`
  locale. See
  [`stringi::locale()`](https://rdrr.io/pkg/stringi/man/about_locale.html)
  for available locales.

## Value

An object of the same type as `.data` with the following properties:

- All rows appear in the output, usually in a different position.

- Columns are not modified.

- Groups are not modified.

- Survey design attributes are preserved.

## Details

### Missing values

Unlike base [`sort()`](https://rdrr.io/r/base/sort.html), `NA` values
are always sorted to the end, even when using
[`dplyr::desc()`](https://dplyr.tidyverse.org/reference/desc.html).

### Domain column

The domain column moves with the rows — row reordering does not affect
which rows are in or out of the survey domain.

## See also

[`filter()`](https://dplyr.tidyverse.org/reference/filter.html) for
domain-aware row marking,
[`slice()`](https://dplyr.tidyverse.org/reference/slice.html) for
physical row selection

## Examples

``` r
library(surveytidy)
library(surveycore)
d <- as_survey(pew_npors_2025, weights = weight, strata = stratum)

# Sort by age category ascending
arrange(d, agecat)
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 5022
#> 
#> # A tibble: 5,022 × 65
#>    respid  mode language languageinitial stratum interview_start interview_end
#>     <dbl> <dbl>    <dbl>           <dbl>   <dbl> <date>          <date>       
#>  1  13673     1        1               9      10 2025-03-02      2025-03-02   
#>  2   9247     1        1               9       7 2025-03-03      2025-03-03   
#>  3  14402     1        1               9      10 2025-03-09      2025-03-09   
#>  4   2820     1        1               9       9 2025-02-24      2025-02-24   
#>  5  12802     1        1               9       6 2025-02-24      2025-02-24   
#>  6   7003     1        1               9       7 2025-02-25      2025-02-25   
#>  7   8391     1        2              10       7 2025-03-14      2025-03-14   
#>  8   2499     1        1               9      10 2025-02-25      2025-02-25   
#>  9     80     1        1               9       1 2025-03-12      2025-03-12   
#> 10   5357     1        1               9      10 2025-03-15      2025-03-15   
#> # ℹ 5,012 more rows
#> # ℹ 58 more variables: econ1mod <dbl>, econ1bmod <dbl>, comtype2 <dbl>,
#> #   unity <dbl>, crimesafe <dbl>, govprotct <dbl>, moregunimpact <dbl>,
#> #   fin_sit <dbl>, vet1 <dbl>, vol12_cps <dbl>, eminuse <dbl>, intmob <dbl>,
#> #   intfreq <dbl>, intfreq_collapsed <dbl>, home4nw2 <dbl>, bbhome <dbl>,
#> #   smuse_fb <dbl>, smuse_yt <dbl>, smuse_x <dbl>, smuse_ig <dbl>,
#> #   smuse_sc <dbl>, smuse_wa <dbl>, smuse_tt <dbl>, smuse_rd <dbl>, …

# Sort by age category descending
arrange(d, dplyr::desc(agecat))
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 5022
#> 
#> # A tibble: 5,022 × 65
#>    respid  mode language languageinitial stratum interview_start interview_end
#>     <dbl> <dbl>    <dbl>           <dbl>   <dbl> <date>          <date>       
#>  1  17184     1        1               9      10 2025-02-24      2025-02-24   
#>  2   3144     1        1               9      10 2025-02-26      2025-02-26   
#>  3  10038     1        1               9      10 2025-02-24      2025-02-24   
#>  4  17831     1        1               9      10 2025-02-27      2025-02-27   
#>  5   3251     1        1               9       2 2025-03-10      2025-03-10   
#>  6  17144     1        2               9       3 2025-02-27      2025-02-27   
#>  7   2383     1        1               9      10 2025-02-25      2025-02-25   
#>  8   7856     1        1               9      10 2025-03-18      2025-03-18   
#>  9   2301     3        1              10       6 2025-03-25      2025-03-25   
#> 10   2206     1        1               9      10 2025-04-01      2025-04-01   
#> # ℹ 5,012 more rows
#> # ℹ 58 more variables: econ1mod <dbl>, econ1bmod <dbl>, comtype2 <dbl>,
#> #   unity <dbl>, crimesafe <dbl>, govprotct <dbl>, moregunimpact <dbl>,
#> #   fin_sit <dbl>, vet1 <dbl>, vol12_cps <dbl>, eminuse <dbl>, intmob <dbl>,
#> #   intfreq <dbl>, intfreq_collapsed <dbl>, home4nw2 <dbl>, bbhome <dbl>,
#> #   smuse_fb <dbl>, smuse_yt <dbl>, smuse_x <dbl>, smuse_ig <dbl>,
#> #   smuse_sc <dbl>, smuse_wa <dbl>, smuse_tt <dbl>, smuse_rd <dbl>, …

# Sort by multiple variables
arrange(d, gender, dplyr::desc(agecat))
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 5022
#> 
#> # A tibble: 5,022 × 65
#>    respid  mode language languageinitial stratum interview_start interview_end
#>     <dbl> <dbl>    <dbl>           <dbl>   <dbl> <date>          <date>       
#>  1  10038     1        1               9      10 2025-02-24      2025-02-24   
#>  2  17831     1        1               9      10 2025-02-27      2025-02-27   
#>  3   2301     3        1              10       6 2025-03-25      2025-03-25   
#>  4   2206     1        1               9      10 2025-04-01      2025-04-01   
#>  5  15100     1        1               9      10 2025-02-22      2025-02-22   
#>  6  17489     1        1               9      10 2025-03-03      2025-03-03   
#>  7  18269     1        1               9       9 2025-03-09      2025-03-09   
#>  8   8270     1        1               9       8 2025-03-21      2025-03-21   
#>  9  12606     1        1               9      10 2025-03-05      2025-03-05   
#> 10  13052     1        1               9      10 2025-03-28      2025-03-28   
#> # ℹ 5,012 more rows
#> # ℹ 58 more variables: econ1mod <dbl>, econ1bmod <dbl>, comtype2 <dbl>,
#> #   unity <dbl>, crimesafe <dbl>, govprotct <dbl>, moregunimpact <dbl>,
#> #   fin_sit <dbl>, vet1 <dbl>, vol12_cps <dbl>, eminuse <dbl>, intmob <dbl>,
#> #   intfreq <dbl>, intfreq_collapsed <dbl>, home4nw2 <dbl>, bbhome <dbl>,
#> #   smuse_fb <dbl>, smuse_yt <dbl>, smuse_x <dbl>, smuse_ig <dbl>,
#> #   smuse_sc <dbl>, smuse_wa <dbl>, smuse_tt <dbl>, smuse_rd <dbl>, …

# Sort by grouping variables first
d_grouped <- group_by(d, gender)
arrange(d_grouped, .by_group = TRUE, agecat)
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 5022
#> Groups: gender
#> 
#> # A tibble: 5,022 × 65
#>    respid  mode language languageinitial stratum interview_start interview_end
#>     <dbl> <dbl>    <dbl>           <dbl>   <dbl> <date>          <date>       
#>  1  13673     1        1               9      10 2025-03-02      2025-03-02   
#>  2   9247     1        1               9       7 2025-03-03      2025-03-03   
#>  3   2499     1        1               9      10 2025-02-25      2025-02-25   
#>  4  10841     1        1               9       5 2025-03-25      2025-03-25   
#>  5   5576     1        1               9      10 2025-02-27      2025-02-27   
#>  6  11753     2        1              NA       5 2025-05-01      2025-05-01   
#>  7  16776     2        1              NA      10 2025-05-02      2025-05-02   
#>  8  11751     1        1               9       9 2025-02-28      2025-02-28   
#>  9  14386     1        1               9       7 2025-02-24      2025-02-24   
#> 10   8965     2        1              NA       2 2025-05-20      2025-05-20   
#> # ℹ 5,012 more rows
#> # ℹ 58 more variables: econ1mod <dbl>, econ1bmod <dbl>, comtype2 <dbl>,
#> #   unity <dbl>, crimesafe <dbl>, govprotct <dbl>, moregunimpact <dbl>,
#> #   fin_sit <dbl>, vet1 <dbl>, vol12_cps <dbl>, eminuse <dbl>, intmob <dbl>,
#> #   intfreq <dbl>, intfreq_collapsed <dbl>, home4nw2 <dbl>, bbhome <dbl>,
#> #   smuse_fb <dbl>, smuse_yt <dbl>, smuse_x <dbl>, smuse_ig <dbl>,
#> #   smuse_sc <dbl>, smuse_wa <dbl>, smuse_tt <dbl>, smuse_rd <dbl>, …
```
