# docs/cleanup — Standardise roxygen across all verb documentation

| Field | Value |
|-------|-------|
| **Package** | surveytidy |
| **Phase** | 0.5 |
| **Branch** | docs/cleanup |
| **PR** | TBD |
| **Date** | 2026-02-23 |

## Executive Summary

Standardised roxygen documentation across all user-facing verb files to mirror
the dplyr/tidyr reference style. Every function now has a user-facing
description (not implementation notes), named `@details` subsections for
surveytidy-specific behaviour, a properties bullet list for `@return`, linked
`@param .data` / `@param x` to `survey_base`, and examples that use
`nhanes_2017` with `library(surveytidy)` + `library(surveycore)` instead of
toy datasets and `library(dplyr)`.

---

## Commits

### `docs: mirror dplyr reference style for arrange, filter, select`

**Purpose:** First pass of documentation standardisation covering the three
earliest verb files.

**Key changes:**
- `R/filter.R`: description rewritten to lead with domain-awareness concept;
  `@details` sections for Chaining, Missing values, Useful filter functions,
  and Inspecting the domain; properties `@return`; nhanes_2017 examples with
  `if_any()`/`if_all()` usage; `filter_out()` switched to `@rdname`
- `R/select.R` (select): design variable preservation and metadata sections;
  nhanes_2017 examples with `dplyr::starts_with()` and `dplyr::where()`
- `R/arrange.R`: Missing values and Domain column `@details` sections;
  nhanes_2017 examples with `dplyr::desc()`; linked `@param .data`

---

### `docs: update roxygen for mutate, rename, relocate, pull, glimpse, group_by, slice, drop_na`

**Purpose:** Second pass covering all remaining verb files.

**Key changes:**
- `R/mutate.R`: description rewritten; `@details` sections for design variable
  modification, `.keep` behaviour, grouped mutate, and useful functions;
  nhanes_2017 examples with `dplyr::if_else()`
- `R/rename.R`: description rewritten; `@details` sections for "What gets
  updated" and "Renaming design variables"; nhanes_2017 examples
- `R/select.R` (relocate): description rewritten; `@details` sections for
  design variable positions and post-`select()` behaviour; nhanes_2017 examples
- `R/select.R` (pull): `@param var` expanded with positional integer docs;
  `@return` clarified; nhanes_2017 examples with named vector example
- `R/select.R` (glimpse): description rewritten to reference `select()` rather
  than internals; nhanes_2017 pipeline example
- `R/group-by.R`: description rewritten; `@details` sections for grouped
  operations, adding groups, and partial ungroup; `@describeIn` switched to
  `@rdname`; nhanes_2017 examples with `.add = TRUE` and partial ungroup
- `R/slice.R`: description rewritten with filter() recommendation; `@details`
  sections for physical subsetting and `weight_by` warning; nhanes_2017
  examples without `suppressWarnings()`
- `R/drop-na.R`: description rewritten to contrast with tidyr's `drop_na()`;
  chaining `@details` section with code comparison; nhanes_2017 examples

---

### `docs(arrange): trim internal detail from @param .by_group`

**Purpose:** Remove reference to `@groups` internal storage from the
`.by_group` param description, consistent with how other verbs document
grouping behaviour.

**Key changes:**
- `R/arrange.R`: `@param .by_group` trimmed to one sentence
