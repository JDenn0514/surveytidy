# Implementation Plan — surveytidy rowstats

**Version:** 1.0
**Date:** 2026-04-15
**Spec:** `plans/spec-rowstats.md` (v0.3, implementation-ready)
**Decisions:** `plans/decisions-rowstats.md`

---

## Overview

This plan delivers `row_means()` and `row_sums()` — row-wise aggregation
functions for use inside `mutate()` on survey objects. Both functions integrate
with `mutate.survey_base()` via the `surveytidy_recode` attribute protocol
already used by `make_factor()`, `make_rev()`, and the six recode functions.

Because `.validate_transform_args()` and `.set_recode_attrs()` are currently
defined in `R/transform.R` but will be called from the new `R/rowstats.R`
(satisfying the 2+ source files rule in `code-style.md`), they must be moved
to `R/utils.R` before the feature code is written. This ships as a separate
refactor PR so the move is isolated from the feature diff.

---

## PR Map

- [x] PR 1: `refactor/rowstats-shared-helpers` — Move `.validate_transform_args()` and `.set_recode_attrs()` to `R/utils.R`
- [x] PR 2: `feature/rowstats` — Implement `row_means()`, `row_sums()`, mutate design-var warning, and tests

---

## PR 1: Move shared helpers to `R/utils.R`

**Branch:** `refactor/rowstats-shared-helpers`
**Depends on:** none

**Files:**
- `R/utils.R` — add `.validate_transform_args()` and `.set_recode_attrs()`; update file header
- `R/transform.R` — remove both helpers; update file header comment

**Acceptance criteria:**
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::test()` 0 failures, 0 skips — all existing tests pass unchanged
- [ ] `.validate_transform_args()` no longer defined in `R/transform.R`
- [ ] `.set_recode_attrs()` no longer defined in `R/transform.R`
- [ ] Both helpers defined in `R/utils.R` with identical bodies (pure move)
- [ ] `R/transform.R` file header updated to remove both helpers from the list
- [ ] `R/utils.R` file header updated to add both helpers to the list
- [ ] Changelog entry written and committed on this branch

**Notes:**

This is a pure code move — no behavioral change, no new tests needed. The
existing `transform.R` tests cover `.validate_transform_args()` and
`.set_recode_attrs()` indirectly through the public transform functions.
Those tests must pass unchanged after the move.

Move both helpers together into a new `# ── transform helpers ──` section
in `R/utils.R`. Place it after the `# ── recode helpers ──` section (line 242)
and before the `# ── survey_result helpers ──` section (line 335).

`.validate_transform_args()` is currently at lines 22–42 of `R/transform.R`.
`.set_recode_attrs()` is at lines 65–74 of `R/transform.R`. Both have
their own inline comments in `transform.R` that should travel with them.

### TDD Tasks (PR 1)

**Task 1.1 — Move `.validate_transform_args()` to `R/utils.R`**
1. Copy the function body (lines 19–42 of `R/transform.R`) into a new
   `# ── transform helpers ──` section in `R/utils.R`.
2. Delete the original definition from `R/transform.R`. Also update or remove
   the `# internal helpers (used only in transform.R)` section comment on
   line 17 — it formerly introduced three functions; after this task only
   `.strip_first_word()` remains there.
3. Update `R/transform.R`'s file header comment to remove
   `.validate_transform_args()` from the "Functions defined here" list.
4. Update `R/utils.R`'s file header comment to add `.validate_transform_args()`.

**Task 1.2 — Move `.set_recode_attrs()` to `R/utils.R`**
1. Copy the function body (lines 59–74 of `R/transform.R`) into the same
   `# ── transform helpers ──` section in `R/utils.R`, below
   `.validate_transform_args()`.
2. Delete the original definition from `R/transform.R`.
3. Update `R/transform.R`'s file header comment to remove `.set_recode_attrs()`
   from the "Functions defined here" list.
4. Update `R/utils.R`'s file header comment to add `.set_recode_attrs()`.

**Task 1.3 — Confirm no behavioral change**
1. Run `devtools::test()`. All existing tests must pass.
2. Run `devtools::check()`. 0 errors, 0 warnings.

**Task 1.4 — Changelog and PR**
1. Write `changelog/` entry for this refactor.
2. Commit and open PR to `develop`.

---

## PR 2: Implement `row_means()`, `row_sums()`, and design-var warning

**Branch:** `feature/rowstats`
**Depends on:** PR 1 (`refactor/rowstats-shared-helpers`) merged to `develop`

**Files:**
- `R/rowstats.R` — new file; `row_means()` and `row_sums()` with full roxygen
- `R/mutate.R` — add design variable overlap check at Step 8
- `tests/testthat/test-rowstats.R` — 30 test sections (28 per spec §VII + 2 from splitting test 16 into 16a/16b/16c)
- `changelog/` — entry, created last before opening PR

**Acceptance criteria:**
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and `man/` in sync
- [ ] `devtools::test()` 0 failures, 0 skips
- [ ] Coverage ≥ 98% on `R/rowstats.R`
- [ ] All 30 test sections present and passing, including dual pattern on tests 11, 17, 25, 26, 27, 28 (test 16 is split into 16a, 16b, 16c)
- [ ] `test_invariants()` is the first assertion in every block that returns a survey object
- [ ] `row_means()` and `row_sums()` are exported (`@export`) and in `@family transformation`
- [ ] `air format R/rowstats.R R/mutate.R` has been run
- [ ] Metadata round-trip verified: `@metadata@transformations[[col]]` has correct `fn`, `source_cols`, `description` after `mutate()`
- [ ] All three design types tested via `make_all_designs()`
- [ ] `surveytidy_warning_rowstats_includes_design_var` emitted when `.cols` overlaps with design variables
- [ ] Changelog entry written and committed on this branch

**Notes:**

### `R/rowstats.R` implementation

**File header:** Follow the `R/transform.R` pattern — comment block listing
all functions defined in the file.

**`row_means()` body outline:**
```r
row_means <- function(.cols, na.rm = FALSE, .label = NULL, .description = NULL) {
  # 1. Validate na.rm inline (before .validate_transform_args, per make_rev pattern)
  if (!is.logical(na.rm) || length(na.rm) != 1L || is.na(na.rm)) {
    cli::cli_abort(...)  # class = "surveytidy_error_rowstats_bad_arg"
  }
  # 2. Validate .label and .description via shared helper
  .validate_transform_args(.label, .description, "surveytidy_error_rowstats_bad_arg")
  # 3. Resolve columns
  df <- dplyr::pick({{ .cols }})
  # 4. Zero-column guard
  if (ncol(df) == 0L) { cli::cli_abort(..., class = "surveytidy_error_row_means_zero_cols") }
  # 5. Non-numeric guard
  not_numeric <- names(df)[!vapply(df, is.numeric, logical(1L))]
  if (length(not_numeric) > 0L) { cli::cli_abort(..., class = "surveytidy_error_row_means_non_numeric") }
  # 6. Compute
  source_cols <- names(df)
  effective_label <- .label %||% tryCatch(dplyr::cur_column(), error = function(e) NULL)
  result <- rowMeans(df, na.rm = na.rm)
  # 7. Set attrs and return
  .set_recode_attrs(result, effective_label, NULL, "row_means", source_cols, .description)
}
```

`row_sums()` is identical, substituting `rowSums`, error class suffixes
`_row_sums_*`, and `fn = "row_sums"`.

**`%||%` operator:** Use without `rlang::` prefix, matching the pattern in
`R/transform.R`, `R/mutate.R`, and `R/group-by.R`. Do not add an `importFrom`
for it — the existing NAMESPACE pattern handles it.

**`.set_recode_attrs()` call:** The `labels` argument (second) is `NULL` for
both functions — row aggregation produces no value labels.

**`source_cols`:** `names(dplyr::pick({{ .cols }}))` returns column names in
data-frame column order, not selector order. This is the correct and expected
behavior per spec §III Behavior Rule 5.

**`effective_label` fallback:** `dplyr::cur_column()` succeeds inside
`mutate()` and returns the output column name (e.g., `"score"` in
`mutate(d, score = row_means(...))`). The `tryCatch` only fires if called
outside a dplyr context, which also causes `dplyr::pick()` to throw first —
so in practice, `effective_label` is always a string when the recode attr
reaches `mutate.survey_base()`.

**Roxygen:** Full `@param`, `@return`, `@examples`, `@export`,
`@family transformation`. Examples must include `library(dplyr)` as the
first line (R CMD check gotcha from CLAUDE.md). Examples use
`surveycore::as_survey()` with an inline data frame — no real dataset.

### `R/mutate.R` Step 8 addition

Inside the `for (col in mutated_names)` loop, within the
`if (!is.null(q) && !is.null(recode_attr))` branch, insert the design
variable overlap check **after** the `source_cols` assignment and **before**
the `updated_metadata@transformations[[col]] <- list(...)` line:

```r
if (isTRUE(recode_fn %in% c("row_means", "row_sums"))) {
  design_vars <- .survey_design_var_names(.data)
  overlap <- intersect(source_cols, design_vars)
  if (length(overlap) > 0L) {
    cli::cli_warn(
      c(
        "!" = paste0(
          ".cols includes {length(overlap)} design variable ",
          "column{?s}: {.field {overlap}}."
        ),
        "i" = paste0(
          "Row aggregation across design variables produces ",
          "methodologically meaningless results."
        ),
        "i" = paste0(
          'Use a targeted selector such as ',
          '{.code starts_with("y")} to restrict to substantive columns.'
        )
      ),
      class = "surveytidy_warning_rowstats_includes_design_var"
    )
  }
}
```

### TDD Tasks (PR 2)

**Task 2.1 — Write tests 1–11, 25–26 (`row_means()` — all tests)**

Write `tests/testthat/test-rowstats.R` with:
- Tests 1–11: row_means happy path, NA behavior, metadata recording, tidyselect helpers
- Tests 25–26: non-numeric and zero-column errors (dual pattern)

All tests are RED at this point — `row_means()` does not exist yet.

For tests that require inline data (non-numeric col, all-NA rows, single col),
construct data frames inline per `testing-standards.md`. For all other tests,
use `make_all_designs(seed = 42)`.

Tests 11, 25, 26 use the dual pattern:
```r
expect_error(..., class = "surveytidy_error_rowstats_bad_arg")
expect_snapshot(error = TRUE, ...)
```

**Task 2.2 — Run tests 1–11, 25–26 to confirm they are red**

```r
devtools::test(filter = "rowstats")
```

Expected behavior before `row_means()` exists:
- Tests 1–11 will **ERROR** (not FAIL) — `row_means()` does not exist yet and
  testthat 3 surfaces a missing-function call as ERROR, not FAIL.
- Tests 25–26 (dual pattern) have mixed behavior:
  - `expect_error(class=)` will **FAIL** (wrong error class thrown).
  - `expect_snapshot(error = TRUE, ...)` will **PASS** on first run — testthat
    creates a new snapshot containing the "could not find function" error.
    This is expected; the snapshot will be corrected in Task 2.3.
- After implementing `row_means()` in Task 2.3, run
  `testthat::snapshot_review()` to update any snapshots created during this
  red phase before marking tests green.

**Task 2.3 — Implement `row_means()` in `R/rowstats.R`**

Create `R/rowstats.R`. Write `row_means()` per the outline above.
Include a file header comment block. Do NOT write `row_sums()` yet.

Run `devtools::test(filter = "rowstats")` after writing. Tests 1–11, 25–26
should be GREEN. Do not proceed if any remain RED.

**Task 2.4 — Write tests 12–17, 27–28 (`row_sums()` — all tests)**

Add to `test-rowstats.R`:
- Tests 12–15: row_sums happy path, NA behavior (0 for all-NA rows)
- Tests 16a, 16b, 16c: `row_sums()` metadata — three separate blocks matching
  the row_means() pattern (tests 5–8):
  - 16a: `.label` stored in `@metadata@variable_labels`
  - 16b: `.label = NULL` falls back to column name
  - 16c: `.description` stored and `source_cols` in `@metadata@transformations`
- Test 17: dual pattern (other row_sums error or edge case)
- Tests 27–28: non-numeric and zero-column errors (dual pattern)

All RED at this point.

**Task 2.5 — Run tests 12–17, 27–28 to confirm they are red**

```r
devtools::test(filter = "rowstats")
```

Expected behavior before `row_sums()` exists:
- Tests 12–17 will **ERROR** — `row_sums()` does not exist yet.
- Tests 27–28 (dual pattern) have mixed behavior:
  - `expect_error(class=)` will **FAIL** (wrong error class thrown).
  - `expect_snapshot(error = TRUE, ...)` will **PASS** on first run, creating
    a bad snapshot. After implementing `row_sums()` in Task 2.6, run
    `testthat::snapshot_review()` to correct these before proceeding.

**Task 2.6 — Implement `row_sums()` in `R/rowstats.R`**

Add `row_sums()` to the existing `R/rowstats.R`. Mirror `row_means()` exactly,
substituting `rowSums`, `"row_sums"` as fn name, and
`"surveytidy_error_row_sums_*"` error classes.

Run `devtools::test(filter = "rowstats")`. Tests 12–17, 27–28 should be
GREEN. All 26 written tests should be GREEN.

**Task 2.7 — Write tests 18–24 (integration tests)**

Add to `test-rowstats.R`:
- 18. Domain column preserved through mutate()
- 19. visible_vars updated correctly after mutate()
- 20. Single column selected — degenerate case
- 21. `where(is.numeric)` includes a design var → design-var warning
- 22. Explicit column list includes weight column → design-var warning
- 23. Warning fires but @metadata records all source_cols (including design var)
- 24. Called outside mutate() → dplyr::pick() error propagates

Tests 18–20, 24 should be GREEN immediately (they test behavior already in
place from `row_means()` + `row_sums()` + existing `mutate.survey_base()`).
Tests 21–23 should be RED — the design var check is not yet in `mutate.R`.

**Task 2.8 — Add design-var check to `R/mutate.R` Step 8**

Edit `R/mutate.R`: inside the `for (col in mutated_names)` loop, in the
`if (!is.null(q) && !is.null(recode_attr))` branch, add the overlap check
per the specification above.

Run `devtools::test(filter = "rowstats")`. All 30 tests should be GREEN.

**Task 2.9 — Run full test suite**

```r
devtools::test()
```

All tests must pass. In particular, confirm that the `mutate.R` addition does
not break any existing `test-mutate.R` or `test-transform.R` tests.

**Task 2.10 — `devtools::document()` and `air format`**

```r
devtools::document()
```

Confirm NAMESPACE has export entries for `row_means` and `row_sums`.

```bash
air format R/rowstats.R
```

**Task 2.11 — `devtools::check()`**

```r
devtools::check()
```

Target: 0 errors, 0 warnings, ≤2 pre-approved notes.

Gotchas to watch:
- Examples require `library(dplyr)` as the first line
- `row_means()` and `row_sums()` must not use `:::` for any surveycore internals
- Snapshot files for tests 11, 17, 25, 26, 27, 28 are created on first run;
  review with `testthat::snapshot_review()` before committing

**Task 2.12 — Changelog entry, commit, PR**

1. Write changelog entry under the rowstats heading.
2. Stage and commit all changes.
3. Open PR from `feature/rowstats` to `develop`.

---

## Quality Gate Checklist (final confirmation before merge)

Per spec §VIII:

- [ ] `devtools::check()`: 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::test()`: 0 failures, 0 skips
- [ ] Coverage ≥ 98% on `R/rowstats.R`
- [ ] All GAPs (GAP-1 through GAP-5) resolved and logged in `plans/decisions-rowstats.md` ✓
- [ ] `plans/error-messages.md` updated with all 5 new classes ✓ (already done)
- [ ] `.validate_transform_args()` moved to `R/utils.R` (PR 1)
- [ ] `.set_recode_attrs()` moved to `R/utils.R` (PR 1)
- [ ] `R/rowstats.R` formatted with `air format R/rowstats.R`
- [ ] All `@examples` run without error under `R CMD check`
- [ ] Metadata round-trip verified for both functions
