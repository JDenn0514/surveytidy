# survey_collection verbs — Design Sketch (surveytidy)

**Status:** Draft concept — not yet scheduled for implementation
**Depends on:** `survey_collection` class and `as_survey_collection()` in
surveycore (shipped in surveycore PR #97, #98, #111, #112, develop branch).

---

## Scope

surveycore already owns:

- `survey_collection` S7 class and validator
- `as_survey_collection()`, `add_survey()`, `remove_survey()`
- `print`, `[[`, `length`, `names` methods
- Dispatch of every `get_*()` analysis function over a collection via
  `.dispatch_over_collection()` — binds per-survey results with a `.id`
  column and carries per-survey metadata under `$per_survey`

**surveytidy's remaining piece:** dplyr/tidyr **verbs** dispatched on
`survey_collection`. Each verb applies the operation to every survey in
the collection independently and returns a new `survey_collection`:

```r
waves |>
  filter(ridageyr >= 18) |>         # filter applied per-survey
  select(health_status, income) |>  # select applied per-survey
  get_freqs(health_status)          # surveycore handles the analysis dispatch
```

The invariant carries over from surveycore: **a collection never combines
or modifies the designs of its members**. Verbs apply element-wise.

---

## Verbs In Scope

Every verb that surveytidy already implements for `survey_base`:

| Category | Verbs |
|---|---|
| Row-marking / filtering | `filter`, `drop_na`, `distinct` |
| Column ops | `select`, `rename`, `mutate`, `transform`, `relocate`, `pull`, `glimpse` |
| Row ops | `arrange`, `slice_head`, `slice_tail`, `slice_min`, `slice_max`, `slice_sample` |
| Grouping | `group_by`, `ungroup`, `group_vars`, `rowwise` |
| Recoding helpers | `recode_values`, `replace_values`, `case_when`, `if_else`, `na_if`, `replace_when` (the survey-aware ones in `R/*.R`) |
| Row stats | `row_means`, `row_sums`, etc. |

Physical subsetting (`subset()`) and joins are deferred — see "Out of scope"
below.

---

## Implementation Pattern

Every `verb.survey_collection` follows the same shape:

```r
filter.survey_collection <- function(.data, ..., .if_missing_var = NULL) {
  .dispatch_verb_over_collection(
    fn = dplyr::filter,
    collection = .data,
    ...,
    .if_missing_var = .if_missing_var
  )
}
```

Per-call `.if_missing_var` defaults to `NULL` and is resolved against
the stored property on the collection inside the dispatcher — mirroring
surveycore's analysis dispatcher
(`surveycore/R/survey-collection.R:696-697`):

```r
resolved_if_missing_var <- .if_missing_var %||% collection@if_missing_var
```

`.dispatch_verb_over_collection()` will live in surveycore (V7) and be
accessed from surveytidy via a `.sc_dispatch_verb_over_collection()`
wrapper in `R/utils.R`. It:

1. Resolves `.if_missing_var` via the precedence rule above
2. Applies `fn(survey, ...)` to each element of `collection@surveys`
3. Catches per-survey errors tagged with `surveycore_error_variable_not_found`
   (or a surveytidy equivalent) and honors the resolved `.if_missing_var`
4. Rebuilds a new `survey_collection` from the per-survey results,
   carrying `@id` and `@if_missing_var` forward unchanged
5. Preserves names and order
6. **Syncs collection-level `@groups`** as the final step: since all
   members share `@groups` by G1, and single-survey verbs that touch
   grouping columns (e.g., `rename.survey_base()` at
   `R/rename.R:131-139`) already update per-survey `@groups`, the
   collection-level sync is trivially
   `coll@groups <- coll@surveys[[1]]@groups`
7. Reuses surveycore's `.propagate_or_match()` helper (via a
   `.sc_*` wrapper) rather than reimplementing the "empty propagates,
   non-empty must match" rule

---

## Relationship to surveycore's Analysis Dispatch

After a chain of verbs, when the pipeline ends in a `get_*()` call,
surveycore's existing `.dispatch_over_collection()` takes over. That
function already handles:

- The `.id` identifier column (resolves `.id %||% collection@id`,
  default property value `".survey"`)
- Collision detection (`surveycore_error_collection_id_collision`)
- `.if_missing_var = "error" | "skip"` for missing variables (resolves
  `.if_missing_var %||% collection@if_missing_var`)
- Per-survey `.meta` under `$per_survey`
- Metadata divergence warnings
  (`surveycore_warning_collection_meta_divergence`)

surveytidy verbs should **not** add a `.id` column themselves. The verb
layer keeps the collection structure intact; the identifier column
appears only when estimation collapses to a data frame. Users who want
to set the column name once-and-for-all do so via the persisted
property — at construction (`as_survey_collection(.id = ...)`) or via
the exported setter `surveycore::set_collection_id()`. surveytidy
re-exports both setters (see "Where It Lives").

**Metadata divergence watch-set is closed by design.**
`.warn_on_meta_divergence()` in surveycore watches exactly three fields
(`value_labels`, `variable_label`, `question_preface`) across `(group, x)`
slots. Metadata-modifying verbs (`rename.survey_collection`,
`select.survey_collection`) can put the collection in a state that
triggers this warning at analysis time — that's expected behavior, not
a verb-layer responsibility. Verb dispatch does not emit divergence
warnings itself.

---

## Resolved Design Decisions (V1–V9)

The six class-level questions from the original sketch were resolved
upstream. V1–V9 below are the surveytidy-specific decisions — all
locked, ready for spec promotion. (V10, about `group_vars()` semantics,
dissolved into V3 once surveycore shipped the uniform `@groups`
invariant.)

### V1: Missing-variable behavior in verbs — **DECIDED**

**Decision:** Error by default; expose per-call `.if_missing_var = "skip"`
on every verb that can meaningfully encounter a missing column. The
default is the **persisted collection property** `coll@if_missing_var`
(set at construction via `as_survey_collection(.if_missing_var = ...)`
or after construction via `set_collection_if_missing_var()`); a non-NULL
per-call argument supersedes.

- `.if_missing_var` per-call signature: `.if_missing_var = NULL`. Inside
  the dispatcher, resolution is
  `.if_missing_var %||% collection@if_missing_var` — exact mirror of
  surveycore's analysis-side dispatch.
- Resolved `"error"`: name every survey that lacks the referenced
  column(s) and abort.
- Resolved `"skip"`: **drop the offending survey from the returned
  collection entirely**. Never partial application; never a no-op that
  produces a heterogeneous-shape collection. If skipping empties the
  collection, V6 takes over.

**Why one-source-of-truth instead of per-call only:** the original
sketch rejected a stored property as "spooky action at a distance,"
but surveycore landed it (PRs #111, #112) and the analysis dispatchers
all read from it. Keeping verbs and analysis functions in lockstep on
this contract is more important than the spooky-action concern, which
is mitigated because (a) the property is rendered by the print method
so it is discoverable, and (b) the per-call argument is always
available as an explicit override.

**Not adopted:** no surveytidy-side caching or shadowing of the property.
Verb dispatch reads `coll@if_missing_var` only at call time and never
mutates it.

### V2: Tidy-select evaluation across heterogeneous schemas — **DECIDED**

**Decision:** Each survey evaluates the tidyselect expression against its
own data; no special interception.

- `where(is.numeric)` is naturally per-survey.
- `all_of()` and bare names hit V1's error path when a column is missing.
- `any_of()` silently drops missing columns per-survey, producing a
  collection whose members may have different column sets. This is legal
  under the class validator; the behavior is documented, not intercepted.

### V3: `@groups` across surveys — **DECIDED**

**Decision:** `@groups` is a collection-level property with a uniform
invariant (surveycore's G1). The group *variable* is guaranteed shared
across members by construction; group *levels* within that variable can
still diverge across waves.

- `survey_collection` has a `@groups` character property
  (`surveycore/R/core-classes.R:685-688`), default `character(0)`.
  Three validator invariants in surveycore:
  - **G1** (equality): every member's `@groups` equals the collection's
    `@groups` — class `surveycore_error_collection_groups_invariant`.
  - **G1b** (column-in-@data): every group column exists in every
    member's `@data` — class
    `surveycore_error_collection_group_not_in_member_data`.
  - **G1c** (well-formed): no NA / empty string / duplicates — class
    `surveycore_error_collection_groups_malformed`.

- `group_by.survey_collection(coll, region)` resolves tidyselect once
  against any member's schema (uniformity permits), propagates to each
  member via single-survey `group_by()`, then sets `coll@groups`.
  Missing `region` in some members → V1.

- `ungroup.survey_collection(coll)` clears per-member `@groups` and
  sets `coll@groups <- character(0)`.

- `group_vars.survey_collection(coll)` is one line: return `coll@groups`.
  (This absorbs what would have been V10 — a separate question about
  query-verb semantics. The uniform invariant dissolves it.)

- Levels within a group variable can still differ across waves (wave A
  has regions 1–4, wave B has 1–3). Analysis functions key on
  `(.survey, region)` and rows unique to wave A simply don't appear in
  wave B's block. **No implicit level completion** — if the user wants
  the full grid, they call `tidyr::complete()` on the analysis output.

- Construction-time grouping is handled by surveycore's
  `as_survey_collection(..., group = ...)` (tidyselect-resolved).
  Members with pre-existing conflicting groups trigger
  `surveycore_warning_collection_group_overridden` (G8).

### V4: `filter()` + per-survey domain columns — **DECIDED**

**Decision:** Let the existing `surveycore_warning_empty_domain` class
fire per-survey. Inject the survey name via `cli` inline rather than
wrapping in a new surveytidy class.

- Class preservation matters: downstream code (in both packages and in
  user pipelines) uses `withCallingHandlers()` keyed on
  `surveycore_warning_empty_domain`. A surveytidy-specific wrapper class
  would break those handlers silently.
- Each survey's `..surveycore_domain..` accumulates independently under
  chained filters. A 3-survey collection where only wave B's filter
  evaluates all-FALSE raises one warning, naming wave B.

### V5: Partial failures during dispatch — **DECIDED**

**Decision:** Fast-fail on the first survey that errors. Re-raise via
`cli_abort(parent = cnd, class = ...)` with the failing survey name in
the message.

- Matches surveycore's existing analysis-dispatch behavior (single
  source of truth for failure semantics across both packages).
- "Collect all errors then raise" is rejected: more complex, masks the
  first useful error under a wall of cascade failures, and in practice
  the second survey's error is usually the same class as the first.

### V6: Result empties the collection — **DECIDED**

**Decision:** Catch the validator's `surveycore_error_collection_empty`
and re-raise as `surveytidy_error_collection_verb_emptied`, naming the
verb and identifying the resolved `.if_missing_var` value that produced
the empty result.

- Error message identifies the verb (`filter`, `select`, …) and calls
  out `.if_missing_var = "skip"` as the trigger so the user can see why
  their collection disappeared.
- The message also reports whether the `"skip"` came from the per-call
  argument or from `coll@if_missing_var`, so users diagnosing a stored
  property surprise see it on the first error.
- Add `surveytidy_error_collection_verb_emptied` to
  `plans/error-messages.md` when the spec lands.

### V7: Shared dispatch helper — surveycore or surveytidy? — **DECIDED**

**Decision:** Option 2 — surveycore owns a second internal helper
`.dispatch_verb_over_collection()` alongside the existing
`.dispatch_over_collection()` (for analysis functions). surveytidy
accesses it through the same `get(".dispatch_verb_over_collection",
envir = asNamespace("surveycore"))` wrapper pattern used for
`.update_design_var_names()` (see `.sc_*` helpers in `R/utils.R`).

- **Rejected Option 1 (duplicate in surveytidy):** divergence risk over
  time; the per-survey iteration, name preservation, and empty-result
  handling should have one implementation.
- **Rejected Option 3 (generalize into one helper):** the return
  semantics differ too much — analysis dispatch binds a data frame with
  a `.id` column and a `$per_survey` meta attachment; verb dispatch
  rebuilds a `survey_collection`. Branching inside a single helper adds
  more indirection than the duplication costs.

**Ordering implication:** V6 and V7 both require a surveycore PR to land
before surveytidy can implement the verbs. The surveycore PR adds
`.dispatch_verb_over_collection()` and must also confirm that
`surveycore_error_collection_empty` is raised by the validator (per the
original sketch it is; verify before depending on it).

**Current upstream state (2026-04-25):** PRs #111 and #112 added the
`@id` and `@if_missing_var` persisted properties and renamed
`.on_missing` → `.if_missing_var` across analysis functions and the
existing analysis-side `.dispatch_over_collection()`. The verb-side
helper is still pending. The verb dispatcher should mirror the analysis
dispatcher's `%||%` precedence pattern at
`surveycore/R/survey-collection.R:696-697` exactly.

### V8: Which verbs, if any, are disallowed on collections? — **DECIDED**

**Governing principle:** `survey_collection` is to surveys what
`dplyr::bind_rows()` is to data frames. Verbs return the type the
equivalent single-survey verb returns — `filter()` → `survey_collection`,
`pull()` → vector, analysis dispatch → `survey_result`. Where a verb's
natural behavior on a single survey escapes the survey abstraction
(e.g., `pull()` returns a vector), the collection verb escapes the
collection abstraction in the analogous way.

**Decision per verb:**

- **Joins (`left_join`, `right_join`, `inner_join`, …):** error. Raise
  `surveytidy_error_collection_verb_unsupported` with `verb = "*_join"`.
  The design space is wide (apply to each survey? broadcast one data
  frame across all? join two collections pairwise by name?) and no
  single answer is obviously right. Defer to a dedicated spec.

- **`pull()`:** **ship.** Returns a combined vector — pull per-survey,
  then combine across surveys. Follows `dplyr::pull()`'s existing API:

  ```r
  pull(coll, health_status)                    # unnamed combined vector
  pull(coll, health_status, name = ".survey")  # each element named by
                                               # its source survey
                                               # (duplicates per-row)
  ```

  Type conflicts across surveys (e.g., `chr` in wave A, `fct` in wave B)
  follow `bind_rows()` coercion rules and raise a standard coercion
  warning. `.if_missing_var` applies per V1.

- **`glimpse()`:** **ship, two modes.**

  - **Default (combined):** `glimpse(coll)` prints a single glimpse of
    the row-bound collection. A `.survey` column is prepended (matching
    analysis dispatch's `.id` default) so the row → source mapping is
    visible. Missing columns are NA-filled. Type conflicts across
    surveys follow `bind_rows()` coercion with the standard warning,
    **and** the glimpse output includes a conflicting-types footer:

    ```
    ! Columns with conflicting types:
      age:    <chr> (2017); <dbl> (2018, 2019, 2020)           → coerced to <chr>
      race_f: <chr> (2017, 2019); <fct> (2018, 2020)           → coerced to <chr>
      party:  <dbl> (2020); <dbl+lbl> (2017, 2018, 2019)       → coerced to <dbl+lbl>
    ```

    The warning and the footer coexist by design: the warning is the
    pipeline signal (caught by `withCallingHandlers()`, uniform across
    all coercion sites — `pull()`, analysis dispatch, etc.); the footer
    is the data-description signal (the user is in "understand this
    object" mode and is actively reading). The footer renders only
    when conflicts exist — no opt-out flag, no opt-in flag.

  - **Per-survey (`.by_survey = TRUE`):** `glimpse(coll, .by_survey =
    TRUE)` prints one glimpse block per element, headed by the survey
    name. The escape hatch when the combined view hides what the user
    needs to see (e.g., inspecting schema evolution across waves).

**Rejected options for the record:**

- Erroring on `pull()` for symmetry with "stay in the collection
  abstraction" — rejected because `pull()` on a single survey already
  exits the survey abstraction; combined vector is the natural
  generalization.
- Erroring on `glimpse()` — rejected for the same reason and because
  schema inspection is a genuine analyst workflow.
- Named-list-of-vectors for `pull()` — rejected as a type break; the
  philosophy requires the vector return type to be preserved.
- Suppressing the coercion warning when the combined glimpse shows a
  footer — rejected because it would make coercion behavior depend on
  which verb triggered it and would break `withCallingHandlers()`
  consumers.

### V9: `distinct()` semantics — **DECIDED**

**Decision:** `distinct.survey_collection()` is **per-survey only**.
Each member deduplicates against its own rows; no cross-survey
deduplication.

A strict reading of the `bind_rows()` philosophy would suggest
cross-survey `distinct()` (rowbind, then dedupe). That is deliberately
rejected here:

- Cross-wave deduplication is not well-defined for survey data. When
  wave A and wave B share what looks like the same row, their weights,
  strata, PSUs, and replicate weights were produced by different
  sampling designs. Silently collapsing them is not a survey-methodology
  operation — there is no correct answer, only plausible-looking ones.
- Analysts who genuinely want cross-wave deduplication must do it
  explicitly: `as_survey(bind_rows(...) |> distinct(...), ...)`, with
  their own choice of design for the combined object. surveytidy does
  not hide that decision.

This is a principled exception to the `bind_rows()` analogy. Every
other data-preserving verb (`filter`, `mutate`, `arrange`, `slice_*`,
etc.) stays strictly within per-survey operation, so per-survey
`distinct()` is consistent with the broader pattern; the cross-survey
reading is the outlier.

Document this behavior prominently in `distinct.survey_collection()`'s
roxygen so users don't assume `bind_rows()` semantics and get silently
different results.

---

## Out of Scope (First Pass)

- `subset.survey_collection` (physical subsetting) — defer until we know
  whether analysts want per-survey subsets; would need its own
  `.if_missing_var`-equivalent decision
- `*_join.survey_collection` — design space is wide; errors for now (V8),
  needs its own spec
- Cross-survey `distinct()` — see V9 for why
- New verbs that don't yet exist for `survey_base`

---

## Where It Lives (updated)

| Component | Package | Status |
|---|---|---|
| `survey_collection` class + validator (G1 / G1b / G1c) | surveycore | ✅ shipped |
| `@groups` property on `survey_collection` | surveycore | ✅ shipped |
| `@id` + `@if_missing_var` persisted properties (PRs #111, #112) | surveycore | ✅ shipped |
| `set_collection_id()` / `set_collection_if_missing_var()` setters | surveycore | ✅ shipped |
| `as_survey_collection(..., group, .id, .if_missing_var)` with G8 override-warning | surveycore | ✅ shipped |
| `add_survey()` (with G4 propagate-or-match), `remove_survey()` | surveycore | ✅ shipped |
| `print`, `[[`, `length`, `names` (no `[[<-` — scrapped) | surveycore | ✅ shipped |
| Print "Groups:" line | surveycore | ✅ shipped |
| `.dispatch_over_collection()` for `get_*()` (with `%||%` precedence) | surveycore | ✅ shipped |
| `.propagate_or_match()` / `.check_groups_match()` helpers | surveycore | ✅ shipped |
| `.dispatch_verb_over_collection()` (V7) | **surveycore** | 🔲 upstream prereq |
| `verb.survey_collection` methods (filter, select, mutate, …) | **surveytidy** | 🔲 this plan |
| `.sc_dispatch_verb_over_collection()` wrapper | **surveytidy** (`R/utils.R`) | 🔲 this plan |
| `.sc_propagate_or_match()` wrapper | **surveytidy** (`R/utils.R`) | 🔲 this plan |
| Re-export `set_collection_id`, `set_collection_if_missing_var`, `as_survey_collection` | **surveytidy** (`R/reexports.R`) | 🔲 this plan |

---

## Next Step

All design questions (V1–V9) are resolved. Promote this sketch to a
spec via `/spec-workflow` Stage 1 when ready. Key inputs for the spec:

1. **surveycore prereq PR:** add internal
   `.dispatch_verb_over_collection()` alongside the existing
   `.dispatch_over_collection()`. Mirror the `%||%` precedence pattern
   at `survey-collection.R:696-697` for `.if_missing_var`. Reuse
   `.propagate_or_match()` and `.check_groups_match()`. (`.id` is not
   relevant to verb dispatch — verbs do not add a `.id` column.)
2. **Re-export the surveycore setters from surveytidy** so users who
   load only surveytidy still get the ergonomic setter API:
   `as_survey_collection`, `set_collection_id`,
   `set_collection_if_missing_var`. Add to `R/reexports.R`. No thin
   wrappers — re-export is sufficient (the surveycore implementations
   are the source of truth for property validation).
3. **Enumerate every verb's dispatch stub** and its expected failure
   modes (which verbs accept `.if_missing_var`; which are pass-through;
   which are disallowed per V8). Per-call signature is
   `.if_missing_var = NULL`; the dispatcher resolves against
   `coll@if_missing_var`.
4. **Cross-design test matrix:** at minimum one collection per test
   combining taylor + replicate + twophase, asserting each verb
   preserves class per member and the uniform `@groups` invariant.
   Add an `if_missing_var = "skip"` axis: assert that a stored
   `coll@if_missing_var = "skip"` produces the same behavior as the
   per-call argument, and that the per-call argument supersedes a
   stored `"error"`.
5. **Error-message additions** to `plans/error-messages.md`:
   - `surveytidy_error_collection_verb_emptied` (V6) — message reports
     the resolved `.if_missing_var` and whether it came from per-call
     or stored property
   - `surveytidy_error_collection_verb_unsupported` (V8 — joins, not
     yet spec'd: specific verb name rendered inline)
6. **Spec out `pull.survey_collection()`** — `name` argument semantics,
   type-coercion warning path, and `.if_missing_var` resolution.
7. **Spec out `glimpse.survey_collection()`** — combined mode (with
   `.survey` column prepended and conflicting-types footer) vs.
   `.by_survey = TRUE` per-survey mode.
8. **Spec out `distinct.survey_collection()`** — per-survey only (V9);
   roxygen must explicitly warn readers that this diverges from the
   `bind_rows()` analogy.
