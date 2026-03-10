## Spec Review: recode — Pass 1 (2026-03-09)

---

#### Section: II — Architecture (§II.1, §II.2, §V.3)

**Issue 1: replace_when() delegation target is inconsistent across three spec sections** ✅ RESOLVED (2026-03-09) — Option A: delegate to `dplyr::replace_when()` directly. §II.1 table, §V.3, and §V.4 step 1 all updated to say `dplyr::replace_when()`. Spec v0.4.
Severity: REQUIRED
Violates engineering-preferences.md §5 (explicit over clever); DRY (§II.1, §II.2, §V.3 all describe the same function differently).

§II.1 marks `replace_when()` as `"Own implementation — identical API"`. §II.2 says it
`"Delegates to dplyr::replace_when()"`. §V.3 says it `"delegates to dplyr::case_when(cond1 ~ val1, ..., .default = x). No internal implementation needed."` These are three different descriptions of the same function. Specifically:

- §II.2 claims delegation to `dplyr::replace_when()`
- §V.3 claims delegation to `dplyr::case_when()` with `.default = x`

These produce different behavior if `dplyr::replace_when()` has different semantics from the `case_when(.default = x)` workaround (e.g., different type-stability guarantees or argument handling for `...`). An implementer reading §V.3 writes a `case_when()` wrapper; an implementer reading §II.2 makes a direct `dplyr::replace_when()` call. The outputs may differ.

§II.1's `"Own implementation"` label is also wrong regardless — the function is a wrapper, not an independent implementation. (`dplyr::replace_when()` exists in dplyr 1.2.0 and is the natural delegation target.)

Options:
- **[A]** Resolve: delegate to `dplyr::replace_when()` directly. Drop the `dplyr::case_when(.default = x)` workaround in §V.3. Update §II.1 table to say `"Wraps dplyr::replace_when()"` and update §V.3 to show the direct delegation call. Effort: low, Risk: low.
- **[B]** Keep the `case_when(.default = x)` workaround and update §II.1 and §II.2 to match. Effort: low, Risk: low.
- **[C] Do nothing** — leaves three contradictory descriptions; implementer chooses whichever they read first.

**Recommendation: A** — `dplyr::replace_when()` exists in dplyr 1.2.0; delegate to it directly. Remove the intermediate workaround and make all three sections consistent.

---

#### Section: III–IV — mutate() changes and case_when() (.factor path)

**Issue 2: §IV.3 says factor output bypasses post-detection; §III.4 (updated by Issue 4 resolution) clears metadata for any non-tagged column in changed_cols** ✅ RESOLVED (2026-03-09) — Option A + extended: §IV.3 step 3 updated to say factors get `surveytidy_recode` attr set (because `.factor = TRUE` is a surveytidy arg), so post-detection processes them via the `surveytidy_recode` path and clears old labels. Also resolved the GAP in §III.2 step 8: transformation record format specified (fn, source_cols, expr, output_type, description). New `.description = NULL` argument added to all 6 function signatures for codebook/plain-language attribution. New error class `surveytidy_error_recode_description_not_scalar` added to §XI. `surveytidy_recode` attr changed from `TRUE` to `list(description = .description)` throughout. Spec v0.4.
Severity: REQUIRED
Violates code-style.md (explicit contracts); testing-standards.md §3 (contract must be unambiguous).

§IV.3 step 3 states:
> "convert result to factor via `.factor_from_result()` and return. Factors are not `haven_labelled`
> and are not picked up by the post-detection step."

§III.4 (post-detection, updated by Issue 4 resolution) states:
> "Else if `col` has any existing entry in `metadata@variable_labels` OR `metadata@value_labels`
> (i.e., the column had labels before this mutate): clear both entries."

The "Else" branch fires when the column is in `changed_cols` AND its output is NOT tagged
`surveytidy_recode`. A factor output carries no `surveytidy_recode` attr (because `.wrap_labelled()`
is bypassed for factors). So §III.4 DOES process factors — it enters the "Else" branch and clears
old metadata.

§IV.3 says "not picked up by the post-detection step" — this is wrong after Issue 4 resolution.
The old metadata WILL be cleared. This statement was correct before Issue 4 was resolved but was not
updated when the spec was revised.

This matters for testing: an implementer following §IV.3 skips post-detection for factors, old labels
stay stale (exactly the bug Issue 4 resolved). An implementer following §III.4 gets the correct behavior.

Options:
- **[A]** Update §IV.3 to say: "Factors carry no `surveytidy_recode` attr. However, `.extract_labelled_outputs()`
  still processes them via the 'Else' branch in §III.4 — any pre-existing labels for the column are
  cleared. This is correct behavior: factor output replaces the column, so old labels are stale."
  Effort: low, Risk: low.
- **[B]** Change §III.4 to explicitly skip the metadata-clearing "Else" branch for factor columns.
  Effort: medium, Risk: medium (partial metadata clearing is harder to reason about; also contradicts
  the deliberate Issue 4 decision).
- **[C] Do nothing** — §III.4 and §IV.3 remain contradictory; implementer picks one.

**Recommendation: A** — §III.4's behavior (clear on non-tagged overwrite) is the deliberate Issue 4
resolution. §IV.3 needs to be updated to reflect it. Clearing old labels when a column is replaced
with a factor is correct.

---

#### Section: XII — Testing Plan (§XII.1 sections 4, 5, 8)

**Issue 3: replace_when(), if_else(), and replace_values() have no error tests in the test plan**
Severity: REQUIRED
Violates testing-standards.md §2 ("every exported function must have tests in all three categories
[including error paths]"); testing-surveytidy.md (dual pattern required for all user-facing errors).

`replace_when()` has 2 error classes (§V.5): `surveytidy_error_recode_label_not_scalar`,
`surveytidy_error_recode_value_labels_unnamed`. §XII.1 section 4 lists only happy-path and
label-inheritance tests — no error tests.

`if_else()` has 2 error classes (§VI.4): same two classes. §XII.1 section 5 lists only
happy-path tests — no error tests.

`replace_values()` has 2 error classes (§IX.5): same two classes. §XII.1 section 8 lists
only happy-path and label-merge tests — no error tests.

That is 6 untested error cases across 3 functions. Each requires both `expect_error(class=)` AND
`expect_snapshot(error=TRUE)` per the dual-pattern requirement. Note: `case_when()` (section 3) and
`recode_values()` (section 7) DO list error tests — the omission is inconsistent.

Options:
- **[A]** Add error test bullets to sections 4, 5, and 8:
  - `"Error: .label not scalar → surveytidy_error_recode_label_not_scalar"`
  - `"Error: .value_labels unnamed → surveytidy_error_recode_value_labels_unnamed"`
  in each of the three sections. Effort: low (spec edit only), Risk: none.
- **[B]** Consolidate all label-arg validation errors into a shared "label arg errors (all functions)"
  section at the top of §XII.1. Effort: low, Risk: low.
- **[C] Do nothing** — implementer writes no tests for these 6 error paths; coverage drops below 95%.

**Recommendation: A** — Add the missing error test bullets explicitly to each function's section.

---

#### Section: IV–IX — All recode functions (label arg validation)

**Issue 4: Same .label/.value_labels validation is specified 5 times with no direction to extract a shared validator**
Severity: REQUIRED
Violates engineering-preferences.md §1 (DRY); code-style.md §4 (helpers used in 2+ files go in utils.R).

The validation conditions:
```
if !is.null(.label) && !(is.character(.label) && length(.label) == 1)
  → surveytidy_error_recode_label_not_scalar

if !is.null(.value_labels) && is.null(names(.value_labels))
  → surveytidy_error_recode_value_labels_unnamed
```

appear identically in §IV.4, §V.5, §VI.4, §VIII.5, and §IX.5. The spec does not say to extract a
shared `.validate_label_args()` internal helper, so an implementer following the spec will write
this check inline 5 times in the same file (`R/recode.R`).

If the error message changes or a third label arg is added, 5 places need updating.

Options:
- **[A]** Add §X.3 to the Internal Helpers section:
  ```r
  .validate_label_args <- function(label, value_labels)
  # label        : any, the .label argument value
  # value_labels : any, the .value_labels argument value
  # Returns      : invisible(TRUE) on success
  # Errors       : surveytidy_error_recode_label_not_scalar
  #                surveytidy_error_recode_value_labels_unnamed
  ```
  Update §IV.4, §V.5, §VI.4, §VIII.5, §IX.5 to say "validated by `.validate_label_args()`" rather
  than re-specifying conditions. Effort: low, Risk: low.
- **[B]** Consolidate error conditions into a single "shared label arg contract" subsection in §XI
  and cross-reference from each function section. Effort: low, Risk: low (documentation only).
- **[C] Do nothing** — 5x duplication; any change to validation logic requires 5 edits.

**Recommendation: A** — This is a direct DRY violation. `.validate_label_args()` is the obvious
extraction. Add it to §X and remove the repeated condition specs.

---

#### Section: VIII — recode_values()

**Issue 5: recode_values() from/to conditional-required enforcement is unspecified**
Severity: REQUIRED
Violates engineering-preferences.md §4 (handle more edge cases); contract completeness (Lens 3).

§VIII.2 states:
- `from`: "Must be supplied unless `.use_labels = TRUE`."
- `to`: "New values corresponding to `from`. Same length as `from`."

Both have `NULL` as default. If a user calls `recode_values(x, .use_labels = FALSE)` with no
`from`/`to`, the spec is silent about what happens. `dplyr::recode_values(x, from = NULL, to = NULL)`
will produce an error, but with dplyr's condition class — not a `surveytidy_error_*` class, so it is
untestable against the surveytidy error table.

Additionally, if `from` and `to` have different lengths, no validation is specified before delegating
to dplyr.

Options:
- **[A]** Add one new error condition to §VIII.5:
  `surveytidy_error_recode_from_to_missing` — triggered when `from` is NULL and `.use_labels = FALSE`.
  Add explicitly: "Length mismatch between `from` and `to` is delegated to dplyr (dplyr's error propagates)."
  Effort: low, Risk: low.
- **[B]** Add a note: "`from` and `to` are passed directly to `dplyr::recode_values()`. All
  validation (including missing-from-entirely and length mismatch) is delegated to dplyr. No
  surveytidy error class for these conditions." Explicitly document the gap. Effort: trivial.
- **[C] Do nothing** — arg table says "must be supplied" but gives no error class and no delegating
  note; implementer guesses.

**Recommendation: A** — The missing-from-entirely case is the most user-facing gap; it deserves a
surveytidy error class. Length mismatch is fine to delegate. Add one error class and one explicit
note about delegation.

---

#### Section: XIII — Quality Gates

**Issue 6: @metadata@transformations expansion GAP not in §XIII quality gates**
Severity: SUGGESTION
Violates engineering-preferences.md §5; §XIII is the authoritative pre-PR checklist.

§III.2 step 8 contains an inline GAP marker:
> "⚠️ GAP: Confirm the `@metadata@transformations` structure in surveycore 0.0.0.9000 before
> speccing the exact log format."

§XIII lists two GAP closures (set_val_labels export, dplyr unmatched error class) but does not
include this third GAP. An implementer running the §XIII checklist before opening a PR will not be
prompted to resolve the transformations format. The recode call logging will be guessed.

Options:
- **[A]** Add to §XIII: `[ ] GAP in §III.2 step 8 (transformations log format) resolved —
  confirm @metadata@transformations structure in surveycore 0.0.0.9000 and specify the exact
  entries logged per recode function call.` Effort: trivial.
- **[B]** Remove the transformations expansion from Phase 0.6. Phase 0.5 logging behavior is
  unchanged; defer to Phase 0.7.
- **[C] Do nothing** — GAP is inline but not in the checklist; likely missed.

**Recommendation: A** — All implementation GAPs belong in §XIII. One gate entry costs nothing.

---

#### Section: VII — na_if()

**Issue 7: .update_labels type not validated — non-logical input silently misbehaves**
Severity: SUGGESTION
Violates engineering-preferences.md §4 (handle more edge cases).

`.update_labels` is declared `logical(1)` in §VII.2 but §VII.4 says "No new error classes."
If a user passes `.update_labels = "yes"` or `.update_labels = c(TRUE, FALSE)`, R's implicit
coercion or length > 1 behavior produces unexpected results rather than an informative error.

Options:
- **[A]** Add a validation: if `!is.logical(.update_labels) || length(.update_labels) != 1`, error
  with `surveytidy_error_recode_update_labels_not_scalar`. Add to §VII.4 and §XI. Effort: low.
- **[B]** Add `rlang::check_scalar_bool(.update_labels)` call (no new error class; rlang's built-in
  check produces a standard rlang error). Add as step 0 in §VII.3. Effort: minimal.
- **[C] Do nothing** — trust user to pass logical(1); wrong values fail downstream with unclear messages.

**Recommendation: B** — `rlang::check_scalar_bool()` exists for exactly this purpose. No new error
class needed; add it to §VII.3 step 0.

---

#### Section: X / XII — Internal helpers and testing

**Issue 8: surveytidy_recode attr lifecycle invariant not stated as a required test assertion**
Severity: SUGGESTION
Violates testing-standards.md §3 (test the contract, not just the happy path).

The `surveytidy_recode` attr is central to the post-detection architecture: `.wrap_labelled()` sets
it, `.extract_labelled_outputs()` reads it, `.strip_label_attrs()` removes it. The invariant is:
**after `mutate()` completes, no column in `@data` carries a `surveytidy_recode` attr.**

If `.strip_label_attrs()` fails to remove this attr (e.g., because a future code path bypasses strip),
`@data` would carry a private internal attr in the stored survey object. No current test would catch
this regression.

Options:
- **[A]** Add to §XII.1 section 2 (post-detection): "After mutate() completes, assert no column
  in `result@data` carries a `'surveytidy_recode'` attribute." Effort: low.
- **[B]** Add this assertion to `test_invariants()` in `helper-test-data.R` so it applies
  automatically to all mutate() tests via the standard first-assertion rule. Effort: low,
  Impact: broader — no individual test needs to remember to add it.
- **[C] Do nothing** — attr leakage is not tested; silent corruption possible.

**Recommendation: B** — Adding this to `test_invariants()` makes it automatic for all mutate tests.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 5 |
| SUGGESTION | 3 |

**Total issues:** 8

**Overall assessment:** The spec is well-structured and the methodology lock resolved the most
significant domain and design-variable risks. No architectural guesses are needed from scratch —
but 5 required issues remain. Two are spec inconsistencies left by the methodology resolve not being
fully propagated (replace_when delegation target, factor-path vs. post-detection clearing). Two are
test-plan gaps (missing error tests for 3 functions, missing shared validator direction). One is an
underspecified enforcement mechanism (recode_values from/to conditional-required). All are low-effort
fixes. The spec is not yet safe to hand off to `/implementation-workflow`.

---

## Spec Review: recode — Pass 2 (2026-03-09)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | replace_when() delegation target inconsistent across three spec sections | ✅ Resolved |
| 2 | §IV.3 factor path bypasses post-detection; §III.4 clears metadata | ✅ Resolved |
| 3 | replace_when(), if_else(), replace_values() have no error tests | ✅ Resolved |
| 4 | .label/.value_labels validation specified 5× with no shared helper | ✅ Resolved |
| 5 | recode_values() from/to conditional-required enforcement unspecified | ✅ Resolved |
| 6 | @metadata@transformations GAP not in §XIII quality gates | ✅ Resolved |
| 7 | .update_labels type not validated | ✅ Resolved |
| 8 | surveytidy_recode attr lifecycle invariant not in test assertions | ✅ Resolved |

### New Issues

#### Section: X — Internal Helpers

**Issue 1: `.factor_from_result()` formula_values extraction mechanism is unspecified for `case_when()`**
Severity: BLOCKING
Violates engineering-preferences.md §5 (explicit over clever); contracts must be implementable without guessing.

§X.2 specifies:
```
formula_values: character vector of unique output values in formula order
                (extracted from the RHS of the ... formulas before calling dplyr)
```

For `recode_values()`, `formula_values = unique(to)` — trivial. For `case_when()`, the `...` formulas
are arbitrary two-sided R expressions like `age > 65 ~ "old"` or `TRUE ~ get_category(x)`. Extracting
RHS values "before calling dplyr" requires iterating `list(...)` and evaluating each RHS in the
calling frame. The spec does not specify: (a) how to iterate formulas, (b) how to evaluate computed RHS
expressions, or (c) what to do when an RHS produces a non-scalar.

If an implementer instead derives `formula_values` from the result vector AFTER calling dplyr (simpler,
handles computed RHS), they get a different level order than "formula appearance order" when some values
don't appear in the data — a silent behavioral difference.

Options:
- **[A]** Specify the extraction mechanism: iterate `list(...)`, call `rlang::eval_tidy(rlang::f_rhs(f))` on each RHS, deduplicate in order. Specify error behavior for non-scalar RHS. Effort: medium, Risk: low.
- **[B]** Change the approach: derive `formula_values` from the result vector AFTER calling dplyr — `unique(as.character(result))[!is.na(unique(as.character(result)))]` in appearance order. Drop "before calling dplyr." Simpler; handles computed RHS without quosure manipulation. Effort: low, Risk: low.
- **[C] Do nothing** — two valid interpretations; implementers produce inconsistent factor level orders.

**Recommendation: B** — Post-dplyr extraction is simpler, correct, and removes the dependency on formula parsing. Update §X.2 to specify this approach.

---

#### Section: X.1 / IV.3 / V.4 / VI.3 / IX.4 — Output Contracts

**Issue 2: "Only `.description` set, no label args" output path is missing from all function output contracts**
Severity: REQUIRED
Violates engineering-preferences.md §5 (explicit over clever); §X.1 rule is never exercised by any function contract.

§X.1 states the rule: "surveytidy_recode attr is set on any output where at least one of `.label`,
`.value_labels`, `.description` is non-NULL, OR `.factor = TRUE`." And: "plain-vector outputs with
only `.description`, the caller sets the attr directly."

But every function's no-label fallback step says "return plain vector" WITHOUT a step for when
`.description` is non-NULL:
- `case_when()` §IV.3 step 5: "If `.factor = FALSE` and **both label args are NULL**: return plain vector."
- `if_else()` §VI.3 step 2: implied else → plain vector.
- `replace_when()` §V.4 step 3: implied else → plain vector.
- `replace_values()` §IX.4 step 3: implied else → plain vector.

An implementer following these contracts returns a plain vector when `.description` is non-NULL but
label args are NULL, silently dropping the description. Post-detection never logs it. The §X.1 rule
becomes dead text.

Options:
- **[A]** Add an explicit step before each "return plain vector" fallback: "If `.factor = FALSE`, `.label` is NULL, `.value_labels` is NULL, but `.description` is non-NULL: `attr(result, 'surveytidy_recode') <- list(description = .description)`; return plain vector." Apply to §IV.3, §V.4, §VI.3, §IX.4, and the new recode_values() output contract (Issue 3). Effort: low (5 small edits), Risk: low.
- **[B]** Change `.wrap_labelled()` to always set the `surveytidy_recode` attr even when it returns `x` unchanged (i.e., when both label args are NULL). Add a `description` path inside `.wrap_labelled()`. Effort: medium (§X.1 contract change), Risk: medium (`.wrap_labelled()` callers must pass `.description` every time).
- **[C] Do nothing** — `.description`-only path silently drops the description; §X.1 rule is never triggered.

**Recommendation: A** — The caller-sets-attr-directly path is already documented in §X.1. It just needs to appear in each function's output contract.

---

#### Section: VIII — recode_values()

**Issue 3: `recode_values()` has no output contract section — factor path and label path are completely unspecified**
Severity: REQUIRED
Violates contract completeness (Lens 3); compare §IV.3 (5-step output contract for case_when()), §VI.3 (3-step output contract for if_else()).

§VIII contains: Signature → Argument Table → Core Delegation (error-catch code) → .use_labels Behavior → Error Table. There is no "Output Contract" section.

An implementer reading §VIII cannot determine from that section alone:
1. When `.factor = TRUE`, call `.factor_from_result()` and set `surveytidy_recode` attr (only discoverable by reading §X.2's aside "Called by case_when() and recode_values()").
2. When `.label` or `.value_labels` is non-NULL, wrap via `.wrap_labelled()`.
3. When `.description` is non-NULL but label args are NULL, set attr directly (Issue 2 above).
4. When no surveytidy args are used, return result unchanged (identical to dplyr).

§VIII.3 "Core Delegation" covers only the delegation call and its error-catching — not the post-delegation output handling.

Options:
- **[A]** Add §VIII.5 "Output Contract" with explicit steps (parallel to §IV.3 steps 2–5, with `unique(to)` as formula_values for .factor_from_result()). Effort: low, Risk: low.
- **[B]** Add a cross-reference: "Output handling follows the same contract as case_when() §IV.3 steps 2–5, substituting `unique(to)` for formula_values." Effort: trivial. Requires Issue 1 to be resolved first so §IV.3 is correct.
- **[C] Do nothing** — implementer reconstructs the contract from §X.1, §X.2, and inference.

**Recommendation: A** — An explicit output contract costs nothing and eliminates guesswork for the most parameter-heavy function in this spec.

---

#### Section: V / IX — replace_when() and replace_values()

**Issue 4: Label-merge algorithm is specified identically in two places with no shared helper**
Severity: REQUIRED
Violates engineering-preferences.md §1 (DRY).

`replace_when()` §V.4 step 2: "start from `attr(x, "labels")`, merge `.value_labels` (overrides for
matching values, retains unmatched entries from `x`)."

`replace_values()` §IX.4 step 2: "start from `attr(x, "labels")`, override with `.value_labels` for
matching values."

Same algorithm, same file (`R/recode.R`). Any edge case fix (e.g., what if both `x` labels and
`.value_labels` are NULL? what if they have incompatible types?) must be applied twice.

Options:
- **[A]** Add `.merge_value_labels(base_labels, override_labels)` to §X: `# base_labels: named vector or NULL; # override_labels: named vector or NULL (.value_labels arg); # Returns: merged named vector — overrides replace base_labels entries for matching values; remaining base_labels entries retained.` Reference from §V.4 and §IX.4. Effort: low, Risk: low.
- **[B]** Cross-reference §IX.4 to §V.4: "Same algorithm as replace_when() §V.4 step 2." Effort: trivial, but doesn't direct implementers to write shared code.
- **[C] Do nothing** — duplicated inline; edge case changes require 2 edits.

**Recommendation: A** — Three-function internal helpers are already in §X. This merge logic is the same algorithm used by two functions in the same file. Extract it.

---

#### Section: XII — Testing Plan

**Issue 5: `na_if()` `.update_labels` non-logical input has no test**
Severity: REQUIRED
Violates testing-standards.md §2 (every validation path must have a test).

§VII.3 step 0 adds `rlang::check_scalar_bool(.update_labels)`. §XII.1 section 6 (na_if tests) does not include a test for this validation path:

```
6. na_if()
   - .update_labels = TRUE removes label entry for y from value_labels
   - .update_labels = FALSE retains label entry for y
   - y is a vector: all matching label entries removed
   - x with no labels: returns plain vector (no labelled wrapping)
   - All 3 design types
```

No test for `.update_labels = "yes"` (character) or `.update_labels = c(TRUE, FALSE)` (length > 1). Both should trigger `rlang::check_scalar_bool()`.

Options:
- **[A]** Add to §XII.1 section 6: `.update_labels = "yes"` (non-logical) → rlang error; `.update_labels = c(TRUE, FALSE)` (length > 1) → rlang error. Note: rlang errors from `check_scalar_bool()` do not have a surveytidy class — use `expect_error()` without `class=`. Effort: low (two test bullets), Risk: none.
- **[B]** Note that `rlang::check_scalar_bool()` is tested by rlang's own suite; no surveytidy test needed. Effort: trivial.
- **[C] Do nothing** — validation path has no coverage; no test catches regression if step 0 is removed.

**Recommendation: A** — Public function arguments should be tested at their boundary.

---

#### Section: XI / XIII — Error/Warning Classes

**Issue 6: `surveytidy_error_recode_description_not_scalar` is in §XI but absent from all 6 function error tables; no validation code is specified**
Severity: REQUIRED
Violates contract completeness (Lens 3); testing-standards.md §3 (error table must be complete).

§XI lists `surveytidy_error_recode_description_not_scalar` with trigger ".description is not NULL and
not a character(1)". §XII.1 section 11 tests `.description not character(1) → surveytidy_error_recode_description_not_scalar`.

None of §IV.4, §V.5, §VI.4, §VII.4, §VIII.5, §IX.5 list this class. `.validate_label_args()` (§X.3)
validates `.label` and `.value_labels` but not `.description`. No spec text tells an implementer
where or how to raise this error.

Additionally, §XIII says "all **7** new error classes" — §XI actually lists **8** entries
(7 error classes + 1 warning class).

Options:
- **[A]** Extend `.validate_label_args()` to accept `.description` as a third argument, add the
  validation `if (!is.null(description) && !(is.character(description) && length(description) == 1))`,
  and update all 6 function contracts to pass `.description` to the validator. Update §X.3 signature.
  Fix §XIII count from 7 to 8. Effort: low, Risk: low.
- **[B]** Add a separate `.validate_description()` helper to §X; call it from each function's output
  contract. Effort: low, but adds a helper with one check — less elegant than A.
- **[C] Do nothing** — error class listed but never triggered; test in §XII.1 section 11 will fail.

**Recommendation: A** — Extend `.validate_label_args()`. The validator already handles the analogous cases for `.label` and `.value_labels`. `.description` validation belongs there.

---

#### Section: V / IX — Variable Label Inheritance

**Issue 7: `na_if()` inherits variable label from `x`; `replace_when()` and `replace_values()` do not — undocumented asymmetry**
Severity: SUGGESTION
Violates engineering-preferences.md §5 (implicit design choices should be stated).

`na_if()` §VII.3 step 2: "Wrap result in `haven::labelled()` with the (possibly updated) labels and
any **inherited `'label'` attr**."

`replace_when()` §V.4: wraps via `.wrap_labelled(label = .label, ...)` — only explicit `.label` arg,
no inheritance from `attr(x, "label")`.

`replace_values()` §IX.4: same omission.

All three functions partially replace values in a vector of unchanged type. Users familiar with
`na_if()`'s inheritance behavior will be surprised that `replace_when()` drops the variable label.
If the asymmetry is intentional (replace operations may change the column's meaning), it should be
stated. If it's an oversight, inherit as `na_if()` does.

Options:
- **[A]** Add variable label inheritance to `replace_when()` and `replace_values()`: when `.label`
  is NULL, inherit `attr(x, "label")` into the wrapped output. Update §V.4 and §IX.4. Effort: low.
- **[B]** Add a note to §V and §IX: "Variable label is NOT inherited from `x`. Set `.label` to carry
  the variable label into the output." Makes the intentional asymmetry explicit. Effort: trivial.
- **[C] Do nothing** — asymmetry exists silently; users discover through trial and error.

**Recommendation: Defer to user** — Both A and B are acceptable; the current asymmetry should be made explicit either way.

---

#### Section: VIII / IX — Delegation Code

**Issue 8: `...` passthrough promised in `recode_values()` and `replace_values()` arg tables but dropped in delegation code**
Severity: SUGGESTION
Violates engineering-preferences.md §5 (arg table and delegation code must match).

`recode_values()` §VIII.2: `...` — "Additional args passed to `dplyr::recode_values()`."
`recode_values()` §VIII.3 delegation: `dplyr::recode_values(x, from = from, to = to, ...)` — `...`
not in the call.

`replace_values()` §IX.2: `...` — "Additional args passed to `dplyr::replace_values()`."
`replace_values()` §IX.3 delegation: `dplyr::replace_values(x, from = from, to = to)` — `...` dropped.

Compare: `replace_when()` §V.4 correctly shows `dplyr::replace_when(x, ...)`.

Options:
- **[A]** Add `...` to both delegation calls. Effort: trivial.
- **[B]** Remove `...` from both function signatures if dplyr doesn't expose useful additional args. Effort: low.
- **[C] Do nothing** — `...` accepted and silently swallowed.

**Recommendation: A or B** — pick one; make arg tables consistent with delegation code.

---

### Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 5 |
| SUGGESTION | 2 |

**Total new issues:** 8

**Overall assessment:** All 8 Pass 1 issues are cleanly resolved. The 8 new issues cluster around two root causes: (1) the `.description`-only output path and its validation are in §X.1 and §XI but never made concrete in any function's output contract or error table — this affects all 6 functions systematically; (2) `recode_values()` is the only function without an output contract section, leaving its factor path and label path entirely implicit. One issue is BLOCKING (`.factor_from_result()` formula_values extraction for `case_when()`). The spec status should be changed from "APPROVED" to "IN REVIEW (Pass 2)" until Stage 4 resolves these. Start Stage 4 in a new session with `/spec-workflow stage 4`.

---

## Spec Review: recode — Pass 3 (2026-03-09)

### Prior Issues (Pass 2)

| # | Title | Status |
|---|---|---|
| 1 | `.factor_from_result()` formula_values extraction unspecified for `case_when()` | ✅ Resolved — two-path detection (all-literal / any-non-literal) specified in §IV.3 step 3 |
| 2 | "Only `.description` set, no label args" output path missing from function contracts | ✅ Resolved — §IV.3 step 5, §V.4 step 5, §VI.3 step 3, §IX.4 step 5 all have explicit `.description`-only branch |
| 3 | `recode_values()` has no output contract section | ✅ Resolved — §VIII.5 "Output Contract" added |
| 4 | Label-merge algorithm specified identically in two places | ✅ Resolved — `.merge_value_labels()` extracted to §X.4; §V.4 and §IX.4 reference it |
| 5 | `na_if()` `.update_labels` non-logical input has no test | ✅ Resolved — §XII.1 section 6 has two error bullets for non-logical and length-2 inputs |
| 6 | `surveytidy_error_recode_description_not_scalar` in §XI but absent from all 6 function error tables | ✅ Resolved — §X.3 `.validate_label_args()` extended to take `description` arg; §IV.4, §V.5, §VI.4, §VII.4, §VIII.6, §IX.5 all list the class; §XIII count corrected to 8 |
| 7 | `na_if()` inherits variable label; `replace_when()`/`replace_values()` do not — undocumented asymmetry | ✅ Resolved — variable label inheritance added to `replace_when()` §V.2/§V.4 and `replace_values()` §IX.2/§IX.4 |
| 8 | `...` passthrough dropped in `recode_values()` and `replace_values()` delegation code | ✅ Resolved — `...` added to both delegation calls |

### New Issues

#### Section: IV — case_when()

**Issue 1: `.factor = TRUE` + `.default` non-NULL → silent NA for `.default` rows in the all-literal path** ✅ RESOLVED (2026-03-09) — Option A: append `.default` (if non-NULL and !is.na(.default)) to `formula_values` in the all-literal path. §IV.3 step 3 updated. Spec v0.7.
Severity: REQUIRED
Violates engineering-preferences.md §4 (handle more edge cases); contract completeness (Lens 3).

§IV.3 step 3 all-literal path:
> "extract the RHS values in formula order → `formula_values`"

`.default` is not a formula pair — it is a separate argument. The all-literal
extraction walks `list(...)` formulas only; `.default` is never included in
`formula_values`.

§X.2 then creates the factor:
> "levels = formula_values (in their given order) otherwise" [when `.value_labels` is NULL]

Consequence: if a user calls `case_when(TRUE ~ "A", .default = "other", .factor = TRUE)`
with no `.value_labels`:
- `formula_values = c("A")` (`.default = "other"` is absent)
- `factor(result, levels = c("A"))` → rows that matched `.default` have value
  `"other"`, which is not a level → they become `NA`

This is silent data loss — no error, no warning, the user's `.default` rows
silently become NA in the factor. The non-literal path escapes this bug because
it derives `formula_values` from `result` AFTER calling dplyr (so `.default`
values appear in `formula_values`). The behavior is inconsistent between the
two paths.

The issue does NOT occur when `.value_labels` is non-NULL (user controls levels
and can include `.default`). It is specific to: all-literal path + `.default`
non-NULL-and-non-NA + `.value_labels` NULL.

Options:
- **[A]** In the all-literal path, after extracting formula RHS values, append
  `.default` if it is non-NULL and `!is.na(.default)`:
  `formula_values <- c(formula_values, as.character(.default))`. Update §IV.3
  step 3 accordingly. Effort: low, Risk: low, Impact: consistent level ordering
  across both paths when `.default` is used.
- **[B]** Add a validation: when `.factor = TRUE`, `.default` is non-NULL and
  non-NA, and `.value_labels` is NULL, error with a new
  `surveytidy_error_recode_factor_default_no_levels` class. "When `.default`
  is set with `.factor = TRUE`, supply `.value_labels` to control factor
  levels." Effort: low, Risk: low, Impact: explicit; prevents silent NA.
- **[C] Do nothing** — `.default` + `.factor = TRUE` silently drops `.default`
  rows as NA in the all-literal path; users discover this through data loss.

**Recommendation: A** — Appending `.default` to `formula_values` is one line
and produces the intuitive result (all values that can appear in the output
become factor levels). Option B forces unnecessary user burden for a common
pattern.

---

#### Section: XII — Testing Plan

**Issue 2: `surveytidy_warning_mutate_structural_var` has no test section** ✅ RESOLVED (2026-03-09) — Option A: §XII.1 section 2b added covering structural-var warnings (strata, PSU, FPC, repweights) + weight-col confirmation, dual pattern, all 3 design types. Spec v0.7.
Severity: REQUIRED
Violates testing-standards.md §2 (every warning class must have a test);
testing-surveytidy.md (dual pattern for all user-facing errors/warnings).

§XI lists `surveytidy_warning_mutate_structural_var` as a new warning class.
§III.1 step 1 specifies when it fires (user mutates strata, PSU, FPC, or
repweights via `mutate()`).

§XII.1 has no test section for this warning. Section 12 covers
`expect_snapshot(error = TRUE)` only — it does not cover warnings. No section
covers:
- `expect_warning(mutate(d, strata = ...), class = "surveytidy_warning_mutate_structural_var")`
- `expect_snapshot(warning = TRUE, mutate(d, strata = ...))`
- Verify warning fires for each structural variable type (strata, PSU, FPC,
  repweights) across all three design types

Options:
- **[A]** Add a new §XII.1 section 2b (or extend section 2): "mutate() step 1 —
  design variable warnings":
  - Structural var mutation → `surveytidy_warning_mutate_structural_var` (strata, PSU, FPC, repweights)
  - Weight var mutation → `surveytidy_warning_mutate_weight_col` (existing, but confirm
    still works after step 1 extension)
  - Each warning type tested with all 3 design types
  - expect_warning(class=) + expect_snapshot(warning=TRUE) dual pattern
  Effort: low (spec edit only), Risk: none.
- **[B]** Note that `surveytidy_warning_mutate_weight_col` tests already exist
  in `test-mutate.R` (Phase 0.5); add only the new structural warning test.
  Effort: low.
- **[C] Do nothing** — new warning class ships with no test coverage; regression
  goes undetected.

**Recommendation: A** — Explicitly specify all design-variable warning tests
in the new test section to make the PR checklist unambiguous. Testing both
weight and structural warnings together is the right scope.

---

#### Section: II — Architecture

**Issue 3: §II.1 and §II.2 give contradictory descriptions of `recode_values()` and `replace_values()` complexity** ✅ RESOLVED (2026-03-09) — Option A: §II.2 updated to distinguish pure delegation (replace_when()) from wrapper delegation with surveytidy logic (recode_values(), replace_values()). Spec v0.7.
Severity: SUGGESTION
Violates engineering-preferences.md §5 (explicit over clever); two sections describe the same functions differently.

§II.1 marks `recode_values()` and `replace_values()` as **"Own implementation
— identical API"**.

§II.2 says:
> "This phase requires `dplyr (>= 1.2.0)` and **delegates directly to these native
> functions — no custom implementations needed.**"
> — `recode_values(x, from, to, ...)` listed in the "delegates directly" table.

`recode_values()` has substantial custom logic: a pre-delegation guard for
`from = NULL`, a `tryCatch` wrapper for `.unmatched = "error"`, a full
`.use_labels = TRUE` path, and the complete surveytidy label output contract.
"No custom implementations needed" is materially false.

`replace_values()` is closer to a delegation but still adds label handling.

An implementer reading §II.2 might skip §VIII believing `recode_values()` is
just a pass-through and produce a function with no error catching or label support.

Options:
- **[A]** Update §II.2 to differentiate: "For `replace_when()`, delegation is
  direct — no custom logic. For `recode_values()` and `replace_values()`,
  delegation is the core path, but surveytidy adds label handling, error
  catching, and a `.use_labels` path (see §VIII and §IX for full contracts)."
  Effort: low.
- **[B]** Change §II.1 `recode_values()` relationship label from "Own
  implementation" to "Wraps `dplyr::recode_values()`" and update §II.2 to
  acknowledge the wrapper logic. Effort: low.
- **[C] Do nothing** — §VIII and §IX have the correct full contracts; an
  implementer reading those sections gets the right behavior regardless.

**Recommendation: A** — The distinction between "pure delegation" and
"delegation + surveytidy logic" matters for an implementer scanning §II for
scope. One sentence in §II.2 prevents misreading.

---

#### Section: XII — Testing Plan (§XII.1 section 9)

**Issue 4: Domain preservation tests don't specify starting from a filtered design** ✅ RESOLVED (2026-03-09) — Option A: §XII.1 section 9 updated to specify `filter(d, y1 > 40)` setup before calling mutate(). Spec v0.7.
Severity: SUGGESTION
Violates testing-surveytidy.md ("After existing domain" is a required test category).

§XII.1 section 9:
> "Domain column present and unchanged after mutate + each recode function"
> "Existing domain column values not modified by labelled output processing"

The second bullet implies "existing domain column" — but `make_all_designs()`
returns unfiltered designs with no domain column. For the domain column to exist
with non-trivial values, the test must first apply `filter()`, then call
`mutate()`.

The spec doesn't say "use `filter(d, ...)` first to create a non-trivial domain
column before testing preservation." An implementer may write:
```r
d <- make_all_designs()$taylor
result <- mutate(d, age_cat = case_when(y1 > 50 ~ "high", TRUE ~ "low"))
# domain column absent → preservation "passes" vacuously
```

Options:
- **[A]** Update section 9 to specify the test setup explicitly:
  "Use `filter(d, y1 > 40)` to create a non-trivial domain column before
  calling `mutate()`. Assert that the domain column in `result@data` is
  identical to the domain column in the filtered input." Effort: low.
- **[B]** Do nothing — "existing domain column values" is implicit enough;
  an implementer reading testing-surveytidy.md will use a filtered design.
- **[C] Do nothing** — risk of vacuous domain preservation tests.

**Recommendation: A** — One explicit sentence prevents the vacuous test pattern.

---

#### Section: XII — Testing Plan (§XII.1 sections 1, 2)

**Issue 5: Pre-attachment and post-detection test sections don't specify "all 3 design types"** ✅ RESOLVED (2026-03-09) — Option A: "All 3 design types" bullet added to §XII.1 sections 1 and 2. Spec v0.7.
Severity: SUGGESTION
Violates testing-surveytidy.md (every verb test must loop over all three design types).

Sections 3–9 each include "All 3 design types" as a test bullet. Sections 1
(pre-attachment) and 2 (post-detection) do not. These sections test behavior
that is identical across design types (it operates on `@data` and `@metadata`,
not on design variables), but the invariant is that mutate() must work on all
three design types — pre-attachment and post-detection are steps within mutate().

Options:
- **[A]** Add "All 3 design types" to section 1 and section 2 test lists.
  Effort: trivial.
- **[B]** Add a preamble to §XII.1: "All test sections use `make_all_designs()`
  and loop over all three design types unless the behavior is design-independent
  and explicitly noted as such." Effort: trivial; saves repeating in every
  section.
- **[C] Do nothing** — sections 1 and 2 may be tested on only one design type.

**Recommendation: B** — A single preamble statement is cleaner than adding
the bullet to every section and also prevents future omissions.

---

#### Section: IV — case_when() (§IV.4)

**Issue 6: `case_when()` `.unmatched = "error"` passes dplyr's condition class — not stated as intentional** ✅ RESOLVED (2026-03-09) — Option A: note added to §IV.4 stating the asymmetry with recode_values() is intentional — dplyr's message is already informative. Spec v0.7.
Severity: SUGGESTION
Violates engineering-preferences.md §5 (implicit design choices should be stated).

§VIII.3 wraps `recode_values()`'s unmatched error in
`surveytidy_error_recode_unmatched_values`. `case_when()` does NOT wrap its
unmatched error — §IV.4 has no entry for `.unmatched = "error"`. The asymmetry
is plausibly intentional (recode_values is tested more carefully, case_when's
error is already informative), but it's not stated.

A reader comparing §IV.4 and §VIII.6 will notice the omission and wonder
whether surveytidy should also wrap `dplyr::case_when()`'s `.unmatched = "error"`.

Options:
- **[A]** Add a note to §IV.4: "Note: `.unmatched = 'error'` failures in
  `dplyr::case_when()` propagate with dplyr's own condition class — no
  surveytidy wrapper. This is intentional: dplyr's message for this scenario
  is already informative." Effort: trivial.
- **[B]** Add `surveytidy_error_recode_case_when_unmatched` wrapping, parallel
  to `recode_values()`. Effort: medium, Risk: medium (more error classes, more
  tests).
- **[C] Do nothing** — asymmetry exists silently.

**Recommendation: A** — State the intentional asymmetry explicitly. Wrapping
is not needed.

---

#### Sections: V, IX — replace_when() and replace_values()

**Issue 7: No explicit note that `replace_when()` and `replace_values()` intentionally omit `.factor`** ✅ RESOLVED (2026-03-09) — Option A: type-stable notes added to §V intro and §IX intro. Spec v0.7.
Severity: SUGGESTION
Violates engineering-preferences.md §5 (explicit over clever).

`case_when()` and `recode_values()` have a `.factor` argument. `replace_when()`
and `replace_values()` do not. The omission is reasonable (both functions are
type-stable — output type matches `x`) but is not stated anywhere. Compare
`na_if()` §VII.3, which explicitly says: "No `.label` argument — variable label
is inherited from `x` unchanged." That explicit note prevents a reader from
wondering whether `.label` was forgotten.

Options:
- **[A]** Add a one-sentence note to §V.1 or §V.4 and §IX.1 or §IX.4:
  "No `.factor` argument — `replace_when()` is type-stable (output type matches
  input `x`). To produce a factor, apply `base::factor()` after the mutation."
  Effort: trivial.
- **[B]** Do nothing — readers who look for `.factor` won't find it and will
  move on. The arg table's absence is implicit documentation.
- **[C] Do nothing**.

**Recommendation: A** — One sentence per function prevents "was this omitted?"
questions during review.

---

### Summary (Pass 3)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 2 |
| SUGGESTION | 5 |

**Total new issues:** 7

**Overall assessment:** All 8 Pass 2 issues are cleanly resolved in v0.6. The
spec is substantially complete and implementable. One required issue is a real
edge-case bug: `case_when()` with `.factor = TRUE`, `.default` non-NULL, and
`.value_labels` NULL silently converts `.default` rows to NA in the all-literal
path. The fix is one line (append `.default` to `formula_values`). The second
required issue is a missing test section for the new `surveytidy_warning_mutate_structural_var`
class. Both are low-effort fixes. The five suggestions are minor clarifications.
The spec is ready for Stage 4 resolution once these two required issues are
addressed.
