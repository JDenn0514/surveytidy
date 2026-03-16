# Partially update a vector using conditional formulas

`replace_when()` is a survey-aware version of
[`dplyr::replace_when()`](https://dplyr.tidyverse.org/reference/case-and-replace-when.html)
that evaluates each formula case sequentially and replaces matching
elements of `x` with the corresponding RHS value. Elements where no case
matches retain their original value from `x`.

Use `replace_when()` when partially updating an existing vector. When
creating an entirely new vector from conditions,
[`case_when()`](https://jdenn0514.github.io/surveytidy/reference/case_when.md)
is a better choice.

`replace_when()` automatically inherits value labels and the variable
label from `x`. Supply `.label` or `.value_labels` to override the
inherited values.

When any of `.label`, `.value_labels`, or `.description` are supplied,
or when `x` carries existing labels, output label metadata is written to
`@metadata` after
[`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md).
When none apply, the output is identical to
[`dplyr::replace_when()`](https://dplyr.tidyverse.org/reference/case-and-replace-when.html).

## Usage

``` r
replace_when(x, ..., .label = NULL, .value_labels = NULL, .description = NULL)
```

## Arguments

- x:

  A vector to partially update.

- ...:

  \<[`dynamic-dots`](https://rlang.r-lib.org/reference/dyn-dots.html)\>
  A sequence of two-sided formulas (`condition ~ value`). The left-hand
  side must be a logical vector the same size as `x`. The right-hand
  side provides the replacement value, cast to the type of `x`. Cases
  are evaluated sequentially; the first matching case is used. `NULL`
  inputs are ignored.

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

- [`dplyr::replace_when()`](https://dplyr.tidyverse.org/reference/case-and-replace-when.html)
  for the base implementation.

- [`case_when()`](https://jdenn0514.github.io/surveytidy/reference/case_when.md)
  to create an entirely new vector from conditions.

- [`replace_values()`](https://jdenn0514.github.io/surveytidy/reference/replace_values.md)
  for in-place replacement using an explicit `from`/`to` mapping rather
  than conditions.

Other recoding:
[`case_when()`](https://jdenn0514.github.io/surveytidy/reference/case_when.md),
[`if_else()`](https://jdenn0514.github.io/surveytidy/reference/if_else.md),
[`na_if()`](https://jdenn0514.github.io/surveytidy/reference/na_if.md),
[`recode_values()`](https://jdenn0514.github.io/surveytidy/reference/recode_values.md),
[`replace_values()`](https://jdenn0514.github.io/surveytidy/reference/replace_values.md)

## Examples

``` r
library(surveycore)
library(surveytidy)
ns_wave1_svy <- as_survey_nonprob(ns_wave1, weights = weight)

# ---------------------------------------------------------------------
# Basic replace_when — identical to dplyr::replace_when() -------------
# ---------------------------------------------------------------------

# Replace "Something else" (pid3 == 4) with 3 (Independent).
# Only matching rows change; all others keep their original value.
new <- ns_wave1_svy |>
  mutate(pid3_clean = replace_when(pid3, pid3 == 4 ~ 3)) |>
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
    pid3_clean = replace_when(
      pid3,
      pid3 == 4 ~ 3,
      .label = "Party ID (3 categories)"
    )
  ) |>
  select(pid3, pid3_clean)
#> Error in dplyr::mutate(base_data, ..., .keep = .keep): ℹ In argument: `pid3_clean = replace_when(pid3, pid3 == 4 ~ 3, .label =
#>   "Party ID (3 categories)")`.
#> Caused by error in `replace_when()`:
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

# Provide updated value labels that reflect the collapsed categories
new <- ns_wave1_svy |>
  mutate(
    pid3_clean = replace_when(
      pid3,
      pid3 == 4 ~ 3,
      .label = "Party ID (3 categories)",
      .value_labels = c(
        "Democrat" = 1,
        "Republican" = 2,
        "Independent/Other" = 3
      )
    )
  ) |>
  select(pid3, pid3_clean)
#> Error in dplyr::mutate(base_data, ..., .keep = .keep): ℹ In argument: `pid3_clean = replace_when(...)`.
#> Caused by error in `replace_when()`:
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
    pid3_clean = replace_when(
      pid3,
      pid3 == 4 ~ 3,
      .label = "Party ID (3 categories)",
      .description = "Recoded pid3: 'Something else' (4) merged into Independent (3)."
    )
  ) |>
  select(pid3, pid3_clean)
#> Error in dplyr::mutate(base_data, ..., .keep = .keep): ℹ In argument: `pid3_clean = replace_when(...)`.
#> Caused by error in `replace_when()`:
#> ! Arguments in `...` must be passed by position, not name.
#> ✖ Problematic arguments:
#> • .label = "Party ID (3 categories)"
#> • .description = "Recoded pid3: 'Something else' (4) merged into Independent
#>   (3)."

new@metadata@transformations
#> $pid3_clean
#> [1] "replace_when(pid3, pid3 == 4 ~ 3)"
#> 
```
