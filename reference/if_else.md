# Vectorised if-else

`if_else()` is a survey-aware version of
[`dplyr::if_else()`](https://dplyr.tidyverse.org/reference/if_else.html)
that applies a binary condition element-wise: `true` values are used
where `condition` is `TRUE`, `false` values where it is `FALSE`, and
`missing` values where it is `NA`.

Compared to base [`ifelse()`](https://rdrr.io/r/base/ifelse.html), this
function is stricter about types: `true`, `false`, and `missing` must be
compatible and will be cast to their common type.

When any of `.label`, `.value_labels`, or `.description` are supplied,
output label metadata is written to `@metadata` after
[`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md).
When none of these arguments are used, the output is identical to
[`dplyr::if_else()`](https://dplyr.tidyverse.org/reference/if_else.html).

For more than two conditions, see
[`case_when()`](https://jdenn0514.github.io/surveytidy/reference/case_when.md).

## Usage

``` r
if_else(
  condition,
  true,
  false,
  missing = NULL,
  ...,
  ptype = NULL,
  .label = NULL,
  .value_labels = NULL,
  .description = NULL
)
```

## Arguments

- condition:

  A logical vector.

- true, false:

  Vectors to use for `TRUE` and `FALSE` values of `condition`. Both are
  recycled to the size of `condition` and cast to their common type.

- missing:

  If not `NULL`, used as the value for `NA` values of `condition`.
  Follows the same size and type rules as `true` and `false`.

- ...:

  These dots are for future extensions and must be empty.

- ptype:

  An optional prototype declaring the desired output type. Overrides the
  common type of `true`, `false`, and `missing`.

- .label:

  `character(1)` or `NULL`. Variable label stored in
  `@metadata@variable_labels` after
  [`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md).

- .value_labels:

  Named vector or `NULL`. Value labels stored in
  `@metadata@value_labels`. Names are the label strings; values are the
  data values.

- .description:

  `character(1)` or `NULL`. Plain-language description of how the
  variable was created. Stored in
  `@metadata@transformations[[col]]$description` after
  [`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md).

## Value

A vector the same size as `condition` and the common type of `true`,
`false`, and `missing`. If `.label` or `.value_labels` are supplied,
returns a `haven_labelled` vector; otherwise returns the same type as
the common type of the inputs.

## See also

- [`dplyr::if_else()`](https://dplyr.tidyverse.org/reference/if_else.html)
  for the base implementation.

- [`case_when()`](https://jdenn0514.github.io/surveytidy/reference/case_when.md)
  for more than two conditions.

- [`na_if()`](https://jdenn0514.github.io/surveytidy/reference/na_if.md)
  to replace specific values with `NA`.

Other recoding:
[`case_when()`](https://jdenn0514.github.io/surveytidy/reference/case_when.md),
[`na_if()`](https://jdenn0514.github.io/surveytidy/reference/na_if.md),
[`recode_values()`](https://jdenn0514.github.io/surveytidy/reference/recode_values.md),
[`replace_values()`](https://jdenn0514.github.io/surveytidy/reference/replace_values.md),
[`replace_when()`](https://jdenn0514.github.io/surveytidy/reference/replace_when.md)

## Examples

``` r
library(surveycore)
library(surveytidy)
ns_wave1_svy <- as_survey_calibrated(ns_wave1, weights = weight)

# ---------------------------------------------------------------------
# Basic if_else — identical to dplyr::if_else() -----------------------
# ---------------------------------------------------------------------

new <- ns_wave1_svy |>
  mutate(senior = if_else(age >= 65, "Senior (65+)", "Non-senior")) |>
  select(age, senior)

new
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_calibrated> (calibrated / non-probability) [experimental]
#> Sample size: 6422
#> 
#> # A tibble: 6,422 × 2
#>      age senior    
#>    <dbl> <chr>     
#>  1    37 Non-senior
#>  2    45 Non-senior
#>  3    24 Non-senior
#>  4    26 Non-senior
#>  5    60 Non-senior
#>  6    55 Non-senior
#>  7    37 Non-senior
#>  8    46 Non-senior
#>  9    60 Non-senior
#> 10    32 Non-senior
#> # ℹ 6,412 more rows
#> 
#> ℹ Design variables preserved but hidden: weight.
#> ℹ Use `print(x, full = TRUE)` to show all variables.

# By default, no metadata is attached
new@metadata
#> <surveycore::survey_metadata>
#>  @ variable_labels  :List of 2
#>  .. $ age   : chr "What is your age? Provided by LUCID. Response is an integer value 18 or ..."
#>  .. $ weight: chr "Survey weight, continuous value from 0-5"
#>  @ value_labels     : Named list()
#>  @ question_prefaces: Named list()
#>  @ notes            : list()
#>  @ transformations  :List of 1
#>  .. $ senior: chr "if_else(age >= 65, \"Senior (65+)\", \"Non-senior\")"
#>  @ weighting_history: list()


# ---- Handle missing values ----

# Use missing = to specify the output value when condition is NA
new <- ns_wave1_svy |>
  mutate(
    dem = if_else(pid3 == 1, "Democrat", "Non-Democrat", missing = "Unknown")
  ) |>
  select(pid3, dem)

new
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_calibrated> (calibrated / non-probability) [experimental]
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
    senior = if_else(
      age >= 65,
      "Senior (65+)",
      "Non-senior",
      .label = "Senior citizen (age 65+)"
    )
  ) |>
  select(age, senior)
#> Error in dplyr::mutate(base_data, ..., .keep = .keep): ℹ In argument: `senior = if_else(age >= 65, "Senior (65+)",
#>   "Non-senior", .label = "Senior citizen (age 65+)")`.
#> Caused by error in `if_else()`:
#> ! `...` must be empty.
#> ✖ Problematic argument:
#> • .label = "Senior citizen (age 65+)"

new@metadata@variable_labels
#> $pid3
#> [1] "3-category party ID"
#> 
#> $weight
#> [1] "Survey weight, continuous value from 0-5"
#> 


# ---- Value labels ----

# Use integer codes for the output and add value labels to document them
new <- ns_wave1_svy |>
  mutate(
    senior = if_else(
      age >= 65,
      true = 1L,
      false = 0L,
      .label = "Senior citizen (age 65+)",
      .value_labels = c("Senior (65+)" = 1, "Non-senior" = 0)
    )
  ) |>
  select(age, senior)
#> Error in dplyr::mutate(base_data, ..., .keep = .keep): ℹ In argument: `senior = if_else(...)`.
#> Caused by error in `if_else()`:
#> ! `...` must be empty.
#> ✖ Problematic arguments:
#> • .label = "Senior citizen (age 65+)"
#> • .value_labels = c(`Senior (65+)` = 1, `Non-senior` = 0)

new@metadata@value_labels
#> $pid3
#>       Democrat     Republican    Independent Something else 
#>              1              2              3              4 
#> 


# ---- Transformation ----

new <- ns_wave1_svy |>
  mutate(
    senior = if_else(
      age >= 65,
      "Senior (65+)",
      "Non-senior",
      .label = "Senior citizen (age 65+)",
      .description = "age >= 65 coded as 'Senior (65+)'; everyone else as 'Non-senior'."
    )
  ) |>
  select(age, senior)
#> Error in dplyr::mutate(base_data, ..., .keep = .keep): ℹ In argument: `senior = if_else(...)`.
#> Caused by error in `if_else()`:
#> ! `...` must be empty.
#> ✖ Problematic arguments:
#> • .label = "Senior citizen (age 65+)"
#> • .description = "age >= 65 coded as 'Senior (65+)'; everyone else as
#>   'Non-senior'."

new@metadata@transformations
#> $dem
#> [1] "if_else(pid3 == 1, \"Democrat\", \"Non-Democrat\", missing = \"Unknown\")"
#> 
```
