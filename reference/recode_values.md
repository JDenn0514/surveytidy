# Recode values using an explicit mapping

`recode_values()` replaces each value of `x` found in `from` with the
corresponding value from `to`. Values not found in `from` are either
kept unchanged (`.unmatched = "default"`, the default) or trigger an
error (`.unmatched = "error"`).

Unlike
[`replace_values()`](https://jdenn0514.github.io/surveytidy/reference/replace_values.md),
which updates only specific matching values and retains everything else,
`recode_values()` is intended for full remapping: every possible value
in `x` typically has a corresponding entry in `from`.

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

  These dots are for future extensions and must be empty.

- from:

  Vector of old values to recode from. Required unless
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

  `logical(1)`. If `TRUE`, returns a factor with levels in `to` order
  (or `.value_labels` name order if supplied). Cannot be combined with
  `.label`.

- .use_labels:

  `logical(1)`. If `TRUE`, reads `attr(x, "labels")` to build the
  `from`/`to` map automatically: values become `from`, label strings
  become `to`. `x` must carry value labels; errors if not.

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
ns_wave1_svy <- as_survey_nonprob(ns_wave1, weights = weight)

# ---------------------------------------------------------------------
# Basic recode_values — explicit from/to mapping ----------------------
# ---------------------------------------------------------------------

# Recode pid3 numeric codes to character labels
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
#> <survey_nonprob> (calibrated / non-probability) [experimental]
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


# ---- Use default to catch unmatched values ----

# Only recode Democrats; everything else becomes "Non-Democrat"
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
#> <survey_nonprob> (calibrated / non-probability) [experimental]
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


# ---------------------------------------------------------------------
# .use_labels — build the map from existing value labels --------------
# ---------------------------------------------------------------------

# pid3 carries value labels (1=Democrat, 2=Republican, 3=Independent,
# 4=Something else). .use_labels = TRUE converts codes to label strings.
new <- ns_wave1_svy |>
  mutate(party = recode_values(pid3, .use_labels = TRUE)) |>
  select(pid3, party)
#> Error in dplyr::mutate(base_data, ..., .keep = .keep): ℹ In argument: `party = recode_values(pid3, .use_labels = TRUE)`.
#> Caused by error in `recode_values()`:
#> ! Arguments in `...` must be passed by position, not name.
#> ✖ Problematic argument:
#> • .use_labels = TRUE

new
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_nonprob> (calibrated / non-probability) [experimental]
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


# ---------------------------------------------------------------------
# Set metadata --------------------------------------------------------
# ---------------------------------------------------------------------

# ---- Variable label ----

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
#> Error in dplyr::mutate(base_data, ..., .keep = .keep): ℹ In argument: `party = recode_values(...)`.
#> Caused by error in `recode_values()`:
#> ! Arguments in `...` must be passed by position, not name.
#> ✖ Problematic argument:
#> • .label = "Party identification"

new@metadata@variable_labels
#> $pid3
#> [1] "3-category party ID"
#> 
#> $weight
#> [1] "Survey weight, continuous value from 0-5"
#> 


# ---- Value labels ----

# Collapse 4 categories to 3 and add updated value labels
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
#> Error in dplyr::mutate(base_data, ..., .keep = .keep): ℹ In argument: `party = recode_values(...)`.
#> Caused by error in `recode_values()`:
#> ! Arguments in `...` must be passed by position, not name.
#> ✖ Problematic arguments:
#> • .label = "Party ID (3 categories)"
#> • .value_labels = c(Democrat = 1, Republican = 2, `Independent/Other` = 3)

new@metadata@value_labels
#> $pid3
#>       Democrat     Republican    Independent Something else 
#>              1              2              3              4 
#> 


# ---- Make output a factor ----

# Levels are ordered by the to vector
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
#> Error in dplyr::mutate(base_data, ..., .keep = .keep): ℹ In argument: `party = recode_values(...)`.
#> Caused by error in `recode_values()`:
#> ! Arguments in `...` must be passed by position, not name.
#> ✖ Problematic argument:
#> • .factor = TRUE

new
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_nonprob> (calibrated / non-probability) [experimental]
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


# ---- Transformation ----

new <- ns_wave1_svy |>
  mutate(
    party = recode_values(
      pid3,
      from = c(1, 2, 3, 4),
      to = c("Democrat", "Republican", "Independent", "Other"),
      .label = "Party identification",
      .description = "pid3 recoded: 1->Democrat, 2->Republican, 3->Independent, 4->Other."
    )
  ) |>
  select(pid3, party)
#> Error in dplyr::mutate(base_data, ..., .keep = .keep): ℹ In argument: `party = recode_values(...)`.
#> Caused by error in `recode_values()`:
#> ! Arguments in `...` must be passed by position, not name.
#> ✖ Problematic arguments:
#> • .label = "Party identification"
#> • .description = "pid3 recoded: 1->Democrat, 2->Republican, 3->Independent,
#>   4->Other."

new@metadata@transformations
#> $dem
#> [1] "recode_values(pid3, from = c(1), to = c(\"Democrat\"), default = \"Non-Democrat\")"
#> 
```
