# surveytidy GitHub Strategy

<!-- Applies to the surveytidy package. Adapted from the surveycore version. -->
<!-- Read on-demand when creating PRs or setting up CI — not auto-loaded. -->

**Version:** 1.0
**Created:** February 2025
**Status:** Decided — do not re-litigate without updating this document

---

## Quick Reference

| Decision | Choice |
|----------|--------|
| Branching model | GitHub Flow — feature branch + self-PR per component |
| Branch naming | `feature/`, `fix/`, `docs/`, `chore/` |
| Long-lived branches | None — `main` is always in-progress |
| Commit format | Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `chore:`) |
| PR template | Lightweight checklist (see below) |
| Merge strategy | Squash and merge |
| PR granularity | One PR per logical unit; one PR per test file |
| Versioning | `0.0.0.9000` dev → `0.1.0` (Phase 0.5 complete) → `1.0.0` |
| CI setup | R-CMD-check + test-coverage + pkgdown |
| NEWS.md | Semi-automated from `git log --oneline` of `feat:` and `fix:` commits |

---

## 1. Branch Protection

### Settings (GitHub → Settings → Branches → Branch protection rules for `main`):
- **Require status checks to pass before merging:** ✅ (R-CMD-check must be green)
- **Require branches to be up to date before merging:** ✅
- **Require pull request reviews before merging:** ❌ (solo author; add when collaborators join)
- **Allow force pushes:** ❌
- **Allow deletions:** ❌

You CAN push directly to `main` for trivial changes (docs, README tweaks), but CI will flag you immediately if the build is broken. All non-trivial changes go through a PR.

---

## 2. Branching Model (GitHub Flow)

Every non-trivial change lives on a feature branch and merges via a self-PR. Trivial changes (typos, comment fixes, README edits) can push directly to `main`.

### Branch lifecycle
```
main
 └── feature/filter         # create branch
      └── (commits)
      └── (CI passes)
      └── (self-PR opened)
      └── (checklist checked off)
      └── (squash merge to main)
      └── (branch deleted)
```

### What gets a branch vs. direct push
| Change type | Branch needed? |
|-------------|---------------|
| New R source file | Yes |
| New test file | Yes |
| Any change to exported function | Yes |
| README / docs update | No |
| Comment or typo fix | No |
| DESCRIPTION metadata | No |
| `.Rbuildignore` / `.gitignore` | No |

---

## 3. Branch Naming

Format: `{type}/{short-description}`

| Prefix | Use for |
|--------|---------|
| `feature/` | New functionality (new R file, new exported function) |
| `fix/` | Bug fix in existing implementation |
| `docs/` | Documentation-only changes (roxygen, README, vignettes) |
| `test/` | Test-only additions or fixes |
| `chore/` | Maintenance (CI config, DESCRIPTION, build tooling) |
| `refactor/` | Internal restructuring with no behavioral change |

### Examples
```
feature/filter
feature/select
feature/mutate
feature/rename
feature/arrange
feature/group-by
feature/drop-na
fix/filter-domain-accumulation
test/filter-cross-design
chore/ci-coverage-workflow
docs/readme-examples
```

---

## 4. PR Granularity

**One PR per logical unit of work.** For dplyr verbs: one PR per verb (or tightly related pair). Never bundle multiple unrelated verbs into one PR because it's faster.

Phase-specific PR maps live in each phase's implementation plan (e.g., `plans/phase-0.5-implementation-plan.md`). The implementation plan is the source of truth for branch names and PR scope — not this file.

---

## 5. Commit Message Format (Conventional Commits)

### Format
```
{type}({scope}): {short description}

[optional body]

[optional footer(s)]
```

### Types
| Type | Use for |
|------|---------|
| `feat` | New exported function, new verb |
| `fix` | Bug fix (behavioral change to existing code) |
| `docs` | Roxygen comments, README, vignettes, plans |
| `test` | Adding or updating tests (no production code change) |
| `chore` | CI config, DESCRIPTION, NAMESPACE, build tooling |
| `refactor` | Internal restructuring with no behavioral change |
| `perf` | Performance improvement (Phase 3+) |

### Scopes (optional but useful)
Use the verb or file name as scope: `filter`, `select`, `mutate`, `rename`, `arrange`, `group-by`, `tidyr`, `utils`, `ci`, `context`

### Examples
```
feat(filter): implement domain-aware filter.survey_base
feat(select): implement select.survey_base with visible_vars
fix(filter): AND-accumulate domain masks across chained filter() calls
test(filter): add cross-design oracle tests for domain estimation
docs(filter): add tidy-select examples to filter.survey_base roxygen
chore(ci): add test-coverage GitHub Actions workflow
chore(description): bump version to 0.1.0 for Phase 0.5 release
```

### Squash merge commit message
Write it as a conventional commit summarizing the whole PR:
```
feat(filter): implement domain-aware filtering for all design types (#3)
```
GitHub auto-appends `(#PR_NUMBER)` if you set the PR title as a conventional commit.

---

## 6. PR Template

`.github/PULL_REQUEST_TEMPLATE.md`:

```markdown
## What

<!-- One sentence: what does this PR add or fix? -->

## Checklist

- [ ] Tests written and passing (`devtools::test()`)
- [ ] R CMD check: 0 errors, 0 warnings (`devtools::check()`)
- [ ] Roxygen docs updated and `devtools::document()` run
- [ ] `plans/error-messages.md` updated (if new errors/warnings added)
- [ ] PR title is a valid Conventional Commit (`feat(scope): description`)
```

Changelog entry format (required before every PR) is defined in
`.claude/skills/changelog-workflow.md`.

---

## 7. Merge Strategy

**Squash and merge** on all PRs. Configure in GitHub → Settings → Pull Requests:
- [x] Allow squash merging
- [ ] Allow merge commits *(disable)*
- [ ] Allow rebase merging *(disable)*
- [x] Automatically delete head branches

---

## 8. Phase Transitions

### Tagging convention
At the completion of each phase:

```bash
# Phase 0.5 complete
git tag -a v0.1.0 -m "Phase 0.5 complete: dplyr/tidyr verbs for survey objects"
git push origin v0.1.0
```

### Version → phase mapping
| Tag | DESCRIPTION version | What it means |
|-----|---------------------|---------------|
| `v0.0.0-pre` | `0.0.0.9000` | Pre-implementation baseline |
| `v0.1.0` | `0.1.0` | Phase 0.5 complete — all dplyr/tidyr verbs |
| `v1.0.0` | `1.0.0` | Stable API, CRAN submission |

### Dev version during a phase
Between tags, DESCRIPTION carries the `.9000` suffix:
```
Version: 0.0.0.9000  # during Phase 0.5 development
```

---

## 9. CI/CD Workflows

### Active workflows
| Workflow | Trigger |
|----------|---------|
| `R-CMD-check.yaml` | Push to any branch, PR to `main` |
| `test-coverage.yaml` | Push to `main`, PRs |
| `pkgdown.yaml` | Push to `main` only |

### R-CMD-check matrix
```yaml
# Matrix: {os: [ubuntu-latest, windows-latest, macos-latest], r: [release, devel]}
```

### Required status check for branch protection
Set `R-CMD-check (ubuntu-latest, release)` as the required status check. Windows and macOS checks are informational.
