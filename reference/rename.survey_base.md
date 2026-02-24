# Rename columns of a survey design object

[`rename()`](https://dplyr.tidyverse.org/reference/rename.html) and
[`rename_with()`](https://dplyr.tidyverse.org/reference/rename.html)
change column names in the underlying data and automatically keep the
survey design in sync. Variable labels, value labels, and other metadata
follow the rename — no manual bookkeeping required.

Use [`rename()`](https://dplyr.tidyverse.org/reference/rename.html) for
`new_name = old_name` pairs; use
[`rename_with()`](https://dplyr.tidyverse.org/reference/rename.html) to
apply a function across a selection of column names.

Renaming a design variable (weights, strata, PSUs) is fully supported:
the design specification updates automatically and a
`surveytidy_warning_rename_design_var` warning is issued to confirm the
change.

## Usage

``` r
rename.survey_base(.data, ...)

rename_with.survey_base(.data, .fn, .cols = dplyr::everything(), ...)
```

## Arguments

- .data:

  A
  [`survey_base`](https://jdenn0514.github.io/surveycore/reference/survey_base.html)
  object.

- ...:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Use `new_name = old_name` pairs to rename columns. Any number of
  columns can be renamed in a single call.

- .fn:

  A function (or formula/lambda) applied to selected column names. Must
  return a character vector of the same length as its input, with no
  duplicates and no conflicts with existing non-renamed column names.

- .cols:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Columns whose names `.fn` will transform. Defaults to all columns.

## Value

An object of the same type as `.data` with the following properties:

- Rows are not added or removed.

- Column order is preserved.

- Renamed columns are updated in `@data`, `@variables`, `@metadata`, and
  `@groups`.

- Survey design attributes are preserved.

## Details

### What gets updated

- **Column names in `@data`** — the rename takes effect immediately.

- **Design specification** — if a renamed column is a design variable
  (weights, strata, PSU, FPC, or replicate weights), `@variables` is
  updated to track the new name.

- **Metadata** — variable labels, value labels, question prefaces,
  notes, and transformation records in `@metadata` are re-keyed to the
  new name.

- **`visible_vars`** — any occurrence of the old name in
  `@variables$visible_vars` is replaced with the new name, so
  [`select()`](https://dplyr.tidyverse.org/reference/select.html) +
  [`rename()`](https://dplyr.tidyverse.org/reference/rename.html)
  pipelines work correctly.

- **Groups** — if a renamed column is in the active grouping, `@groups`
  is updated to use the new name.

### Renaming design variables

Renaming a design variable (e.g., the weights column) is intentionally
allowed. A `surveytidy_warning_rename_design_var` warning is issued as a
reminder that the design specification has been updated — not to
indicate an error.

### rename_with() function forms

`.fn` can be any of:

- A bare function: `rename_with(d, toupper)`

- A formula: `rename_with(d, ~ toupper(.))`

- A lambda: `rename_with(d, \(x) paste0(x, "_v2"))`

Extra arguments to `.fn` can be passed via `...`:

    rename_with(d, stringr::str_replace, .cols = starts_with("y"),
                pattern = "y", replacement = "outcome")

`.cols` uses tidy-select syntax. The default
[`dplyr::everything()`](https://tidyselect.r-lib.org/reference/everything.html)
applies `.fn` to all columns including design variables — which will
trigger a `surveytidy_warning_rename_design_var` warning for each
renamed design variable.

## See also

[`mutate()`](https://dplyr.tidyverse.org/reference/mutate.html) to add
or modify column values,
[`select()`](https://dplyr.tidyverse.org/reference/select.html) to drop
columns

Other modification:
[`mutate.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/mutate.survey_base.md)

## Examples

``` r
library(dplyr)
library(surveytidy)
library(surveycore)
d <- as_survey(pew_npors_2025, weights = weight, strata = stratum)

# rename() ----------------------------------------------------------------

# Rename an outcome column
rename(d, financial_situation = fin_sit)
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
#> #   financial_situation <dbl>, vet1 <dbl>, vol12_cps <dbl>, eminuse <dbl>,
#> #   intmob <dbl>, intfreq <dbl>, intfreq_collapsed <dbl>, home4nw2 <dbl>,
#> #   bbhome <dbl>, smuse_fb <dbl>, smuse_yt <dbl>, smuse_x <dbl>,
#> #   smuse_ig <dbl>, smuse_sc <dbl>, smuse_wa <dbl>, smuse_tt <dbl>, …

# Rename multiple columns at once
rename(d, region = cregion, education = educcat)
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

# Rename a design variable — warns and updates the design specification
rename(d, survey_weight = weight)
#> Warning: ! Renamed design variable weight.
#> ℹ The survey design has been updated to track the new name.
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

# rename_with() -----------------------------------------------------------

# Apply a function to all outcome columns
rename_with(d, toupper, .cols = starts_with("econ"))
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
#> # ℹ 58 more variables: ECON1MOD <dbl>, ECON1BMOD <dbl>, comtype2 <dbl>,
#> #   unity <dbl>, crimesafe <dbl>, govprotct <dbl>, moregunimpact <dbl>,
#> #   fin_sit <dbl>, vet1 <dbl>, vol12_cps <dbl>, eminuse <dbl>, intmob <dbl>,
#> #   intfreq <dbl>, intfreq_collapsed <dbl>, home4nw2 <dbl>, bbhome <dbl>,
#> #   smuse_fb <dbl>, smuse_yt <dbl>, smuse_x <dbl>, smuse_ig <dbl>,
#> #   smuse_sc <dbl>, smuse_wa <dbl>, smuse_tt <dbl>, smuse_rd <dbl>, …

# Use a formula
rename_with(d, ~ paste0(., "_v2"), .cols = starts_with("econ"))
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
#> # ℹ 58 more variables: econ1mod_v2 <dbl>, econ1bmod_v2 <dbl>, comtype2 <dbl>,
#> #   unity <dbl>, crimesafe <dbl>, govprotct <dbl>, moregunimpact <dbl>,
#> #   fin_sit <dbl>, vet1 <dbl>, vol12_cps <dbl>, eminuse <dbl>, intmob <dbl>,
#> #   intfreq <dbl>, intfreq_collapsed <dbl>, home4nw2 <dbl>, bbhome <dbl>,
#> #   smuse_fb <dbl>, smuse_yt <dbl>, smuse_x <dbl>, smuse_ig <dbl>,
#> #   smuse_sc <dbl>, smuse_wa <dbl>, smuse_tt <dbl>, smuse_rd <dbl>, …
```
