# Stage 2 Resolve: Lock Methodology

## Contents
- Before Starting
- Two Categories of Issues
- Working Through the Issues
- Methodology Lock Rule
- Decisions Log
- After Resolution

---

## Before Starting — Load Open Issues via Subagent

Check whether the methodology review file exists:

```bash
test -f plans/spec-methodology-{id}.md && echo exists || echo absent
```

**If absent:** Tell the user:

> "No methodology review file found at `plans/spec-methodology-{id}.md`.
> Run Stage 2 first to get the issue list, then come back here."

**If it exists:** Dispatch a loader subagent to extract just the open
issues. **Do not read the methodology file yourself** — it can be 500+
lines and loading it forces compaction mid-session.

Use the `Agent` tool with `subagent_type: "general-purpose"`. Hand it the
prompt below verbatim:

````
You are loading open issues from a surveyverse methodology review file
for a Stage 2 Resolve session. Your job: read the file and return ONLY
the unresolved issues in a compact structured list. Filter out
section headers, summary tables, prior-pass status tables, prose, and
any issue marked ✅ Resolved on a later pass.

## Input

File: plans/spec-methodology-{id}.md

## What "open" means

An issue is open if it appears in the most recent pass's "New Issues"
section AND has not been marked ✅ Resolved by a later pass. If the
most recent pass shows it as ⚠️ Still open in its Prior Issues table,
it is still open.

## Output format

Return a JSON-style array. One object per open issue. Use this schema:

[
  {
    "id": <number>,
    "lens": "<lens name from the file, e.g. 'Lens 3 — Design Variable Integrity'>",
    "severity": "BLOCKING" | "REQUIRED" | "SUGGESTION",
    "resolution_type": "UNAMBIGUOUS" | "JUDGMENT CALL",
    "title": "<short title>",
    "body": "<the full markdown body of the issue, verbatim — description,
             options with effort/risk/impact/maintenance, recommendation,
             confirmation prompt>"
  },
  ...
]

After the array, add two summary lines:
"Loaded N open issues: U unambiguous, J judgment calls."
"Severity counts: B blocking, R required, S suggestion."

Do not summarize, abbreviate, or paraphrase the issue bodies. The user
needs the full text to make informed decisions.
````

Hold the returned list in conversation state. Use the `body` field
verbatim when presenting issues — do not re-summarize.

---

## Working Through the Issues

Each loaded issue carries a `resolution_type`: **UNAMBIGUOUS** (one correct
fix; batch them) or **JUDGMENT CALL** (multiple valid options; present
one at a time). Work through BLOCKING first, then REQUIRED, then
SUGGESTION.

### Unambiguous batch

Collect all UNAMBIGUOUS issues. Print this list as plain markdown in the
conversation:

```
The following issues have one correct fix. I'll apply them all if you confirm:

Issue [N]: [title] — [one-sentence fix]
Issue [N]: [title] — [one-sentence fix]
...
```

**Leave a blank line**, then call `AskUserQuestion`:

```
question: "Apply all unambiguous fixes?"
header: "Unambiguous fixes"
multiSelect: false
options:
  - label: "Yes — apply all"
    description: "Edit the spec for each fix listed above."
  - label: "No — walk through them one at a time"
    description: "Treat each as a judgment call."
```

The blank line is load-bearing — without it the rendering clips the last
line of the markdown and the user can't see the full fix list.

After confirmation, **dispatch one editor subagent with all approved
unambiguous fixes batched into a single call.** Do not edit the spec in
main context — the spec is 1500+ lines for a typical phase, and reading
it mid-session forces compaction. See "Applying Fixes — Editor Subagent"
below for the dispatch prompt.

Surface the editor's per-fix summaries to the user as a list when it
returns.

### Judgment calls

Present each JUDGMENT CALL issue individually. **First print this block as
plain markdown in the conversation**, leave a blank line, then call
`AskUserQuestion`:

```
**Issue [N]: [Short title]**

[Concrete description, with spec section reference. Cite the methodology
lens, e.g. "Violates Lens 3 — Design Variable Integrity" or
"Violates engineering-preferences.md §4."]

Options:
- **[A]** [Description] — Effort: [low/medium/high], Risk: [low/medium/high],
  Impact: [what this affects], Maintenance: [ongoing burden]
- **[B]** [Description]
- **[C] Do nothing** — [consequences of not addressing this]

**Recommendation: [A/B/C]** — [Why, mapped to the methodology lens or
engineering-preferences.md.]

> Do you agree with option [letter], or would you prefer a different direction?
```

The blank line is **load-bearing** — without it the rendering clips the
last line of the markdown and the user loses the recommendation or
confirmation prompt. Call `AskUserQuestion` with labels A / B / C and
brief trade-offs in the descriptions; the full Effort / Risk / Impact /
Maintenance breakdown lives in the markdown above (the tool fits only a
12-char header and 1–5 word labels).

After each user decision, **dispatch an editor subagent** (see "Applying
Fixes" below). Do not batch judgment-call fixes — one dispatch per
approved issue gives live "Section X updated" feedback and surfaces
wording problems early.

---

## Applying Fixes — Editor Subagent

Same prompt for both batch (unambiguous) and per-fix (judgment-call)
dispatches. Phrase the FIND / REPLACE WITH text yourself, then hand the
editor verbatim strings via `Agent` (subagent_type: `general-purpose`):

````
You are applying one or more approved spec edits. Your job: open the
spec file and apply each edit in order, returning a per-edit summary.

## Inputs

- Spec file: plans/spec-{id}.md
- Edits (apply in order):

EDIT 1:
- Issue: <title>
- Section (for context only): <e.g., "§III.2 — rename pre-flight">
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

EDIT 2: ...

(Repeat for each edit.)

## Workflow

1. Open the spec file with Read once.
2. For each EDIT in order:
   - REPLACE: use Edit with old_string=FIND, new_string=REPLACE WITH.
   - INSERT_AFTER: use Edit with old_string=ANCHOR,
     new_string=ANCHOR + "\n\n" + NEW TEXT.
   - If FIND/ANCHOR is not unique, expand with surrounding context until
     unique, then retry.
   - If FIND/ANCHOR is not found, record the failure and continue with
     the next edit.
3. Return a list of per-edit results:

   "Edit 1 (Issue <title>): Section <name> updated: <one-sentence summary>."
   "Edit 2 (Issue <title>): Edit failed: <reason>."
   ...

Do not paraphrase or improve supplied text. Apply it verbatim.
````

After the subagent returns, surface the per-edit summaries and move on.
If any edit failed, ask the user how to proceed for the failures (re-phrase?
skip?). Do not attempt failed edits in main context as a fallback.

---

## Methodology Lock Rule

After all issues are resolved, the spec is **methodology-locked**:

- Stage 2 does not reopen unless new survey-manipulation semantics are added
  (e.g., a new verb is added to scope, join behavior is specified for a new
  design type, or a value-modifying path is newly introduced)
- Discovering a domain-semantics flaw in Stage 3 or during implementation IS
  worth reopening Stage 2 for — treat it as a new mini-pass on the specific
  section
- API design changes (argument names, return type), test plan additions, and
  documentation changes do not reopen Stage 2

---

## Decisions Log

After all issues are resolved, append a decisions log entry to
`plans/decisions-{id}.md` if ANY judgment call was resolved. If every fix
was unambiguous, skip the log entry.

The log lives at `plans/decisions-{id}.md` and is **append-only**. Create it
with this header only if it does not exist yet:

```markdown
# Decisions Log — surveytidy [id]

This file records planning decisions made during [id].
Each entry corresponds to one planning session.

---
```

Entry format:

```markdown
## [YYYY-MM-DD] — Methodology lock: [component]

### Context

[1–2 sentences: what methodology questions were resolved in this session.]

### Questions & Decisions

**Q: [The question that came up]**
- Options considered:
  - **[Option A]:** [description and trade-offs]
  - **[Option B]:** [description and trade-offs]
- **Decision:** [what was decided]
- **Rationale:** [why]

### Outcome

[1 sentence: what the spec now says as a result of this session]

---
```

---

## After Resolution

1. Update the spec version in the header block (bump the minor version, e.g.
   `1.0` → `1.1`).
2. End the session with:

   > "Methodology locked. {N} issues resolved ({X} unambiguous fixes, {Y}
   > judgment calls). Spec is at version [X.Y]. Start Stage 3 in a new session
   > to run the code/architecture review."
