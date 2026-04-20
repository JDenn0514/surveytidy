# Implementation Plan: feature/joins

**Spec:** `plans/spec-joins.md` v0.3
**Decisions log:** `plans/decisions-joins.md`
**Status:** Approved — ready for `/r-implement`

---

## Overview

This plan delivers the eight dplyr join functions for `survey_base` objects:
`left_join`, `semi_join`, `anti_join`, `bind_cols`, `inner_join`, `right_join`,
`full_join`, and `bind_rows`. All eight live in a single new file `R/joins.R`,
registered in `R/zzz.R`, and re-exported via `R/reexports.R`. Implementation
follows TDD, one function group at a time.

---

## PR Map

- [x] PR 1: `feature/joins` — All eight join functions, shared helpers, tests, registration, re-exports

---

## PR 1: Join functions for survey objects

**Branch:** `feature/joins`
**Depends on:** none (`develop` at v0.3.0.9000)

**Files changed:**
- `R/joins.R` — all 8 join methods + 5 shared internal helpers (new file)
- `tests/testthat/test-joins.R` — ~30 test sections (new file)
- `R/zzz.R` — add `# ── feature/joins ──` block with 8 `registerS3method()` calls
- `R/reexports.R` — add re-export entries for all 8 join generics
- `plans/error-messages.md` — add 7 new error/warning classes (done before any code)
- `changelog/feature-joins.md` — created last, before opening PR

**Acceptance criteria:**
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and `man/` in sync
- [ ] All ~30 test sections pass
- [ ] All user-facing errors tested with dual pattern (`expect_error(class=)` + `expect_snapshot(error=TRUE)`)
- [ ] All three design types looped via `make_all_designs()` for tests 1–26
- [ ] `test_invariants(result)` called first in every non-error test block
- [ ] Domain column preservation asserted in every applicable test
- [ ] `@variables$domain` sentinel asserted in semi_join, anti_join, inner_join (domain-aware) tests
- [ ] `@groups` preservation asserted in tests 8, 9, 14, 18, 23, 24
- [ ] `@metadata` label absence asserted in tests 1, 18, 23
- [ ] Coverage ≥ 98% on `R/joins.R`
- [ ] GAP-6 (`bind_rows` dispatch) verified and documented in `decisions-joins.md`
- [ ] All `@examples` run under R CMD check (each block begins with `library(dplyr)`)
- [ ] `air format R/joins.R` run before opening PR
- [ ] Changelog entry written and committed on this branch

---

## Task List

### Phase 0 — Pre-implementation

**Task 1:** Update `plans/error-messages.md`

Add the 7 new classes from §XV of the spec to the errors/warnings tables before
writing any source code. Source file for all: `R/joins.R`.

Errors to add (8 total):
- `surveytidy_error_join_survey_to_survey` — `y` is a survey object in any join
- `surveytidy_error_join_adds_rows` — `right_join` or `full_join` on a survey
- `surveytidy_error_join_row_expansion` — duplicate keys in `y` would expand row count
- `surveytidy_error_join_twophase_row_removal` — physical `inner_join` on `survey_twophase`
- `surveytidy_error_bind_rows_survey` — `bind_rows` with a survey object
- `surveytidy_error_bind_cols_row_mismatch` — row counts differ in `bind_cols`
- `surveytidy_warning_join_col_conflict` — `y` has design-variable column names
- `surveytidy_error_reserved_col_name` — `"..surveytidy_row_index.."` already in `names(x@data)` when `semi_join`, `anti_join`, or `inner_join` (domain-aware) is called (source: `R/joins.R`, from §IV)

Re-used classes (no new entry needed): `surveycore_warning_physical_subset`,
`surveycore_warning_empty_domain`, `surveytidy_error_subset_empty_result`.

---

### Phase 1 — `left_join`

**Task 2:** Write failing tests for `left_join()` (tests 1–8 including 7b)

Create `tests/testthat/test-joins.R`. Add test blocks for tests 1–8 + 7b only;
leave placeholder comments for the remaining sections. Test structure:

```
# 1.  left_join() — adds columns from y; survey rows preserved (3 designs)
#     Assert test_invariants(result) first; assert new cols absent from
#     @metadata@variable_labels
# 2.  left_join() — visible_vars extended when set
# 3.  left_join() — visible_vars unchanged when NULL
# 4.  left_join() — design variable column in y → warns + dropped
#     expect_warning(class = "surveytidy_warning_join_col_conflict")
#     Assert the conflicting column is absent from the result
# 5.  left_join() — duplicate keys in y → surveytidy_error_join_row_expansion
#     Dual: expect_error(class=) + expect_snapshot(error=TRUE)
# 6.  left_join() — y is a survey → surveytidy_error_join_survey_to_survey
#     Dual pattern
# 7.  left_join() — domain column preserved unchanged after join
# 7b. left_join() — suffix rename: @metadata key and visible_vars entry
#     updated when x and y share a non-design column name
# 8.  left_join() — @groups preserved through the join
```

**Task 3:** Run `devtools::test("test-joins")` → confirm all left_join tests fail
(expected: "could not find function").

**Task 4:** Create `R/joins.R`. Implement shared internal helpers + `left_join.survey_base`.

File structure (in order):
```
# File header comment
# ── Shared internal helpers ──────────────────────────────────────────────────
.check_join_y_type(y)
.check_join_col_conflict(x, y, by)
.check_join_row_expansion(original_nrow, new_nrow)
.new_join_domain_sentinel(type, keys)
.repair_suffix_renames(x, old_x_cols, suffix)

# ── left_join ────────────────────────────────────────────────────────────────
#' @name left_join
NULL
#' @rdname left_join
#' @method left_join survey_base
#' @noRd
left_join.survey_base <- function(...)
```

Helper implementation notes:

- `.check_join_y_type(y)`: Single `S7::S7_inherits(y, surveycore::survey_base)` check.
  Error `surveytidy_error_join_survey_to_survey`.

- `.check_join_col_conflict(x, y, by)`: Identify design variable names via
  `surveycore::.get_design_vars_flat(x)` (it is `@keywords internal` but
  exported from surveycore — use `surveycore::` directly, no wrapper needed).
  Also include `surveycore::SURVEYCORE_DOMAIN_COL` in the protected set.
  Exclude `by` columns from the conflict check (they are join keys, not new columns).
  Parse `by` argument: if `NULL`, `character(0)`; if a `character` vector, take it
  as-is; if a `dplyr::join_by()` object, extract `.$x` names. Warn with
  `surveytidy_warning_join_col_conflict`, drop conflicting columns from `y`,
  return cleaned `y`.

- `.check_join_row_expansion(original_nrow, new_nrow)`: `if (new_nrow > original_nrow)`
  → error `surveytidy_error_join_row_expansion`. The message requires `{old_n}`,
  `{new_n}`, and `{key_col}`. For `{key_col}`, the caller should pass the key info
  since this helper doesn't know the by argument. **Implementation decision:** pass
  `by_label` (a character string) as a third argument to the helper so the error
  message can show the key. This deviates slightly from the spec signature
  `(int, int)` — extend to `(original_nrow, new_nrow, by_label = NULL)` with a
  fallback message if NULL. Log this in `decisions-joins.md`.

- `.new_join_domain_sentinel(type, keys)`:
  `structure(list(type = type, keys = keys), class = "surveytidy_join_domain")`

- `.repair_suffix_renames(x, old_x_cols, suffix)`: Find columns in `old_x_cols`
  that are absent from `names(x@data)` but whose suffixed version (e.g., `col.x`)
  is present. Build rename map (old key → new key). Apply to
  `@metadata@variable_labels` and `@variables$visible_vars`. Return the modified `x`.
  Guard: skip if no renamed columns found (fast path).

`left_join.survey_base` steps per §III: guard (y type) → guard (col conflict, capture
cleaned y) → join raw data → guard (row expansion) → set `x@data` → repair suffix
renames → update `visible_vars` → return `x`.

After implementing `.check_join_row_expansion` with the extended signature
`(original_nrow, new_nrow, by_label = NULL)`, add an entry to `plans/decisions-joins.md`
documenting this deviation from the spec's `(int, int)` signature and the rationale
(error message quality — `{key_col}` requires the caller to pass key info).

**Resolved_by for sentinels:** `semi_join`, `anti_join`, and `inner_join` need to
compute `resolved_by` before constructing the sentinel. Use:
```r
if (is.null(by)) {
  resolved_by <- intersect(names(x@data), names(y))
} else if (is.character(by)) {
  resolved_by <- unname(by)
} else {
  # join_by() object
  resolved_by <- by$x
}
```
This pattern is repeated in semi_join, anti_join, and inner_join — extract it into
an inline expression (not a helper, since it's used in 3 spots and is short).

**Task 4b:** Add `left_join` registration to `R/zzz.R` (inside the existing `.onLoad` block):

```r
# ── feature/joins ─────────────────────────────────────────────────────────────
registerS3method("left_join", "surveycore::survey_base",
  get("left_join.survey_base", envir = ns), envir = asNamespace("dplyr"))
```

This must be done before running the tests so dplyr dispatches to `left_join.survey_base`.

**Task 5:** Run `devtools::test("test-joins")` → confirm tests 1–8 + 7b pass.

---

### Phase 2 — `semi_join` + `anti_join`

**Task 6:** Add test sections 9–17 (including 12b, 13b, 13c) to `test-joins.R`.

```
# 9.  semi_join() — marks unmatched rows as out-of-domain; no new cols (3 designs)
#     Assert sentinel appended (type="semi_join"), @groups preserved,
#     visible_vars identical to original
# 10. semi_join() — ANDs with existing domain
# 11. semi_join() — all rows unmatched → surveycore_warning_empty_domain
# 12. semi_join() — duplicate keys in y collapse to single TRUE (no row expansion)
# 12b. anti_join() — duplicate keys collapse to single FALSE per survey row
# 13. semi_join() — y is a survey → surveytidy_error_join_survey_to_survey
# 13b. semi_join() — x@data has "..surveytidy_row_index.." →
#      surveytidy_error_reserved_col_name; dual pattern
# 13c. anti_join() — x@data has "..surveytidy_row_index.." →
#      surveytidy_error_reserved_col_name; dual pattern
# 14. anti_join() — marks matched rows as out-of-domain; no new cols (3 designs)
#     Assert sentinel appended (type="anti_join"), @groups preserved,
#     visible_vars identical to original
# 15. anti_join() — ANDs with existing domain
# 16. anti_join() — all rows matched → surveycore_warning_empty_domain
# 17. anti_join() — y is a survey → surveytidy_error_join_survey_to_survey
```

**Task 7:** Run `devtools::test("test-joins")` → confirm tests 9–17 fail.

**Task 8:** Implement `semi_join.survey_base` and `anti_join.survey_base` in `R/joins.R`.

Both use the row-index approach (§IV Step 2):
```r
x_temp <- x@data
x_temp[["..surveytidy_row_index.."]] <- seq_len(nrow(x@data))
matched <- dplyr::semi_join(x_temp, y, by = by, copy = copy, ...)
new_mask <- seq_len(nrow(x@data)) %in% matched[["..surveytidy_row_index.."]]
```

`new_mask` is always `TRUE = matched by y` for both functions. **Do not pre-negate for
`anti_join`.** The negation happens exclusively in the domain AND step:
- `semi_join`: `new_domain <- existing_domain & new_mask`
- `anti_join`: `new_domain <- existing_domain & !new_mask`

Guard for reserved column name (`"..surveytidy_row_index.."` already in
`names(x@data)`) must fire **before** creating `x_temp`. Error class:
`surveytidy_error_reserved_col_name`.

Both functions append a domain sentinel to `@variables$domain`. The `"domain"` key
may be absent (first domain operation on this object) — use
`x@variables$domain <- c(x@variables$domain, list(sentinel))`, which works whether
`x@variables$domain` is NULL or a list.

Include `@name semi_join` / `@name anti_join` NULL stubs with full roxygen docs.

**Task 8b:** Add `semi_join` and `anti_join` registrations to `R/zzz.R` (append to the `# ── feature/joins ──` block):

```r
registerS3method("semi_join", "surveycore::survey_base",
  get("semi_join.survey_base", envir = ns), envir = asNamespace("dplyr"))
registerS3method("anti_join", "surveycore::survey_base",
  get("anti_join.survey_base", envir = ns), envir = asNamespace("dplyr"))
```

**Task 9:** Run `devtools::test("test-joins")` → confirm tests 9–17 pass; tests 1–8 still green.

---

### Phase 3 — `bind_cols`

**Task 10:** Add test sections 18–22 to `test-joins.R`.

```
# 18. bind_cols() — adds columns by position; row count unchanged (3 designs)
#     Assert @groups preserved; new cols absent from @metadata@variable_labels
# 19. bind_cols() — visible_vars extended when set
# 20. bind_cols() — row mismatch → surveytidy_error_bind_cols_row_mismatch
#     Dual pattern
# 21. bind_cols() — design variable column in ... → warns + dropped
#     expect_warning(class = "surveytidy_warning_join_col_conflict")
#     Assert the conflicting column is absent from the result
# 22. bind_cols() — ... contains a survey → surveytidy_error_join_survey_to_survey
#     Dual pattern
```

**Task 11:** Run `devtools::test("test-joins")` → confirm tests 18–22 fail.

**Task 12:** Implement `bind_cols.survey_base` in `R/joins.R`.

Key implementation notes per §V:
- Check each element of `list(...)` for survey type before binding
- `cleaned_y <- .check_join_col_conflict(x, dplyr::bind_cols(...), by = character(0))`
  — `by = character(0)` means all new columns are subject to the conflict check
- Row count guard: `nrow(cleaned_y) == nrow(x@data)` (error before any assignment)
- `x@data <- dplyr::bind_cols(x@data, cleaned_y, .name_repair = .name_repair)`
- `visible_vars` update: same pattern as `left_join` Step 5

Include `@name bind_cols` NULL stub.

**Task 12b:** Add `bind_cols` registration to `R/zzz.R` (append to the `# ── feature/joins ──` block):

```r
registerS3method("bind_cols", "surveycore::survey_base",
  get("bind_cols.survey_base", envir = ns), envir = asNamespace("dplyr"))
```

**Task 13:** Run `devtools::test("test-joins")` → confirm tests 18–22 pass.

---

### Phase 4 — `inner_join`

**Task 14:** Add test sections 23–26 (including 23b–23d, 24–24d) to `test-joins.R`.

```
# 23. inner_join() [domain-aware, default] — unmatched rows out-of-domain;
#     new cols appended; row count unchanged (3 designs)
#     Assert sentinel appended (type="inner_join"), @groups preserved,
#     new cols absent from @metadata@variable_labels
# 23b. inner_join() [domain-aware] — ANDs with existing domain
# 23c. inner_join() [domain-aware] — all rows unmatched →
#      surveycore_warning_empty_domain
# 23d. inner_join() [domain-aware] — duplicate keys in y →
#      surveytidy_error_join_row_expansion; dual pattern
#      (Step 3 match mask collapses duplicates correctly, but Step 6 left_join
#      runs against the original duplicate-keyed y and triggers the row
#      expansion guard — same error as physical mode, per §VI error table "Both modes")
# 24. inner_join(.domain_aware=FALSE) — removes unmatched rows + warns
#     (taylor, replicate); assert visible_vars unchanged
# 24b. inner_join(.domain_aware=FALSE) — twophase →
#      surveytidy_error_join_twophase_row_removal; dual pattern
# 24c. inner_join(.domain_aware=FALSE) — all rows removed →
#      surveytidy_error_subset_empty_result; dual pattern
# 24d. inner_join(.domain_aware=FALSE) — duplicate keys →
#      surveytidy_error_join_row_expansion; dual pattern
# 23e. inner_join() [domain-aware] — x@data has "..surveytidy_row_index.." →
#      surveytidy_error_reserved_col_name; dual pattern
# 25. inner_join() — y is a survey → surveytidy_error_join_survey_to_survey
#     (both modes)
# 26. inner_join() — design variable column in y → warns + dropped (both modes)
#     expect_warning(class = "surveytidy_warning_join_col_conflict")
#     Assert the conflicting column is absent from the result
```

**Task 15:** Run `devtools::test("test-joins")` → confirm tests 23–26 fail.

**Task 16:** Implement `inner_join.survey_base` in `R/joins.R`.

Domain-aware mode (`.domain_aware = TRUE`, default) follows §VI Steps 1–7:
1. Guard: y type
2. Guard: col conflict (capture `y <- .check_join_col_conflict(...)`)
3. Compute match mask (row-index approach — identical to `semi_join`)
4. AND with existing domain; write back to `x@data[[SURVEYCORE_DOMAIN_COL]]`
5. Empty domain check → inline `surveycore_warning_empty_domain`
6. Left join for new columns: `old_x_cols <- names(x@data)`;
   run `dplyr::left_join(x@data, y, ...)`; guard row expansion;
   `.repair_suffix_renames`; update `visible_vars`
7. Append sentinel: `.new_join_domain_sentinel("inner_join", resolved_by)`

Physical mode (`.domain_aware = FALSE`) follows §VI Steps 1–7:
1. Guard: y type
2. Guard: twophase (`S7::S7_inherits(x, surveycore::survey_twophase)`) →
   `surveytidy_error_join_twophase_row_removal`
3. Guard: col conflict
4. Run `dplyr::inner_join(x@data, y, ...)` → guard row expansion
5. (Result already computed in Step 4)
6. Issue physical-subset warning: **inline** `cli::cli_warn()` with class
   `"surveycore_warning_physical_subset"` (do NOT call `.warn_physical_subset()`).
   The spec message includes `{removed_n}` (computed as `nrow(x@data) - nrow(result)`)
   and custom bullets specific to `inner_join`. Inlining avoids modifying the
   shared helper for one call site.
7. Empty result guard: `if (nrow(result) == 0)` → error
   `surveytidy_error_subset_empty_result`

After both modes: write the result back to `x@data` and return `x`.

Include `@name inner_join` NULL stub with full roxygen docs including
`.domain_aware` argument and `@details` section warning about replicate designs
in physical mode.

**Task 16b:** Add `inner_join` registration to `R/zzz.R` (append to the `# ── feature/joins ──` block):

```r
registerS3method("inner_join", "surveycore::survey_base",
  get("inner_join.survey_base", envir = ns), envir = asNamespace("dplyr"))
```

**Task 17:** Run `devtools::test("test-joins")` → confirm tests 23–26 pass.

---

### Phase 5 — `right_join`, `full_join`, `bind_rows`

**Task 18:** Add test sections 27–30 to `test-joins.R`.

```
# 27. right_join() — always errors (surveytidy_error_join_adds_rows)
#     Dual pattern; verify {fn} = "right_join" in snapshot message
# 28. full_join()  — always errors (surveytidy_error_join_adds_rows)
#     Dual pattern; verify {fn} = "full_join" in snapshot message
# 29. bind_rows()  — always errors (surveytidy_error_bind_rows_survey)
#     Dual pattern
# 30. All survey × survey combinations → surveytidy_error_join_survey_to_survey
#     One test per function (parametrized loop or individual blocks)
#     Dual pattern per function (each call site produces a distinct snapshot)
# 31. 0-row y edge cases (spec §XII)
#     left_join: all survey rows preserved, new columns all NA
#     semi_join: all rows marked out-of-domain (equivalent to empty match; no error)
#     anti_join: all rows marked in-domain (equivalent to no matches; no error)
#     Construct: y <- data.frame(id = integer(0)) (or equivalent with join key col)
# 32. 0-column y edge cases (spec §XII)
#     left_join: no-op (survey unchanged, no new columns added)
#     bind_cols: no-op (survey unchanged)
#     Construct: y <- data.frame()[seq_len(nrow(d@data)), , drop = FALSE]
```

**Task 19:** Run `devtools::test("test-joins")` → confirm tests 27–30 fail.

**Task 20:** Implement `right_join.survey_base`, `full_join.survey_base`, and
`bind_rows.survey_base` in `R/joins.R`.

`right_join` and `full_join`: Each checks `.check_join_y_type(y)` first (survey ×
survey guard), then errors with `surveytidy_error_join_adds_rows`. The `{fn}`
placeholder is filled by a local `fn_name <- "right_join"` (or `"full_join"`) before
the `cli_abort()` call — do NOT use `sys.call()` or `match.call()` for this.

`bind_rows`: Checks `S7::S7_inherits(x, surveycore::survey_base)` (always TRUE since
this is the method for survey objects), then errors immediately with
`surveytidy_error_bind_rows_survey`. Include in `@details`: "If the survey object is
passed as a non-first argument (e.g., `bind_rows(df, survey)`), this method is not
dispatched and the call completes silently with an invalid data frame. Always pass
the survey object as the first argument."

Include `@name right_join`, `@name full_join`, `@name bind_rows` NULL stubs.

**Task 20b:** Add `right_join`, `full_join`, and `bind_rows` registrations to `R/zzz.R` (append to the `# ── feature/joins ──` block):

```r
registerS3method("right_join", "surveycore::survey_base",
  get("right_join.survey_base", envir = ns), envir = asNamespace("dplyr"))
registerS3method("full_join", "surveycore::survey_base",
  get("full_join.survey_base", envir = ns), envir = asNamespace("dplyr"))
registerS3method("bind_rows", "surveycore::survey_base",
  get("bind_rows.survey_base", envir = ns), envir = asNamespace("dplyr"))
```

**Task 21:** Run `devtools::test("test-joins")` → confirm all ~30 tests pass.

**Task 22:** Verify GAP-6 (`bind_rows` dispatch).

In a fresh R session with the package loaded from source (`devtools::load_all()`),
test:
```r
d <- make_all_designs(42)$taylor
df <- data.frame(x = 1:nrow(d@data))
dplyr::bind_rows(d, df)   # should hit bind_rows.survey_base → error
```
If the `registerS3method` approach fails (dplyr uses `vctrs::vec_rbind` internally
and bypasses S3 dispatch), investigate:
- Alternative A: intercept via `dplyr_reconstruct.survey_base` (already wired)
- Alternative B: `.onLoad` hook on the generic

Document the result (which approach works, or that the default approach works) in
`plans/decisions-joins.md`.

---

### Phase 6 — Re-exports

Note: All 8 `registerS3method()` calls were added incrementally to `R/zzz.R` during
Phases 1–5 (Tasks 4b, 8b, 12b, 16b, 20b). This phase covers only re-exports.

**Task 23:** Verify `R/zzz.R` has all 8 registrations from the `# ── feature/joins ──`
block, added across Phases 1–5. No new edits needed if each task's `b` step was
completed correctly.

**Task 24:** Update `R/reexports.R`.

Add re-export entries for all 8 join generics after the existing `# ── dplyr verbs
──` section. Primary verbs (`left_join`, `inner_join`, `semi_join`, `anti_join`,
`bind_cols`) use `@rdname` to merge into per-verb Rd files:

```r
#' @rdname left_join
#' @export
dplyr::left_join

#' @rdname inner_join
#' @export
dplyr::inner_join

# etc. for semi_join, anti_join, bind_cols
```

Error-only verbs (`right_join`, `full_join`, `bind_rows`) also get `@rdname` since
their NULL stubs carry the error documentation that users need:

```r
#' @rdname right_join
#' @export
dplyr::right_join

#' @rdname full_join
#' @export
dplyr::full_join

#' @rdname bind_rows
#' @export
dplyr::bind_rows
```

---

### Phase 7 — Final quality checks

**Task 25:** Run `devtools::document()`.

Verify:
- NAMESPACE is updated with all new exports
- All `man/` Rd files generated correctly
- No "S3 methods shown with full name" NOTE (the `@name` + `@rdname` + `@method`
  pattern in `joins.R` prevents this)

**Task 26:** Run `devtools::check()`.

Target: 0 errors, 0 warnings, ≤2 pre-approved notes. Fix any issues before proceeding.
Common issues to watch for:
- Examples missing `library(dplyr)` at the start → add it
- `@examples` calling `make_all_designs()` without it being on the search path →
  use inline `data.frame` examples instead, matching the pattern used in `filter.R`

**Task 27:** Run `covr::file_coverage("R/joins.R", "tests/testthat/test-joins.R")`.

Target: ≥ 98% line coverage. If coverage gaps exist, add tests for uncovered lines.

**Task 28:** Run `air format R/joins.R`.

Apply the formatter; do not manually undo its changes. If output looks wrong,
diagnose a syntax problem.

**Task 29:** Run `devtools::test()` one final time → all tests green.

**Task 30:** Write `changelog/feature-joins.md` changelog entry (one file per the
established changelog pattern, created last on this branch).

---

## Implementation Notes and Gotchas

### Empty domain warning — inline, not a helper
The `surveycore_warning_empty_domain` warning is inlined in `filter.R` and
`drop-na.R` (no shared helper function). Follow the same inline `cli::cli_warn()`
pattern in `joins.R` for `semi_join`, `anti_join`, and `inner_join` (domain-aware).

### Physical-subset warning for `inner_join` — inline, not the shared helper
The `inner_join` physical mode warning message includes `{removed_n}` (row count
removed) and has `"i"` and `"v"` bullets specific to `inner_join`. The shared
`.warn_physical_subset()` helper in `R/utils.R` uses a different fixed-format
message. **Do not call `.warn_physical_subset("inner_join")`** — inline the warning
directly with `cli::cli_warn(..., class = "surveycore_warning_physical_subset")`.
This is the explicit-over-clever choice for a single-use call site.

### `by` argument parsing for `resolved_by`
When constructing domain sentinels (in `semi_join`, `anti_join`, `inner_join`
domain-aware), the `resolved_by` value must be a character vector of key names.
Parse inline in each function:
```r
resolved_by <- if (is.null(by)) {
  intersect(names(x@data), names(y))
} else if (is.character(by)) {
  unname(by)
} else {
  by$x  # dplyr::join_by() object
}
```

### `@variables$domain` key may be absent
The `"domain"` key is absent from `@variables` until the first domain-restricting
operation (formal exception to the "all keys always present" rule, per `filter.R`
implementation). When appending a sentinel:
```r
x@variables$domain <- c(x@variables$domain, list(sentinel))
```
`c(NULL, list(sentinel))` produces `list(sentinel)`, which is correct.

### `surveycore::.get_design_vars_flat(x)` — exported, use `::` directly
This function is `@keywords internal` but exported from surveycore via `@export`.
Call it as `surveycore::.get_design_vars_flat(x)` — no wrapper needed. Also
include `surveycore::SURVEYCORE_DOMAIN_COL` in the protected column set within
`.check_join_col_conflict()` (the domain column is a design-structural column that
must never be overwritten by a join).

### `.check_join_row_expansion` — extend signature for error message quality
The spec signature is `(original_nrow, new_nrow)` but the message template requires
the key column name(s) (`{key_col}`). Extend to
`.check_join_row_expansion(original_nrow, new_nrow, by_label = NULL)` where
`by_label` is a human-readable string (e.g., `"id"` or `"id, wave"`). When `NULL`,
omit the key reference from the message. Log this extension in `decisions-joins.md`.

### GAP-6 — verify at end of Phase 5, not at the beginning
GAP-6 (`bind_rows` dispatch) is verified in Task 22 (after implementation), not
before. This is intentional: the fastest way to verify is to implement the method
and test it, rather than speculating from dplyr source code. If the dispatch fails,
Task 22 is the place to decide on an alternative approach and update the spec + plan.
