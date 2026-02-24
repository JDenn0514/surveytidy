# Package index

## Data frame verbs

### Rows

[`filter()`](https://dplyr.tidyverse.org/reference/filter.html),
[`filter_out()`](https://dplyr.tidyverse.org/reference/filter.html), and
[`drop_na()`](https://tidyr.tidyverse.org/reference/drop_na.html) use
**domain estimation** — rows are marked in or out of the analysis domain
without being removed, so variance estimates stay correct. Physical row
removal ([`subset()`](https://rdrr.io/r/base/subset.html), `slice_*()`)
is also available but issues a warning because removing rows can bias
variance estimates.

- [`filter.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/filter.survey_base.md)
  [`filter_out.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/filter.survey_base.md)
  : Keep or drop rows using domain estimation
- [`distinct.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/distinct.survey_base.md)
  : Remove duplicate rows from a survey design object
- [`drop_na.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/drop_na.survey_base.md)
  : Mark rows with missing values as out-of-domain
- [`arrange.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/arrange.survey_base.md)
  : Order rows using column values
- [`slice.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/slice.survey_base.md)
  [`slice_head.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/slice.survey_base.md)
  [`slice_tail.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/slice.survey_base.md)
  [`slice_min.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/slice.survey_base.md)
  [`slice_max.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/slice.survey_base.md)
  [`slice_sample.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/slice.survey_base.md)
  : Physically select rows of a survey design object
- [`subset(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/subset.survey_base.md)
  : Physically remove rows from a survey design object

### Columns

Select, reorder, rename, create, extract, and inspect columns. Design
variables (weights, strata, PSU, FPC) are always retained even when not
explicitly selected.
[`rename()`](https://dplyr.tidyverse.org/reference/rename.html)
automatically updates the survey design specification and variable
metadata to match the new name.

- [`select.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/select.survey_base.md)
  : Keep or drop columns using their names and types
- [`relocate.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/relocate.survey_base.md)
  : Change column order in a survey design object
- [`rename.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/rename.survey_base.md)
  [`rename_with.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/rename.survey_base.md)
  : Rename columns of a survey design object
- [`mutate.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/mutate.survey_base.md)
  : Create, modify, and delete columns of a survey design object
- [`pull.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/pull.survey_base.md)
  : Extract a column from a survey design object
- [`glimpse.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/glimpse.survey_base.md)
  : Get a glimpse of a survey design object

### Groups

[`group_by()`](https://dplyr.tidyverse.org/reference/group_by.html)
stores grouping columns on the survey object for use by grouped
operations like
[`mutate()`](https://dplyr.tidyverse.org/reference/mutate.html).
[`rowwise()`](https://dplyr.tidyverse.org/reference/rowwise.html)
enables row-by-row computation. Unlike dplyr, the underlying data is not
modified — groups are stored on the survey object and applied when
needed.

- [`group_by.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/group_by.survey_base.md)
  [`ungroup.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/group_by.survey_base.md)
  : Group and ungroup a survey design object
- [`rowwise.survey_base()`](https://jdenn0514.github.io/surveytidy/reference/rowwise.survey_base.md)
  : Compute row-wise on a survey design object

### Predicates

Test the current grouping and rowwise state of a survey design object.
These predicates are designed for use by estimation functions in Phase
1.

- [`is_rowwise()`](https://jdenn0514.github.io/surveytidy/reference/is_rowwise.md)
  : Test whether a survey design is in rowwise mode
- [`is_grouped()`](https://jdenn0514.github.io/surveytidy/reference/is_grouped.md)
  : Test whether a survey design has active grouping
