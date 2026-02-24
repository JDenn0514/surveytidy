# surveytidy Package Development

**Part of the [surveyverse
ecosystem](https://jdenn0514.github.io/survey-standards/ECOSYSTEM.md) —
see there for ecosystem vision, architecture, and how surveytidy relates
to other packages.**

------------------------------------------------------------------------

## Project Overview

surveytidy provides dplyr/tidyr verbs for survey design objects from
surveycore. It extends tidyverse workflows to work seamlessly with
complex survey designs, allowing users to filter, select, mutate, and
group survey objects while maintaining proper variance estimation and
metadata handling.

## Package Information

- **Name:** surveytidy
- **Purpose:** dplyr/tidyr verbs for survey objects (filter, select,
  mutate, rename, arrange, group_by, etc.)
- **Target Audience:** Survey researchers using tidyverse; users
  transitioning from srvyr
- **Current Status:** Phase 0.5 (planning complete; implementation
  starting)
- **License:** GPL-3 (inherits from surveycore)
- **Dependencies:** surveycore (imports core S7 classes)

## Vision & Goals

surveytidy makes survey analysis feel natural to tidyverse users by:

1.  **Domain-aware filtering** —
    [`filter()`](https://dplyr.tidyverse.org/reference/filter.html)
    marks rows in/out of domain without removing them
2.  **Intelligent metadata handling** —
    [`select()`](https://dplyr.tidyverse.org/reference/select.html) and
    [`rename()`](https://dplyr.tidyverse.org/reference/rename.html)
    update labels automatically
3.  **Group-by support** —
    [`group_by()`](https://dplyr.tidyverse.org/reference/group_by.html)
    sets up stratification for Phase 1 estimation functions
4.  **Familiar API** — Users never write formula syntax; everything uses
    bare names (tidy-select)

## Key Design Decisions (Finalized)

- **dplyr verbs map to survey concepts** — filter = domain, select =
  simplify data (remove non-design cols), mutate = add variables
- **Metadata travels with data** — All verbs update `@variables` and
  `@metadata` keys
- **Filter preserves all rows** — Uses domain column internally; never
  removes rows
- **No formula syntax** — Always `filter(design, age > 65)`, never
  `filter(design, ~age > 65)`
- **S3 dispatch via registerS3method()** — Not S7 methods; dplyr’s S3
  dispatch works for all survey classes

## dplyr Dispatch Pattern (CRITICAL)

S7 namespaced class names break S3 dispatch. To make dplyr verbs work:

``` r
# In .onLoad():
registerS3method(
  "filter", "surveycore::survey_base",
  get("filter.survey_base", envir = ns),
  envir = asNamespace("dplyr")
)
```

This registers the S3 method with dplyr’s environment so dispatch works.

See `R/zzz.R` for full setup.

## Architecture

### File Organization (R/)

    R/
    ├── arrange.R              # arrange.survey_base (row sorting)
    ├── filter.R               # filter.survey_base + subset.survey_base
    ├── group-by.R             # group_by.survey_base + ungroup.survey_base
    ├── joins.R                # *_join() (stretch goals)
    ├── mutate.R               # mutate.survey_base (warns on weight column modification)
    ├── rename.R               # rename.survey_base (auto-updates @variables + @metadata keys)
    ├── select.R               # select + relocate + pull + glimpse
    ├── slice.R                # all slice_*.survey_base via factory
    ├── surveytidy-package.R   # Package-level documentation
    ├── drop-na.R              # drop_na.survey_base
    ├── utils.R                # shared helpers (.protected_cols, dplyr_reconstruct, etc.)
    └── zzz.R                  # .onLoad(): S3 method registration + S7::methods_register()

### Test Organization (tests/testthat/)

    tests/testthat/
    ├── helper-test-data.R      # Shared test data generators (copied from surveycore)
    ├── test-filter.R           # filter() and related domain operations
    ├── test-select.R           # select(), pull(), glimpse()
    ├── test-mutate.R           # mutate() behavior + weight column warnings
    ├── test-rename.R           # rename() + automatic metadata updates
    ├── test-arrange.R          # arrange(), slice_*()
    ├── test-group-by.R         # group_by(), ungroup()
    └── test-tidyr.R            # tidyr functions (drop_na, separate, unite)

### Key Concepts

#### Domain Column

- Name: `"..surveycore_domain.."` (use
  [`surveycore::SURVEYCORE_DOMAIN_COL`](https://jdenn0514.github.io/surveycore/reference/SURVEYCORE_DOMAIN_COL.html))
- Type: logical column in `@data`
- Content: TRUE for in-domain rows, FALSE for out-of-domain rows
- Never removed; only created/updated by
  [`filter()`](https://dplyr.tidyverse.org/reference/filter.html)

#### visible_vars

- Key in `@variables$visible_vars`
- Set by [`select()`](https://dplyr.tidyverse.org/reference/select.html)
  to the user’s explicit column selection
- Controls which columns [`print()`](https://rdrr.io/r/base/print.html)
  shows (hides design vars from display)
- NULL means all columns in `@data` are shown (default)
- After [`select()`](https://dplyr.tidyverse.org/reference/select.html),
  `@data` only contains design vars + user-selected cols; `visible_vars`
  tracks the user’s selection so design vars are hidden from print

#### @groups

- Reserved for Phase 0.5 (now used by
  [`group_by()`](https://dplyr.tidyverse.org/reference/group_by.html))
- Populated by
  [`group_by()`](https://dplyr.tidyverse.org/reference/group_by.html),
  cleared by
  [`ungroup()`](https://dplyr.tidyverse.org/reference/group_by.html)
- Will be used by Phase 1 estimation functions

#### dplyr_reconstruct()

- Required for complex pipelines (joins, across(), slice, etc.)
- Rebuilds survey class from reconstructed `data` + original template
- Errors if design variables are removed

## Before Starting Any Implementation

**Start here:** - `.claude/WORKFLOW.md` — how the planning,
implementation, and PR cycles fit together

**Rules (always apply — loaded at session start):** 1.
`.claude/rules/code-style.md` — indentation, pipe operator, air
formatter, S7 patterns, cli error structure, argument order, helper
placement 2. `.claude/rules/r-package-conventions.md` — `::` usage,
NAMESPACE, roxygen2, `@return`, `@examples`, export policy 3.
`.claude/rules/surveytidy-conventions.md` — S3 dispatch, verb method
names, special columns (domain, visible_vars, @groups), return
visibility 4. `.claude/rules/testing-standards.md` — test structure,
coverage requirements, assertion patterns, data generators 5.
`.claude/rules/testing-surveytidy.md` — `test_invariants()`, three
design type loops, domain preservation, verb error patterns 6.
`.claude/rules/engineering-preferences.md` — DRY, well-tested,
engineered enough, explicit over clever

**Skills (invoke on-demand):** - `.claude/skills/spec-workflow/SKILL.md`
— planning arc: draft → review → implementation plan → decisions log -
`.claude/skills/r-implement/SKILL.md` — implementation loop: read plan →
write code → verify → mark done -
`.claude/skills/commit-and-pr/SKILL.md` — PR cycle: changelog →
pre-flight → commit → PR → CI

**GitHub strategy (read when creating PRs):** -
`.claude/rules/github-strategy.md` — branching model, commit format, PR
workflow, CI/CD setup

**Reference:** - `../surveycore/CLAUDE.md` — surveycore architecture
(survey class structure, @data/@variables/@metadata) -
`plans/error-messages.md` — surveytidy error/warning classes (update
before adding any new class)

## Phase 0.5 Build Order

1.  `feature/filter` — `R/01-filter.R` + `tests/testthat/test-filter.R`
2.  `feature/select` — `R/02-select.R` + `tests/testthat/test-select.R`
3.  `feature/mutate` — `R/03-mutate.R` + `tests/testthat/test-mutate.R`
4.  `feature/rename` — `R/04-rename.R` + `tests/testthat/test-rename.R`
5.  `feature/arrange` — `R/05-arrange.R` +
    `tests/testthat/test-arrange.R`
6.  `feature/group-by` — `R/06-group-by.R` +
    `tests/testthat/test-group-by.R`
7.  `feature/tidyr` — `R/07-tidyr.R` + `tests/testthat/test-tidyr.R`
    (stretch)
8.  `feature/joins` — `R/08-joins.R` + `tests/testthat/test-joins.R`
    (stretch)

------------------------------------------------------------------------

## Key Implementation Details

### filter() Specifics

- Stores conditions in `@variables$domain` (list of quosures)
- Chained filters AND the masks: `existing_domain & new_mask`
- Empty domain (all FALSE) triggers `surveycore_warning_empty_domain`
- `.by` argument not supported; raises
  `surveycore_error_filter_by_unsupported`

### select() Specifics

- **Physically removes** non-selected, non-design columns from `@data`
- **Always keeps** all design variables in `@data` (weights, strata,
  PSU, FPC, repweights, domain column) — they are required for variance
  estimation
- Sets `@variables$visible_vars` to the user’s selection — this hides
  design vars from print output (they’re in `@data` but not in the
  user’s selection)
- Normalises `visible_vars` to `NULL` when result is empty (e.g. user
  selects only design variables) — `NULL` means “show all columns in
  @data”
- Deletes `@metadata` entries for physically removed columns only
- [`select()`](https://dplyr.tidyverse.org/reference/select.html) is
  irreversible within a pipeline: removed columns are gone

### rename() Specifics

- Uses `surveycore:::.update_design_var_names()` to update @variables
  keys
- Uses `surveycore:::.rename_metadata_keys()` to update @metadata keys
- **Warns** (does not error) if user renames a design variable; updates
  `@variables` to track the new column name
  (`surveytidy_warning_rename_design_var`)

### dplyr_reconstruct()

- Called by dplyr for complex operations (joins, across(), slice, etc.)
- Must rebuild survey class from `data` + `template`
- Errors with `surveycore_error_design_var_removed` if design cols
  deleted

### subset.survey_base

- Physical subsetting (actually removes rows, unlike filter)
- Always issues `surveycore_warning_physical_subset`
- Registered via NAMESPACE (base R generic, not dplyr)

## R CMD Check Gotchas

### Examples must load dplyr/tidyr explicitly

dplyr verbs (`filter`, `select`, `arrange`, etc.) are in **Imports** but
are **not re-exported**. R CMD check runs examples in a fresh session
with only
[`library(surveytidy)`](https://jdenn0514.github.io/surveytidy/) loaded
— the dplyr functions are not on the search path. Every `@examples`
block that calls a dplyr or tidyr verb must begin with an explicit
[`library()`](https://rdrr.io/r/base/library.html) call:

``` r
#' @examples
#' library(dplyr)        # required — dplyr verbs not re-exported by surveytidy
#' df <- data.frame(...)
#' d  <- surveycore::as_survey(df, weights = wt)
#' arrange(d, y)
```

Use [`library(tidyr)`](https://tidyr.tidyverse.org) instead for
[`drop_na()`](https://tidyr.tidyverse.org/reference/drop_na.html) and
other tidyr verbs.

## Working With This Codebase

1.  **Follow established patterns** — consistency with surveycore
    matters
2.  **Update metadata automatically** — verbs should handle
    @variables/@metadata updates
3.  **Test all combinations** — each verb tested with all three design
    types (taylor, replicate, twophase)
4.  **Check domain preservation** — domain column should survive all
    operations intact
5.  **Provide complete code blocks** — ready to copy and use
6.  **Include tests** — always provide corresponding tests for new verbs

## Reference Documents

All planning documents are in `plans/`: - (Currently minimal; will grow
as Phase 0.5 proceeds)

All finalized decisions are in `../survey-standards/.claude/rules/`: -
`code-style.md` — R style, S7 patterns, error conventions, function
design, roxygen/package check - `testing-standards.md` — test structure,
coverage, assertion patterns, test data

PR workflow: `.claude/skills/github-strategy.md`

------------------------------------------------------------------------

**Always defer to surveycore’s CLAUDE.md for survey class internals.
surveytidy is an add-on layer.**
