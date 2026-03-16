---
Version: 1.0
Date: 2026-03-16
Status: Draft
---

# Implementation Plan: Transformation Functions

## Overview

This plan delivers five vector-level transformation functions (`make_factor`,
`make_dicho`, `make_binary`, `make_rev`, `make_flip`) as specified in
`plans/spec-transform.md` v0.4. All five functions operate on plain R vectors
and integrate with `mutate.survey_base()` via the existing `surveytidy_recode`
attribute protocol — no new `mutate()` machinery required. A single PR
completes the full feature, including a structural update to the
`surveytidy_recode` attribute in all Phase 0.6 recode files (7 files;
quality gate).

## PR Map

- [ ] PR 1: `feature/transformation` — Implement `make_factor()`,
  `make_dicho()`, `make_binary()`, `make_rev()`, `make_flip()`; update
  `mutate.survey_base()` step 8; expand `surveytidy_recode` structure in
  Phase 0.6 recode files (full file list per plan-review Pass 1 Issues 1–2)

---

## PR 1: Transformation Functions

**Branch:** `feature/transformation`
**Depends on:** none (cuts from `develop`)

**Files:**
- `plans/error-messages.md` — 10 new error classes + 3 new warning classes
  (updated before any source code or tests are written)
- `R/transform.R` — all 5 transformation functions + 2 internal helpers (new)
- `tests/testthat/test-transform.R` — all 59+ test cases (new)
- `R/mutate.R` — step 8 updated to read `surveytidy_recode$fn` and
  `surveytidy_recode$var` from the attr (spec §XI quality gate requirement)
- `R/recode-values.R` — `surveytidy_recode` expanded to `list(fn, var, description)`;
  single-input function (quality gate requirement)
- `R/na-if.R` — same expansion; single-input
- `R/replace-when.R` — same expansion; single-input
- `R/replace-values.R` — same expansion; single-input
- `R/case-when.R` — same expansion; multi-input (`var = NULL`)
- `R/if-else.R` — same expansion; multi-input (`var = NULL`)
- `R/utils.R` — `.wrap_labelled()` signature updated to accept `fn` and `var`;
  all 6 callers updated to pass those arguments through
- `changelog/phase-transformation/feature-transformation.md` — created last, before opening PR

**Acceptance criteria:**
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and `man/` in sync
- [ ] `devtools::test()` 0 failures, 0 skips
- [ ] Line coverage ≥ 98% on `R/transform.R`
- [ ] Line coverage on modified recode files does not decrease after structural
  update; new `fn`/`var` fields verified in at least one test per updated recode
  function (confirmed in Task 31)
- [ ] Existing recode tests pass 0 failures after structural update; any snapshot
  diffs from recode attr changes reviewed with `snapshot_review()` before opening PR
  (Task 31)
- [ ] All 10 new error classes in `plans/error-messages.md`
- [ ] All 3 new warning classes in `plans/error-messages.md`
- [ ] Every error class tested: `expect_error(..., class=)` +
  `expect_snapshot(error=TRUE, ...)`
- [ ] Every warning class tested: `expect_warning(..., class=)`
- [ ] `test_invariants(result)` is first assertion in tests 56–59 (all
  `mutate()` integration tests)
- [ ] Domain column preservation tested (test 58b — folded into test 58 loop)
- [ ] All 3 design types tested in integration tests via `make_all_designs()`
- [ ] `attr(result, "surveytidy_recode")` set on every code path through all
  5 functions; structure is `list(fn, var, description)` — no `call` field
- [ ] `surveytidy_recode$var` captures correct column name in `across()`
  workflow (test 59)
- [ ] `mutate.survey_base()` step 8 reads `surveytidy_recode$fn` and
  `surveytidy_recode$var` from the attr; verified by integration tests 56–57
- [ ] `@family transformation` on all 5 exported functions
- [ ] All `@examples` blocks that use `mutate()` begin with `library(dplyr)`
- [ ] `air format R/transform.R` run before commit
- [ ] Changelog entry committed on this branch at `changelog/phase-transformation/feature-transformation.md`

**Notes:**

### Argument validation — use `.validate_transform_args()` (defined at top of `transform.R`)
The spec says "validated by `.validate_label_args()`" but also specifies
*different* error classes (`surveytidy_error_make_factor_bad_arg` for
`make_factor()`; `surveytidy_error_transform_bad_arg` for the other four).
The existing `.validate_label_args()` in `utils.R` raises
`surveytidy_error_recode_label_not_scalar` — the wrong class for transform
functions.

Define a thin internal helper at the **top of `transform.R`** (before `make_factor()`):

```r
.validate_transform_args <- function(label, description, error_class) {
  if (!is.null(label) && !rlang::is_string(label)) {
    cli::cli_abort(
      c("x" = "{.arg .label} must be a single character string or {.code NULL}.",
        "i" = "Got {.cls {class(label)}} of length {length(label)}."),
      class = error_class
    )
  }
  if (!is.null(description) && !rlang::is_string(description)) {
    cli::cli_abort(
      c("x" = "{.arg .description} must be a single character string or {.code NULL}.",
        "i" = "Got {.cls {class(description)}} of length {length(description)}."),
      class = error_class
    )
  }
}
```

All four transform functions (`make_dicho()`, `make_binary()`, `make_rev()`,
`make_flip()`) call `.validate_transform_args(.label, .description, "surveytidy_error_transform_bad_arg")`.
`make_factor()` uses inline validation for its extra scalar args (`ordered`,
`drop_levels`, `force`, `na.rm`) but also calls `.validate_transform_args()` for
`.label`/`.description` with `"surveytidy_error_make_factor_bad_arg"`.

Do NOT put this helper in `utils.R` — it is used only in `transform.R`.

### `var_name` capture — always inline, never abstract
Per spec §II, this line must appear early in every user-facing function body,
before `x` is evaluated or modified:

```r
var_name <- tryCatch(
  dplyr::cur_column(),
  error = function(e) rlang::as_label(rlang::enquo(x))
)
```

`rlang::enquo(x)` must be evaluated in the function's own frame. Do not
abstract this into a helper. There is no `call_expr` capture — `call` is not
part of the `surveytidy_recode` structure (spec §II and §XI). The `expr` field
in `@metadata@transformations` is derived by `mutate()` from the quosure, not
stored in the attr.

### `.set_recode_attrs()` and `.strip_first_word()` — `transform.R` only
Both helpers are used exclusively inside `R/transform.R`. Define them at the
top of the file, before `make_factor()`. Do NOT put them in `utils.R`.

### `make_factor()` — factor pass-through + `ordered`/`drop_levels`
For factor input, apply both `ordered` and `drop_levels`:
- `ordered = TRUE` on an unordered factor → `factor(x, levels=levels(x), ordered=TRUE)`
- `ordered = FALSE` on an ordered factor → `factor(x, levels=levels(x), ordered=FALSE)`
- `drop_levels = TRUE` → `droplevels()` after the `ordered` coercion

A single call like `factor(x, levels=levels(x), ordered=ordered)` followed
by `if (drop_levels) droplevels(result)` handles all four combinations.

### `make_factor()` — numeric `force = TRUE` path
Per spec (as corrected from "return early"): call `.set_recode_attrs()`,
THEN return. The label-completeness check is skipped because `labels_attr`
is NULL, not because of an early `return()`. Structure:

```r
if (is.null(labels_attr) && isTRUE(force)) {
  cli::cli_warn(...)
  result <- as.factor(x)
  result <- .set_recode_attrs(result, ...)
  return(result)
}
```

### `make_dicho()` — no 2-level short-circuit
Rule 5 was removed from the spec. All inputs go through the full
qualifier-stripping path (`.strip_first_word()` on every level). A 2-level
factor with single-word levels (e.g., `c("Agree", "Disagree")`) returns
those words unchanged — `.strip_first_word()` returns single-word labels
unchanged.

### `make_binary()` encoding
Default (`flip_values = FALSE`): first level → 1L, second → 0L.
Formula: `result <- 2L - as.integer(dicho)`.
With `flip_values = TRUE`: `result <- as.integer(dicho) - 1L`.

### `surveytidy_recode` structure — 3-field list (no `call`)
The authoritative structure is defined in spec §II and confirmed in §XI:

```r
list(
  fn          = "make_factor",  # hardcoded string per function
  var         = var_name,       # column name via cur_column() or enquo fallback
  description = .description    # user-supplied string or NULL
)
```

There is NO `call` field. Spec §III–VII output contract tables still show
`list(fn, var, call, description)` — this is a stale inconsistency in the spec
that was not fully cleaned up; §II and §XI are authoritative.

### `surveytidy_recode` structure update in recode files
The quality gate requires expanding the `surveytidy_recode` attribute in Phase
0.6 recode files from `list(description = .description)` to
`list(fn, var, description)` — see spec §X. The structure differs by function
type:

- **Single-input functions** (`na_if`, `replace_when`, `replace_values`,
  `recode_values`): add `var_name` capture at top; set `var = var_name`.
- **Multi-input functions** (`case_when`, `if_else`): skip `var_name` capture;
  set `var = NULL` — `mutate()` derives source columns via quosure `all.vars()`
  fallback.

The conditional `if (!is.null(.description))` guard remains unchanged; this PR
expands the structure within existing guarded sites only.

---

## Tasks (TDD order, one action each)

### Pre-implementation

**Task 1: Update `plans/error-messages.md`**
Add 10 error classes and 3 warning classes. Verify count before proceeding.

Errors (add to Errors table):

| Class | Source file | Trigger |
|-------|-------------|---------|
| `surveytidy_error_make_factor_bad_arg` | `R/transform.R` | `.label`/`.description` not `character(1)`, or `ordered`/`drop_levels`/`force`/`na.rm` not `logical(1)` |
| `surveytidy_error_make_factor_unsupported_type` | `R/transform.R` | `x` not numeric, haven_labelled, factor, or character |
| `surveytidy_error_make_factor_no_labels` | `R/transform.R` | `x` is numeric/haven_labelled, `attr(x, "labels")` is NULL, `force = FALSE` |
| `surveytidy_error_make_factor_incomplete_labels` | `R/transform.R` | One or more non-NA observed values lack a label entry |
| `surveytidy_error_make_dicho_too_few_levels` | `R/transform.R` | Fewer than 2 levels remain after `.exclude` |
| `surveytidy_error_make_dicho_collapse_ambiguous` | `R/transform.R` | First-word stripping does not yield exactly 2 unique stems |
| `surveytidy_error_make_rev_not_numeric` | `R/transform.R` | `typeof(x)` not `"double"` or `"integer"` |
| `surveytidy_error_make_flip_not_numeric` | `R/transform.R` | `typeof(x)` not `"double"` or `"integer"` |
| `surveytidy_error_make_flip_missing_label` | `R/transform.R` | `label` missing or not `character(1)` |
| `surveytidy_error_transform_bad_arg` | `R/transform.R` | `.label`/`.description` not `character(1)`, or boolean flag not `logical(1)`, in `make_dicho()`, `make_binary()`, `make_rev()`, or `make_flip()` |

Warnings (add to Warnings table):

| Class | Source file | Trigger |
|-------|-------------|---------|
| `surveytidy_warning_make_factor_forced` | `R/transform.R` | `force = TRUE` coerces numeric without labels via `as.factor()` |
| `surveytidy_warning_make_dicho_unknown_exclude` | `R/transform.R` | A name in `.exclude` not found in levels of `x` |
| `surveytidy_warning_make_rev_all_na` | `R/transform.R` | All values in `x` are `NA` |

---

### `R/transform.R` — skeleton

**Task 2: Create `R/transform.R` skeleton**
Create the file with:
- File header comment (purpose + list of functions defined)
- `.validate_transform_args(label, description, error_class)` — full
  implementation (see Argument validation note above); placed first so all
  5 functions can call it
- `.strip_first_word(label)` — full implementation (see spec §II + §IV)
- `.set_recode_attrs(result, label, labels, fn, var, description)` —
  full implementation: sets `attr(result, "label")`, `attr(result, "labels")`,
  `attr(result, "surveytidy_recode")` as `list(fn, var, description)`
- Stub functions for all 5 exports: empty bodies returning `NULL`, with full
  roxygen (incl. `@export`, `@family transformation`, `@param`, `@return`,
  `@examples` with `library(dplyr)` where needed)

**Task 3: Run `devtools::document()`**
Verify `man/make_factor.Rd`, `man/make_dicho.Rd`, `man/make_binary.Rd`,
`man/make_rev.Rd`, `man/make_flip.Rd` are created. Fix any roxygen errors.

---

### `make_factor()` — TDD

**Task 4: Write failing tests 1–11b (happy paths + label inheritance)**

Tests:
```
# 1.  make_factor() — haven_labelled: levels ordered by numeric value
# 2.  make_factor() — plain numeric with labels attr: correct level order
# 3.  make_factor() — factor pass-through: levels preserved
# 3a. make_factor() — ordered = TRUE on factor pass-through → ordered factor
# 3b. make_factor() — ordered = FALSE on ordered factor → removes ordered class
# 4.  make_factor() — character input: alphabetical levels
# 5.  make_factor() — drop_levels = FALSE: unobserved levels included
# 6.  make_factor() — ordered = TRUE: ordered factor returned
# 7.  make_factor() — na.rm = TRUE with na_values: special values become NA
# 8.  make_factor() — na.rm = TRUE with na_range: range values become NA
# 9.  make_factor() — .label overrides inherited variable label attr
# 10. make_factor() — .description sets surveytidy_recode attr
# 11. make_factor() — label inherited from attr(x, "label") when .label = NULL
# 11b.make_factor() — label falls back to var_name when no attr + .label = NULL
```

Run `devtools::test("test-transform")` — confirm all 14 tests fail.

**Task 5: Implement `make_factor()` happy paths**
- Inline `var_name` capture at top
- Inline arg validation for `ordered`, `drop_levels`, `force`, `na.rm`
  (each must be `logical(1)`; error class: `surveytidy_error_make_factor_bad_arg`)
- Call `.validate_transform_args(.label, .description, "surveytidy_error_make_factor_bad_arg")`
- Input dispatch: factor → pass-through; character → `factor(x)`;
  numeric/haven_labelled → label dispatch
- `drop_levels`: `if (drop_levels) result <- droplevels(result)`
- `.label` inheritance: `.label` → `attr(x, "label")` → `var_name`
- `.set_recode_attrs()` call at the end of every code path

**Task 6: Run `devtools::test("test-transform")` for tests 1–11b**
All 14 tests must pass. Fix any failures before proceeding.

**Task 7: Write failing tests 12–14c (error paths + `force`)**

Tests:
```
# 12.  make_factor() — error: unsupported type (list, logical)
# 12b. make_factor() — error: bad arg type (ordered = "yes", drop_levels = 2L)
# 13.  make_factor() — error: no labels (plain numeric, labels=NULL, force=FALSE)
# 14.  make_factor() — error: incomplete labels (one value missing a label)
# 14b. make_factor() — force = TRUE: numeric without labels warns + coerces
# 14c. make_factor() — force = TRUE: warning class is
#                      surveytidy_warning_make_factor_forced
```

Run `devtools::test("test-transform")` — confirm these 6 tests fail.

**Task 8: Implement `make_factor()` error paths and `force = TRUE`**
- Error for unsupported type: `surveytidy_error_make_factor_unsupported_type`
- Error for no labels: `surveytidy_error_make_factor_no_labels`
- Error for incomplete labels: `surveytidy_error_make_factor_incomplete_labels`
- `force = TRUE` path: warn `surveytidy_warning_make_factor_forced`, coerce
  via `as.factor(x)`, call `.set_recode_attrs()`, return

**Task 9: Run `devtools::test("test-transform")` for tests 1–14c**
All 20 tests must pass. Run `expect_snapshot()` — create snapshots for all
error tests. Fix any failures.

---

### `make_dicho()` — TDD

**Task 10: Write failing tests 15–26d**

Tests:
```
# 15.  make_dicho() — 4-level Likert auto-collapses to 2 stems
# 16.  make_dicho() — already 2-level: single-word labels pass through
# 17.  make_dicho() — .exclude sets middle level to NA
# 18.  make_dicho() — .exclude: excluded rows become NA in the 2-level result
# 19.  make_dicho() — flip_levels reverses level order
# 20.  make_dicho() — warning: unknown .exclude level
# 21.  make_dicho() — error: too few levels after .exclude
# 22.  make_dicho() — error: collapse ambiguous (4 distinct stems)
# 23.  make_dicho() — single-word labels: no stripping (returned unchanged)
# 24.  make_dicho() — non-standard first words stripped ("Always agree" → "Agree")
# 25.  make_dicho() — level order preserved from original labels, not alphabetical
# 26.  make_dicho() — .label and .description set attrs on result
# 26b. make_dicho() — label falls back to var_name when no attr + .label = NULL
# 26c. make_dicho() — error: bad arg type (.label = 123)
# 26d. make_dicho() — error: bad arg type (flip_levels = "yes")
```

Run `devtools::test("test-transform")` — confirm all 15 tests fail.

**Task 11: Implement `make_dicho()`**
- Inline `var_name` capture
- Inline arg validation for `flip_levels` (must be `logical(1)`;
  error class: `surveytidy_error_transform_bad_arg`)
- Call `.validate_transform_args(.label, .description, "surveytidy_error_transform_bad_arg")`
- Input normalization: call `make_factor(x)` unless `is.factor(x)`
- `.exclude` application loop: for each name, if found set to NA and drop level,
  else warn `surveytidy_warning_make_dicho_unknown_exclude`
- Level count check: error `surveytidy_error_make_dicho_too_few_levels` if < 2
- First-word collapse via `.strip_first_word()`; collect unique stems;
  error `surveytidy_error_make_dicho_collapse_ambiguous` if not exactly 2
- Map levels to stems, build 2-level factor preserving original level order
- `flip_levels`: `factor(result, levels = rev(levels(result)))`
- `.label` inheritance + `.set_recode_attrs()` at end

**Task 12: Run `devtools::test("test-transform")` for tests 1–26d**
All 35 tests must pass. Create snapshots for error tests. Fix any failures.

---

### `make_binary()` — TDD

**Task 13: Write failing tests 27–32d**

Tests:
```
# 27.  make_binary() — basic 0/1: first level → 1, second → 0
# 28.  make_binary() — flip_values: first level → 0, second → 1
# 29.  make_binary() — .exclude passed through to make_dicho
# 30.  make_binary() — NA propagates to NA_integer_
# 31.  make_binary() — attr(result, "labels") reflects 0/1 mapping
# 32.  make_binary() — .label and .description set attrs on result
# 32b. make_binary() — label falls back to var_name when no attr + .label = NULL
# 32c. make_binary() — error: bad arg type (.label = 123)
# 32d. make_binary() — error: bad arg type (flip_values = "yes")
```

Run `devtools::test("test-transform")` — confirm all 9 tests fail.

**Task 14: Implement `make_binary()`**
- Inline `var_name` capture
- Inline arg validation for `flip_values` (must be `logical(1)`;
  error class: `surveytidy_error_transform_bad_arg`)
- Call `.validate_transform_args(.label, .description, "surveytidy_error_transform_bad_arg")`
- Call `make_dicho(x, .exclude = .exclude)` — errors from `make_dicho()`
  propagate unchanged
- Encode: default `2L - as.integer(dicho)`; flipped `as.integer(dicho) - 1L`
- `attr(result, "labels")`: named integer vector from level names of dicho output
- NA → `NA_integer_`
- `.label` inheritance + `.set_recode_attrs()` at end

**Task 15: Run `devtools::test("test-transform")` for tests 1–32d**
All 44 tests must pass. Create snapshots for error tests. Fix any failures.

---

### `make_rev()` — TDD

**Task 16: Write failing tests 33–41**

Tests:
```
# 33.  make_rev() — reverses 1–4 scale correctly
# 34.  make_rev() — remaps value labels: strings stay tied to concept
# 35.  make_rev() — .label overrides inherited variable label
# 35b. make_rev() — label falls back to var_name when no attr + .label = NULL
# 36.  make_rev() — all-NA input: returns all-NA + warning
# 37.  make_rev() — error: non-numeric input (factor, character)
# 38.  make_rev() — NA values in input remain NA in output
# 39.  make_rev() — .description sets surveytidy_recode attr
# 39b. make_rev() — error: bad arg type (.label = 123)
# 40.  make_rev() — labels sorted ascending by new value after reversal
# 41.  make_rev() — 2–5 scale: range preserved (not shifted to 1–4)
```

Run `devtools::test("test-transform")` — confirm all 11 tests fail.

**Task 17: Implement `make_rev()`**
- Inline `var_name` capture
- Call `.validate_transform_args(.label, .description, "surveytidy_error_transform_bad_arg")`
- `typeof()` check: error `surveytidy_error_make_rev_not_numeric`
- All-NA short-circuit: warn `surveytidy_warning_make_rev_all_na`, preserve
  `attr(x, "labels")` unchanged, call `.set_recode_attrs()`, return
- Reversal: `min(x, na.rm=TRUE) + max(x, na.rm=TRUE) - x`
- Label remapping: `m - old_value` for each label value; sort by new value
- `.label` inheritance + `.set_recode_attrs()` at end

**Task 18: Run `devtools::test("test-transform")` for tests 1–41**
All 55 tests must pass. Create snapshots for error tests. Fix any failures.

---

### `make_flip()` — TDD

**Task 19: Write failing tests 42–50**

Tests:
```
# 42. make_flip() — values unchanged, label strings reversed
# 43. make_flip() — variable label set to required `label` arg
# 44. make_flip() — attr(result, "labels") has reversed string-to-value mapping
# 45. make_flip() — input with no value labels: only variable label changes
# 46. make_flip() — error: non-numeric input
# 47. make_flip() — error: label missing
# 48. make_flip() — error: label not character(1) (numeric, NULL)
# 49. make_flip() — .description sets surveytidy_recode attr
# 49b.make_flip() — error: bad arg type (.description = 123)
# 50. make_flip() — all-NA input: values unchanged, labels reversed, no warning
```

Run `devtools::test("test-transform")` — confirm all 10 tests fail.

**Task 20: Implement `make_flip()`**
- Inline `var_name` capture
- `label` check: error `surveytidy_error_make_flip_missing_label` if missing
  or not `character(1)` (use `rlang::is_missing(label)` to detect missing arg)
- Call `.validate_transform_args(NULL, .description, "surveytidy_error_transform_bad_arg")`
  (pass `NULL` for `label` since `label` is validated separately above)
- `typeof()` check: error `surveytidy_error_make_flip_not_numeric`
- Values: unchanged (copy `x`)
- Label reversal: `setNames(unname(labels_attr), rev(names(labels_attr)))`
- No all-NA special case
- `.set_recode_attrs(result, label = label, labels = reversed_labels, ...)` at end

**Task 21: Run `devtools::test("test-transform")` for tests 1–50**
All 65 tests must pass. Create snapshots for error tests. Fix any failures.

---

### `surveytidy_recode` attribute tests

**Task 22: Write failing tests 51–53**

Tests:
```
# 51. surveytidy_recode — var field: captures column name via cur_column() in across()
# 52. surveytidy_recode — var field: falls back to symbol name in direct call
# 53. surveytidy_recode — fn field matches function name for all 5 functions
```

For test 51, call `mutate(df, across(c(q1, q2), make_factor))` on a plain
data.frame (not a design object) — `cur_column()` works inside `across()`
in any context.

Run `devtools::test("test-transform")` — confirm tests fail.

**Task 23: Verify `surveytidy_recode` attribute structure**
These 3 tests verify that the `var_name` capture written in Tasks 5, 11, 14, 17,
and 20 (following the Task 2 pattern) is correct. They will only pass if each
earlier task correctly included the `var_name` capture. If any fail, the capture
in that function's implementation task is the bug — fix it there.

---

### Integration tests

**Task 24: Write failing integration tests 54–59**

Tests:
```
# 54. Integration — make_factor() |> make_dicho() vector pipeline
# 55. Integration — make_factor() |> make_rev() pipeline is an error (factor)
# 56. Integration — inside mutate(): @metadata updated correctly for all 5 fns
# 57. Integration — inside mutate(): @data stripped of haven attrs after call
# 58. Integration — inside mutate() on all 3 design types (taylor, replicate,
#                   twophase) + 58b: domain column preserved on filtered design
# 59. Integration — across() workflow: multiple columns, correct var_name per col
```

For tests 56–59, use `make_all_designs(seed = 42)` and a three-design loop.
`test_invariants(result)` must be the first assertion inside each loop body.
Test 54–55 are vector-level (no survey design object) — `test_invariants()`
does NOT apply.

Run `devtools::test("test-transform")` — confirm all tests fail.

**Task 25: Run `devtools::test("test-transform")` for tests 54–59**
These tests exercise existing functions (`mutate.survey_base()`) via the new
transform functions. If any fail, the issue is either in the test data setup
or an attribute-setting bug in the transform functions — fix accordingly.

---

### Full test suite check

**Task 26: Run `devtools::test()` — full package test suite**
All tests must pass, 0 failures, 0 skips.

---

### `mutate.R` update

**Task 27: Update `mutate.survey_base()` step 8 to read from `surveytidy_recode` attr**
In `R/mutate.R`, find the step 8 block where `@metadata@transformations` is populated.
Update it to read `fn` and `source_cols` from `attr(result, "surveytidy_recode")$fn`
and `attr(result, "surveytidy_recode")$var` when that attr is present, rather than
deriving them from the quosure. Columns whose result lacks `surveytidy_recode` are
unaffected. See spec §XI and the Transformation Record Format in spec §II.

Run `devtools::test("test-mutate")` — verify existing mutate tests still pass.

---

### `surveytidy_recode` structure update in recode files

**Task 28: Read all Phase 0.6 recode files — identify all sites
where `attr(result, "surveytidy_recode")` is set**
Files to check: `R/recode-values.R`, `R/case-when.R`, `R/replace-when.R`,
`R/if-else.R`, `R/na-if.R`, `R/replace-values.R`, `R/utils.R` (`.wrap_labelled()`).
Note line numbers, surrounding context, and whether each function is single-input
or multi-input.

**Task 28a: Update `.wrap_labelled()` signature and all callers**
In `R/utils.R`, update `.wrap_labelled()` to accept `fn` and `var` arguments:

```r
.wrap_labelled <- function(result, label, labels, fn, var, description, ...)
```

Inside the function body, update the `attr(result, "surveytidy_recode")` assignment
to `list(fn = fn, var = var, description = description)`. Then update all 6 callers
(in the recode files) to pass `fn` and `var` through:

```r
.wrap_labelled(result, label, labels, fn = "na_if", var = var_name, description = .description)
```

Multi-input callers (`case_when`, `if_else`) pass `var = NULL`.

Run `devtools::test("test-recode")` after this task — verify existing tests still pass.

**Task 29: Update single-input recode functions**
Single-input functions: `na_if`, `replace_when`, `replace_values`, `recode_values`.

In each function body that sets `surveytidy_recode`, add `var_name` capture at the
top (before any `x` modification):

```r
var_name <- tryCatch(
  dplyr::cur_column(),
  error = function(e) rlang::as_label(rlang::enquo(x))
)
```

Update the attribute assignment from:

```r
attr(result, "surveytidy_recode") <- list(description = .description)
```

to:

```r
attr(result, "surveytidy_recode") <- list(
  fn          = "na_if",     # use actual function name per site
  var         = var_name,
  description = .description
)
```

Keep the existing `if (!is.null(.description))` guard unchanged.

**Task 30: Update multi-input recode functions**
Multi-input functions: `case_when`, `if_else`.

These functions receive multiple input columns — `var_name` via `cur_column()`
would return the output column name, not a meaningful source column. Set
`var = NULL` instead and let `mutate()` derive source columns from the quosure:

```r
attr(result, "surveytidy_recode") <- list(
  fn          = "case_when",  # use actual function name per site
  var         = NULL,
  description = .description
)
```

No `var_name` capture needed. Keep the existing `if (!is.null(.description))` guard.

**Task 31: Run `devtools::test()` — verify recode file tests still pass**
If existing snapshots for recode functions capture the `surveytidy_recode`
attribute structure, update them with `testthat::snapshot_review()`. Review
each diff before accepting. Verify `fn` and `var` fields are correct in at least
one test per updated recode function.

---

### Documentation and quality gates

**Task 32: Run `devtools::document()`**
Verify `NAMESPACE` and `man/` files are in sync. Commit `NAMESPACE` + `man/`
changes.

**Task 33: Run `air format R/transform.R`**
Commit the reformatted file if `air` makes any changes.

**Task 34: Verify `@examples` blocks run cleanly**
For each function, check that `@examples` demonstrates both standalone
vector usage and — if `mutate()` is shown — begins with `library(dplyr)`.
Run `devtools::run_examples()` or check via `devtools::check()`.

**Task 35: Run `devtools::check()`**
Target: 0 errors, 0 warnings, ≤2 pre-approved notes. Fix any issues before
proceeding.

**Task 36: Run `covr::package_coverage()` on `R/transform.R`**

```r
covr::file_coverage("R/transform.R", "tests/testthat/test-transform.R")
```

Target: ≥ 98%. If below 98%, identify uncovered lines and add targeted tests.

---

### Changelog

**Task 37: Write `changelog/phase-transformation/feature-transformation.md`**
Document the five new functions, their signatures, and the `surveytidy_recode`
attribute structure they set (`list(fn, var, description)`). Follow the existing
changelog format in `changelog/phase-0.6/`.

---
