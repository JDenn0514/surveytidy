# Feature PR Template

Used for all PRs targeting `main`.

---

## What

<!-- One sentence: what does this PR add or fix? -->

## Checklist

- [ ] Tests written and passing (`devtools::test()`)
- [ ] R CMD check: 0 errors, 0 warnings (`devtools::check()`)
- [ ] Roxygen docs updated and `devtools::document()` run
- [ ] `plans/error-messages.md` updated (if new errors/warnings added)
- [ ] All three design types tested via `make_all_designs()`
- [ ] Domain column preservation asserted in tests
- [ ] All examples begin with `library(dplyr)` or `library(tidyr)`
- [ ] PR title is a valid Conventional Commit (`feat(scope): description`)
- [ ] PR targets `main`
