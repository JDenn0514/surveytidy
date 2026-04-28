# Stage 3: Resolve Plan Issues + Log Decisions

## Before Starting — Load Open Issues via Subagent

Check whether the plan-review file exists:

```bash
test -f plans/plan-review-{phase}.md && echo exists || echo absent
```

(`{phase}` is the phase id, e.g. `phase-0.7`, `phase-1`, or a feature
slug like `joins`.)

**If absent:** Tell the user:

> "No plan-review file found at `plans/plan-review-{phase}.md`.
> Run Stage 2 first to get a saved issue list, then come back here to
> resolve them. Alternatively, confirm you want an informal review pass
> without a saved issue list."

**If it exists:** Dispatch a loader subagent to extract just the open
issues. **Do not read the plan-review file yourself** — it can be 1000+
lines and loading it forces compaction mid-session.

Use the `Agent` tool with `subagent_type: "general-purpose"`. Hand it the
prompt below verbatim:

````
You are loading open issues from a surveyverse plan-review file for a
Stage 3 Resolve session. Your job: read the file and return ONLY the
unresolved issues in a compact structured list. Filter out section
headers, summary tables, prior-pass status tables, prose, and any issue
marked ✅ Resolved on a later pass.

## Input

File: plans/plan-review-{phase}.md

## What "open" means

An issue is open if it appears in the most recent pass's "New Issues"
section AND has not been marked ✅ Resolved by a later pass. If the most
recent pass shows it as ⚠️ Still open in its Prior Issues table, it is
still open.

## Output format

Return a JSON-style array. One object per open issue. Use this schema:

[
  {
    "id": <number>,
    "section": "<plan section name from the file, e.g. 'PR Map' or 'PR 2 — Implementation'>",
    "severity": "BLOCKING" | "REQUIRED" | "SUGGESTION",
    "title": "<short title>",
    "body": "<the full markdown body of the issue, verbatim — description,
             options with effort/risk/impact/maintenance, recommendation,
             confirmation prompt>"
  },
  ...
]

After the array, add one summary line:
"Loaded N open issues. Severity counts: B blocking, R required, S suggestion. Walkthrough order: <list of ids in order>."

Walkthrough order: BLOCKING first, then REQUIRED, then SUGGESTION;
within each tier, file order.

Do not summarize, abbreviate, or paraphrase the issue bodies. The user
needs the full text to make informed decisions.
````

Hold the returned list in conversation state. Use the `body` field
verbatim when presenting issues — do not re-summarize.

---

## Choose a Batch Size

Use the `AskUserQuestion` tool:

```
question: "How many issues do you want to see at a time?"
header: "Batch size"
multiSelect: false
options:
  - label: "BIG — 4 issues at a time"
    description: "Present up to 4 issues, resolve all of them, then move to the next batch. Faster overall."
  - label: "SMALL — 1 issue at a time"
    description: "Present one issue, resolve it, then the next. Easier to stay focused."
```

Wait for the answer before presenting any issues.

---

## Working Through the Issues

Work through the issues **in the order they appear in the review file** —
do not re-group or re-sequence them.

Present a batch (4 or 1 depending on the chosen mode). For each issue in the
batch, show the issue text and options, then wait for the user's direction.
After the user has resolved all issues in the batch, ask:

> "Ready for the next batch?"

Then present the next batch. Do not apply fixes speculatively — wait for
explicit direction on each issue.

---

## Issue Format

For each issue (whether from the review file or found during this session),
**first print this block as plain markdown in the conversation**, leave a
blank line, then call `AskUserQuestion`:

```
**Issue [N]: [Short title]**

[Concrete description, with section/plan reference. Cite rule file if applicable,
e.g. "Violates github-strategy.md PR granularity rule."]

Options:
- **[A]** [Description] — Effort: [low/medium/high], Risk: [low/medium/high],
  Impact: [what this affects], Maintenance: [ongoing burden]
- **[B]** [Description]
- **[C] Do nothing** — [consequences of not addressing this]

**Recommendation: [A/B/C]** — [Why, mapped to engineering-preferences.md.]

> Do you agree with option [letter], or would you prefer a different direction?
```

The blank line between the markdown and the `AskUserQuestion` call is
**load-bearing** — without it the tool-call rendering clips the last line of
the markdown and the user loses the recommendation or the confirmation
prompt. This is non-negotiable: the markdown above is what the user reads
to make an informed decision, not the tool UI.

Call `AskUserQuestion` with the labels A / B / C and brief trade-off
summaries in the description fields. The full Effort / Risk / Impact /
Maintenance breakdown and the rationale must live in the markdown — they
will not fit inside the tool call (header is ≤12 chars, labels are 1–5
words).

---

## Applying Fixes — Editor Subagent

When the user approves a direction, **dispatch an editor subagent** to apply
the change. Do not edit the plan file in main context — implementation
plans are 800–1500 lines for a typical phase, and reading them mid-session
forces compaction.

Phrase the FIND and REPLACE WITH text yourself based on the user's chosen
option (you have the issue body, you know what the plan currently says
because the issue quoted it, and you know what the new wording should be).
Then hand the editor the verbatim before/after strings.

Use the `Agent` tool with `subagent_type: "general-purpose"`. Hand it
this prompt:

````
You are applying an approved plan edit. Your job: open the plan file,
locate the target text, replace it, and confirm.

## Inputs

- Plan file: plans/impl-{id}.md
- Target section (for context only): {e.g., "PR 2 — Acceptance Criteria"}
- Edit type: REPLACE | INSERT_AFTER

If REPLACE:
  - FIND (verbatim current text, must be unique in file):
    {paste exact current text}
  - REPLACE WITH (verbatim new text):
    {paste exact new text}

If INSERT_AFTER:
  - ANCHOR (verbatim text the new content goes after, must be unique):
    {paste anchor text}
  - NEW TEXT:
    {paste new text}

## Workflow

1. Open the plan file with Read.
2. For REPLACE: use Edit with old_string=FIND, new_string=REPLACE WITH.
   For INSERT_AFTER: use Edit with old_string=ANCHOR,
   new_string=ANCHOR + "\n\n" + NEW TEXT.
3. If FIND/ANCHOR is not unique, expand it with surrounding context
   until unique, then retry.
4. If FIND/ANCHOR is not found, return:
   "Edit failed: <reason>." Do not invent content.
5. On success, return:
   "Section <target> updated: <one-sentence summary of what changed>."

Do not paraphrase or improve the supplied text. Apply it verbatim.
````

After the subagent returns, surface its one-sentence summary and move to
the next issue.

If the subagent reports failure, surface the failure to the user and
ask how to proceed (re-phrase the FIND text? skip this issue?). Do not
attempt the edit in main context as a fallback — that re-introduces the
plan into main context, which is what this dispatch avoids.

Do not batch fixes. One editor dispatch per approved issue gives you
live "Section X updated" feedback after each decision and surfaces
wording problems early.

---

## Decisions Log

After all issues are resolved, write a decisions log entry if ANY of these
are true:

- You asked the user a question during this session
- You chose between meaningfully different approaches for PR scope or sequence
- You made a scope assumption not obvious from the spec or plan
- You deferred something to a later phase

**If every decision is already fully captured in the updated plan, skip the
log entry.**

The log lives at `plans/claude-decisions-phase-{X}.md`. Create the file with
this header if it doesn't exist:

```markdown
# Claude Decisions Log — surveytidy Phase [X]

This file records planning decisions made during implementation of Phase [X].
Each entry corresponds to one planning session.

---
```

Entry format:

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

Only log decisions — not implementation details already determined by the plan
or a rule file.

---

## After Resolution

Tell the user:

> "The plan is approved. Hand off to `/r-implement` and start with PR 1
> in the PR map."
