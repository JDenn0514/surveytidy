## Methodology Review: recode — Pass 1 (2026-03-09)

### New Issues

#### Lens 1 — Domain Semantics

**Issue 1: Domain column handling in new mutate steps is implicit, not stated**
Severity: SUGGESTION
Lens: 1 — Domain Semantics
Resolution type: UNAMBIGUOUS

The spec adds three new steps to `mutate.survey_base()`: `.attach_label_attrs()`,
`.extract_labelled_outputs()`, and `.strip_label_attrs()`. None of these steps
mention the domain column (`..surveycore_domain..`).

The domain column is a plain logical column in `@data` with no `@metadata`
entries. As a consequence:
- `.attach_label_attrs()` does not attach any attrs to it (only touches columns
  with `@metadata` entries) — correct, but not stated.
- `.extract_labelled_outputs()` does not update `@metadata` for it — correct,
  but not stated.
- `.strip_label_attrs()` calls `haven::zap_labels()` on every column including
  the domain column — a no-op since a plain logical carries no haven attrs, but
  not confirmed in the spec.

The domain column also lacks any guard in step 6 (re-attach protected columns).
Whether the domain column is in `.protected_cols()` is not addressed by this
spec (it is a Phase 0.5 concern, but since mutate is being modified, confirming
the existing guard still holds is warranted).

An implementer following the spec as written would likely get this right, but
it relies on implicit reasoning rather than explicit contract.

Options:
- **[A]** Add a one-sentence note in §III.3 and §III.5 confirming the domain
  column is unaffected by pre-attachment and strip (it has no `@metadata`
  entries and no haven attrs). Effort: low, Risk: low, Impact: eliminates
  implementer doubt.
- **[B]** Add an explicit guard in `.attach_label_attrs()` that skips
  `SURVEYCORE_DOMAIN_COL`. Effort: low, Risk: low, Impact: defensive but
  unnecessary if the filter-by-metadata-presence logic is correct.
- **[C] Do nothing** — the implicit reasoning is sound; no test will fail
  without this clarification.

**Recommendation: A** — A sentence costs nothing and eliminates the implicit
reasoning chain an implementer must reconstruct.

---

#### Lens 2 — Row Universe Integrity

No issues found. All six recode functions operate on plain vectors inside
`mutate()`. None can add or remove rows. The pre-attachment, post-detection,
and strip steps operate on column attributes, not rows. `dplyr::mutate()` is
row-preserving by definition.

---

#### Lens 3 — Design Variable Integrity

**Issue 2: Pre-attachment type contract is internally inconsistent**
Severity: REQUIRED
Lens: 3 — Design Variable Integrity
Resolution type: UNAMBIGUOUS

§III.3 contains two contradictory claims about what `.attach_label_attrs()` produces:

**Claim A (pseudocode):**
```r
attr(data[[col]], "labels") <- metadata@value_labels[[col]]
attr(data[[col]], "label")  <- metadata@variable_labels[[col]]
```
Setting these attributes does NOT give `x` the `"haven_labelled"` class. The
result is a plain vector with non-standard attributes.

**Claim B (side-effect note in §III.3):**
> "class() will include 'haven_labelled'."

This claim is false for the pseudocode shown. `attr<-` does not set class.

This inconsistency has practical consequences for implementers:

1. If the pseudocode is authoritative, recode functions must use `attr(x,
   "labels")` (not `inherits(x, "haven_labelled")`) to detect pre-attached
   labels. The spec already does this correctly in §VII.3 (`na_if`) and §V.4
   (`replace_when`). But implementers reading §III.3's class claim may use
   `inherits()` for INPUT detection — which would always return FALSE and break
   label inheritance.

2. If Claim B is authoritative, `.attach_label_attrs()` must call
   `haven::labelled()` to create proper haven_labelled objects — which attaches
   the full `"haven_labelled"` class to every column with metadata. This gives
   those columns a different class signature inside `dplyr::mutate()`, which
   could cause unexpected dispatch in third-party functions.

3. The post-detection step uses `inherits(data[[col]], "haven_labelled")` for
   OUTPUT detection. This is correct regardless of which approach is used for
   pre-attachment, because recode function OUTPUTS are created via
   `.wrap_labelled()` / `haven::labelled()` and are always proper haven_labelled
   objects.

The fix is to pick one approach and remove the contradictory claim.

Options:
- **[A]** Keep the pseudocode (attr-only, no class change). Remove the
  "class() will include 'haven_labelled'" sentence from §III.3. Replace with:
  "Columns gain `'labels'` and `'label'` attributes but NOT the `'haven_labelled'`
  class. Recode functions detect pre-attached labels via `attr(x, 'labels')`,
  not via `inherits()`." Effort: low, Risk: low, Impact: consistent with
  recode function input-detection contracts already in §V.4 and §VII.3.
- **[B]** Change pre-attachment to use `haven::labelled()` for columns that
  have value_labels, creating proper haven_labelled objects. Update §III.3 to
  match. Effort: medium, Risk: medium (haven_labelled class can cause dispatch
  surprises in third-party functions used inside mutate). Impact: true
  haven_labelled inputs for recode functions.
- **[C] Do nothing** — leaves contradictory claims in the spec; the first
  implementer to read it will choose an interpretation and get one thing wrong.

**Recommendation: A** — attr-only pre-attachment is simpler, avoids class
dispatch surprises, and is consistent with how the recode functions already
detect labels via `attr()`.

---

**Issue 3: No warning specified for recoding strata, PSU, or FPC columns**
Severity: REQUIRED
Lens: 3 — Design Variable Integrity
Resolution type: JUDGMENT CALL

Phase 0.5 introduced `surveytidy_warning_mutate_weight_col`, which fires when
the user modifies the weight column via `mutate()`. This spec inherits that
behavior (step 1 of the new flow is "unchanged").

However, the spec is silent on what happens when a user recodes a strata,
PSU, or FPC column via one of the new recode functions:

```r
mutate(d,
  strata = recode_values(strata, from = c(1,2,3), to = c("A","A","B")),
  psu    = case_when(TRUE ~ 1L)
)
```

Recoding a weight column changes effective sample size but the design
structure (strata, PSU assignments) survives. Recoding strata or PSU values
fundamentally changes the probability model — collapsed strata invalidate
variance estimates in a way that is not immediately obvious and produces no
downstream error.

The Phase 0.5 spec apparently only warns for weight columns. This spec
introduces recode functions that make it dramatically easier to accidentally
recode structural design variables. The absence of a spec position on this
leaves an implementer with two choices:
1. Use only the inherited weight-column warning (silent failure for strata/PSU)
2. Extend the warning to cover all design variables (blocking more use cases)

Both are defensible, but the spec must take a position.

Options:
- **[A]** Extend the design variable modification warning to cover ALL design
  variables (weights, strata, PSU, FPC, repweights) with a generalized
  `surveytidy_warning_mutate_design_var` class. Keep `surveytidy_warning_mutate_weight_col`
  as an alias or use the new class for both. Add to `plans/error-messages.md`.
  Effort: medium (requires updating mutate.R from Phase 0.5), Risk: low,
  Impact: users are informed whenever they modify any design variable.
- **[B]** Extend warnings to structural variables only (strata, PSU, FPC,
  repweights) — use a distinct class `surveytidy_warning_mutate_structural_var`
  to distinguish from weight modification. The message can be more alarming
  for structural variables. Effort: medium, Risk: low, Impact: differentiates
  weight modification (dangerous but recoverable) from structural modification
  (potentially invalidates the probability model).
- **[C]** Explicitly scope Phase 0.6 to inheriting Phase 0.5 behavior only
  (weight warning, silence for structural variables). Document this as a known
  gap in the spec and defer to Phase 0.7 or later. Effort: low (just document
  it), Risk: medium (users who recode strata get no warning), Impact: leaves
  the gap, but at least it's a deliberate decision.

**Recommendation: B** — Differentiating weight vs. structural modification is
the methodologically correct distinction. Phase 0.6 introduces recode functions
that make structural variable modification much easier; not extending warnings
at the same time is a missed opportunity.

---

#### Lens 4 — Variance Estimation Validity

No new issues beyond Issue 3. The recode functions operate on plain vectors;
`@variables` is not modified by any recode operation (only `@metadata` is
updated via post-detection). The variance estimator continues to locate design
variable columns by their names from `@variables`, which are unchanged. After
`.strip_label_attrs()`, all columns in `@data` are plain R vectors — the
estimator sees no change in column types.

The `@groups` property is not touched by any new step. `@variables$domain` is
not touched by the new mutate steps (it is only modified by `filter()`).

---

#### Lens 5 — Structural Transformation Validity

**Issue 4: Stale @metadata when a column is overwritten with non-labelled output**
Severity: REQUIRED
Lens: 5 — Structural Transformation Validity
Resolution type: JUDGMENT CALL

§XII test section 2 specifies: "Non-labelled output → @metadata unchanged,
@data stays plain." This IS the stated behavior, but the spec does not
acknowledge the stale metadata consequence.

Concrete scenario:
1. User calls `set_var_label(d, group, "Treatment group")` and
   `set_val_labels(d, group, c("Treatment" = 1, "Control" = 2))`.
2. `@metadata@variable_labels$group` = `"Treatment group"`.
   `@metadata@value_labels$group` = `c("Treatment" = 1, "Control" = 2)`.
3. User calls `mutate(d, group = recode_values(group, from = c(1,2), to = c("T","C")))`.
4. `recode_values()` without label args returns a plain character vector.
5. Post-detection: `group` output is NOT `haven_labelled` → `@metadata` unchanged.
6. Result: `@data$group` = `c("T","C","T",...)` (characters). `@metadata@value_labels$group` = `c("Treatment" = 1, "Control" = 2)` (STALE — numeric codes for a character column).

The stale value labels are now semantically incorrect: they reference numeric
codes that no longer exist in the column. Any downstream use of
`@metadata@value_labels$group` (for display, export, or label-reading) will
produce wrong output. No error or warning is issued.

An implementer who follows the spec as written and the test as specified would
implement exactly this behavior, pass all tests, and ship stale metadata.

This is a judgment call about the right design, not a bug with an obvious fix.

Options:
- **[A]** Retain old metadata when non-labelled output is returned (current
  spec behavior). Rationale: the user chose not to supply label args, so label
  state is preserved from before the mutation. Effort: none (current spec),
  Risk: medium (stale labels silently present), Impact: simple; users must
  clear labels manually with `set_val_labels(d, group, NULL)` if they want to
  clear them.
- **[B]** Clear `@metadata@variable_labels[[col]]` and
  `@metadata@value_labels[[col]]` for any column in `changed_cols` when the
  output is not `haven_labelled`. Rationale: the column was explicitly
  overwritten; old labels are no longer valid. Effort: low (two additional
  lines in `.extract_labelled_outputs()`), Risk: low, Impact: clean metadata
  after recode; users who want to preserve labels must pass label args.
- **[C]** Issue a `surveytidy_warning_recode_stale_metadata` warning when a
  column with existing metadata is overwritten with non-labelled output.
  Effort: medium, Risk: low, Impact: noisy for users who legitimately overwrite
  labelled columns without intending to preserve labels.

**Recommendation: B** — Explicit overwrite of a column should clear its old
labels. The user explicitly wrote `group = recode_values(...)`, replacing the
column; retaining pre-existing labels for a structurally different column is
confusing. If users want to preserve labels, the label args exist for that
purpose. Update §XII test section 2 to test that old labels are cleared.

---

**Issue 5: `_impl` function references in §V.4 and §IX.4 are undefined**
Severity: REQUIRED
Lens: 5 — Structural Transformation Validity
Resolution type: UNAMBIGUOUS

§V.4 (`replace_when()` output contract) says:
> "Call `.replace_when_impl(x, ...)`.

§IX.4 (`replace_values()` output contract) says:
> "Call `.replace_values_impl(x, from = from, to = to, ...)`.

Neither `.replace_when_impl()` nor `.replace_values_impl()` is defined in §X
(Internal Helpers). §X defines only `.wrap_labelled()` and `.factor_from_result()`.

This creates a contradiction with §V.3, which says:
> "`replace_when(x, cond1 ~ val1, cond2 ~ val2)` delegates to
> `dplyr::case_when(cond1 ~ val1, cond2 ~ val2, .default = x)`.
> No internal implementation needed."

§II.2 also says these three functions "delegate directly to these native
[dplyr 1.2.0] functions — no custom implementations needed."

An implementer reading §V.4 would create `.replace_when_impl()` as an internal
function; an implementer reading §V.3 would not. The same contradiction
applies to `replace_values()` in §IX.3 vs §IX.4.

Additionally, §II.1 shows `replace_when()` as "Own implementation — identical
API" relative to `dplyr::replace_when()`, while §II.2's table and §V.3 say
it delegates to `dplyr::replace_when()` natively. Which is it?

Options:
- **[A]** Remove the `_impl` function references from §V.4 and §IX.4.
  Replace with direct delegation expressions: for `replace_when()`, show
  `dplyr::replace_when(x, ...)` (or `dplyr::case_when(..., .default = x)` if
  `dplyr::replace_when()` doesn't exist as a callable function). For
  `replace_values()`, show `dplyr::replace_values(x, from = from, to = to)`.
  Clarify §II.1 table to state "wraps `dplyr::replace_when()`" not "own
  implementation" if the function is delegated. Effort: low, Risk: low.
- **[B]** Formally define `.replace_when_impl()` and `.replace_values_impl()`
  in §X as thin wrappers around their dplyr counterparts. Effort: low, Risk:
  low, Impact: adds unnecessary abstraction for functions that are pure
  pass-throughs.
- **[C] Do nothing** — leaves the spec with undefined internal functions;
  the implementer invents something.

**Recommendation: A** — Remove the `_impl` references and use direct calls.
Thin-wrapper internal functions with no logic are noise.

---

**Issue 6: `recode_values()` error-catching is over-broad and may reclassify wrong errors**
Severity: REQUIRED
Lens: 5 — Structural Transformation Validity
Resolution type: JUDGMENT CALL

§VIII.3 defines the following error-catching pattern:

```r
tryCatch(
  dplyr::recode_values(x, from = from, to = to, default = default,
                       .unmatched = .unmatched, ptype = ptype),
  error = function(e) {
    if (.unmatched == "error") {
      cli::cli_abort(
        c("x" = "Some values in {.arg x} were not found in {.arg from}.",
          "i" = "Set {.code .unmatched = \"default\"} to keep unmatched values."),
        class = "surveytidy_error_recode_unmatched_values",
        parent = e
      )
    }
    stop(e)
  }
)
```

The `tryCatch` handler catches ALL errors from `dplyr::recode_values()`, not
just unmatched-values errors. If `.unmatched = "error"` and dplyr throws a
type-mismatch error (e.g., `from` and `x` have incompatible types), the
handler catches it and rethrows it as `surveytidy_error_recode_unmatched_values`
— the wrong error class for a type mismatch. The user gets a message about
unmatched values when their actual problem is a type mismatch.

When `.unmatched = "default"`, any error from dplyr is correctly re-thrown via
`stop(e)`. But when `.unmatched = "error"`, any error (including type errors)
is silently reclassified.

Options:
- **[A]** Inspect the condition class or message of `e` to determine whether
  it is an unmatched-values error before rethrowing. If dplyr's
  unmatched-values error has a specific class (e.g., from rlang's condition
  system), check `inherits(e, "dplyr_error_...")`. If not, use
  `grepl("unmatched", conditionMessage(e))` as a fallback. Re-throw as
  `surveytidy_error_recode_unmatched_values` only for confirmed
  unmatched-values errors; re-throw all others via `stop(e)`. Effort: medium
  (requires identifying dplyr's condition class), Risk: low, Impact: correct
  error class routing.
- **[B]** Remove the `tryCatch` entirely. Pass `.unmatched` directly to
  `dplyr::recode_values()`. Accept that dplyr's unmatched-values error is
  rethrown with dplyr's own class and message. Only wrap if dplyr's class is
  not testable (i.e., not a stable public class). Add a note in the quality
  gates to verify the dplyr error class. Effort: low, Risk: medium (dplyr's
  error class may not be stable), Impact: loses `surveytidy_error_recode_unmatched_values`
  class — tests for that class fail.
- **[C]** Keep the over-broad catch but add a guard: check
  `grepl("unmatched|not found", conditionMessage(e))` before reclassifying.
  Effort: low, Risk: low (heuristic but adequate for the common case),
  Impact: type errors are no longer misclassified as unmatched-value errors.

**Recommendation: A** — Identify dplyr's error condition class (likely a
stable rlang class). Gate the reclassification on that class. Document the
dplyr class in a comment so it's easy to update if it changes.

---

**Issue 7: S7 validator intermediate state in .extract_labelled_outputs()**
Severity: SUGGESTION
Lens: 5 — Structural Transformation Validity
Resolution type: UNAMBIGUOUS

`.extract_labelled_outputs()` updates `metadata@variable_labels[[col]]` and
`metadata@value_labels[[col]]` for each changed column. Since `metadata` is an
S7 object, each `@<-` assignment may trigger the S7 class validator.

The MEMORY.md documents that `rename()` required a validator bypass
(`attr(.data, "variables") <- ...` + `S7::validate()`) because intermediate
states after each `@<-` assignment were invalid.

If the `@metadata` S7 validator enforces cross-field consistency (e.g., all
keys in `variable_labels` must also exist in the data, or similar), then
`.extract_labelled_outputs()` may trigger validation errors between the
`variable_labels` update and the `value_labels` update for the same column.

The spec says `.extract_labelled_outputs()` receives and returns a `metadata`
object (passed by value). Since R uses copy-on-modify, the local mutations
in the function body don't assign back to `.data@metadata` until the final
`@data@metadata <- updated_metadata` assignment. S7 validation fires on
each `@<-` assignment to the S7 object returned to `.data`.

If the whole `updated_metadata` is assigned in one `@<-` call at the end of
`mutate.survey_base()`, and the fully updated `metadata` is valid, then only
one validation fires and it's on a consistent state. The spec should confirm
this is the implementation pattern.

Options:
- **[A]** Add a note in §III.4 confirming that `.extract_labelled_outputs()`
  returns a fully updated `metadata` object (not modifying `.data@metadata`
  in-place) and that the single final assignment to `.data@metadata` triggers
  only one S7 validation on a fully consistent state. Effort: none,
  Risk: none, Impact: eliminates implementer uncertainty.
- **[B]** Do nothing — the S7 copy-on-modify semantics handle this correctly
  without documentation.

**Recommendation: A** — Given the documented rename() S7 bypass issue in
MEMORY.md, this is worth one confirming sentence.

---

### Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 5 |
| SUGGESTION | 2 |

**Total issues:** 7

**Overall assessment:** The spec's domain semantics are sound — the recode
functions are vector-level and pose no domain column or row-universe risks.
The five required issues center on three fixable contradictions (the
pre-attachment type contract, the `_impl` function references, the
`recode_values()` error-catch scope) and two deliberate design choices that
need explicit positions (stale metadata retention and the strata/PSU warning
gap). None of these would cause wrong variance estimates, but two of them
(stale metadata and structural variable warning absence) would silently produce
incorrect label state or leave users unwarned when they modify design structure.
The spec is ready for Stage 2 Resolve after these issues are addressed.
