# Spec: `survey_collection` Verb Dispatch

**Version:** 0.2 (Stage 2 methodology-locked)
**Date:** 2026-04-27
**Status:** METHODOLOGY-LOCKED — pending Stage 3 (spec review)
**Phase:** 0.7 (post–Phase 0.6)
**Branch prefix:** `feature/survey-collection`
**Promoted from:** `plans/future/survey-collection-design.md`

---

## Document Purpose

This is the source of truth for implementing dplyr / tidyr **verb dispatch**
over `survey_collection` objects in surveytidy. surveycore already owns the
class and the analysis-side dispatcher; this spec covers the per-survey
**verb-side** application that returns a new `survey_collection`.

Any decision not found here defers to:

- `.claude/rules/code-style.md`, `r-package-conventions.md`,
  `surveytidy-conventions.md`, `engineering-preferences.md`
- `.claude/rules/testing-standards.md`, `testing-surveytidy.md`
- `plans/future/survey-collection-design.md` (the design sketch)
- surveycore's `survey-collection.R` and its companion CLAUDE notes

---

## I. Scope

### I.1 What This Phase Delivers

| Deliverable | Description |
|---|---|
| `R/collection-dispatch.R` | NEW: `.dispatch_verb_over_collection()` internal helper |
| `R/utils.R` | MODIFIED: thin `.sc_*` wrappers for surveycore internals (`.propagate_or_match`, `.check_groups_match`) |
| `R/<verb>.R` (existing) | MODIFIED: add `verb.survey_collection` method alongside the existing `verb.survey_base` method, in the same file |
| `R/reexports.R` | MODIFIED: re-export surveycore setters (`as_survey_collection`, `set_collection_id`, `set_collection_if_missing_var`) |
| `R/zzz.R` | MODIFIED: register S3 methods for the `surveycore::survey_collection` class string |
| `R/collection-pull-glimpse.R` | NEW: `pull.survey_collection` and `glimpse.survey_collection` (collapsing verbs) |
| `tests/testthat/helper-test-data.R` | MODIFIED: add `make_test_collection(seed)` helper |
| `tests/testthat/test-collection-*.R` | NEW: per-verb collection tests |
| `plans/error-messages.md` | MODIFIED: 4 new error classes, 1 new warning class |
| `DESCRIPTION` | MODIFIED: add `vctrs (>= 0.7.0)` to Imports (used by `pull.survey_collection`'s typed combination via `vctrs::vec_c()`); bump the `surveycore` minimum-version pin to a release that exports every symbol in §VI (per Issue 11 / §XIII.1). |

### I.2 What This Phase Does NOT Deliver

- New surveycore work — the analysis-side `.dispatch_over_collection()`,
  `survey_collection` class, validators, setters, and `as_survey_collection()`
  are already shipped (surveycore PRs #97, #98, #111, #112, #113).
- `subset.survey_collection` (physical subsetting). Deferred — would need its
  own `.if_missing_var`-equivalent decision.
- `*_join.survey_collection` (any join verb). Errors per V8 with
  `surveytidy_error_collection_verb_unsupported`. A future spec may add joins
  with their own contract.
- Cross-survey deduplication in `distinct()`. Per-survey only (V9).
- New verbs that don't yet exist for `survey_base`. The collection layer
  mirrors what `survey_base` already supports.
- Collection-level metadata-divergence warnings — those are owned by
  surveycore's analysis dispatcher (V3 and V8 of the design sketch).

### I.3 Design Support Matrix

Two distinct surveycore-owned invariants govern members:

- **Member type validation** (S7 property type on `@surveys`, enforced
  by the `survey_collection` class definition itself): every element of
  `@surveys` must be a `survey_base` instance. Failures here surface as
  S7 property-type errors, not as `surveycore_error_collection_groups_*`
  classes — they are a separate validation layer from the G1 family.
- **`@groups` consistency** (G1 / G1b / G1c, enforced by the
  `survey_collection` validator): G1 requires every member's `@groups`
  to equal the collection's `@groups`; G1b requires every group column
  to exist in every member's `@data`; G1c requires the group vector to
  be well-formed. None of G1/G1b/G1c speaks to member class type.

Members may be any concrete subclass (`survey_taylor`,
`survey_replicate`, `survey_twophase`), and a single collection may mix
subclasses. Verbs apply per-member, so any per-survey behaviour already
supported by `verb.survey_base` is supported on a collection of that
subclass.

The cross-design test matrix (§IX) asserts every verb works on a collection
mixing all three subclasses.

### I.4 Revision to V7 (from the design sketch)

The design sketch's V7 selected "Option 2 — surveycore owns
`.dispatch_verb_over_collection()`." During Stage 1 verification, the
existing surveycore `.dispatch_over_collection()` (analysis dispatcher) was
inspected: it row-binds per-survey results into a tibble and prepends a
`.id` column. **It cannot be reused for verb dispatch**, which must rebuild
a `survey_collection` from per-survey survey objects.

> **V7 (revised) — DECIDED:** surveytidy owns the verb dispatcher
> `.dispatch_verb_over_collection()` as a private helper in
> `R/collection-dispatch.R`. surveycore is not modified. Mirrors the
> `%||%` precedence pattern at `surveycore/R/survey-collection.R:696-697`.
> Reuses surveycore's `.propagate_or_match()` and `.check_groups_match()`
> via `.sc_*` wrappers in `R/utils.R`.

The original V7 reasoning ("Rejected Option 3: generalize into one helper
… return semantics differ too much") still holds. The change is which
package houses the verb-side helper. There is no behavioural or semantic
divergence from the design sketch; only the file location moves.

---

## II. Architecture

### II.1 File Organization

```
R/
  collection-dispatch.R       # NEW — .dispatch_verb_over_collection()
  collection-pull-glimpse.R   # NEW — pull.survey_collection, glimpse.survey_collection
  arrange.R                   # MODIFIED — add arrange.survey_collection
  distinct.R                  # MODIFIED — add distinct.survey_collection
  drop-na.R                   # MODIFIED — add drop_na.survey_collection
  filter.R                    # MODIFIED — add filter.survey_collection, filter_out.survey_collection
  group-by.R                  # MODIFIED — add group_by/ungroup/group_vars.survey_collection
  joins.R                     # MODIFIED — add stub *_join.survey_collection methods (error)
  mutate.R                    # MODIFIED — add mutate.survey_collection
  rename.R                    # MODIFIED — add rename/rename_with.survey_collection
  rowwise.R                   # MODIFIED — add rowwise.survey_collection
  select.R                    # MODIFIED — add select/relocate.survey_collection
  slice.R                     # MODIFIED — add slice and slice_*.survey_collection
  reexports.R                 # MODIFIED — re-export surveycore setters
  utils.R                     # MODIFIED — add .sc_propagate_or_match, .sc_check_groups_match
  zzz.R                       # MODIFIED — registerS3method() for survey_collection class string
```

No new dispatch files per verb. Each verb lives where its `survey_base`
sibling already lives, matching the pattern set by `survey_result` methods.

### II.2 Dispatch Registration

`survey_collection` is an S7 class living in surveycore; its full class
string is `"surveycore::survey_collection"`. Registration follows the same
pattern as `survey_base`:

```r
# R/zzz.R additions
registerS3method(
  "filter", "surveycore::survey_collection",
  get("filter.survey_collection", envir = ns),
  envir = asNamespace("dplyr")
)
# … one block per verb, mirroring the existing survey_base block.
```

`survey_collection` is not a subclass of `survey_base` — collections wrap
many surveys. Method names (`filter.survey_collection`, etc.) follow the
plain-name convention; functions are not exported.

### II.3 Shared Helpers

#### II.3.1 `.dispatch_verb_over_collection()` (new, internal)

```r
.dispatch_verb_over_collection <- function(
  fn,
  verb_name,
  collection,
  ...,
  .if_missing_var = NULL,
  .detect_missing = "none",
  .may_change_groups = FALSE
) { … }
```

Parameters:

| Name | Type | Default | Description |
|---|---|---|---|
| `fn` | function | (required) | The dplyr/tidyr generic to dispatch (e.g., `dplyr::filter`). When the dispatcher calls `fn(survey, ...)`, S3 routes to the per-member `verb.survey_base` method. |
| `verb_name` | `chr(1)` | (required) | The verb's bound name as a literal string (e.g., `"filter"`). Used for the empty-result error (§VII.3), the skipped-surveys message (step 3), and the re-raise via `surveytidy_error_collection_verb_failed` (step 2). Function objects do not carry their bound name intrinsically; the verb method passes its own name explicitly. |
| `collection` | `survey_collection` | (required) | The collection being transformed. |
| `...` | – | – | NSE-aware forwarding. Carries data-masking and tidyselect arguments unchanged. |
| `.if_missing_var` | `chr(1)` or `NULL` | `NULL` | Per-call override of `collection@if_missing_var`. Resolved via `%||%`. |
| `.detect_missing` | `chr(1)` | `"none"` | One of `"pre_check"` (data-masking verbs), `"class_catch"` (tidyselect verbs), or `"none"` (verbs that reference no user columns — `slice`, `slice_head`/`slice_tail`, `slice_sample` when `weight_by = NULL`, `ungroup`). Selects the missing-variable detection strategy — see step 2. The `"none"` default is the safest no-op: a verb method that forgets to pass an explicit value gets a working dispatcher with no missing-variable detection rather than a silent failure or a `match.arg` surprise. Verb methods that need detection MUST pass `"pre_check"` or `"class_catch"` explicitly per §II.4. |
| `.may_change_groups` | `lgl(1)` | `FALSE` | When `FALSE` (the non-grouping verbs), the dispatcher asserts `identical(out_coll@groups, collection@groups)` after step 5 via `stopifnot()`. The assertion is an internal regression catch, not a user-actionable condition — it should never fire in correct code. Set to `TRUE` only for `group_by`, `ungroup`, `rename`, and `rename_with` — the documented grouping-verb whitelist. See §III.4. |

Behaviour (numbered to match the design sketch's six-step contract):

1. Resolve `resolved_if_missing_var <- .if_missing_var %||% collection@if_missing_var`.

   **Step 1.5 — track override source.** Compute
   `id_from_stored <- is.null(.if_missing_var)` (TRUE when no per-call
   override was supplied and the resolution fell back to the collection's
   stored property; FALSE when the caller passed an explicit
   `.if_missing_var`). Both `resolved_if_missing_var` and `id_from_stored`
   are plumbed into the step-4 empty-result error site (§VII.3) — the
   message branches on `id_from_stored` to tell the user whether the
   resolved value came from their call or from `coll@if_missing_var`.
2. For each `nm` in `names(collection@surveys)`, detect missing-variable
   conditions per the `.detect_missing` mode supplied by the calling verb
   method, then apply `r <- fn(collection@surveys[[nm]], ...)`. Two paths:

   - **Pre-check** (`.detect_missing == "pre_check"`, used by data-masking
     verbs — `filter`, `filter_out`, `mutate`, `arrange`, `group_by`,
     `slice_min`, `slice_max`, `pull`): extract referenced bare names from
     the captured `...` quosures via `all.vars()`, then filter out names
     that resolve in the quosure's enclosing environment (so locally-bound
     constants and helpers pass through). For each remaining name, compare
     it against `names(collection@surveys[[nm]]@data)` BEFORE calling
     `fn(survey, ...)`. If any name is still unresolved, treat as a
     missing-variable condition (synthesize a typed sentinel condition —
     see step 2.1 below — rather than dispatching the verb call).

     The env-filter step is mandatory: bare-name data-masking expressions
     routinely reference enclosing-scope objects (e.g.,
     `filter(coll, age %in% allowed_ages)`), and a naive `all.vars()` check
     would flag every such name as missing. The pre-check must:

     1. Take `quo` from the captured `...`; extract bare names via
        `all.vars(rlang::quo_get_expr(quo))`.
     2. Drop pronoun guards `.data` and `.env`.
     3. Drop names where `exists(name, envir = rlang::quo_get_env(quo), inherits = TRUE)`
        is `TRUE` — these resolve via the data mask's enclosing-env fallback.
     4. The residual is the candidate missing-variable set. A name in that
        set that is also absent from `names(survey@data)` is a true missing
        variable.

     This is necessary because bare-name data-masking verbs surface only as
     a generic `rlang_error` whose parent is
     `simpleError("object 'X' not found")` — there is no distinguishing
     class to pattern-match on at `tryCatch` time.

     **Step 2.1 — sentinel condition format.** When the pre-check detects a
     missing variable, the dispatcher synthesizes a typed condition with
     class `c("surveytidy_pre_check_missing_var", "error", "condition")`
     and fields `$missing_vars` (character — the names that failed both
     env-resolve and `@data` lookup), `$survey_name` (character — `nm`), and
     `$quosure` (the offending quosure for diagnostics). This class is
     internal — not part of the public condition API — but stable for
     `parent`-chain testing (§IX.3) and `expect_error(class = ...)` use.
     The class chain deliberately omits `"rlang_error"` so that
     `inherits(cnd$parent, "rlang_error")` distinguishes the class-catch
     path (where the parent is a real rlang/tidyselect condition) from
     the pre-check path (where the parent is the surveytidy-synthesized
     sentinel).

   - **Class-catch** (`.detect_missing == "class_catch"`, used by
     tidyselect verbs — `select`, `relocate`, `rename`, `rename_with`,
     `drop_na`, `distinct`, `rowwise`): wrap `fn(survey, ...)` in
     `tryCatch()` with handlers keyed on `vctrs_error_subscript_oob` and
     `rlang_error_data_pronoun_not_found`. To recover the `all_of()` wrap
     case (where the user-facing condition is a generic `rlang_error`
     whose `cnd$parent` is `vctrs_error_subscript_oob`), the handler
     walks one level of `cnd$parent` before deciding whether to treat
     the condition as a missing-variable signal. `any_of()` is already
     lenient and never reaches the handler — `.if_missing_var = "skip"`
     is a no-op there, which is documented behaviour.

   - **None** (`.detect_missing == "none"`, used by verbs that reference
     no user columns — `slice`, `slice_head`/`slice_tail`, `slice_sample`
     when `weight_by = NULL`, `ungroup`): skip both pre-check and
     class-catch logic. Call `fn(survey, ...)` directly. Errors from
     `fn` propagate unchanged. `.if_missing_var` is irrelevant — these
     verbs do not advertise it in their signatures (per §II.4), so the
     dispatcher is invoked with `.if_missing_var = NULL` and the
     resolution at step 1 is inert.

   In both paths, when a missing-variable condition is detected:
   - If `resolved_if_missing_var == "skip"`: append `nm` to `skipped`,
     set `r <- NULL`.
   - If `resolved_if_missing_var == "error"`: re-raise via
     `cli::cli_abort(parent = cnd, class = "surveytidy_error_collection_verb_failed")`,
     naming the failing survey. (For the pre-check path, `cnd` is the
     internal sentinel synthesized by the dispatcher; for the class-catch
     path, `cnd` is the original tidyselect/rlang condition.)

   Other errors raised by `fn(survey, ...)` (S7 validator failures,
   surveycore errors, unrelated rlang failures) are not caught — they
   propagate unchanged. Pure broad-catching on `rlang_error` would
   swallow these and defeat `.if_missing_var = "skip"`; see D1.
3. Drop `NULL` results from `results`. If `length(skipped) > 0`, emit a
   message via `cli::cli_inform()` with class
   `surveytidy_message_collection_skipped_surveys` (mirrors the
   `surveycore_message_collection_skipped_surveys` shape from the
   analysis dispatcher).
4. If `length(results) == 0L`, raise `surveytidy_error_collection_verb_emptied`
   (V6) reporting the verb name (`verb_name` parameter) and the
   resolved `.if_missing_var` source (per-call vs stored). This is a
   proactive check: the dispatcher never lets an empty `@surveys` list
   reach the surveycore class validator (which would also reject it via
   `surveycore_error_collection_empty`, but with a less diagnostic
   message). The validator class is documented as a safety net only —
   see §VII.2.
5. Build `out_coll` via the surveycore constructor:

   ```r
   out_coll <- surveycore::as_survey_collection(
     !!!results,
     .id = collection@id,
     .if_missing_var = collection@if_missing_var
   )
   ```

   The constructor re-derives `@groups` from the members (every
   member's `@groups` already matches by G1 because per-member methods
   update `@groups` synchronously), runs the S7 validator once on a
   fully consistent state, and preserves the original `names(@surveys)`
   order minus skipped. This is the only sanctioned construction path —
   the dispatcher does not perform raw `@<-` writes on `out_coll`,
   does not clone-and-update, and does not bypass the validator via
   `attr()`. Rationale: surveycore owns the `survey_collection` class
   contract; surveytidy goes through the documented constructor so
   any future invariant change in surveycore is picked up
   automatically without touching the dispatcher.

   When `.may_change_groups == FALSE` (the default — every non-grouping
   verb), assert via `stopifnot(identical(out_coll@groups, collection@groups))`
   after construction. This is an internal regression catch, not a typed
   condition — it should never fire in correct code, so it does not
   warrant entry in the public error-messages registry. The failure
   mode it guards against is: a per-member call clears or rewrites
   `@groups` synchronously across all members (so G1 still holds) but
   the collection's documented non-grouping-verb invariance contract
   is broken — Phase 1 estimation downstream would otherwise run with
   corrupted grouping. If `stopifnot()` triggers, the resulting
   `simpleError` surfaces the assertion text directly; tests that need
   to assert the regression catch fires can use
   `expect_error(class = "simpleError")`. The grouping-verb whitelist
   (`group_by`, `ungroup`, `rename`, `rename_with`) sets
   `.may_change_groups = TRUE` and skips this assertion.
6. Return `out_coll`.

The dispatcher is **not** responsible for:

- Joining results into a tibble — that's the analysis dispatcher's job.
- Adding a `.id` column — verbs preserve the collection structure.
- Detecting metadata divergence — that fires only at analysis time.

#### II.3.2 `.sc_propagate_or_match()` and `.sc_check_groups_match()`

Mirror the existing `.sc_*` wrapper pattern in `R/utils.R` for
`.update_design_var_names()` and `.rename_metadata_keys()`:

```r
.sc_propagate_or_match <- function(...) {
  get(".propagate_or_match", envir = asNamespace("surveycore"))(...)
}
.sc_check_groups_match <- function(...) {
  get(".check_groups_match", envir = asNamespace("surveycore"))(...)
}
```

These are used by `group_by.survey_collection()` (and only by it —
collection-level G1 enforcement is otherwise carried by surveycore's
class validator on every assignment).

#### II.3.3 `.derive_member_seed()` (new, internal)

Used by `slice_sample.survey_collection` to produce a stable per-survey
integer seed from a survey name and a user-provided `seed`:

```r
.derive_member_seed <- function(survey_name, seed) {
  hex <- rlang::hash(paste0(survey_name, "::", seed))
  strtoi(substr(hex, 1, 7), 16L)
}
```

Returns an integer in `[0, 2^28)`. `rlang` is already an Imports
dependency; no new package required.

### II.4 Verb Coverage Matrix

Every verb that currently has a `verb.survey_base` method gets a
`verb.survey_collection` method, except where noted.

| Verb | Collection method | `.if_missing_var` arg | Detection mode | Notes |
|---|---|---|---|---|
| `filter` | yes | yes | pre-check | empty-domain warning fires per-survey (V4) |
| `filter_out` | yes | yes | pre-check | mirrors filter |
| `drop_na` | yes | yes | class-catch | tidyselect for column args; raises `vctrs_error_subscript_oob` |
| `distinct` | yes | yes | class-catch | per-survey only (V9) — see §V.5 |
| `select` | yes | yes | class-catch | tidyselect evaluated per-survey (V2) |
| `rename` | yes | yes | class-catch | per-survey rename; G1 still holds afterward (group cols renamed in lockstep) |
| `rename_with` | yes | yes | class-catch | mirrors rename |
| `mutate` | yes | yes | pre-check | data-masking per-survey |
| `relocate` | yes | yes | class-catch | tidyselect per-survey |
| `arrange` | yes | yes | pre-check | data-masking per-survey |
| `slice` | yes | **no** | none | row-index per-survey; no column refs. `.if_missing_var` would be inert, so it is omitted from the signature. |
| `slice_head` / `slice_tail` | yes | **no** | none | row-index per-survey; no column refs. `.if_missing_var` omitted (would be inert). |
| `slice_min` / `slice_max` | yes | yes | pre-check | references a data-mask `order_by` column |
| `slice_sample` | yes | conditional | conditional | When `weight_by` is set: detection mode is `"pre_check"` and `.if_missing_var` is in the signature. When `weight_by = NULL`: detection mode is `"none"` and `.if_missing_var` is omitted. Per-survey seeding via `seed` arg — see §IV.6 and D2. |
| `group_by` | yes | yes | pre-check | sets `@groups` on collection AND every member (G1) |
| `ungroup` | yes | n/a | none | clears `@groups` on collection AND every member |
| `group_vars` | yes | n/a | n/a (no dispatch) | one-liner: returns `coll@groups` directly without invoking the dispatcher |
| `rowwise` | yes | yes | class-catch | applied per-member; `...` is tidyselect |
| `pull` | yes | yes | class-catch | `var` is `<tidy-select>` (resolved via `tidyselect::eval_select()` — class-catch on `vctrs_error_subscript_oob` / `rlang_error_data_pronoun_not_found` to avoid false positives on tidyselect helpers like `last_col()` or `where()`). `name = "<column>"` is a string subscript (class-catch on `vctrs_error_subscript_oob`). Both honor `.if_missing_var`. Collapses to a vector — see §V.1 |
| `glimpse` | yes | n/a | n/a (no dispatch) | side-effecting; custom collapsing logic; does not invoke the dispatcher. See §V.5 |
| `subset` | **no** | n/a | n/a | out of scope (deferred) |
| `*_join` | **error** | n/a | n/a | raises `surveytidy_error_collection_verb_unsupported` (V8) |

---

## III. Standard Verb Pattern

### III.1 Method Body Template

Almost every verb follows this exact shape. Differences are which
arguments are forwarded explicitly and whether the verb takes
`.if_missing_var`.

```r
#' @rdname filter
#' @method filter survey_collection
filter.survey_collection <- function(
  .data,
  ...,
  .by = NULL,
  .preserve = FALSE,
  .if_missing_var = NULL
) {
  if (!is.null(.by)) {
    cli::cli_abort(
      c(
        "x" = "{.arg .by} is not supported on {.cls survey_collection}.",
        "i" = "Per-call grouping overrides do not compose cleanly with {.code coll@groups}.",
        "v" = "Use {.fn group_by} on the collection (or set {.code coll@groups}) instead."
      ),
      class = "surveytidy_error_collection_by_unsupported"
    )
  }
  .dispatch_verb_over_collection(
    fn = dplyr::filter,
    verb_name = "filter",
    collection = .data,
    ...,
    .preserve = .preserve,
    .if_missing_var = .if_missing_var,
    .detect_missing = "pre_check",
    .may_change_groups = FALSE
  )
}
```

The dispatcher applies `dplyr::filter(survey, ...)` to each member; that
call S3-dispatches to `filter.survey_base`, which does the actual work.
`.detect_missing = "pre_check"` selects the data-masking detection
strategy (see §II.3.1 step 2); tidyselect verbs pass `"class_catch"`.
`.may_change_groups = FALSE` enables the post-dispatch groups
invariance assertion (see §II.3.1 step 5); only `group_by`, `ungroup`,
`rename`, and `rename_with` set this to `TRUE`.
Each verb method passes its bound name as a literal `verb_name` string
so error and message templates can name the verb without heuristics.

**Shared `.by` rejection contract.** Every collection verb whose
`survey_base` sibling accepts a `.by` (or `by`) argument rejects it at
the collection layer with `surveytidy_error_collection_by_unsupported`,
using the same `cli::cli_abort()` template shown above (the message
substitutes the verb's argument name — `.by` for `filter`, `mutate`,
and `summarise`; `by` for `slice_min`, `slice_max`, `slice_sample`).
Affected verbs: `filter`, `filter_out`, `mutate`, `slice_min`,
`slice_max`, `slice_sample`. Per-call grouping does not compose with
`coll@groups`'s collection-aware semantics; users who want grouping
must set it on the collection. Symmetric with how `filter.survey_base`
rejects `.by` (per surveycore). The rejection runs before dispatch and
short-circuits any missing-variable detection.

### III.2 Per-Verb Argument Tables

Each verb method's argument table follows its `survey_base` sibling exactly,
plus `.if_missing_var = NULL` at the end of optional scalars.

For verbs already specced in earlier phases (filter, select, mutate,
rename, arrange, slice_min, slice_max, group_by, ungroup, drop_na,
distinct, relocate, rowwise, group_vars, rename_with, filter_out), the
collection method inherits the per-survey argument table and adds **one**
new argument:

| Argument | Type | Default | Description |
|---|---|---|---|
| `.if_missing_var` | `chr(1)` or `NULL` | `NULL` | Per-call override of `collection@if_missing_var`. `"error"` aborts when any member is missing a referenced variable; `"skip"` drops missing-variable members from the result. `NULL` resolves to `collection@if_missing_var` via `%||%`. |

**Exception — verbs that reference no user columns:** `slice`,
`slice_head`, `slice_tail`, and `slice_sample` (when `weight_by = NULL`)
take row indices or counts only. They cannot raise a missing-variable
condition, so `.if_missing_var` would be inert and is omitted from
those signatures rather than advertised as a no-op. `slice_sample`'s
signature includes `.if_missing_var` only when `weight_by` is non-NULL
(see §IV.6). This follows `engineering-preferences.md`'s rule against
parameters that don't do anything.

Each per-verb roxygen block (for verbs that DO take `.if_missing_var`)
includes one shared description fragment (documented in §VIII).

### III.3 Output Contract (every standard verb)

The returned `survey_collection` satisfies:

| Property | Value |
|---|---|
| `@surveys` | Per-survey verb result, in original order, minus skipped surveys |
| `@id` | Identical to input `collection@id` |
| `@if_missing_var` | Identical to input `collection@if_missing_var` |
| `@groups` | Identical to `out@surveys[[1]]@groups` (G1) |

Nothing else changes at the collection level. Per-member changes are
exactly what `verb.survey_base` would produce in standalone use.

**Domain column preservation.** For every standard verb except `filter`,
`filter_out`, and `drop_na` (which create or update the domain column
per V4), the per-member domain column (`surveycore::SURVEYCORE_DOMAIN_COL`,
when present on the input member) is preserved on every member that
survives `.if_missing_var = "skip"`. This is a transitive consequence
of per-member dispatch — `select.survey_base`, `mutate.survey_base`,
`arrange.survey_base`, `rename.survey_base`, etc. each preserve the
domain column individually — and is stated here explicitly because the
collection layer relies on it for V4 to compose correctly with the rest
of the verb suite.

### III.4 Group-Affecting Verbs

`group_by`, `ungroup`, and `rename` (when renaming a group column) require
synchronized updates to `@groups` on every member AND on the collection
itself. The dispatcher's step 5 sync is sufficient for `group_by` and
`ungroup` because each `survey_base` method updates its own `@groups`
before returning. For `rename`, the `survey_base` method already updates
its `@groups` if a renamed column was a group column (see existing
`rename.survey_base`). The dispatcher pulls the post-rename `@groups`
from `results[[1]]` and lifts it to `out_coll@groups`.

This is safe because G1 guarantees every member's `@groups` is identical;
reading from any member is sufficient. Reading from `results[[1]]` is the
documented choice; the spec asserts equivalence in tests (§IX.4).

---

## IV. Standard Verb Specs (per verb)

### IV.1 `filter.survey_collection` and `filter_out.survey_collection`

**Signature:** see §III.1.

**Behavior:** Each member's domain column is updated independently per V4.
The empty-domain warning (`surveycore_warning_empty_domain`) fires
per-survey from the underlying `filter.survey_base` call; the dispatcher
does not interpose. Surveys whose post-filter domain is all-FALSE remain
in the collection (with an empty domain) — the design's V4 decision is
that domain emptiness is a per-survey signal, not a collection-level
skip trigger.

`.by` is rejected at the collection layer with
`surveytidy_error_collection_by_unsupported` (the new shared
collection-scoped class — see §III.1's "Shared `.by` rejection
contract" and §VII.1). The per-survey `filter.survey_base` continues
to use the original `surveycore_error_filter_by_unsupported`.

`.if_missing_var` controls behavior when a referenced column is missing
from a member's data (see D1).

Detection mode: pre-check (data-masking).

### IV.2 `drop_na.survey_collection`

Mirrors `filter` in shape. Per-member empty-domain warnings still fire.
`.if_missing_var` applies when a tidyselect-named column is absent.

Detection mode: class-catch (tidyselect). `drop_na(d, missing_col)`
raises `vctrs_error_subscript_oob`, which the dispatcher's class-catch
handler converts to the missing-variable signal.

### IV.3 `select.survey_collection` / `relocate.survey_collection`

Per V2: each member evaluates its tidyselect against its own data.
- `where(is.numeric)` evaluated per-survey.
- `all_of()` and bare names → V1 path on missing.
- `any_of()` silently drops missing per-survey.

Result: a collection whose members may have different visible columns.
This is class-legal (the validator does not require column uniformity);
analysis-time metadata-divergence warnings (G3) catch problematic cases
later.

**Pre-flight for group columns (`select` only).** Before dispatching,
`select.survey_collection` resolves the user's tidyselect against the
first member's data (V2 permits per-member resolution; the first
member's resolution is sufficient to check whether the user's intent
excludes any group column) and raises
`surveytidy_error_collection_select_group_removed` BEFORE touching any
member if any column in `coll@groups` would be removed. The error names
the verb and the offending group column.

Without this pre-flight, the per-member dispatch removes the group
column from every member's `@data`, then the surveycore class validator
G1b (`surveycore_error_collection_group_not_in_member_data`) fires on
the rebuilt collection — accurate but misleading: the cause is the
`select(-group_col)` expression, not the rebuilt member. Mirrors D3's
group-rename pre-flight: the post-select G1b invariant is structurally
unrecoverable (silently dropping the column from `coll@groups` would
silently drop the user's grouping; allowing it through violates G1b).

**`relocate` is NOT subject to the group-removal pre-flight.**
`dplyr::relocate` only reorders columns — it cannot drop them.
Negative tidyselect selectors (`relocate(d, -cyl, .before = wt)`)
still preserve the negated column in the output; they only affect
where the column lands. This was verified against
`dplyr::relocate(mtcars, -cyl)` — the column is reordered, not
removed. `relocate.survey_collection` therefore dispatches directly
to per-member with class-catch detection only; no group-removal check
is needed.

Detection mode: class-catch (tidyselect). `select` adds a verb-layer
pre-flight for group-column safety; `relocate` does not.

### IV.4 `rename.survey_collection` / `rename_with.survey_collection`

Per-member rename. If the renamed column is in `@groups`, every member
updates `@groups` consistently because G1 implies every member has the
same group columns. The dispatcher pulls the post-rename `@groups` to
the collection level (§III.4).

**Pre-flight for group columns (D3 resolution):** Before dispatching,
`rename.survey_collection` and `rename_with.survey_collection` check
whether any `old_name` in the rename map is in `coll@groups`. For each
such `old_name`, every member must contain the column — otherwise the
rename would leave the collection with a half-renamed `@groups`
invariant that no `.if_missing_var` policy can recover (skipping the
offending member would silently drop the user's grouping; allowing it
through would violate G1). When the check fails, the verb raises
`surveytidy_error_collection_rename_group_partial` BEFORE touching any
member, naming the offending column and the members lacking it.

**Reachability note.** The pre-flight is structured identically for
both verbs but its load-bearingness differs:

- For plain `rename`, the rename map is identical across members
  (it's the user's bare-name `new = old` mapping). If
  `old_name ∈ coll@groups`, G1b already guarantees `old_name` exists in
  every member's `@data`, so the "members lacking it" branch cannot
  fire under correct construction. The check is structurally redundant
  for `rename` but kept as defense-in-depth at trivial cost — it
  catches a regression in surveycore's G1b enforcement and surfaces a
  diagnostic message naming the verb rather than letting an internal
  validator failure bubble up.
- For `rename_with`, the rename map is computed per-member (`.cols`
  is tidyselect-resolved against each member's columns; `.fn` is then
  applied to the resolved names). A `.cols = where(is.factor)` could
  resolve to `psu` in member A (factor-typed) and not in member B
  (numeric). If `psu ∈ coll@groups`, the rename map includes
  `psu → new` for A but not B — exactly the partial-rename scenario
  the pre-flight is designed to catch. The check is genuinely
  reachable here and is the primary justification for the class.

A future contributor who reads the plain-`rename` branch and sees it
"can never fire given G1b" should NOT remove or short-circuit it: the
shared structure is intentional, and the cost (one set membership and
one column-existence loop per group column per rename call) is
negligible.

**Non-group column rename:** Standard `.if_missing_var` behaviour
applies. Members lacking the `old_name` either skip (under `"skip"`) or
trigger `surveytidy_error_collection_verb_failed` (under `"error"`),
per the dispatcher's class-catch path on `vctrs_error_subscript_oob`.

`rename_with` follows the same contract. Its pre-flight resolves the
`.cols` tidyselect against each member, applies `.fn` to the resolved
names to compute the rename map, and runs the same group-column
coverage check. (The check is per-member because `.cols` may select
different columns in different members.)

Detection mode: class-catch (tidyselect), with a verb-layer pre-flight
for group-column safety.

**Per-member warning multiplicity.** Renaming a non-group design
variable (weights, ids, strata, fpc) on an N-member collection emits
`surveytidy_warning_rename_design_var` N times — once per member.
This is the documented per-member dispatch contract (symmetric with
V4's per-member `surveycore_warning_empty_domain` for filter/drop_na):
each member's `rename.survey_base` raises its own typed condition, and
the dispatcher does not interpose. `withCallingHandlers()` consumers
should expect N firings on an N-member collection. The roxygen
`@section Survey collections:` block calls this out explicitly.

### IV.5 `mutate.survey_collection`

Per-member mutate. Surveytidy's recoding helpers (`case_when`, `if_else`,
`recode_values`, etc.) and row-stat helpers (`row_means`, `row_sums`,
etc.) are vector-level, so they "just work" inside a collection-level
mutate without any additional collection methods.

`mutate` honors `.if_missing_var` — when a referenced column is absent in
a member, that member is either skipped or errors.

`.by` is rejected at the collection layer with
`surveytidy_error_collection_by_unsupported` per §III.1's shared
contract. Per-call grouping does not compose with `coll@groups`; users
who want grouped mutate must set it on the collection.

**Per-member warning multiplicity.** Mutating a weight column (or any
column that triggers `surveytidy_warning_mutate_weight_col` in
`mutate.survey_base`) emits the warning N times on an N-member
collection — once per member. Same per-member dispatch contract as
§IV.4's note on `surveytidy_warning_rename_design_var`. The roxygen
`@section Survey collections:` block documents this explicitly.

**Rowwise mixed-state pre-check.** `mutate.survey_base` reads
`@variables$rowwise` per member to decide between rowwise and
column-vector evaluation semantics. On a mixed-rowwise collection —
where `is_rowwise()` is not uniform across `coll@surveys` — a single
collection-level `mutate()` call will produce different evaluation
semantics on different members, which is almost always a bug. Before
dispatching, `mutate.survey_collection` computes
`vapply(coll@surveys, is_rowwise, logical(1))`; if the values are not
all-`TRUE` or all-`FALSE`, it emits
`surveytidy_warning_collection_rowwise_mixed` once and then dispatches
normally. The warning names the offending members. Per-member
dispatch is not blocked — the warning is diagnostic, not fatal — so
that users who deliberately constructed a mixed collection can
suppress the class via `withCallingHandlers()` and proceed. This is
the soft uniformity invariant referenced in §IV.10; it does not exist
as a class-validator check because the rowwise key is owned by
surveytidy, not surveycore. The check is the only collection-layer
consumer of rowwise state — every other verb is rowwise-agnostic.

Detection mode: pre-check (data-masking).

### IV.6 `arrange.survey_collection`, `slice.survey_collection`, `slice_*`

Per-member operation. Each member arranges or slices independently.
`slice_sample` seeds per-survey (D2 — Stage 4 to confirm whether
per-survey seeds should derive deterministically from a single user-
provided seed for reproducibility).

`by` is rejected at the collection layer for `slice_min`, `slice_max`,
and `slice_sample` with `surveytidy_error_collection_by_unsupported`
per §III.1's shared contract. `slice`, `slice_head`, and `slice_tail`
do not advertise `by`. Per-call grouping does not compose with
`coll@groups`.

Each `slice_*.survey_base` call emits `surveycore_warning_physical_subset`
per member; the dispatcher does not interpose. The class is preserved
so `withCallingHandlers()` consumers see the same signal as for a
single-survey slice. Mirrors V4's per-member treatment of
`surveycore_warning_empty_domain` for filter/drop_na.

**Pre-flight for empty-result slice arguments.** Before dispatching,
each slice verb's collection method checks whether the supplied slice
arguments would produce a 0-row result on every member, and raises
`surveytidy_error_collection_slice_zero` BEFORE touching any member.
The check is verb-specific:

- `slice.survey_collection`: when the integer index `...` evaluates to
  `integer(0)` (or all positions are negative selectors that exclude
  every row). **Evaluation context:** `slice()` accepts NSE (literal
  indices like `1:5`, but also data-mask references like `n()` or
  `which(x > 0)`). The pre-flight evaluates `...` in an empty
  environment via `tryCatch(eval_tidy(quo, data = NULL))`. If the
  result is an integer vector and equals `integer(0)`, raise the
  pre-flight error. If evaluation fails (NSE references a column or
  helper like `n()`), silently skip the pre-flight — the per-member
  call evaluates the expression against each member's `@data` and any
  empty-result fallout flows through the surveycore validator. This
  matches how the dispatcher treats data-mask expressions in pre-check
  step 2: literal failures are caught up front; mask-resolved failures
  defer to per-member.
- `slice_head.survey_collection` / `slice_tail.survey_collection`:
  when `n == 0` and `prop` is unset (or `prop == 0`).
- `slice_sample.survey_collection`: when `n == 0` and `prop` is unset
  (or `prop == 0`).
- `slice_min.survey_collection` / `slice_max.survey_collection`: when
  `n == 0` and `prop` is unset (or `prop == 0`). The `order_by`
  expression itself is not pre-evaluated — only the `n`/`prop`
  arguments are inspected, since they fully determine whether the
  result is empty.

Without this pre-flight, the dispatcher applies the slice per-member,
each member's `@data` becomes 0-row, and the surveycore class
validator on the first rebuilt `survey_base` member errors — surfacing
a misleading "single member is invalid" message rather than identifying
the slice argument as the cause. The pre-flight is symmetric with D3's
"intercept at the collection layer when the consequences are
structurally unrecoverable" pattern.

The pre-flight does not run on `slice_*` arguments that COULD produce
a 0-row member only for some members (e.g., `slice_head(n = 100)` on a
mix of 50-row and 200-row surveys). Per-member 0-row results from
otherwise valid arguments are still rejected by the surveycore
validator at member rebuild time — this is consistent with the
per-survey verb's contract and outside the collection layer's
responsibility.

Detection modes: `arrange` is pre-check (data-masking on the sort
expressions). `slice_min` / `slice_max` are pre-check (their `order_by`
is data-mask). `slice`, `slice_head`, `slice_tail`, `slice_sample` are
n/a — they reference no user columns.

#### `slice_sample.survey_collection` reproducibility

`slice_sample.survey_collection` adds a `seed = NULL` argument absent from
`slice_sample.survey_base`. This controls how RNG state is managed across
per-survey sampling.

| `seed` value | Behaviour |
|---|---|
| `NULL` (default) | No seed manipulation. Per-survey `slice_sample()` calls draw from the ambient RNG state in iteration order. Reproducibility requires a single upstream `set.seed()` AND a stable collection size and member order — adding or removing a survey changes the samples drawn from every subsequent survey. |
| integer | Each per-survey call is wrapped with a deterministic per-survey seed derived as `strtoi(substr(rlang::hash(paste0(survey_name, "::", seed)), 1, 7), 16L)`. Per-survey samples are stable regardless of collection order, additions, or removals. The ambient `.Random.seed` is restored on exit (via base `on.exit()` — no `withr` dependency). |

The `seed = NULL` default preserves the ambient-RNG behaviour users get
from a piped `slice_sample()` call without thinking about reproducibility,
and avoids silently changing semantics for existing pipelines. The roxygen
documentation strongly recommends passing an explicit `seed` for any
analysis intended to be reproducible.

When `weight_by` is set (a data-mask column reference), the dispatcher
runs in pre-check mode for that one argument; otherwise detection is n/a
because `slice_sample` does not reference user columns. The verb method
sets `.detect_missing` accordingly.

### IV.7 `group_by.survey_collection`

```r
group_by.survey_collection <- function(
  .data,
  ...,
  .add = FALSE,
  .drop = TRUE,
  .if_missing_var = NULL
) { … }
```

Behaviour:

1. Resolve `.if_missing_var`.
2. Use the dispatcher to apply `dplyr::group_by(survey, ..., .add = .add, .drop = .drop)` to each member.
3. The dispatcher's step-5 sync lifts `results[[1]]@groups` to the
   collection's `@groups`.
4. Class validator (G1, G1b, G1c) on the rebuilt collection enforces:
   - All members' `@groups` are identical (G1).
   - Every group column exists in every member's `@data` (G1b).
   - Group vector is well-formed (G1c).

If a group column exists in some members but not others, `.if_missing_var`
governs (members missing the column are either skipped or trigger an
error). G1b would fail if a member without the group column survives —
the validator catches this and raises
`surveycore_error_collection_group_not_in_member_data`.

Detection mode: pre-check (data-masking — `group_by()` accepts bare
names that resolve via the data mask).

### IV.8 `ungroup.survey_collection`

Per-member `ungroup()`. The dispatcher's step-5 sync sets
`out@groups <- character(0)` because every member's `@groups` is now
empty.

Detection mode: n/a — `ungroup()` references no user columns.

### IV.9 `group_vars.survey_collection`

```r
group_vars.survey_collection <- function(x) {
  x@groups
}
```

One-liner — does not use the dispatcher. Documented under V3.

Detection mode: n/a — no column references.

### IV.10 `rowwise.survey_collection`

Per-member `rowwise()`. The dispatcher pattern applies. Rowwise state
lives entirely per-member: `rowwise.survey_base` writes
`@variables$rowwise` and `@variables$rowwise_id_cols` and leaves
`@data`, `@groups`, and `@metadata` unchanged (see `R/rowwise.R`). The
collection layer has no rowwise marker — there is no `coll@rowwise`
property and no aggregated rowwise state on the collection. Because
`@groups` is invariant under per-member rowwise, the dispatcher is
called with `.may_change_groups = FALSE` (the default), and
`rowwise.survey_collection` is correctly excluded from the
grouping-verb whitelist in §III.4.

Detection mode: class-catch (tidyselect — `rowwise()`'s `...` is
tidyselect over column names).

#### Soft uniformity invariant

`rowwise.survey_collection` produces uniform rowwise state by
construction (every member is rowwise after the call). Mixed-state
collections — where some members are rowwise and others are not — are
not enforceable at the surveycore class validator without leaking a
surveytidy concept (`@variables$rowwise`) into a class surveycore
owns. Construction-time enforcement would also require either an
`@rowwise` property on `survey_collection` (duplicate state on top of
the per-member key) or a back-pointer from members to their
collection (does not exist). For these reasons, uniformity is treated
as a soft invariant rather than a hard one: rowwise mixed state is
allowed to exist on a `survey_collection`, but is detected and warned
about by `mutate.survey_collection` at dispatch time (see §IV.5). The
predicate `is_rowwise.survey_collection` (below) returns `FALSE` on a
mixed collection, which is the diagnostic users should consult.

#### `is_rowwise.survey_collection`

Mirrors `group_vars.survey_collection` (§IV.9) — a one-liner that does
not invoke the dispatcher:

```r
is_rowwise.survey_collection <- function(x) {
  length(x@surveys) > 0L &&
    all(vapply(x@surveys, is_rowwise, logical(1)))
}
```

Returns `TRUE` iff every member is rowwise. Empty collections return
`FALSE` (cannot occur in practice — surveycore's class validator rejects
empty `@surveys`). Because the `rowwise.survey_collection` dispatcher
calls `rowwise.survey_base` uniformly across members, this "all or
nothing" invariant always holds in practice; the predicate is a
diagnostic for users who construct collections from members with mixed
prior rowwise state. Registered in `R/zzz.R` alongside the other S3
methods. Test row in §IX.4.

### IV.11 `distinct.survey_collection`

Per V9: per-survey only. No cross-survey deduplication.

```r
distinct.survey_collection <- function(
  .data,
  ...,
  .keep_all = FALSE,
  .if_missing_var = NULL
) {
  .dispatch_verb_over_collection(
    fn = dplyr::distinct,
    verb_name = "distinct",
    collection = .data,
    ...,
    .keep_all = .keep_all,
    .if_missing_var = .if_missing_var,
    .detect_missing = "class_catch",
    .may_change_groups = FALSE
  )
}
```

The roxygen for this method explicitly documents the V9 divergence from
the `bind_rows()` analogy. A test asserts that, when two members share a
literally identical row, the row appears in both members' results
post-`distinct()` (no cross-survey collapse).

Detection mode: class-catch (tidyselect).

---

## V. Collapsing Verbs

These verbs do not return a `survey_collection`. They follow V8: the
collection-level verb escapes the collection abstraction in the same way
the per-survey verb escapes the survey abstraction.

### V.1 `pull.survey_collection`

```r
pull.survey_collection <- function(
  .data,
  var = -1,
  name = NULL,
  ...,
  .if_missing_var = NULL
) { … }
```

**Behaviour:**

1. Resolve `.if_missing_var`.
2. For each member, apply `dplyr::pull(survey, {{ var }}, name = {{ name }})`,
   collecting per-survey vectors. Missing-variable handling per V1.
   `pull` uses **class-catch only** — both column-reference arguments
   (`var` and `name`) flow through a single `tryCatch` handler around
   the per-member `dplyr::pull` call:

   - **`var` (class-catch).** `var` is documented `<tidy-select>` and
     resolved internally by `tidyselect::eval_select()`. A pre-check via
     env-aware `all.vars()` would misclassify tidyselect helpers
     (`last_col()`, `where(is.numeric)`, etc.) as missing variables
     because their names appear in `all.vars()` but resolve through
     tidyselect, not the data mask. Missing-column failures surface as
     `vctrs_error_subscript_oob` or `rlang_error_data_pronoun_not_found`
     and are caught by the same handler as the dispatcher's class-catch
     path in §II.3.1 step 2.
   - **`name` (class-catch).** When `name` is a string referencing a
     column (e.g., `name = "id"`), `dplyr::pull` raises
     `vctrs_error_subscript_oob` if the column is absent — caught by
     the same handler. The by-survey naming sentinel `name = coll@id`
     (step 4) is internal and never resolves through this path.
     `name = NULL` (the default) cannot fail.

   The class-catch handler honors `.if_missing_var`: under `"skip"` the
   member is dropped from the per-survey result list; under `"error"`
   the failure re-raises via `surveytidy_error_collection_verb_failed`
   with `parent = cnd` (the caught `vctrs_error_subscript_oob` or
   `rlang_error_data_pronoun_not_found`).

   **Domain inclusion — inherits `pull.survey_base` semantics.**
   `pull.survey_base` (`R/select.R:313`) calls `dplyr::pull(@data, ...)`
   directly: it does NOT filter to in-domain rows, so the returned
   vector includes both in-domain and out-of-domain values.
   `pull.survey_collection` inherits this contract — the combined
   vector mixes in-domain and out-of-domain values across surveys, and
   the user has no per-element marker for domain membership. This is
   noted as a known limitation of `pull` at the per-survey verb level
   (not the collection layer); any future change to filter by domain
   should originate in `pull.survey_base` and the collection method
   will pick it up automatically. Document this explicitly in the
   roxygen `@section Domain inclusion:` block.
3. Combine via `vctrs::vec_c(!!!per_survey_results)`. On
   `vctrs_error_incompatible_type`, the dispatcher catches the condition
   and re-raises as `surveytidy_error_collection_pull_incompatible_types`
   with `parent = cnd`, naming the column and the surveys whose types
   disagreed. No auto-coercion — `pull` returns a single vector and
   silent coercion would mask the kind of data-type bug users almost
   certainly want surfaced. (This diverges from `glimpse`'s behaviour
   in §V.2, which auto-coerces with a footer; the divergence is
   intentional — glimpse is diagnostic, pull is computational.)
4. Naming:
   - `name = NULL` (default) — unnamed combined vector.
   - `name = coll@id` — by-survey naming sentinel: each combined element
     is named by its source survey. The sentinel string is whatever
     `coll@id` resolves to (default `.survey`; user-set values like
     `"wave"` or `"year"` work identically). Matches the analysis
     dispatcher's `.id` behaviour — see §XIII.1.
   - `name = "<other_column>"` — passes through to `dplyr::pull`'s
     `name` arg unchanged (per-row names from another column inside
     each member), then combined across surveys via the same
     `vctrs::vec_c()` path as the values (D4).

### V.2 `glimpse.survey_collection`

```r
glimpse.survey_collection <- function(
  x,
  width = NULL,
  .by_survey = FALSE
) { … }
```

**Default mode (`.by_survey = FALSE`):**

1. **Pre-check `coll@id` collision.** Before binding, if `x@id`
   matches a column name in any member's `@data`, raise
   `surveytidy_error_collection_glimpse_id_collision` naming the
   colliding column, the value of `x@id`, and the members where the
   collision occurs. The user must either rename their column or set
   a non-colliding `coll@id` via
   `surveycore::set_collection_id()` before glimpsing.

   Otherwise, build
   `combined <- dplyr::bind_rows(map(x@surveys, function(s) s@data))`,
   prepending a column named `x@id` (resolved at runtime — e.g.,
   `.survey` by default, or `"wave"` / `"year"` for user-set ids).
   Missing columns are NA-filled per `bind_rows`. Type conflicts
   coerce per `bind_rows()` rules with the standard coercion warning.

   This pre-check is symmetric with surveycore's existing analysis-side
   `surveycore_error_collection_id_collision` (collection construction
   already checks for this kind of name collision; glimpse adds the
   verb-side equivalent because the user can introduce the collision
   between construction and glimpse via `mutate` etc.).
2. **Rename the internal domain column for display.** If
   `surveycore::SURVEYCORE_DOMAIN_COL` (`..surveycore_domain..`) is
   present in `combined`, rename it to `.in_domain` for the glimpse
   render. This preserves the diagnostic value (users see which rows
   are out of domain) without exposing the surveycore-internal column
   name. Per-member `@data` is untouched — only the local `combined`
   tibble used for glimpse is renamed. The rename is unconditional when
   the column is present; no opt-out flag.
3. Print a single `dplyr::glimpse()` of `combined`.
4. If type conflicts occurred, print a footer enumerating them:

   ```
   ! Columns with conflicting types:
     age:    <chr> (2017); <dbl> (2018, 2019, 2020)           → coerced to <chr>
     race_f: <chr> (2017, 2019); <fct> (2018, 2020)           → coerced to <chr>
   ```

   Footer renders only when conflicts exist. No opt-out flag.
   Truncation rule (resolved per D7): when more than 5 columns have
   type conflicts, render the first 5 in column order followed by
   `+ N more conflicting columns`. Line width capped at 80 chars.
5. Returns `invisible(x)`.

**Per-survey mode (`.by_survey = TRUE`):**

For each member, print a labelled glimpse block (`▸ wave_2017`, etc.)
followed by `dplyr::glimpse(member_data_for_display)`, where
`member_data_for_display` is `member@data` with
`surveycore::SURVEYCORE_DOMAIN_COL` (if present) renamed to `.in_domain`
— same display rule as the default mode (step 2 above). Returns
`invisible(x)`.

`.if_missing_var` does not apply: `glimpse` does not reference user-named
columns.

### V.3 Joins (V8 — error)

```r
left_join.survey_collection <- function(x, y, ..., .if_missing_var = NULL) {
  cli::cli_abort(
    c(
      "x" = "{.fn left_join} on a {.cls survey_collection} is not supported.",
      "i" = "The semantics (apply to each survey? broadcast across all?) are still being designed.",
      "v" = "Apply the join inside a per-survey pipeline before constructing the collection."
    ),
    class = "surveytidy_error_collection_verb_unsupported"
  )
}
```

One method per join verb (`left_join`, `right_join`, `inner_join`,
`full_join`, `semi_join`, `anti_join`). All raise the same error class
with the verb name interpolated.

---

## VI. Re-exports

surveytidy re-exports surveycore's collection setters so that
`library(surveytidy)` is sufficient. Add to `R/reexports.R`:

```r
# Collection construction and setters (live in surveycore)

#' @export
surveycore::as_survey_collection

#' @export
surveycore::set_collection_id

#' @export
surveycore::set_collection_if_missing_var
```

No thin wrappers — surveycore's implementations are the source of truth
for property validation. The print method, `[[`, `length`, `names`, and
`add_survey` / `remove_survey` are also re-exported (already present in
surveycore's namespace; no surveytidy-side wiring needed beyond the
re-export).

**Re-exports added:**

| Symbol | Source |
|---|---|
| `as_survey_collection` | `surveycore` |
| `set_collection_id` | `surveycore` |
| `set_collection_if_missing_var` | `surveycore` |
| `add_survey` | `surveycore` |
| `remove_survey` | `surveycore` |

---

## VII. Errors and Warnings

### VII.1 New classes (add to `plans/error-messages.md`)

| Class | Source file | Trigger |
|---|---|---|
| `surveytidy_error_collection_verb_emptied` | `R/collection-dispatch.R` | Verb result is an empty collection (e.g., every member skipped via `.if_missing_var = "skip"`). Message identifies the verb and reports whether `.if_missing_var` came from per-call or stored property. |
| `surveytidy_error_collection_verb_unsupported` | `R/joins.R` (and any other unsupported verb) | Join verb dispatched on a `survey_collection`. Message names the verb. |
| `surveytidy_error_collection_verb_failed` | `R/collection-dispatch.R` | Per-survey verb application errored under `.if_missing_var = "error"`. Re-raises with `parent = cnd` so the original error chain is preserved. |
| `surveytidy_error_collection_rename_group_partial` | `R/rename.R` | Pre-flight check in `rename.survey_collection` / `rename_with.survey_collection`: a renamed column is in `coll@groups` and absent from at least one member. Raised before any member is touched. No `.if_missing_var` escape. |
| `surveytidy_error_collection_select_group_removed` | `R/select.R` | Pre-flight check in `select.survey_collection` / `relocate.survey_collection`: the resolved tidyselect would remove a column in `coll@groups`. Raised before any member is touched. Names the verb and the offending group column. No `.if_missing_var` escape — symmetric with the D3 rename-group-partial error. |
| `surveytidy_error_collection_pull_incompatible_types` | `R/collection-pull-glimpse.R` | `pull.survey_collection`'s `vctrs::vec_c()` raised `vctrs_error_incompatible_type`. Re-raised with `parent = cnd` so the original vctrs error chain is preserved. Names the column and the surveys whose types disagreed. |
| `surveytidy_error_collection_slice_zero` | `R/slice.R` | Pre-flight check in `slice.survey_collection` / `slice_head` / `slice_tail` / `slice_sample` (and `slice_min` / `slice_max` when their `n`/`prop` would empty every member): the supplied slice arguments would produce a 0-row result on every member. Raised before any member is touched. |
| `surveytidy_error_collection_glimpse_id_collision` | `R/collection-pull-glimpse.R` | Pre-flight check in `glimpse.survey_collection` (default mode): `x@id` matches a column name in at least one member's `@data`, which would collide with the prepended id column during `bind_rows`. Raised before binding. Names the colliding column and the members where it occurs. Mirrors surveycore's `surveycore_error_collection_id_collision` for verb-side collisions introduced after construction. |
| `surveytidy_error_collection_by_unsupported` | `R/filter.R`, `R/mutate.R`, `R/slice.R` | Per-call `.by` (or `by` for `slice_min`/`slice_max`/`slice_sample`) was supplied to a verb dispatched on a `survey_collection`. Raised before dispatch. Names the verb and points users to `group_by` on the collection or `coll@groups`. Replaces the verb-specific `surveytidy_error_filter_by_unsupported` for the collection layer; the per-survey `filter.survey_base` continues to use `surveycore_error_filter_by_unsupported` unchanged. |
| `surveytidy_message_collection_skipped_surveys` | `R/collection-dispatch.R` | Informational `cli::cli_inform()` listing surveys skipped under `.if_missing_var = "skip"`. (Not an error or warning — but registered as a typed message for handler consistency.) |
| `surveytidy_pre_check_missing_var` | `R/collection-dispatch.R` | **Internal — not part of public condition API.** Typed condition synthesized by the pre-check path when a data-masking quosure references a name that is unresolved in both the quosure's enclosing env and the survey's `@data`. Class chain: `c("surveytidy_pre_check_missing_var", "error", "condition")`. Fields: `$missing_vars` (chr), `$survey_name` (chr), `$quosure`. Stable for `parent`-chain testing (§IX.3); not exported. |

> **Note on detection:** The dispatcher uses two strategies to detect
> missing-variable conditions — pre-check for data-masking verbs (via
> `all.vars()` on captured quosures) and class-catch for tidyselect
> verbs (via `tryCatch` on `vctrs_error_subscript_oob` and
> `rlang_error_data_pronoun_not_found`, walking one level of
> `cnd$parent` to recover the `all_of()` wrap case). See §II.3.1 step 2.
> No new error class is needed for D1 resolution; the dispatcher reuses
> `surveytidy_error_collection_verb_failed` for the re-raise path.

### VII.2 Reused classes

- `surveycore_warning_empty_domain` — fires per-survey from
  `filter`/`drop_na`/`filter_out` (V4). The dispatcher does not wrap or
  rebrand.
- `surveycore_error_collection_groups_invariant` (G1) — raised by the
  surveycore class validator if the dispatcher returns a malformed
  collection. The dispatcher should not be able to produce a G1
  violation; the class validator is a safety net.
- `surveycore_error_collection_group_not_in_member_data` (G1b) — same
  contract.
- `surveycore_error_collection_groups_malformed` (G1c) — same contract.
- `surveycore_error_collection_empty` — raised by the surveycore
  validator if `out_coll@surveys` is length 0. The dispatcher's step-4
  proactive check prevents this from ever reaching the validator: by
  the time the dispatcher would assemble `out_coll`, it has already
  raised `surveytidy_error_collection_verb_emptied` with the verb name
  and `.if_missing_var` source. The validator class is documented as a
  safety net only — surveytidy is not expected to ever trip it.

### VII.3 Message template — `surveytidy_error_collection_verb_emptied`

```r
cli::cli_abort(
  c(
    "x" = "{.fn {verb_name}} produced an empty {.cls survey_collection}.",
    "i" = if (resolved_if_missing_var == "skip") {
      "All surveys were skipped because they were missing referenced variables."
    } else {
      "All surveys produced empty results."
    },
    "i" = if (id_from_stored) {
      "{.code .if_missing_var} resolved to {.val {resolved_if_missing_var}} from the collection's stored property."
    } else {
      "{.code .if_missing_var = {.val {resolved_if_missing_var}}} was passed to this call."
    },
    "v" = "Inspect {.fn names} on the input collection and verify each member has the referenced columns."
  ),
  class = "surveytidy_error_collection_verb_emptied"
)
```

---

## VIII. Roxygen Conventions

Every collection verb's roxygen block:

1. Joins the per-verb Rd file via `@rdname <verb>`.
2. Has its method tag: `@method <verb> survey_collection`.
3. Adds a `@section Survey collections:` block (one per verb) with the
   shared collection contract:

   > When applied to a `survey_collection`, the verb is dispatched to
   > each member independently. The result is a new `survey_collection`
   > whose `@id`, `@if_missing_var`, and `@groups` properties are
   > preserved from the input. Use `.if_missing_var` to override the
   > collection's stored missing-variable behavior for this call.

4. Documents `.if_missing_var` once in a shared template (linked via
   `@inheritParams`). Define a stub documentation node, no
   accompanying function — roxygen2 parses `@param` blocks from `@noRd`
   stubs and only suppresses the `.Rd` output, so `@inheritParams`
   resolution is unaffected. The canonical stub lives in
   `R/collection-dispatch.R`:

   ```r
   #' Shared parameters for survey_collection verb methods
   #'
   #' @name survey_collection_args
   #' @keywords internal
   #' @noRd
   #'
   #' @param .if_missing_var Per-call override of
   #'   `collection@if_missing_var`. One of `"error"` or `"skip"`, or
   #'   `NULL` (the default) to inherit the collection's stored value.
   #'   See `?surveycore::set_collection_if_missing_var`.
   NULL
   ```

   Each verb's roxygen then carries `#' @inheritParams survey_collection_args`.

5. Includes one `@examples` block per verb showing collection usage.
   Examples must `library(dplyr)` (or `tidyr`) and `library(surveytidy)`
   per `r-package-conventions.md`.

---

## IX. Testing

### IX.1 Test File Layout

```
tests/testthat/
  helper-test-data.R                     # MODIFIED: add make_test_collection()
  test-collection-dispatch.R             # NEW: dispatcher unit tests
  test-collection-filter.R               # NEW: filter + filter_out
  test-collection-drop-na.R              # NEW
  test-collection-select.R               # NEW: select + relocate
  test-collection-rename.R               # NEW: rename + rename_with
  test-collection-mutate.R               # NEW
  test-collection-arrange.R              # NEW: arrange
  test-collection-slice.R                # NEW: slice + slice_head/_tail/_min/_max/_sample
  test-collection-group-by.R             # NEW: group_by + ungroup + group_vars + is_rowwise
  test-collection-rowwise.R              # NEW: rowwise
  test-collection-distinct.R             # NEW: V9 contract
  test-collection-pull.R                 # NEW
  test-collection-glimpse.R              # NEW
  test-collection-joins.R                # NEW: V8 error stubs
  test-collection-reexports.R            # NEW: setter re-exports work
```

### IX.2 `make_test_collection()` helper

Adds to `helper-test-data.R`:

```r
make_test_collection <- function(seed = 42) {
  designs <- make_all_designs(seed = seed)
  surveycore::as_survey_collection(
    !!!designs,
    .id = ".survey",
    .if_missing_var = "error"
  )
}
```

Returns a 3-member collection with one of each design subclass, sharing
the column schema produced by `make_all_designs()`.

A second helper `make_heterogeneous_collection(seed)` returns a
3-member, all-`survey_taylor` collection whose members differ in their
non-design columns — used to test `.if_missing_var = "skip"`,
`any_of()` behaviour under V2, and per-verb missing-variable handling.

```r
make_heterogeneous_collection <- function(seed = 42) {
  base <- make_survey_data(n = 200, n_psu = 20, n_strata = 4, seed = seed)

  m1_data <- base                                   # full schema
  m2_data <- base[, !(names(base) %in% c("y2", "y3"))]
  m3_data <- base[, !(names(base) %in% "y1")]
  m3_data$region <- sample(
    c("north", "south", "east", "west"),
    nrow(m3_data),
    replace = TRUE
  )

  to_taylor <- function(df) {
    surveycore::as_survey(df, ids = psu, strata = strata, weights = wt, fpc = fpc)
  }

  surveycore::as_survey_collection(
    m1 = to_taylor(m1_data),
    m2 = to_taylor(m2_data),
    m3 = to_taylor(m3_data),
    .id = ".survey",
    .if_missing_var = "error"
  )
}
```

Contract:

- **Member count and names:** exactly 3 members, named `"m1"`, `"m2"`,
  `"m3"` (deterministic — tests can assert names directly).
- **Design subclass:** every member is `survey_taylor`. Subclass-mixing
  is exercised by `make_test_collection()`; this helper isolates schema
  heterogeneity from subclass heterogeneity.
- **Common columns (every member):** `psu`, `strata`, `fpc`, `wt`,
  `group`. The group column is uniform across members so G1b holds and
  the collection can carry `coll@groups = "group"` if a test calls
  `group_by`.
- **Schema differences:**
  - `m1` carries the full `make_survey_data()` schema —
    `c(psu, strata, fpc, wt, y1, y2, y3, group)`.
  - `m2` drops `y2` and `y3` —
    `c(psu, strata, fpc, wt, y1, group)`.
  - `m3` drops `y1` and adds `region` (a 4-level character) —
    `c(psu, strata, fpc, wt, y2, y3, group, region)`.
- **Reproducibility:** derived from a single `seed` argument routed
  through `make_survey_data(seed = seed)`; `region` sampling uses the
  ambient RNG state.
- **`@id` / `@if_missing_var`:** `".survey"` and `"error"` (matching
  `make_test_collection()` so tests can swap helpers without changing
  call-site assertions on `@id` / `@if_missing_var`).

This shape exercises three distinct missing-variable cases in one
fixture: `y1` missing on `m3`, `y2`/`y3` missing on `m2`, and `region`
present on `m3` only. Tests for `any_of()`, `.if_missing_var = "skip"`,
and the dispatcher's pre-check / class-catch paths reuse this fixture.

#### `test_collection_invariants()` — collection-level invariant helper

`testing-surveytidy.md` mandates `test_invariants(design)` as the first
assertion in every verb test block that creates or transforms a survey
object. The existing helper asserts six properties on `survey_base`
instances (data is a data.frame, ≥ 1 row, no duplicate column names,
design vars exist + atomic, weights numeric+positive, every
`visible_vars` column exists). None of those apply to a
`survey_collection`, which has `@surveys`, `@id`, `@if_missing_var`,
`@groups` and no `@data` of its own.

Add a collection-level analog to `helper-test-data.R`:

```r
test_collection_invariants <- function(coll) {
  # Class
  testthat::expect_true(S7::S7_inherits(coll, surveycore::survey_collection))

  # @surveys: non-empty list of survey_base members
  testthat::expect_gte(length(coll@surveys), 1L)
  for (member in coll@surveys) {
    testthat::expect_true(S7::S7_inherits(member, surveycore::survey_base))
  }

  # @id: character(1), non-empty
  testthat::expect_type(coll@id, "character")
  testthat::expect_length(coll@id, 1L)
  testthat::expect_true(nzchar(coll@id))

  # @if_missing_var: one of {"error", "skip"}
  testthat::expect_true(coll@if_missing_var %in% c("error", "skip"))

  # G1: every member's @groups equals collection's @groups
  for (member in coll@surveys) {
    testthat::expect_identical(member@groups, coll@groups)
  }

  # G1b: every group column exists in every member's @data
  for (gcol in coll@groups) {
    for (member in coll@surveys) {
      testthat::expect_true(gcol %in% names(member@data))
    }
  }

  invisible(coll)
}
```

Every collection verb test block must call **both** invariant helpers
as its first assertions (after constructing the collection but before
applying the verb under test):

```r
test_that("filter.survey_collection marks rows in domain on every member", {
  coll <- make_test_collection(seed = 42)
  test_collection_invariants(coll)
  for (member in coll@surveys) test_invariants(member)

  result <- dplyr::filter(coll, y1 > 50)
  test_collection_invariants(result)
  for (member in result@surveys) test_invariants(member)
  # ... further assertions
})
```

The collection helper covers collection-level invariants (G1, G1b, `@id`
shape, `@if_missing_var` enum, member class type); the per-member loop
preserves the existing `survey_base`-level discipline. Both are
non-negotiable: omitting the per-member loop would let a regression in a
verb's `survey_base` method (e.g., dropping a design variable from
`@data`) reach the collection layer undetected. Cross-references this
discipline from §IX.3 and §IX.4 in place of the simpler "class
invariants hold" wording.

### IX.3 Per-Verb Test Categories

For each verb method, the test file covers:

| Category | Required assertions |
|---|---|
| Happy path | Verb applied per-member; output is `survey_collection`; member count and order preserved. **Invariant discipline (required first assertions):** `test_collection_invariants(input)` AND `test_invariants(member)` iterated over `input@surveys` BEFORE applying the verb; same pair on the output. See §IX.2's "`test_collection_invariants()`" subsection. |
| `@id` / `@if_missing_var` preservation | Output has identical `@id` and `@if_missing_var` to input. |
| `@groups` sync | After `group_by`/`ungroup`/`rename`-of-group-col, every member's `@groups` equals `out@groups`. |
| `.if_missing_var = "error"` | Member missing a referenced column → error class `surveytidy_error_collection_verb_failed`, with the original tidyselect/rlang condition as `parent` (`vctrs_error_subscript_oob`, `rlang_error_data_pronoun_not_found`, or the dispatcher's pre-check sentinel — see D1 / §II.3.1 step 2). Snapshot test on message text. |
| `.if_missing_var = "skip"` | Same setup → returned collection has the offending member dropped; informational message fires (`surveytidy_message_collection_skipped_surveys`). |
| `.if_missing_var` precedence | Stored `coll@if_missing_var = "error"` + per-call `"skip"` → skip wins; reverse → error wins. |
| Empty result | All members skipped → `surveytidy_error_collection_verb_emptied`. Snapshot. |
| Domain column preservation | Pre-filter the input collection (`coll |> filter(y1 > 0)`) to create `surveycore::SURVEYCORE_DOMAIN_COL` on every member; apply the verb under test; assert the column is still present on every surviving member and the per-member values are unchanged. Skipped for `filter` / `filter_out` / `drop_na` (which legitimately modify the domain column) and `pull` / `glimpse` (which collapse). Required by `testing-surveytidy.md`. |
| `visible_vars` propagation | For `select` / `relocate` only: after `select(coll, y1, y2)`, every member's `@variables$visible_vars` equals `c("y1", "y2")`. After `select(coll, psu, strata)` (only design vars), every member's `@variables$visible_vars` is NULL. After verbs other than `select`/`relocate`, an existing `visible_vars` is preserved unchanged on every member. Required by `testing-surveytidy.md`. |
| Per-member `@metadata` | For `rename` / `rename_with`: after `rename(coll, new = old)`, every member's `@metadata` keys for `old` are renamed to `new` (mirrors the per-survey verb's contract). For `select`: after `select(coll, ...)`, `@metadata` entries for physically removed columns are dropped on every member. Required by `testing-surveytidy.md`. |
| Cross-design | `make_test_collection()` (mixed taylor/replicate/twophase) — every assertion above runs on the mixed collection. |
| Subclass-asymmetric design columns | For `rename` / `rename_with` / `select` / `relocate` only: assert behaviour when a referenced column is a design variable that exists on one subclass but not others (e.g., `repweights` is on `survey_replicate` only). On a `make_test_collection()` (mixed subclasses), `rename(coll, new = repweights)` under `.if_missing_var = "skip"` drops the non-replicate members; under `.if_missing_var = "error"` re-raises with `parent` set to the original tidyselect/rlang condition. The post-skip output is a 1-member collection containing only the replicate survey. Test exercises the same case for `select(coll, repweights)`. |

### IX.4 Dispatcher-Level Tests (`test-collection-dispatch.R`)

- Names and order preserved (and skipped members removed without
  reordering survivors).
- `@groups` sync correctness when a per-member verb updates `@groups`.
- Re-raise with `parent = cnd` produces a chain visible via
  `rlang::cnd_chain()`.
- The dispatcher does not call `surveycore::.dispatch_over_collection()`
  (separation of concerns).
- **Env-aware pre-check (load-bearing for D1).** The pre-check's
  env-filter substeps from §II.3.1 step 2 must each be exercised:
  - Locally-bound constant in the calling scope —
    `allowed <- 18:65; filter(coll, age %in% allowed)` — `allowed` must
    NOT be flagged as missing (it resolves via the quosure's enclosing
    env).
  - Global-env constant — assign `threshold <- 5` in the test's global
    env (or via `local({...})` with the appropriate parent), call
    `filter(coll, age > threshold)` — `threshold` must NOT be flagged.
  - `.data`/`.env` pronouns — `filter(coll, .data$age > 5)` and
    `filter(coll, .env$threshold > 0)` — neither pronoun is flagged
    (dropped per substep 2).
  - Column reference resolved by `@data` — `filter(coll, age > 5)`
    where `age` is in every member's `@data` — passes.
  - Truly missing name — `filter(coll, ghost_col > 5)` where
    `ghost_col` is absent from `@data` and from any enclosing env — IS
    flagged, and the resulting condition has class
    `surveytidy_pre_check_missing_var` with `$missing_vars == "ghost_col"`.
- **Internal `@groups` regression catch.** Confirm the
  `.may_change_groups = FALSE` assertion fires as a `simpleError` if a
  test-only mock per-member method mutates `@groups` (use
  `expect_error(class = "simpleError")`).
- **Sentinel class chain.** Assert
  `inherits(cnd, "surveytidy_pre_check_missing_var") && !inherits(cnd, "rlang_error")`
  for the synthesized condition (pins Issue 3's class-chain fix).
- **`surveytidy_message_collection_skipped_surveys` typed message.**
  Construct a 3-member collection where one member is missing a
  referenced column; call a verb under `.if_missing_var = "skip"`;
  assert via `expect_message(class = "surveytidy_message_collection_skipped_surveys")`
  that the message fires, and snapshot the body to pin the wording
  (must name every skipped survey). Mirrors the `expect_error` +
  snapshot discipline §IX.5 requires for typed errors and warnings.

### IX.5 Quality Gate Coverage

- ≥98% line coverage; ≥95% on every new file (per `engineering-preferences.md`).
- Every error class has a typed `expect_error(class = …)` test AND a
  snapshot test.
- Every warning class has an `expect_warning(class = …)` test.
- Every registered typed message class (e.g.,
  `surveytidy_message_collection_skipped_surveys`) has an
  `expect_message(class = …)` test AND a snapshot test, on the same
  discipline as errors.

---

## X. Quality Gates

Before opening the surveytidy PR:

- [ ] `devtools::test()` passes locally.
- [ ] `devtools::check()` passes with 0 errors, 0 warnings, ≤2 pre-approved notes.
- [ ] `covr::package_coverage()` reports ≥98% line coverage; ≥95% on every new file.
- [ ] `air format .` run and committed.
- [ ] `devtools::document()` run; NAMESPACE up-to-date with collection
      method registrations and re-exports.
- [ ] `plans/error-messages.md` has rows for every new class.
- [ ] `NEWS.md` `## (development version)` section has a `### survey_collection support` block.
- [ ] All examples include `library(dplyr)` / `library(tidyr)` per CI gotcha.
- [ ] Cross-design test matrix in §IX.3 passes for every verb.
- [ ] Roxygen `@section Survey collections:` present on every collection verb.
- [ ] `print.survey_collection` rendering still discoverable for `@id` /
      `@if_missing_var` / `@groups` (visual check).
- [ ] `DESCRIPTION` pins `surveycore` at a version that exports every
      symbol in §VI (`add_survey`, `remove_survey`, the collection setters,
      and internals `.propagate_or_match`/`.check_groups_match`). See §XIII.1.
- [ ] `DESCRIPTION` declares `vctrs (>= 0.7.0)` under Imports (used by
      `pull.survey_collection`'s typed combination — see §XIII.1).

---

## XI. Open Design Questions (for Stage 4)

These are issues the design sketch under-specified. Stage 2 (methodology)
and Stage 3 (spec review) may add more; Stage 4 resolves all of them and
folds answers into this spec.

### D1 — Missing-variable error class for data-masking verbs (RESOLVED)

> **D1 — DECIDED:** Hybrid pre-check + class-catch.

**Audit summary** (rlang 1.2.0, tidyselect 1.2.1, vctrs 0.7.3,
dplyr 1.2.1, tidyr 1.3.2):

- Tidyselect verbs (`select`, `rename`, `rename_with`, `relocate`,
  `distinct`, `rowwise`, `drop_na`) raise `vctrs_error_subscript_oob`
  reliably. `all_of()` wraps it as `cnd$parent` of a generic
  `rlang_error` — recoverable by walking one level of the parent chain.
- `.data$X` raises `rlang_error_data_pronoun_not_found`.
- `any_of()` does not raise — already lenient.
  `.if_missing_var = "skip"` is a no-op there.
- Bare-name data-masking verbs (`filter`, `filter_out`, `mutate`,
  `arrange`, `group_by`, `slice_min`, `slice_max`, `pull`) surface a
  generic `rlang_error` whose parent is
  `simpleError("object 'X' not found")` — **no distinguishing class**.
  A pure broad-catch (Option C) on `rlang_error` would also swallow
  S7 validator failures, surveycore errors, and unrelated rlang
  errors, defeating the purpose of `.if_missing_var = "skip"`.
- `surveycore_error_variable_not_found` is **never raised by any
  surveytidy verb** — it fires only inside surveycore's analysis paths.

**Decision:** the dispatcher takes a `.detect_missing` argument
(`"pre_check"` or `"class_catch"`).

- **Pre-check** (data-masking verbs): extract referenced names via
  `all.vars()` on the captured `...` quosures, compare to
  `names(survey@data)` before calling `fn(survey, ...)`.
- **Class-catch** (tidyselect verbs):
  `tryCatch(..., vctrs_error_subscript_oob = h, rlang_error_data_pronoun_not_found = h)`,
  with one parent-walk to catch the `all_of()` wrap case.

Each verb method declares its mode. See §II.3.1 step 2 for the
dispatcher's behaviour and §II.4 for the per-verb assignment.

### D2 — `slice_sample` reproducibility across surveys (RESOLVED)

> **D2 — DECIDED:** Option B — `slice_sample.survey_collection` gains a
> `seed = NULL` argument; non-`NULL` derives a deterministic per-survey
> seed via `rlang::hash`.

**Decision:**

- `seed = NULL` (default): no seed manipulation; ambient RNG state is
  consumed per-survey in iteration order. Reproducibility is
  order-dependent. Preserved as the literal default to avoid silently
  changing semantics for existing piped `slice_sample()` calls.
- `seed = <integer>` (recommended): per-survey seed derived as
  `strtoi(substr(rlang::hash(paste0(survey_name, "::", seed)), 1, 7), 16L)`.
  Stable across collection reorder, addition, and removal. Ambient
  `.Random.seed` is restored on exit via base `on.exit()` — no new
  package dependency (`rlang` is already in Imports; `withr` is not
  required).

See §II.3.3 for the helper, §IV.6 for the verb spec, and the verb matrix
note in §II.4.

### D3 — `rename` of a column that exists in some members but not all (RESOLVED)

> **D3 — DECIDED:** Hybrid — option (a) for non-group columns, option (c)
> for group columns.

**Decision:**

- **Non-group column rename:** Standard `.if_missing_var` behaviour
  (option a). Members lacking the renamed column either skip (under
  `"skip"`) or trigger `surveytidy_error_collection_verb_failed` (under
  `"error"`). Consistent with every other verb.
- **Group column rename:** Pre-flight error at the dispatch layer
  (option c). Before any member is touched, `rename.survey_collection`
  and `rename_with.survey_collection` verify that every member contains
  every `old_name` in `coll@groups`. If any member is missing a renamed
  group column, the verb raises
  `surveytidy_error_collection_rename_group_partial` and exits without
  mutation. No `.if_missing_var` escape — the post-rename G1 invariant
  is structurally unrecoverable (skipping the offending member would
  silently drop the user's grouping; allowing the rename through would
  produce a half-renamed `@groups` that violates G1).
- **Option (b) rejected:** Deferring to the validator fires after the
  dispatcher has mutated some members, leaves the collection in an
  indeterminate state, and produces a message that does not name the
  rename operation as the cause.

See §IV.4 for the verb spec, §VII.1 for the new error class, and the
internal helper `.check_group_rename_coverage()` (defined under §IV.4).

### D4 — `pull` combination semantics (RESOLVED)

> **D4 — DECIDED:** `vctrs::vec_c()`, with type conflicts surfaced as
> a typed surveytidy error.

**Decision:**

- `pull.survey_collection` combines per-survey results via
  `vctrs::vec_c(!!!per_survey_results)`. Consistent with surveycore's
  analysis dispatcher (which uses `dplyr::bind_rows`, also `vctrs`-backed).
- On `vctrs_error_incompatible_type`, the dispatcher catches the
  condition and re-raises as
  `surveytidy_error_collection_pull_incompatible_types` with
  `parent = cnd`, naming the offending column and the surveys whose
  types disagreed.
- No auto-coercion. `pull` returns a single vector — silently coercing
  to a common type (e.g., factor → character) would mask data-type bugs
  the user almost certainly wants surfaced.
- This intentionally diverges from `glimpse.survey_collection` (§V.2),
  which auto-coerces with a footer enumerating conflicts. The divergence
  is justified: glimpse is diagnostic (you want to SEE the conflict);
  pull is computational (you want type-safe output).
- `vctrs` is already a transitive dependency via `dplyr (>= 1.1.0)`;
  it is added explicitly to Imports for clarity.

See §V.1 for the verb spec and §VII.1 for the new error class.

### D5 — `pull` `name = ".survey"` resolution (RESOLVED)

> **D5 — DECIDED:** The by-survey naming sentinel resolves through
> `coll@id` (not a hard-coded literal).

**Decision:**

- `name = NULL` (default): unnamed combined vector.
- `name = coll@id`: by-survey naming. Each combined element is named
  by its source survey. The sentinel string is whatever `coll@id`
  resolves to — `.survey` by default, but user-set values like
  `"wave"` or `"year"` work identically. Matches the analysis
  dispatcher's existing `.id` behaviour, so the same string means the
  same thing in both verbs.
- `name = "<other_column>"`: passes through to `dplyr::pull`'s `name`
  arg unchanged (per-row names from another column inside each member),
  combined across surveys via the same `vctrs::vec_c()` path as the
  values (D4).

A hard-coded `.survey` literal was rejected as a brittle "the same name
means different things in different verbs" footgun for any user who
has set a non-default `coll@id`.

See §V.1 step 4 for the verb spec.

### D6 — Roxygen `@inheritParams` from a stub (RESOLVED)

> **D6 — DECIDED:** The stub pattern works as specified in §VIII.

**Decision:** Use a `@name survey_collection_args` + `@noRd` +
`@param .if_missing_var` stub in `R/collection-dispatch.R`. Each verb's
roxygen carries `#' @inheritParams survey_collection_args` to inherit
the shared parameter description.

**Verification:** roxygen2 parses `@param` blocks from any source
roxygen block, including ones marked `@noRd`. The `@noRd` tag only
suppresses generation of the corresponding `.Rd` file; it does NOT
remove the param definitions from roxygen2's symbol table. Therefore
`@inheritParams stub_name` resolves regardless of whether the stub
itself produces a manual page. This is documented in roxygen2's
inheritance vignette (`vignette("rd-other", package = "roxygen2")`)
and is the standard idiom for "private documentation node referenced
by exported functions."

No fallback to per-method param copies is needed.

### D7 — `glimpse` coercion footer width (RESOLVED)

**Decision:** Truncate at 5 conflicting columns, line width capped at
80 chars per row. When more than 5 columns have type conflicts, the
footer renders the first 5 (in column order as they appear in
`combined`) followed by a summary line:

```
! Columns with conflicting types:
  age:    <chr> (2017); <dbl> (2018, 2019, 2020)           → coerced to <chr>
  race_f: <chr> (2017, 2019); <fct> (2018, 2020)           → coerced to <chr>
  ...
  educ:   <ord> (2017); <fct> (2018, 2019, 2020)           → coerced to <fct>
  + 7 more conflicting columns
```

Selection of which 5 to show is deterministic (column order in
`combined`); no severity ranking. The footer does not paginate, wrap
each block, or otherwise render conflicts beyond the first 5.

**Rationale:** width-bounded truncation matches pillar's standard
behaviour for tibble printing; predictable and bounded. Users who need
the full type-conflict report can call `dplyr::glimpse()` per-member
via `.by_survey = TRUE` (which renders each member's data without the
footer, since the footer applies only to the cross-survey
`bind_rows`).

---

## XII. Implementation Plan (sketch)

This plan slates work into four PRs. Specifics are owned by
`/implementation-workflow` Stage 1.

| PR | Branch | Scope |
|---|---|---|
| 1 | `feature/survey-collection-dispatch` | Dispatcher (`R/collection-dispatch.R`), `.sc_*` wrappers, `make_test_collection()` helper, `make_heterogeneous_collection()` helper, `test-collection-dispatch.R`. Foundation. |
| 2a | `feature/survey-collection-data-mask-verbs` | Data-masking verbs: `filter`, `filter_out`, `mutate`, `arrange`. Pre-check detection mode. Per-verb test files. NAMESPACE registrations in `zzz.R`. |
| 2b | `feature/survey-collection-tidyselect-verbs` | Tidyselect verbs: `select`, `relocate`, `rename`, `rename_with`, `drop_na`, `distinct`, `rowwise`. Class-catch detection mode. Includes the verb-layer pre-flights (`surveytidy_error_collection_select_group_removed`, `surveytidy_error_collection_rename_group_partial`). Per-verb test files. NAMESPACE updates. |
| 2c | `feature/survey-collection-grouping-verbs` | Grouping verbs: `group_by`, `ungroup`, `group_vars`, `is_rowwise`. The two non-dispatching one-liners (`group_vars`, `is_rowwise`) live in this PR. Per-verb test files. NAMESPACE updates. |
| 2d | `feature/survey-collection-slice-verbs` | Slice family: `slice`, `slice_head`, `slice_tail`, `slice_min`, `slice_max`, `slice_sample`. Includes `surveytidy_error_collection_slice_zero` pre-flight infrastructure and `.derive_member_seed()`. Per-verb test files. NAMESPACE updates. |
| 3 | `feature/survey-collection-collapsing` | `pull.survey_collection`, `glimpse.survey_collection`. Type-coercion footer infrastructure (D7 truncation rule). |
| 4 | `feature/survey-collection-joins-and-reexports` | Join error stubs (V8), surveycore setter re-exports, `print` discoverability check, `NEWS.md` block, final QA. |

**Notes on the split:**

- The 15-verb scope from the original PR 2 is split along the
  detection-mode boundary (pre-check vs. class-catch) plus a
  grouping-verb partition and a slice-family partition. This mirrors
  §II.4's coverage matrix and minimizes reviewer load — each sub-PR
  has a coherent set of conventions and shared error classes.
- 2a and 2b can ship in parallel (they share no files and the
  dispatcher in PR 1 is the only common dependency). 2c depends on
  2b only inasmuch as `rename.survey_collection` must be merged
  before any group-rename pre-flight test (which lives in PR 2b).
  2d is independent of 2a/2b/2c.
- The original PR numbering (3, 4) stays the same so downstream
  references in the spec do not need renumbering.

Final PR granularity is owned by `/implementation-workflow` Stage 1
and may be revised at that point.

---

## XIII. Integration Contracts

### XIII.1 With surveycore

surveytidy depends on (must remain stable in surveycore):

| Surveycore symbol | Used by surveytidy for |
|---|---|
| `survey_collection` (S7 class) | `S7::S7_inherits()` checks, dispatch |
| `as_survey_collection`, `set_collection_id`, `set_collection_if_missing_var` | re-exports |
| `add_survey`, `remove_survey` | re-exports |
| `.propagate_or_match`, `.check_groups_match` | wrapped via `.sc_*` helpers |
| `surveycore_error_variable_not_found` | raised by surveycore's analysis paths only; the verb dispatcher does NOT catch it (see D1 — surveytidy verbs surface tidyselect/rlang-native conditions instead) |
| `surveycore_error_collection_empty` | catch class in dispatcher (re-raised as `surveytidy_error_collection_verb_emptied`) |
| `surveycore_error_collection_groups_invariant` (G1) | safety-net validator class |
| `surveycore_error_collection_group_not_in_member_data` (G1b) | safety-net validator class |
| `surveycore_error_collection_groups_malformed` (G1c) | safety-net validator class |
| `surveycore_warning_collection_meta_divergence` | not raised by surveytidy; user may see at analysis time |

surveytidy also takes an explicit Imports dependency on `vctrs`
(already a transitive dependency via `dplyr (>= 1.1.0)`). Used by
`pull.survey_collection` for typed combination via `vctrs::vec_c()`
(see D4).

**Minimum surveycore version pin.** `DESCRIPTION` must pin
`surveycore` at a version that exports every symbol re-exported by §VI
— specifically `as_survey_collection`, `set_collection_id`,
`set_collection_if_missing_var`, `add_survey`, `remove_survey`, and
the internals `.propagate_or_match` / `.check_groups_match` (used via
the `.sc_*` wrappers in `R/utils.R`). These shipped together in
surveycore PRs #97, #98, #111, #112, #113. The pin must be confirmed
against the installed surveycore version at PR time and bumped if any
re-exported setter has not yet been released — without the pin, a
user with an older surveycore install hits a load-time error
(`object 'add_survey' is not exported by 'namespace:surveycore'`).
This is a Quality Gate checklist item (§X).

surveytidy must NOT:

- Modify `survey_collection` properties via setters not exposed by
  surveycore (no direct `@id <-` outside the dispatcher's rebuild).
- Introduce a parallel `.dispatch_verb_over_collection()` in surveycore.
- Re-implement validator logic.

### XIII.2 With dplyr / tidyr

The collection methods rely on dplyr's S3 dispatch finding
`verb.surveycore::survey_collection` via `registerS3method()`. This is
the same pattern as `survey_base`, and `R/zzz.R` is the single point of
registration.

`dplyr_reconstruct` is **not** registered for `survey_collection` —
collections are not data frames, so dplyr never tries to reconstruct
them via that hook.

---

## XIV. Out-of-Scope Reminders

- **`subset.survey_collection`** — physical subsetting deferred (would
  need its own `.if_missing_var`-equivalent decision).
- **`*_join.survey_collection`** — error per V8; dedicated future spec.
- **Cross-survey `distinct`** — see V9.
- **New verbs not yet on `survey_base`** — collection methods are added
  only when their per-survey method exists.
- **Recoding helpers** (`case_when`, `recode_values`, etc.) and **row stats**
  (`row_means`, `row_sums`, etc.) — vector-level; "just work" inside
  collection-level `mutate` without bespoke methods.
- **Collection-level metadata-divergence detection** — owned by
  surveycore's analysis dispatcher; surveytidy's verb dispatch does not
  emit divergence warnings.
