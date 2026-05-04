# Package index

## Data frame verbs

### Rows

[`filter()`](https://jdenn0514.github.io/surveytidy/reference/filter.md),
[`filter_out()`](https://dplyr.tidyverse.org/reference/filter.html), and
[`drop_na()`](https://jdenn0514.github.io/surveytidy/reference/drop_na.md)
use **domain estimation** — rows are marked in or out of the analysis
domain without being removed, so variance estimates stay correct.
Physical row removal ([`subset()`](https://rdrr.io/r/base/subset.html),
`slice_*()`) is also available but issues a warning because removing
rows can bias variance estimates.

- [`filter_out(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/filter.md)
  [`filter_out(`*`<survey_collection>`*`)`](https://jdenn0514.github.io/surveytidy/reference/filter.md)
  [`filter()`](https://jdenn0514.github.io/surveytidy/reference/filter.md)
  : Keep or drop rows using domain estimation
- [`distinct()`](https://jdenn0514.github.io/surveytidy/reference/distinct.md)
  : Remove duplicate rows from a survey design object
- [`drop_na()`](https://jdenn0514.github.io/surveytidy/reference/drop_na.md)
  : Mark rows with missing values as out-of-domain
- [`arrange()`](https://jdenn0514.github.io/surveytidy/reference/arrange.md)
  : Order rows using column values
- [`slice()`](https://jdenn0514.github.io/surveytidy/reference/slice.md)
  [`slice_head(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/slice.md)
  [`slice_tail(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/slice.md)
  [`slice_min(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/slice.md)
  [`slice_max(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/slice.md)
  [`slice_sample(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/slice.md)
  [`slice_head(`*`<survey_result>`*`)`](https://jdenn0514.github.io/surveytidy/reference/slice.md)
  [`slice_tail(`*`<survey_result>`*`)`](https://jdenn0514.github.io/surveytidy/reference/slice.md)
  [`slice_min(`*`<survey_result>`*`)`](https://jdenn0514.github.io/surveytidy/reference/slice.md)
  [`slice_max(`*`<survey_result>`*`)`](https://jdenn0514.github.io/surveytidy/reference/slice.md)
  [`slice_sample(`*`<survey_result>`*`)`](https://jdenn0514.github.io/surveytidy/reference/slice.md)
  [`slice_head(`*`<survey_collection>`*`)`](https://jdenn0514.github.io/surveytidy/reference/slice.md)
  [`slice_tail(`*`<survey_collection>`*`)`](https://jdenn0514.github.io/surveytidy/reference/slice.md)
  [`slice_min(`*`<survey_collection>`*`)`](https://jdenn0514.github.io/surveytidy/reference/slice.md)
  [`slice_max(`*`<survey_collection>`*`)`](https://jdenn0514.github.io/surveytidy/reference/slice.md)
  [`slice_sample(`*`<survey_collection>`*`)`](https://jdenn0514.github.io/surveytidy/reference/slice.md)
  : Physically select rows of a survey design object
- [`subset(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/subset.survey_base.md)
  : Physically remove rows from a survey design object

### Columns

Select, reorder, rename, create, extract, and inspect columns. Design
variables (weights, strata, PSU, FPC) are always retained even when not
explicitly selected.
[`rename()`](https://jdenn0514.github.io/surveytidy/reference/rename.md)
automatically updates the survey design specification and variable
metadata to match the new name.

- [`select()`](https://jdenn0514.github.io/surveytidy/reference/select.md)
  : Keep or drop columns using their names and types
- [`relocate()`](https://jdenn0514.github.io/surveytidy/reference/relocate.md)
  : Change column order in a survey design object
- [`rename()`](https://jdenn0514.github.io/surveytidy/reference/rename.md)
  [`rename_with(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/rename.md)
  [`rename_with(`*`<survey_result>`*`)`](https://jdenn0514.github.io/surveytidy/reference/rename.md)
  [`rename_with(`*`<survey_collection>`*`)`](https://jdenn0514.github.io/surveytidy/reference/rename.md)
  : Rename columns of a survey design object
- [`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md)
  : Create, modify, and delete columns of a survey design object
- [`pull()`](https://jdenn0514.github.io/surveytidy/reference/pull.md) :
  Extract a column from a survey design object
- [`glimpse()`](https://jdenn0514.github.io/surveytidy/reference/glimpse.md)
  : Get a glimpse of a survey design object

### Groups

[`group_by()`](https://jdenn0514.github.io/surveytidy/reference/group_by.md)
stores grouping columns on the survey object for use by grouped
operations like
[`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md).
[`rowwise()`](https://jdenn0514.github.io/surveytidy/reference/rowwise.md)
enables row-by-row computation. Unlike dplyr, the underlying data is not
modified — groups are stored on the survey object and applied when
needed.

- [`ungroup(`*`<survey_base>`*`)`](https://jdenn0514.github.io/surveytidy/reference/group_by.md)
  [`ungroup(`*`<survey_collection>`*`)`](https://jdenn0514.github.io/surveytidy/reference/group_by.md)
  [`group_by()`](https://jdenn0514.github.io/surveytidy/reference/group_by.md)
  : Group and ungroup a survey design object
- [`rowwise()`](https://jdenn0514.github.io/surveytidy/reference/rowwise.md)
  : Compute row-wise on a survey design object

### Joins

Join a survey design object with a plain data frame.
[`left_join()`](https://jdenn0514.github.io/surveytidy/reference/left_join.md)
adds lookup columns without changing row count.
[`semi_join()`](https://jdenn0514.github.io/surveytidy/reference/semi_join.md)
and
[`anti_join()`](https://jdenn0514.github.io/surveytidy/reference/semi_join.md)
are domain-aware: unmatched rows are marked out-of-domain rather than
removed, preserving variance estimation validity.
[`inner_join()`](https://jdenn0514.github.io/surveytidy/reference/inner_join.md)
defaults to domain-aware mode and supports an explicit
`.domain_aware = FALSE` for physical row removal.
[`right_join()`](https://jdenn0514.github.io/surveytidy/reference/right_join.md),
[`full_join()`](https://jdenn0514.github.io/surveytidy/reference/right_join.md),
and
[`bind_rows()`](https://jdenn0514.github.io/surveytidy/reference/bind_rows.md)
always error — they would add rows with missing design variables.

- [`left_join()`](https://jdenn0514.github.io/surveytidy/reference/left_join.md)
  : Add columns from a data frame to a survey design
- [`semi_join()`](https://jdenn0514.github.io/surveytidy/reference/semi_join.md)
  [`anti_join()`](https://jdenn0514.github.io/surveytidy/reference/semi_join.md)
  : Domain-aware semi- and anti-join for survey designs
- [`inner_join()`](https://jdenn0514.github.io/surveytidy/reference/inner_join.md)
  : Domain-aware inner join for survey designs
- [`bind_cols()`](https://jdenn0514.github.io/surveytidy/reference/bind_cols.md)
  : Append columns to a survey design by position
- [`right_join()`](https://jdenn0514.github.io/surveytidy/reference/right_join.md)
  [`full_join()`](https://jdenn0514.github.io/surveytidy/reference/right_join.md)
  : Unsupported joins for survey designs
- [`bind_rows()`](https://jdenn0514.github.io/surveytidy/reference/bind_rows.md)
  : Stack surveys with bind_rows (errors unconditionally)

### Predicates

Test the current grouping and rowwise state of a survey design object.
These predicates are designed for use by estimation functions in Phase
1.

- [`is_rowwise()`](https://jdenn0514.github.io/surveytidy/reference/is_rowwise.md)
  : Test whether a survey design is in rowwise mode
- [`is_grouped()`](https://jdenn0514.github.io/surveytidy/reference/is_grouped.md)
  : Test whether a survey design has active grouping

## Recoding

Survey-aware versions of dplyr’s recoding and conditional functions.
When called with `.label`, `.value_labels`, `.factor`, or
`.description`, these functions automatically propagate label metadata
into `@metadata` via
[`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md).
When called without these arguments, the output is identical to the
corresponding dplyr function.

- [`case_when()`](https://jdenn0514.github.io/surveytidy/reference/case_when.md)
  : A generalised vectorised if-else

- [`replace_when()`](https://jdenn0514.github.io/surveytidy/reference/replace_when.md)
  : Partially update a vector using conditional formulas

- [`if_else()`](https://jdenn0514.github.io/surveytidy/reference/if_else.md)
  : Vectorised if-else

- [`na_if()`](https://jdenn0514.github.io/surveytidy/reference/na_if.md)
  :

  Convert values to `NA`

- [`recode_values()`](https://jdenn0514.github.io/surveytidy/reference/recode_values.md)
  : Recode values using an explicit mapping

- [`replace_values()`](https://jdenn0514.github.io/surveytidy/reference/replace_values.md)
  : Partially update values using an explicit mapping

## Transformation

Vector-level transformation functions for common survey variable
operations. These functions operate on plain R vectors and integrate
with
[`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md)
via the `surveytidy_recode` attribute protocol, automatically recording
transformation metadata in `@metadata@transformations`.

- [`make_factor()`](https://jdenn0514.github.io/surveytidy/reference/make_factor.md)
  : Convert a vector to a factor using value labels
- [`make_dicho()`](https://jdenn0514.github.io/surveytidy/reference/make_dicho.md)
  : Collapse a multi-level factor to two levels
- [`make_binary()`](https://jdenn0514.github.io/surveytidy/reference/make_binary.md)
  : Convert a dichotomous variable to a numeric 0/1 indicator
- [`make_rev()`](https://jdenn0514.github.io/surveytidy/reference/make_rev.md)
  : Reverse the numeric values of a scale variable
- [`make_flip()`](https://jdenn0514.github.io/surveytidy/reference/make_flip.md)
  : Flip the semantic valence of a variable
- [`row_means()`](https://jdenn0514.github.io/surveytidy/reference/row_means.md)
  : Compute row-wise means across selected columns
- [`row_sums()`](https://jdenn0514.github.io/surveytidy/reference/row_sums.md)
  : Compute row-wise sums across selected columns
