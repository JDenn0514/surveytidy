# Convert values to `NA`

`na_if()` is a survey-aware version of
[`dplyr::na_if()`](https://dplyr.tidyverse.org/reference/na_if.html)
that converts values equal to `y` to `NA`. It is useful for replacing
sentinel values (e.g., `999` for "don't know") with proper missing
values.

Unlike
[`dplyr::na_if()`](https://dplyr.tidyverse.org/reference/na_if.html),
which accepts only a scalar `y`, this version accepts a vector `y` and
replaces all matching values in a single call.

When `x` carries value labels, `na_if()` automatically inherits those
labels. By default (`.update_labels = TRUE`), the label entries for the
NA'd values are removed from the output; set `.update_labels = FALSE` to
retain them (useful when you want to document what was set to missing).

## Usage

``` r
na_if(x, y, .update_labels = TRUE, .description = NULL)
```

## Arguments

- x:

  Vector to modify.

- y:

  Value or vector of values to replace with `NA`. `y` is cast to the
  type of `x` before comparison. When `y` has more than one element,
  each value is replaced sequentially.

- .update_labels:

  `logical(1)`. If `TRUE` (the default) and `x` carries value labels,
  label entries for values in `y` are removed from the output's value
  labels. Set to `FALSE` to retain all inherited labels even for values
  that were set to `NA`.

- .description:

  `character(1)` or `NULL`. Plain-language description of how the
  variable was created. Stored in
  `@metadata@transformations[[col]]$description` after
  [`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md).

## Value

A modified version of `x` where values equal to `y` are replaced with
`NA`. If `x` carries value labels, returns a `haven_labelled` vector
with updated (or retained) labels; otherwise returns the same type as
`x`.

## See also

- [`dplyr::na_if()`](https://dplyr.tidyverse.org/reference/na_if.html)
  for the base implementation.

- [`dplyr::coalesce()`](https://dplyr.tidyverse.org/reference/coalesce.html)
  to replace `NA`s with the first non-missing value.

- [`replace_values()`](https://jdenn0514.github.io/surveytidy/reference/replace_values.md)
  for replacing specific values with a new value rather than `NA`.

- [`replace_when()`](https://jdenn0514.github.io/surveytidy/reference/replace_when.md)
  for condition-based in-place replacement.

Other recoding:
[`case_when()`](https://jdenn0514.github.io/surveytidy/reference/case_when.md),
[`if_else()`](https://jdenn0514.github.io/surveytidy/reference/if_else.md),
[`recode_values()`](https://jdenn0514.github.io/surveytidy/reference/recode_values.md),
[`replace_values()`](https://jdenn0514.github.io/surveytidy/reference/replace_values.md),
[`replace_when()`](https://jdenn0514.github.io/surveytidy/reference/replace_when.md)

## Examples

``` r
library(surveycore)
library(surveytidy)
ns_wave1_svy <- as_survey_nonprob(ns_wave1, weights = weight)

# ---------------------------------------------------------------------
# Basic na_if — replace a specific value with NA ----------------------
# ---------------------------------------------------------------------

# Replace "Something else" (pid3 == 4) with NA
new <- ns_wave1_svy |>
  mutate(pid3_clean = na_if(pid3, 4)) |>
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
#>  7     4         NA
#>  8     2          2
#>  9     2          2
#> 10     1          1
#> # ℹ 6,412 more rows
#> 
#> ℹ Design variables preserved but hidden: weight.
#> ℹ Use `print(x, full = TRUE)` to show all variables.


# ---- Replace multiple values at once ----

# Replace both Independent (3) and "Something else" (4) with NA
new <- ns_wave1_svy |>
  mutate(pid3_2party = na_if(pid3, c(3, 4))) |>
  select(pid3, pid3_2party)
#> Error in dplyr::mutate(base_data, ..., .keep = .keep): ℹ In argument: `pid3_2party = na_if(pid3, c(3, 4))`.
#> Caused by error in `na_if()`:
#> ! Can't recycle `y` (size 2) to size 6422.

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
#>  7     4         NA
#>  8     2          2
#>  9     2          2
#> 10     1          1
#> # ℹ 6,412 more rows
#> 
#> ℹ Design variables preserved but hidden: weight.
#> ℹ Use `print(x, full = TRUE)` to show all variables.


# ---------------------------------------------------------------------
# .update_labels — control which value labels are kept ----------------
# ---------------------------------------------------------------------

# .update_labels = TRUE (default): the label entry for the NA'd value
# is removed from the output's value labels
new <- ns_wave1_svy |>
  mutate(pid3_clean = na_if(pid3, 4, .update_labels = TRUE)) |>
  select(pid3, pid3_clean)
#> Error in dplyr::mutate(base_data, ..., .keep = .keep): ℹ In argument: `pid3_clean = na_if(pid3, 4, .update_labels = TRUE)`.
#> Caused by error in `na_if()`:
#> ! unused argument (.update_labels = TRUE)

# "Something else" (4) is removed from pid3_clean's value labels
new@metadata@value_labels$pid3_clean
#> NULL


# .update_labels = FALSE: the label entry for 4 is retained even though
# those rows are now NA; useful when documenting what was set to missing
new <- ns_wave1_svy |>
  mutate(pid3_clean = na_if(pid3, 4, .update_labels = FALSE)) |>
  select(pid3, pid3_clean)
#> Error in dplyr::mutate(base_data, ..., .keep = .keep): ℹ In argument: `pid3_clean = na_if(pid3, 4, .update_labels = FALSE)`.
#> Caused by error in `na_if()`:
#> ! unused argument (.update_labels = FALSE)

# "Something else" (4) is still in pid3_clean's value labels
new@metadata@value_labels$pid3_clean
#> NULL


# ---- Transformation ----

new <- ns_wave1_svy |>
  mutate(
    pid3_clean = na_if(
      pid3,
      4,
      .description = "Set 'Something else' (pid3 == 4) to NA."
    )
  ) |>
  select(pid3, pid3_clean)
#> Error in dplyr::mutate(base_data, ..., .keep = .keep): ℹ In argument: `pid3_clean = na_if(pid3, 4, .description = "Set
#>   'Something else' (pid3 == 4) to NA.")`.
#> Caused by error in `na_if()`:
#> ! unused argument (.description = "Set 'Something else' (pid3 == 4) to NA.")

new@metadata@transformations
#> $pid3_clean
#> [1] "na_if(pid3, 4)"
#> 
```
