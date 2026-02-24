# feature/distinct — distinct.survey_base()

| Field | Value |
|-------|-------|
| **Package** | surveytidy |
| **Phase** | dedup-rename-rowwise |
| **Branch** | feature/distinct |
| **PR** | TBD |
| **Date** | 2026-02-24 |

## Executive Summary

Adds `distinct()` support for survey design objects. `distinct()` physically
removes duplicate rows while always retaining all columns — design variables are
never dropped. Issues `surveycore_warning_physical_subset` on every call.
Re-exports `dplyr::distinct` so `library(surveytidy)` is sufficient.

---

## Commits

### `feat(distinct): implement distinct.survey_base() with physical-subset warning`

**Purpose:** Deliver `distinct.survey_base()` per spec §III.

**Key changes:**

- `R/distinct.R` (new): `distinct.survey_base()` implementation
  - Always issues `surveycore_warning_physical_subset` before deduplication
  - Empty `...`: deduplicates on non-design columns only (survey-safe default)
  - Non-empty `...`: issues `surveytidy_warning_distinct_design_var` if any
    specified column is a protected design variable; operation still proceeds
  - `.keep_all` user argument silently ignored — all columns are always retained
  - `@groups` and `@metadata` propagate unchanged (pure row operation)

- `R/reexports.R` (modified): added `dplyr::distinct` re-export

- `R/zzz.R` (modified): registered `distinct` S3 method under
  `# ── feature/distinct` section

- `tests/testthat/test-distinct.R` (new): 20 test blocks covering all six
  sections from spec §VI.2 — happy paths, warning always issued, column
  contract, domain preservation, `@groups` propagation, and edge cases

- `_pkgdown.yml` (modified): added `distinct.survey_base` to the Rows section
