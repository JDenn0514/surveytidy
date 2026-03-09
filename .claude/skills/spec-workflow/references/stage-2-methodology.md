# Stage 2: Adversarial Methodology Review

## Trigger Condition

Run this stage only when the spec contains **at least one** of:
- A verb that creates, reads, or modifies the domain column
- A verb that could change row count (joins, slice, drop_na, subset)
- A verb that operates on or could affect design variable columns
- A verb that changes `@variables`, `@metadata`, `@groups`, or `visible_vars`
- A shape-changing operation (joins, nest, unnest, pivot)

If none of these apply (e.g., the feature is a `print()` method, a `glimpse()`
display helper, a roxygen documentation change, or an internal utility with no
survey semantics), declare Stage 2 not applicable, note the reason briefly in
the output file, and skip to Stage 3.

---

## Scope Assessment

Before applying the lenses, answer the following:

- Does this feature implement or extend a verb that manipulates survey data?
- Could it create, modify, or remove domain membership for any rows?
- Could it modify the values or presence of any design variable (weights, ids,
  strata, fpc, repweights)?
- Could it change `@variables`, `@metadata`, `@groups`, or `visible_vars`?
- Could it affect the row count or row order of `@data`?

**If none of these apply**, declare Stage 2 not applicable and skip to Stage 3.
Note the reason briefly in the output file.

**If any apply**, proceed with all five lenses below. Within each lens, skip
sub-questions that genuinely don't apply to the feature being reviewed — but
err toward checking rather than skipping.

---

## Your Role

You are reviewing a spec for survey data manipulation correctness. Your job:
find every flaw in the underlying methodology before a line of code is written.
A verb that silently removes domain rows or invalidates the variance structure
produces wrong downstream answers that pass all tests — that is far worse than
a crash.

This stage produces a **complete methodology issue list saved to a file**. It
is a batch pass — do not resolve issues here. Resolution happens in Stage 2
Resolve.

---

## Input Requirement

If no spec document is provided in the message, ask the user to paste the spec
or provide the file path. Read the full spec once before generating any output.
Do not start reporting issues mid-read.

---

## Five Methodology Lenses

### Lens 1 — Domain Semantics

The central promise of surveytidy is that verbs preserve the row universe. Only
`subset()` physically removes rows, and it always warns. Every other verb that
"restricts" the data must do so by marking rows out-of-domain — never by
deleting them.

Flag any of the following:

**Domain column lifecycle:**
- Does the spec distinguish between domain marking (`filter()`) and physical
  removal (`subset()`)? A verb that says "filter to rows where..." without
  specifying domain-marking semantics is ambiguous.
- For `filter()`: are conditions accumulated with AND logic across chained
  calls? A second `filter()` call should tighten, not replace, the domain.
- For `drop_na()`: does the spec mark rows with NAs as out-of-domain (not
  remove them physically)?
- For verbs that don't touch the domain: does the spec state explicitly that
  an existing domain column passes through unchanged?

**Domain column in `@data`:**
- Does the spec define what happens to the domain column after the operation?
  Silence means "unchanged" — but that must be stated.
- If the operation creates the domain column for the first time, is the column
  name `surveycore::SURVEYCORE_DOMAIN_COL` ("..surveycore_domain..")?
- If a verb might produce an empty domain (all `FALSE`), does the spec define a
  warning (`surveycore_warning_empty_domain`)?
- For joins: does the spec explain how the domain column is handled when rows
  are introduced (one-to-many) or removed (non-matching rows in an inner join)?

**Anti-patterns:**
- Does the spec use language like "remove rows where..." for a verb that should
  instead mark rows out-of-domain?
- Does the spec call `filter()` in a context where only `subset()` is
  appropriate (e.g., a verb designed for physical subsetting)?

---

### Lens 2 — Row Universe Integrity

Surveys derive their statistical validity from the complete sample. Physically
removing rows without warning compromises variance estimation. Any verb that
changes row count must carry a warning.

Flag any of the following:

**Row count changes:**
- Does the verb add, remove, or reorder rows?
- If rows are removed: is there always a warning (e.g.,
  `surveycore_warning_physical_subset`)?
- For `arrange()`: row reordering is safe — does the spec confirm no rows are
  added or removed?
- For `slice_*()`: physical subsetting; the spec must require a warning.

**Join semantics:**
- For a left join: what happens to rows in the left design that have no match
  in the right table? (They should remain; their domain status should be
  unaffected unless explicitly changed.)
- For an inner join: rows with no match are physically removed. Does the spec
  require a warning identical to `subset()`?
- For a one-to-many join: the design gains rows it didn't have. This inflates
  the apparent sample size and invalidates variance estimates. Does the spec
  flag this as an error or a prominent warning?
- For a full join: both tables contribute rows, potentially introducing rows
  with no design weights. The spec must address what fills in the missing weight
  values.

**Empty result:**
- Does the spec define behavior when the operation produces zero rows? (An
  error is usually more appropriate than a silent empty design.)

---

### Lens 3 — Design Variable Integrity

Design variables (weights, ids, strata, fpc, repweights) define the probability
sample. Operations that modify or silently remove them invalidate variance
estimation without raising any immediate error.

**Sub-lens A — Structural preservation:**
- Does the verb physically remove any design variable columns from `@data`?
  Only `select()` can do this, and it must error if the user tries. Other verbs
  must always preserve design variable columns.
- Does `select()` error with `surveycore_error_design_var_removed` if the user
  selects only non-design columns and a design variable would be dropped?
- Does the spec define `dplyr_reconstruct()` behavior to check for removed
  design variables in complex pipelines (joins, `across()`, `slice()`)?
- Are `@variables` keys updated if the operation changes column names
  (e.g., `rename()` must update `@variables$weights` if the weight column is
  renamed)?

**Sub-lens B — Value-modifying operations (CRITICAL):**
- Does the spec allow `mutate()`, `recode()`, or `case_when()` on design
  variable columns?
- If a user runs `mutate(d, wt = wt * 2)` or
  `mutate(d, strata = recode(strata, ...))`, what happens? The spec must state.
- Is there a warning when design variable **values** are modified? (e.g.,
  `surveytidy_warning_mutate_weight_col` for weight columns)
- If a user recodes a stratification variable via `case_when()`, the
  stratification structure has fundamentally changed — does the spec flag this
  with a warning distinct from ordinary column mutations?
- Does the spec distinguish between modifying weights (changes effective sample
  size but the design structure survives) and modifying structural variables
  like strata or PSU (changes the probability model itself)?
- For `rename()` on a design variable: the column is still present with its
  original values, so this is safe — but `@variables` must be updated. Does
  the spec require this update?

---

### Lens 4 — Variance Estimation Validity

surveytidy verbs are not estimation functions, but they must not silently
invalidate the ability to estimate variance downstream. A verb that destroys
the design structure is a validity bug even if it produces no immediate error.

Flag any of the following:

**Design structure preservation:**
- After this operation, can variance be estimated correctly using the design?
- Does the verb change `@variables` in a way that would break the variance
  estimator (e.g., removing strata, changing PSU assignments, losing the
  weight column name)?
- For `rename()` on a design variable: does the spec require updating `@variables`
  so the estimator can still find the right columns by their new name?
- For `mutate()` on a weight column: does the spec warn that the variance
  estimator will use the modified weights, which may no longer reflect the true
  sampling probabilities?

**@groups and Phase 1 compatibility:**
- For `group_by()`: does the spec clarify that `@groups` affects Phase 1
  estimation functions (not variance estimation within Phase 0.5 verbs)?
- Does the spec state explicitly what `@groups = character(0)` means for
  ungrouped designs, so Phase 1 functions can rely on a well-defined contract?

**Shape-changing operations:**
- For `nest()`, `unnest()`, `pivot_wider()`, `pivot_longer()`: can the
  resulting survey object still produce valid variance estimates? The spec must
  address this — it cannot be deferred to the user.
- For joins: does the join change the PSU/strata/weight structure of the left
  design? (It should not unless the right table contributes design columns.)
  If there is any risk, the spec must address it.

---

### Lens 5 — Structural Transformation Validity

Some verbs change the shape or structure of the survey object beyond just
manipulating rows or columns. These require checking that `@variables`,
`@metadata`, `@groups`, and `visible_vars` are updated correctly and that the
invariants checked by `test_invariants()` still hold.

**Flat operation bookkeeping (applies to most Phase 0.5 verbs):**
- Does `rename()` update `@variables` keys for renamed columns?
- Does `rename()` update `@metadata` keys for renamed columns?
- Does `select()` set `@variables$visible_vars` to the user's explicit
  column selection?
- Does `select()` remove `@metadata` entries for physically removed columns only
  (not design variable entries, since design vars are always preserved in
  `@data`)?
- Does `group_by()` set `@groups` to the specified column names?
- Does `ungroup()` reset `@groups` to `character(0)`?
- Does `filter()` update `@variables$domain` with the accumulated list of
  quosures (AND-logic across chained calls)?

**Shape-changing operations (joins, nest, unnest, pivot):**
- After a join: are `@variables` still valid? All design variable column names
  must still be present in `@data`.
- After a join: are `@metadata` keys still valid? Keys for columns that were
  removed or renamed must be updated.
- After `nest()` / `unnest()`: does the resulting survey object satisfy all
  invariants checked by `test_invariants()`? If not, the operation must error
  before returning.
- After `pivot_wider()` / `pivot_longer()`: same question. A column that was
  a design variable before pivoting may not exist after — does the spec handle
  this?
- For any shape-changing operation: does the spec require calling
  `dplyr_reconstruct()` or a custom validation step before returning the
  modified object?
- Does the spec define what happens to `@metadata` when columns are
  pivoted, nested, or unnested? (e.g., a column's variable label before
  pivot_wider may not map cleanly to the post-pivot columns)
- If the operation could violate invariants: does it error with a clear message
  before returning rather than returning a malformed design?

---

## Issue Format

Use this format for every issue:

```
**Issue [N]: [Short title]**
Severity: BLOCKING | REQUIRED | SUGGESTION
Lens: [1–5 and lens name]
Resolution type: UNAMBIGUOUS | JUDGMENT CALL

[Concrete description. Quote or reference the spec text that is missing or
wrong. State the specific methodological problem in plain language.
For UNAMBIGUOUS: state the correct fix directly.
For JUDGMENT CALL: state the options and their trade-offs.]

Options:
- **[A]** [Description] — Effort: [low/medium/high], Risk: [low/medium/high],
  Impact: [what changes]
- **[B]** [Alternative description]
- **[C] Do nothing** — [what stays wrong or ambiguous]

**Recommendation: [A/B/C]** — [One sentence rationale]
```

**Severity tiers:**

- **BLOCKING** — The function will produce wrong behavior without resolving
  this. An implementer could write code that passes all tests and still
  violate domain semantics or silently corrupt the design.
- **REQUIRED** — A significant gap or ambiguity that will cause silent wrong
  behavior or user confusion about what the verb does to survey data.
- **SUGGESTION** — A documentation or clarity improvement; the implementation
  would likely still be correct without it.

**Resolution types** (used by Stage 2 Resolve for batching):

- **UNAMBIGUOUS** — There is one correct answer. Show the fix; ask once to
  confirm the batch.
- **JUDGMENT CALL** — Multiple valid approaches exist. Ask the user to decide.

---

## If a Methodology Review File Already Exists

Before writing any output, check for `plans/spec-methodology-{id}.md`.

**If it exists:**
1. Read the full existing file
2. Complete your fresh review of the current spec
3. In the new pass section, list every previously flagged issue with a status:
   - ✅ Resolved — the spec was updated to address it
   - ⚠️ Still open — the spec was not changed
4. **Append** the new pass section to the bottom of the existing file — never
   overwrite or delete prior content

**If it does not exist:** create the file with Pass 1.

---

## Output Structure

Organize all issues by lens. If a lens has no issues, say "No issues found."
If a lens was skipped, say "Lens [N] not applicable: [reason]."

```markdown
## Methodology Review: [id] — Pass [N] ([YYYY-MM-DD])

### Prior Issues (Pass [N-1])
_Omit this section on Pass 1._

| # | Title | Lens | Status |
|---|---|---|---|
| 1 | [title] | 1 | ✅ Resolved |
| 2 | [title] | 3 | ⚠️ Still open |

### New Issues

#### Lens 1 — Domain Semantics

**Issue [N]: [title]**
Severity: BLOCKING
Lens: 1 — Domain Semantics
Resolution type: UNAMBIGUOUS
...

#### Lens 2 — Row Universe Integrity

[continue for all five lenses]

---

## Summary (Pass [N])

| Severity | Count |
|---|---|
| BLOCKING | N |
| REQUIRED | N |
| SUGGESTION | N |

**Total issues:** N

**Overall assessment:** [One honest sentence — e.g., "The domain accumulation
contract is sound, but the spec is silent on how the domain column is handled
when a join introduces new rows, which will produce undefined behavior in any
joined design."]
```

---

## Before Outputting

Ask yourself:

- Did I complete the Scope Assessment and determine which lenses apply?
- Have I applied all applicable lenses, even for verbs that seem
  straightforward?
- Have I flagged every place where the spec says "remove" when it should say
  "mark out-of-domain"?
- Have I checked every verb for what it does to design variable columns?
- Have I checked every verb that modifies column values for whether those
  columns might be design variables?
- Have I assigned UNAMBIGUOUS or JUDGMENT CALL to every issue?
- Is the overall assessment honest — does it match the issue count and
  severity?

If the methodology is genuinely sound, say so. Adversarial means rigorous, not
performatively negative.

---

## Mini-Pass Mode

Use this mode when a methodology flaw is discovered in Stage 3 or during
implementation and the methodology lock needs a targeted update.

1. Read only the affected section of the spec, not the full document.
2. Apply only the relevant lenses to that section.
3. Write a `### Mini-Pass [N] ([YYYY-MM-DD])` section and **append** it to
   the existing `plans/spec-methodology-{id}.md` — never overwrite.
4. End with: `"Mini-pass complete: {N} issues found. Resolve via Stage 2
   Resolve targeting these issues only."`

---

## After Completing the Review

1. Determine `{id}` from the spec filename if not already known.
2. Append the new pass section to `plans/spec-methodology-{id}.md` (create on
   Pass 1).
3. End the session with:

   > "Methodology review Pass [N] complete: {N} new issues ({X} blocking,
   > {Y} required, {Z} suggestions). Start a new session with
   > `/spec-workflow stage 2 resolve` to lock the methodology before running
   > the code review. Review appended to `plans/spec-methodology-{id}.md`."
