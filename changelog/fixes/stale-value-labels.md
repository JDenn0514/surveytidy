# fix: Prune stale inherited value labels after recode

**Branch:** `fix/stale-value-labels`
**Status:** Complete — `devtools::check()` passing (0 errors, 0 warnings, 0 notes)

---

## What Changed

### Bug fix: stale inherited value labels pruned by `replace_when()` and `replace_values()`

Previously, when `replace_when()` or `replace_values()` collapsed or replaced
values (e.g. mapping value 4 to 3), the inherited value labels from the input
vector were carried through unchanged — including labels for values that no
longer appeared in the result. This left stale label entries like `"High" = 4`
attached to a vector that contained no 4s.

**After this fix:** both functions automatically prune any inherited base label
whose value does not appear in the recoded result.

### Rules

| Label type | Behavior |
|---|---|
| Inherited base labels (from `attr(x, "labels")`) | Pruned if the labelled value is absent from `unique(result)` |
| User-supplied `.value_labels` | Always preserved, even if the value is absent from the result |
| Inherited base labels for values still in result | Preserved unchanged |

NA is handled correctly by `%in%` semantics: an inherited label for `NA` is
preserved when `NA` appears in the result and pruned when it does not.

### Files changed

- `R/utils.R` — added `result_values = NULL` parameter to `.merge_value_labels()`;
  prunes `base_labels` before the merge when `result_values` is non-NULL
- `R/replace-when.R` — passes `result_values = unique(result)` to `.merge_value_labels()`
- `R/replace-values.R` — passes `result_values = unique(result)` to `.merge_value_labels()`
- `tests/testthat/test-utils.R` — 4 new direct unit tests for the `result_values` branches
- `tests/testthat/test-recode.R` — 5 new stale-pruning tests for `replace_when()`
  and 5 for `replace_values()`; updated 1 pre-existing test whose assertion
  reflected the old (incorrect) behavior

### Coverage

99.8% line coverage after this fix.
