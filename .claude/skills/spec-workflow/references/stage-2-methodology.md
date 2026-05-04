# Stage 2: Adversarial Methodology Review (Subagent Dispatcher)

Find every methodology flaw — domain semantics, row universe, design
variable integrity, variance validity, structural transformation — before
code is written. **Runs as a single subagent so the spec never enters
main context.** Your job here is dispatch, not review. (Surveyverse specs
are 1500–2000 lines; reviewing in main context forces compaction.)

---

## Step 1 — Confirm inputs

If not already obvious from the user's message, ask for any missing values:

- **Spec path** (default: `plans/spec-{id}.md`)
- **`{id}`** (e.g., `filter`, `joins`, `phase-0.7`, `survey-collection`)

Output path is always `plans/spec-methodology-{id}.md`.

If the user is invoking **mini-pass mode** (a targeted update of a single
section after a methodology flaw was discovered downstream), also capture
the section name they want re-reviewed.

Do **not** read the spec yourself. The whole point is to keep it out of
main context.

## Step 2 — Check for an existing methodology file

Use Bash: `test -f plans/spec-methodology-{id}.md && echo exists || echo absent`

The subagent's append-vs-create behavior depends on this. Pass it verbatim.

## Step 3 — Dispatch the methodology subagent

Use the `Agent` tool with `subagent_type: "general-purpose"`. Hand it the
prompt below verbatim, with `{spec_path}`, `{methodology_path}`,
`{exists_or_absent}`, and `{mode}` substituted. `{mode}` is either
`"full review"` or `"mini-pass on section: <section name>"`. Run in the
foreground.

````
You are reviewing a surveytidy spec for survey data manipulation
correctness. Your job: find every flaw in the underlying methodology
before a line of code is written. A verb that silently removes domain
rows or invalidates the variance structure produces wrong downstream
answers that pass all tests — that is far worse than a crash. Be
adversarial. The user does not want validation — they want problems
found now, before code is written.

## Inputs

- Spec: {spec_path}
- Output: {methodology_path}
- Existing methodology file: {exists_or_absent}
  - If "exists": read it, determine the highest existing Pass number,
    new pass = N+1; list prior issues with ✅ Resolved or ⚠️ Still open
    status; APPEND the new pass to the bottom — never overwrite.
  - If "absent": create the file with Pass 1; omit the Prior Issues
    section.
- Mode: {mode}
  - If "full review": apply the full Scope Assessment + five lenses
    workflow below.
  - If "mini-pass on section: ...": skip the full-document read; read
    only the named section; apply only the relevant lenses to it; write
    a `### Mini-Pass [N] ([YYYY-MM-DD])` block appended to the existing
    file. End with: "Mini-pass complete: {N} issues found. Resolve via
    Stage 2 Resolve targeting these issues only."

## Surveyverse rules (read what's relevant)

When citing a methodology violation, name the file:
- `.claude/rules/surveytidy-conventions.md` — domain column, visible_vars, @groups
- `.claude/rules/code-style.md` — error class naming, cli structure
- `.claude/rules/engineering-preferences.md` — edge cases, explicit over clever

## Workflow (full review mode)

Read the spec in full once. Read the existing methodology file if any.
Complete the Scope Assessment below. If not applicable, note the reason
and return early. Otherwise apply the five lenses, write the file, and
return the one-line summary defined under "Return value" at the end.

## Scope Assessment (full review mode only)

Run this stage only when the spec contains at least one of:
- A verb that creates, reads, or modifies the domain column
- A verb that could change row count (joins, slice, drop_na, subset)
- A verb that operates on or could affect design variable columns
- A verb that changes `@variables`, `@metadata`, `@groups`, or `visible_vars`
- A shape-changing operation (joins, nest, unnest, pivot)

If none of these apply (e.g., a `print()` method, a `glimpse()` display
helper, a roxygen documentation change, or an internal utility with no
survey semantics), declare Stage 2 not applicable, note the reason
briefly in the output file, and return:
"Stage 2 not applicable for {id}: <reason>. No methodology issues to resolve."

If any apply, proceed with all five lenses. Within each lens, skip
sub-questions that genuinely don't apply, but err toward checking.

## Five methodology lenses

### Lens 1 — Domain Semantics

The central promise of surveytidy is that verbs preserve the row
universe. Only `subset()` physically removes rows, and it always warns.
Every other verb that "restricts" the data must do so by marking rows
out-of-domain — never by deleting them.

Domain column lifecycle:
- Does the spec distinguish between domain marking (`filter()`) and
  physical removal (`subset()`)? A verb that says "filter to rows
  where..." without specifying domain-marking semantics is ambiguous.
- For `filter()`: are conditions accumulated with AND logic across
  chained calls? A second `filter()` should tighten, not replace, the
  domain.
- For `drop_na()`: does the spec mark rows with NAs as out-of-domain
  (not remove them physically)?
- For verbs that don't touch the domain: does the spec state explicitly
  that an existing domain column passes through unchanged?

Domain column in `@data`:
- Does the spec define what happens to the domain column after the
  operation? Silence means "unchanged" — but that must be stated.
- If the operation creates the domain column for the first time, is the
  column name `surveycore::SURVEYCORE_DOMAIN_COL` ("..surveycore_domain..")?
- If a verb might produce an empty domain (all `FALSE`), does the spec
  define a warning (`surveycore_warning_empty_domain`)?
- For joins: does the spec explain how the domain column is handled
  when rows are introduced (one-to-many) or removed (non-matching rows
  in an inner join)?

Anti-patterns:
- Does the spec use language like "remove rows where..." for a verb
  that should instead mark rows out-of-domain?
- Does the spec call `filter()` in a context where only `subset()` is
  appropriate?

### Lens 2 — Row Universe Integrity

Surveys derive their statistical validity from the complete sample.
Physically removing rows without warning compromises variance
estimation. Any verb that changes row count must carry a warning.

Row count changes:
- Does the verb add, remove, or reorder rows?
- If rows are removed: is there always a warning (e.g.,
  `surveycore_warning_physical_subset`)?
- For `arrange()`: row reordering is safe — does the spec confirm no
  rows are added or removed?
- For `slice_*()`: physical subsetting; the spec must require a warning.

Join semantics:
- Left join: rows in the left design with no match should remain;
  domain status unaffected unless explicitly changed.
- Inner join: rows with no match are physically removed. Spec must
  require a warning identical to `subset()`.
- One-to-many join: design gains rows, inflating apparent sample size
  and invalidating variance estimates. Spec must flag as error or
  prominent warning.
- Full join: both tables contribute rows, potentially with no design
  weights. Spec must address what fills missing weight values.

Empty result:
- Does the spec define behavior when the operation produces zero rows?
  An error is usually more appropriate than a silent empty design.

### Lens 3 — Design Variable Integrity

Design variables (weights, ids, strata, fpc, repweights) define the
probability sample. Operations that modify or silently remove them
invalidate variance estimation without raising any immediate error.

Sub-lens A — Structural preservation:
- Does the verb physically remove any design variable columns from
  `@data`? Only `select()` can do this, and it must error.
- Does `select()` error with `surveycore_error_design_var_removed` if a
  design variable would be dropped?
- Does the spec define `dplyr_reconstruct()` behavior to check for
  removed design variables in complex pipelines?
- Are `@variables` keys updated if the operation changes column names
  (e.g., `rename()` updating `@variables$weights`)?

Sub-lens B — Value-modifying operations (CRITICAL):
- Does the spec allow `mutate()`, `recode()`, or `case_when()` on design
  variable columns? What happens?
- Is there a warning when design variable values are modified (e.g.,
  `surveytidy_warning_mutate_weight_col`)?
- If a user recodes a stratification variable, the stratification
  structure has fundamentally changed — does the spec flag this with a
  warning distinct from ordinary column mutations?
- Does the spec distinguish modifying weights (changes effective sample
  size; design structure survives) from modifying structural variables
  like strata or PSU (changes the probability model itself)?
- For `rename()` on a design variable: column still present with
  original values, so safe — but `@variables` must be updated.

### Lens 4 — Variance Estimation Validity

surveytidy verbs are not estimation functions, but they must not
silently invalidate the ability to estimate variance downstream.

Design structure preservation:
- After this operation, can variance be estimated correctly?
- Does the verb change `@variables` in a way that would break the
  variance estimator (removing strata, changing PSU assignments,
  losing the weight column name)?
- For `rename()` on a design variable: spec must require updating
  `@variables` so the estimator finds the right columns by their new
  name.
- For `mutate()` on a weight column: spec must warn that the variance
  estimator will use modified weights, which may no longer reflect
  true sampling probabilities.

@groups and Phase 1 compatibility:
- For `group_by()`: does the spec clarify that `@groups` affects
  Phase 1 estimation functions (not variance estimation within
  Phase 0.5 verbs)?
- Does the spec state explicitly what `@groups = character(0)` means
  for ungrouped designs?

Shape-changing operations:
- For `nest()`, `unnest()`, `pivot_wider()`, `pivot_longer()`: can the
  resulting survey object still produce valid variance estimates?
  Spec must address this — cannot be deferred to the user.
- For joins: does the join change the PSU/strata/weight structure of
  the left design? Spec must address any risk.

### Lens 5 — Structural Transformation Validity

Some verbs change the shape or structure of the survey object beyond
just manipulating rows or columns. These require checking that
`@variables`, `@metadata`, `@groups`, and `visible_vars` are updated
correctly and that `test_invariants()` still holds.

Flat operation bookkeeping:
- Does `rename()` update `@variables` keys for renamed columns?
- Does `rename()` update `@metadata` keys for renamed columns?
- Does `select()` set `@variables$visible_vars` to the user's explicit
  column selection?
- Does `select()` remove `@metadata` entries for physically removed
  columns only (not design variable entries, since design vars are
  always preserved)?
- Does `group_by()` set `@groups` to the specified column names?
- Does `ungroup()` reset `@groups` to `character(0)`?
- Does `filter()` update `@variables$domain` with the accumulated list
  of quosures (AND-logic across chained calls)?

Shape-changing operations (joins, nest, unnest, pivot):
- After a join: `@variables` still valid? All design variable column
  names still present in `@data`?
- After a join: `@metadata` keys still valid? Keys for removed or
  renamed columns updated?
- After `nest()` / `unnest()`: does the result satisfy all invariants
  checked by `test_invariants()`? If not, must error before returning.
- After `pivot_wider()` / `pivot_longer()`: same question. A column
  that was a design variable before pivoting may not exist after.
- For any shape-changing operation: spec must require calling
  `dplyr_reconstruct()` or a custom validation step before returning.
- Does the spec define what happens to `@metadata` when columns are
  pivoted, nested, or unnested?
- If the operation could violate invariants: must error with a clear
  message before returning rather than returning a malformed design.

## Issue format

```
**Issue [N]: [Short title]**
Severity: BLOCKING | REQUIRED | SUGGESTION
Lens: [1–5 and lens name]
Resolution type: UNAMBIGUOUS | JUDGMENT CALL

[Concrete description. Quote or reference the spec text that is missing
or wrong. State the specific methodological problem in plain language.
For UNAMBIGUOUS: state the correct fix directly.
For JUDGMENT CALL: state the options and their trade-offs.]

Options:
- **[A]** [Description] — Effort: [low/medium/high], Risk: [low/medium/high], Impact: [what changes]
- **[B]** [Alternative description]
- **[C] Do nothing** — [what stays wrong or ambiguous]

**Recommendation: [A/B/C]** — [One sentence rationale]
```

## Severity tiers

- BLOCKING — The function will produce wrong behavior without resolving
  this. An implementer could write code that passes all tests and still
  violate domain semantics or silently corrupt the design.
- REQUIRED — A significant gap or ambiguity that will cause silent wrong
  behavior or user confusion about what the verb does to survey data.
- SUGGESTION — A documentation or clarity improvement; the
  implementation would likely still be correct without it.

## Resolution types (used by Stage 2 Resolve for batching)

- UNAMBIGUOUS — There is one correct answer. Show the fix; ask once to
  confirm the batch.
- JUDGMENT CALL — Multiple valid approaches exist. Ask the user to decide.

## Output file structure

Organize all issues by lens. If a lens has no issues, say "No issues
found." If a lens was skipped, say "Lens [N] not applicable: [reason]."

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

**Overall assessment:** [One honest sentence]
```

## Before writing the file

Confirm: all applicable lenses applied; every issue has BLOCKING / REQUIRED
/ SUGGESTION and UNAMBIGUOUS / JUDGMENT CALL; the overall assessment
honestly matches the issue count. Adversarial means rigorous, not
performatively negative — if the methodology is sound, say so.

## Return value

Return ONLY one of these one-liners (the dispatcher surfaces it; do not
echo issues or file contents):
- "Methodology Pass N complete: X blocking, Y required, Z suggestion. Review at {methodology_path}."
- "Stage 2 not applicable for {id}: <reason>."
- "Mini-pass complete: N issues found. Resolve via Stage 2 Resolve."
````

## Step 4 — Report to the user

The subagent returns a single-line summary. Surface it as one of:

> Methodology review Pass [N] complete: {N} new issues ({X} blocking,
> {Y} required, {Z} suggestions). Start a new session with
> `/spec-workflow stage 2 resolve` to lock the methodology before
> running the code review. Review appended to
> `plans/spec-methodology-{id}.md`.

Or for a not-applicable result:

> Stage 2 not applicable for {id}: <reason>. Proceed to
> `/spec-workflow stage 3`.

Or for mini-pass mode:

> Mini-pass complete: {N} issues found. Resolve via Stage 2 Resolve
> targeting these issues only.

Do not echo the issue list itself — it lives in the file.

## What if the subagent fails?

If the subagent reports an error (file not found, can't write output,
etc.), surface the error to the user without retrying. Do not attempt
to do the review in main context as a fallback — that re-creates the
exact problem this dispatcher is solving.
