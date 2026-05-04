# Stage 2: Adversarial Plan Review (Subagent Dispatcher)

This stage finds every gap, wrong PR boundary, missing file, unverifiable
acceptance criterion, and spec coverage failure in the implementation plan.

**Stage 2 runs as a single subagent.** The plan + spec content never enters
main context. Your job here is dispatch, not review.

This is deliberate: real surveyverse plans are 800–1500 lines and the spec
they reference is 1500+ lines. Reviewing them in main context forces a
compaction mid-pass.

---

## Step 1 — Confirm inputs

If not already obvious from the user's message, ask for any missing values:

- **Plan path** (default: `plans/impl-{id}.md`)
- **Spec path** (default: `plans/spec-{id}.md`)
- **Phase id** for the output file (e.g., `phase-0.7`, `filter`, `joins`)

Output path is always `plans/plan-review-{phase}.md`.

Do **not** read the plan or spec yourself. The whole point is to keep them
out of main context.

## Step 2 — Check for an existing review file

Use Bash: `test -f plans/plan-review-{phase}.md && echo exists || echo absent`

If it exists, the subagent will append Pass N+1; if it does not, the
subagent will create it as Pass 1. Pass that fact to the subagent verbatim.

## Step 3 — Dispatch the review subagent

Use the `Agent` tool with `subagent_type: "general-purpose"`. Hand it the
prompt below verbatim, with `{plan_path}`, `{spec_path}`, `{review_path}`,
and `{exists_or_absent}` substituted. Run it in the foreground — you need
the summary before reporting to the user.

````
You are reviewing an implementation plan for surveytidy. Your job: find
every gap, wrong PR boundary, missing file, unverifiable acceptance
criterion, and spec coverage failure in the plan. Be adversarial. The
user does not want validation — they want problems found before coding
starts.

## Inputs

- Plan: {plan_path}
- Spec: {spec_path}
- Output: {review_path}
- Existing review file: {exists_or_absent}
  - If "exists": read it, determine the highest existing Pass number,
    new pass = N+1; list prior issues with ✅ Resolved or ⚠️ Still open
    status; APPEND the new pass to the bottom — never overwrite.
  - If "absent": create the file with Pass 1; omit the Prior Issues
    section.

## Surveyverse rules (read what's relevant)

The plan must conform to surveyverse rules. Read any of these you need
to evaluate an issue:

- `.claude/rules/github-strategy.md` — PR granularity, branching, commit format
- `.claude/rules/testing-standards.md` — coverage targets, assertion patterns
- `.claude/rules/testing-surveytidy.md` — `test_invariants()`, design loops, domain preservation
- `.claude/rules/engineering-preferences.md` — DRY, edge cases, explicit over clever
- `.claude/rules/code-style.md` — cli error structure, error classes
- `.claude/rules/r-package-conventions.md` — `::`, NAMESPACE, roxygen
- `.claude/rules/surveytidy-conventions.md` — S3 dispatch, special columns

When citing a rule violation in an issue, name the file (e.g.,
"Violates github-strategy.md PR granularity").

## Workflow

1. Read the plan in full (single pass).
2. Read the spec in full (single pass) — needed for Lens 4.
3. If a review file exists, read it.
4. Apply the five lenses below to the plan.
5. Write the review (append or create per the rule above).
6. Return a single-line summary:
   "Pass N complete: X blocking, Y required, Z suggestion. Review at {review_path}."

## Five review lenses (apply all five, in order)

### Lens 1 — PR Granularity
- Are any PRs bundling verbs that should be separate?
  (e.g., `rename` + `mutate` in one PR — not acceptable)
- Are any PRs missing that should exist?
  (e.g., shared infrastructure lumped into the first verb's PR)
- Does any PR contain more than ~3 new R files + their test files?
- Are tightly related verb pairs explicitly justified?
  (`arrange` + `slice_*` is acceptable; `filter` + `select` is not)
- Is there a dedicated PR for shared infrastructure that ships before
  the verbs depending on it?

### Lens 2 — Dependency Ordering
- Do PRs build in the right sequence? Shared helpers before verbs,
  verbs before integration tests.
- Is every `Depends on:` field accurate — no circular dependencies, no
  missing dependencies?
- If two PRs are genuinely independent, are they marked as such?
- Does the first PR leave `main`/`develop` in a state where CI passes?
- Does the PR sequence match the build order defined in the spec's
  Architecture section?

### Lens 3 — Acceptance Criteria
For every PR:
- Are all acceptance criteria objectively verifiable? ("Works correctly"
  is not verifiable; "0 errors in `devtools::check()`" is.)
- Are the standard criteria present?
  - `devtools::check()` pass
  - `devtools::document()` run; NAMESPACE and man/ in sync
  - All three design types tested via `make_all_designs()`
  - Domain column preservation asserted
  - Changelog entry written and committed on this branch
- Are verb-specific criteria present and complete?
  (e.g., for filter: domain column created, AND-accumulation tested;
  for rename: @variables and @metadata keys updated)
- Is the 98%+ line coverage requirement stated?
- Is `plans/error-messages.md` update listed as a criterion where new
  error classes are introduced?

### Lens 4 — Spec Coverage
Compare the plan against the spec:
- Does every function in the spec have a corresponding PR?
- Does every error class in the spec have a test requirement in the
  acceptance criteria?
- Are any behaviors from the spec absent from the plan?
- Does the plan include anything NOT in the spec? (Scope creep — flag it.)
- Are all edge cases from the spec covered by at least one acceptance
  criterion?

### Lens 5 — File Completeness
For every PR, check that all required files are listed:
- `R/[verb].R` — implementation file
- `tests/testthat/test-[verb].R` — test file (listed before source in TDD order)
- `changelog/phase-{X}/feature-[name].md` — changelog entry
- NAMESPACE and man/ (implicitly via `devtools::document()` criterion)
- `plans/error-messages.md` update (if new error classes are introduced)
- `tests/testthat/helper-test-data.R` update (if new test helpers are needed)

## Issue format

```
**Issue [N]: [Short title]**
Severity: BLOCKING | REQUIRED | SUGGESTION
[Rule or principle violated, e.g. "Violates github-strategy.md PR granularity"]

[Concrete description of the problem. Quote the plan text that is problematic,
or name the thing that is absent.]

Options:
- **[A]** [Description] — Effort: [low/medium/high], Risk: [low/medium/high], Impact: [what]
- **[B]** [Alternative description]
- **[C] Do nothing** — [what breaks or stays ambiguous]

**Recommendation: [A/B/C]** — [One sentence rationale]
```

## Severity tiers

- **BLOCKING** — Cannot implement correctly without resolving;
  implementer would have to guess PR scope or sequence.
- **REQUIRED** — Will cause test failures, missed coverage, or a broken
  `main` if not addressed.
- **SUGGESTION** — Quality improvement worth considering before coding starts.

## Output file structure

Organize issues by plan section. If a section has no issues, say
"No issues found."

```markdown
## Plan Review: Phase [X] — Pass [N] ([YYYY-MM-DD])

### Prior Issues (Pass [N-1])
_Omit this section on Pass 1._

| # | Title | Status |
|---|---|---|
| 1 | [title] | ✅ Resolved |
| 2 | [title] | ⚠️ Still open |

### New Issues

#### Section: PR Map

**Issue [N]: [title]**
Severity: BLOCKING
...

#### Section: PR [N] — [title]

No new issues found.

---

## Summary (Pass [N])

| Severity | Count |
|---|---|
| BLOCKING | N |
| REQUIRED | N |
| SUGGESTION | N |

**Total issues:** N

**Overall assessment:** [One honest sentence — e.g., "The plan is ready
to implement after resolving one blocking ambiguity in the PR dependency
order."]
```

## Before writing the file

Ask yourself:
- Have I applied all five lenses, not just the ones that found issues?
- For every PR: did I check granularity, dependencies, all acceptance
  criteria, and all files?
- Have I cross-referenced against the spec for coverage gaps?
- Is the overall assessment honest — does it match the issue count and severity?

If a plan is genuinely solid, say so. Adversarial means honest, not
performatively negative.

## Return value

After writing the file, return ONLY the one-line summary. The dispatcher
will surface it to the user. Do not echo the issue list or the file
contents — the dispatcher must keep main context clean.
````

## Step 4 — Report to the user

The subagent returns a single-line summary. Surface it as:

> Pass [N] complete: {N} new issues ({X} blocking, {Y} required, {Z}
> suggestions). Review at `plans/plan-review-{phase}.md`. Start a new
> session with `/implementation-workflow stage 3` to resolve these
> interactively.

Do not echo the issue list itself — it lives in the file. The whole
point of dispatching to a subagent is that main context never sees it.

## What if the subagent fails?

If the subagent reports an error (file not found, can't write output,
etc.), surface the error to the user without retrying. They probably
need to fix a path or permissions before re-dispatching. Do not attempt
to do the review in main context as a fallback — that re-creates the
exact problem this dispatcher is solving.
