# Implementation Plan: Survey-Aware Value Recoding Functions

**Version:** 1.0
**Date:** 2026-03-09
**Spec:** `plans/spec-recode.md` v0.7 (APPROVED)
**Phase:** 0.6

---

## Overview

This plan delivers six vector-level recode functions (`case_when`, `if_else`,
`na_if`, `replace_when`, `recode_values`, `replace_values`) that integrate with
`mutate.survey_base()` to propagate labels into and out of `@metadata`. It also
modifies `mutate.survey_base()` with three new steps: pre-attachment (label attrs
→ augmented data), post-detection (surveytidy_recode attr → @metadata), and strip
(haven attrs removed before @data is stored). One PR covers all deliverables.

---

## PR Map

- [ ] PR 1: `feature/recode` — six recode functions, mutate.R changes, utils.R
  helpers, full test coverage

---

## PR 1: feature/recode

**Branch:** `feature/recode`
**Depends on:** none

**Files:**

- `plans/error-messages.md` — register 8 new error/warning classes (quality gate:
  this is edited first, before any source code)
- `DESCRIPTION` — add `haven (>= 2.5.0)` to Imports; bump `dplyr (>= 1.2.0)`
- `R/utils.R` — add 3 mutate-support helpers:
  `.attach_label_attrs()`, `.extract_labelled_outputs()`, `.strip_label_attrs()`
- `R/recode.R` — NEW file: 6 exported functions + 4 internal helpers:
  `.validate_label_args()`, `.wrap_labelled()`, `.factor_from_result()`,
  `.merge_value_labels()`
- `R/mutate.R` — MODIFIED: extend step 1 (split weight vs. structural-var
  warnings), add pre-attachment (step 2), post-detection (step 4), strip (step 5),
  expand transformation logging (step 8)
- `tests/testthat/helper-test-data.R` — extend `test_invariants()` with the
  `surveytidy_recode` attr lifecycle check (Task 6.8, after strip step is wired)
- `tests/testthat/test-mutate.R` — MODIFIED: update warning class reference from
  `surveytidy_warning_mutate_design_var` → `surveytidy_warning_mutate_weight_col`
  (Task 6.2)
- `tests/testthat/test-recode.R` — NEW test file: 12 sections, full coverage
- `changelog/phase-0.6/feature-recode.md` — created last, before opening PR

**Acceptance criteria:**

- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] `plans/error-messages.md` updated with all 8 new classes before any code
- [ ] All three design types tested via `make_all_designs()` in every test section
- [ ] Domain column preservation asserted after every `mutate()` call
- [ ] All 12 test sections in §XII.1 implemented
- [ ] Backward-compatibility section (section 10) passes — no extra attrs when
  surveytidy args are absent
- [ ] No `surveytidy_recode` attr remains on any `@data` column after `mutate()`
  (enforced by extended `test_invariants()`)
- [ ] Line coverage ≥98% for `R/recode.R` and new helpers in `R/utils.R`; no
  drop below 95% overall
- [ ] `air format .` run before final commit
- [ ] Changelog entry written and committed on this branch

---

## Implementation Tasks

### STEP 0 — Pre-implementation: Resolve GAPs

Before writing any source code, resolve the two open GAPs from §XIII.

---

#### Task 0.1 — Verify dplyr unmatched-values error class

Read dplyr 1.2.0 source to find the exact condition class thrown when
`.unmatched = "error"` is set in `dplyr::recode_values()` and unmatched values
exist. The spec placeholder is `"dplyr_error_recode_unmatched"` — confirm or
correct it.

- Check `dplyr:::recode_values` source (or GitHub tag `v1.2.0`)
- Find the `cli_abort()` or `stop()` call for the unmatched case and read its
  `class=` argument
- Note the exact class name (may be a character vector — use the innermost class)
- Record it as a comment in the Notes section at the bottom of this plan

If dplyr does not expose a condition class (bare `stop()`), the `tryCatch` must
use a different guard (e.g., inspect the message with a regex). Note that
alternative approach here.

---

#### Task 0.2 — Verify surveycore set_val_labels export

Check whether `surveycore::set_val_labels()` (or an equivalent function that sets
`@metadata@value_labels`) is exported from surveycore 0.0.0.9000.

- Run `ls(asNamespace("surveycore"))` or inspect `NAMESPACE` in the surveycore
  package directory
- If exported: use it in test setup for label-aware tests
- If not exported: use direct `@metadata@value_labels` assignment inside test
  setup (acceptable per §XII.2 note in spec)
- Record the outcome in the Notes section below

---

#### Task 0.3 — Identify existing warning class discrepancy

The spec (§III.2) refers to `surveytidy_warning_mutate_weight_col` as "Phase 0.5,
unchanged", but the existing `mutate.R` uses `surveytidy_warning_mutate_design_var`
for all design-variable modifications (weights + structural combined).

Resolution (already decided — no user action needed):

Phase 0.6 will:
1. Rename `surveytidy_warning_mutate_design_var` → `surveytidy_warning_mutate_weight_col`
   (weight-column-only warning, same trigger, updated message if needed)
2. Add new `surveytidy_warning_mutate_structural_var` for strata/PSU/FPC/repweights
3. Update `error-messages.md` (remove old class, add two new ones)
4. Update `tests/testthat/test-mutate.R` to reference
   `surveytidy_warning_mutate_weight_col` instead of `surveytidy_warning_mutate_design_var`

This is captured as part of STEP 1.3 (error-messages.md update) and STEP 6
(mutate.R modification).

---

### STEP 1 — Pre-flight: Register error classes and update DESCRIPTION

No tests in this step — just file edits that unblock everything else.

---

#### Task 1.1 — Update plans/error-messages.md

Edit `plans/error-messages.md`:

Remove existing row:
- `surveytidy_warning_mutate_design_var` — R/mutate.R — `mutate()` modifies a
  design variable column

Add new Errors rows:
- `surveytidy_error_recode_label_not_scalar` — R/recode.R — `.label` is not NULL
  and not a character(1)
- `surveytidy_error_recode_value_labels_unnamed` — R/recode.R — `.value_labels`
  is not NULL and has no names
- `surveytidy_error_recode_factor_with_label` — R/recode.R — `.factor = TRUE` and
  `.label` is non-NULL
- `surveytidy_error_recode_use_labels_no_attrs` — R/recode.R — `.use_labels = TRUE`
  but `attr(x, "labels")` is NULL
- `surveytidy_error_recode_unmatched_values` — R/recode.R — `.unmatched = "error"`
  and unmatched values exist in `recode_values()`
- `surveytidy_error_recode_from_to_missing` — R/recode.R — `from` is NULL and
  `.use_labels = FALSE` in `recode_values()`
- `surveytidy_error_recode_description_not_scalar` — R/recode.R — `.description`
  is not NULL and not a character(1)

Add new Warnings rows:
- `surveytidy_warning_mutate_weight_col` — R/mutate.R — `mutate()` modifies a
  weight column (replaces `surveytidy_warning_mutate_design_var`)
- `surveytidy_warning_mutate_structural_var` — R/mutate.R — `mutate()` modifies a
  structural design variable (strata, PSU, FPC, or repweights)

---

#### Task 1.2 — Update DESCRIPTION

Edit `DESCRIPTION`:

- Add to `Imports:`: `haven (>= 2.5.0)`
- Update `dplyr` lower bound to `dplyr (>= 1.2.0)` (if currently lower)

Run `devtools::document()` to confirm no parse errors. (NAMESPACE does not change
from this step — haven is Imports, not imported via `@importFrom`.)

---

### STEP 2 — Extend test_invariants() [DEFERRED — see Task 6.8]

> **Note:** The `test_invariants()` extension that asserts no column carries a
> `"surveytidy_recode"` attribute is deferred to **Task 6.8** (after the strip
> step in `mutate.R` is wired in STEP 6). Adding it here would cause every
> STEP 5 per-function TDD loop to fail: `dplyr::mutate()` preserves custom
> attrs, and the strip step (`step 5`) does not exist until Task 6.4.
>
> STEP 5 tests call `test_invariants()` on the result of `mutate(d, col =
> recode_fn(...))` — those tests are only valid once the strip step is in place.
>
> **See Task 6.8** for the `test_invariants()` extension code and the
> `devtools::test()` confirmation step.

---

### STEP 3 — utils.R: three mutate-support helpers

These helpers are called by `mutate.survey_base()` in STEP 6. They are tested
indirectly through the mutate/recode integration tests (§XII.1 sections 1 and 2).
Write stub tests for those sections first, then write the helpers.

---

#### Task 3.1 — Write failing tests: pre-attachment and post-detection (§XII.1 §§1–2)

Add the following to `tests/testthat/test-recode.R` (create the file).

Section 1 (mutate pre-attachment):
```r
test_that("mutate() makes variable labels available as attr inside mutate [all designs]", {
  # stub — fails until mutate.R is modified
})

test_that("mutate() makes value labels available as attr(x, 'labels') inside mutate [all designs]", {
  # stub — fails until mutate.R is modified
})

test_that("mutate() pre-attachment is a no-op when @metadata has no labels [all designs]", {
  # stub — fails until mutate.R is modified
})
```

Section 2 (post-detection):
```r
test_that("mutate() extracts variable_label from haven_labelled result into @metadata [all designs]", {
  # stub — fails until mutate.R is modified
})

test_that("mutate() extracts value_labels from haven_labelled result into @metadata [all designs]", {
  # stub — fails until mutate.R is modified
})

test_that("mutate() strips haven attrs from @data after mutation [all designs]", {
  # stub — fails until mutate.R is modified
})

test_that("mutate() clears @metadata labels when labelled column is overwritten with non-labelled output [all designs]", {
  # stub — fails until mutate.R is modified
})
```

Run `devtools::test("test-recode")` to confirm these stub tests pass trivially
(empty stubs with no assertions pass). The point is to establish the file and
confirm the infrastructure loads.

---

#### Task 3.2 — Write .attach_label_attrs() in R/utils.R

Add under a new section `# ── mutate() label helpers ───────────────────────────`:

```r
.attach_label_attrs <- function(data, metadata) {
  # Fast path: no-op when both label stores are empty
  if (length(metadata@value_labels) == 0L &&
      length(metadata@variable_labels) == 0L) {
    return(data)
  }
  for (col in names(metadata@value_labels)) {
    if (col %in% names(data)) {
      attr(data[[col]], "labels") <- metadata@value_labels[[col]]
    }
  }
  for (col in names(metadata@variable_labels)) {
    if (col %in% names(data)) {
      attr(data[[col]], "label") <- metadata@variable_labels[[col]]
    }
  }
  data
}
```

Key details:
- Returns a modified copy — does NOT mutate `@data` in place
- Does NOT set the `"haven_labelled"` class — attr-only per §III.3
- Skips columns not in `data` (design vars and metadata are independent sets)
- Fast path returns early when metadata has no labels (all-empty check)

---

#### Task 3.3 — Write .extract_labelled_outputs() in R/utils.R

```r
.extract_labelled_outputs <- function(data, metadata, changed_cols) {
  for (col in changed_cols) {
    if (!col %in% names(data)) next
    recode_attr <- attr(data[[col]], "surveytidy_recode")
    if (!is.null(recode_attr)) {
      # Column was produced by a surveytidy recode function: extract labels.
      # attr(x, "label") is NULL for factor outputs, NULL for plain-with-desc.
      # attr(x, "labels") is NULL for factor and plain outputs.
      # Assigning NULL clears the entry — this is intentional for factors,
      # which clear old labels (old encoding is no longer valid).
      metadata@variable_labels[[col]] <- attr(data[[col]], "label")
      metadata@value_labels[[col]] <- attr(data[[col]], "labels")
    } else if (
      !is.null(metadata@variable_labels[[col]]) ||
      !is.null(metadata@value_labels[[col]])
    ) {
      # Non-recode overwrite of a previously-labelled column: clear stale labels.
      metadata@variable_labels[[col]] <- NULL
      metadata@value_labels[[col]] <- NULL
    }
  }
  metadata
}
```

Key details:
- Returns updated `metadata` object (does NOT assign to `.data@metadata` internally)
- `changed_cols` = explicitly-named LHS expressions from `rlang::quos(...)` names
- Factor outputs carry `surveytidy_recode` attr but no `"label"` or `"labels"` attrs →
  sets both metadata entries to NULL (correct: old labels for replaced column are stale)
- Only `changed_cols` are inspected — unnamed mutate expressions are not processed

---

#### Task 3.4 — Write .strip_label_attrs() in R/utils.R

```r
.strip_label_attrs <- function(data) {
  for (col in names(data)) {
    data[[col]] <- haven::zap_labels(data[[col]])
    attr(data[[col]], "surveytidy_recode") <- NULL
  }
  data
}
```

Key details:
- `haven::zap_labels()` removes `"label"`, `"labels"`, `"format.spss"`,
  `"display_width"`, and the `"haven_labelled"` class
- `"surveytidy_recode"` must be removed separately (not a haven attr)
- Always runs on every column — no conditional check needed
- Domain column: `haven::zap_labels()` is a no-op on plain logical vectors
- Returns modified `data`

Run `devtools::test("test-recode")` — stubs still pass (no real assertions yet).
Run `devtools::check()` to confirm no lint/namespace issues from the new utils.

---

### STEP 4 — recode.R: internal helpers

Write the 4 internal helpers first (no TDD needed — they have no user-visible errors
and are exercised through the exported functions in STEP 5).

Create `R/recode.R` with the header comment and the 4 helpers.

---

#### Task 4.1 — Write file header and .validate_label_args()

Create `R/recode.R`:

```r
# R/recode.R
#
# Survey-aware value recoding functions for use inside mutate().
#
# Six exported functions shadow or wrap their dplyr equivalents with
# @metadata integration:
#   case_when()     — shadows dplyr::case_when(); adds .label, .value_labels,
#                     .factor, .description
#   replace_when()  — wraps dplyr::replace_when(); adds .label, .value_labels,
#                     .description + label inheritance from x
#   if_else()       — shadows dplyr::if_else(); adds .label, .value_labels,
#                     .description
#   na_if()         — shadows dplyr::na_if(); adds .update_labels, .description
#   recode_values() — own implementation (identical to dplyr 1.2.0 API); adds
#                     .label, .value_labels, .factor, .use_labels, .description
#   replace_values() — own implementation (identical to dplyr 1.2.0 API); adds
#                     .label, .value_labels, .description + label inheritance
#
# Four internal helpers (placement: single-file, not in utils.R):
#   .validate_label_args()  — validates .label, .value_labels, .description
#   .wrap_labelled()        — wraps result in haven::labelled(); sets surveytidy_recode attr
#   .factor_from_result()   — converts result to factor with correct level order
#   .merge_value_labels()   — merges base labels with override labels
#
# Dispatch wiring: these functions shadow dplyr generics. No S3 registration
# needed — users call them directly (e.g., mutate(d, x = case_when(...))).
# surveytidy::case_when() takes precedence over dplyr::case_when() when
# surveytidy is attached after dplyr.
```

Then write `.validate_label_args()`:

```r
.validate_label_args <- function(label, value_labels, description = NULL) {
  if (!is.null(label) && !(is.character(label) && length(label) == 1L)) {
    cli::cli_abort(
      c(
        "x" = "{.arg .label} must be a single character string.",
        "i" = "Got {.cls {class(label)}} of length {length(label)}."
      ),
      class = "surveytidy_error_recode_label_not_scalar"
    )
  }
  if (!is.null(value_labels) && is.null(names(value_labels))) {
    cli::cli_abort(
      c(
        "x" = "{.arg .value_labels} must be a named vector.",
        "i" = "Got an unnamed {.cls {class(value_labels)}}.",
        "v" = "Use {.code c(\"Label\" = value, ...)} to name the entries."
      ),
      class = "surveytidy_error_recode_value_labels_unnamed"
    )
  }
  if (!is.null(description) &&
      !(is.character(description) && length(description) == 1L)) {
    cli::cli_abort(
      c(
        "x" = "{.arg .description} must be a single character string.",
        "i" = "Got {.cls {class(description)}} of length {length(description)}."
      ),
      class = "surveytidy_error_recode_description_not_scalar"
    )
  }
  invisible(TRUE)
}
```

---

#### Task 4.2 — Write .wrap_labelled()

```r
.wrap_labelled <- function(x, label, value_labels, description = NULL) {
  result <- haven::labelled(x, labels = value_labels, label = label)
  attr(result, "surveytidy_recode") <- list(description = description)
  result
}
```

Key detail: `surveytidy_recode` attr is always set when this helper is called —
the caller has already determined that at least one surveytidy arg is non-NULL.

---

#### Task 4.3 — Write .factor_from_result()

```r
.factor_from_result <- function(x, value_labels, formula_values) {
  if (!is.null(value_labels)) {
    levels <- names(value_labels)
  } else {
    levels <- formula_values
  }
  factor(x, levels = levels)
}
```

Called by `case_when()` and `recode_values()` when `.factor = TRUE`.

---

#### Task 4.4 — Write .merge_value_labels()

```r
.merge_value_labels <- function(base_labels, override_labels) {
  if (is.null(base_labels) && is.null(override_labels)) return(NULL)
  if (is.null(base_labels)) return(override_labels)
  if (is.null(override_labels)) return(base_labels)
  # Replace matching entries; append new entries from override_labels.
  merged <- base_labels
  for (nm in names(override_labels)) {
    merged[nm] <- override_labels[[nm]]
  }
  merged
}
```

---

### STEP 5 — recode.R: six exported functions (TDD per function)

For each function: write failing tests → confirm failure → implement → confirm pass.
Tests go in the relevant section of `tests/testthat/test-recode.R`.

The overall test file skeleton (to be filled incrementally):

```r
# tests/testthat/test-recode.R
#
# Tests for surveytidy recode functions + mutate() label integration.
# Sections follow spec §XII.1.
library(dplyr)

# Data setup helpers defined at top of file (used across sections):
# make_all_designs(), make_survey_data() — from helper-test-data.R
```

---

#### Task 5.1 — Write case_when() tests (§XII.1 section 3)

Write real test blocks for section 3:

```r
# ── 3. case_when() ───────────────────────────────────────────────────────────

test_that("case_when() with no label args produces output identical to dplyr::case_when() [all designs]", {
  designs <- make_all_designs(seed = 42)
  for (d in designs) {
    result <- mutate(d, cat = case_when(y1 > 50 ~ "high", .default = "low"))
    test_invariants(result)
    # No surveytidy attrs on the column
    expect_null(attr(result@data$cat, "surveytidy_recode"))
    expect_null(attr(result@data$cat, "label"))
    expect_null(attr(result@data$cat, "labels"))
    # Output matches dplyr
    expect_identical(
      result@data$cat,
      dplyr::case_when(d@data$y1 > 50 ~ "high", .default = "low")
    )
  }
})

test_that("case_when() .label stores variable label in @metadata [all designs]", {
  designs <- make_all_designs(seed = 42)
  for (d in designs) {
    result <- mutate(d, cat = case_when(
      y1 > 50 ~ "high", .default = "low",
      .label = "Response category"
    ))
    test_invariants(result)
    expect_identical(result@metadata@variable_labels$cat, "Response category")
  }
})

test_that("case_when() .value_labels stores value labels in @metadata [all designs]", {
  designs <- make_all_designs(seed = 42)
  for (d in designs) {
    result <- mutate(d, cat = case_when(
      y1 > 50 ~ 1L, .default = 0L,
      .value_labels = c("High" = 1L, "Low" = 0L)
    ))
    test_invariants(result)
    expect_identical(
      result@metadata@value_labels$cat,
      c("High" = 1L, "Low" = 0L)
    )
  }
})

test_that("case_when() .factor = TRUE returns factor with levels from .value_labels [all designs]", {
  designs <- make_all_designs(seed = 42)
  for (d in designs) {
    result <- mutate(d, cat = case_when(
      y1 > 50 ~ "high", .default = "low",
      .factor = TRUE,
      .value_labels = c("High" = "high", "Low" = "low")
    ))
    test_invariants(result)
    expect_true(is.factor(result@data$cat))
    expect_identical(levels(result@data$cat), c("High", "Low"))
  }
})

test_that("case_when() .factor = TRUE without .value_labels uses formula appearance order [all designs]", {
  designs <- make_all_designs(seed = 42)
  for (d in designs) {
    result <- mutate(d, cat = case_when(
      y1 > 50 ~ "high", .default = "low",
      .factor = TRUE
    ))
    test_invariants(result)
    expect_true(is.factor(result@data$cat))
    expect_identical(levels(result@data$cat), c("high", "low"))
  }
})

test_that("case_when() error: .label not scalar → surveytidy_error_recode_label_not_scalar [all designs]", {
  d <- make_all_designs(seed = 42)$taylor
  expect_error(
    mutate(d, cat = case_when(y1 > 50 ~ "high", .label = c("a", "b"))),
    class = "surveytidy_error_recode_label_not_scalar"
  )
  expect_snapshot(
    error = TRUE,
    mutate(d, cat = case_when(y1 > 50 ~ "high", .label = c("a", "b")))
  )
})

test_that("case_when() error: .value_labels unnamed → surveytidy_error_recode_value_labels_unnamed [all designs]", {
  d <- make_all_designs(seed = 42)$taylor
  expect_error(
    mutate(d, cat = case_when(y1 > 50 ~ 1L, .value_labels = c(1L, 0L))),
    class = "surveytidy_error_recode_value_labels_unnamed"
  )
  expect_snapshot(
    error = TRUE,
    mutate(d, cat = case_when(y1 > 50 ~ 1L, .value_labels = c(1L, 0L)))
  )
})

test_that("case_when() error: .factor = TRUE + .label → surveytidy_error_recode_factor_with_label", {
  d <- make_all_designs(seed = 42)$taylor
  expect_error(
    mutate(d, cat = case_when(y1 > 50 ~ "high", .factor = TRUE, .label = "bad")),
    class = "surveytidy_error_recode_factor_with_label"
  )
  expect_snapshot(
    error = TRUE,
    mutate(d, cat = case_when(y1 > 50 ~ "high", .factor = TRUE, .label = "bad"))
  )
})

test_that("case_when() domain column preserved through mutate [all designs]", {
  designs <- make_all_designs(seed = 42)
  for (d in designs) {
    d_filtered <- filter(d, y1 > 40)
    result <- mutate(d_filtered, cat = case_when(y1 > 50 ~ "high", .default = "low"))
    test_invariants(result)
    expect_identical(
      result@data[[surveycore::SURVEYCORE_DOMAIN_COL]],
      d_filtered@data[[surveycore::SURVEYCORE_DOMAIN_COL]]
    )
  }
})
```

---

#### Task 5.2 — Run tests to confirm initial failure

```r
devtools::test("test-recode")
```

Tests that call `case_when()` with `.label` etc. should fail because `case_when()`
in scope is `dplyr::case_when()` which doesn't accept `.label`. This confirms the
tests are wired correctly.

---

#### Task 5.3 — Implement case_when() in R/recode.R

```r
#' Conditional recoding with metadata propagation
#'
#' @description
#' A survey-aware version of [dplyr::case_when()]. When called with `.label`,
#' `.value_labels`, `.factor`, or `.description`, the output propagates label
#' metadata into `@metadata` via [mutate()].
#'
#' When called without these arguments, output is identical to
#' [dplyr::case_when()].
#'
#' @param ... Two-sided formulas (`condition ~ value`). Passed to
#'   [dplyr::case_when()].
#' @param .default Default value for unmatched rows. Passed through.
#' @param .unmatched `"default"` (use `.default`) or `"error"`. Passed through.
#' @param .ptype Output type prototype. Passed through.
#' @param .size Expected output length. Passed through.
#' @param .label character(1) or NULL. Variable label stored in
#'   `@metadata@variable_labels` after `mutate()`.
#' @param .value_labels Named vector or NULL. Value labels stored in
#'   `@metadata@value_labels`. Names are label strings; values are data values.
#' @param .factor logical(1). If `TRUE`, return a factor. Incompatible with
#'   `.label`.
#' @param .description character(1) or NULL. Plain-language description of how
#'   the variable was created. Stored in `@metadata@transformations`.
#'
#' @return A vector, factor, or `haven_labelled` vector depending on arguments.
#'
#' @examples
#' library(surveytidy)
#' library(dplyr)
#' library(surveycore)
#' d <- as_survey(data.frame(x = 1:10, w = rep(1, 10)), weights = w)
#'
#' # Basic case_when — identical to dplyr::case_when()
#' mutate(d, cat = case_when(x > 5 ~ "high", .default = "low"))
#'
#' # With metadata
#' mutate(d, cat = case_when(
#'   x > 5 ~ "high", .default = "low",
#'   .label = "Response category"
#' ))
#'
#' @family recoding
#' @export
case_when <- function(
  ...,
  .default = NULL,
  .unmatched = "default",
  .ptype = NULL,
  .size = NULL,
  .label = NULL,
  .value_labels = NULL,
  .factor = FALSE,
  .description = NULL
) {
  .validate_label_args(.label, .value_labels, .description)
  if (isTRUE(.factor) && !is.null(.label)) {
    cli::cli_abort(
      c(
        "x" = "{.arg .label} cannot be used with {.code .factor = TRUE}.",
        "i" = "Factor levels carry their own labels."
      ),
      class = "surveytidy_error_recode_factor_with_label"
    )
  }

  # Delegate core computation to dplyr
  result <- dplyr::case_when(
    ...,
    .default = .default,
    .unmatched = .unmatched,
    .ptype = .ptype,
    .size = .size
  )

  has_surveytidy_args <- !is.null(.label) || !is.null(.value_labels) ||
    !is.null(.description) || isTRUE(.factor)

  if (isTRUE(.factor)) {
    # Two-path detection for factor levels
    formulas <- list(...)
    all_literal <- all(vapply(
      formulas,
      function(f) rlang::is_syntactic_literal(rlang::f_rhs(f)),
      logical(1L)
    ))
    if (all_literal) {
      formula_values <- as.character(
        vapply(formulas, function(f) rlang::f_rhs(f), list(1))
      )
      if (!is.null(.default) && !is.na(.default)) {
        formula_values <- c(formula_values, as.character(.default))
      }
    } else {
      formula_values <- unique(as.character(result[!is.na(result)]))
    }
    result <- .factor_from_result(result, .value_labels, formula_values)
    attr(result, "surveytidy_recode") <- list(description = .description)
    return(result)
  }

  if (!is.null(.label) || !is.null(.value_labels)) {
    return(.wrap_labelled(result, .label, .value_labels, .description))
  }

  if (!is.null(.description)) {
    attr(result, "surveytidy_recode") <- list(description = .description)
  }

  result
}
```

---

#### Task 5.4 — Run tests; confirm section 3 passes

```r
devtools::test("test-recode")
```

All section 3 tests should now pass. Move on to `replace_when`.

---

#### Task 5.5 — Write replace_when() tests (§XII.1 section 4) and implement

Write tests covering: happy path, label inheritance from `x`, `.value_labels`
merge, all 3 design types, error paths.

Then implement `replace_when()`:

```r
#' @rdname case_when
#' @export
replace_when <- function(
  x,
  ...,
  .label = NULL,
  .value_labels = NULL,
  .description = NULL
) {
  .validate_label_args(.label, .value_labels, .description)

  result <- dplyr::replace_when(x, ...)

  merged_labels <- .merge_value_labels(attr(x, "labels"), .value_labels)
  effective_label <- if (!is.null(.label)) .label else attr(x, "label")

  has_surveytidy_args <- !is.null(.label) || !is.null(.value_labels) ||
    !is.null(.description)

  if (!is.null(merged_labels) || !is.null(effective_label)) {
    return(.wrap_labelled(result, effective_label, merged_labels, .description))
  }

  if (!is.null(.description)) {
    attr(result, "surveytidy_recode") <- list(description = .description)
  }

  result
}
```

Run `devtools::test("test-recode")` — section 4 passes.

---

#### Task 5.6 — Write if_else() tests (§XII.1 section 5) and implement

Write tests covering: happy path (identical to dplyr), `.label`/`.value_labels`
set metadata, all 3 design types, error paths.

```r
#' @rdname case_when
#' @export
if_else <- function(
  condition,
  true,
  false,
  missing = NULL,
  ...,
  ptype = NULL,
  .label = NULL,
  .value_labels = NULL,
  .description = NULL
) {
  .validate_label_args(.label, .value_labels, .description)

  result <- dplyr::if_else(condition, true, false, missing = missing,
                           ..., ptype = ptype)

  if (!is.null(.label) || !is.null(.value_labels)) {
    return(.wrap_labelled(result, .label, .value_labels, .description))
  }

  if (!is.null(.description)) {
    attr(result, "surveytidy_recode") <- list(description = .description)
  }

  result
}
```

Run tests — section 5 passes.

---

#### Task 5.7 — Write na_if() tests (§XII.1 section 6) and implement

Write tests covering: `.update_labels = TRUE/FALSE`, `y` as a vector, `x` with
no labels (plain vector), all 3 design types, rlang error for non-scalar
`.update_labels`.

```r
#' @rdname case_when
#' @export
na_if <- function(x, y, .update_labels = TRUE, .description = NULL) {
  rlang::check_scalar_bool(.update_labels)
  .validate_label_args(label = NULL, value_labels = NULL, description = .description)

  result <- dplyr::na_if(x, y)

  labels_attr <- attr(x, "labels")
  label_attr  <- attr(x, "label")

  if (!is.null(labels_attr)) {
    if (isTRUE(.update_labels)) {
      keep <- !labels_attr %in% y
      labels_attr <- labels_attr[keep]
      if (length(labels_attr) == 0L) labels_attr <- NULL
    }
    return(.wrap_labelled(result, label_attr, labels_attr, .description))
  }

  if (!is.null(.description)) {
    attr(result, "surveytidy_recode") <- list(description = .description)
  }

  result
}
```

Run tests — section 6 passes.

---

#### Task 5.8 — Write recode_values() tests (§XII.1 section 7) and implement

Write tests covering: explicit `from`/`to`, `.use_labels = TRUE`, `.use_labels =
TRUE` with no labels (error), `.unmatched = "error"` with unmatched values (error),
`.factor = TRUE`, `.factor = TRUE + .label` (error), `from = NULL + .use_labels =
FALSE` (error), all 3 design types.

Also include the interaction edge case: `.use_labels = TRUE` + `.factor = TRUE`
together — `to` becomes `names(labels_attr)` (label strings), so factor levels
must equal `unique(names(labels_attr))` in label-definition order. Assert both
`is.factor(result)` and that `levels(result)` matches the expected label strings.

**Pre-implementation**: confirm the dplyr unmatched-values condition class from
Task 0.1. Substitute the correct class name in `inherits(e, "<class>")` below.

```r
#' @rdname case_when
#' @export
recode_values <- function(
  x,
  ...,
  from = NULL,
  to = NULL,
  default = NULL,
  .unmatched = "default",
  ptype = NULL,
  .label = NULL,
  .value_labels = NULL,
  .factor = FALSE,
  .use_labels = FALSE,
  .description = NULL
) {
  .validate_label_args(.label, .value_labels, .description)
  if (isTRUE(.factor) && !is.null(.label)) {
    cli::cli_abort(
      c("x" = "{.arg .label} cannot be used with {.code .factor = TRUE}.",
        "i" = "Factor levels carry their own labels."),
      class = "surveytidy_error_recode_factor_with_label"
    )
  }

  if (isTRUE(.use_labels)) {
    labels_attr <- attr(x, "labels")
    if (is.null(labels_attr)) {
      cli::cli_abort(
        c("x" = "{.arg x} has no value labels.",
          "i" = "{.code .use_labels = TRUE} requires {.arg x} to carry value labels.",
          "v" = "Provide {.arg from} and {.arg to} explicitly instead."),
        class = "surveytidy_error_recode_use_labels_no_attrs"
      )
    }
    from <- unname(labels_attr)
    to   <- names(labels_attr)
  } else if (is.null(from)) {
    cli::cli_abort(
      c("x" = "{.arg from} must be supplied when {.code .use_labels = FALSE}.",
        "v" = paste0(
          "Supply {.arg from} and {.arg to}, or set ",
          "{.code .use_labels = TRUE} to build the map from {.arg x}'s value labels."
        )),
      class = "surveytidy_error_recode_from_to_missing"
    )
  }

  result <- tryCatch(
    dplyr::recode_values(x, from = from, to = to, default = default,
                         .unmatched = .unmatched, ptype = ptype, ...),
    error = function(e) {
      # ⚠ Substitute the correct dplyr condition class confirmed in Task 0.1
      if (.unmatched == "error" && inherits(e, "dplyr_error_recode_unmatched")) {
        cli::cli_abort(
          c("x" = "Some values in {.arg x} were not found in {.arg from}.",
            "i" = "Set {.code .unmatched = \"default\"} to keep unmatched values."),
          class = "surveytidy_error_recode_unmatched_values",
          parent = e
        )
      }
      stop(e)
    }
  )

  if (isTRUE(.factor)) {
    result <- .factor_from_result(result, .value_labels, unique(to))
    attr(result, "surveytidy_recode") <- list(description = .description)
    return(result)
  }

  if (!is.null(.label) || !is.null(.value_labels)) {
    return(.wrap_labelled(result, .label, .value_labels, .description))
  }

  if (!is.null(.description)) {
    attr(result, "surveytidy_recode") <- list(description = .description)
  }

  result
}
```

Run tests — section 7 passes.

---

#### Task 5.9 — Write replace_values() tests (§XII.1 section 8) and implement

Write tests covering: happy path (no labels), `.value_labels` merge with `x`'s
existing labels, label inheritance, all 3 design types, error paths.

```r
#' @rdname case_when
#' @export
replace_values <- function(
  x,
  ...,
  from = NULL,
  to = NULL,
  .label = NULL,
  .value_labels = NULL,
  .description = NULL
) {
  .validate_label_args(.label, .value_labels, .description)

  result <- dplyr::replace_values(x, from = from, to = to, ...)

  merged_labels <- .merge_value_labels(attr(x, "labels"), .value_labels)
  effective_label <- if (!is.null(.label)) .label else attr(x, "label")

  if (!is.null(merged_labels) || !is.null(effective_label)) {
    return(.wrap_labelled(result, effective_label, merged_labels, .description))
  }

  if (!is.null(.description)) {
    attr(result, "surveytidy_recode") <- list(description = .description)
  }

  result
}
```

Run tests — section 8 passes.

---

### STEP 6 — mutate.R: extend step 1, add steps 2/4/5, expand step 8

At this point, all 6 recode functions exist and their unit tests pass. Now modify
`mutate.survey_base()` to wire in the 3 utils.R helpers and expand the warning logic.

---

#### Task 6.1 — Write failing tests for §XII.1 sections 1, 2, 2b

Replace the stub tests written in Task 3.1 with real assertions. Also add the
design-variable warning tests (section 2b).

Section 1 real tests: set up a design with `@metadata@variable_labels` and
`@metadata@value_labels`, call `mutate()` using a recode function that reads
from `x`, assert the label was visible to the function (inferred by the presence
of label in output metadata).

Section 2 real tests: call `mutate()` with a `haven::labelled()` output — assert
metadata is updated and haven attrs are stripped from `@data`.

Section 2b tests: mutate strata column, PSU column, FPC column, replicate-weight
column — each should emit `surveytidy_warning_mutate_structural_var`. Also confirm
weight-column mutation still emits `surveytidy_warning_mutate_weight_col`.

Run `devtools::test("test-recode")` to confirm these tests fail.

---

#### Task 6.2 — Extend step 1 in mutate.survey_base()

Split the existing single design-variable warning into two:

```r
# Step 1: Detect design variable modification by name.
# Split into two warning classes:
#   - weight column: surveytidy_warning_mutate_weight_col
#   - structural design vars (strata, PSU, FPC, repweights):
#     surveytidy_warning_mutate_structural_var
weight_var <- if (S7::S7_inherits(.data, surveycore::survey_twophase)) {
  .data@variables$phase1$weights
} else {
  .data@variables$weights
}
structural_vars <- setdiff(.survey_design_var_names(.data), weight_var)
structural_vars <- intersect(structural_vars, names(.data@data))

changed_weight     <- intersect(mutated_names, weight_var)
changed_structural <- intersect(mutated_names, structural_vars)

if (length(changed_weight) > 0L) {
  cli::cli_warn(
    c(
      "!" = paste0(
        "mutate() modified weight column {.field {changed_weight}}."
      ),
      "i" = "Effective sample size may be affected.",
      "v" = "Use {.fn update_design} to intentionally change design variables."
    ),
    class = "surveytidy_warning_mutate_weight_col"
  )
}
if (length(changed_structural) > 0L) {
  cli::cli_warn(
    c(
      "!" = paste0(
        "mutate() modified structural design variable(s): ",
        "{.field {changed_structural}}."
      ),
      "i" = "Structural recoding can invalidate variance estimates.",
      "i" = paste0(
        "Use {.fn subset} or {.fn filter} to restrict the domain; ",
        "do not recode design variables."
      )
    ),
    class = "surveytidy_warning_mutate_structural_var"
  )
}
```

Also update `tests/testthat/test-mutate.R`: change any reference to
`surveytidy_warning_mutate_design_var` → `surveytidy_warning_mutate_weight_col`.

> **Intentional gap (documented):** The old `.protected_cols()` check also
> covered the domain column (`"..surveycore_domain.."`). The new two-pronged
> check using `.survey_design_var_names()` does NOT include the domain column,
> so `mutate(d, ..surveycore_domain.. = TRUE)` no longer emits a warning.
> This regression is accepted: the domain column name is intentionally obscure
> and no realistic user would write it in a `mutate()` call. If this becomes a
> concern, add a third check: `intersect(mutated_names, surveycore::SURVEYCORE_DOMAIN_COL)`.

---

#### Task 6.2b — Update mutate snapshot

Run `devtools::test("test-mutate")`. Expect a snapshot failure: the existing
snapshot in `tests/testthat/_snaps/mutate.md` covers the old
`surveytidy_warning_mutate_design_var` message text. The new split warnings
produce different message text.

```r
testthat::snapshot_review()
```

Review each diff individually and approve the updated warning message(s) for
`surveytidy_warning_mutate_weight_col` and `surveytidy_warning_mutate_structural_var`.
Do not run `snapshot_accept()` blindly — inspect each change before approving.

Confirm `devtools::test("test-mutate")` passes after approving.

---

#### Task 6.3 — Add pre-attachment step (step 2)

In `mutate.survey_base()`, after step 1 and before the `dplyr::mutate()` call
(currently "Step 3"):

```r
# Step 2: Pre-attach label attrs from @metadata so recode functions can
# read them via attr(x, "labels") / attr(x, "label").
augmented_data <- .attach_label_attrs(.data@data, .data@metadata)
```

Update "Step 3" to call `dplyr::mutate()` on `augmented_data` instead of
`.data@data`. (Keep the variable name `base_data` and `new_data` consistent
with existing code — assign `augmented_data` from `.data@data` or `rowwise()`
wrapping as appropriate.)

Note: in rowwise mode, `base_data` is `dplyr::rowwise(augmented_data, ...)` not
`dplyr::rowwise(.data@data, ...)`.

---

#### Task 6.4 — Add post-detection and strip steps (steps 4–5)

After the `dplyr::mutate()` call produces `new_data`, add:

```r
# Step 4: Post-detect labelled outputs and update @metadata.
mutated_names <- names(rlang::quos(...))
updated_metadata <- .extract_labelled_outputs(new_data, .data@metadata, mutated_names)

# Step 5: Strip haven attrs and surveytidy_recode attr from @data.
new_data <- .strip_label_attrs(new_data)
```

Note: `mutated_names` is already computed earlier in the function (used for the
design-var warning checks). Reuse the existing variable.

---

#### Task 6.5 — [SUPERSEDED by Task 6.6]

> This task's implementation ordering is incorrect — the transformation log must
> capture `surveytidy_recode` attrs *before* the strip step, which is resolved
> in Task 6.6. **Skip this task entirely and implement Task 6.6 instead.**

---

#### Task 6.6 — Revised ordering for transformation log

Actual implementation order within `mutate.survey_base()`:

```
Step 4: Post-detect → updated_metadata (extracts labels from new_data)
Step 5a: Capture recode attrs for transformation log:
         recode_descs <- lapply(mutated_names, function(col) {
           attr(new_data[[col]], "surveytidy_recode")$description
         })
         names(recode_descs) <- mutated_names
Step 5b: Strip → new_data (removes haven attrs + surveytidy_recode)
Step 6:  Re-attach protected cols (existing, unchanged)
Step 7:  Update visible_vars (existing, unchanged)
Step 8:  Transformation log (expanded):
         for (col in mutated_names) {
           q <- mutations[[col]]
           desc <- recode_descs[[col]]  # NULL if no .description or not a recode call
           if (!is.null(q) && !is.null(desc)) {
             # Only log recode calls (desc is non-NULL only when surveytidy_recode
             # attr was set, which happens only when a surveytidy arg was used)
             .data@metadata@transformations[[col]] <- list(
               fn          = as.character(rlang::call_name(rlang::quo_get_expr(q))),
               source_cols = setdiff(all.vars(rlang::quo_squash(q)), col),
               expr        = deparse(rlang::quo_squash(q)),
               output_type = if (is.factor(new_data[[col]])) "factor" else "vector",
               description = desc
             )
           } else if (!is.null(q) && col %in% new_cols) {
             # Non-recode new column: keep existing plain-text log
             .data@metadata@transformations[[col]] <- rlang::quo_text(q)
           }
         }
Step 9: Assign @data and updated @metadata (expanded from just @data):
         .data@data <- new_data
         .data@metadata <- updated_metadata
         .data
```

Note: `updated_metadata` from step 4 already has labels extracted. Step 8
adds transformation records to it. The single final assignment of `@metadata`
happens once at step 9.

---

#### Task 6.7 — Run tests; confirm sections 1, 2, 2b pass

```r
devtools::test("test-recode")
```

All section 1, 2, and 2b tests should now pass. test_invariants() checks run
automatically (without the recode-attr invariant yet — see Task 6.8).

---

#### Task 6.8 — Add surveytidy_recode attr check to test_invariants()

Now that the strip step (Task 6.4, step 5 in `mutate.survey_base()`) is wired,
extend `test_invariants()` in `tests/testthat/helper-test-data.R`.

After the last existing assertion (the `visible_vars` check), add inside
`test_invariants()`:

```r
# Invariant 7: surveytidy_recode attr must be stripped before @data is stored.
# .strip_label_attrs() in mutate.survey_base() must remove this attr from every
# column. Any failure here is a regression in the strip step.
for (col in names(design@data)) {
  testthat::expect_null(
    attr(design@data[[col]], "surveytidy_recode"),
    label = paste0(
      "@data[[\"", col, "\"]] must not carry surveytidy_recode attr"
    )
  )
}
```

Run `devtools::test()` to confirm all existing tests still pass with the new
invariant active. Any failure here is a regression in the strip step — fix
before proceeding.

---

### STEP 7 — Complete remaining test sections

---

#### Task 7.1 — Write sections 9, 10, 11, 12 (domain preservation, backward compat, .description, snapshots)

Section 9 (domain preservation):

```r
test_that("domain column preserved through mutate + each recode function [all designs]", {
  designs <- make_all_designs(seed = 42)
  for (d in designs) {
    d_filtered <- filter(d, y1 > 40)
    domain_before <- d_filtered@data[[surveycore::SURVEYCORE_DOMAIN_COL]]
    result <- mutate(d_filtered,
      cat = case_when(y1 > 50 ~ "high", .default = "low",
                      .label = "Category"))
    test_invariants(result)
    expect_identical(
      result@data[[surveycore::SURVEYCORE_DOMAIN_COL]],
      domain_before
    )
  }
})
```

Section 10 (backward compatibility — shadowing):

```r
test_that("case_when() with no surveytidy args is identical to dplyr::case_when()", {
  x <- 1:10
  st_out <- case_when(x > 5 ~ "high", .default = "low")
  dp_out <- dplyr::case_when(x > 5 ~ "high", .default = "low")
  expect_identical(st_out, dp_out)
  expect_null(attr(st_out, "surveytidy_recode"))
})

test_that("if_else() with no surveytidy args is identical to dplyr::if_else()", {
  x <- 1:10
  st_out <- if_else(x > 5, "high", "low")
  dp_out <- dplyr::if_else(x > 5, "high", "low")
  expect_identical(st_out, dp_out)
})

test_that("na_if() with no surveytidy args is identical to dplyr::na_if()", {
  x <- c(1, 2, NA, 4)
  st_out <- na_if(x, 2)
  dp_out <- dplyr::na_if(x, 2)
  expect_identical(st_out, dp_out)
})
```

Section 11 (.description argument for all 6 functions):

```r
test_that(".description is stored in @metadata@transformations$description for all 6 functions [all designs]", {
  designs <- make_all_designs(seed = 42)
  for (d in designs) {
    # case_when
    r1 <- mutate(d, cat = case_when(
      y1 > 50 ~ "high", .default = "low",
      .description = "High vs. low y1"
    ))
    test_invariants(r1)
    expect_identical(r1@metadata@transformations$cat$description, "High vs. low y1")

    # replace_when
    r2 <- mutate(d, cat = replace_when(
      y1, y1 > 50 ~ "high", .default = "low",
      .description = "replace_when desc"
    ))
    test_invariants(r2)
    expect_identical(r2@metadata@transformations$cat$description, "replace_when desc")

    # if_else
    r3 <- mutate(d, cat = if_else(
      y1 > 50, "high", "low",
      .description = "if_else desc"
    ))
    test_invariants(r3)
    expect_identical(r3@metadata@transformations$cat$description, "if_else desc")

    # na_if
    r4 <- mutate(d, cat = na_if(y1, 0L, .description = "na_if desc"))
    test_invariants(r4)
    expect_identical(r4@metadata@transformations$cat$description, "na_if desc")

    # recode_values
    r5 <- mutate(d, cat = recode_values(
      y1, from = c(1L, 2L), to = c("low", "low"),
      .description = "recode_values desc"
    ))
    test_invariants(r5)
    expect_identical(r5@metadata@transformations$cat$description, "recode_values desc")

    # replace_values
    r6 <- mutate(d, cat = replace_values(
      y1, from = 0L, to = NA_integer_,
      .description = "replace_values desc"
    ))
    test_invariants(r6)
    expect_identical(r6@metadata@transformations$cat$description, "replace_values desc")
  }
})

test_that(".description = NULL stores description = NULL in transformations record [all designs]", {
  designs <- make_all_designs(seed = 42)
  for (d in designs) {
    result <- mutate(d, cat = case_when(
      y1 > 50 ~ "high", .default = "low",
      .label = "Category"  # .description absent → NULL
    ))
    test_invariants(result)
    expect_null(result@metadata@transformations$cat$description)
  }
})

test_that("no surveytidy args → no surveytidy_recode attr on @data (backward compat, all shadowed fns)", {
  d <- make_all_designs(seed = 42)$taylor

  # case_when via dplyr directly
  r1 <- mutate(d, cat = dplyr::case_when(y1 > 50 ~ "high", .default = "low"))
  test_invariants(r1)
  expect_null(attr(r1@data$cat, "surveytidy_recode"))

  # if_else with no surveytidy args (surveytidy's if_else delegates to dplyr)
  r2 <- mutate(d, cat = if_else(y1 > 50, "high", "low"))
  test_invariants(r2)
  expect_null(attr(r2@data$cat, "surveytidy_recode"))

  # na_if with no surveytidy args
  r3 <- mutate(d, cat = na_if(y1, 0L))
  test_invariants(r3)
  expect_null(attr(r3@data$cat, "surveytidy_recode"))
})
```

Section 12 (error snapshots — one per class in §XI):

```r
test_that("error snapshots for all recode error classes", {
  d <- make_all_designs(seed = 42)$taylor

  expect_snapshot(error = TRUE,
    mutate(d, cat = case_when(y1 > 50 ~ "high", .label = c("a", "b"))))
  expect_snapshot(error = TRUE,
    mutate(d, cat = case_when(y1 > 50 ~ 1L, .value_labels = c(1L, 0L))))
  expect_snapshot(error = TRUE,
    mutate(d, cat = case_when(y1 > 50 ~ "hi", .factor = TRUE, .label = "x")))
  expect_snapshot(error = TRUE,
    mutate(d, cat = recode_values(y1, from = 1, to = 2, .use_labels = TRUE)))
  expect_snapshot(error = TRUE,
    mutate(d, cat = recode_values(y1, .use_labels = FALSE)))
  expect_snapshot(error = TRUE,
    mutate(d, cat = recode_values(y1, from = 99L, to = "other", .unmatched = "error")))
  expect_snapshot(error = TRUE,
    mutate(d, cat = case_when(y1 > 50 ~ "high", .description = c("a", "b"))))
  # surveytidy_warning_mutate_structural_var
  expect_snapshot(warning = TRUE,
    mutate(d, strata = strata + 1L))
  # surveytidy_warning_mutate_weight_col
  expect_snapshot(warning = TRUE,
    mutate(d, wt = wt * 2))
})
```

Run `devtools::test("test-recode")` — all sections pass.

---

### STEP 8 — Quality gate pass

---

#### Task 8.1 — Run devtools::document()

```r
devtools::document()
```

Confirm NAMESPACE reflects the 6 new exports. Confirm `man/case_when.Rd` (and
other `@rdname case_when` entries) were generated. No errors or warnings.

---

#### Task 8.2 — Run devtools::check()

```r
devtools::check()
```

Target: 0 errors, 0 warnings, ≤2 notes.

Expected notes (pre-approved):
- `no visible binding for global variable` — standard for tidy NSE code
- `checking CRAN incoming feasibility` — informational

If any unexpected NOTE appears, resolve before opening PR.

---

#### Task 8.3 — Run air format

```r
air format .
```

Commit formatted files before opening PR.

---

### STEP 9 — Changelog entry

Create `changelog/phase-0.6/feature-recode.md` before opening the PR. Follow the
existing changelog format in the project.

---

## Notes (to be filled during Task 0.1 and 0.2)

### GAP A: dplyr unmatched-values condition class (resolved during Task 0.1)

> _Fill in after reading dplyr 1.2.0 source:_
>
> Verified class name: `____________`
>
> Verification method: ____________
>
> If no class available: use `grepl("unmatched", conditionMessage(e))` guard
> (note fragility; document in code comment)

### GAP B: surveycore set_val_labels export (resolved during Task 0.2)

> _Fill in after checking surveycore NAMESPACE:_
>
> Exported: yes / no
>
> If no: use `design@metadata@value_labels[[col]] <- c(...)` in test setup.

---

## Post-plan notes

Review the PR map carefully before starting implementation. This is a single
tightly-coupled PR — splitting it would require each intermediate state to be
consistent, but the mutate.R changes depend on recode.R functions, and the tests
for recode.R functions depend on mutate.R accepting them inside `mutate()`.

Run Stage 2 adversarial review of this plan in a new session before handing off
to `/r-implement`.
