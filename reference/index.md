# Package index

## Filtering and subsetting

[`filter()`](https://rdrr.io/r/stats/filter.html) uses domain estimation
— it marks rows as in-domain without removing them, preserving correct
variance estimation. Physical row removal is available via
[`subset()`](https://rdrr.io/r/base/subset.html), `slice_*()`, and
`drop_na()` with appropriate warnings.

- [`filter(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/filter.survey_base.md)
  [`subset(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/filter.survey_base.md)
  : Filter survey data using domain estimation

## Column selection

Select, reorder, extract, and inspect columns. Design variables
(weights, strata, PSU, FPC) are always retained in `@data` even when not
explicitly selected.

- [`select(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/select.survey_base.md)
  [`relocate(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/select.survey_base.md)
  [`pull(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/select.survey_base.md)
  [`glimpse(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/select.survey_base.md)
  : Select, relocate, pull, and glimpse columns of a survey design
  object

## Modifying columns

Add or modify columns (`mutate()`) and rename them (`rename()`). Both
verbs keep the survey design specification and metadata in sync.

- [`mutate(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/mutate.survey_base.md)
  : Add or modify columns of a survey design object
- [`rename(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/rename.survey_base.md)
  : Rename columns of a survey design object

## Row ordering and physical selection

Sort rows with `arrange()`. The `slice_*()` family physically removes
rows — use [`filter()`](https://rdrr.io/r/stats/filter.html) instead for
subpopulation analyses.

- [`arrange(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/arrange.survey_base.md)
  [`slice(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/arrange.survey_base.md)
  [`slice_head(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/arrange.survey_base.md)
  [`slice_tail(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/arrange.survey_base.md)
  [`slice_min(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/arrange.survey_base.md)
  [`slice_max(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/arrange.survey_base.md)
  [`slice_sample(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/arrange.survey_base.md)
  : Sort rows and physically select rows of a survey design object

## Grouping

Store grouping variables in `@groups` for use by estimation functions
and grouped `mutate()`. No `grouped_df` attribute is added to `@data`.

- [`group_by(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/group_by.survey_base.md)
  [`ungroup(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/group_by.survey_base.md)
  : Group and ungroup a survey design object

## Missing value removal

Physically remove rows with `NA` values. Issues a warning because
physical removal can bias variance estimates.

- [`drop_na(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/drop_na.survey_base.md)
  : Remove rows containing missing values from a survey design object
