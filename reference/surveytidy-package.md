# surveytidy: Tidy dplyr/tidyr Verbs for Survey Design Objects

Provides dplyr and tidyr verbs for survey design objects created with
the `surveycore` package. The key statistical feature is **domain-aware
filtering**:
[`filter()`](https://jdenn0514.github.io/surveytidy/reference/filter.md)
marks rows as in-domain rather than removing them, which is essential
for correct variance estimation of subpopulation statistics.

## Details

### Key verbs

- [`filter()`](https://jdenn0514.github.io/surveytidy/reference/filter.md)
  — domain estimation (marks rows, never removes them)

- [`select()`](https://jdenn0514.github.io/surveytidy/reference/select.md)
  — column selection preserving design variables

- [`mutate()`](https://jdenn0514.github.io/surveytidy/reference/mutate.md)
  — add/modify columns with weight-change warnings

- [`rename()`](https://jdenn0514.github.io/surveytidy/reference/rename.md)
  — auto-updates design variable names and metadata

- [`group_by()`](https://jdenn0514.github.io/surveytidy/reference/group_by.md)
  / [`ungroup()`](https://dplyr.tidyverse.org/reference/group_by.html) —
  grouped analysis support

- [`arrange()`](https://jdenn0514.github.io/surveytidy/reference/arrange.md)
  — row sorting preserving domain membership

- [`subset()`](https://rdrr.io/r/base/subset.html) — physical row
  removal with a strong warning

### Domain estimation vs. physical subsetting

[`filter()`](https://jdenn0514.github.io/surveytidy/reference/filter.md)
and [`subset()`](https://rdrr.io/r/base/subset.html) have fundamentally
different statistical meanings:

- `filter(.data, condition)` — sets `..surveycore_domain..` to `TRUE`
  for matching rows. All rows are retained. Variance estimation
  correctly uses the full design.

- `subset(.data, condition)` — physically removes non-matching rows.
  Variance estimates will be biased unless the design was explicitly
  built for the subset. Use only when you understand the statistical
  implications.

## See also

Useful links:

- <https://jdenn0514.github.io/surveytidy/>

- <https://github.com/JDenn0514/surveytidy>

- Report bugs at <https://github.com/JDenn0514/surveytidy/issues>

## Author

**Maintainer**: Jacob Dennen <jdenn0514@gmail.com>
([ORCID](https://orcid.org/0000-0003-3006-7364)) \[copyright holder\]
