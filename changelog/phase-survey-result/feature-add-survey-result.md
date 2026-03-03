# Add passthrough dplyr/tidyr verb support for `survey_result` objects

| Field | Value |
|-------|-------|
| **Package** | surveytidy |
| **Phase** | survey-result |
| **Branch** | feature/add-survey-result |
| **PR** | TBD |
| **Date** | 2026-03-02 |

## Executive Summary

Registers 10 dplyr/tidyr verb methods for `survey_result` objects — the S3
base class for all surveycore analysis outputs (`survey_means`, `survey_freqs`,
`survey_totals`, `survey_quantiles`, `survey_corr`, `survey_ratios`). Prior to
this PR, applying verbs like `drop_na()` to these objects could silently strip
the custom class and `.meta` attribute. Now both are preserved across all
supported row-reordering/filtering operations, and `mutate()` keeps `meta$group`
coherent when `.keep` drops grouping columns.

All 10 methods follow a consistent passthrough pattern: capture class and
`.meta` before `NextMethod()`, then restore both afterward via
`.restore_survey_result()`. The registration target is `"survey_result"` (the
shared base class), so the single set of registrations covers all six
subclasses automatically via S3 dispatch.

This is PR 1 of 2. PR 2 (`feature/survey-result-meta`) will add
`select()`, `rename()`, and `rename_with()` with full meta-updating logic.

---

## Commits

### `feat(survey-result): add passthrough verb methods for survey_result objects`

**Purpose:** Prevents class and `.meta` attribute loss when users apply common
dplyr/tidyr verbs to surveycore analysis results. Provides the full test
infrastructure for survey_result verb testing, shared across PR 1 and PR 2.

**Key changes:**

- `R/verbs-survey-result.R` (new file): three inline helpers plus 10 passthrough
  verb implementations:
  - `.restore_survey_result(result, old_class, old_meta)` — restores class and
    `.meta` after `NextMethod()` strips them
  - `.prune_result_meta(meta, kept_cols)` — removes `meta$group` entries for
    columns no longer present; used by `mutate.survey_result` and (in PR 2)
    `select.survey_result`
  - `.apply_result_rename_map(result, rename_map)` — renames tibble columns and
    updates `.meta` group/x/numerator/denominator key references; used by PR 2
    `rename` and `select` methods (defined here so all call sites are in one file)
  - `filter.survey_result`, `arrange.survey_result`, `mutate.survey_result`,
    `slice.survey_result`, `slice_head.survey_result`, `slice_tail.survey_result`,
    `slice_min.survey_result`, `slice_max.survey_result`,
    `slice_sample.survey_result`, `drop_na.survey_result`

- `R/zzz.R`: 10 `registerS3method()` calls added in `.onLoad()` under a
  `# ── survey_result verbs (PR 1 — passthrough)` block; all registered against
  `"survey_result"` base class; `drop_na` registered in `tidyr`'s namespace,
  the rest in `dplyr`'s

- `tests/testthat/helper-test-data.R`: added three new test helpers:
  - `make_survey_result(type, design, seed)` — builds a fixture for any
    combination of `c("means","freqs","ratios")` × `c("taylor","replicate","twophase")`
  - `test_result_invariants(result, expected_class)` — asserts all 8 structural
    invariants (inherits survey_result, is tibble, has .meta list, .meta$group
    is a list, is data.frame, no duplicate names, ≥1 row, correct expected class)
  - `test_result_meta_coherent(result)` — asserts all `.meta` column references
    name columns that actually exist in the result

- `tests/testthat/test-verbs-survey-result.R` (new file): full PR 1 test suite
  covering sections 1–4, 23–26, and 29:
  - Section 1: one block per verb, inner loop over all 3 types × all 3 designs
  - Section 2: `filter`, `slice_head`, `slice_tail` row-count assertions + 0-row edge case
  - Section 3/3b/3c: `mutate()` happy path, `.keep = "none"`, `.keep = "used"` meta coherence
  - Section 4: `n_respondents` unchanged after `filter()`
  - Section 23: `drop_na()` with injected NAs — rows dropped, meta preserved
  - Section 24: `filter()` with `.by = group`
  - Section 25: `slice_min/slice_max` with non-default args
  - Section 26: `slice_sample` with `replace = TRUE` and over-sampling
  - Section 29: `drop_na()` with no NAs — all rows preserved

- `NEWS.md`: development-version bullet added for passthrough verb support
