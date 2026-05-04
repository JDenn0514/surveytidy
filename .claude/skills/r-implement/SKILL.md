---
name: r-implement
description: >
  Use when it's time to write R implementation code for surveytidy. Trigger
  when the user says "implement", "code this up", "start coding", "write the
  code", "start the PR", or "let's build this". Also use when commit-and-pr
  produces a CI Failure handoff block and the user needs the failure fixed
  (Mode B), or when the user says "subagent mode", "drive it yourself", or
  "auto-implement the plan" (Mode C: subagent-driven per-section dispatch).
---

**Announce at start:** "Running r-implement skill."

# R Implementation Skill

You are implementing R package code for surveytidy.

The surveytidy coding rules (code style, conventions, testing standards) are
already loaded into context at session start from `.claude/rules/` via
`CLAUDE.md`. Do not re-read them — assume they are present and authoritative.
The only rules-adjacent file you may need to touch is
`plans/error-messages.md` (the registry of error/warning classes).

---

## Step 0 — Choose a mode (ask, do not infer)

Before anything else, use the `AskUserQuestion` tool to ask which mode to
run. Always ask — do not infer from trigger phrases, conversation context,
or the presence of a CI failure block. The user's explicit answer
determines the path. This avoids accidentally falling into the
context-heavy inline path when the user actually wanted subagent dispatch.

Call `AskUserQuestion` with one question, header `"Mode"`, and these three
options (in this order, with Mode C marked Recommended):

1. **Mode C: Subagent-Driven (Recommended)** — Main thread reads the plan
   once, then dispatches a fresh implementer subagent per section, with
   spec-compliance and code-quality reviewer subagents after each. Lowest
   main-context usage; best for plans with multiple sections.
2. **Mode A: Inline** — Main agent reads plan/spec and writes code
   directly in this session. Suitable for tiny one-off changes or
   interactive driving. Highest main-context usage on multi-section work.
3. **Mode B: CI-fix** — Triages a `CI Failure — Handoff to r-implement`
   block from `commit-and-pr`, reproduces locally, fixes within 3
   attempts. Use only when the user has handed over a CI failure block.

Branch on the answer:
- **Mode A** → continue with Pre-flight below.
- **Mode B** → read `references/ci-fix.md`. Skip Pre-flight.
- **Mode C** → read `references/mode-c-subagent.md`. Skip Pre-flight.

---

## Pre-flight (Mode A)

### Step 1 — Branch

```bash
git branch --show-current
```

- On `main`: stop. Tell the user "Feature branches start from `develop`. Run
  `git checkout develop` and re-invoke `/r-implement`." Do not proceed.
- On `develop`: ask for the plan path (if not given), find the first
  unchecked `- [ ]` section, propose a branch name from that section, and
  on confirmation create it: `git checkout -b feature/X`.
- On a feature branch: continue.

### Step 2 — surveycore version

surveycore is a co-developed GitHub-only dependency. A stale install means
you'd implement against the wrong API:

```bash
gh release view --repo JDenn0514/surveycore --json tagName \
  --template '{{.tagName}}'
Rscript -e "cat(as.character(packageVersion('surveycore')))"
```

If installed < latest tag, stop and tell the user to run
`pak::pak('JDenn0514/surveycore')` and re-invoke `/r-implement`. If `gh`
fails (no auth/network), warn and ask whether to proceed.

### Step 3 — Locate the plan section (do NOT read the full plan)

Plan files are 1,000+ lines. Reading the whole file blows the cache budget
before you've started. Instead:

```bash
grep -n "^- \[ \]\|^## \|^### " plans/<plan-file>.md
```

Use the line numbers to locate the first unchecked `- [ ]` and its enclosing
section headers. Then `Read` only that range with `offset` and `limit`. The
section you read is the **entire scope** for this session — do not implement
anything outside it.

If all sections are checked, report "All sections complete — nothing to
implement" and stop.

### Step 4 — Locate the spec section (same approach)

```bash
grep -n "^## \|^### " plans/<spec-file>.md
```

Find the section that maps to your plan section. `Read` only that range.

Before writing any code, confirm the spec section gives you:
- Every function signature (inputs, outputs, defaults)
- Every error condition with a class name that exists in
  `plans/error-messages.md`
- Every edge case and its expected behavior

If anything is ambiguous or underspecified, **stop and ask the user**. Do not
guess at architecture — surface the question.

### Step 5 — Survey existing patterns via Explore subagent

Skip this step only if the section is the first verb in a new family — when
there are no patterns to mirror yet. Otherwise, do not skim the codebase
yourself; reading 5–10 R/ and test files in full is the single biggest
context drain in this workflow.

Dispatch an `Explore` subagent at `medium` thoroughness. Brief it explicitly
to **navigate, not abstract** — its job is to point you at the right line
ranges so you can do precise verbatim reads, not to paraphrase the code into
a summary you'd implement from. Surveytidy's conventions (exact helper
signatures, exact `test_invariants()` placement, exact error class names)
need to be copied character-for-character, and a summary loses that.

Suggested brief:

> "We're implementing **<section name>** for surveytidy. Survey the codebase
> and return **navigation pointers, not summaries**. For the verbs and tests
> most similar to what we're building, report:
> - File path + exact line range of each relevant function or test block
> - Function/test signature (def line + arg names only — not the body)
> - 5-line pseudocode shape of the body
> - Error/warning classes referenced
> - Helper functions called from `R/utils.R` or `R/collection-dispatch.R`
>
> Cap the report at 250 lines. I'll do verbatim `Read` of the spans you
> point to — your job is navigation, not abstraction."

When the report comes back, do precision reads with `offset`/`limit` on the
spans the subagent pointed to. Do not re-survey the codebase yourself.

### Step 6 — Stage new error classes

If your section adds error or warning classes, add rows to
`plans/error-messages.md` *before* writing code that uses them.

---

## Implementation (TDD — red phase mandatory)

For each sub-task in the section:

1. Write the test file first, drawing categories from the spec
   (happy path + every error class + every listed edge case).
2. Run `devtools::test()` and **confirm the new tests fail** with messages
   like "did not throw" or "object not found." If anything passes before
   source code exists, the tests aren't exercising real behavior — stop and
   investigate.
3. Write the R source file to make the tests pass.
4. Run `devtools::document()` if roxygen2 tags changed.
5. Update `_pkgdown.yml` if new exports were added — place them in the
   reference section that matches the `@family` tag.

**No production code before a failing test.** A test written after the code
almost always passes immediately, which proves nothing. The red phase is the
evidence that the test exercises what you think it does.

When studying existing R/ or test files for patterns, `Read` with
`offset`/`limit` on the relevant function — full files are 200–500 lines.

---

## Verification & Sub-task Gate

After a sub-task's new tests pass, run both:

```r
devtools::test()
devtools::check()
```

Then verify before marking the sub-task `[x]`:

- **Spec** — every error condition fires, every listed edge case has a test,
  return-value visibility matches the spec.
- **Conventions** — `class=` on every `cli_abort`/`cli_warn`; no
  `@importFrom`; no `:::` (use `R/utils.R` wrappers); S3 methods registered
  in `.onLoad()`, not via `UseMethod()`; `test_invariants()` is the first
  assertion in every verb test block; dual pattern (`class=` + snapshot) on
  user-facing error tests; domain column preserved through the operation;
  all 3 design types covered via `make_all_designs()`; examples that use
  dplyr/tidyr verbs open with `library(dplyr)` or `library(tidyr)`.

If either reveals a gap, fix before moving to the next sub-task.

After **3 failed attempts on the same failure**, stop and report:
- The exact error output
- What you tried
- Why it's still failing

---

## Completion

When `devtools::test()` and `devtools::check()` both pass (0 errors,
0 warnings, ≤2 notes) and every sub-task has cleared the gate:

1. Mark the section `[x]` in the plan.
2. Confirm: `document()` was run if roxygen changed, `_pkgdown.yml` updated
   if exports were added, `error-messages.md` updated if classes were added.
3. Report:

> "Section complete. Start a new session with `/commit-and-pr` to create the PR."
