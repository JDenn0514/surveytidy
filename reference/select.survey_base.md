# Select, relocate, pull, and glimpse columns of a survey design object

- [`select()`](https://dplyr.tidyverse.org/reference/select.html)
  chooses which columns to keep, **always retaining design variables**
  (weights, strata, PSU, FPC, replicate weights) even when not
  explicitly selected. The user's selection is recorded in
  `@variables$visible_vars` so
  [`print()`](https://rdrr.io/r/base/print.html) hides the design
  columns.

- [`relocate()`](https://dplyr.tidyverse.org/reference/relocate.html)
  reorders `visible_vars` when set; reorders `@data` otherwise.

- [`pull()`](https://dplyr.tidyverse.org/reference/pull.html) extracts a
  column as a plain vector (terminal — result is not a survey object).

- [`glimpse()`](https://pillar.r-lib.org/reference/glimpse.html) prints
  a concise column summary, respecting `visible_vars`.

## Usage

``` r
# S3 method for class 'survey_base'
select(.data, ...)

# S3 method for class 'survey_base'
relocate(.data, ..., .before = NULL, .after = NULL)

# S3 method for class 'survey_base'
pull(.data, var = -1, name = NULL, ...)

# S3 method for class 'survey_base'
glimpse(x, width = NULL, ...)
```

## Arguments

- .data:

  A survey design object.

- ...:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Columns to select / reorder. For
  [`pull()`](https://dplyr.tidyverse.org/reference/pull.html), the
  column to extract.

- .before, .after:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Destination of relocated columns (passed to
  [`dplyr::relocate()`](https://dplyr.tidyverse.org/reference/relocate.html)).

- var:

  \<[`data-masking`](https://rlang.r-lib.org/reference/args_data_masking.html)\>
  Column to pull. Defaults to the last column.

- name:

  \<[`data-masking`](https://rlang.r-lib.org/reference/args_data_masking.html)\>
  Optional column to use as names for the returned vector.

- x:

  A survey design object (for
  [`glimpse()`](https://pillar.r-lib.org/reference/glimpse.html)).

- width:

  Width of the output, passed to
  [`dplyr::glimpse()`](https://pillar.r-lib.org/reference/glimpse.html).

## Value

- [`select()`](https://dplyr.tidyverse.org/reference/select.html),
  [`relocate()`](https://dplyr.tidyverse.org/reference/relocate.html):
  the survey object with updated `@data` and/or
  `@variables$visible_vars`.

- [`pull()`](https://dplyr.tidyverse.org/reference/pull.html): a plain
  vector (not a survey object).

- [`glimpse()`](https://pillar.r-lib.org/reference/glimpse.html): `x`
  invisibly.

## Functions

- `relocate(survey_base)`: Reorder columns.

- `pull(survey_base)`: Extract a column as a vector.

- `glimpse(survey_base)`: Print a concise column summary.

## See also

[`dplyr::mutate()`](https://dplyr.tidyverse.org/reference/mutate.html)
to add columns,
[`dplyr::rename()`](https://dplyr.tidyverse.org/reference/rename.html)
to rename them

## Examples

``` r
library(dplyr)
df <- data.frame(y1 = rnorm(50), y2 = rnorm(50),
                 wt = runif(50, 1, 5), g = sample(c("A","B"), 50, TRUE))
d  <- surveycore::as_survey(df, weights = wt)

# select() keeps design vars even though only y1, y2 are named
d2 <- select(d, y1, y2)
names(d2@data)               # includes wt (design var)
#> [1] "y1" "y2" "wt"
d2@variables$visible_vars    # c("y1", "y2")
#> [1] "y1" "y2"

# relocate() moves y2 before y1 in the visible columns
d3 <- relocate(d2, y2, .before = y1)

# pull() returns a plain numeric vector
pull(d, y1)
#>  [1]  1.18779227 -0.51754221 -0.25956025 -0.32806467  0.07343239 -0.24786302
#>  [7] -1.37386226 -0.04044582  0.42153824  0.20159751 -1.69719192  0.64228768
#> [13] -0.99523961  0.96381390 -1.65603723  1.07086109 -0.10902636  1.89918639
#> [19] -1.13703073 -0.27971976 -0.89412905  0.13670185 -0.74916542  0.51819908
#> [25] -0.19233721  0.02880981  0.35859089 -0.02899503  1.14704207  0.37358894
#> [31]  0.32333921 -0.82981932  1.39446258 -0.19154358  0.27227702 -1.08165901
#> [37] -2.32939936 -0.54962596 -0.07257999  1.03228840  0.21513853 -0.49434012
#> [43]  1.51213828 -0.57946326  1.67478963 -1.00098026  1.22270284  1.07718817
#> [49] -0.61194546  0.50686697

# glimpse() respects visible_vars
glimpse(d2)
#> Rows: 50
#> Columns: 2
#> $ y1 <dbl> 1.18779227, -0.51754221, -0.25956025, -0.32806467, 0.07343239, -0.2…
#> $ y2 <dbl> 0.46006837, 1.48439186, 0.88196323, -0.53670224, 1.28555371, 0.5878…
```
