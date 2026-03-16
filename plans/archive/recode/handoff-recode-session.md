# Recode Implementation Handoff

**Branch:** `feature/recode`
**Status:** Implementation complete, tests pass, `devtools::check()` failing on one example error

---

## What Was Implemented (Phase 0.6)

Six new exported functions in `R/recode.R` that shadow their dplyr equivalents and propagate `@metadata` label information in/out of survey objects:

| Function | Description |
|---|---|
| `case_when()` | Shadows `dplyr::case_when()`; adds `.label`, `.value_labels`, `.factor`, `.description` |
| `replace_when()` | Wraps `dplyr::replace_when()`; adds label inheritance from input |
| `if_else()` | Shadows `dplyr::if_else()`; adds label args |
| `na_if()` | Shadows `dplyr::na_if()`; adds `.update_labels`, `.description` |
| `recode_values()` | Wraps `dplyr::recode_values()`; adds `.label`, `.value_labels`, `.factor`, `.use_labels` |
| `replace_values()` | Wraps `dplyr::replace_values()`; adds label args + label inheritance |

`mutate.survey_base()` in `R/mutate.R` was also rewritten with three new steps:
- **Pre-attachment** (step 2): `attach_label_attrs()` copies label attrs from `@metadata` into `@data` before `dplyr::mutate()` so recode functions can read them
- **Post-detection** (step 4): `extract_labelled_outputs()` reads the `surveytidy_recode` sentinel attr from mutated columns and writes labels back to `@metadata`
- **Strip** (step 5b): `strip_label_attrs()` removes all haven attrs and the `surveytidy_recode` attr from `@data` before storing

---

## Files Changed

| File | Change |
|---|---|
| `R/recode.R` | **New file** — 6 exported functions + 4 internal helpers |
| `R/mutate.R` | Rewrote `mutate.survey_base()` with Phase 0.6 pre/post/strip steps; split design-var warning into two classes |
| `R/utils.R` | Added `.attach_label_attrs()`, `.extract_labelled_outputs()`, `.strip_label_attrs()` under `# ── mutate() label helpers` |
| `tests/testthat/test-recode.R` | **New file** — 12 test sections, 3535+ assertions |
| `tests/testthat/test-mutate.R` | Updated warning class: `surveytidy_warning_mutate_design_var` → `surveytidy_warning_mutate_weight_col` |
| `tests/testthat/helper-test-data.R` | Fixed `as_survey_rep` → `as_survey_repweights` (surveycore 0.4.0); added Invariant 7 (no `surveytidy_recode` attr in `@data`) |
| `tests/testthat/test-distinct.R` | Fixed `as_survey_rep` → `as_survey_repweights` |
| `plans/error-messages.md` | Added 7 new error classes, 2 new warning classes; removed old `surveytidy_warning_mutate_design_var` |
| `DESCRIPTION` | Added `haven (>= 2.5.0)` to Imports; bumped dplyr to `(>= 1.2.0)` |
| `NAMESPACE` | Regenerated via `devtools::document()` — includes 6 new exports |

---

## Decisions Made

1. **Two warning classes instead of one**: Split `surveytidy_warning_mutate_design_var` into `surveytidy_warning_mutate_weight_col` (weight column) and `surveytidy_warning_mutate_structural_var` (strata/PSU/FPC/repweights). Weight modification is less severe (affects ESS), structural is more severe (invalidates estimates).

2. **`surveytidy_recode` sentinel attr**: All 6 recode functions set `attr(result, "surveytidy_recode") <- list(description = .description)` on their output when at least one surveytidy arg is used. `mutate.survey_base()` uses presence of this attr (not the description field) to decide whether to write a structured transformation log entry.

3. **`attr(x, "label", exact = TRUE)`**: R's `attr()` partially matches — `attr(x, "label")` would match `"labels"`. All attr calls throughout `R/recode.R` and `R/utils.R` use `exact = TRUE`.

4. **`haven::zap_labels()` keeps "label" attr**: After calling `haven::zap_labels()` in `.strip_label_attrs()`, must explicitly `attr(col, "label") <- NULL` — zap_labels removes `"labels"` but not `"label"`.

5. **`na_if()` loops over y**: `dplyr::na_if()` doesn't accept a vector `y`. Our wrapper loops: `for (yval in y) { result <- dplyr::na_if(result, yval) }`.

6. **`dplyr::recode_values()` param is `unmatched` not `.unmatched`**: dplyr's arg has no dot prefix. Our function uses `.unmatched` as our arg name and passes `unmatched = .unmatched` to dplyr.

7. **`case_when()` factor path uses `for` loop**: `vapply(..., list(NULL))` had a type mismatch. Changed to a `for` loop to extract formula RHS values.

8. **Example library order**: `library(dplyr)` first, then `library(surveycore)`, then `library(surveytidy)` last. This order ensures surveytidy's `case_when`, `if_else`, etc. mask dplyr's on the search path. `library(dplyr)` is required because `mutate()` is in Imports but not re-exported.

---

## The Remaining Bug: `devtools::check()` Fails

### Symptom
```
Error in `dplyr::mutate()`:
ℹ In argument: `cat = case_when(x > 5 ~ "high", .default = "low", .label = "Response category")`.
Caused by error in `case_when()`:
! Case 2 (`.label = "Response category"`) must be a two-sided formula
```
Backtrace shows `dplyr::case_when` is being called, not `surveytidy::case_when`.

### Root cause (partially understood)
The installed package was stale (pre-recode build). After `devtools::install()`, interactive usage works correctly. However, `devtools::check()` still fails even though it builds fresh from source.

**Leading hypothesis**: When `mutate.survey_base()` does `rlang::inject(dplyr::mutate(base_data, ...))`, the quosures in `...` may be evaluated in an environment where `case_when` resolves to dplyr's version. The inner `dplyr::mutate(base_data, ...)` is a call to a data frame mutate — it captures the `...` quosures via `dplyr_quosures(...)` inside `dplyr:::mutate.data.frame`. The environment of those quosures may be the dplyr namespace or the `mutate.survey_base` execution environment rather than the user's example environment.

**What was tried**:
- Swapped library order in examples (dplyr first, surveytidy last) ✓
- Ran `devtools::document()` ✓
- Ran `devtools::install()` ✓
- Interactive test now works ✓
- `devtools::check()` still fails ✗

### Likely fix directions to investigate
1. **Avoid the example entirely**: Replace the example that uses `.label` inside `mutate()` with one that calls `case_when()` directly (outside mutate), so the quosure issue doesn't apply.
2. **Qualify the call**: Use `surveytidy::case_when(...)` explicitly in the example with `.label`.
3. **Fix the quosure environment**: In `mutate.survey_base()`, instead of forwarding `...` as quosures to the inner `dplyr::mutate()`, evaluate the recode functions in the correct environment. But this may require a deeper refactor.
4. **Use `\dontrun{}`**: Not ideal, but would pass check — the `.label` example would be excluded from check. (Conflicts with no-`\dontrun{}` rule, so probably not acceptable.)

Option 1 (simplest): Change the `@examples` to not call `mutate()` when demonstrating `.label`. Instead, show `case_when()` called standalone:
```r
# Direct usage (without mutate)
x <- 1:10
case_when(x > 5 ~ "high", .default = "low", .label = "Response category")
```
This bypasses the quosure dispatch issue entirely.

---

## Test Status

```
devtools::test()  →  [ FAIL 0 | WARN 1 | SKIP 0 | PASS 11624 ]
```
WARN 1 = new snapshot generated for structural var warning (expected on first run, saved to `_snaps/`).

All 3535 recode-specific assertions pass. All 11,624 total assertions pass.

---

## Remaining Work Before PR

- [ ] Fix `devtools::check()` error (see bug above — likely by changing the example)
- [ ] Run `devtools::check()` to get 0 errors, 0 warnings, ≤2 notes
- [ ] Update `_pkgdown.yml` — add 6 new exports to the correct `reference:` section (under a `Recoding` family)
- [ ] Mark implementation plan sections as `[x]` in `plans/impl-recode.md`
- [ ] Create `changelog/phase-0.6/feature-recode.md` (required by commit-and-pr skill)
- [ ] Run `air format .` before final commit
- [ ] Invoke `/commit-and-pr`

---

## Key Code Patterns to Know

### The sentinel attr pattern
```r
# All recode functions set this when they produce labelled output:
attr(result, "surveytidy_recode") <- list(description = .description)

# mutate.survey_base() checks for it BEFORE stripping:
recode_attr <- attr(new_data[[col]], "surveytidy_recode")
if (!is.null(recode_attr)) {
  # write structured transformation log
}

# Then strip it:
attr(data[[col]], "surveytidy_recode") <- NULL
```

### The pre/post/strip flow in mutate.survey_base()
```r
# Step 2: attach label attrs from @metadata into @data
augmented_data <- .attach_label_attrs(.data@data, .data@metadata)
# Step 3: run dplyr::mutate on augmented_data
# Step 4: extract labels from output back to @metadata
updated_metadata <- .extract_labelled_outputs(new_data, .data@metadata, mutated_names)
# Step 5a: capture surveytidy_recode attrs before strip
# Step 5b: strip all haven attrs + surveytidy_recode attr
new_data <- .strip_label_attrs(new_data)
```

### Error class for unmatched recode values
```r
tryCatch(
  dplyr::recode_values(..., unmatched = .unmatched),
  vctrs_error_combine_unmatched = function(e) {
    cli::cli_abort(..., class = "surveytidy_error_recode_unmatched_values")
  }
)
```
