# Stage 1: Drafting a Spec Sheet

## Before Writing Anything

Use the `AskUserQuestion` tool to gather context before reading or writing
anything:

```
questions:
  - question: "Which package and phase is this spec for?"
    header: "Package / Phase"
    multiSelect: false
    options:
      - label: "surveytidy — Phase 1"
        description: "Estimation functions (means, totals, proportions, etc.)"
      - label: "surveytidy — Phase 2"
        description: "Modelling and regression support"
      - label: "surveycore — next phase"
        description: "surveycore internals or class changes"

  - question: "Is there an existing roadmap or upstream spec to reference?"
    header: "Context docs"
    multiSelect: false
    options:
      - label: "Yes — I'll share the path or paste the content"
        description: "Provide the document before the draft begins."
      - label: "No roadmap exists yet"
        description: "Draft from scratch based on this conversation."

  - question: "Are there upstream phase specs that constrain this one?"
    header: "Upstream specs"
    multiSelect: false
    options:
      - label: "Yes — I'll share them"
        description: "Share before drafting so constraints are captured."
      - label: "No upstream constraints"
        description: "This phase is self-contained."
```

Wait for the user to provide any referenced documents. Read all provided
context before writing a single line of the spec.

---

## Spec Structure

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
| Integration section | Contracts with other packages (surveycore, estimators, etc.) |

---

## Spec Writing Rules

- Every public verb gets a full argument table: name, type, default,
  one-sentence description. Argument order must follow `code-style.md`:
  `.data` first → required NSE → required scalar → optional NSE →
  optional scalar → `...`.
- Every verb gets an explicit output contract: what changes in the returned
  object (@data, @variables, @metadata, @groups).
- Every error condition is listed in a table with: error class, trigger
  condition, and the message template. Class names follow:
  - New errors: `"surveytidy_error_{snake_case}"` or
    `"surveytidy_warning_{snake_case}"`
  - Re-used surveycore errors: `"surveycore_error_{snake_case}"`
- "TBD" and "to be determined" are not allowed — flag as **GAP** with
  `> ⚠️ GAP: [description]` so they're easy to find.
- Domain estimation and grouping behavior must be specified for every verb.
- Do NOT restate rules already defined in `code-style.md`,
  `r-package-conventions.md`, or `surveytidy-conventions.md`. Reference them.

---

## After the Draft

Tell the user:

> "This is a first draft. I expect there are gaps — run Stage 2 in a new
> session to get an adversarial review before we resolve anything."
