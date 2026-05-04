# Mark rows with missing values as out-of-domain

`drop_na()` marks rows where specified columns contain `NA` as
out-of-domain, without removing them. If no columns are specified, any
`NA` in any column marks the row out-of-domain.

This is the domain-aware equivalent of tidyr's `drop_na()`: rather than
physically dropping rows, it applies
[`filter()`](https://jdenn0514.github.io/surveytidy/reference/filter.md)
with `!is.na()` conditions, preserving all rows for correct variance
estimation.

## Usage

``` r
# S3 method for class 'survey_base'
drop_na(data, ...)

# S3 method for class 'survey_result'
drop_na(data, ...)

# S3 method for class 'survey_collection'
drop_na(data, ...)

drop_na(data, ...)
```

## Arguments

- data:

  A
  [`survey_base`](https://jdenn0514.github.io/surveycore/reference/survey_base.html)
  object, or a `survey_result` object returned by a surveycore
  estimation function.

- ...:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Columns to inspect for `NA`. If empty, all columns are checked.

## Value

An object of the same type as `data` with the following properties:

- Rows are not added or removed.

- Rows where selected columns contain `NA` are marked out-of-domain.

- Columns and survey design attributes are unchanged.

## Details

### Chaining

Successive `drop_na()` calls AND their conditions together, and they
accumulate with
[`filter()`](https://jdenn0514.github.io/surveytidy/reference/filter.md)
calls too. These are equivalent:

    drop_na(d, bpxsy1) |> filter(ridageyr >= 18)
    filter(d, !is.na(bpxsy1), ridageyr >= 18)

## Survey collections

When applied to a `survey_collection`, `drop_na()` is dispatched to each
member independently with the same `...`. Per-member empty-domain
warnings fire as usual. The collection's stored `@if_missing_var`
controls behavior when a tidyselect-named column is absent from one or
more members; detection mode is class-catch (the tidyselect error is
caught at dispatch time).

Unlike other collection verbs, `drop_na()` does not accept a per-call
`.if_missing_var` argument: tidyr's `drop_na()` generic calls
[`rlang::check_dots_unnamed()`](https://rlang.r-lib.org/reference/check_dots_unnamed.html)
before S3 dispatch, which rejects any named `...` argument. Use
[`surveycore::set_collection_if_missing_var()`](https://jdenn0514.github.io/surveycore/reference/set_collection_if_missing_var.html)
to change the collection's stored behavior instead.

## See also

[`filter()`](https://jdenn0514.github.io/surveytidy/reference/filter.md)
for domain-aware row marking

Other row operations:
[`distinct`](https://jdenn0514.github.io/surveytidy/reference/distinct.md),
[`slice`](https://jdenn0514.github.io/surveytidy/reference/slice.md)

## Examples

``` r
library(tidyr)

# create a survey object from the bundled NPORS dataset
d <- surveycore::as_survey(
  surveycore::pew_npors_2025,
  weights = weight,
  strata = stratum
)

# mark rows with NA in votegen_post as out-of-domain
drop_na(d, votegen_post)
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 5022
#> Domain: 3973 of 5022 rows
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

# mark rows with NA in either social media column
drop_na(d, smuse_fb, smuse_yt)
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 5022
#> Domain: 4846 of 5022 rows
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

# no columns specified — any NA in any column marks the row out-of-domain
drop_na(d)
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 5022
#> Domain: 626 of 5022 rows
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
```
