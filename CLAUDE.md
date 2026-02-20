# surveytidy Package Development

**Part of the [surveyverse ecosystem](../survey-standards/ECOSYSTEM.md) — see there for ecosystem vision, architecture, and how surveytidy relates to other packages.**

---

## Project Overview

surveytidy provides dplyr/tidyr verbs for survey design objects from surveycore.
It extends tidyverse workflows to work seamlessly with complex survey designs,
allowing users to filter, select, mutate, and group survey objects while
maintaining proper variance estimation and metadata handling.

## Package Information

- **Name:** surveytidy
- **Purpose:** dplyr/tidyr verbs for survey objects (filter, select, mutate, rename, arrange, group_by, etc.)
- **Target Audience:** Survey researchers using tidyverse; users transitioning from srvyr
- **Current Status:** Phase 0.5 (planning complete; implementation starting)
- **License:** GPL-3 (inherits from surveycore)
- **Dependencies:** surveycore (imports core S7 classes)

## Vision & Goals

surveytidy makes survey analysis feel natural to tidyverse users by:

1. **Domain-aware filtering** — `filter()` marks rows in/out of domain without removing them
2. **Intelligent metadata handling** — `select()` and `rename()` update labels automatically
3. **Group-by support** — `group_by()` sets up stratification for Phase 1 estimation functions
4. **Familiar API** — Users never write formula syntax; everything uses bare names (tidy-select)

## Key Design Decisions (Finalized)

- **dplyr verbs map to survey concepts** — filter = domain, select = visible columns, mutate = add variables
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

See `R/00-zzz.R` for full setup.

## Architecture

### File Organization (R/)

```
R/
├── 00-zzz.R                # .onLoad(): S3 method registration + S7::methods_register()
├── 01-filter.R             # filter.survey_base, dplyr_reconstruct.survey_base
├── 02-select.R             # select.survey_base, pull.survey_base, glimpse.survey_base
├── 03-mutate.R             # mutate.survey_base (warns on weight column modification)
├── 04-rename.R             # rename.survey_base (auto-updates @variables + @metadata keys)
├── 05-arrange.R            # arrange.survey_base, slice_*.survey_base
├── 06-group-by.R           # group_by.survey_base, ungroup.survey_base
├── 07-tidyr.R              # drop_na(), separate_*(), unite() (stretch goals)
├── 08-joins.R              # *_join() (stretch goals)
└── surveytidy-package.R    # Package-level documentation + @importFrom dplyr
```

### Test Organization (tests/testthat/)

```
tests/testthat/
├── helper-test-data.R      # Shared test data generators (copied from surveycore)
├── test-filter.R           # filter() and related domain operations
├── test-select.R           # select(), pull(), glimpse()
├── test-mutate.R           # mutate() behavior + weight column warnings
├── test-rename.R           # rename() + automatic metadata updates
├── test-arrange.R          # arrange(), slice_*()
├── test-group-by.R         # group_by(), ungroup()
└── test-tidyr.R            # tidyr functions (drop_na, separate, unite)
```

### Key Concepts

#### Domain Column
- Name: `"..surveycore_domain.."` (use `surveycore::SURVEYCORE_DOMAIN_COL`)
- Type: logical column in `@data`
- Content: TRUE for in-domain rows, FALSE for out-of-domain rows
- Never removed; only created/updated by `filter()`

#### visible_vars
- Key in `@variables$visible_vars`
- Set by `select()` to control which columns `print()` shows
- NULL means all columns are visible (default)

#### @groups
- Reserved for Phase 0.5 (now used by `group_by()`)
- Populated by `group_by()`, cleared by `ungroup()`
- Will be used by Phase 1 estimation functions

#### dplyr_reconstruct()
- Required for complex pipelines (joins, across(), slice, etc.)
- Rebuilds survey class from reconstructed `data` + original template
- Errors if design variables are removed

## Before Starting Any Implementation

**Read these files first — in this order — before writing any code:**

**Shared standards (all surveyverse packages follow these):**
1. `../survey-standards/.claude/rules/code-style.md` — indentation, S7 method syntax, error conventions, function design
2. `../survey-standards/.claude/rules/testing-standards.md` — test structure, coverage requirements, assertion patterns
3. `../survey-standards/.claude/rules/r-package-conventions.md` — roxygen2, NAMESPACE, exports, R CMD check hygiene
4. `../survey-standards/.claude/rules/github-strategy.md` — branching model, commit format, PR workflow

**Package-specific (surveytidy only):**
- `.claude/rules/` — any package-specific rules or extensions

**Then reference:**
- `../surveycore/CLAUDE.md` — for surveycore architecture (survey class structure, @data/@variables/@metadata)
- `../surveycore/plans/` — error-messages.md, formal spec, implementation plan

## Phase 0.5 Build Order

1. `feature/filter` — `R/01-filter.R` + `tests/testthat/test-filter.R`
2. `feature/select` — `R/02-select.R` + `tests/testthat/test-select.R`
3. `feature/mutate` — `R/03-mutate.R` + `tests/testthat/test-mutate.R`
4. `feature/rename` — `R/04-rename.R` + `tests/testthat/test-rename.R`
5. `feature/arrange` — `R/05-arrange.R` + `tests/testthat/test-arrange.R`
6. `feature/group-by` — `R/06-group-by.R` + `tests/testthat/test-group-by.R`
7. `feature/tidyr` — `R/07-tidyr.R` + `tests/testthat/test-tidyr.R` (stretch)
8. `feature/joins` — `R/08-joins.R` + `tests/testthat/test-joins.R` (stretch)

---

## Key Implementation Details

### filter() Specifics
- Stores conditions in `@variables$domain` (list of quosures)
- Chained filters AND the masks: `existing_domain & new_mask`
- Empty domain (all FALSE) triggers `surveycore_warning_empty_domain`
- `.by` argument not supported; raises `surveycore_error_filter_by_unsupported`

### select() Specifics
- Updates `@variables$visible_vars` (vector of column names to show in print)
- Keeps all columns in `@data` (doesn't physically remove; just hides)
- If design variable is selected, it still prints even if not in visible_vars

### rename() Specifics
- Uses `surveycore:::.update_design_var_names()` to update @variables keys
- Uses `surveycore:::.rename_metadata_keys()` to update @metadata keys
- Errors if user tries to rename a design variable (strata, ids, etc.)

### dplyr_reconstruct()
- Called by dplyr for complex operations (joins, across(), slice, etc.)
- Must rebuild survey class from `data` + `template`
- Errors with `surveycore_error_design_var_removed` if design cols deleted

### subset.survey_base
- Physical subsetting (actually removes rows, unlike filter)
- Always issues `surveycore_warning_physical_subset`
- Registered via NAMESPACE (base R generic, not dplyr)

## Working With This Codebase

1. **Follow established patterns** — consistency with surveycore matters
2. **Update metadata automatically** — verbs should handle @variables/@metadata updates
3. **Test all combinations** — each verb tested with all three design types (taylor, replicate, twophase)
4. **Check domain preservation** — domain column should survive all operations intact
5. **Provide complete code blocks** — ready to copy and use
6. **Include tests** — always provide corresponding tests for new verbs

## Reference Documents

All planning documents are in `plans/`:
- (Currently minimal; will grow as Phase 0.5 proceeds)

All finalized decisions are in `../survey-standards/.claude/rules/`:
- `code-style.md` — R style, S7 patterns, error conventions, function design
- `testing-standards.md` — test structure, coverage, assertion patterns, test data
- `r-package-conventions.md` — roxygen2, NAMESPACE, exports, R CMD check hygiene
- `github-strategy.md` — branching, commits, PRs, CI/CD, release process

---

**Always defer to surveycore's CLAUDE.md for survey class internals. surveytidy is an add-on layer.**
