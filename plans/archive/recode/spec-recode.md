# Spec: Survey-Aware Value Recoding Functions

**Version:** 0.7
**Date:** 2026-03-09
**Status:** APPROVED — all spec review issues resolved (Pass 1 + Pass 2 + Pass 3); ready for /implementation-workflow
**Phase:** 0.6 (post–Phase 0.5 extension)
**Branch prefix:** `feature/recode`

---

## Document Purpose

This is the source of truth for implementing survey-aware vector-level recoding
functions in surveytidy. It covers (a) six new exported functions that wrap or
re-implement dplyr's value-transformation utilities with `@metadata` management,
and (b) the changes to `mutate.survey_base()` required to support label
pre-attachment and post-detection.

These functions are called inside `mutate()` exactly like `dplyr::case_when()`.
No new table-level verbs are introduced.

Any decision not found here defers to the rule files in `.claude/rules/`.

---

## I. Scope

### I.1 What This Phase Delivers

| Deliverable | Description |
|---|---|
| `R/recode.R` | New file: 6 exported functions + 2 internal helpers |
| `R/mutate.R` | Modified: add pre-attachment, post-detection, and strip steps |
| `R/utils.R` | Modified: 3 new internal helpers used by mutate |
| `DESCRIPTION` | Add `haven (>= 2.5.0)` to Imports; bump `dplyr (>= 1.2.0)` |
| `tests/testthat/test-recode.R` | New test file: full coverage |
| `plans/error-messages.md` | New error classes registered |

### I.2 What This Phase Does NOT Deliver

- New table-level verbs (no `recode()` generic taking a design object directly)
- `*_fct()` shorthand variants — may be added later as thin wrappers
- Integration with Phase 1 estimation functions
- Batch label management (`set_var_label`, `set_val_labels` — those are in
  surveycore)

### I.3 Design Support Matrix

All 6 functions are vector-level, called inside `mutate()`. Because they
operate on plain vectors, not on the survey object, they work with all three
design types (taylor, replicate, twophase) without any design-specific code.
The `mutate.survey_base()` changes apply equally to all three types.

---

## II. Architecture

### II.1 Function Names and dplyr Shadowing

The six exported functions are named identically to their dplyr counterparts —
no `_survey` suffix:

| surveytidy export | dplyr equivalent | Relationship |
|---|---|---|
| `case_when()` | `dplyr::case_when()` | **Shadows** — adds `.label`, `.value_labels`, `.factor` |
| `if_else()` | `dplyr::if_else()` | **Shadows** — adds `.label`, `.value_labels` |
| `na_if()` | `dplyr::na_if()` | **Shadows** — adds `.update_labels` |
| `replace_when()` | `dplyr::replace_when()` *(1.2.0+)* | **Wraps** `dplyr::replace_when()` — no internal implementation |
| `recode_values()` | `dplyr::recode_values()` *(1.2.0+)* | **Own implementation** — identical API |
| `replace_values()` | `dplyr::replace_values()` *(1.2.0+)* | **Own implementation** — identical API |

**Shadowing contract:** When a user loads surveytidy after dplyr, surveytidy's
`case_when`, `if_else`, and `na_if` mask dplyr's. This is intentional. The
contract is: **when called without `.label`, `.value_labels`, `.update_labels`,
or `.factor`, surveytidy's versions produce output identical to dplyr's.** No
behavioral difference when the extra args are absent or NULL/FALSE.

Users can always use `dplyr::case_when()` explicitly to bypass the surveytidy
version. This is a feature, not a bug — it allows surveytidy-aware code to live
alongside code that intentionally skips label tracking.

### II.2 dplyr Version Strategy

`replace_when()`, `recode_values()`, and `replace_values()` were introduced in
dplyr 1.2.0. This phase requires `dplyr (>= 1.2.0)`. Delegation complexity varies:
`replace_when()` delegates directly with no custom logic. `recode_values()`
and `replace_values()` use delegation as the core path but add surveytidy
label handling, error catching, and (for `recode_values()`) a `.use_labels`
path — see §VIII and §IX for full contracts.

| surveytidy function | Delegates to | dplyr since |
|---|---|---|
| `replace_when(x, cond ~ val, ...)` | `dplyr::replace_when()` | 1.2.0 ✓ |
| `recode_values(x, from, to, ...)` | `dplyr::recode_values()` | 1.2.0 ✓ |
| `replace_values(x, from, to)` | `dplyr::replace_values()` | 1.2.0 ✓ |

**Rationale:** `dplyr::recode_values()` and `dplyr::replace_values()` are the
authoritative replacements for the now-soft-deprecated `dplyr::case_match()`.
They natively accept `from`/`to` arguments and handle type coercion via vctrs
internally. Delegating to them directly gives correct behavior for free with no
formula construction machinery needed.

**`dplyr::case_match()` is NOT used** — it is soft-deprecated in dplyr 1.2.0.

**`.unmatched = "error"` in recode_values():** `dplyr::recode_values()` exposes
`.unmatched` natively. Pass `.unmatched` through to dplyr, but catch dplyr's
error and rethrow with `surveytidy_error_recode_unmatched_values` for
testability and consistent error class coverage.

### II.3 File Organization

```
R/
  mutate.R      # MODIFIED: add pre-attachment, post-detection, strip steps
  recode.R      # NEW: 6 exported functions + 2 internal helpers
  utils.R       # MODIFIED: 3 new helpers (.attach_label_attrs, etc.)

tests/testthat/
  test-recode.R  # NEW: full test coverage

DESCRIPTION           # MODIFIED: haven (>= 2.5.0)
plans/error-messages.md  # MODIFIED: 3 new error classes
```

### II.4 Internal Helper Placement

**Decision:** The three mutate-support helpers (`.attach_label_attrs()`,
`.extract_labelled_outputs()`, `.strip_label_attrs()`) go in `R/utils.R`, not
inline in `R/mutate.R`.

Rationale: these helpers are substantial (~15–25 lines each) and share the same
infrastructure role as `.protected_cols()` and `.warn_physical_subset()`. The
single-use rule in `code-style.md` is a size heuristic; it yields to grouping
by conceptual layer for helpers of this complexity.

There are no internal implementation helpers for the three new functions —
`replace_when`, `recode_values`, and `replace_values` each delegate directly
to their dplyr 1.2.0 counterparts (see §II.2).

### II.5 Import Strategy (haven)

`haven::labelled()` is called at runtime in exported functions. Add
`haven (>= 2.5.0)` to `Imports:` in DESCRIPTION. Use `haven::labelled()` and
`haven::zap_labels()` with `::` throughout — no `@importFrom`, consistent with
`r-package-conventions.md`.

---

## III. Changes to mutate.survey_base()

### III.1 Background

surveycore strips haven label attrs from `@data` columns — `@data` stores plain
vectors. Inside `dplyr::mutate()`, columns therefore carry no label attrs.
The recode functions need access to labels (for `.use_labels = TRUE` and label
inheritance), and they return `haven_labelled` vectors that must be extracted
into `@metadata` and stripped from `@data`.

Three new steps in `mutate.survey_base()` handle this.

### III.2 Revised mutate.survey_base() Flow

**Current (Phase 0.5):**
1. Warn on design variable modification
2. Call `dplyr::mutate()` on `@data`
3. Re-attach protected columns dropped by `.keep`
4. Update `visible_vars`
5. Record transformations in `@metadata`
6. Assign updated `@data`

**New:**
1. Warn on design variable modification *(extended)*:
   - **Weight column** → `surveytidy_warning_mutate_weight_col` (Phase 0.5, unchanged)
   - **Structural design variable** (strata, PSU, FPC, repweights) → new
     `surveytidy_warning_mutate_structural_var`. Message is more alarming than
     the weight warning — structural recoding can invalidate the probability
     model, not just effective sample size. Example message:
     ```
     ! Recoding column `{col}` modifies design structure (strata, PSU, or FPC).
     i Structural recoding can invalidate variance estimates.
     i Use subset() or filter() to restrict the domain; do not recode design
       variables.
     ```
   - Both checks run in step 1 before any pre-attachment or mutate call.
2. **[NEW]** Pre-attach: `augmented_data <- .attach_label_attrs(.data@data, .data@metadata)`
3. Call `dplyr::mutate()` on `augmented_data` *(was on `@data`)*
4. **[NEW]** Post-detect: `updated_metadata <- .extract_labelled_outputs(new_data, .data@metadata, mutated_names)`
5. **[NEW]** Strip: `new_data <- .strip_label_attrs(new_data)`
6. Re-attach protected columns dropped by `.keep` *(unchanged)*
7. Update `visible_vars` *(unchanged)*
8. Record transformations in `@metadata@transformations` — **expanded**: for
   each name in `changed_cols` whose result carries a `surveytidy_recode` attr,
   build and store a provenance record:
   ```r
   @metadata@transformations[[col]] <- list(
     fn          = as.character(rlang::call_name(rlang::quo_get_expr(quo))),
     source_cols = setdiff(all.vars(rlang::quo_squash(quo)), col),
     expr        = deparse(rlang::quo_squash(quo)),
     output_type = if (is.factor(new_data[[col]])) "factor" else "vector",
     description = attr(new_data[[col]], "surveytidy_recode")$description
   )
   ```
   `description` is `NULL` when the user did not supply `.description`.
   Columns whose result has no `surveytidy_recode` attr (non-recode mutate
   expressions) are not logged here — transformation attribution is
   recode-function-specific.
9. Assign updated `@data` AND updated `@metadata` *(extended: was only `@data`)*

### III.3 Pre-Attachment Step: .attach_label_attrs()

```r
.attach_label_attrs <- function(data, metadata)
# data     : plain data.frame from @data
# metadata : the @metadata S7 object
# Returns  : modified copy of data with haven label attrs attached to
#             columns that have entries in @metadata
```

Behavior:
- For each name in `names(metadata@value_labels)` that also exists in `data`:
  `attr(data[[col]], "labels") <- metadata@value_labels[[col]]`
- For each name in `names(metadata@variable_labels)` that also exists in `data`:
  `attr(data[[col]], "label") <- metadata@variable_labels[[col]]`
- Returns a modified copy — does NOT mutate `@data` in place.
- No-op if `@metadata` has no labels (fast path: check both lists are empty).

**Always-on:** This step runs on every `mutate()` call, not only when a recode
function is used. For designs with many labelled columns this adds `attr<-`
overhead, which is negligible in practice (100 attr assignments on a 1000-row
data frame is microseconds). The always-on approach is simpler than trying to
detect which `mutate()` expressions call recode functions.

**Side-effect:** Any function called inside `mutate()` will see columns with
`"labels"` and `"label"` attributes for columns that have `@metadata` entries —
but NOT the `"haven_labelled"` class. `attr<-` does not change `class()`.
Post-detection therefore does NOT check `inherits(data[[col]], "haven_labelled")`;
it checks the `"surveytidy_recode"` attribute set by `.wrap_labelled()` on recode
function outputs (see §III.4 and §X.1). This is an accepted consequence.

Note on the domain column (`surveycore::SURVEYCORE_DOMAIN_COL`):
- **Pre-attachment (§III.3):** The domain column has no `@metadata` entries.
  `.attach_label_attrs()` skips it — its name is absent from both
  `metadata@value_labels` and `metadata@variable_labels`.
- **Strip (§III.5):** The domain column carries no haven attrs and no
  `"surveytidy_recode"` attr. `haven::zap_labels()` is a no-op on it.
- **Re-attach (step 6):** The domain column is included in `.protected_cols()`
  (Phase 0.5 established this). Step 6 is unchanged and continues to protect it.

### III.4 Post-Detection Step: .extract_labelled_outputs()

```r
.extract_labelled_outputs <- function(data, metadata, changed_cols)
# data         : new_data after dplyr::mutate()
# metadata     : the @metadata S7 object (from .data, pre-mutation)
# changed_cols : character vector — LHS names from rlang::quos(...),
#                i.e. the names of explicitly named mutation expressions
# Returns      : updated metadata object
```

Behavior:
- For each name in `changed_cols` that exists in `data`:
  - If `!is.null(attr(data[[col]], "surveytidy_recode"))` — this attribute is
    set on all recode function outputs that used at least one surveytidy arg
    (`.label`, `.value_labels`, `.description`, or `.factor = TRUE`). It is a
    named list: `list(description = <character(1) or NULL>)`. Set by
    `.wrap_labelled()` for labelled outputs; set directly in the function body
    for factor and plain-with-description outputs (see §X.1):
    - `metadata@variable_labels[[col]] <- attr(data[[col]], "label")`
    - `metadata@value_labels[[col]] <- attr(data[[col]], "labels")`
  - Else if `col` has any existing entry in `metadata@variable_labels` OR
    `metadata@value_labels` (i.e., the column had labels before this mutate):
    - `metadata@variable_labels[[col]] <- NULL`
    - `metadata@value_labels[[col]] <- NULL`
    - Rationale: an explicit column overwrite with non-labelled output replaces
      the column; retaining old labels for a structurally different column
      produces stale metadata. Users who want to preserve labels must pass
      `.label` / `.value_labels` args.
- Return updated `metadata`.

**Implementation note (S7 validation):** `.extract_labelled_outputs()` receives
`metadata` by value and returns a fully updated copy. It does NOT assign to
`.data@metadata` inside its body. The single final assignment in
`mutate.survey_base()` (`@metadata <- updated_metadata`) triggers exactly one
S7 class validation on a fully consistent state — avoiding the validator bypass
pattern that `rename()` required for intermediate-state assignments.

**Limitation:** `changed_cols` covers only explicitly-named LHS expressions
(e.g., `mutate(d, age_cat = case_when(...))`) — NOT anonymous expressions
like `mutate(d, across(...))` that happen to produce labelled output. This
limitation is accepted for Phase 0.6 and documented in the function header.

### III.5 Strip Step: .strip_label_attrs()

```r
.strip_label_attrs <- function(data)
# data    : data.frame after dplyr::mutate()
# Returns : data.frame with all haven label attrs removed from every column
```

Behavior:
- For each column: apply `haven::zap_labels()` to remove `"label"`, `"labels"`,
  `"format.spss"`, `"display_width"`, and the `"haven_labelled"` class.
- For each column: remove `attr(data[[col]], "surveytidy_recode")` if present.
- Returns modified `data`.

`haven::zap_labels()` is the authoritative haven function for haven attr removal.
The `"surveytidy_recode"` attr must be removed separately (it is not a haven attr).
See §III.3 for the full domain column note (it is a no-op in this step).

---

## IV. case_when()

### IV.1 Signature

```r
case_when(
  ...,
  .default = NULL,
  .unmatched = "default",
  .ptype = NULL,
  .size = NULL,
  .label = NULL,
  .value_labels = NULL,
  .factor = FALSE,
  .description = NULL
)
```

Argument order follows `code-style.md`: required NSE (`...`) first, then
optional dplyr pass-through scalars, then surveytidy-specific label args.

### IV.2 Argument Table

| Argument | Type | Default | Description |
|---|---|---|---|
| `...` | formula pairs | — | Two-sided formulas `condition ~ value`. Passed unchanged to `dplyr::case_when()`. Required. |
| `.default` | scalar or NULL | `NULL` | Default value for unmatched rows. Passed through. |
| `.unmatched` | character(1) | `"default"` | `"default"` (use `.default`) or `"error"`. Passed through. |
| `.ptype` | type prototype or NULL | `NULL` | Output type prototype. Passed through. |
| `.size` | integer(1) or NULL | `NULL` | Expected output length. Passed through. |
| `.label` | character(1) or NULL | `NULL` | Variable label. Stored in `@metadata@variable_labels` via post-detection. Errors if `.factor = TRUE`. |
| `.value_labels` | named vector or NULL | `NULL` | Value labels: `c("Label" = value, ...)`. Stored in `@metadata@value_labels` via post-detection. |
| `.factor` | logical(1) | `FALSE` | If TRUE, return a factor instead of a labelled vector. Cannot be combined with `.label`. |
| `.description` | character(1) or NULL | `NULL` | Plain-language description of how the variable was created (e.g., `"Age category: young (<30), middle (30–59), old (60+)"`). Stored in `@metadata@transformations[[col]]$description`. Intended for codebooks and non-R audiences. |

### IV.3 Output Contract

1. Pass `...`, `.default`, `.unmatched`, `.ptype`, `.size` to `dplyr::case_when()`.
2. If `.factor = TRUE` AND `.label` is non-NULL: error with
   `surveytidy_error_recode_factor_with_label` before calling dplyr.
3. If `.factor = TRUE`: determine factor levels via two-path detection, then
   call `.factor_from_result()`:
   - **Detect literal RHS:** walk each formula in `list(...)`, apply
     `rlang::is_syntactic_literal(rlang::f_rhs(f))` to each.
   - **All-literal path:** if every formula's RHS is a syntactic literal,
     extract the RHS values in formula order → `formula_values` (empty levels
     preserved: a literal RHS value becomes a level even if no row matches that
     branch); if `.default` is non-NULL and `!is.na(.default)`, append
     `as.character(.default)` to `formula_values`. Then call
     `dplyr::case_when(...)` → `result`.
   - **Any-non-literal path:** if any formula's RHS is a function call or
     other non-literal expression, call `dplyr::case_when(...)` → `result`
     first; derive `formula_values <- unique(as.character(result[!is.na(result)]))`
     in appearance order. (Empty levels are not preserved in this path; use
     `.value_labels` to specify levels explicitly when full control is needed.)
   - Call `.factor_from_result(result, .value_labels, formula_values)`.
   - Set `attr(result, "surveytidy_recode") <- list(description = .description)`
     on the factor result before returning.
   Post-detection processes the column via the `surveytidy_recode` path
   (§III.4): `attr(x, "label")` and `attr(x, "labels")` are both NULL on a
   factor, so any pre-existing labels in `@metadata` are cleared. This is
   correct — the old labels described a different encoding; the column has been
   replaced. `.value_labels` is used only for level ordering.
4. If `.factor = FALSE` and `.label` or `.value_labels` is non-NULL: wrap
   result in `haven::labelled()` via `.wrap_labelled()`. Post-detection extracts
   this into `@metadata`.
5. If `.factor = FALSE` and both label args are NULL:
   - If `.description` is non-NULL: `attr(result, "surveytidy_recode") <- list(description = .description)`; return result.
   - Otherwise: return plain vector (identical to `dplyr::case_when()` behavior).

### IV.4 Error Table

| Class | Trigger | Message template |
|---|---|---|
| `surveytidy_error_recode_label_not_scalar` | `.label` not NULL and not character(1) — validated by `.validate_label_args()` (§X.3) | `.label` must be a single character string, not {.cls {class(.label)}}. |
| `surveytidy_error_recode_value_labels_unnamed` | `.value_labels` not NULL and unnamed — validated by `.validate_label_args()` (§X.3) | `.value_labels` must be a named vector. |
| `surveytidy_error_recode_description_not_scalar` | `.description` not NULL and not character(1) — validated by `.validate_label_args()` (§X.3) | `.description` must be a single character string. |
| `surveytidy_error_recode_factor_with_label` | `.factor = TRUE` and `.label` is non-NULL | `.label` cannot be used with `.factor = TRUE`; factor levels carry their own labels. |

**Note:** `.unmatched = "error"` failures in `dplyr::case_when()` propagate
with dplyr's own condition class — no surveytidy wrapper. This is intentional:
dplyr's message for unmatched rows is already informative. Contrast with
`recode_values()` (§VIII.6), which does wrap its unmatched error.

---

## V. replace_when()

**No `.factor` argument** — `replace_when()` is type-stable (output type
matches input `x`). To produce a factor, apply `base::factor()` after the
mutation.

### V.1 Signature

```r
replace_when(
  x,
  ...,
  .label = NULL,
  .value_labels = NULL,
  .description = NULL
)
```

### V.2 Argument Table

| Argument | Type | Default | Description |
|---|---|---|---|
| `x` | vector | — | Input vector. Required. |
| `...` | formula pairs | — | Two-sided formulas `condition ~ replacement`. Required. |
| `.label` | character(1) or NULL | `NULL` | Variable label for the output column. If NULL, the variable label is inherited from `attr(x, "label")` when available. |
| `.value_labels` | named vector or NULL | `NULL` | Value labels. Merged with labels inherited from `x`. `.value_labels` overrides for matching values; remaining labels from `x` are retained. |
| `.description` | character(1) or NULL | `NULL` | Plain-language description of the replacement logic. Stored in `@metadata@transformations[[col]]$description`. |

### V.3 Core Delegation

`replace_when(x, cond1 ~ val1, cond2 ~ val2)` delegates directly to
`dplyr::replace_when(x, cond1 ~ val1, cond2 ~ val2)`. `dplyr::replace_when()`
is the native dplyr 1.2.0 function; it is type-stable — unmatched positions
keep their original value from `x`. No internal implementation needed.

### V.4 Output Contract

1. Call `dplyr::replace_when(x, ...)` (no internal impl — see §V.3).
2. Determine output labels: `merged_labels <- .merge_value_labels(attr(x, "labels"), .value_labels)` (§X.4).
3. Resolve effective variable label: `effective_label <- if (!is.null(.label)) .label else attr(x, "label")`.
4. If `merged_labels` is non-NULL or `effective_label` is non-NULL: wrap via
   `.wrap_labelled(result, label = effective_label, value_labels = merged_labels, description = .description)`.
5. Otherwise: if `.description` is non-NULL, set
   `attr(result, "surveytidy_recode") <- list(description = .description)`;
   return plain vector.

### V.5 Error Table

| Class | Trigger |
|---|---|
| `surveytidy_error_recode_label_not_scalar` | `.label` not NULL and not character(1) — validated by `.validate_label_args()` (§X.3) |
| `surveytidy_error_recode_value_labels_unnamed` | `.value_labels` not NULL and unnamed — validated by `.validate_label_args()` (§X.3) |
| `surveytidy_error_recode_description_not_scalar` | `.description` not NULL and not character(1) — validated by `.validate_label_args()` (§X.3) |

---

## VI. if_else()

### VI.1 Signature

```r
if_else(
  condition,
  true,
  false,
  missing = NULL,
  ...,
  ptype = NULL,
  .label = NULL,
  .value_labels = NULL,
  .description = NULL
)
```

### VI.2 Argument Table

| Argument | Type | Default | Description |
|---|---|---|---|
| `condition` | logical vector | — | Required. |
| `true` | vector | — | Value(s) when condition is TRUE. Required. |
| `false` | vector | — | Value(s) when condition is FALSE. Required. |
| `missing` | vector or NULL | `NULL` | Value(s) when condition is NA. Passed to `dplyr::if_else()`. |
| `...` | — | — | Passed through to `dplyr::if_else()`. |
| `ptype` | type prototype | `NULL` | Output type. Passed through. |
| `.label` | character(1) or NULL | `NULL` | Variable label for the output column. |
| `.value_labels` | named vector or NULL | `NULL` | Value labels. Explicit only — true/false may differ in meaning, no auto-inference. |
| `.description` | character(1) or NULL | `NULL` | Plain-language description of the conditional logic. Stored in `@metadata@transformations[[col]]$description`. |

### VI.3 Output Contract

1. Pass `condition`, `true`, `false`, `missing`, `...`, `ptype` to
   `dplyr::if_else()`.
2. If `.label` or `.value_labels` is non-NULL: wrap in `haven::labelled()`.
3. Otherwise: if `.description` is non-NULL, set
   `attr(result, "surveytidy_recode") <- list(description = .description)`;
   return plain vector.

No `.factor` argument.

### VI.4 Error Table

| Class | Trigger |
|---|---|
| `surveytidy_error_recode_label_not_scalar` | `.label` not NULL and not character(1) — validated by `.validate_label_args()` (§X.3) |
| `surveytidy_error_recode_value_labels_unnamed` | `.value_labels` not NULL and unnamed — validated by `.validate_label_args()` (§X.3) |
| `surveytidy_error_recode_description_not_scalar` | `.description` not NULL and not character(1) — validated by `.validate_label_args()` (§X.3) |

---

## VII. na_if()

### VII.1 Signature

```r
na_if(
  x,
  y,
  .update_labels = TRUE,
  .description = NULL
)
```

### VII.2 Argument Table

| Argument | Type | Default | Description |
|---|---|---|---|
| `x` | vector | — | Input vector. Required. |
| `y` | scalar or vector | — | Value(s) to replace with NA. Passed to `dplyr::na_if()`. Required. |
| `.update_labels` | logical(1) | `TRUE` | If TRUE and `x` carries value labels, remove label entries for values in `y` from the output's value labels. |
| `.description` | character(1) or NULL | `NULL` | Plain-language description of which values were set to NA and why. Stored in `@metadata@transformations[[col]]$description`. |

### VII.3 Output Contract

0. `rlang::check_scalar_bool(.update_labels)` — validates that `.update_labels`
   is a non-NA `logical(1)`. Produces a standard rlang error on failure; no
   surveytidy error class needed.
1. Call `dplyr::na_if(x, y)`.
2. If `x` carries `"labels"` attr (from pre-attachment):
   - If `.update_labels = TRUE`: remove all entries where `labels_attr[i] %in% y`.
   - If `.update_labels = FALSE`: retain labels unchanged.
   - Wrap result in `haven::labelled()` with the (possibly updated) labels and
     any inherited `"label"` attr.
3. If `x` carries no label attrs: return plain vector.

No `.label` argument — variable label is inherited from `x` unchanged.
If the user needs to change the variable label, they use `set_var_label()`
afterward or chain a rename.

### VII.4 Error Table

| Class | Trigger |
|---|---|
| `surveytidy_error_recode_description_not_scalar` | `.description` not NULL and not character(1) — validated by `.validate_label_args(label = NULL, value_labels = NULL, description = .description)` (§X.3) |

`dplyr::na_if()` errors propagate as-is.

---

## VIII. recode_values()

### VIII.1 Signature

```r
recode_values(
  x,
  ...,
  from = NULL,
  to = NULL,
  default = NULL,
  .unmatched = "default",
  ptype = NULL,
  .label = NULL,
  .value_labels = NULL,
  .factor = FALSE,
  .use_labels = FALSE,
  .description = NULL
)
```

### VIII.2 Argument Table

| Argument | Type | Default | Description |
|---|---|---|---|
| `x` | vector | — | Input vector to recode. Required. |
| `...` | — | — | Additional args passed to `dplyr::recode_values()`. |
| `from` | vector or NULL | `NULL` | Old values. Must be supplied unless `.use_labels = TRUE`. |
| `to` | vector or NULL | `NULL` | New values corresponding to `from`. Same length as `from`. |
| `default` | scalar or NULL | `NULL` | Value for entries in `x` not found in `from`. NULL = keep original value. |
| `.unmatched` | character(1) | `"default"` | `"default"` (use `default`) or `"error"`. Passed to `dplyr::recode_values()`; dplyr's error is caught and rethrown as `surveytidy_error_recode_unmatched_values`. |
| `ptype` | type prototype | `NULL` | Output type. |
| `.label` | character(1) or NULL | `NULL` | Variable label. Errors if `.factor = TRUE`. |
| `.value_labels` | named vector or NULL | `NULL` | Value labels for the output column. |
| `.factor` | logical(1) | `FALSE` | If TRUE, return a factor. Cannot be combined with `.label`. |
| `.use_labels` | logical(1) | `FALSE` | If TRUE, read `attr(x, "labels")` to build the from/to map automatically. |
| `.description` | character(1) or NULL | `NULL` | Plain-language description of the recoding logic. Stored in `@metadata@transformations[[col]]$description`. |

### VIII.3 Core Delegation

Before delegating, enforce the conditional-required contract:

```r
if (is.null(from) && !.use_labels) {
  cli::cli_abort(
    c(
      "x" = "{.arg from} must be supplied when {.code .use_labels = FALSE}.",
      "v" = "Supply {.arg from} and {.arg to}, or set {.code .use_labels = TRUE}
             to build the map from {.arg x}'s value labels."
    ),
    class = "surveytidy_error_recode_from_to_missing"
  )
}
```

**Length mismatch** between `from` and `to` is delegated to `dplyr::recode_values()` — dplyr's error propagates unchanged with its own condition class. No surveytidy error class for this condition.

`recode_values(x, from, to, default, .unmatched, ptype)` then delegates to
`dplyr::recode_values()`. The `from`/`to` arguments are passed directly — no
formula construction needed:

```r
tryCatch(
  dplyr::recode_values(x, from = from, to = to, default = default,
                       .unmatched = .unmatched, ptype = ptype, ...),
  error = function(e) {
    # Gate reclassification on dplyr's specific unmatched-values error class.
    # Only reclassify that class; all other errors (type mismatches, etc.)
    # are re-thrown unchanged so the user sees the correct error.
    # ⚠️ GAP: Verify the exact dplyr condition class for unmatched-values
    # errors in dplyr 1.2.0 source before implementing. The class name below
    # is illustrative — update from actual dplyr source.
    if (.unmatched == "error" &&
        inherits(e, "dplyr_error_recode_unmatched")) {
      cli::cli_abort(
        c("x" = "Some values in {.arg x} were not found in {.arg from}.",
          "i" = "Set {.code .unmatched = \"default\"} to keep unmatched values."),
        class = "surveytidy_error_recode_unmatched_values",
        parent = e
      )
    }
    stop(e)  # all other errors pass through with their original class
  }
)
```

`dplyr::recode_values()` handles type coercion via vctrs internally. The GAP
above must be resolved (dplyr error class confirmed) before implementation — add
it to §XIII Quality Gates.

### VIII.4 `.use_labels = TRUE` Behavior

1. Read `labels_attr <- attr(x, "labels")`. If NULL, error with
   `surveytidy_error_recode_use_labels_no_attrs`.
2. Build `from = unname(labels_attr)` (original codes),
   `to = names(labels_attr)` (label strings become new values).
3. Call `dplyr::recode_values(x, from = from, to = to)` (no internal impl —
   see §II.2).
4. If `.value_labels` is NULL: do not set value labels on output — output values
   ARE the label strings, so a second layer of value labels is not meaningful.
   Return plain character vector (or wrap with `.label` if set).

### VIII.5 Output Contract

Pre-delegation (before calling `dplyr::recode_values()`):
- If `.factor = TRUE` AND `.label` is non-NULL: error with
  `surveytidy_error_recode_factor_with_label`.

After `dplyr::recode_values()` returns `result`:

1. If `.factor = TRUE`: call `.factor_from_result(result, .value_labels, unique(to))`.
   (`unique(to)` is always the `formula_values` for this function — no
   formula-literal detection needed, unlike `case_when()`.) Set
   `attr(result, "surveytidy_recode") <- list(description = .description)` on
   the factor result before returning.
2. If `.factor = FALSE` and `.label` or `.value_labels` is non-NULL: wrap
   result via `.wrap_labelled()`.
3. If `.factor = FALSE` and both label args are NULL:
   - If `.description` is non-NULL: `attr(result, "surveytidy_recode") <- list(description = .description)`; return result.
   - Otherwise: return result unchanged (identical to `dplyr::recode_values()`
     behavior).

### VIII.6 Error Table

| Class | Trigger |
|---|---|
| `surveytidy_error_recode_label_not_scalar` | `.label` not NULL and not character(1) — validated by `.validate_label_args()` (§X.3) |
| `surveytidy_error_recode_value_labels_unnamed` | `.value_labels` not NULL and unnamed — validated by `.validate_label_args()` (§X.3) |
| `surveytidy_error_recode_description_not_scalar` | `.description` not NULL and not character(1) — validated by `.validate_label_args()` (§X.3) |
| `surveytidy_error_recode_factor_with_label` | `.factor = TRUE` and `.label` non-NULL |
| `surveytidy_error_recode_from_to_missing` | `from` is NULL and `.use_labels = FALSE` |
| `surveytidy_error_recode_use_labels_no_attrs` | `.use_labels = TRUE` but `attr(x, "labels")` is NULL |
| `surveytidy_error_recode_unmatched_values` | `.unmatched = "error"` and some values in `x` are not in `from` |

---

## IX. replace_values()

**No `.factor` argument** — `replace_values()` is type-stable (output type
matches input `x`). To produce a factor, apply `base::factor()` after the
mutation.

### IX.1 Signature

```r
replace_values(
  x,
  ...,
  from = NULL,
  to = NULL,
  .label = NULL,
  .value_labels = NULL,
  .description = NULL
)
```

### IX.2 Argument Table

| Argument | Type | Default | Description |
|---|---|---|---|
| `x` | vector | — | Input vector. Required. |
| `...` | — | — | Additional args passed to `dplyr::replace_values()`. |
| `from` | vector or NULL | `NULL` | Old values to replace. |
| `to` | vector or NULL | `NULL` | Replacement values. Same length as `from`. |
| `.label` | character(1) or NULL | `NULL` | Variable label for the output column. If NULL, the variable label is inherited from `attr(x, "label")` when available. |
| `.value_labels` | named vector or NULL | `NULL` | Value labels. Merged with labels retained from `x`. `.value_labels` overrides for matching values. |
| `.description` | character(1) or NULL | `NULL` | Plain-language description of the replacement logic. Stored in `@metadata@transformations[[col]]$description`. |

### IX.3 Core Delegation

`replace_values(x, from, to)` delegates to `dplyr::replace_values()` directly:

```r
dplyr::replace_values(x, from = from, to = to, ...)
```

`dplyr::replace_values()` preserves unmatched values (equivalent to
`default = x`) and handles type coercion via vctrs internally.

### IX.4 Output Contract

1. Call `dplyr::replace_values(x, from = from, to = to)` (no internal impl —
   see §IX.3).
2. Determine output labels: `merged_labels <- .merge_value_labels(attr(x, "labels"), .value_labels)` (§X.4).
3. Resolve effective variable label: `effective_label <- if (!is.null(.label)) .label else attr(x, "label")`.
4. If `merged_labels` is non-NULL or `effective_label` is non-NULL: wrap via
   `.wrap_labelled(result, label = effective_label, value_labels = merged_labels, description = .description)`.
5. Otherwise: if `.description` is non-NULL, set
   `attr(result, "surveytidy_recode") <- list(description = .description)`;
   return plain vector.

No `.factor` argument — type-stable.

### IX.5 Error Table

| Class | Trigger |
|---|---|
| `surveytidy_error_recode_label_not_scalar` | `.label` not NULL and not character(1) — validated by `.validate_label_args()` (§X.3) |
| `surveytidy_error_recode_value_labels_unnamed` | `.value_labels` not NULL and unnamed — validated by `.validate_label_args()` (§X.3) |
| `surveytidy_error_recode_description_not_scalar` | `.description` not NULL and not character(1) — validated by `.validate_label_args()` (§X.3) |

---

## X. Internal Helpers in R/recode.R

### X.1 .wrap_labelled()

```r
.wrap_labelled <- function(x, label, value_labels, description = NULL)
# x            : result vector
# label        : character(1) or NULL
# value_labels : named vector or NULL
# description  : character(1) or NULL — the .description arg from the caller
# Returns      : haven::labelled(x, labels = value_labels, label = label)
#                if either arg is non-NULL; x unchanged otherwise.
#                Always sets attr(result, "surveytidy_recode") <- list(description = description)
#                on the returned object so .extract_labelled_outputs() can identify
#                recode function outputs and extract the description for the
#                transformation record. .strip_label_attrs() removes this attr
#                before @data is stored.
```

For recode function outputs that use surveytidy args but do NOT go through
`.wrap_labelled()` (factor outputs; plain-vector outputs with only
`.description`), the caller sets the attr directly:

```r
attr(result, "surveytidy_recode") <- list(description = .description)
```

The rule: `surveytidy_recode` attr is set on any output where at least one of
`.label`, `.value_labels`, `.description` is non-NULL, OR `.factor = TRUE`.
When none of these surveytidy args are used, the output is identical to the
dplyr equivalent (no extra attrs).

### X.2 .factor_from_result()

```r
.factor_from_result <- function(x, value_labels, formula_values)
# x             : result vector (after calling dplyr)
# value_labels  : named vector or NULL (.value_labels argument)
# formula_values: character vector of unique output values; derived by the caller:
#                   - case_when(): all-literal path → formula-order literals
#                                  any-non-literal path → appearance-order from result
#                                  (see §IV.3 step 3 for detection logic)
#                   - recode_values(): always unique(to) (trivial)
# Returns       : factor
#   levels = names(value_labels) if value_labels non-NULL
#   levels = formula_values (in their given order) otherwise
```

Called by `case_when()` and `recode_values()` when `.factor = TRUE`.

### X.3 .validate_label_args()

```r
.validate_label_args <- function(label, value_labels, description = NULL)
# label        : any — the .label argument value from the caller
# value_labels : any — the .value_labels argument value from the caller
# description  : any — the .description argument value from the caller
# Returns      : invisible(TRUE) on success
# Errors       : surveytidy_error_recode_label_not_scalar
#                  if !is.null(label) && !(is.character(label) && length(label) == 1)
#                surveytidy_error_recode_value_labels_unnamed
#                  if !is.null(value_labels) && is.null(names(value_labels))
#                surveytidy_error_recode_description_not_scalar
#                  if !is.null(description) && !(is.character(description) && length(description) == 1)
```

Called at the start of every recode function (all 6). For functions that
accept `.label` and `.value_labels` (`case_when()`, `replace_when()`,
`if_else()`, `recode_values()`, `replace_values()`), pass all three args.
For `na_if()` (which has no `.label`/`.value_labels`), pass
`label = NULL, value_labels = NULL, description = .description` — only the
description check fires. Centralises all three validation conditions so they
are not duplicated inline in each function body.

Placement: in `R/recode.R` (single-file helper; does not go in `utils.R`
because it is only used within `recode.R`).

### X.4 .merge_value_labels()

```r
.merge_value_labels <- function(base_labels, override_labels)
# base_labels    : named vector or NULL — attr(x, "labels") from pre-attachment
# override_labels: named vector or NULL — the .value_labels argument from the caller
# Returns        : merged named vector — override_labels replace base_labels
#                  entries for matching values; remaining base_labels entries
#                  retained. Returns NULL if both inputs are NULL.
```

Merge logic:
- If both are NULL: return NULL.
- If `base_labels` is NULL: return `override_labels`.
- If `override_labels` is NULL: return `base_labels`.
- Otherwise: start from `base_labels`; for each name in `names(override_labels)`
  that matches a name in `base_labels`, replace that entry; append any
  `override_labels` entries whose names do not appear in `base_labels`.

Called by `replace_when()` (§V.4) and `replace_values()` (§IX.4).
Placement: in `R/recode.R` alongside the other single-file helpers.

---

## XI. Error/Warning Classes (New)

Add to `plans/error-messages.md` before implementation:

| Class | Source file | Trigger |
|---|---|---|
| `surveytidy_error_recode_label_not_scalar` | `R/recode.R` | `.label` is not NULL and not a character(1) |
| `surveytidy_error_recode_value_labels_unnamed` | `R/recode.R` | `.value_labels` is not NULL and has no names |
| `surveytidy_error_recode_factor_with_label` | `R/recode.R` | `.factor = TRUE` and `.label` is non-NULL |
| `surveytidy_error_recode_use_labels_no_attrs` | `R/recode.R` | `.use_labels = TRUE` but `attr(x, "labels")` is NULL |
| `surveytidy_error_recode_unmatched_values` | `R/recode.R` | `.unmatched = "error"` and unmatched values exist in `recode_values()` |
| `surveytidy_warning_mutate_structural_var` | `R/mutate.R` | User mutates a structural design variable (strata, PSU, FPC, or repweights) via `mutate()` |
| `surveytidy_error_recode_from_to_missing` | `R/recode.R` | `from` is NULL and `.use_labels = FALSE` in `recode_values()` |
| `surveytidy_error_recode_description_not_scalar` | `R/recode.R` | `.description` is not NULL and not a character(1) |

---

## XII. Testing Plan

**File:** `tests/testthat/test-recode.R`

### XII.1 Test Sections

```
1. mutate() pre-attachment
   - Labels available as attr(x, "labels") inside mutate() when @metadata
     has value_labels set
   - Variable label available as attr(x, "label") when @metadata has
     variable_labels set
   - Pre-attachment is a no-op when @metadata has no labels
   - All 3 design types

2. mutate() post-detection
   - haven_labelled output → value_labels stored in @metadata@value_labels
   - haven_labelled output → variable_label stored in @metadata@variable_labels
   - haven attr stripped from @data column after mutation
   - Non-labelled output overwrites unlabelled column → @metadata unchanged
   - Non-labelled output overwrites a previously-labelled column → @metadata
     clears old variable_labels and value_labels for that column
   - All 3 design types

2b. mutate() step 1 — design variable warnings
   - Mutating strata column → surveytidy_warning_mutate_structural_var (dual
     pattern: expect_warning(class=) + expect_snapshot(warning=TRUE))
   - Mutating PSU column → surveytidy_warning_mutate_structural_var
   - Mutating FPC column → surveytidy_warning_mutate_structural_var
   - Mutating repweights column (replicate design) → surveytidy_warning_mutate_structural_var
   - Mutating weight column → surveytidy_warning_mutate_weight_col (confirm
     existing Phase 0.5 test still fires after step 1 extension)
   - All 3 design types for each structural-var warning test

3. case_when()
   - Happy path: basic case_when, no label args → plain output (identical to
     dplyr::case_when behavior)
   - .label sets variable label extracted into @metadata
   - .value_labels sets value labels extracted into @metadata
   - .factor = TRUE returns factor with correct levels (from .value_labels order)
   - .factor = TRUE without .value_labels: levels in formula appearance order
   - All 3 design types
   - Error: .label not scalar → surveytidy_error_recode_label_not_scalar
   - Error: .value_labels unnamed → surveytidy_error_recode_value_labels_unnamed
   - Error: .factor = TRUE + .label → surveytidy_error_recode_factor_with_label
   - dplyr type-mismatch errors propagate unchanged
   - Domain column preserved through mutate + case_when

4. replace_when()
   - Happy path, no labels → plain output
   - Label inheritance from x (carried via pre-attachment)
   - .value_labels merge overrides matching entries, retains others
   - All 3 design types
   - Error: .label not scalar → surveytidy_error_recode_label_not_scalar
   - Error: .value_labels unnamed → surveytidy_error_recode_value_labels_unnamed

5. if_else()
   - Happy path, no labels → plain output (identical to dplyr::if_else)
   - .label and .value_labels set metadata via post-detection
   - All 3 design types
   - Error: .label not scalar → surveytidy_error_recode_label_not_scalar
   - Error: .value_labels unnamed → surveytidy_error_recode_value_labels_unnamed

6. na_if()
   - .update_labels = TRUE removes label entry for y from value_labels
   - .update_labels = FALSE retains label entry for y
   - y is a vector: all matching label entries removed
   - x with no labels: returns plain vector (no labelled wrapping)
   - All 3 design types
   - Error: .update_labels = "yes" (non-logical) → expect_error() [rlang error; no surveytidy class]
   - Error: .update_labels = c(TRUE, FALSE) (length > 1) → expect_error() [rlang error; no surveytidy class]

7. recode_values()
   - Happy path (explicit from/to)
   - .use_labels = TRUE reads attr(x, "labels") to build from/to
   - .use_labels = TRUE with no labels → surveytidy_error_recode_use_labels_no_attrs
   - unmatched = "error" with unmatched values → surveytidy_error_recode_unmatched_values
   - .factor = TRUE returns factor with correct levels
   - .factor = TRUE + .label → surveytidy_error_recode_factor_with_label
   - Error: from = NULL and .use_labels = FALSE → surveytidy_error_recode_from_to_missing
   - All 3 design types

8. replace_values()
   - Happy path, no labels
   - .value_labels merge with x labels
   - All 3 design types
   - Error: .label not scalar → surveytidy_error_recode_label_not_scalar
   - Error: .value_labels unnamed → surveytidy_error_recode_value_labels_unnamed

9. Domain preservation
   - Use `filter(d, y1 > 40)` first to create a non-trivial domain column
     before calling `mutate()`. Assert that the domain column in
     `result@data` is identical to the domain column in the filtered input.
   - Domain column present and unchanged after mutate + each recode function
   - Existing domain column values not modified by labelled output processing

10. Backward compatibility (shadowing)
    - case_when() with no surveytidy args: output identical to dplyr::case_when()
    - if_else() with no surveytidy args: output identical to dplyr::if_else()
    - na_if() with no surveytidy args: output identical to dplyr::na_if()

11. .description argument (all 6 functions)
    - .description stored in @metadata@transformations[[col]]$description
    - .description = NULL → transformations record has description = NULL
    - .description not character(1) → surveytidy_error_recode_description_not_scalar
    - Backward compat: no surveytidy args (no .description) → no surveytidy_recode attr set

12. Error snapshots
    - expect_snapshot(error = TRUE) for each class in §XI
```

### XII.2 Data Setup

Use `make_all_designs(seed = 42)` as the base. For label-aware tests, set up
value labels before calling `mutate()`.

> ⚠️ GAP: Confirm `surveycore::set_val_labels()` (or equivalent) is an exported
> function in surveycore 0.0.0.9000. If not exported, manipulate
> `@metadata@value_labels` directly in test setup (acceptable since tests
> legitimately need to set internal state).

Call `test_invariants(result)` as the first assertion in every `test_that()`
block that returns a survey object from `mutate()`.

**Extend `test_invariants()` in `helper-test-data.R`** to include the
`surveytidy_recode` attr lifecycle invariant: after any verb completes, no
column in `result@data` should carry a `"surveytidy_recode"` attribute. Add:

```r
# surveytidy_recode attr must be stripped before @data is stored
for (col in names(result@data)) {
  expect_null(
    attr(result@data[[col]], "surveytidy_recode"),
    label = paste0("@data[[\"", col, "\"]] must not carry surveytidy_recode attr")
  )
}
```

This applies automatically to all tests that call `test_invariants()` — no
individual test needs to add it explicitly. It will catch any regression where
`.strip_label_attrs()` fails to remove the attr before `@data` is stored.

---

## XIII. Quality Gates

All gates must pass before opening a PR:

- [ ] `devtools::check()` — 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::test()` — all tests pass
- [ ] Coverage ≥95% for all new/modified code
- [ ] `plans/error-messages.md` updated with all 8 new error/warning classes (§XI)
      before any code is written
- [ ] `DESCRIPTION` updated: `haven (>= 2.5.0)` in Imports, `dplyr (>= 1.2.0)` pin bumped
- [ ] No custom vector implementations — `replace_when`, `recode_values`,
      `replace_values` each delegate to their dplyr 1.2.0 counterparts (no `case_match()`)
- [ ] Backward compatibility verified: `case_when`, `if_else`, `na_if` without
      label args produce output identical to dplyr equivalents (section 10 tests)
- [ ] GAP in §III.2 step 8 (transformations log format) resolved — ✅ format
      specified above (fn, source_cols, expr, output_type, description)
- [ ] GAP in §XII.2 (set_val_labels export) resolved
- [ ] GAP in §VIII.3 (dplyr unmatched error class) resolved — verify the exact
      condition class for unmatched-values errors in dplyr 1.2.0 source and
      update the `inherits(e, "dplyr_error_recode_unmatched")` call
- [ ] `@examples` in `R/recode.R` include `library(dplyr)` where needed
      (per CLAUDE.md R CMD check convention)
- [ ] `air format .` run before final commit

---

## XIV. Integration

### XIV.1 surveycore API Used

| API | Where used |
|---|---|
| `surveycore::survey_base` | `mutate.survey_base()` (existing) |
| `surveycore::SURVEYCORE_DOMAIN_COL` | domain preservation (existing) |
| `@metadata@variable_labels` | `.attach_label_attrs()`, `.extract_labelled_outputs()` |
| `@metadata@value_labels` | `.attach_label_attrs()`, `.extract_labelled_outputs()` |
| `@metadata@transformations` | `mutate.survey_base()` (existing, unchanged) |

### XIV.2 haven API Used

| API | Where used |
|---|---|
| `haven::labelled()` | `.wrap_labelled()` in `R/recode.R` |
| `haven::zap_labels()` | `.strip_label_attrs()` in `R/utils.R` |

### XIV.3 dplyr API Used

| Function | Used by | dplyr version |
|---|---|---|
| `dplyr::case_when()` | `case_when()` | ≥ 1.1.0 ✓ |
| `dplyr::if_else()` | `if_else()` | ≥ 1.1.0 ✓ |
| `dplyr::na_if()` | `na_if()` | ≥ 1.1.0 ✓ |
| `dplyr::replace_when()` | `replace_when()` | ≥ 1.2.0 ✓ |
| `dplyr::recode_values()` | `recode_values()` | ≥ 1.2.0 ✓ |
| `dplyr::replace_values()` | `replace_values()` | ≥ 1.2.0 ✓ |

Note: `dplyr::case_match()` is NOT used — soft-deprecated in dplyr 1.2.0.

---

*This is a first draft. I expect there are gaps — run Stage 2 in a new session
to get an adversarial methodology review before resolving anything.*
