# fix: allow .label + .factor = TRUE in case_when() and recode_values()

**Branch:** `fix/factor-label-combined`
**Status:** Complete — `devtools::check()` passing (0 errors, 0 warnings, 0 notes)

---

## What Changed

### Bug fix: incorrect restriction on combining `.label` with `.factor = TRUE`

`case_when()` and `recode_values()` previously raised
`surveytidy_error_recode_factor_with_label` when both `.label` and
`.factor = TRUE` were supplied, with the message "Factor levels carry their own
labels." This restriction was wrong.

`.label` is a **variable label** — a human-readable name for the column stored
in `@metadata@variable_labels`. Factor levels are the **values/categories** of
the variable. They are orthogonal concepts; a factor column can and should be
able to have a variable label.

**After this fix:** passing `.label = "My label"` alongside `.factor = TRUE`
returns a factor whose variable label is stored in `@metadata@variable_labels`
via the normal `surveytidy_recode` attr machinery.

### Files changed

- `R/case-when.R` — removed the guard that errored on `.label + .factor = TRUE`;
  added `attr(result, "label") <- .label` in the `.factor` branch; updated
  `@param` docs to remove the "Cannot be combined with" restrictions
- `R/recode-values.R` — same changes as `case-when.R`
- `tests/testthat/test-recode.R` — replaced two error tests with happy-path
  tests confirming `.label + .factor = TRUE` stores the variable label; removed
  the corresponding snapshot call from the omnibus error snapshot block
- `tests/testthat/_snaps/recode.md` — deleted the two stale error snapshots
- `plans/error-messages.md` — removed the `surveytidy_error_recode_factor_with_label`
  row (error class no longer exists)
