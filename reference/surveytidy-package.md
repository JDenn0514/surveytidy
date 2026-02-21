# surveytidy: Tidy dplyr/tidyr Verbs for Survey Design Objects

Provides dplyr and tidyr verbs for survey design objects created with
the `surveycore` package. The key statistical feature is **domain-aware
filtering**:
[`filter()`](https://dplyr.tidyverse.org/reference/filter.html) marks
rows as in-domain rather than removing them, which is essential for
correct variance estimation of subpopulation statistics.

## Details

### Key verbs

- [`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html)
  — domain estimation (marks rows, never removes them)

- [`dplyr::select()`](https://dplyr.tidyverse.org/reference/select.html)
  — column selection preserving design variables

- [`dplyr::mutate()`](https://dplyr.tidyverse.org/reference/mutate.html)
  — add/modify columns with weight-change warnings

- [`dplyr::rename()`](https://dplyr.tidyverse.org/reference/rename.html)
  — auto-updates design variable names and metadata

- [`dplyr::group_by()`](https://dplyr.tidyverse.org/reference/group_by.html)
  /
  [`dplyr::ungroup()`](https://dplyr.tidyverse.org/reference/group_by.html)
  — grouped analysis support

- [`dplyr::arrange()`](https://dplyr.tidyverse.org/reference/arrange.html)
  — row sorting preserving domain membership

- [`subset()`](https://rdrr.io/r/base/subset.html) — physical row
  removal with a strong warning

### Domain estimation vs. physical subsetting

[`filter()`](https://dplyr.tidyverse.org/reference/filter.html) and
[`subset()`](https://rdrr.io/r/base/subset.html) have fundamentally
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

**Maintainer**: Jacob Dennen <jacob.dennen@example.com>
