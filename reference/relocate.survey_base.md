# Change column order in a survey design object

[`relocate()`](https://dplyr.tidyverse.org/reference/relocate.html)
moves columns to a new position using the same [tidyselect
mini-language](https://tidyselect.r-lib.org/reference/language.html) as
[`select()`](https://dplyr.tidyverse.org/reference/select.html). Design
variables (weights, strata, PSUs) are not moved — only analysis columns
change position.

## Usage

``` r
relocate.survey_base(.data, ..., .before = NULL, .after = NULL)
```

## Arguments

- .data:

  A
  [`survey_base`](https://jdenn0514.github.io/surveycore/reference/survey_base.html)
  object.

- ...:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Columns to move.

- .before, .after:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  A destination column. Columns in `...` are placed immediately before
  or after it. Specify at most one of `.before` and `.after`.

## Value

An object of the same type as `.data` with the following properties:

- Rows are not modified.

- All columns are present; only their order changes.

- Design variables are not moved.

- Groups and survey design attributes are preserved.

## Details

### Design variable positions

Design variables are always preserved at their current position in the
underlying data. When you call
[`relocate()`](https://dplyr.tidyverse.org/reference/relocate.html),
only non-design columns are affected by the reordering.

### After [`select()`](https://dplyr.tidyverse.org/reference/select.html)

When [`select()`](https://dplyr.tidyverse.org/reference/select.html) has
been called,
[`relocate()`](https://dplyr.tidyverse.org/reference/relocate.html)
reorders the visible columns (those shown when you print the object).
This has no effect on the physical column order in the underlying data.

## See also

[`select()`](https://dplyr.tidyverse.org/reference/select.html) to keep
or drop columns,
[`rename()`](https://dplyr.tidyverse.org/reference/rename.html) to
rename them

Other selecting:
[`glimpse.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/glimpse.survey_base.md),
[`pull.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/pull.survey_base.md),
[`select.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/select.survey_base.md)

## Examples

``` r
library(surveytidy)
library(surveycore)
d <- as_survey(pew_npors_2025, weights = weight, strata = stratum)

# Move agecat before gender
relocate(d, agecat, .before = gender)
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

# Move all social media columns to the front
relocate(d, dplyr::starts_with("smuse_"))
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 5022
#> 
#> # A tibble: 5,022 × 65
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
#> # ℹ 57 more variables: smuse_bsk <dbl>, smuse_th <dbl>, smuse_ts <dbl>,
#> #   respid <dbl>, mode <dbl>, language <dbl>, languageinitial <dbl>,
#> #   stratum <dbl>, interview_start <date>, interview_end <date>,
#> #   econ1mod <dbl>, econ1bmod <dbl>, comtype2 <dbl>, unity <dbl>,
#> #   crimesafe <dbl>, govprotct <dbl>, moregunimpact <dbl>, fin_sit <dbl>,
#> #   vet1 <dbl>, vol12_cps <dbl>, eminuse <dbl>, intmob <dbl>, intfreq <dbl>, …

# After select(), relocate reorders the visible columns
d |>
  select(gender, agecat, partysum) |>
  relocate(partysum, .before = gender)
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 5022
#> 
#> # A tibble: 5,022 × 3
#>    partysum gender agecat
#>       <dbl>  <dbl>  <dbl>
#>  1        2      2      4
#>  2        2      1      4
#>  3        1      2      4
#>  4        1      1      2
#>  5        1      1      4
#>  6        1      1      4
#>  7        2      1      3
#>  8        1      2      4
#>  9        1      2      3
#> 10        2      2      2
#> # ℹ 5,012 more rows
#> 
#> ℹ Design variables preserved but hidden: weight and stratum.
#> ℹ Use `print(x, full = TRUE)` to show all variables.
```
