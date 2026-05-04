# surveytidy Package Development

**Part of the [surveyverse ecosystem](../survey-standards/ECOSYSTEM.md) — see there for ecosystem vision, architecture, and how surveytidy relates to other packages.**

---

## Project Overview

surveytidy provides dplyr/tidyr verbs and survey-aware data wrangling for
survey design objects from surveycore. It extends tidyverse workflows to work
seamlessly with complex survey designs, allowing users to filter, select,
mutate, group, recode, and compute row-wise statistics on survey objects while
maintaining proper variance estimation and metadata handling.

## Package Information

- **Name:** surveytidy
- **Purpose:** dplyr/tidyr verbs (filter, select, mutate, rename, arrange,
  group_by, slice_*, drop_na, distinct, joins), survey-aware recoding
  (recode, recode_values, replace_values, replace_when, na_if, case_when,
  if_else), and row-wise computations (rowstats, rowwise) for survey objects
- **Target Audience:** Survey researchers using tidyverse; users transitioning from srvyr
- **License:** GPL-3 (inherits from surveycore)
- **Dependencies:** surveycore (imports core S7 classes)
- **Status:** v0.5.0; CRAN submission in prep (see `cran-comments.md` and the
  `/cran` skill)

## Vision & Goals

surveytidy makes survey analysis feel natural to tidyverse users by:

1. **Domain-aware filtering** — `filter()` marks rows in/out of domain without removing them
2. **Intelligent metadata handling** — `select()` and `rename()` update labels automatically
3. **Group-by support** — `group_by()` sets up stratification for downstream estimation functions
4. **Familiar API** — Users never write formula syntax; everything uses bare names (tidy-select)

## Key Design Decisions (Finalized)

- **dplyr verbs map to survey concepts** — filter = domain, select = simplify data (remove non-design cols), mutate = add variables
- **Metadata travels with data** — All verbs update `@variables` and `@metadata` keys
- **Filter preserves all rows** — Uses domain column internally; never removes rows
- **No formula syntax** — Always `filter(design, age > 65)`, never `filter(design, ~age > 65)`
- **S3 dispatch via registerS3method()** — Not S7 methods; dplyr's S3 dispatch works for all survey classes

## dplyr Dispatch Pattern (CRITICAL)

S7 namespaced class names break S3 dispatch. To make dplyr verbs work:

```r
# In .onLoad():
registerS3method(
  "filter", "surveycore::survey_base",
  get("filter.survey_base", envir = ns),
  envir = asNamespace("dplyr")
)
```

This registers the S3 method with dplyr's environment so dispatch works.

See `R/zzz.R` for full setup.

## Architecture

### File Organization (R/)

Files are grouped by family. Each verb file contains both the `survey_base`
and `survey_result` methods (no separate `verbs-survey-result.R`).

**dplyr/tidyr verbs:**
- `arrange.R`, `distinct.R`, `drop-na.R`, `filter.R`, `group-by.R`, `joins.R`,
  `mutate.R`, `rename.R`, `select.R`, `slice.R`, `transform.R`

**Survey-aware recoding:**
- `recode.R`, `recode-values.R`, `replace-values.R`, `replace-when.R`,
  `na-if.R`, `case-when.R`, `if-else.R`

**Row-wise computations:**
- `rowstats.R`, `rowwise.R`

**Dispatch and infrastructure:**
- `collection-dispatch.R` — routes user-facing function calls across the survey
  collection (data frames, surveys, lists of surveys)
- `reexports.R` — re-exports for dplyr/tidyr verbs
- `utils.R` — shared helpers (`.protected_cols`, `dplyr_reconstruct`,
  `.sc_update_design_var_names()`, `.sc_rename_metadata_keys()`,
  `.restore_survey_result()`, etc.)
- `zzz.R` — `.onLoad()`: S3 method registration + `S7::methods_register()`
- `surveytidy-package.R` — package-level documentation

### Test Organization (tests/testthat/)

Each source file has a corresponding `test-*.R`. Cross-cutting tests live in
`test-pipeline.R` (multi-verb pipelines), `test-wiring.R` (S3 dispatch +
`.onLoad()`), and `test-verbs-survey-result.R` (survey_result method
contracts). Shared generators in `helper-test-data.R`.

### Key Concepts

#### Domain Column
- Name: `"..surveycore_domain.."` (use `surveycore::SURVEYCORE_DOMAIN_COL`)
- Type: logical column in `@data`
- Content: TRUE for in-domain rows, FALSE for out-of-domain rows
- Never removed; only created/updated by `filter()`

#### visible_vars
- Key in `@variables$visible_vars`
- Set by `select()` to the user's explicit column selection
- Controls which columns `print()` shows (hides design vars from display)
- NULL means all columns in `@data` are shown (default)
- After `select()`, `@data` only contains design vars + user-selected cols;
  `visible_vars` tracks the user's selection so design vars are hidden from print

#### @groups
- Populated by `group_by()`, cleared by `ungroup()`
- Used by downstream estimation functions

#### dplyr_reconstruct()
- Required for complex pipelines (joins, across(), slice, etc.)
- Rebuilds survey class from reconstructed `data` + original template
- Errors if design variables are removed

## Before Starting Any Implementation

**Start here:**
- `.claude/WORKFLOW.md` — how the planning, implementation, and PR cycles fit together

**Rules (always apply — loaded at session start):**
1. `.claude/rules/code-style.md` — indentation, pipe operator, air formatter, S7 patterns, cli error structure, argument order, helper placement
2. `.claude/rules/r-package-conventions.md` — `::` usage, NAMESPACE, roxygen2, `@return`, `@examples`, export policy
3. `.claude/rules/surveytidy-conventions.md` — S3 dispatch, verb method names, special columns (domain, visible_vars, @groups), return visibility
4. `.claude/rules/testing-standards.md` — test structure, coverage requirements, assertion patterns, data generators
5. `.claude/rules/testing-surveytidy.md` — `test_invariants()`, three design type loops, domain preservation, verb error patterns
6. `.claude/rules/engineering-preferences.md` — DRY, well-tested, engineered enough, explicit over clever

**Skills (invoke on-demand):**

*Planning:*
- `spec-workflow` — draft → methodology review → resolve → spec review → resolve + log
- `implementation-workflow` — draft plan → adversarial review → resolve + decisions log
- `spec-reviewer` — adversarial spec review (also wired into spec-workflow Stage 2)

*Implementation:*
- `r-implement` — read plan → write code → verify → mark done
- `auto-ship` — drives a plan end-to-end: TDD → review → changelog → commit → PR → CI → squash-merge
- `testing-r-packages` — testthat 3 patterns
- `cli` — cli_abort/cli_warn/cli_inform conventions

*Review:*
- `critical-code-reviewer` — adversarial code review
- `describe-design` — architectural documentation

*Release:*
- `commit-and-pr` — changelog → pre-flight → commit → PR → CI
- `merge-main` — develop → main release: NEWS → version bump → tag → post-release `.9000`
- `cran` — CRAN submission workflow (R CMD check --as-cran, cran-comments.md, reviewer feedback)
- `lifecycle` — deprecation, superseding, experimental tags
- `release-post` — Tidyverse/Shiny blog release announcements
- `create-release-checklist` — release issue/checklist scaffolding

**GitHub strategy (read when creating PRs):**
- `.claude/rules/github-strategy.md` — branching model, commit format, PR workflow, CI/CD setup

**Reference:**
- `../surveycore/CLAUDE.md` — surveycore architecture (survey class structure, @data/@variables/@metadata)
- `plans/error-messages.md` — surveytidy error/warning classes (update before adding any new class)

## Key Implementation Details

### filter() Specifics
- Stores conditions in `@variables$domain` (list of quosures)
- Chained filters AND the masks: `existing_domain & new_mask`
- Empty domain (all FALSE) triggers `surveycore_warning_empty_domain`
- `.by` argument not supported; raises `surveycore_error_filter_by_unsupported`

### select() Specifics
- **Physically removes** non-selected, non-design columns from `@data`
- **Always keeps** all design variables in `@data` (weights, strata, PSU, FPC,
  repweights, domain column) — they are required for variance estimation
- Sets `@variables$visible_vars` to the user's selection — this hides design
  vars from print output (they're in `@data` but not in the user's selection)
- Normalises `visible_vars` to `NULL` when result is empty (e.g. user selects
  only design variables) — `NULL` means "show all columns in @data"
- Deletes `@metadata` entries for physically removed columns only
- `select()` is irreversible within a pipeline: removed columns are gone

### rename() Specifics
- Uses `.sc_update_design_var_names()` (wrapper in `R/utils.R`) to update
  @variables keys; the wrapper resolves `surveycore:::.update_design_var_names`
  via `get(..., envir = asNamespace("surveycore"))` to avoid the
  `:::`-induced R CMD check NOTE
- Uses `.sc_rename_metadata_keys()` (wrapper in `R/utils.R`) for @metadata keys
- **Warns** (does not error) if user renames a design variable; updates
  `@variables` to track the new column name (`surveytidy_warning_rename_design_var`)
- Bypasses S7 validation during the @data + @variables update (per-assignment
  validation rejects the intermediate state); calls `S7::validate()` once at
  the end on the consistent state

### `:::` policy (project rule)
Never call `surveycore:::*` directly — it raises a "Unexported object" NOTE
under R CMD check. Instead, add a thin wrapper in `R/utils.R` that uses
`get("name", envir = asNamespace("surveycore"))`. Existing wrappers:
`.sc_update_design_var_names()`, `.sc_rename_metadata_keys()`.

### dplyr_reconstruct()
- Called by dplyr for complex operations (joins, across(), slice, etc.)
- Must rebuild survey class from `data` + `template`
- Errors with `surveycore_error_design_var_removed` if design cols deleted

### subset.survey_base
- Physical subsetting (actually removes rows, unlike filter)
- Always issues `surveycore_warning_physical_subset`
- Registered via NAMESPACE (base R generic, not dplyr)

## R CMD Check Gotchas

### Examples must load dplyr/tidyr explicitly
dplyr verbs (`filter`, `select`, `arrange`, etc.) are in **Imports** but are **not re-exported**.
R CMD check runs examples in a fresh session with only `library(surveytidy)` loaded — the dplyr
functions are not on the search path. Every `@examples` block that calls a dplyr or tidyr verb
must begin with an explicit `library()` call:

```r
#' @examples
#' library(dplyr)        # required — dplyr verbs not re-exported by surveytidy
#' df <- data.frame(...)
#' d  <- surveycore::as_survey(df, weights = wt)
#' arrange(d, y)
```

Use `library(tidyr)` instead for `drop_na()` and other tidyr verbs.

## Working With This Codebase

1. **Follow established patterns** — consistency with surveycore matters
2. **Update metadata automatically** — verbs should handle @variables/@metadata updates
3. **Test all combinations** — each verb tested with all three design types (taylor, replicate, twophase)
4. **Check domain preservation** — domain column should survive all operations intact
5. **Provide complete code blocks** — ready to copy and use
6. **Include tests** — always provide corresponding tests for new verbs

## Common commands

```r
devtools::document()  # rebuild NAMESPACE + man/ from roxygen
devtools::test()      # run testthat suite
devtools::check()     # full R CMD check (use --as-cran near submission)
covr::package_coverage()  # line coverage
```

## Reference Documents

All planning documents are in `plans/`.

Local rules in `.claude/rules/` are authoritative for surveytidy. The
ecosystem-wide copies under `../survey-standards/.claude/rules/` are a
historical mirror; the local versions override on any divergence.

PR workflow: `.claude/rules/github-strategy.md`

---

**Always defer to surveycore's CLAUDE.md for survey class internals. surveytidy is an add-on layer.**
