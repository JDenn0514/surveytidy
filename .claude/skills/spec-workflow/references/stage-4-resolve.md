# Stage 3: Resolve Issues + Log Decisions

## Before Starting — Load Open Issues via Subagent

Check whether either review file exists. Stage 4 may have output from
Stage 2 (methodology), Stage 3 (spec review), or both.

```bash
test -f plans/spec-methodology-{id}.md && echo m-exists || echo m-absent
test -f plans/spec-review-{id}.md && echo r-exists || echo r-absent
```

**If neither exists:** Tell the user:

> "No review files found at `plans/spec-methodology-{id}.md` or
> `plans/spec-review-{id}.md`. Run Stage 2 and/or Stage 3 first to get a
> saved issue list, then come back here to resolve them."

**If at least one exists:** Dispatch a loader subagent to extract just the
open issues. **Do not read the review files yourself** — they can be 1000+
lines combined and loading them forces compaction mid-session.

Use the `Agent` tool with `subagent_type: "general-purpose"`. Hand it the
prompt below verbatim, substituting the existing file paths (omit any
file that doesn't exist):

````
You are loading open issues from surveyverse review files for a Stage 4
resolve session. Your job: read the listed review files and return ONLY
the unresolved issues in a compact structured list. Filter out everything
else — section headers, summary tables, prior-pass status tables, prose,
and any issue marked ✅ Resolved on a later pass.

## Inputs

Files to read (skip any that don't exist):
- {methodology_path}
- {spec_review_path}

## What "open" means

An issue is open if it appears in the most recent pass's "New Issues"
section AND has not been marked ✅ Resolved by a later pass. If the most
recent pass shows it as ⚠️ Still open in its Prior Issues table, it is
still open. If any later pass shows it as ✅ Resolved, it is closed.

## Output format

Return a JSON-style array. One object per open issue. Use this schema:

[
  {
    "id": <number>,
    "source": "methodology" | "spec_review",
    "lens_or_section": "<lens name or section name from the file>",
    "severity": "BLOCKING" | "REQUIRED" | "SUGGESTION",
    "resolution_type": "UNAMBIGUOUS" | "JUDGMENT CALL" | null,
    "title": "<short title>",
    "body": "<the full markdown body of the issue, verbatim — description,
             options with effort/risk/impact/maintenance, recommendation,
             confirmation prompt>"
  },
  ...
]

After the array, add a one-line summary:
"Loaded N open issues: X methodology, Y spec review. Walkthrough order: <list of source/id pairs in order>."

Walkthrough order: BLOCKING first, then REQUIRED, then SUGGESTION;
within each tier, methodology issues before spec review issues; within
source, file order.

Do not summarize, abbreviate, or paraphrase the issue bodies. The user
needs the full text — including the recommendation and confirmation
prompt — to make informed decisions.
````

Hold the returned list in conversation state. Use the `body` field
verbatim when presenting each issue (per the Issue Format section
below) — do not re-summarize.

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

Work through the issues **in the walkthrough order returned by the loader
subagent** (BLOCKING → REQUIRED → SUGGESTION). Do not re-group or
re-sequence them.

Present a batch (4 or 1 depending on the chosen mode). For each issue in
the batch, print the loader's `body` field verbatim as markdown (per the
Issue Format section), leave a blank line, then call `AskUserQuestion`
for the user's direction. After the user has resolved all issues in the
batch, ask:

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

[Concrete description, with section/spec reference. Cite rule file if applicable,
e.g. "Violates code-style.md §3."]

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
the change. Do not edit the spec in main context — the spec is 1500+ lines
for a typical phase, and reading it mid-session forces compaction.

Phrase the FIND and REPLACE WITH text yourself based on the user's chosen
option (you have the issue body, you know what the spec currently says
because the issue quoted it, and you know what the new wording should
be). Then hand the editor the verbatim before/after strings.

Use the `Agent` tool with `subagent_type: "general-purpose"`. Hand it
this prompt:

````
You are applying an approved spec edit. Your job: open the spec file,
locate the target text, replace it, and confirm.

## Inputs

- Spec file: plans/spec-{id}.md
- Target section (for context only): {e.g., "§III.2 — rename pre-flight"}
- Edit type: REPLACE | INSERT_AFTER

If REPLACE:
  - FIND (verbatim current text, must be unique in file):
    {paste exact current text here}
  - REPLACE WITH (verbatim new text):
    {paste exact new text here}

If INSERT_AFTER:
  - ANCHOR (verbatim text the new content goes after, must be unique):
    {paste anchor text}
  - NEW TEXT:
    {paste new text}

## Workflow

1. Open the spec file with Read.
2. For REPLACE: use the Edit tool with old_string=FIND, new_string=REPLACE WITH.
   For INSERT_AFTER: use Edit with old_string=ANCHOR,
   new_string=ANCHOR + "\n\n" + NEW TEXT.
3. If FIND/ANCHOR is not unique, expand it with surrounding context
   until unique, then retry.
4. If FIND/ANCHOR is not found at all, return:
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
spec into main context, which is what this dispatch avoids.

Do not batch fixes. One editor dispatch per approved issue gives you
live "Section X updated" feedback after each decision and surfaces
wording problems early.

---

## Decisions Log

After all issues are resolved, write a decisions log entry if ANY of these
are true:

- You asked the user a question during this session
- You chose between meaningfully different approaches
- You made a scope or behavior assumption not obvious from the spec
- You deferred something to a later phase

**If every decision is already fully captured in the updated spec, skip the
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

Only log decisions — not implementation details already determined by the spec
or a rule file. If the answer was predetermined, there is no decision to log.
