# Create, modify, and delete columns of a survey design object

[`mutate()`](https://dplyr.tidyverse.org/reference/mutate.html) adds new
columns or modifies existing ones while preserving the survey design
structure required for valid variance estimation. It delegates column
computation to
[`dplyr::mutate()`](https://dplyr.tidyverse.org/reference/mutate.html)
on the underlying data.

Use `NULL` as a value to delete a column. Design variables (weights,
strata, PSUs) cannot be deleted this way — they are always preserved.

## Usage

``` r
mutate.survey_base(
  .data,
  ...,
  .by = NULL,
  .keep = c("all", "used", "unused", "none"),
  .before = NULL,
  .after = NULL
)
```

## Arguments

- .data:

  A
  [`survey_base`](https://jdenn0514.github.io/surveycore/reference/survey_base.html)
  object.

- ...:

  \<[`data-masking`](https://rlang.r-lib.org/reference/args_data_masking.html)\>
  Name-value pairs. The name gives the output column name; the value is
  an expression evaluated against the survey data. Use `NULL` to delete
  a non-design column.

- .by:

  Not used directly. Set grouping with
  [`group_by()`](https://dplyr.tidyverse.org/reference/group_by.html)
  instead. When `@groups` is non-empty and `.by` is `NULL` (the
  default), the active groups are applied automatically.

- .keep:

  Which columns to retain. One of `"all"` (default), `"used"`,
  `"unused"`, or `"none"`. Design variables are always re-attached
  regardless of this argument.

- .before, .after:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Optionally position new columns before or after an existing one.

## Value

An object of the same type as `.data` with the following properties:

- Rows are not added or removed.

- Columns are retained, modified, or removed per `...` and `.keep`.

- Design variables (weights, strata, PSUs) are always present.

- Groups and survey design attributes are preserved.

## Details

### Design variable modification

If the left-hand side of a mutation names a design variable (e.g.,
`mutate(d, wt = wt * 2)`), a `surveytidy_warning_mutate_design_var`
warning is issued. Detection is name-based:
[`across()`](https://dplyr.tidyverse.org/reference/across.html) calls
that happen to modify design variables will **not** trigger the warning.

### `.keep` and design variables

Design variables (weights, strata, PSUs, FPC, replicate weights, and the
domain column) are always preserved in the output, regardless of
`.keep`. This ensures variance estimation remains valid even when
`.keep = "none"`.

### Grouped mutate

Grouping set by
[`group_by()`](https://dplyr.tidyverse.org/reference/group_by.html) is
respected automatically — leave `.by = NULL` (the default) and mutate
expressions will compute within groups. The `.by` argument is not used
directly.

### Useful mutate functions

- Arithmetic: `+`, `-`, `*`, `/`, `^`, `%%`, `%/%`

- Rounding: [`round()`](https://rdrr.io/r/base/Round.html),
  [`floor()`](https://rdrr.io/r/base/Round.html),
  [`ceiling()`](https://rdrr.io/r/base/Round.html),
  [`trunc()`](https://rdrr.io/r/base/Round.html)

- Ranking:
  [`dplyr::dense_rank()`](https://dplyr.tidyverse.org/reference/row_number.html),
  [`dplyr::min_rank()`](https://dplyr.tidyverse.org/reference/row_number.html),
  [`dplyr::row_number()`](https://dplyr.tidyverse.org/reference/row_number.html)

- Cumulative: [`cumsum()`](https://rdrr.io/r/base/cumsum.html),
  [`cummax()`](https://rdrr.io/r/base/cumsum.html),
  [`cummin()`](https://rdrr.io/r/base/cumsum.html),
  [`dplyr::cummean()`](https://dplyr.tidyverse.org/reference/cumall.html)

- Conditional:
  [`dplyr::if_else()`](https://dplyr.tidyverse.org/reference/if_else.html),
  [`dplyr::case_when()`](https://dplyr.tidyverse.org/reference/case-and-replace-when.html),
  [`dplyr::case_match()`](https://dplyr.tidyverse.org/reference/case_match.html)

- Missing values:
  [`dplyr::na_if()`](https://dplyr.tidyverse.org/reference/na_if.html),
  [`dplyr::coalesce()`](https://dplyr.tidyverse.org/reference/coalesce.html)

## See also

[`rename()`](https://dplyr.tidyverse.org/reference/rename.html) to
rename columns,
[`select()`](https://dplyr.tidyverse.org/reference/select.html) to drop
columns

Other modification:
[`rename.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/rename.survey_base.md)

## Examples

``` r
library(surveytidy)
library(surveycore)
d <- as_survey(pew_npors_2025, weights = weight, strata = stratum)

# Add a new column
mutate(d, college_grad = educcat == 1)
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

# Conditional recoding
mutate(d, college = dplyr::if_else(educcat == 1, "college+", "non-college"))
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

# Grouped mutate — within-group mean centring
d |>
  group_by(gender) |>
  mutate(econ_centred = econ1mod - mean(econ1mod, na.rm = TRUE))
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 5022
#> Groups: gender
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

# .keep = "none" keeps only new columns plus design vars (always preserved)
mutate(d, college = dplyr::if_else(educcat == 1, "college+", "non-college"),
  .keep = "none")
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 5022
#> 
#> # A tibble: 5,022 × 3
#>    college     weight stratum
#>    <chr>        <dbl>   <dbl>
#>  1 college+     0.497      10
#>  2 non-college  0.307       7
#>  3 non-college  0.647       5
#>  4 non-college  1.31       10
#>  5 college+     0.242       9
#>  6 college+     0.694      10
#>  7 college+     1.12        4
#>  8 non-college  0.856      10
#>  9 college+     1.01       10
#> 10 non-college  0.689      10
#> # ℹ 5,012 more rows
```
