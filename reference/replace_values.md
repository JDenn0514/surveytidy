# Partially update values using an explicit mapping

`replace_values()` replaces each value of `x` found in `from` with the
corresponding value from `to`. Values not found in `from` retain their
original value unchanged.

Use `replace_values()` when updating only specific values of an existing
variable. When remapping the full range of values in `x`,
[`recode_values()`](https://jdenn0514.github.io/surveytidy/reference/recode_values.md)
is a better choice.

`replace_values()` automatically inherits value labels and the variable
label from `x`. Supply `.label` or `.value_labels` to override the
inherited values.

When any of `.label`, `.value_labels`, or `.description` are supplied,
or when `x` carries existing labels, output label metadata is written to
`@metadata` after
[`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md).
When none apply, the output is the same type as `x`.

## Usage

``` r
replace_values(
  x,
  ...,
  from = NULL,
  to = NULL,
  .label = NULL,
  .value_labels = NULL,
  .description = NULL
)
```

## Arguments

- x:

  Vector to partially update.

- ...:

  These dots are for future extensions and must be empty.

- from:

  Vector of old values to replace. Must be the same type as `x`.

- to:

  Vector of new values corresponding to `from`. Must be the same length
  as `from`.

- .label:

  `character(1)` or `NULL`. Variable label stored in
  `@metadata@variable_labels` after
  [`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md).
  Overrides the label inherited from `x`.

- .value_labels:

  Named vector or `NULL`. Value labels stored in
  `@metadata@value_labels`. Names are the label strings; values are the
  data values. Merged with any existing labels inherited from `x`;
  entries in `.value_labels` take precedence over inherited entries with
  the same name.

- .description:

  `character(1)` or `NULL`. Plain-language description of how the
  variable was created. Stored in
  `@metadata@transformations[[col]]$description` after
  [`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md).

## Value

An updated version of `x` with the same type and size. If `x` carries
labels or any surveytidy args are supplied, returns a `haven_labelled`
vector; otherwise returns the same type as `x`.

## See also

- [`dplyr::replace_values()`](https://dplyr.tidyverse.org/reference/recode-and-replace-values.html)
  for the base implementation.

- [`recode_values()`](https://jdenn0514.github.io/surveytidy/reference/recode_values.md)
  for full value remapping with explicit `from`/`to` vectors; does not
  inherit labels from `x` automatically.

- [`replace_when()`](https://jdenn0514.github.io/surveytidy/reference/replace_when.md)
  for condition-based partial replacement.

- [`na_if()`](https://jdenn0514.github.io/surveytidy/reference/na_if.md)
  to replace specific values with `NA`.

Other recoding:
[`case_when()`](https://jdenn0514.github.io/surveytidy/reference/case_when.md),
[`if_else()`](https://jdenn0514.github.io/surveytidy/reference/if_else.md),
[`na_if()`](https://jdenn0514.github.io/surveytidy/reference/na_if.md),
[`recode_values()`](https://jdenn0514.github.io/surveytidy/reference/recode_values.md),
[`replace_when()`](https://jdenn0514.github.io/surveytidy/reference/replace_when.md)

## Examples

``` r
library(surveycore)
library(surveytidy)
ns_wave1_svy <- as_survey_nonprob(ns_wave1, weights = weight)

# ---------------------------------------------------------------------
# Basic replace_values — replace specific values ----------------------
# ---------------------------------------------------------------------

# Replace "Something else" (4) with 3 (Independent) in pid3.
# Only matching rows change; all others keep their original value.
new <- ns_wave1_svy |>
  mutate(pid3_clean = replace_values(pid3, from = 4, to = 3)) |>
  select(pid3, pid3_clean)

new
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_nonprob> (calibrated / non-probability) [experimental]
#> Sample size: 6422
#> 
#> # A tibble: 6,422 × 2
#>     pid3 pid3_clean
#>    <dbl>      <dbl>
#>  1     1          1
#>  2     1          1
#>  3     1          1
#>  4     3          3
#>  5     2          2
#>  6     1          1
#>  7     4          3
#>  8     2          2
#>  9     2          2
#> 10     1          1
#> # ℹ 6,412 more rows
#> 
#> ℹ Design variables preserved but hidden: weight.
#> ℹ Use `print(x, full = TRUE)` to show all variables.

# Value labels from pid3 carry over to pid3_clean automatically
new@metadata@value_labels
#> $pid3
#>       Democrat     Republican    Independent Something else 
#>              1              2              3              4 
#> 


# ---------------------------------------------------------------------
# Set metadata --------------------------------------------------------
# ---------------------------------------------------------------------

# ---- Variable label ----

# Override the variable label inherited from pid3
new <- ns_wave1_svy |>
  mutate(
    pid3_clean = replace_values(
      pid3,
      from = 4,
      to = 3,
      .label = "Party ID (3 categories)"
    )
  ) |>
  select(pid3, pid3_clean)
#> Error in dplyr::mutate(base_data, ..., .keep = .keep): ℹ In argument: `pid3_clean = replace_values(pid3, from = 4, to = 3,
#>   .label = "Party ID (3 categories)")`.
#> Caused by error in `replace_values()`:
#> ! Arguments in `...` must be passed by position, not name.
#> ✖ Problematic argument:
#> • .label = "Party ID (3 categories)"

new@metadata@variable_labels
#> $pid3
#> [1] "3-category party ID"
#> 
#> $weight
#> [1] "Survey weight, continuous value from 0-5"
#> 


# ---- Value labels ----

# Provide updated value labels that reflect the recoded categories
new <- ns_wave1_svy |>
  mutate(
    pid3_clean = replace_values(
      pid3,
      from = 4,
      to = 3,
      .label = "Party ID (3 categories)",
      .value_labels = c(
        "Democrat" = 1,
        "Republican" = 2,
        "Independent/Other" = 3
      )
    )
  ) |>
  select(pid3, pid3_clean)
#> Error in dplyr::mutate(base_data, ..., .keep = .keep): ℹ In argument: `pid3_clean = replace_values(...)`.
#> Caused by error in `replace_values()`:
#> ! Arguments in `...` must be passed by position, not name.
#> ✖ Problematic arguments:
#> • .label = "Party ID (3 categories)"
#> • .value_labels = c(Democrat = 1, Republican = 2, `Independent/Other` = 3)

new@metadata@value_labels
#> $pid3
#>       Democrat     Republican    Independent Something else 
#>              1              2              3              4 
#> 


# ---- Transformation ----

new <- ns_wave1_svy |>
  mutate(
    pid3_clean = replace_values(
      pid3,
      from = 4,
      to = 3,
      .label = "Party ID (3 categories)",
      .description = "'Something else' (pid3 == 4) replaced with value 3 (Independent)."
    )
  ) |>
  select(pid3, pid3_clean)
#> Error in dplyr::mutate(base_data, ..., .keep = .keep): ℹ In argument: `pid3_clean = replace_values(...)`.
#> Caused by error in `replace_values()`:
#> ! Arguments in `...` must be passed by position, not name.
#> ✖ Problematic arguments:
#> • .label = "Party ID (3 categories)"
#> • .description = "'Something else' (pid3 == 4) replaced with value 3
#>   (Independent)."

new@metadata@transformations
#> $pid3_clean
#> [1] "replace_values(pid3, from = 4, to = 3)"
#> 
```
