# Physically select rows of a survey design object

`slice()`,
[`slice_head()`](https://dplyr.tidyverse.org/reference/slice.html),
[`slice_tail()`](https://dplyr.tidyverse.org/reference/slice.html),
[`slice_min()`](https://dplyr.tidyverse.org/reference/slice.html),
[`slice_max()`](https://dplyr.tidyverse.org/reference/slice.html), and
[`slice_sample()`](https://dplyr.tidyverse.org/reference/slice.html)
**physically remove rows** from a survey design object. For
subpopulation analyses, use
[`filter()`](https://jdenn0514.github.io/surveytidy/reference/filter.md)
instead — it marks rows as out-of-domain without removing them,
preserving valid variance estimation.

All slice functions always issue `surveycore_warning_physical_subset`
and error if the result would have 0 rows.

## Usage

``` r
slice(.data, ..., .by = NULL, .preserve = FALSE)

# S3 method for class 'survey_base'
slice(.data, ...)

# S3 method for class 'survey_base'
slice_head(.data, ...)

# S3 method for class 'survey_base'
slice_tail(.data, ...)

# S3 method for class 'survey_base'
slice_min(.data, ...)

# S3 method for class 'survey_base'
slice_max(.data, ...)

# S3 method for class 'survey_base'
slice_sample(.data, ...)

# S3 method for class 'survey_result'
slice(.data, ...)

# S3 method for class 'survey_result'
slice_head(.data, ...)

# S3 method for class 'survey_result'
slice_tail(.data, ...)

# S3 method for class 'survey_result'
slice_min(.data, ...)

# S3 method for class 'survey_result'
slice_max(.data, ...)

# S3 method for class 'survey_result'
slice_sample(.data, ...)

# S3 method for class 'survey_collection'
slice(.data, ...)

# S3 method for class 'survey_collection'
slice_head(.data, ..., n = NULL, prop = NULL)

# S3 method for class 'survey_collection'
slice_tail(.data, ..., n = NULL, prop = NULL)

# S3 method for class 'survey_collection'
slice_min(
  .data,
  order_by,
  ...,
  n = NULL,
  prop = NULL,
  by = NULL,
  with_ties = TRUE,
  na_rm = FALSE,
  .if_missing_var = NULL
)

# S3 method for class 'survey_collection'
slice_max(
  .data,
  order_by,
  ...,
  n = NULL,
  prop = NULL,
  by = NULL,
  with_ties = TRUE,
  na_rm = FALSE,
  .if_missing_var = NULL
)

# S3 method for class 'survey_collection'
slice_sample(
  .data,
  ...,
  n = NULL,
  prop = NULL,
  by = NULL,
  weight_by = NULL,
  replace = FALSE,
  seed = NULL,
  .if_missing_var = NULL
)
```

## Arguments

- .data:

  A
  [`survey_base`](https://jdenn0514.github.io/surveycore/reference/survey_base.html)
  object, a `survey_result` object returned by a surveycore estimation
  function, or a
  [`survey_collection`](https://jdenn0514.github.io/surveycore/reference/survey_collection.html).

- ...:

  Passed to the corresponding `dplyr::slice_*()` function. For `slice()`
  only, the `...` accepts a vector of row indices.

- .by:

  Accepted for interface compatibility; not used by survey methods.

- .preserve:

  Accepted for interface compatibility; not used by survey methods.

- n:

  Number of rows to keep. See
  [`dplyr::slice_head()`](https://dplyr.tidyverse.org/reference/slice.html).

- prop:

  Fraction of rows to keep (between 0 and 1). See
  [`dplyr::slice_head()`](https://dplyr.tidyverse.org/reference/slice.html).

- order_by:

  \<[`data-masking`](https://rlang.r-lib.org/reference/args_data_masking.html)\>
  Variable to order by, used by
  [`slice_min()`](https://dplyr.tidyverse.org/reference/slice.html) and
  [`slice_max()`](https://dplyr.tidyverse.org/reference/slice.html). See
  [`dplyr::slice_min()`](https://dplyr.tidyverse.org/reference/slice.html).

- by:

  Per-call grouping override accepted by
  [`slice_min()`](https://dplyr.tidyverse.org/reference/slice.html),
  [`slice_max()`](https://dplyr.tidyverse.org/reference/slice.html), and
  [`slice_sample()`](https://dplyr.tidyverse.org/reference/slice.html).
  Not supported on `survey_collection` — passing a non-NULL value raises
  `surveytidy_error_collection_by_unsupported`. Use
  [`group_by()`](https://jdenn0514.github.io/surveytidy/reference/group_by.md)
  on the collection (or set `coll@groups`) instead.

- with_ties:

  Should ties be kept together? Used by
  [`slice_min()`](https://dplyr.tidyverse.org/reference/slice.html) and
  [`slice_max()`](https://dplyr.tidyverse.org/reference/slice.html). See
  [`dplyr::slice_min()`](https://dplyr.tidyverse.org/reference/slice.html).

- na_rm:

  Should missing values in `order_by` be removed before slicing? Used by
  [`slice_min()`](https://dplyr.tidyverse.org/reference/slice.html) and
  [`slice_max()`](https://dplyr.tidyverse.org/reference/slice.html). See
  [`dplyr::slice_min()`](https://dplyr.tidyverse.org/reference/slice.html).

- .if_missing_var:

  Per-call override of `collection@if_missing_var`. One of `"error"` or
  `"skip"`, or `NULL` (the default) to inherit the collection's stored
  value. See
  [`surveycore::set_collection_if_missing_var()`](https://jdenn0514.github.io/surveycore/reference/set_collection_if_missing_var.html).

- weight_by:

  \<[`data-masking`](https://rlang.r-lib.org/reference/args_data_masking.html)\>
  Sampling weights for
  [`slice_sample()`](https://dplyr.tidyverse.org/reference/slice.html).
  See
  [`dplyr::slice_sample()`](https://dplyr.tidyverse.org/reference/slice.html).
  Independent of the survey design weights — issues
  `surveytidy_warning_slice_sample_weight_by` as a reminder.

- replace:

  Should sampling be performed with replacement? Used by
  [`slice_sample()`](https://dplyr.tidyverse.org/reference/slice.html).
  See
  [`dplyr::slice_sample()`](https://dplyr.tidyverse.org/reference/slice.html).

- seed:

  Used by `slice_sample.survey_collection` only. `NULL` (the default)
  leaves the ambient RNG state alone; an integer seed makes per-survey
  samples deterministic and order-independent (see "Survey collections"
  below).

## Value

An object of the same type as `.data` with the following properties:

- A subset of rows is retained; unselected rows are permanently removed.

- Columns and survey design attributes are unchanged.

- Always issues `surveycore_warning_physical_subset`.

## Details

### Physical subsetting

Unlike
[`filter()`](https://jdenn0514.github.io/surveytidy/reference/filter.md),
slice functions actually remove rows. This changes the survey design —
unless the design was explicitly built for the subset population,
variance estimates may be incorrect.

### [`slice_sample()`](https://dplyr.tidyverse.org/reference/slice.html) and survey weights

`slice_sample(weight_by = )` samples rows proportional to a column's
values, independently of the survey design weights. A
`surveytidy_warning_slice_sample_weight_by` warning is issued as a
reminder. If you intend probability-proportional sampling, use the
design weights directly.

## Survey collections

Slice variants are dispatched to each member independently. Each
member's `slice_*.survey_base` call emits
`surveycore_warning_physical_subset` — an N-member collection therefore
surfaces N warnings.

Before dispatching, a verb-specific pre-flight raises
`surveytidy_error_collection_slice_zero` when the supplied arguments
would produce a 0-row result on every member (e.g., `n = 0`, literal
`slice(integer(0))`). This stops dispatch before any member is touched,
so users see a slice-specific message instead of a misleading per-member
validator failure.

`slice`, `slice_head`, `slice_tail`, and `slice_sample` (when
`weight_by = NULL`) reference no user columns — their signatures omit
`.if_missing_var`. `slice_min`, `slice_max`, and `slice_sample` with a
non-NULL `weight_by` do reference user columns; their signatures include
`.if_missing_var`.

`slice_min`, `slice_max`, and `slice_sample` reject the per-call `by`
argument with `surveytidy_error_collection_by_unsupported`; use
[`group_by()`](https://jdenn0514.github.io/surveytidy/reference/group_by.md)
on the collection (or `coll@groups`) instead.

## `slice_sample.survey_collection` reproducibility

`slice_sample.survey_collection` adds a `seed = NULL` argument absent
from `slice_sample.survey_base`.

- `seed = NULL` (default): no seed manipulation. Per-survey
  [`slice_sample()`](https://dplyr.tidyverse.org/reference/slice.html)
  calls draw from the ambient RNG state in iteration order.
  Reproducibility requires a single upstream
  [`set.seed()`](https://rdrr.io/r/base/Random.html) AND a stable
  collection size and member order — adding or removing a survey changes
  the samples drawn from every subsequent survey.

- `seed = <integer>`: each per-survey call is wrapped with a
  deterministic per-survey seed derived as
  `strtoi(substr(rlang::hash(paste0(survey_name, "::", seed)), 1, 7), 16L)`.
  Per-survey samples are stable regardless of collection order,
  additions, or removals. The ambient `.Random.seed` is restored on
  exit.

For any analysis intended to be reproducible, pass an explicit integer
`seed`.

## See also

[`filter()`](https://jdenn0514.github.io/surveytidy/reference/filter.md)
for domain-aware row marking (preferred for subpopulation analyses),
[`arrange()`](https://jdenn0514.github.io/surveytidy/reference/arrange.md)
for row sorting

Other row operations:
[`distinct`](https://jdenn0514.github.io/surveytidy/reference/distinct.md),
[`drop_na`](https://jdenn0514.github.io/surveytidy/reference/drop_na.md)

## Examples

``` r
# create a survey object from the bundled NPORS dataset
d <- surveycore::as_survey(
  surveycore::pew_npors_2025,
  weights = weight,
  strata = stratum
)

# first 10 rows (issues a physical subset warning)
slice_head(d, n = 10)
#> Warning: ! `slice_head()` physically removes rows from the survey data.
#> ℹ This is different from `filter()`, which preserves all rows for correct
#>   variance estimation.
#> ✔ Use `filter()` for subpopulation analyses instead.
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 10
#> 
#> # A tibble: 10 × 65
#>    respid  mode language languageinitial stratum interview_start interview_end
#>     <dbl> <dbl>    <dbl>           <dbl>   <dbl> <date>          <date>       
#>  1   1470     2        1              NA      10 2025-05-27      2025-05-27   
#>  2   2374     2        1              NA       7 2025-05-01      2025-05-01   
#>  3   1177     3        1              10       5 2025-03-04      2025-03-04   
#>  4  15459     2        1              NA      10 2025-05-05      2025-05-05   
#>  5   9849     1        1               9       9 2025-02-22      2025-02-22   
#>  6   8178     3        1               9      10 2025-03-10      2025-03-10   
#>  7   3682     1        1               9       4 2025-02-27      2025-02-27   
#>  8   6999     2        1              NA      10 2025-05-12      2025-05-12   
#>  9   9945     2        1              NA      10 2025-05-09      2025-05-09   
#> 10   1901     1        1               9      10 2025-03-01      2025-03-01   
#> # ℹ 58 more variables: econ1mod <dbl>, econ1bmod <dbl>, comtype2 <dbl>,
#> #   unity <dbl>, crimesafe <dbl>, govprotct <dbl>, moregunimpact <dbl>,
#> #   fin_sit <dbl>, vet1 <dbl>, vol12_cps <dbl>, eminuse <dbl>, intmob <dbl>,
#> #   intfreq <dbl>, intfreq_collapsed <dbl>, home4nw2 <dbl>, bbhome <dbl>,
#> #   smuse_fb <dbl>, smuse_yt <dbl>, smuse_x <dbl>, smuse_ig <dbl>,
#> #   smuse_sc <dbl>, smuse_wa <dbl>, smuse_tt <dbl>, smuse_rd <dbl>,
#> #   smuse_bsk <dbl>, smuse_th <dbl>, smuse_ts <dbl>, radio <dbl>, …

# rows with the 5 lowest survey weights
slice_min(d, order_by = weight, n = 5)
#> Warning: ! `slice_min()` physically removes rows from the survey data.
#> ℹ This is different from `filter()`, which preserves all rows for correct
#>   variance estimation.
#> ✔ Use `filter()` for subpopulation analyses instead.
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 51
#> 
#> # A tibble: 51 × 65
#>    respid  mode language languageinitial stratum interview_start interview_end
#>     <dbl> <dbl>    <dbl>           <dbl>   <dbl> <date>          <date>       
#>  1   3716     1        1               9       1 2025-02-25      2025-02-25   
#>  2     80     1        1               9       1 2025-03-12      2025-03-12   
#>  3  13195     1        1               9       7 2025-02-24      2025-02-24   
#>  4  12549     1        1               9       9 2025-03-30      2025-03-30   
#>  5  18538     1        1               9       8 2025-03-06      2025-03-06   
#>  6  12391     2        1              NA       7 2025-05-05      2025-05-05   
#>  7   2656     1        1               9       1 2025-03-08      2025-03-08   
#>  8   5702     1        1               9       1 2025-03-10      2025-03-10   
#>  9   7131     1        1               9       2 2025-03-04      2025-03-04   
#> 10   6278     1        1               9       7 2025-03-01      2025-03-01   
#> # ℹ 41 more rows
#> # ℹ 58 more variables: econ1mod <dbl>, econ1bmod <dbl>, comtype2 <dbl>,
#> #   unity <dbl>, crimesafe <dbl>, govprotct <dbl>, moregunimpact <dbl>,
#> #   fin_sit <dbl>, vet1 <dbl>, vol12_cps <dbl>, eminuse <dbl>, intmob <dbl>,
#> #   intfreq <dbl>, intfreq_collapsed <dbl>, home4nw2 <dbl>, bbhome <dbl>,
#> #   smuse_fb <dbl>, smuse_yt <dbl>, smuse_x <dbl>, smuse_ig <dbl>,
#> #   smuse_sc <dbl>, smuse_wa <dbl>, smuse_tt <dbl>, smuse_rd <dbl>, …

# random sample of 50 rows
slice_sample(d, n = 50)
#> Warning: ! `slice_sample()` physically removes rows from the survey data.
#> ℹ This is different from `filter()`, which preserves all rows for correct
#>   variance estimation.
#> ✔ Use `filter()` for subpopulation analyses instead.
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 50
#> 
#> # A tibble: 50 × 65
#>    respid  mode language languageinitial stratum interview_start interview_end
#>     <dbl> <dbl>    <dbl>           <dbl>   <dbl> <date>          <date>       
#>  1  18518     2        1              NA       7 2025-05-02      2025-05-02   
#>  2   8073     2        1              NA      10 2025-05-06      2025-05-06   
#>  3    447     1        1               9      10 2025-03-02      2025-03-02   
#>  4   4799     3        1               9      10 2025-03-13      2025-03-13   
#>  5  11051     1        1               9      10 2025-02-22      2025-02-22   
#>  6  16872     1        1               9       9 2025-03-09      2025-03-09   
#>  7   9470     2        1              NA      10 2025-05-12      2025-05-12   
#>  8    884     1        1               9       7 2025-03-22      2025-03-22   
#>  9  16750     1        1               9      10 2025-02-27      2025-02-27   
#> 10  16852     1        1               9       2 2025-03-01      2025-03-01   
#> # ℹ 40 more rows
#> # ℹ 58 more variables: econ1mod <dbl>, econ1bmod <dbl>, comtype2 <dbl>,
#> #   unity <dbl>, crimesafe <dbl>, govprotct <dbl>, moregunimpact <dbl>,
#> #   fin_sit <dbl>, vet1 <dbl>, vol12_cps <dbl>, eminuse <dbl>, intmob <dbl>,
#> #   intfreq <dbl>, intfreq_collapsed <dbl>, home4nw2 <dbl>, bbhome <dbl>,
#> #   smuse_fb <dbl>, smuse_yt <dbl>, smuse_x <dbl>, smuse_ig <dbl>,
#> #   smuse_sc <dbl>, smuse_wa <dbl>, smuse_tt <dbl>, smuse_rd <dbl>, …
```
