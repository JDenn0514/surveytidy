# feature/rename-with — .apply_rename_map() refactor + rename_with.survey_base()

| Field | Value |
|-------|-------|
| **Package** | surveytidy |
| **Phase** | dedup-rename-rowwise |
| **Branch** | feature/rename-with |
| **PR** | TBD |
| **Date** | 2026-02-24 |

## Executive Summary

Extracts `.apply_rename_map()` from `rename.survey_base()` so both `rename()`
and `rename_with()` share the atomic-update logic. Adds `rename_with()` for
function-based column renaming. Three behavioral improvements are introduced
by the refactor: `@groups` is now updated when a renamed column was grouped,
the domain column is silently blocked from being renamed, and the warning
message no longer includes the calling function name (snapshot updated).

Also fixes a pre-existing limitation where renaming twophase design variables
(phase1/phase2 nested keys, subset column) would not update `@variables` —
both `rename()` and `rename_with()` now correctly update all design variables
including the twophase-specific nested structure.

---

## Commits

### `refactor(rename): extract .apply_rename_map() shared helper`

**Purpose:** Share atomic-update logic between `rename()` and `rename_with()`.

**Key changes:**

- `R/rename.R` (modified): extracted `.apply_rename_map(.data, rename_map)`:
  - Silently blocks renaming `SURVEYCORE_DOMAIN_COL` (domain column has fixed
    identity; renaming would break `filter()` and estimation)
  - Warns `surveytidy_warning_rename_design_var` when any renamed column is
    a protected design variable (domain col and regular design vars combined
    into a single warning)
  - Atomically updates `@data`, `@variables`, `@metadata`, `visible_vars`,
    and `@groups` via `attr()` bypass + `S7::validate()` at end
  - **New: `@groups` updated** — if a renamed column appeared in `@groups`,
    the old name is replaced with the new name
  - **New: twophase support** — updates `@variables$phase1`, `@variables$phase2`,
    and `@variables$subset` (previously these were not updated when renaming
    twophase design variables)
  - Warning message changed: no longer includes `"rename()"` (shared helper
    cannot hardcode a calling function name)
  - `rename.survey_base()` reduced to a thin wrapper that builds the
    rename_map and delegates to `.apply_rename_map()`

- `tests/testthat/_snaps/rename.md` (updated): snapshot reflects the new
  warning message text (no longer says `"rename() renamed design variable(s)"`)

### `feat(rename): add rename_with.survey_base()`

**Purpose:** Function-based column renaming per spec §IV.

**Key changes:**

- `R/rename.R` (modified): added `rename_with.survey_base()`:
  - Resolves `.cols` via `tidyselect::eval_select(rlang::enquo(.cols), ...)` —
    `enquo` captures caller's environment so tidyselect helpers (e.g.,
    `starts_with()`) work correctly
  - Converts `.fn` via `rlang::as_function()` (supports bare functions,
    `~formula`, `\(x) lambda` syntax)
  - Forwards `...` to `.fn` via `rlang::exec()` + `!!!rlang::list2(...)`
  - Validates `.fn` output: non-character, wrong length, duplicates, conflicts
    — all raise `surveytidy_error_rename_fn_bad_output`
  - Delegates to `.apply_rename_map()` for the atomic update

- `R/reexports.R` (modified): added `dplyr::rename_with` re-export

- `R/zzz.R` (modified): registered `rename_with` S3 method under
  `# ── feature/rename` section

- `tests/testthat/test-rename.R` (modified): added 15 new test blocks
  covering all spec §VI.3 sections — happy paths, design var warning, domain
  col protection, `@groups` staleness, error cases (dual pattern), and
  refactor regression

- `_pkgdown.yml` (modified): added `rename_with.survey_base` to Columns section
