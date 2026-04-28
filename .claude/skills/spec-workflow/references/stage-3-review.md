# Stage 3: Adversarial Spec Review (Subagent Dispatcher)

This stage finds every code-quality gap, ambiguity, under-specification,
over-engineering, and missing test case in the spec. It complements Stage 2
(methodology) — Stage 2 catches "the function does the wrong thing to survey
data"; Stage 3 catches "the function is not implementable as specified."

**Stage 3 runs as a single subagent.** The spec content never enters main
context. Your job here is dispatch, not review.

This is deliberate: surveyverse specs are 1500–2000 lines and reviewing
them in main context forces a compaction mid-pass.

---

## Step 1 — Confirm inputs

If not already obvious from the user's message, ask for any missing values:

- **Spec path** (default: `plans/spec-{id}.md`)
- **`{id}`** (e.g., `filter`, `joins`, `phase-0.7`, `survey-collection`)

Output path is always `plans/spec-review-{id}.md`.

Do **not** read the spec yourself. The whole point is to keep it out of
main context.

## Step 2 — Check for an existing spec review file

Use Bash: `test -f plans/spec-review-{id}.md && echo exists || echo absent`

The subagent's append-vs-create behavior depends on this. Pass it verbatim.

## Step 3 — Dispatch the review subagent

Use the `Agent` tool with `subagent_type: "general-purpose"`. Hand it the
prompt below verbatim, with `{spec_path}`, `{review_path}`, and
`{exists_or_absent}` substituted. Run in the foreground.

````
You are reviewing a surveytidy spec for code-quality completeness. Your
job: find every gap, ambiguity, under-specification, over-engineering,
and missing test case in the spec. Be adversarial. The user does not
want validation — they want problems found now, before code is written.

This stage complements the Stage 2 methodology review. Assume the
methodology is locked; focus on whether the spec is actually
implementable as written.

## Inputs

- Spec: {spec_path}
- Output: {review_path}
- Existing review file: {exists_or_absent}
  - If "exists": read it, determine the highest existing Pass number,
    new pass = N+1; list prior issues with ✅ Resolved or ⚠️ Still open
    status; APPEND the new pass to the bottom — never overwrite.
  - If "absent": create the file with Pass 1; omit the Prior Issues
    section.

## Surveyverse rules (read what's relevant)

When citing a violation, name the file:
- `.claude/rules/code-style.md` — indentation, pipe, formatter, cli error
  structure, argument order, helper placement
- `.claude/rules/r-package-conventions.md` — `::`, NAMESPACE, roxygen,
  `@return`, `@examples`, export policy
- `.claude/rules/surveytidy-conventions.md` — S3 dispatch, verb method
  names, special columns, return visibility
- `.claude/rules/testing-standards.md` — `test_that()` scope, 98%
  coverage, assertion patterns, data generators
- `.claude/rules/testing-surveytidy.md` — `test_invariants()`, three
  design type loops, domain preservation, verb error patterns
- `.claude/rules/engineering-preferences.md` — DRY, edge cases, explicit
  over clever
- `.claude/rules/github-strategy.md` — branch naming, PR granularity,
  commit format

When the spec is silent on something a rule already defines, note that
the rule is authoritative — the spec doesn't need to repeat it.

## Workflow

1. Read the spec in full (single pass).
2. If a review file exists, read it.
3. Apply the five lenses below, in order.
4. Write the file (append or create per the rule above).
5. Return a single-line summary:
   "Pass N complete: X blocking, Y required, Z suggestion. Review at {review_path}."

## Five review lenses (apply all five, in order)

### Lens 1 — DRY (highest priority)

Find every place two functions describe the same behavior:
- Two or more verbs performing the same validation (e.g., both
  validate tidy-select input the same way)
- The same error condition described separately in two function contracts
- Test setup that will clearly be duplicated across test blocks
- Spec sections that restate behavior already defined elsewhere without
  referencing the original definition

### Lens 2 — Test Completeness

For every exported verb/function, verify a test plan exists for each:

1. Happy path — standard inputs, expected output
2. All three design types — taylor, replicate, twophase via `make_all_designs()`
3. Domain preservation — domain column survives the verb operation
4. After existing domain — verb applied to a filtered design; domain preserved
5. `visible_vars` behavior — if `select()` involved, state is asserted
6. `@groups` behavior — if `group_by()`/`ungroup()` involved, state is asserted
7. `@metadata` contract — metadata updates specified and tested
8. Error paths — every row in the error table covered by a test
9. Edge cases — all-NA input, single-row data, empty domain, 0-row result

Mechanic rules:
- `test_invariants()` specified as first assertion in every verb test block?
- Dual pattern (class= + snapshot) specified for all user-facing errors?
- `class=` required on every error and warning in the spec?
- All three design types covered for every verb?

### Lens 3 — Contract Completeness

For every function:
- All arguments documented with type, default, one-sentence description?
- Argument order correct?
  `.data` → required NSE → required scalar → optional NSE → optional scalar → `...`
- All output changes named and typed (every change to @data,
  @variables, @metadata, @groups stated explicitly)?
- Error table complete with class names in correct format?
- All new error classes flagged as additions to `plans/error-messages.md`?
- Edge case behaviors explicitly defined — not left as "reasonable behavior"?
- Every example block begins with `library(dplyr)` or `library(tidyr)`?

### Lens 4 — Edge Cases

Do these scenarios appear explicitly somewhere in the spec?
- All-NA input column (for filter, drop_na, etc.)
- Zero-weight rows in `@data`
- Single-row design
- Empty domain after a `filter()` call
- Domain estimation combined with `group_by()`
- `filter()` chaining — second filter AND-accumulates with first
- Renaming a design variable (weights, strata, PSU)
- Selecting only design variables (visible_vars = NULL)
- Mutating the weight column

"The implementation should handle edge cases gracefully" is not a spec.

### Lens 5 — Engineering Level

Apply `engineering-preferences.md` to flag both failure modes:

Under-engineered: missing edge case handling, contracts that don't
specify behavior at boundaries, "behavior is undefined for X" without
stating what actually happens, error classes named but absent from the
error table.

Over-engineered: abstraction layers without two real call sites in the
spec, generalization for hypothetical future phases not in the current
roadmap, performance optimization specified before correctness is
established.

## Issue format

```
**Issue [N]: [Short title]**
Severity: BLOCKING | REQUIRED | SUGGESTION
[Rule or principle violated, e.g. "Violates engineering-preferences.md §4"]

[Concrete description of the problem. Quote the spec text that is
problematic, or name the thing that is absent.]

Options:
- **[A]** [Description] — Effort: [low/medium/high], Risk: [low/medium/high], Impact: [what]
- **[B]** [Alternative description]
- **[C] Do nothing** — [what stays broken or ambiguous]

**Recommendation: [A/B/C]** — [One sentence rationale]
```

## Severity tiers

- BLOCKING — Cannot implement without resolving; implementer would have
  to make an architectural guess.
- REQUIRED — Will cause test failures, R CMD check issues, or runtime
  bugs if not addressed.
- SUGGESTION — Quality improvement worth considering before
  implementation.

## Output file structure

Organize all issues by spec section. If a section has no issues, say
"No issues found."

```markdown
## Spec Review: [id] — Pass [N] ([YYYY-MM-DD])

### Prior Issues (Pass [N-1])
_Omit this section on Pass 1._

| # | Title | Status |
|---|---|---|
| 1 | [title] | ✅ Resolved |
| 2 | [title] | ⚠️ Still open |

### New Issues

#### Section: [First major section name]

**Issue [N]: [title]**
Severity: BLOCKING
...

#### Section: [Next section name]

No new issues found.

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

- Have I applied all five lenses, not just the ones that found issues?
- For every function contract: did I check argument order, all three
  design types, and the error table?
- Have I flagged actual problems, not manufactured ones?
- Is the overall assessment honest — does it match the issue count and
  severity?

If a spec is genuinely complete and well-specified, say so. Adversarial
means honest, not performatively negative.

## Return value

After writing the file, return ONLY the one-line summary. The dispatcher
will surface it to the user. Do not echo the issue list or the file
contents.
````

## Step 4 — Report to the user

The subagent returns a single-line summary. Surface it as:

> Pass [N] complete: {N} new issues ({X} blocking, {Y} required, {Z}
> suggestions). Start a new session with `/spec-workflow stage 4` to
> resolve these interactively. Review appended to
> `plans/spec-review-{id}.md`.

Do not echo the issue list itself — it lives in the file.

## What if the subagent fails?

If the subagent reports an error (file not found, can't write output,
etc.), surface the error to the user without retrying. Do not attempt
to do the review in main context as a fallback — that re-creates the
exact problem this dispatcher is solving.
