# Recode values using an explicit mapping

`recode_values()` replaces each value of `x` with a corresponding new
value. The mapping can be supplied in any of three ways:

- **Formula interface** — pass `old_value ~ new_value` formulas in
  `...`:
  `recode_values(score, 1 ~ "SD", 2 ~ "D", 3 ~ "N", 4 ~ "A", 5 ~ "SA")`.

- **Lookup-table interface** — pass parallel `from` and `to` vectors.

- **Label-driven interface** — set `.use_labels = TRUE` to build the map
  from `attr(x, "labels")` (values become `from`, label strings become
  `to`).

Values not found in the map are either kept unchanged
(`.unmatched = "default"`, the default) or trigger an error
(`.unmatched = "error"`).

Unlike
[`replace_values()`](https://jdenn0514.github.io/surveytidy/reference/replace_values.md),
which updates only specific matching values and retains everything else,
`recode_values()` is intended for full remapping: every possible value
in `x` typically has a corresponding entry in the map.

When any of `.label`, `.value_labels`, `.factor`, or `.description` are
supplied, output label metadata is written to `@metadata` after
[`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md).
When none of these arguments are used, the output is identical to
[`dplyr::recode_values()`](https://dplyr.tidyverse.org/reference/recode-and-replace-values.html).

## Usage

``` r
recode_values(
  x,
  ...,
  from = NULL,
  to = NULL,
  default = NULL,
  .unmatched = "default",
  ptype = NULL,
  .label = NULL,
  .value_labels = NULL,
  .factor = FALSE,
  .use_labels = FALSE,
  .description = NULL
)
```

## Arguments

- x:

  Vector to recode.

- ...:

  `old_value ~ new_value` formulas describing the recoding map.
  Equivalent to supplying parallel `from`/`to` vectors. When `...` is
  non-empty, `from` and `.use_labels = TRUE` must not be used.

- from:

  Vector (or list of vectors, for many-to-one mapping) of old values.
  Required unless formulas are supplied in `...` or
  `.use_labels = TRUE`. Must be the same type as `x`.

- to:

  Vector of new values corresponding to `from`. Must be the same length
  as `from`.

- default:

  Value for entries in `x` not found in `from`. `NULL` (the default)
  keeps unmatched values unchanged. Ignored when `.unmatched = "error"`.

- .unmatched:

  `"default"` (the default) or `"error"`. When `"error"`, any value in
  `x` not present in `from` triggers a
  `surveytidy_error_recode_unmatched_values` error.

- ptype:

  An optional prototype declaring the desired output type.

- .label:

  `character(1)` or `NULL`. Variable label stored in
  `@metadata@variable_labels` after
  [`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md).
  Cannot be combined with `.factor = TRUE`.

- .value_labels:

  Named vector or `NULL`. Value labels stored in
  `@metadata@value_labels`. Names are the label strings; values are the
  data values.

- .factor:

  `logical(1)`. If `TRUE`, returns a factor. Levels are taken from
  `.value_labels` names if supplied, otherwise from `to` in lookup mode
  or from the right-hand sides of the `...` formulas in formula mode.
  Cannot be combined with `.label`.

- .use_labels:

  `logical(1)`. If `TRUE`, reads `attr(x, "labels")` to build the
  `from`/`to` map automatically: values become `from`, label strings
  become `to`. `x` must carry value labels; errors if not. Cannot be
  combined with formulas in `...`.

- .description:

  `character(1)` or `NULL`. Plain-language description of how the
  variable was created. Stored in
  `@metadata@transformations[[col]]$description` after
  [`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md).

## Value

A vector, factor, or `haven_labelled` vector:

- No surveytidy args — same output as
  [`dplyr::recode_values()`](https://dplyr.tidyverse.org/reference/recode-and-replace-values.html).

- `.factor = TRUE` — a factor with levels in `to` order.

- `.label` or `.value_labels` supplied — a `haven_labelled` vector.

## See also

- [`dplyr::recode_values()`](https://dplyr.tidyverse.org/reference/recode-and-replace-values.html)
  for the base implementation.

- [`replace_values()`](https://jdenn0514.github.io/surveytidy/reference/replace_values.md)
  for partial replacement (updates only matching values, retains
  existing value labels from `x`).

- [`case_when()`](https://jdenn0514.github.io/surveytidy/reference/case_when.md)
  for condition-based remapping.

Other recoding:
[`case_when()`](https://jdenn0514.github.io/surveytidy/reference/case_when.md),
[`if_else()`](https://jdenn0514.github.io/surveytidy/reference/if_else.md),
[`na_if()`](https://jdenn0514.github.io/surveytidy/reference/na_if.md),
[`replace_values()`](https://jdenn0514.github.io/surveytidy/reference/replace_values.md),
[`replace_when()`](https://jdenn0514.github.io/surveytidy/reference/replace_when.md)

## Examples

``` r
library(surveycore)
library(surveytidy)

# create the survey design
ns_wave1_svy <- as_survey_nonprob(ns_wave1, weights = weight)

# formula interface — recode pid3 using `old ~ new` formulas in `...`
new <- ns_wave1_svy |>
  mutate(
    party = recode_values(
      pid3,
      1 ~ "Democrat",
      2 ~ "Republican",
      3 ~ "Independent",
      4 ~ "Other"
    )
  ) |>
  select(pid3, party)

new
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_nonprob> (non-probability) [experimental]
#> Sample size: 6422
#> 
#> # A tibble: 6,422 × 2
#>     pid3 party      
#>    <dbl> <chr>      
#>  1     1 Democrat   
#>  2     1 Democrat   
#>  3     1 Democrat   
#>  4     3 Independent
#>  5     2 Republican 
#>  6     1 Democrat   
#>  7     4 Other      
#>  8     2 Republican 
#>  9     2 Republican 
#> 10     1 Democrat   
#> # ℹ 6,412 more rows
#> 
#> ℹ Design variables preserved but hidden: weight.
#> ℹ Use `print(x, full = TRUE)` to show all variables.

# formula interface with default for unmatched values
new <- ns_wave1_svy |>
  mutate(
    dem = recode_values(pid3, 1 ~ "Democrat", default = "Non-Democrat")
  ) |>
  select(pid3, dem)

new
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_nonprob> (non-probability) [experimental]
#> Sample size: 6422
#> 
#> # A tibble: 6,422 × 2
#>     pid3 dem         
#>    <dbl> <chr>       
#>  1     1 Democrat    
#>  2     1 Democrat    
#>  3     1 Democrat    
#>  4     3 Non-Democrat
#>  5     2 Non-Democrat
#>  6     1 Democrat    
#>  7     4 Non-Democrat
#>  8     2 Non-Democrat
#>  9     2 Non-Democrat
#> 10     1 Democrat    
#> # ℹ 6,412 more rows
#> 
#> ℹ Design variables preserved but hidden: weight.
#> ℹ Use `print(x, full = TRUE)` to show all variables.

# explicit from/to mapping — recode numeric codes to character labels
new <- ns_wave1_svy |>
  mutate(
    party = recode_values(
      pid3,
      from = c(1, 2, 3, 4),
      to = c("Democrat", "Republican", "Independent", "Other")
    )
  ) |>
  select(pid3, party)

new
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_nonprob> (non-probability) [experimental]
#> Sample size: 6422
#> 
#> # A tibble: 6,422 × 2
#>     pid3 party      
#>    <dbl> <chr>      
#>  1     1 Democrat   
#>  2     1 Democrat   
#>  3     1 Democrat   
#>  4     3 Independent
#>  5     2 Republican 
#>  6     1 Democrat   
#>  7     4 Other      
#>  8     2 Republican 
#>  9     2 Republican 
#> 10     1 Democrat   
#> # ℹ 6,412 more rows
#> 
#> ℹ Design variables preserved but hidden: weight.
#> ℹ Use `print(x, full = TRUE)` to show all variables.

# use default to catch unmatched values
new <- ns_wave1_svy |>
  mutate(
    dem = recode_values(
      pid3,
      from = c(1),
      to = c("Democrat"),
      default = "Non-Democrat"
    )
  ) |>
  select(pid3, dem)

new
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_nonprob> (non-probability) [experimental]
#> Sample size: 6422
#> 
#> # A tibble: 6,422 × 2
#>     pid3 dem         
#>    <dbl> <chr>       
#>  1     1 Democrat    
#>  2     1 Democrat    
#>  3     1 Democrat    
#>  4     3 Non-Democrat
#>  5     2 Non-Democrat
#>  6     1 Democrat    
#>  7     4 Non-Democrat
#>  8     2 Non-Democrat
#>  9     2 Non-Democrat
#> 10     1 Democrat    
#> # ℹ 6,412 more rows
#> 
#> ℹ Design variables preserved but hidden: weight.
#> ℹ Use `print(x, full = TRUE)` to show all variables.

# .use_labels = TRUE builds the from/to map from existing value labels
new <- ns_wave1_svy |>
  mutate(party = recode_values(pid3, .use_labels = TRUE)) |>
  select(pid3, party)

new
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_nonprob> (non-probability) [experimental]
#> Sample size: 6422
#> 
#> # A tibble: 6,422 × 2
#>     pid3 party         
#>    <dbl> <chr>         
#>  1     1 Democrat      
#>  2     1 Democrat      
#>  3     1 Democrat      
#>  4     3 Independent   
#>  5     2 Republican    
#>  6     1 Democrat      
#>  7     4 Something else
#>  8     2 Republican    
#>  9     2 Republican    
#> 10     1 Democrat      
#> # ℹ 6,412 more rows
#> 
#> ℹ Design variables preserved but hidden: weight.
#> ℹ Use `print(x, full = TRUE)` to show all variables.

# attach a variable label via .label
new <- ns_wave1_svy |>
  mutate(
    party = recode_values(
      pid3,
      from = c(1, 2, 3, 4),
      to = c("Democrat", "Republican", "Independent", "Other"),
      .label = "Party identification"
    )
  ) |>
  select(pid3, party)

new@metadata@variable_labels
#> $pid3
#> [1] "3-category party ID"
#> 
#> $weight
#> [1] "Survey weight, continuous value from 0-5"
#> 
#> $party
#> [1] "Party identification"
#> 

# collapse 4 categories to 3 and document via .value_labels
new <- ns_wave1_svy |>
  mutate(
    party = recode_values(
      pid3,
      from = c(1, 2, 3, 4),
      to = c(1, 2, 3, 3),
      .label = "Party ID (3 categories)",
      .value_labels = c(
        "Democrat" = 1,
        "Republican" = 2,
        "Independent/Other" = 3
      )
    )
  ) |>
  select(pid3, party)

new@metadata@value_labels
#> $pid3
#>       Democrat     Republican    Independent Something else 
#>              1              2              3              4 
#> 
#> $party
#>          Democrat        Republican Independent/Other 
#>                 1                 2                 3 
#> 

# return a factor with levels in `to` order
new <- ns_wave1_svy |>
  mutate(
    party = recode_values(
      pid3,
      from = c(1, 2, 3, 4),
      to = c("Democrat", "Republican", "Independent", "Other"),
      .factor = TRUE
    )
  ) |>
  select(pid3, party)

new
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_nonprob> (non-probability) [experimental]
#> Sample size: 6422
#> 
#> # A tibble: 6,422 × 2
#>     pid3 party      
#>    <dbl> <fct>      
#>  1     1 Democrat   
#>  2     1 Democrat   
#>  3     1 Democrat   
#>  4     3 Independent
#>  5     2 Republican 
#>  6     1 Democrat   
#>  7     4 Other      
#>  8     2 Republican 
#>  9     2 Republican 
#> 10     1 Democrat   
#> # ℹ 6,412 more rows
#> 
#> ℹ Design variables preserved but hidden: weight.
#> ℹ Use `print(x, full = TRUE)` to show all variables.

# attach a plain-language description of the transformation
new <- ns_wave1_svy |>
  mutate(
    party = recode_values(
      pid3,
      from = c(1, 2, 3, 4),
      to = c("Democrat", "Republican", "Independent", "Other"),
      .label = "Party identification",
      .description = paste(
        "pid3 recoded: 1->Democrat, 2->Republican,",
        "3->Independent, 4->Other."
      )
    )
  ) |>
  select(pid3, party)

new@metadata@transformations
#> $party
#> $party$fn
#> [1] "recode_values"
#> 
#> $party$source_cols
#> [1] "pid3"
#> 
#> $party$expr
#> [1] "recode_values(pid3, from = c(1, 2, 3, 4), to = c(\"Democrat\", "                     
#> [2] "    \"Republican\", \"Independent\", \"Other\"), .label = \"Party identification\", "
#> [3] "    .description = paste(\"pid3 recoded: 1->Democrat, 2->Republican,\", "            
#> [4] "        \"3->Independent, 4->Other.\"))"                                             
#> 
#> $party$output_type
#> [1] "vector"
#> 
#> $party$description
#> [1] "pid3 recoded: 1->Democrat, 2->Republican, 3->Independent, 4->Other."
#> 
#> 
```
