# chore(description): regenerate documentation with roxygen2 8.1.1

**Date**: 2026-11-03
**Branch**: chore/roxygen-8.1.1
**Phase**: fixes

## Changes

- Regenerate NAMESPACE and `man/` with roxygen2 8.1.1 (was 7.3.3).
- roxygen2 8 replaces the `RoxygenNote` field in DESCRIPTION with
  `Config/roxygen2/version`.
- NAMESPACE groups the `importFrom()` names for each package into one call.
  The set of imported names is unchanged.
- Rd links to dplyr's slice help now name the exact topic (for example
  `dplyr:slice_head` in place of `dplyr:slice`).
- The package help page now lists the authors.
- The DESCRIPTION example in `.claude/rules/r-package-conventions.md` shows
  `Config/roxygen2/version` in place of `RoxygenNote`.

## Files Modified

- `DESCRIPTION` — `RoxygenNote: 7.3.3` replaced by
  `Config/roxygen2/version: 8.1.1`.
- `NAMESPACE` — regenerated; `importFrom()` calls grouped by package.
- `man/*.Rd` (36 files) — regenerated; link targets and whitespace changes
  only.
- `.claude/rules/r-package-conventions.md` — DESCRIPTION example updated.
