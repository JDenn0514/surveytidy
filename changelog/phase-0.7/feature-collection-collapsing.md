# feat(collection): collapsing verbs for survey_collection

**Date**: 2026-04-29
**Branch**: feature/survey-collection-collapsing
**Phase**: Phase 0.7
**Spec**: `plans/spec-survey-collection.md` (§V.1, §V.2, §IX.3)
**Implementation plan**: `plans/impl-survey-collection.md` (PR 3)

## What Changed

PR 3 of the survey_collection verb-dispatch arc. Adds the two collapsing
verbs — `pull.survey_collection` (returns a vector) and
`glimpse.survey_collection` (prints diagnostic output) — neither of which
routes through `.dispatch_verb_over_collection` because their results are
not `survey_collection`s. Both iterate per-member directly.

### New: `R/collection-pull-glimpse.R`

#### `pull.survey_collection(.data, var = -1, name = NULL, ..., .if_missing_var = NULL)`

Per spec §V.1:

- Iterates per-member, calling `dplyr::pull(member, var, name)` inside a
  local `tryCatch` that mirrors `.apply_class_catch()` from the dispatcher.
  Catches `vctrs_error_subscript_oob` and
  `rlang_error_data_pronoun_not_found` (plus the `rlang_error` parent-walk
  case for the `all_of()` wrap path), routing through
  `.handle_class_catch()` so `.if_missing_var` resolution and the typed
  message-or-error are shared with the dispatcher's verb path. Class-catch
  detection only — no pre-check; verifies the Issue 22 / Pass 2 fix that
  tidyselect helpers like `last_col()` are not flagged as missing.
- Detects the by-survey naming sentinel (`name = coll@id`) by evaluating
  the captured `name` quosure once and comparing the result against
  `.data@id`. When the sentinel matches, the inner `dplyr::pull` is called
  with `name = NULL` (avoiding a column-lookup attempt for the sentinel
  string), and per-survey names are applied after the cross-survey
  combination.
- Combines per-member results via `vctrs::vec_c(!!!unname(results))`.
  Unnaming the outer list before splicing prevents the
  `cannot merge outer name ... with vector of length > 1` failure that
  vctrs raises for named splice elements where any element is multi-row.
- Re-raises `vctrs_error_incompatible_type` as
  `surveytidy_error_collection_pull_incompatible_types` with
  `parent = cnd` so the original vctrs chain is preserved. Names the
  column and the surveys involved. No auto-coercion; contrasts with
  `glimpse`'s footer-renderer behaviour. (`pull` is computational;
  `glimpse` is diagnostic.)
- Domain inclusion: returns both in-domain and out-of-domain rows
  (inherits `pull.survey_base`'s contract — `dplyr::pull` does not filter
  on the domain column).

The duplicated class-catch handler is acceptable per
`engineering-preferences.md` §3 — generalising the dispatcher to also
support collapsing return types is over-engineering until a third
collapsing verb appears.

#### `glimpse.survey_collection(x, width = NULL, ..., .by_survey = FALSE)`

Per spec §V.2:

- **Default mode** binds every member's `@data` into a single tibble (via
  `dplyr::bind_rows()` with `.id = coll@id`) and glimpses the result.
  Type conflicts are pre-coerced via `vctrs::vec_ptype_common()` (with a
  character fallback for incompatible types and lossy casts) so that
  `bind_rows` does not raise `vctrs_error_incompatible_type` — vctrs no
  longer auto-coerces in `bind_rows` as the spec assumed, so the
  coercion is now done explicitly.
- **Pre-flight id-collision check** raises
  `surveytidy_error_collection_glimpse_id_collision` BEFORE binding when
  any member's `@data` already contains a column named `coll@id`.
  Symmetric with surveycore's `surveycore_error_collection_id_collision`
  for collisions introduced after construction (e.g., via `mutate(coll,
  .survey = ...)`).
- **Display rename:** when `surveycore::SURVEYCORE_DOMAIN_COL`
  (`..surveycore_domain..`) is present in the bound (or per-member)
  tibble, the local copy is renamed to `.in_domain` for the rendered
  output. Per-member `@data` is untouched; the rename is unconditional
  when the column is present.
- **Type-coercion footer** prints when `.detect_glimpse_type_conflicts()`
  reports any conflicts. Truncates after 5 columns (D7) and caps line
  width at 80 characters; when more than 5 columns have conflicts,
  appends `+ N more conflicting columns`. Footer is `cat()`-based (not
  `cli::cli_*`) so output is captured by `capture.output()` for tests
  and so the symbols render reliably across renderers.
- **Per-survey mode (`.by_survey = TRUE`)** prints a labelled `▸ <name>`
  header per member followed by `dplyr::glimpse(member_data_for_display)`.
  Skips both the id-collision check and the bind step. Same `.in_domain`
  display rename per member.
- Returns `invisible(x)` in both modes.

Non-ASCII characters in user-facing strings (`▸`, `→`) are written via
`\u` escapes (`▸`, `→`) so R CMD check's portability check
passes; comments retain the raw symbols (allowed by R CMD check).

### Modified: `R/zzz.R`

Two `registerS3method()` calls in the `# ── survey_collection: collapsing
verbs (PR 3) ──` block, registering `pull.survey_collection` and
`glimpse.survey_collection` against `"surveycore::survey_collection"` to
the `dplyr` namespace.

### Modified: `DESCRIPTION`

Added `vctrs (>= 0.6.0)` to `Imports` (used by `pull.survey_collection`
for `vctrs::vec_c()` and by `glimpse.survey_collection` for
`vctrs::vec_ptype_common()` / `vctrs::vec_cast()`).

### Modified: `plans/error-messages.md`

Added two rows:

- `surveytidy_error_collection_pull_incompatible_types`
- `surveytidy_error_collection_glimpse_id_collision`

### New: `tests/testthat/test-collection-pull.R`

110 tests covering:

- Happy path across all design types in `make_test_collection()` —
  combined-vector length matches sum of per-member nrow; unnamed.
- Naming variants: `name = NULL`, `name = coll@id` (default `.survey`
  and user-set `"wave"`), `name = "<other_col>"` (per-row names from
  another column).
- Class-catch detection: `tidyselect::all_of("region")` raises
  `surveytidy_error_collection_verb_failed` with `parent =
  vctrs_error_subscript_oob`; same for `name = "region"`. Bare-name
  references that produce `rlang_error → simpleError "object not
  found"` are out-of-scope per spec §V.1 step 2.
- `.if_missing_var = "skip"` drops bad members; `surveytidy_message_
  collection_skipped_surveys` fires; output length matches the surviving
  members' nrow sum.
- Empty-result error: every member skipped raises
  `surveytidy_error_collection_verb_emptied` (covering both
  `id_from_stored = TRUE` and per-call `.if_missing_var` branches).
- `vctrs::vec_c()` type incompatibility: a 2-member fixture with
  `flag = chr` on m1 and `flag = int` on m2 produces
  `surveytidy_error_collection_pull_incompatible_types` with `parent =
  vctrs_error_incompatible_type`. Snapshot.
- Domain inclusion: pre-filtered collection with `y1 > 60` retains both
  in-domain and out-of-domain rows; output length matches per-member
  nrow sum, not the in-domain count.
- `tidyselect::last_col()` resolves correctly on a homogeneous all-taylor
  collection (verifies class-catch over pre-check from Issue 22).

### New: `tests/testthat/test-collection-glimpse.R`

137 tests covering:

- Happy-path render in default mode: row count matches sum of per-member
  nrow; default `.survey` id column appears; `withVisible()` confirms
  invisible return.
- Custom `coll@id`: `"wave"` shows up as the prepended column; default
  `.survey` does not.
- Id-collision pre-flight: a 2-member fixture where m2's `@data` already
  contains a `.survey` column raises
  `surveytidy_error_collection_glimpse_id_collision` BEFORE binding;
  message names the offending member and column. Snapshot.
- Domain-column rename for display: pre-filtered collection's render
  shows `.in_domain` instead of `..surveycore_domain..`; per-member
  `@data` retains the original name. Negative case: collection without
  domain column has no `.in_domain` in render.
- `.by_survey = TRUE` mode: per-member labelled headers; no prepended
  `.survey` id; `.in_domain` rename applied per member; invisible
  return; id-collision check is skipped (collisions are tolerated).
- Type-coercion footer: 0 conflicts → no footer; 1 conflict →
  one-row footer with `coerced to`; 6 conflicts → first 5 shown plus
  `+ 1 more conflicting column`; line width cap at 80 chars;
  many-member overflow forces the trailing-ellipsis truncation branch.

## Verification

- `devtools::test()` — 19,234 tests pass (0 failures, 0 warnings, 0
  skips)
- `devtools::check()` — 0 errors, 0 warnings, 1 pre-approved note
  (timestamp note)
- `covr::package_coverage()` — 97.31% on
  `R/collection-pull-glimpse.R`; 99.55% package-wide
- `air format` — applied to all touched files

## Files Modified

- `R/collection-pull-glimpse.R` — new file:
  `pull.survey_collection`, `glimpse.survey_collection`, plus helpers
  (`.pull_apply_class_catch`, `.detect_glimpse_type_conflicts`,
  `.render_glimpse_type_conflict_footer`, `.coerce_conflicting_columns`,
  `.rename_domain_for_display`, `symbol_pointer`)
- `R/zzz.R` — filled PR 3 registration block (2 `registerS3method` calls)
- `DESCRIPTION` — added `vctrs (>= 0.6.0)` to `Imports`
- `tests/testthat/test-collection-pull.R` — new
- `tests/testthat/test-collection-glimpse.R` — new
- `tests/testthat/_snaps/collection-pull.md` — new (snapshot)
- `tests/testthat/_snaps/collection-glimpse.md` — new (snapshot)
- `plans/error-messages.md` — added
  `surveytidy_error_collection_pull_incompatible_types` and
  `surveytidy_error_collection_glimpse_id_collision`
- `man/glimpse.Rd`, `man/pull.Rd` — regenerated for the new collection
  methods
- `plans/impl-survey-collection.md` — PR 3 to be marked complete
