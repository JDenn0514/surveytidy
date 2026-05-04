## Methodology Review: joins — Pass 1 (2026-04-16)

### Scope Assessment

All five lenses apply:
- Verbs manipulate survey `@data`: `left_join`, `inner_join`, `semi_join`,
  `anti_join`, `bind_cols`
- Domain membership modified: `semi_join`, `anti_join`, `inner_join` (physically)
- Could affect design variable presence: guarded but reviewed below
- `@variables`, `@metadata`, `visible_vars` changed by `left_join`, `bind_cols`
- Row count changed by `inner_join`; row count expansion risk in `left_join` and
  (critically) `inner_join` if `y` has duplicate keys

---

### New Issues

#### Lens 1 — Domain Semantics

---

**Issue 1: inner_join does not state that the domain column is preserved for surviving rows**
Severity: REQUIRED
Lens: 1 — Domain Semantics
Resolution type: UNAMBIGUOUS

§VI output contract says `"..surveycore_domain.."`: "Removed rows gone
(physical)" (§XI table). This describes what happens to the column for removed
rows but says nothing about the domain column values for the **surviving** rows.
If the survey has already been `filter()`-ed (so the domain column holds a
mixture of TRUE/FALSE), the surviving rows each have a meaningful domain value.
Those values must survive the `inner_join`.

In practice, dplyr's `inner_join` on a data frame preserves all columns from
the left side — so surviving rows keep their domain column values. But the spec
is silent on this, leaving an implementer no guidance on what to assert in
tests. A test that checks `d_filtered |> inner_join(...) |> d@data[["..surveycore_domain.."]]`
would have no spec basis.

Fix: add to §VI output contract: "`..surveycore_domain..`: If the domain column
existed before the join, its values for surviving rows are preserved unchanged.
Rows removed by the join are gone."

---

**Issue 2: GAP-1 (inner_join Option A vs. Option B) needs a methodology
recommendation before Stage 2 can lock**
Severity: REQUIRED
Lens: 1 — Domain Semantics
Resolution type: JUDGMENT CALL

The spec presents `inner_join` as "physical subset + warning" (Option A) but
flags it as an open question with Option B (domain-aware, implemented as
`semi_join + left_join` internally). This is a methodology question with direct
implications for variance estimation: Option A physically removes rows and
warns; Option B marks them out-of-domain and preserves all rows.

Options:
- **[A] Physical subset + `surveycore_warning_physical_subset`** (current plan)
  Effort: low, Risk: medium.
  Impact: users who expect inner_join to reduce row count get what they expect,
  but variance estimation on the result is compromised unless the user is careful.
  Consistent with how `subset()` works. The warning is the only safety net.
- **[B] Domain-aware (mark rows, do not remove)**
  Effort: medium, Risk: low.
  Impact: preserves variance estimation validity. Surprise factor: users who
  examine `nrow()` after inner_join will see the original count, not the
  filtered count. Consistent with `semi_join` semantics.
- **[C] Do nothing — leave GAP-1 open**
  Violates the HARD-GATE (decisions must be logged before implementation).

**Recommendation: B** — The surveytidy philosophy is that verbs do not silently
invalidate variance estimation. `inner_join` is semantically equivalent to
`semi_join` + `left_join`: it filters to matched rows AND adds columns from `y`.
Implementing it as a domain-aware operation (= `semi_join` followed by
`left_join`) is the survey-correct choice. The surprise (nrow unchanged) is
mitigated by the fact that surveytidy's `filter()` already sets that precedent.
If Option A is chosen, the §VI spec should be reviewed more carefully for
variance estimation language, and the twophase error should remain even under
Option A.

---

**Issue 3: @variables$domain after semi_join / anti_join — Phase 1
compatibility not validated**
Severity: REQUIRED
Lens: 1 — Domain Semantics / Lens 4 — Variance Estimation Validity
Resolution type: JUDGMENT CALL

GAP-5 in §IV poses whether `@variables$domain` (the quosure list accumulated
by `filter()`) should be updated after `semi_join`/`anti_join`. The spec leans
toward option (a): leave it unchanged, because the authoritative domain state
is in the `..surveycore_domain..` column.

The methodology risk: if Phase 1 estimation functions read `@variables$domain`
to understand what domain restrictions have been applied (e.g., to annotate
output or to reproduce the domain), they would miss any filtering introduced
by `semi_join` or `anti_join`. The domain column would be correct, but the
quosure list would be incomplete.

Options:
- **[A] Leave @variables$domain unchanged** — Effort: none, Risk: medium if
  Phase 1 reads the quosure list.
- **[B] Append a sentinel descriptor** (e.g., `list(type = "semi_join",
  keys = resolved_by)`) — Effort: low, Risk: low.
  Lets Phase 1 know a join-based domain restriction was applied, even without
  a quosure.
- **[C] Do nothing — decide in Phase 1**
  Defers the decision, but creates a contract gap that Phase 1 must fill
  retroactively.

**Recommendation: B** — Appending a structured sentinel costs almost nothing
and protects Phase 1 from a silent contract violation. Even if Phase 1 only
reads the domain column, the sentinel serves as documentation of what happened.
GAP-5 should be resolved explicitly in favor of B before implementation.

---

#### Lens 2 — Row Universe Integrity

---

**Issue 4: inner_join row EXPANSION (duplicate keys in y) not guarded**
Severity: BLOCKING
Lens: 2 — Row Universe Integrity
Resolution type: UNAMBIGUOUS

The spec adds a `.check_join_row_expansion()` guard to `left_join` (§III,
Rule 3) to catch duplicate keys in `y` that would expand `x`. The same
problem exists for `inner_join` and is **not addressed anywhere in §VI**.

dplyr's `inner_join` with duplicate keys in `y` expands rows from `x` the
same way `left_join` does: if `x` has one row with `id = 1` and `y` has
three rows with `id = 1`, the result has three rows for that respondent.
This is not "physical subsetting" — it is phantom row creation. The spec
introduces `surveytidy_error_join_row_expansion` for `left_join` but omits it
entirely for `inner_join`.

Fix: add the following to §VI Behavior rules (between Step 3/4):

> **Guard: row count must not expand.**
> After delegating to `dplyr::inner_join(x@data, y, ...)`, compare
> `nrow(result)` to `nrow(x@data)`. If `nrow(result) > nrow(x@data)`, error
> with `surveytidy_error_join_row_expansion` (same error class as `left_join`).
> This guard fires before the physical-subset warning.

Add `surveytidy_error_join_row_expansion` to the §VI error table. The `.check_join_row_expansion()` helper already exists per §II — just call it.

---

**Issue 5: GAP-2 (left_join row expansion: error vs. warn) — confirm error
is the correct methodology call**
Severity: REQUIRED
Lens: 2 — Row Universe Integrity
Resolution type: JUDGMENT CALL

GAP-2 asks whether row expansion in `left_join` (duplicate keys in `y`)
should error or warn. The spec currently leans toward error.

Options:
- **[A] Error** (current plan) — Effort: already spec'd, Risk: low.
  Impact: prevents any survey object from silently gaining phantom rows.
  The only escape is to deduplicate `y` before joining.
- **[B] Warn + proceed** — Effort: low, Risk: high.
  The resulting object has more rows than the original survey, which corrupts
  variance estimation. A warn-and-proceed path leaves the corrupted object in
  use.
- **[C] Do nothing** — violates the HARD-GATE.

**Recommendation: A** — Row expansion in a survey join is always wrong from a
methodology standpoint. A phantom row means a respondent appears multiple times
in the sample, invalidating the probability model. Error is correct. This also
aligns with the proposed fix for Issue 4 (inner_join). GAP-2 should be resolved
as closed in favor of error.

---

#### Lens 3 — Design Variable Integrity

---

**Issue 6: `.check_join_col_conflict()` return value contract is ambiguous**
Severity: REQUIRED
Lens: 3 — Design Variable Integrity
Resolution type: UNAMBIGUOUS

§II defines `.check_join_col_conflict(x, y)` with the signature:
`(x, y) → invisible(TRUE) or warn + returns cleaned y`. This is inconsistent:
- When no conflict: returns `invisible(TRUE)` (a logical)
- When conflict: warns and returns the cleaned `y` (a data frame)

The callers (`left_join` and `bind_cols`) need a consistent return type to
assign the (possibly cleaned) `y` back. As written, the caller would need to
inspect whether the return value is logical or a data frame, or use the input
`y` as default when no conflict. Neither pattern is clean.

Fix: change the helper contract so it **always returns `y`** (possibly cleaned):
- If no conflict: returns `y` unchanged
- If conflict: warns + returns `y` with conflicting columns dropped

Signature: `(x, y) → y (data frame, possibly subset)`

The caller then always does `y <- .check_join_col_conflict(x, y)` before
proceeding with the join.

---

**Issue 7: Join key that IS a design variable — not addressed**
Severity: SUGGESTION
Lens: 3 — Design Variable Integrity
Resolution type: UNAMBIGUOUS

If the user specifies `by = "strata"` (a design variable) as the join key,
`.check_join_col_conflict()` would detect "strata" in `y` and drop it from
`y` before the join. But the user explicitly asked to join ON strata — they
expect x's strata column to survive (which it does since it comes from the
left side). The drop is silent.

More importantly: after the conflict guard drops "strata" from `y`, the join
proceeds using "strata" from `x@data` as the key. The column suffix logic
would not fire (since "strata" only exists in `x`). The result is correct but
the warning misleads the user — the guard message says "has been dropped from
y to protect the survey design" but "strata" wasn't going to replace anything;
it was a join key.

Fix (suggestion): in `.check_join_col_conflict()`, exclude columns that are
listed in `by` from the conflict check. Join key columns in `y` are not being
added as new columns — they are being matched — so they do not threaten design
variable integrity. The check should only apply to non-key columns of `y`.

---

#### Lens 4 — Variance Estimation Validity

---

**Issue 8: inner_join on replicate designs — BRR structure violation not
documented**
Severity: REQUIRED
Lens: 4 — Variance Estimation Validity
Resolution type: UNAMBIGUOUS

The spec allows `inner_join` on `survey_replicate` designs with a warning
(`surveycore_warning_physical_subset`). It errors only for `survey_twophase`.

For a BRR or jackknife replicate design, the replicate weights encode specific
pairing or half-sample structure assumptions. Physical row removal can violate
these assumptions (e.g., BRR requires even numbers of PSUs per stratum for
valid variance estimation; removing rows could collapse strata). This is a
distinct risk beyond the general physical-subset warning.

The spec's rationale for the twophase error is that "physical row removal can
orphan phase2 rows or corrupt the phase1 sample frame." A parallel concern
exists for replicate designs: removing rows can leave half-samples with
degenerate structure, producing variance estimates that pass without error
but are numerically wrong.

This is not a new error; the spec doesn't need to add one. But the §V and §VI
sections should explicitly note: "For `survey_replicate` designs, physical row
removal (as in `inner_join`) can corrupt BRR or jackknife structure. The
`surveycore_warning_physical_subset` warning is the only protection. Users of
replicate designs should prefer `semi_join()`."

This documentation belongs in the §VI rationale and in the `@details` section
of the roxygen docs.

---

#### Lens 5 — Structural Transformation Validity

---

**Issue 9: Suffix renaming corrupts @metadata keys and visible_vars**
Severity: BLOCKING
Lens: 5 — Structural Transformation Validity
Resolution type: UNAMBIGUOUS

When `left_join` is called and `y` contains a non-design-variable column that
shares a name with a column already in `x@data`, dplyr applies a suffix:
`income` becomes `income.x` (x's version) and `income.y` (y's version). The
`.check_join_col_conflict()` guard only protects **design variable** column
names — it does not protect or handle non-design columns with the same name.

After the join:
1. `@metadata@variable_labels["income"]` refers to a column that no longer
   exists. The column is now `"income.x"`. The metadata key is stale.
2. If `@variables$visible_vars` included `"income"`, it now points to a
   non-existent column. `print()` would attempt to display "income" and either
   fail or silently skip the column.

The spec's §III (Output contract, `@metadata`) says: "New columns from `y`
get no labels in `@metadata@variable_labels`." It says nothing about what
happens to existing metadata keys when columns are suffix-renamed by the join.

Fix: add to §III Behavior rules (after Step 4, before Step 5):

> **Step 4b: Detect and repair suffix renames.**
> Before the join, capture `old_x_cols <- names(x@data)`. After the join,
> for each column in `old_x_cols`, check if it still exists in `names(result)`.
> Columns that are gone and whose suffixed name (`paste0(name, suffix[1])`) IS
> present were renamed by the join. Build a rename map
> (`setNames(old_name, new_name)` for each renamed column) and apply it to:
>
> - `@metadata@variable_labels` keys (rename any affected keys)
> - `@variables$visible_vars` (replace old name with suffixed name in the vector)
>
> Design variable columns should never be in this rename map because they are
> excluded from y before the join via `.check_join_col_conflict()` — so their
> names are stable.

Also update §XI table column "left_join" row "`@metadata@variable_labels`" to
read: "New cols get no labels; existing keys for suffix-renamed cols updated."

And `visible_vars` row: "Append new col names if set; update any suffix-renamed
col names."

---

**Issue 10: @variables$domain is stale after inner_join (physical row removal)**
Severity: SUGGESTION
Lens: 5 — Structural Transformation Validity
Resolution type: UNAMBIGUOUS

After `inner_join` physically removes rows (Option A), `@variables$domain`
still holds the quosure list from any prior `filter()` calls. Those quosures
referred to conditions on the original population. For the surviving rows,
the quosures are still technically correct (each surviving row satisfied the
filter conditions), but the `@variables$domain` list gives no indication that
rows were also removed by an inner_join.

This is consistent with how `subset()` works today (it also doesn't update
`@variables$domain`), so no new behavior is required. But the spec should
state it explicitly: "After `inner_join`, `@variables$domain` is unchanged.
It reflects only prior `filter()` conditions, not the join-based row removal."

This documents the expected state rather than leaving it implicit.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 2 (Issues 4, 9) |
| REQUIRED | 6 (Issues 1, 2, 3, 5, 6, 8) |
| SUGGESTION | 2 (Issues 7, 10) |

**Total issues:** 10

**Overall assessment:** The domain semantics for `semi_join`/`anti_join` are
sound and the guard structure is well-conceived. Two blocking issues must be
resolved before implementation: `inner_join` is missing its row-expansion guard
(the same duplicate-key scenario guarded for `left_join` was overlooked for
`inner_join`), and `left_join` suffix renaming corrupts `@metadata` keys and
`visible_vars` when x and y share non-design column names. GAP-1 (inner_join
Option A vs B) and GAP-2 (row expansion error vs warn) should also be locked —
both have clear methodology answers (Option B and error, respectively). All ten
issues should be resolved before the methodology lock.
