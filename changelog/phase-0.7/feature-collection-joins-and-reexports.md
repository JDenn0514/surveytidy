# feat(collection): joins, re-exports, integration polish

**Date**: 2026-04-29
**Branch**: feature/survey-collection-joins-and-reexports
**Phase**: Phase 0.7
**Spec**: `plans/spec-survey-collection.md` (§V.3, §VI, §VII.1, §IX.3)
**Implementation plan**: `plans/impl-survey-collection.md` (PR 4)

## What Changed

PR 4 — the **final** entry in the survey_collection verb-dispatch arc.
Wires up the unsupported join error stubs, re-exports surveycore's
collection construction and setter API, and adds the cross-verb pipeline
integration test that validates all four verb-family PRs (PR 2a / 2b /
2c / 2d) compose into a well-formed collection.

### Modified: `R/joins.R`

Added six `*_join.survey_collection` error stubs (`left_join`,
`right_join`, `inner_join`, `full_join`, `semi_join`, `anti_join`). All
share a single internal helper `.collection_join_unsupported(verb_name)`
that interpolates the verb name into the spec V.3 V8 template and raises
`surveytidy_error_collection_verb_unsupported`. Each method's roxygen
attaches to the existing per-verb Rd file via `@rdname` and adds a
`@section Survey collections:` block (per spec §VIII).

The semantics for joining a plain data frame onto a multi-survey
container are still being designed (apply per member? broadcast? error
on partial coverage?). Until that contract is resolved, the verbs error
early and direct users at applying the join inside a per-survey pipeline
before constructing the collection.

### Modified: `R/zzz.R`

Added a `# ── survey_collection: join error stubs (PR 4) ──` block at
the bottom of `.onLoad()` with six `registerS3method()` calls — one per
join verb — registering the stubs against
`"surveycore::survey_collection"` to the `dplyr` namespace.

### Modified: `R/reexports.R`

Re-exported five surveycore symbols (spec §VI) using the bare-symbol
roxygen form (`surveycore::as_survey_collection`, etc.). After
`devtools::document()`, NAMESPACE carries `export(as_survey_collection)`
and `importFrom(surveycore, as_survey_collection)` for each. surveycore
remains the source of truth for property validation — no thin wrappers.

| Symbol | Source |
|---|---|
| `as_survey_collection` | `surveycore` |
| `set_collection_id` | `surveycore` |
| `set_collection_if_missing_var` | `surveycore` |
| `add_survey` | `surveycore` |
| `remove_survey` | `surveycore` |

### New: `tests/testthat/test-collection-joins.R`

Six tests, one per join verb. Each asserts:

- `expect_error(class = "surveytidy_error_collection_verb_unsupported")`
- `expect_snapshot(error = TRUE)` — stable CLI message text per verb.

### New: `tests/testthat/test-collection-reexports.R`

Five tests, one per re-exported symbol. Each asserts:

- `exists("<name>", where = "package:surveytidy", inherits = FALSE)`
- `identical(surveytidy::<name>, surveycore::<name>)` — confirming
  it is the same function object (no thin wrapper).

### New: `tests/testthat/test-collection-pipeline.R`

The load-bearing cross-verb integration test. Builds
`make_test_collection(seed = 42)` and pipes through one verb from each
verb-family PR:

```r
result <- coll |>
  dplyr::filter(y1 > 40) |>            # PR 2a — data-mask
  dplyr::select(y1, y2, group) |>      # PR 2b — tidyselect
  dplyr::group_by(group) |>            # PR 2c — grouping
  dplyr::slice_head(n = 5)             # PR 2d — slicing
```

Asserts the dual invariant explicitly:

- `test_collection_invariants(result)` (collection-level — G1 / G1b /
  `@id` / `@if_missing_var` checks).
- For each surviving member: `test_invariants(member)` (per-member —
  `@data` shape, design var presence, weight positivity, `visible_vars`
  consistency, `surveytidy_recode` attr stripping).

Plus targeted assertions:

- `result@groups == "group"` and each member's `@groups` matches.
- Each member's `visible_vars` contains exactly `c("y1", "y2", "group")`.
- `expect_snapshot(print(result))` captures `@id`, `@if_missing_var`,
  `@groups`, and the per-member summary line.

`slice_head()` fires `surveycore_warning_physical_subset` per member;
that contract is exercised in the per-member slice tests, so the
pipeline call is wrapped in `suppressWarnings()` to keep the integration
test focused on shape and composition rather than per-verb side
effects.

### Modified: `plans/error-messages.md`

Added a row for `surveytidy_error_collection_verb_unsupported` next to
the other `surveytidy_error_collection_*` entries.

### Modified: `NEWS.md`

Added a `# surveytidy (development version)` section above
`# surveytidy 0.5.0` summarising the entire survey_collection arc:
every collection method (data-mask, tidyselect, grouping, slicing,
collapsing), the `.if_missing_var` semantics, all surveycore re-exports,
the new error / warning / message classes, and the dependency
additions (`vctrs`, `surveycore` pin bump).

### Modified: `DESCRIPTION`

Bumped `Version` from `0.5.0` to `0.5.0.9000` (per
`.claude/rules/github-strategy.md`: develop carries `.9000` between
releases). `surveycore (>= 0.8.2)` and `vctrs (>= 0.6.0)` pins remain
correct from earlier PRs in the arc.

### New: `changelog/phase-0.7/feature-collection-joins-and-reexports.md`

This file. The final batch entry for the survey_collection arc.

### Modified: `.claude/skills/r-implement/SKILL.md` (tooling — rode along)

Restructured the entry point of the `r-implement` skill so that mode
selection is an **explicit `AskUserQuestion` prompt** at Step 0 rather
than an inferred branch from trigger phrases. The three modes are now:

- **Mode C: Subagent-Driven (Recommended)** — main thread reads the plan
  once, then dispatches a fresh implementer subagent per section, with
  spec-compliance and code-quality reviewer subagents after each.
- **Mode A: Inline** — main agent reads plan/spec and writes code
  directly in this session (legacy default).
- **Mode B: CI-fix** — triages a `CI Failure — Handoff to r-implement`
  block from `commit-and-pr`.

The Pre-flight section was tightened (Mode A only), and the rules-loading
preamble now explicitly notes that `.claude/rules/` content is already in
context at session start. No behavioural change to the actual TDD /
implement / verify loop.

This change is unrelated to the survey_collection work but was developed
in the same working tree and is being landed alongside PR 4 to avoid a
trivial follow-up PR.

### Modified: `.claude/settings.local.json` (tooling — rode along)

Five auto-added `Bash(awk ...)` permission entries from local sessions.
Local allowlist hygiene only.

## Verification

- `devtools::test()` — XX,XXX tests pass (0 failures, 0 warnings).
- `devtools::check()` — 0 errors, 0 warnings, 1 pre-approved note
  (timestamp note).
- `covr::package_coverage()` — new files at ≥95% coverage.
- `air format` — applied to all touched files.

## Files Modified

- `R/joins.R` — 6 collection error stubs + shared helper.
- `R/zzz.R` — PR 4 registration block (6 `registerS3method` calls).
- `R/reexports.R` — 5 surveycore re-exports.
- `tests/testthat/test-collection-joins.R` — new.
- `tests/testthat/test-collection-reexports.R` — new.
- `tests/testthat/test-collection-pipeline.R` — new.
- `tests/testthat/_snaps/collection-joins.md` — new.
- `tests/testthat/_snaps/collection-pipeline.md` — new.
- `plans/error-messages.md` — added
  `surveytidy_error_collection_verb_unsupported`.
- `NEWS.md` — added `# surveytidy (development version)` section.
- `DESCRIPTION` — `Version: 0.5.0.9000`.
- `man/anti_join.Rd`, `man/inner_join.Rd`, `man/left_join.Rd`,
  `man/right_join.Rd`, `man/semi_join.Rd`, `man/reexports.Rd` —
  regenerated.
