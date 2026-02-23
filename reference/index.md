# Package index

## Data frame verbs

### Rows

[`filter()`](https://dplyr.tidyverse.org/reference/filter.html) and
[`filter_out()`](https://dplyr.tidyverse.org/reference/filter.html) use
**domain estimation** — rows are marked in or out of the analysis domain
without being removed, so variance estimates stay correct. Physical row
removal ([`subset()`](https://rdrr.io/r/base/subset.html), `slice_*()`,
`drop_na()`) is available but issues a warning because removing rows can
bias variance estimates.

- [`filter(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/filter.survey_base.md)
  [`subset(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/filter.survey_base.md)
  : Filter survey data using domain estimation
- [`filter_out(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/filter_out.survey_base.md)
  : Exclude rows from a survey domain
- [`slice(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/slice.survey_base.md)
  [`slice_head(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/slice.survey_base.md)
  [`slice_tail(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/slice.survey_base.md)
  [`slice_min(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/slice.survey_base.md)
  [`slice_max(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/slice.survey_base.md)
  [`slice_sample(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/slice.survey_base.md)
  : Physically select rows of a survey design object
- [`arrange(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/arrange.survey_base.md)
  : Sort rows of a survey design object
- [`drop_na(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/drop_na.survey_base.md)
  : Mark rows with missing values as out-of-domain in a survey design
  object

### Columns

Select, reorder, rename, create, extract, and inspect columns. Design
variables (weights, strata, PSU, FPC) are always retained in `@data`
even when not explicitly selected.
[`rename()`](https://dplyr.tidyverse.org/reference/rename.html)
automatically updates the survey design specification and variable
metadata to match the new name.

- [`select(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/select.survey_base.md)
  [`relocate(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/select.survey_base.md)
  [`pull(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/select.survey_base.md)
  [`glimpse(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/select.survey_base.md)
  : Select, relocate, pull, and glimpse columns of a survey design
  object
- [`rename(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/rename.survey_base.md)
  : Rename columns of a survey design object
- [`mutate(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/mutate.survey_base.md)
  : Add or modify columns of a survey design object

### Groups

[`group_by()`](https://dplyr.tidyverse.org/reference/group_by.html)
stores grouping variables in `@groups` for use by estimation functions
(Phase 1+). Unlike dplyr, no `grouped_df` attribute is added to `@data`
— grouping lives on the survey object itself.

- [`group_by(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/group_by.survey_base.md)
  [`ungroup(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/group_by.survey_base.md)
  : Group and ungroup a survey design object
