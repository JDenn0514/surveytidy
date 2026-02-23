# Changelog Workflow

This is a reference document, not an invocable skill. It defines the canonical
changelog format enforced by `commit-and-pr`.

---

## Location and Timing

```
Location:  changelog/phase-{X}/{branch-name}.md
Timing:    Created LAST on the branch, BEFORE opening the PR
Populated: From git log main..HEAD --oneline
```

Where `{X}` is the current phase number (e.g., `0.5` for Phase 0.5). If unsure,
check the branch name or ask the user.

---

## Entry Format

```markdown
# [type]([scope]): [description]

**Date**: YYYY-MM-DD
**Branch**: feature/[name]
**Phase**: Phase X

## Changes

- [Bullet derived from commit messages describing what changed]
- [One bullet per logical change, not one per commit]

## Files Modified

- `R/[file].R` — [one sentence describing what changed in this file]
- `tests/testthat/test-[file].R` — [one sentence]
- `plans/error-messages.md` — [if new error classes were added]
```

---

## Deriving Content from Commits

Run `git log main..HEAD --oneline` to get the commit list. Use those messages
to populate the `## Changes` section. Group related commits into single bullets
where appropriate (e.g., a sequence of "fix: " commits that address the same
issue can be one bullet).

---

## Validation Rules

These are enforced by `commit-and-pr` before a PR is opened:

1. File must exist at `changelog/phase-{X}/{branch-name}.md`
2. File must not be empty or a stub (no `<!-- TODO -->` placeholders)
3. `## Changes` section must have at least one bullet
4. `## Files Modified` section must list at least one file
5. `**Date**` must be a real date (not a placeholder)

---

## Example

For a branch `feature/filter` in Phase 0.5:

```markdown
# feat(filter): implement domain-aware filter.survey_base

**Date**: 2026-02-23
**Branch**: feature/filter
**Phase**: Phase 0.5

## Changes

- Implement `filter.survey_base()` with domain-aware row marking
- Register S3 method in `.onLoad()` via `registerS3method()` for dplyr dispatch
- Domain conditions stored in `@variables$domain` and AND-accumulated on chaining
- Empty domain triggers `surveycore_warning_empty_domain`
- `.by` argument raises `surveycore_error_filter_by_unsupported`
- Add `plans/error-messages.md` entries for new surveytidy error classes

## Files Modified

- `R/filter.R` — `filter.survey_base()`, `subset.survey_base()`, `dplyr_reconstruct.survey_base()`
- `R/zzz.R` — register S3 methods in `.onLoad()`
- `tests/testthat/test-filter.R` — happy path, error paths, edge cases, all 3 design types
- `plans/error-messages.md` — new `surveytidy_error_filter_non_logical` entry
```
