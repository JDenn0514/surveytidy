# Implementation Plan: Stale Value Label Pruning

**ID:** stale-value-labels
**Status:** Draft

## Overview

`replace_when()` and `replace_values()` both inherit value labels from their
input vector `x` and merge them with any caller-supplied `.value_labels`. The
bug: when a replacement eliminates a value entirely (e.g., collapsing value 4
into 3), the inherited label for that value survives in the output. The fix
adds a `result_values` parameter to `.merge_value_labels()` so stale inherited
labels are pruned before the merge. Caller-supplied `.value_labels` entries are
never pruned — only inherited ones are.

## PR Map

- [x] PR 1: `fix/stale-value-labels` — prune stale inherited labels in `.merge_value_labels()` and update both callers

---

## PR 1: Prune stale inherited value labels

**Branch:** `fix/stale-value-labels`
**Depends on:** none

**Files:**
- `R/utils.R` — add `result_values` parameter to `.merge_value_labels()`; prune
  stale base label entries before merging
- `R/replace-when.R` — pass `unique(result)` as `result_values` to `.merge_value_labels()`
- `R/replace-values.R` — pass `unique(result)` as `result_values` to `.merge_value_labels()`
- `tests/testthat/test-utils.R` — add a `# ── .merge_value_labels() with result_values ──` section with direct unit tests for the 4 new helper branches
- `tests/testthat/test-recode.R` — add new stale-pruning test blocks to existing sections for `replace_when()` and `replace_values()`
- `changelog/fixes/stale-value-labels.md` — created last, before opening PR (new `fixes/` subdirectory for standalone bug fixes not tied to a named phase)

**Acceptance criteria:**
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] Line coverage ≥98% verified with `covr::package_coverage()`
- [ ] Stale inherited label pruned when value no longer appears in result
- [ ] Inherited labels for unaffected values are preserved unchanged
- [ ] Auto-pruning works when `.value_labels = NULL` (no explicit labels supplied)
- [ ] User-supplied `.value_labels` entries for values not in result are NOT pruned
- [ ] Both `replace_when()` and `replace_values()` covered
- [ ] Changelog entry written and committed on this branch

**Notes:**

### `.merge_value_labels()` signature change

Add `result_values = NULL` as a third parameter with a `NULL` default so all
existing call sites remain valid without modification (defensive: the default
means "no pruning").

Prune `base_labels` — and only `base_labels` — before the existing merge logic
runs. `override_labels` is never touched. The pruning step:

```r
if (!is.null(base_labels) && !is.null(result_values)) {
  base_labels <- base_labels[unname(base_labels) %in% result_values]
  if (length(base_labels) == 0L) base_labels <- NULL
}
```

Place this block at the top of the function, before the three early-return
`NULL` checks, so that pruning can reduce `base_labels` to `NULL` and trigger
the correct early return.

### Caller changes

Both callers use `unique(result)` (not `result`) to avoid passing a
potentially large vector when only distinct values matter for the lookup:

```r
merged_labels <- .merge_value_labels(
  attr(x, "labels", exact = TRUE),
  .value_labels,
  result_values = unique(result)
)
```

### Documentation update for `.merge_value_labels()`

Update the inline comment above the function to describe the new parameter and
pruning behavior. No roxygen change needed (function is internal/`@noRd`).

### Test cases required

**`test-recode.R` (section for `replace_when()`)** — all new blocks must use
`make_all_designs(seed = 42)` and a `for (d in designs)` loop over all three
design types (taylor, replicate, twophase). Add a block titled
`"replace_when() preserves all inherited labels when no value is eliminated"`:
- Run `replace_when(x, x == 99 ~ 0)` on a labelled vector with values 1–4
  (no 99s in the data, so no value is collapsed)
- Call `test_invariants(result)` first
- Assert all labels for values 1, 2, 3, 4 are present and unchanged
- This is the backward-compatibility regression test for the `result_values = NULL`
  default path

Add a block titled
`"replace_when() drops inherited labels for values no longer in result"`:
- Run `replace_when(x, x == 4 ~ 3)` on a labelled vector with values 1–4
- Call `test_invariants(result)` first
- Assert label for value 4 is absent from output labels
- Assert labels for values 1, 2, 3 are present and unchanged

Add a block titled
`"replace_when() preserves .value_labels entries even when value absent from result"`:
- Run `replace_when(x, x == 4 ~ 3, .value_labels = c("Something else" = 4))`
- Call `test_invariants(result)` first
- Assert `"Something else" = 4` is present in the output labels — value `4` exists in
  the input and is eliminated by the replacement, but user-supplied labels are never
  pruned even when the labelled value no longer appears in the result

Add a block titled
`"replace_when() auto-prunes stale labels with no .value_labels supplied"`:
- Run `replace_when(x, x == 4 ~ 3)` with no `.value_labels`
- Call `test_invariants(result)` first
- Assert label for value 4 is absent

Add a block titled
`"replace_when() prunes inherited NA-value label when NA no longer appears in result"`:
- Build a labelled vector with a label for `NA` (e.g., `c("Missing" = NA)` in
  the labels)
- Run `replace_when(x, is.na(x) ~ 0)` so all `NA` values become `0`
- Call `test_invariants(result)` first
- Assert the `NA` label entry is absent from the output labels

**`test-recode.R` (section for `replace_values()`)** — mirror the same four blocks
for `replace_values()` (backward-compat, stale-pruning, user-supplied, and NA-pruning),
plus the auto-prune-no-.value_labels block. All blocks must use
`make_all_designs(seed = 42)` and a `for (d in designs)` loop over all three
design types.

### Direct unit tests for `.merge_value_labels()` — add to `test-utils.R`

Add a section titled `# ── .merge_value_labels() with result_values ──` containing
four blocks:

1. `"result_values = NULL default skips pruning"` — call `.merge_value_labels()`
   with `base_labels` containing a value not in any `result_values`, but with
   `result_values = NULL`; assert the base label is preserved unchanged
   (backward-compat guarantee).

2. `"result_values prunes stale base entry"` — call `.merge_value_labels()` with
   a base label for value `4` and `result_values = c(1L, 2L, 3L)`; assert the
   label for `4` is absent from the return value.

3. `"result_values keeps base entries still in result"` — call
   `.merge_value_labels()` with base labels for values `1`, `2`, `3`, `4` and
   `result_values = c(1L, 2L, 3L, 4L)`; assert all four labels are present.

4. `"result_values pruning to empty returns NULL base, triggering early-return"` —
   call `.merge_value_labels()` with base labels for values `3`, `4` only and
   `result_values = c(1L, 2L)` (no overlap); assert the return value is `NULL`
   (all base labels pruned, no override labels).

### NA values in result

`unique(result)` may include `NA`. `%in%` treats `NA %in% NA` as `TRUE`, so
inherited labels for `NA` (i.e., tagged missing values) are correctly preserved
when `NA` still appears in the result, and correctly pruned when it does not.
No special-casing needed.
