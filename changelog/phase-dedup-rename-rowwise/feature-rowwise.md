# feature/rowwise — rowwise.survey_base(), mutate() rowwise routing, group_by() fix, predicates

| Field | Value |
|-------|-------|
| **Package** | surveytidy |
| **Phase** | dedup-rename-rowwise |
| **Branch** | feature/rowwise |
| **PR** | TBD |
| **Date** | 2026-02-24 |

## Executive Summary

Adds `rowwise()` support for survey design objects. Rowwise mode enables
row-by-row computation in `mutate()` (e.g., `max(c_across(...))`). State is
stored in `@variables$rowwise` and `@variables$rowwise_id_cols` — never in
`@groups`, keeping those clean for estimation functions.

Also ships three exported predicates (`is_rowwise()`, `is_grouped()`,
`group_vars()`) for use by Phase 1 estimation functions, and updates
`group_by()` and `ungroup()` to properly exit rowwise mode.

---

## Commits

### `feat(rowwise): implement rowwise.survey_base(), predicates, mutate routing, and group_by/ungroup fixes`

**Purpose:** Deliver `rowwise.survey_base()` per spec §V, plus supporting
changes to `mutate()`, `group_by()`, and `ungroup()`.

**Key changes:**

- `R/rowwise.R` (new): `rowwise.survey_base()`, `is_rowwise()`, `is_grouped()`
  - `rowwise()` sets `@variables$rowwise = TRUE` and `@variables$rowwise_id_cols`
  - `@groups` is never modified by `rowwise()`
  - `is_rowwise()` exported — returns `TRUE` when `@variables$rowwise` is `TRUE`
  - `is_grouped()` exported — returns `TRUE` when `@groups` is non-empty

- `R/group-by.R` (modified):
  - Added `group_vars.survey_base()` — returns `@groups` directly (no sentinel)
  - `group_by(.add = FALSE)`: now also clears `@variables$rowwise` and
    `@variables$rowwise_id_cols` when exiting rowwise mode
  - `group_by(.add = TRUE)` when rowwise: promotes `@variables$rowwise_id_cols`
    to `@groups`, appends new groups, clears rowwise keys (mirrors dplyr)
  - `ungroup()` (full): now also clears `@variables$rowwise` and
    `@variables$rowwise_id_cols`
  - `ungroup()` (partial): rowwise keys NOT cleared (matches dplyr behaviour)

- `R/mutate.R` (modified):
  - Detects `@variables$rowwise` and routes to `dplyr::rowwise(@data)` in
    rowwise branch so expressions like `max(c_across(...))` compute per-row
  - Strips `rowwise_df` class from `@data` after rowwise mutation via
    `dplyr::ungroup(new_data)` — prevents rowwise semantics from leaking

- `R/reexports.R` (modified): added `dplyr::rowwise` and `dplyr::group_vars`
  re-exports

- `R/zzz.R` (modified): registered `rowwise` and `group_vars` S3 methods under
  `# ── feature/rowwise` section

- `tests/testthat/test-rowwise.R` (new): 18 test blocks covering all six
  sections from spec §VI.4 — rowwise state, mutate rowwise computation,
  ungroup exits, group_by exits, propagation through other verbs, edge cases

- `_pkgdown.yml` (modified): added `is_rowwise`, `is_grouped` to Predicates
  section; `rowwise.survey_base` to Grouping section
