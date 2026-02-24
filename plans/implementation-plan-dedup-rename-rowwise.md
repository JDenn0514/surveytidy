# Implementation Plan: Deduplication, Programmatic Renaming, and Row-Wise Operations

**Version:** 1.0
**Date:** 2026-02-24
**Status:** Draft — awaiting review
**Spec:** `plans/spec-dedup-rename-rowwise.md`
**Decisions log:** `plans/claude-decisions-phase-dedup-rename-rowwise.md`

This plan delivers three new dplyr verbs (`distinct()`, `rename_with()`,
`rowwise()`) plus the internal `.apply_rename_map()` refactor, `mutate()`
rowwise routing, `group_by()` `.add=TRUE` rowwise-exit logic, and three
exported predicates (`is_rowwise()`, `is_grouped()`, `group_vars()`). Each
verb ships in its own PR. PRs are independent and may be merged in any order.
See Sequencing section for suggested merge order.

---

## PR Map

- [x] PR 1: `feature/distinct` — `distinct.survey_base()` with physical-subset warning and design-var guard
- [x] PR 2: `feature/rename-with` — `.apply_rename_map()` refactor + `rename_with.survey_base()`
- [ ] PR 3: `feature/rowwise` — `rowwise.survey_base()`, `mutate()` rowwise routing, `group_by()` `.add=TRUE` fix, three exported predicates

---

## PR 1: `distinct()`

**Branch:** `feature/distinct`
**Depends on:** none

**Files:**
- `R/distinct.R` — NEW: `distinct.survey_base()` implementation
- `R/reexports.R` — MODIFIED: add `dplyr::distinct` re-export
- `R/zzz.R` — MODIFIED: register `distinct` S3 method in `.onLoad()`
- `tests/testthat/test-distinct.R` — NEW: all six sections from spec §VI.2
- `changelog/phase-dedup-rename-rowwise/feature-distinct.md` — created last, before opening PR

**Acceptance criteria:**
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and `man/` in sync
- [ ] `devtools::test()` all pass; no skipped tests
- [ ] Line coverage does not drop below 95% (CI enforced); 98%+ is the target; aim for 100%
- [ ] `air format .` run on all modified files
- [ ] All three design types pass via `make_all_designs()` cross-design loop
- [ ] `test_invariants(result)` is the first assertion in every `test_that()` block
- [ ] `surveycore_warning_physical_subset` issued on every call (tested)
- [ ] `surveytidy_warning_distinct_design_var` issued when `...` includes a protected column (tested with `expect_warning(class = "surveytidy_warning_distinct_design_var")`)
- [ ] All `@data` columns retained after `distinct()` regardless of `...` (tested)
- [ ] `visible_vars` unchanged after `distinct()` (tested)
- [ ] `@metadata` unchanged after `distinct()` (`expect_identical`) (tested)
- [ ] `@groups` passed through unchanged (tested)
- [ ] Domain column (`SURVEYCORE_DOMAIN_COL`) preserved in `result@data` (tested)
- [ ] `plans/error-messages.md` updated with `surveytidy_warning_distinct_design_var`
- [ ] Changelog entry written and committed on this branch

**Notes:**

The implementation calls `dplyr::distinct(.data@data, ..., .keep_all = TRUE)` in
all cases. The `.keep_all = FALSE` user argument is silently ignored — this is
intentional and documented in the spec.

**Empty `...` path (survey-safe default):** When `...` is empty, do NOT call
`dplyr::distinct(.data@data, .keep_all = TRUE)` directly — that deduplicates
on all columns including design variables. Instead use:
```r
non_design <- setdiff(names(.data@data), .protected_cols(.data))
dplyr::distinct(.data@data, dplyr::across(dplyr::all_of(non_design)), .keep_all = TRUE)
```
This is the survey-safe default specified in spec §III.3 Rule 3.

**Warn order:** Issue `surveycore_warning_physical_subset` first (always), then
`surveytidy_warning_distinct_design_var` if triggered. Both warnings are issued
before the operation executes.

**Design-var check:** Use `.protected_cols(.data)` (from `R/utils.R`) to detect
whether any column in `...` is a design variable. Resolve `...` to column names
first using `tidyselect::eval_select(rlang::expr(c(...)), .data@data)`, then
intersect with `.protected_cols(.data)`.

**`@groups` and `@metadata` propagation:** Assign `result@groups <- .data@groups`
and carry `@metadata` unchanged — `distinct()` is a pure row operation.

**Registration:** Register in `zzz.R` under a `# ── feature/distinct` section,
following the same pattern as all other Phase 0.5 verbs (register with
`envir = asNamespace("dplyr")`).

**Test edge cases:** Single-row data (returns 1 row, still warns); all-identical
rows (returns exactly 1 row). Build these inline — do not add parameters to
`make_all_designs()`.

---

## PR 2: `rename_with()` + `.apply_rename_map()` refactor

**Branch:** `feature/rename-with`
**Depends on:** none (can develop in parallel with PR 1; merges independently)

**Files:**
- `R/rename.R` — MODIFIED: extract `.apply_rename_map()` from `rename.survey_base()`; add `rename_with.survey_base()`
- `R/reexports.R` — MODIFIED: add `dplyr::rename_with` re-export
- `R/zzz.R` — MODIFIED: register `rename_with` S3 method in `.onLoad()`
- `tests/testthat/test-rename.R` — MODIFIED: add `rename_with()` sections + regression tests for refactored `rename()`
- `tests/testthat/_snaps/rename.md` — UPDATE: snapshot will change because warning message no longer contains `"rename()"` (see note below)
- `changelog/phase-dedup-rename-rowwise/feature-rename-with.md` — created last, before opening PR

**Acceptance criteria:**
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and `man/` in sync
- [ ] `devtools::test()` all pass including updated snapshots
- [ ] Line coverage does not drop below 95% (CI enforced); 98%+ is the target; aim for 100%
- [ ] `air format .` run on all modified files
- [ ] `.apply_rename_map()` extracted; `rename.survey_base()` passes all existing regression tests
- [ ] `_snaps/rename.md` snapshot reviewed and updated (warning text no longer says `"rename()"`)
- [ ] All three design types pass via `make_all_designs()` cross-design loop
- [ ] `test_invariants(result)` is the first assertion in every `test_that()` block
- [ ] Domain column preserved after `rename_with()` when `.cols` excludes it (tested)
- [ ] Domain column unchanged and NOT renamed when `.cols = everything()` (tested — warns, blocks rename)
- [ ] `@groups` updated when renamed column is in `@groups` — both `rename()` and `rename_with()` tested separately:
  - `rename(group_by(d, y1), z = y1)` → `result@groups == "z"`
  - `rename_with(group_by(d, y1), toupper, .cols = y1)` → `result@groups == "Y1"`
- [ ] `visible_vars` old names replaced with new names (tested)
- [ ] `surveytidy_warning_rename_design_var` issued when `.cols` resolves to include design vars (tested)
- [ ] All four `surveytidy_error_rename_fn_bad_output` conditions tested with dual pattern:
  - `.fn` returns non-character output
  - `.fn` returns wrong-length vector
  - `.fn` returns duplicate names
  - `.fn` returns names conflicting with existing non-renamed columns
- [ ] `plans/error-messages.md` updated with `surveytidy_error_rename_fn_bad_output`
- [ ] Changelog entry written and committed on this branch

**Notes:**

**Refactor order within this PR:** Do the `.apply_rename_map()` extraction
first, confirm existing `rename()` tests still pass (run `devtools::test()`),
then add `rename_with()` on top. This order ensures the refactor regression is
caught before new code is layered on.

**Three behavioral changes introduced by the refactor** (spec §IV.1):
1. `@groups` update: `.apply_rename_map()` now replaces old column names with
   new names in `@groups` when a renamed column was grouped. Current `rename()`
   does not touch `@groups`. This is new behavior for `rename()` after refactor.
2. Domain column protection: `.apply_rename_map()` silently removes
   `SURVEYCORE_DOMAIN_COL` from the rename map before any renaming, then warns
   with `surveytidy_warning_rename_design_var`. Current `rename()` would warn
   but still rename. After refactor, the rename is blocked.
3. Warning message text change: current warning says `"! rename() renamed
   design variable(s)..."`. After refactor, the shared helper uses the new
   template (no function name): `"! Renamed design variable{?s} {.field
   {design_cols}}."` — this breaks the existing `_snaps/rename.md` snapshot.
   Update the snapshot intentionally using `testthat::snapshot_review()`.

**S7 validation bypass:** `.apply_rename_map()` must update `@data`, `@variables`,
`@metadata`, and `@groups` atomically. Use `attr(.data, "data") <- new_data`
and `attr(.data, "variables") <- new_vars` etc. to bypass per-assignment S7
validation, then call `S7::validate(.data)` once at the end. This is the same
pattern already used in `rename.survey_base()` — carry it into the extracted helper.

**`rename_with()` `.cols` resolution:** Use `tidyselect::eval_select()` (NOT
`eval_rename()`). `eval_select(rlang::expr(.cols), .data@data)` returns a named
integer vector; `names()` gives the selected column names.

**`.fn` forwarding and formula support:**
```r
.fn       <- rlang::as_function(.fn)
new_names <- rlang::exec(.fn, old_names, !!!rlang::list2(...))
```
`rlang::as_function()` enables `~ toupper(.)`, `\(x) toupper(x)`, and bare
functions. `rlang::exec()` with `!!!rlang::list2(...)` forwards extra args (e.g.,
`rename_with(d, stringr::str_replace, pattern = "y", replacement = "Y")`).

**Error validation order in `rename_with()`:**
1. Resolve `.cols` → `old_names`
2. Apply `.fn` → `new_names`
3. Validate output: not character? wrong length? duplicates? conflicts?
4. Remove domain col from map if present
5. Delegate to `.apply_rename_map()`

**Conflicting names check:** A "conflicting name" is a new name that matches an
existing column that was NOT in the rename selection. Check:
```r
non_renamed <- setdiff(names(.data@data), old_names)
conflicts   <- intersect(new_names, non_renamed)
```
If `length(conflicts) > 0`, raise `surveytidy_error_rename_fn_bad_output`.

---

## PR 3: `rowwise()`, mutate routing, predicates, group_by fix

**Branch:** `feature/rowwise`
**Depends on:** none (can develop in parallel; merges independently)

**Files:**
- `R/rowwise.R` — NEW: `rowwise.survey_base()`, `is_rowwise()`, `is_grouped()`
- `R/mutate.R` — MODIFIED: detect `@variables$rowwise`; route to `dplyr::rowwise()` in rowwise branch; strip `rowwise_df` class after mutation
- `R/group-by.R` — MODIFIED: `group_by()` `.add=TRUE` rowwise-exit logic; `ungroup()` clears rowwise keys; `group_vars.survey_base()`
- `R/reexports.R` — MODIFIED: add `dplyr::rowwise` and `dplyr::group_vars` re-exports
- `R/zzz.R` — MODIFIED: register `rowwise`, `group_vars` S3 methods in `.onLoad()`
- `tests/testthat/test-rowwise.R` — NEW: all six sections from spec §VI.4
- `tests/testthat/test-group-by.R` — NOT modified; new `group_by()`/`ungroup()` rowwise behaviors are tested in `test-rowwise.R` per spec §VI.4. Existing tests must still pass.
- `changelog/phase-dedup-rename-rowwise/feature-rowwise.md` — created last, before opening PR

**Acceptance criteria:**
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and `man/` in sync
- [ ] `devtools::test()` all pass; existing mutate and group-by tests still pass
- [ ] Line coverage does not drop below 95% (CI enforced); 98%+ is the target; aim for 100%
- [ ] `air format .` run on all modified files
- [ ] All three design types pass via `make_all_designs()` cross-design loop
- [ ] `test_invariants(result)` is the first assertion in every `test_that()` block
- [ ] `rowwise.survey_base()` sets `@variables$rowwise = TRUE` and `@variables$rowwise_id_cols` correctly (tested)
- [ ] `is_rowwise()` exported and tested (`is_rowwise(rowwise(d))` → `TRUE`; `is_rowwise(d)` → `FALSE`)
- [ ] `is_grouped()` exported and tested (no sentinel-stripping needed — `@groups` is always clean)
- [ ] `group_vars.survey_base()` registered in `zzz.R`; returns `@groups` (always clean character vector)
- [ ] `rowwise() |> mutate()` computes row-by-row correctly (tested)
- [ ] `rowwise_df` class stripped from `@data` after rowwise mutation (tested via vectorization regression: subsequent `mutate()` is vectorized, not rowwise)
- [ ] `ungroup()` (full) clears `@variables$rowwise` and `@variables$rowwise_id_cols` to `NULL` (tested)
- [ ] `ungroup(d, col)` (partial) does NOT clear rowwise keys — rowwise mode persists (tested)
- [ ] `group_by(.add = FALSE)` clears rowwise keys (tested)
- [ ] `group_by(.add = TRUE)` when rowwise: id cols promoted to `@groups`, rowwise keys cleared (tested — mirrors dplyr)
- [ ] Domain column preserved after `rowwise() |> mutate()` on filtered design (tested)
- [ ] Rowwise state propagated through `filter()`, `select()`, `arrange()` (tested in §VI.4 Section 5)
- [ ] `group_vars(rowwise(d))` → `character(0)` (id_cols not in `@groups`) (tested)
- [ ] `group_vars(group_by(d, group))` → `"group"` (tested)
- [ ] Changelog entry written and committed on this branch

**Notes:**

**Storage convention (decided in decisions log):** Rowwise mode is stored in
`@variables`, not in `@groups`. `@groups` always contains only real column names.
- `@variables$rowwise` — logical `TRUE` when in rowwise mode; `NULL` otherwise
- `@variables$rowwise_id_cols` — character vector of id cols; `character(0)` if none

Detection: `isTRUE(.data@variables$rowwise)`. This is clean — no sentinel
string, no `setdiff()` needed anywhere.

**`mutate()` changes (spec §V.5):**
```r
is_rowwise  <- isTRUE(.data@variables$rowwise)
id_cols     <- .data@variables$rowwise_id_cols %||% character(0)
group_names <- .data@groups

if (is_rowwise) {
  effective_by <- NULL
  base_data <- if (length(id_cols) > 0L) {
    dplyr::rowwise(.data@data, dplyr::all_of(id_cols))
  } else {
    dplyr::rowwise(.data@data)
  }
} else if (is.null(.by) && length(group_names) > 0L) {
  base_data    <- .data@data
  effective_by <- group_names
} else {
  base_data    <- .data@data
  effective_by <- .by
}
```
Change `dplyr::mutate(.data@data, ...)` to `dplyr::mutate(base_data, ...)`.
After the shared `rlang::inject(dplyr::mutate(base_data, ...))` call, apply
`dplyr::ungroup()` only in the rowwise branch via an explicit conditional guard:

```r
new_data <- rlang::inject(dplyr::mutate(base_data, ...))
if (is_rowwise) {
  new_data <- dplyr::ungroup(new_data)
}
```

This strips the `rowwise_df` class from `@data` only when rowwise mode was
active, preventing rowwise semantics from leaking into subsequent operations.

**`group_by()` changes:**
- `.add = FALSE` (default): replace `@groups` with new groups AND clear
  `@variables$rowwise` and `@variables$rowwise_id_cols` to `NULL`.
- `.add = TRUE` when rowwise: promote `@variables$rowwise_id_cols` to
  `@groups` first, then append new groups, then clear rowwise keys:
  ```r
  base_groups <- .data@variables$rowwise_id_cols %||% character(0)
  .data@variables$rowwise         <- NULL
  .data@variables$rowwise_id_cols <- NULL
  .data@groups <- unique(c(base_groups, group_names))
  ```
- `.add = TRUE` when NOT rowwise: existing behavior unchanged
  (`unique(c(.data@groups, group_names))`).

**`ungroup()` changes:**
- Full `ungroup(data)`: existing behavior (clears `@groups`) PLUS set
  `@variables$rowwise <- NULL` and `@variables$rowwise_id_cols <- NULL`.
- Partial `ungroup(data, some_col)`: removes `some_col` from `@groups` only;
  rowwise keys are NOT touched. This matches dplyr behavior where partial
  ungroup does not exit rowwise mode.

**`group_vars.survey_base()`:** Returns `x@groups` directly — no filtering needed
since `@groups` never contains a sentinel. Register in `zzz.R` via
`registerS3method("group_vars", "surveycore::survey_base", ...)` with
`envir = asNamespace("dplyr")`.

**`is_rowwise()` and `is_grouped()`:** Both are plain exported functions in
`R/rowwise.R`. `is_grouped()` is simply `length(design@groups) > 0L` — no
sentinel-stripping needed.

**Test column name:** Use `"group"` (from `make_all_designs()`) throughout the
rowwise test file — there is no `"id_col"` column in the test data. The spec §VI.4
has been updated to use `"group"` consistently.

**Section 5 arrange test:** `rowwise(d) |> arrange(y1)` (no `.by_group = TRUE`)
must pass. Since `@groups` is always clean (no sentinel), `arrange.survey_base()`
does not need modification for `.by_group = FALSE`. Test `arrange()` without
`.by_group` only — that is the rowwise state-propagation assertion.

**`%||%`:** Use `rlang::\`%||\`` for null-coalescing — consistent with other
verbs in the package.

---

## Sequencing and Merge Order

All three PRs can be developed independently in parallel. Suggested merge order:

1. **PR 1 (`feature/distinct`)** — simplest, no dependencies, good warm-up
2. **PR 2 (`feature/rename-with`)** — modifies `rename.R`; snapshot regression
   must be resolved before merge
3. **PR 3 (`feature/rowwise`)** — modifies `mutate.R` and `group-by.R`; existing
   tests for both must stay green

**Rebase before merge:** All three PRs modify `R/reexports.R` and `R/zzz.R`.
Before merging PRs 2 and 3, rebase each branch onto `main` to resolve merge
conflicts in those files.

After all three are merged, run `covr::package_coverage()` to verify ≥ 98% line
coverage across the full package.

---

## Pre-Implementation Checklist

Before starting any PR:

- [ ] `plans/error-messages.md` exists and has stub entries for:
  - `surveytidy_warning_distinct_design_var`
  - `surveytidy_error_rename_fn_bad_output`
  - (all other existing classes already present)
- [ ] All three quality gates from spec §VII are understood
- [ ] `devtools::check()` is clean on `main` before branching
