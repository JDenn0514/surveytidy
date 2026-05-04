# A generalised vectorised if-else

`case_when()` is a survey-aware version of
[`dplyr::case_when()`](https://dplyr.tidyverse.org/reference/case-and-replace-when.html)
that evaluates each formula case sequentially and uses the first match
for each element to determine the output value.

Use `case_when()` when creating an entirely new vector. When partially
updating an existing vector,
[`replace_when()`](https://jdenn0514.github.io/surveytidy/reference/replace_when.md)
is a better choice — it retains the original value wherever no case
matches and inherits existing value labels from the input automatically.

When any of `.label`, `.value_labels`, `.factor`, or `.description` are
supplied, output label metadata is written to `@metadata` after
[`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md).
When none of these arguments are used, the output is identical to
[`dplyr::case_when()`](https://dplyr.tidyverse.org/reference/case-and-replace-when.html).

## Usage

``` r
case_when(
  ...,
  .default = NULL,
  .unmatched = "default",
  .ptype = NULL,
  .size = NULL,
  .label = NULL,
  .value_labels = NULL,
  .factor = FALSE,
  .description = NULL
)
```

## Arguments

- ...:

  \<[`dynamic-dots`](https://rlang.r-lib.org/reference/dyn-dots.html)\>
  A sequence of two-sided formulas (`condition ~ value`). The left-hand
  side must be a logical vector. The right-hand side provides the
  replacement value. Cases are evaluated sequentially; the first
  matching case is used. `NULL` inputs are ignored.

- .default:

  The value used when all LHS conditions return `FALSE` or `NA`. If
  `NULL` (the default), unmatched rows receive `NA`.

- .unmatched:

  Handling of unmatched rows. `"default"` (the default) uses `.default`;
  `"error"` raises an error if any row is unmatched.

- .ptype:

  An optional prototype declaring the desired output type. Overrides the
  common type of the RHS inputs.

- .size:

  An optional size declaring the desired output length. Overrides the
  common size computed from the LHS inputs.

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

  `logical(1)`. If `TRUE`, returns a factor. Levels are ordered by the
  RHS values in formula order, or by `.value_labels` names if supplied.
  Cannot be combined with `.label`.

- .description:

  `character(1)` or `NULL`. Plain-language description of how the
  variable was created. Stored in
  `@metadata@transformations[[col]]$description` after
  [`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md).

## Value

A vector, factor, or `haven_labelled` vector:

- No surveytidy args — same output as
  [`dplyr::case_when()`](https://dplyr.tidyverse.org/reference/case-and-replace-when.html).

- `.factor = TRUE` — a factor with levels in RHS formula order.

- `.label` or `.value_labels` supplied — a `haven_labelled` vector.

## See also

- [`dplyr::case_when()`](https://dplyr.tidyverse.org/reference/case-and-replace-when.html)
  for the base implementation.

- [`replace_when()`](https://jdenn0514.github.io/surveytidy/reference/replace_when.md)
  to partially update an existing vector; also inherits existing value
  labels from the input automatically.

- [`if_else()`](https://jdenn0514.github.io/surveytidy/reference/if_else.md)
  for the two-condition case.

- [`recode_values()`](https://jdenn0514.github.io/surveytidy/reference/recode_values.md)
  for value-mapping with explicit `from`/`to` vectors.

Other recoding:
[`if_else()`](https://jdenn0514.github.io/surveytidy/reference/if_else.md),
[`na_if()`](https://jdenn0514.github.io/surveytidy/reference/na_if.md),
[`recode_values()`](https://jdenn0514.github.io/surveytidy/reference/recode_values.md),
[`replace_values()`](https://jdenn0514.github.io/surveytidy/reference/replace_values.md),
[`replace_when()`](https://jdenn0514.github.io/surveytidy/reference/replace_when.md)

## Examples

``` r
library(surveycore)
library(surveytidy)

# create the survey design
ns_wave1_svy <- as_survey_nonprob(
  ns_wave1,
  weights = weight
)

# basic case_when — identical to dplyr::case_when()
new <- ns_wave1_svy |>
  mutate(
    age_pid = case_when(
      age < 30 & pid3 == 1 ~ "18-29 Democrats",
      age < 30 & pid3 == 2 ~ "18-29 Republicans",
      age < 30 & pid3 %in% c(3:4) ~ "18-29 Independents",
      .default = "Everyone else"
    )
  ) |>
  select(age, pid3, age_pid)

# by default, no metadata is attached
new
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_nonprob> (non-probability) [experimental]
#> Sample size: 6422
#> 
#> # A tibble: 6,422 × 3
#>      age  pid3 age_pid           
#>    <dbl> <dbl> <chr>             
#>  1    37     1 Everyone else     
#>  2    45     1 Everyone else     
#>  3    24     1 18-29 Democrats   
#>  4    26     3 18-29 Independents
#>  5    60     2 Everyone else     
#>  6    55     1 Everyone else     
#>  7    37     4 Everyone else     
#>  8    46     2 Everyone else     
#>  9    60     2 Everyone else     
#> 10    32     1 Everyone else     
#> # ℹ 6,412 more rows
#> 
#> ℹ Design variables preserved but hidden: weight.
#> ℹ Use `print(x, full = TRUE)` to show all variables.
new@metadata
#> <surveycore::survey_metadata>
#>  @ variable_labels  :List of 3
#>  .. $ pid3  : chr "3-category party ID"
#>  .. $ age   : chr "What is your age? Provided by LUCID. Response is an integer value 18 or ..."
#>  .. $ weight: chr "Survey weight, continuous value from 0-5"
#>  @ value_labels     :List of 1
#>  .. $ pid3: Named num [1:4] 1 2 3 4
#>  ..  ..- attr(*, "names")= chr [1:4] "Democrat" "Republican" "Independent" "Something else"
#>  @ question_prefaces: Named list()
#>  @ notes            : list()
#>  @ universe         : list()
#>  @ missing_codes    : list()
#>  @ sata             : list()
#>  @ transformations  :List of 1
#>  .. $ age_pid: chr "case_when(age < 30 & pid3 == 1 ~ \"18-29 Democrats\", age < 30 & \n    pid3 == 2 ~ \"18-29 Republicans\", age <"| __truncated__
#>  @ weighting_history: list()

# attach a variable label via .label
new <- ns_wave1_svy |>
  mutate(
    age_pid = case_when(
      age < 30 & pid3 == 1 ~ "18-29 Democrats",
      age < 30 & pid3 == 2 ~ "18-29 Republicans",
      age < 30 & pid3 %in% c(3:4) ~ "18-29 Independents",
      .default = "Everyone else",
      .label = "Age and Partisanship"
    )
  ) |>
  select(age, pid3, age_pid)

new@metadata@variable_labels
#> $pid3
#> [1] "3-category party ID"
#> 
#> $age
#> [1] "What is your age? Provided by LUCID. Response is an integer value 18 or ..."
#> 
#> $weight
#> [1] "Survey weight, continuous value from 0-5"
#> 
#> $age_pid
#> [1] "Age and Partisanship"
#> 

# attach a plain-language description of the transformation
new <- ns_wave1_svy |>
  mutate(
    age_pid = case_when(
      age < 30 & pid3 == 1 ~ "18-29 Democrats",
      age < 30 & pid3 == 2 ~ "18-29 Republicans",
      age < 30 & pid3 %in% c(3:4) ~ "18-29 Independents",
      .default = "Everyone else",
      .label = "Age and Partisanship",
      .description = paste(
        "Young (< 30) Democrats, Republicans, and Independents",
        "were grouped by partisanship; everyone else was set to",
        "'Everyone else'."
      )
    )
  ) |>
  select(age, pid3, age_pid)

new@metadata@transformations
#> $age_pid
#> $age_pid$fn
#> [1] "case_when"
#> 
#> $age_pid$source_cols
#> [1] "age"  "pid3"
#> 
#> $age_pid$expr
#> [1] "case_when(age < 30 & pid3 == 1 ~ \"18-29 Democrats\", age < 30 & "                            
#> [2] "    pid3 == 2 ~ \"18-29 Republicans\", age < 30 & pid3 %in% c(3:4) ~ "                        
#> [3] "    \"18-29 Independents\", .default = \"Everyone else\", .label = \"Age and Partisanship\", "
#> [4] "    .description = paste(\"Young (< 30) Democrats, Republicans, and Independents\", "         
#> [5] "        \"were grouped by partisanship; everyone else was set to\", "                         
#> [6] "        \"'Everyone else'.\"))"                                                               
#> 
#> $age_pid$output_type
#> [1] "vector"
#> 
#> $age_pid$description
#> [1] "Young (< 30) Democrats, Republicans, and Independents were grouped by partisanship; everyone else was set to 'Everyone else'."
#> 
#> 

# attach value labels alongside numeric codes
new <- ns_wave1_svy |>
  mutate(
    age_pid = case_when(
      age < 30 & pid3 == 1 ~ 1,
      age < 30 & pid3 == 2 ~ 2,
      age < 30 & pid3 %in% c(3:4) ~ 3,
      .default = 4,
      .label = "Age and Partisanship",
      .value_labels = c(
        "18-29 Democrats" = 1,
        "18-29 Republicans" = 2,
        "18-29 Independents" = 3,
        "Everyone else" = 4
      )
    )
  ) |>
  select(age, pid3, gender, age_pid)

new@metadata@value_labels
#> $pid3
#>       Democrat     Republican    Independent Something else 
#>              1              2              3              4 
#> 
#> $gender
#> Female   Male 
#>      1      2 
#> 
#> $age_pid
#>    18-29 Democrats  18-29 Republicans 18-29 Independents      Everyone else 
#>                  1                  2                  3                  4 
#> 

# return a factor with levels in formula order
new <- ns_wave1_svy |>
  mutate(
    age_pid = case_when(
      age < 30 & pid3 == 1 ~ "18-29 Democrats",
      age < 30 & pid3 == 2 ~ "18-29 Republicans",
      age < 30 & pid3 %in% c(3:4) ~ "18-29 Independents",
      .default = "Everyone else",
      .factor = TRUE
    )
  ) |>
  select(age, pid3, age_pid)

new
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_nonprob> (non-probability) [experimental]
#> Sample size: 6422
#> 
#> # A tibble: 6,422 × 3
#>      age  pid3 age_pid           
#>    <dbl> <dbl> <fct>             
#>  1    37     1 Everyone else     
#>  2    45     1 Everyone else     
#>  3    24     1 18-29 Democrats   
#>  4    26     3 18-29 Independents
#>  5    60     2 Everyone else     
#>  6    55     1 Everyone else     
#>  7    37     4 Everyone else     
#>  8    46     2 Everyone else     
#>  9    60     2 Everyone else     
#> 10    32     1 Everyone else     
#> # ℹ 6,412 more rows
#> 
#> ℹ Design variables preserved but hidden: weight.
#> ℹ Use `print(x, full = TRUE)` to show all variables.
```
