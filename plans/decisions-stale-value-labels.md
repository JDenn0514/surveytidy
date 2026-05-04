# Decisions Log — stale-value-labels

This file records planning decisions made during Stage 3 (Resolve) for the
`fix/stale-value-labels` implementation plan.

---

## 2026-05-01 — Stage 3 resolve session

### Context

Resolved 9 issues raised by the Stage 2 adversarial review of
`plans/impl-stale-value-labels.md`. Issues ranged from wrong test file
references to missing test coverage requirements and edge cases.

### Questions & Decisions

**Q: Where should new test blocks for `replace_when()` / `replace_values()` live?**
- Options considered:
  - **New files (`test-replace-when.R`, `test-replace-values.R`):** These files
    do not exist; creating them would split coverage for the same functions across
    two files and inflate PR scope.
  - **Existing `test-recode.R`:** All current tests for both functions live here
    in dedicated sections; adding new blocks here is consistent.
- **Decision:** Add new blocks to `test-recode.R` in the existing sections for
  each function.
- **Rationale:** Consistency with established test layout; no new files needed;
  no coverage fragmentation.

**Q: Where should the changelog entry live? (No active phase directory for this bug fix.)**
- Options considered:
  - **`changelog/fix/`:** Singular; no prior precedent.
  - **Most recent existing phase dir:** None clearly applicable to a standalone bug fix.
  - **`changelog/phase-collection/`:** Would match recent collection commits but
    this bug fix is independent.
  - **`changelog/fixes/`:** Plural; new convention for standalone bug fixes not
    tied to a named phase.
- **Decision:** Create `changelog/fixes/` as the home for standalone bug fix
  changelog entries.
- **Rationale:** Establishes a consistent convention for future standalone fixes
  without conflating them with named phase work.

**Q: Should the user-supplied label test use `99` (ghost value) or `4` (eliminated value)?**
- Options considered:
  - **`99` (never in data):** Contract is tested correctly but the test doesn't
    distinguish "not pruned because user-supplied" from "not pruned because value
    was never a candidate."
  - **`4` (in data, eliminated by replacement):** Makes the "user-supplied labels
    survive even when the labelled value is eliminated" contract unambiguous.
- **Decision:** Use `.value_labels = c("Something else" = 4)` — value `4` exists
  in the input and is eliminated by the replacement.
- **Rationale:** A value that was in the data and then eliminated makes the
  contract more vivid and harder to misread (`testing-standards.md` §4).

### Outcome

The plan now specifies: `test-utils.R` with 4 direct unit tests for
`.merge_value_labels()` new branches; `test-recode.R` with cross-design
integration blocks (5 for `replace_when()`, 5 for `replace_values()`); coverage
criterion; `test_invariants()` in all blocks; and `changelog/fixes/` as the
new convention for standalone bug fix entries.

---
