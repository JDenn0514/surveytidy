# Add filter_out() — domain-aware row exclusion

| Field | Value |
|-------|-------|
| **Package** | surveytidy |
| **Phase** | 0.5 |
| **Branch** | feature/filter-out |
| **PR** | TBD |
| **Date** | 2026-02-23 |

## Executive Summary

`filter_out()` is the complement of `filter()`: instead of marking rows
as in-domain, it marks rows matching the condition as out-of-domain while
leaving all other rows in-domain. Like `filter()`, it never physically
removes rows, preserving the full design for correct variance estimation.

`filter_out()` is a real dplyr generic (added in dplyr 1.2.0) using
`UseMethod("filter_out")`. The implementation follows the same dispatch
pattern as all other surveytidy verbs — `filter_out.survey_base()` is
registered in `.onLoad()` via `registerS3method()` against dplyr's
namespace with the namespaced class string `"surveycore::survey_base"`.

NA handling matches dplyr's documented behaviour: `filter_out()` keeps
both `NA` and `FALSE` rows — a row with an `NA` condition result is
treated as "not excluded" and stays in-domain.

---

## Commits

### `feat(filter): add filter_out.survey_base() for domain exclusion`

**Purpose:** Provides a readable complement to `filter()` for exclusion
use-cases (`filter_out(d, group == "control")` is clearer than
`filter(d, group != "control")`). Chains correctly with `filter()` via
AND-accumulation on the domain column.

**Key changes:**
- `R/filter.R`: added `filter_out.survey_base()` with `.by`/`.preserve`
  params matching dplyr's generic signature; evaluates conditions, ANDs
  them, negates the result, ANDs with any existing domain column; errors
  with `surveytidy_error_filter_by_unsupported` on `.by`; errors with
  `surveytidy_error_filter_out_non_logical` on non-logical conditions;
  warns with `surveycore_warning_empty_domain` when all rows excluded
- `R/zzz.R`: registered `filter_out.survey_base` in `.onLoad()` via
  `registerS3method("filter_out", "surveycore::survey_base", ..., envir = asNamespace("dplyr"))`
- `R/surveytidy-package.R`: added `filter_out` to `@importFrom dplyr`
- `NAMESPACE`: regenerated to include `importFrom(dplyr, filter_out)`
- `tests/testthat/test-filter.R`: 18 new test blocks — happy path for
  all 3 design types, no-condition behaviour, multiple conditions,
  equivalence with `filter(!cond)`, chaining in both directions,
  NA-stays-in-domain, `@groups`/`@metadata` preservation, `.by` error,
  non-logical error, empty-domain warning
- `tests/testthat/_snaps/filter.md`: added snapshots for `.by` error,
  non-logical error, and empty-domain warning
