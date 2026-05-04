# Rename columns of a survey design object

`rename()` and
[`rename_with()`](https://dplyr.tidyverse.org/reference/rename.html)
change column names in the underlying data and automatically keep the
survey design in sync. Variable labels, value labels, and other metadata
follow the rename — no manual bookkeeping required.

Use `rename()` for `new_name = old_name` pairs; use
[`rename_with()`](https://dplyr.tidyverse.org/reference/rename.html) to
apply a function across a selection of column names.

Renaming a design variable (weights, strata, PSUs) is fully supported:
the design specification updates automatically and a
`surveytidy_warning_rename_design_var` warning is issued to confirm the
change.

## Usage

``` r
rename(.data, ...)

# S3 method for class 'survey_base'
rename(.data, ...)

# S3 method for class 'survey_result'
rename(.data, ...)

# S3 method for class 'survey_base'
rename_with(.data, .fn, .cols = dplyr::everything(), ...)

# S3 method for class 'survey_result'
rename_with(.data, .fn, .cols = dplyr::everything(), ...)

# S3 method for class 'survey_collection'
rename(.data, ..., .if_missing_var = NULL)

# S3 method for class 'survey_collection'
rename_with(
  .data,
  .fn,
  .cols = dplyr::everything(),
  ...,
  .if_missing_var = NULL
)
```

## Arguments

- .data:

  A
  [`survey_base`](https://jdenn0514.github.io/surveycore/reference/survey_base.html)
  object, or a `survey_result` object returned by a surveycore
  estimation function.

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

- .if_missing_var:

  Per-call override of `collection@if_missing_var`. One of `"error"` or
  `"skip"`, or `NULL` (the default) to inherit the collection's stored
  value. See
  [`surveycore::set_collection_if_missing_var()`](https://jdenn0514.github.io/surveycore/reference/set_collection_if_missing_var.html).

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
  [`select()`](https://jdenn0514.github.io/surveytidy/reference/select.md) +
  `rename()` pipelines work correctly.

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

    rename_with(d, stringr::str_replace, .cols = tidyselect::starts_with("y"),
                pattern = "y", replacement = "outcome")

`.cols` uses tidy-select syntax. The default
[`dplyr::everything()`](https://tidyselect.r-lib.org/reference/everything.html)
applies `.fn` to all columns including design variables — which will
trigger a `surveytidy_warning_rename_design_var` warning for each
renamed design variable.

## Survey collections

When applied to a `survey_collection`, `rename()` is dispatched to each
member independently. Each member's `rename.survey_base` updates
`@data`, `@variables`, `@metadata`, and `@groups` atomically.

Before dispatching, `rename.survey_collection` resolves the rename map
against each member's `@data` and raises
`surveytidy_error_collection_rename_group_partial` if any column in
`coll@groups` would be renamed on some members but not others — that
would leave the collection with an inconsistent `@groups` invariant (G1)
that no `.if_missing_var` policy can recover. For plain `rename` the
rename map is universal, so this branch normally fires only as a
defense-in-depth catch for regressions in the surveycore G1b validator.

Renaming a non-group design variable (weights, ids, strata, fpc) emits
`surveytidy_warning_rename_design_var` once per member — N firings on an
N-member collection. Capture with
[`withCallingHandlers()`](https://rdrr.io/r/base/conditions.html).

When applied to a `survey_collection`,
[`rename_with()`](https://dplyr.tidyverse.org/reference/rename.html) is
dispatched to each member independently. Each member resolves `.cols`
against its own `@data`, so a `.cols` like `where(is.factor)` may select
different columns on different members.

Before dispatching, `rename_with.survey_collection` resolves `.cols`
per-member and raises `surveytidy_error_collection_rename_group_partial`
if any column in `coll@groups` would be renamed on some members but not
others. This is the genuine trigger for the partial-rename class —
`.cols` resolving differently across a heterogeneous collection is the
path the spec is designed to catch (see §IV.4 reachability note).

Per-member design-variable warnings fire once per affected member.

## See also

[`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md)
to add or modify column values,
[`select()`](https://jdenn0514.github.io/surveytidy/reference/select.md)
to drop columns

Other modification:
[`mutate`](https://jdenn0514.github.io/surveytidy/reference/mutate.md)

## Examples

``` r
library(surveytidy)
library(surveycore)

# create a survey design from the pew_npors_2025 example dataset
d <- as_survey(pew_npors_2025, weights = weight, strata = stratum)

# rename() ----------------------------------------------------------------

# rename an outcome column
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

# rename multiple columns at once
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

# rename a design variable — warns and updates the design specification
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

# apply a function to all matching columns
rename_with(d, toupper, .cols = tidyselect::starts_with("econ"))
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

# use a formula
rename_with(d, ~ paste0(., "_v2"), .cols = tidyselect::starts_with("econ"))
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
