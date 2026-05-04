# Stack surveys with bind_rows (errors unconditionally)

`bind_rows()` errors unconditionally when the first argument is a survey
design object. Stacking two surveys changes the design — the combined
object requires a new design specification (e.g., a new survey-wave
stratum).

When the first argument is not a survey object, this function delegates
to
[`dplyr::bind_rows()`](https://dplyr.tidyverse.org/reference/bind_rows.html)
transparently.

## Usage

``` r
bind_rows(x, ..., .id = NULL)
```

## Arguments

- x:

  A
  [`survey_base`](https://jdenn0514.github.io/surveycore/reference/survey_base.html)
  object (always errors), or any object accepted by
  [`dplyr::bind_rows()`](https://dplyr.tidyverse.org/reference/bind_rows.html)
  (transparent delegation).

- ...:

  Additional arguments.

- .id:

  Forwarded to
  [`dplyr::bind_rows()`](https://dplyr.tidyverse.org/reference/bind_rows.html).

## Value

Never returns when `x` is a survey object — always throws an error. When
`x` is not a survey object, returns the result of
[`dplyr::bind_rows()`](https://dplyr.tidyverse.org/reference/bind_rows.html).

## Details

**Known limitation:** If the survey object is passed as a **non-first**
argument (e.g., `bind_rows(df, survey)`), this function delegates to
`dplyr::bind_rows(df, survey)` which will fail with a dplyr/vctrs error
rather than the survey-specific error. Always pass the survey object as
the first argument to ensure the correct error is triggered.

### Dispatch note

[`dplyr::bind_rows()`](https://dplyr.tidyverse.org/reference/bind_rows.html)
uses
[`vctrs::vec_rbind()`](https://vctrs.r-lib.org/reference/vec_bind.html)
internally for recent dplyr versions and does not reliably dispatch via
S3 on `x` for S7 objects. surveytidy provides its own `bind_rows()` that
intercepts survey objects before delegating to dplyr (GAP-6 verified: S3
dispatch does not work; standalone function approach used instead).

## See also

Other joins:
[`bind_cols()`](https://jdenn0514.github.io/surveytidy/reference/bind_cols.md),
[`inner_join`](https://jdenn0514.github.io/surveytidy/reference/inner_join.md),
[`left_join`](https://jdenn0514.github.io/surveytidy/reference/left_join.md),
[`right_join`](https://jdenn0514.github.io/surveytidy/reference/right_join.md),
[`semi_join`](https://jdenn0514.github.io/surveytidy/reference/semi_join.md)

## Examples

``` r
# NOTE: do not load dplyr here — its bind_rows() would mask surveytidy's
# bind_rows() and bypass the survey-object check shown below.

# two raw data frames that together define a combined survey
df1 <- data.frame(wt = c(1, 1), y1 = c(1, 2))
df2 <- data.frame(wt = c(1, 1), y1 = c(3, 4))

# bind_rows() on plain data frames delegates to dplyr::bind_rows()
bind_rows(df1, df2)
#>   wt y1
#> 1  1  1
#> 2  1  2
#> 3  1  3
#> 4  1  4

# but bind_rows() on a survey object always errors — stacking two surveys
# would change the design, requiring a new design specification
d1 <- surveycore::as_survey(df1, weights = wt)

tryCatch(
  bind_rows(d1, df2),
  error = function(e) message(conditionMessage(e))
)
#> ✖ `bind_rows()` cannot stack survey design objects.
#> ℹ Stacking two surveys changes the design — the combined object requires a new
#>   design specification.
#> ✔ Extract `@data` from each survey object with `surveycore::survey_data()`,
#>   bind the raw data frames with `dplyr::bind_rows()`, then re-specify the
#>   combined design with `surveycore::as_survey()`.

# the recommended workflow: extract raw data from each survey, bind, then
# re-specify the design on the combined data frame
combined <- bind_rows(
  surveycore::survey_data(d1),
  df2
)
surveycore::as_survey(combined, weights = wt)
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 4
#> 
#> # A tibble: 4 × 2
#>      wt    y1
#>   <dbl> <dbl>
#> 1     1     1
#> 2     1     2
#> 3     1     3
#> 4     1     4
```
