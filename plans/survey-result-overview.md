# Adding dplyr and tidyr Verb Support for `survey_result` Objects

I'm adding dplyr and tidyr verb support for `survey_result` objects to the
surveytidy package. These objects are produced by surveycore's analysis
functions (`get_freqs()`, `get_means()`, `get_totals()`, etc.) and carry a
`.meta` attribute that must be actively updated — not just blindly copied —
when transformations are applied.

## Background: What `survey_result` Objects Are

All six surveycore analysis functions return S3 tibble subclasses:

```r
class(result) = c("survey_freqs", "survey_result", "tbl_df", "tbl", "data.frame")
```

The `.meta` attribute is attached via `attr(result, ".meta")` and accessed
via `meta(result)` (exported from surveycore). It is a named list with:

- `design_type`, `n_respondents`, `conf_level`, `call` — always present
- `group_names`, `group_labels` — group variable names and labels
- `variable` (or `variables`) — name(s) of the focal variable(s)
- `variable_label` — human-readable label for the focal variable
- `value_labels` — named list: variable name → named vector of labels

surveycore also exports a `meta<-` replacement function (or if it doesn't yet,
that may need to be added) so surveytidy methods can update `.meta` cleanly.

## What Already Exists in surveytidy

surveytidy already registers dplyr S3 methods for survey *design* objects
(`survey_base` subclasses) via `registerS3method()` in `.onLoad()`. Look at
the existing `filter.survey_base`, `select.survey_base`, `rename.survey_base`
implementations — the registration pattern for `survey_result` should follow
the exact same approach.

## The Goal: Active Meta Updates Per Verb

Each verb should update `.meta` to reflect the transformation, rather than
just copying it blindly. Here is the intended behavior per verb:

### `rename()` — Update Variable Name References

If the user renames a column that `.meta` references by name
(e.g. `meta$variable`, `meta$group_names`, keys of `meta$value_labels`,
keys of `meta$group_labels`), update those references in `.meta` to the new
name. Non-referenced columns can be renamed freely with no meta change.

**Example:**

```r
result |> rename(party = party_id)
# meta$variable:     "party_id" → "party"
# meta$value_labels: list(party_id = ...) → list(party = ...)
```

### `select()` — Prune Stale References

When columns are dropped, remove the corresponding entries from:

- `meta$group_names` (and `meta$group_labels`) if a group column is dropped
- `meta$value_labels` if a focal variable column is dropped

The `variable` / `variable_label` fields should be set to `NULL` if the focal
variable column is dropped.

### `filter()`, `arrange()`, and `slice()` — Preserve Meta As-Is

These operate on rows, not columns. `.meta` was built from the full design
and describes the analysis, not the filtered view. Preserve it verbatim.
Do **not** update `n_respondents` — that reflects the original sample design.

### `mutate()` — Preserve Meta As-Is

New computed columns are outside the scope of `.meta`. Just copy it through.

## Files to Look At in Both Packages

**In surveycore** (for context only — do not modify):

| File | Purpose |
|------|---------|
| `R/analysis-helpers.R` | `.make_result_tibble()`, `.build_meta()`, meta key constants |
| `R/analysis-meta.R` | `meta()` accessor, `print.survey_result` |
| `tests/testthat/helper-test-data.R` | `test_result_invariants()` |

**In surveytidy** (modify these):

| File | Purpose |
|------|---------|
| `R/zzz.R` (or equivalent) | `.onLoad()` where `registerS3method()` calls live |
| `R/verbs-*.R` | Existing verb implementations for `survey_base` |
| `tests/testthat/` | Add `test-verbs-survey-result.R` |

## Conventions to Follow

- **S3 method registration** via `registerS3method()` in `.onLoad()` — same as existing
  design object methods. Do **not** use `NAMESPACE` `S3method()` declarations for these.
- **`cli_warn()`** with `class=` on every warning (see surveycore's `error-messages.md`
  convention — surveytidy should follow the same pattern with
  `"surveytidy_warning_{condition}"` class names).
- **Tests:** one `test_that()` block per observable behavior; `test_result_invariants()`
  as the first assertion in every block that produces a result.
- After `rename`/`select`: `meta(result)` should pass a stricter invariant that
  checks column names match meta variable references.

## Starting Point

Please read the existing surveytidy verb implementations for `survey_base` objects
first so the new `survey_result` methods follow the same patterns. Then draft an
implementation plan (one PR per verb group makes sense) before writing code.