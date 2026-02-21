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
#>  [1] -1.42236955  1.10814896  1.07847764 -0.44025034 -0.77816901 -1.81859001
#>  [7] -1.12408090  1.06052384 -1.47870016 -1.55156017  0.77750668  1.06844014
#> [13] -0.18358770  1.55824293 -0.21324238  0.93053526  0.41081180 -1.27984430
#> [19] -0.78236663 -2.27608345 -0.12639591  1.44814671 -1.44275737  1.46718718
#> [25] -0.74329990 -0.30422384  0.33765806 -0.60750209 -0.29556027 -0.13453714
#> [31]  0.81478437 -0.27292173  2.15948580  1.09173757  0.74338485 -1.20785935
#> [37]  0.32781805 -0.53416511  1.28394672  0.02893134 -0.39567707 -0.69486833
#> [43] -1.49208070  1.44425724 -0.34701739 -0.04025917  1.24663211 -1.34630152
#> [49] -0.57390128 -0.70595925

# glimpse() respects visible_vars
glimpse(d2)
#> Rows: 50
#> Columns: 2
#> $ y1 <dbl> -1.4223695, 1.1081490, 1.0784776, -0.4402503, -0.7781690, -1.818590…
#> $ y2 <dbl> -1.85740454, -0.24697048, -0.33556093, -0.24937687, 0.45952256, -0.…
```
