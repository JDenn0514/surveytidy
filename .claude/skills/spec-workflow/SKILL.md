---
name: spec-workflow
description: >
  Use this skill for any surveyverse planning or spec work — creating a new phase
  spec, reviewing an existing spec, building an implementation plan, or logging
  decisions. Trigger whenever the user says "next phase", "spec sheet", "finalize
  the spec", "review the plan", "implementation plan", "decision log", or references
  a phase number (e.g. "phase 1", "phase 0.5"). Also trigger when the user says
  they want to start planning or want help preparing before writing code.
---

# Surveyverse Spec Workflow

This skill governs all planning work for surveytidy (and other surveyverse
packages). It covers four stages that always happen in order:

1. **Draft** — Create the spec sheet
2. **Review** — Iteratively review and fix the spec (with decision logging)
3. **Plan** — Create the implementation plan
4. **Handoff** — Write the decisions log entry before any code is touched

Apply engineering-preferences.md at every stage.

Read the relevant stage below based on where the user is in the workflow. If
unclear, ask.

---

## Rules in Context

This skill works alongside — never instead of — the following rule files. When
reviewing a spec or plan, check compliance with all of them:

| Rule file | What it governs |
|---|---|
| `code-style.md` | Indentation, pipe, air formatter, cli error structure, argument order, helper placement |
| `r-package-conventions.md` | `::` usage, NAMESPACE, roxygen2, `@return`, `@examples`, export policy |
| `surveytidy-conventions.md` | S3 dispatch, verb method names, special columns (domain, visible_vars, @groups), return visibility |
| `testing-standards.md` | `test_that()` scope, flat structure, 98% coverage, assertion patterns, data generators |
| `testing-surveytidy.md` | `test_invariants()`, three design type loops, domain preservation, verb error patterns |

When a spec decision touches one of these rules, cite the rule file. When a spec
is *silent* on something these rules already define, note that the rule is
authoritative and the spec doesn't need to repeat it.

---

## Stage 1: Drafting a Spec Sheet

### Before writing anything

Ask the user:
1. Which package and phase is this for?
2. Is there an existing roadmap document to reference?
3. Are there upstream phase specs that constrain this one? (Ask them to share.)

Then read all provided context before writing a single line.

### Spec structure

Model every spec on the Phase 0.5 structure. Required sections:

| Section | Content |
|---|---|
| Header block | Version, date, status |
| Document Purpose | One paragraph: this is the source of truth |
| I. Scope | What this phase delivers (table), what it does NOT deliver, design support matrix |
| II. Architecture | File organization tree, shared helpers with signatures |
| III–N. Function specs | One section per verb: signature, argument table, output contract, behavior rules, error table |
| Testing section | Per-verb test categories, edge cases, invariant helpers |
| Quality Gates | Checklist of what "done" means — must be objectively verifiable |
| Integration section | Contracts with other packages (surveycore, estimators in Phase 1) |

### Spec writing rules

- Every public verb gets a full argument table with: name, type, default, and
  one-sentence description. Argument order must follow `code-style.md`: `.data`
  first → required NSE → required scalar → optional NSE → optional scalar → `...`.
- Every verb gets an explicit output contract: what changes in the returned object.
- Every error condition is listed in a table with: error class, trigger condition,
  and the message template. Class names must follow:
  `"surveytidy_error_{snake_case}"` or `"surveytidy_warning_{snake_case}"` for new
  errors; `"surveycore_error_{snake_case}"` for re-used surveycore errors.
- "TBD" and "to be determined" are not allowed — flag explicitly as a **GAP**
  with `> ⚠️ GAP: [description]` so it's easy to find.
- Domain estimation and grouping behavior must be specified for every verb.
- Do NOT restate rules already defined in `code-style.md`, `r-package-conventions.md`,
  or `surveytidy-conventions.md`. Reference them instead.

### After the draft

Tell the user: "This is a first draft. I expect there are gaps — let's move to the
review stage to find and fix them."

---

## Stage 2: Reviewing the Spec

### Before starting review

Check for a spec-reviewer output file at `plans/spec-review-phase-{X}.md`. If it
exists, work through those issues in order rather than doing a fresh review pass —
the adversarial review has already been done. Skip to the BIG/SMALL question below,
then address each issue in the file sequentially.

If no file exists, do a fresh review using the sections below.

### Two review modes

Before starting any review, ask:

> I can work through this in one of two ways:
> 1. **BIG CHANGE** — Work through this interactively, one section at a time
>    (Architecture → Contracts → Tests → Quality Gates), with at most 4 top
>    issues per section.
> 2. **SMALL CHANGE** — Work through interactively ONE question per section.
>
> Which do you prefer?

Wait for the answer before proceeding.

### Review sections and what to evaluate

#### Architecture review

- Overall system design and component boundaries
- Dependency graph — do helpers follow the placement rule from `code-style.md`:
  inline if used in 1 file, `utils.R` if used in 2+ files?
- File organization tree — does it match the naming conventions in `surveytidy-conventions.md`?
- Are all shared helpers specified with full signatures and return types?
- Are there DRY violations — verbs with duplicated logic that should share a helper?
- Is dispatch correct per `surveytidy-conventions.md`: S3 via `registerS3method()`
  in `.onLoad()`, not S7 methods?

#### Contract review

- **Argument completeness**: every argument documented with type, default, and
  one-sentence description. Survey-specific args (`.by`, `...`) get fuller treatment.
- **Argument order**: follows `code-style.md` rule — `.data` → required NSE →
  required scalar → optional NSE → optional scalar → `...`.
- **Output contract**: what changes in the returned survey object — @data, @variables,
  @metadata, @groups. Every change explicitly stated.
- **Return visibility**: all dplyr verbs return the modified survey object visibly.
- **Error table completeness**: every error class defined; every trigger condition
  covered. All new classes added to `plans/error-messages.md`.
- **cli structure**: `"x"` + `"i"` + optional `"v"` format; `class=` on every
  `cli_abort()` and `cli_warn()` — no exceptions (per `code-style.md` §3).
- **Missing edge cases**: all-NA inputs, single-row designs, empty domain,
  domain + grouping simultaneously, renaming design variables, selecting only
  design variables.
- **`@variables` keys**: are all keys always present (never absent, value `NULL`
  when unspecified) per `code-style.md` §2?
- **Example blocks**: every example starts with `library(dplyr)` or `library(tidyr)`.

#### Test review

Apply `testing-surveytidy.md` standards for this section.

Check these specifically:

- **`test_invariants()` present**: every verb test block calls it as the
  first assertion.
- **Three design types covered**: every verb tested with all of taylor, replicate,
  twophase via `make_all_designs()`.
- **Domain preservation tested**: domain column survives every verb operation.
- **Test categories present** for every verb:
  1. Happy path (class, properties, `test_invariants()` first)
  2. All three design types (cross-design loop)
  3. After existing domain (verb applied to filtered design)
  4. `visible_vars` / `@groups` state (where applicable)
  5. Metadata updates (where applicable)
  6. Error paths (every row in the error table covered)
  7. Edge cases (single-row, all-NA, empty domain, etc.)
- **Error test pattern**: dual pattern — `expect_error(class=)` + `expect_snapshot(error=TRUE)`.
- **Warning capture**: `expect_warning()` wrapping the call; result from return value.
  No `withCallingHandlers()` or `tryCatch()` in tests.
- **`test_that()` scope**: one observable behavior per block; present-tense assertion
  description; no `describe()` nesting.
- **`skip_if_not_installed()`**: block-level, not file-level.
- **Data**: unit tests use `make_all_designs(seed = N)`, not real datasets.
  Edge case data is inline — never added as parameters to the generator.
- **Coverage target**: 98%+ line coverage; any `# nocov` usage must be justified
  in a comment.

#### Quality Gates review

- Are the quality gates objectively verifiable (no vague criteria like "works correctly")?
- `devtools::check()` target present: 0 errors, 0 warnings, ≤2 pre-approved notes?
- All new files listed?
- `plans/error-messages.md` update in the gate list?
- `devtools::document()` cadence addressed (must run before any commit that changes
  roxygen2 content per `r-package-conventions.md`)?

### Issue format (required for every issue found)

NUMBER issues sequentially across sections. Give LETTERS to options.

```
**Issue [N]: [Short title]**

[Concrete description of the problem, with section/spec reference.
If a rule file governs this, cite it: e.g. "Violates code-style.md §3."]

Options:
- **[A]** [Description] — Effort: [low/medium/high], Risk: [low/medium/high],
  Impact: [what this affects], Maintenance: [ongoing burden]
- **[B]** [Description] — [same fields]
- **[C] Do nothing** — [consequences of not addressing this]

**Recommendation: [A/B/C]** — [Why, mapped to engineering preferences below.]

> Do you agree with option [letter], or would you prefer a different direction?
```

### Engineering preferences to apply in reviews

Map recommendations to `engineering-preferences.md` (priority order: DRY →
well-tested → engineered enough → edge cases → explicit over clever).

### After each review section

Output the section's issues (up to 4 for BIG CHANGE, 1 for SMALL CHANGE),
with all options and your recommendation. Then ask:

> "Does this look right? Any changes before I move to [next section]?"

Do not proceed to the next section until the user confirms.

### Applying fixes

When the user approves a direction, **edit the spec file immediately** — before
presenting the next issue. Do not batch fixes. Do not create a new file. After
each edit, summarize what changed in one sentence.

---

## Stage 3: Building the Implementation Plan

Only start this stage when the user explicitly says the spec is finalized.

### Plan structure

The implementation plan is a separate document from the spec. Required sections:

**Overview** — 2–3 sentences: what this plan delivers and how it relates to the spec.

**PR map** — A checkbox list of every planned PR. Use this exact format so
`r-implement` can read and check off sections:

```
- [ ] PR 1: `feature/branch-name` — one-sentence description
- [ ] PR 2: `feature/branch-name` — one-sentence description
```

Rules for the PR map:
- **One PR per logical unit of work.** For dplyr verbs: one PR per verb (or
  tightly related pair like `arrange` + `slice_*`). Never bundle multiple
  unrelated verbs into one PR because it's faster.
- Shared infrastructure (helpers, test helpers) ships in its own PR before
  the verbs that depend on it.
- No PR should contain more than ~3 new R files + their test files.
- `devtools::document()` and `devtools::check()` must pass before every PR is opened.

**Per-PR sections** — For each PR in the map:

```
### PR [N]: [Human-readable title]

**Branch:** `feature/[name]`
**Depends on:** PR [n] (or "none")

**Files:**
- `R/[file].R` — [one-sentence description]
- `tests/testthat/test-[file].R` — [one-sentence description]
- `changelog/phase-{X}/feature-[name].md` — created last, before opening PR

**Acceptance criteria:**
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] [specific test categories that must pass for this PR]
- [ ] All three design types tested via `make_all_designs()`
- [ ] Domain column preservation asserted
- [ ] Changelog entry written and committed on this branch

**Notes:** [Any implementation details the implementor needs to know that aren't
in the spec — gotchas, ordering constraints, etc.]
```

### After the plan is drafted

Tell the user: "Review the PR map carefully — the scope of each PR is harder to
change once implementation starts. In particular, confirm that no PR bundles
verbs that should be separate."

---

## Stage 4: Decisions Log Entry

Write a decisions log entry **if and only if** decisions were made in this session
that are NOT already reflected in the updated spec or implementation plan. If every
decision is captured in those documents, skip this stage.

When it is needed: this entry protects you when you look at the code six months
later and wonder why something was done a certain way.

The decisions log lives at:
- `plans/claude-decisions-phase-{X}.md`

If the file doesn't exist, create it with a header:

```markdown
# Claude Decisions Log — surveytidy Phase [X]

This file records planning decisions made during implementation of Phase [X].
Each entry corresponds to one planning session.

---
```

### What to log

Log a decision if ANY of these are true:
- You asked the user a question during planning
- You chose between two or more meaningfully different approaches
- You made a scope or behavior assumption not obvious from the spec
- You deferred something to a later phase

Do NOT log implementation details already fully determined by the spec or by a
rule file. If the answer was predetermined, there is no decision to log.

### Entry format

```markdown
## [YYYY-MM-DD] — [Component or feature planned]

### Context

[1–2 sentences: what were we trying to figure out in this session?]

### Questions & Decisions

**Q: [The question that came up]**
- Options considered:
  - **[Option A]:** [description and trade-offs]
  - **[Option B]:** [description and trade-offs]
- **Decision:** [what was decided]
- **Rationale:** [why — mapped to project constraints and engineering preferences]

### Outcome

[1 sentence: what will be built as a result of this session]

---
```

---

## Quick Reference

| User says... | Do this |
|---|---|
| "Start the next phase" / "Let's plan phase X" | Stage 1: ask for roadmap + upstream specs, then draft |
| "Review the spec" / "Check the plan" | Stage 2: ask BIG or SMALL, then review |
| "The spec looks good, build the implementation plan" | Stage 3: write the PR map |
| "Ready to start coding" / "ExitPlanMode" | Stage 4: write decisions log entry (if needed) |
| "Add to the decisions log" | Stage 4 only |

---

## File Locations Reference

```
Implementation plans: plans/phase-{X}-implementation-plan.md
Spec reviews:         plans/spec-review-phase-{X}.md
Decisions log:        plans/claude-decisions-phase-{X}.md
Changelogs:           changelog/phase-{X}/{branch-name}.md
```

Changelog entry format (written last on each branch, before opening a PR) is
defined in `.claude/skills/changelog-workflow.md`. This skill covers the planning
stage only.
