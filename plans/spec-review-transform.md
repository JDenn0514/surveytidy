## Spec Review: transform — Pass 1 (2026-03-13)

---

### New Issues

#### Section: III — `make_factor()` Behavior Rules

**Issue 1: `drop_levels` for factor pass-through is contradicted between rule 1 and rule 2**
Severity: BLOCKING
Violates engineering-preferences.md §5 (explicit over clever)

Rule 1 states: "return `x` as-is, applying only `.label` and `.description` attrs, and
`ordered`/`drop_levels` if `x` is already a factor." This says `drop_levels` IS applied
for factor pass-through.

Rule 2 states: "**`drop_levels`**: Applied after building initial levels. Removes levels
with zero observed rows. Ignored for character and factor pass-through inputs." This says
`drop_levels` is NOT applied for factor pass-through.

These rules are mutually exclusive. An implementer reading both has a 50/50 coin-flip
decision. An existing R factor with empty levels (e.g., from a previous `droplevels()` call
that wasn't run) will behave differently depending on which rule the implementer follows.

Note: applying `drop_levels` to a factor pass-through IS useful — `make_factor(x,
drop_levels = TRUE)` on a factor with empty levels should remove those levels. The likely
intent is that rule 2's "factor pass-through" exclusion is a mistake; it should say
"character pass-through" only.

Options:
- **[A]** Remove "factor" from rule 2's exclusion; `drop_levels` applies to all inputs
  including factor pass-through; rule 1 is authoritative — Effort: low, Risk: low,
  Impact: consistent, predictable behavior for all input types
- **[B]** Remove `ordered`/`drop_levels` from rule 1's "applying only..." list; factor
  pass-through truly does not honor `drop_levels`; update rule 2 to be authoritative —
  Effort: low, Risk: low, Impact: simpler but potentially surprising to users with empty levels
- **[C] Do nothing** — implementer guesses; either behavior gets coded and passes or fails
  depending on which tests are written

**Recommendation: A** — A factor with empty levels is a real input condition; `drop_levels =
TRUE` should clean it up. Rule 2 was likely written to exclude the "character" path (which
builds levels from observations and has no "empty level" concept), not the "factor" path.

---

**Issue 2: `make_factor()` — no error specified for bad `ordered`, `drop_levels`, `na.rm` argument types**
Severity: SUGGESTION
Violates testing-standards.md §2 (test all edge cases) / engineering-preferences.md §4

The spec specifies types (`logical(1)`) for `ordered`, `drop_levels`, and `na.rm` but
defines no error for type mismatches. Passing `ordered = "yes"` or `drop_levels = 2L` would
produce a confusing error from inside `factor()`, not a clear surveytidy error.

The Phase 0.6 recode functions validate `.label` and `.description` via
`.validate_label_args()` (which maps to `surveytidy_error_recode_label_not_scalar` and
`surveytidy_error_recode_description_not_scalar` in `R/utils.R`). Transform functions specify
no analogous validation.

Options:
- **[A]** Specify that `.label` and `.description` are validated by the existing
  `.validate_label_args()` helper (consistent with recode functions); add explicit `stopifnot`
  or `cli_abort` for `ordered`, `drop_levels`, `na.rm` if not logical(1) — Effort: low,
  Risk: low, Impact: consistent API behavior across all surveytidy transformation functions
- **[B]** Rely on base R to produce errors for bad `ordered`/`drop_levels`/`na.rm`; only
  validate `.label`/`.description` via `.validate_label_args()` — Effort: low, Risk: low,
  Impact: partial consistency
- **[C] Do nothing** — validation omitted; inconsistent with recode functions

**Recommendation: A** — transform functions should behave consistently with recode functions
for the arguments they share (`.label`, `.description`). `.validate_label_args()` already
exists for this purpose.

---

#### Section: IV — `make_dicho()` Behavior Rules

**Issue 3: Rule 5 (2-level pass-through) contradicts step 4 (title-cased stems) and breaks qualifier-stripping for qualified 2-level inputs**
Severity: BLOCKING
Violates engineering-preferences.md §5 (explicit over clever) + §4 (handle edge cases)

Rule 5 states: "Already 2-level factor input: If the factor already has exactly 2 levels
after `.exclude` is applied, skip qualifier stripping and use those 2 levels directly (they
are already the stems)."

Step 4 states: "Output levels are the two title-cased stems."

These conflict in two ways:

**Conflict 1 — title-casing ambiguity:** For a 2-level factor with lowercase levels
`c("agree", "disagree")`, rule 5 says "use directly" (no change), but step 4 says
"title-cased." Test 16 says "levels unchanged," which implies no title-casing. An
implementer cannot determine whether to title-case the 2-level pass-through output.

**Conflict 2 — qualifier-stripping breakage:** For a factor with levels
`c("Strongly Agree", "Strongly Disagree")` — 2 levels — rule 5 short-circuits and outputs
`c("Strongly Agree", "Strongly Disagree")`. The normal path (without rule 5) would strip
qualifiers to produce `c("Agree", "Disagree")`. Rule 5 prevents `make_dicho()` from
fulfilling its stated purpose for the most common real-world input: a 2-level qualified
scale.

**The deeper problem:** Rule 5 is unnecessary. The normal qualifier-stripping path already
handles 2-level inputs correctly:
- `c("Strongly Agree", "Strongly Disagree")` → strip → `c("Agree", "Disagree")` → 2 unique
  stems → no error → correct output.
- `c("Agree", "Disagree")` → strip (no qualifier found, return unchanged) → `c("Agree",
  "Disagree")` → 2 unique stems → correct output.
Rule 5 adds special-case logic that solves no real problem and introduces two contradictions.

Options:
- **[A]** Remove rule 5 entirely; the normal qualifier-stripping path (steps 1–6) handles
  all inputs including 2-level factors correctly — Effort: low, Risk: low, Impact: closes
  both contradictions; simplifies the behavior contract
- **[B]** Keep rule 5 but rewrite it to: "If the factor already has exactly 2 levels after
  `.exclude`, run qualifier stripping on those 2 level names; if the result is already 2
  unique stems, use them (this is the common case); `flip_levels` applies." Update step 4
  to clarify title-casing applies in all paths — Effort: low, Risk: low, Impact: clarifies
  title-casing; still strip qualifiers
- **[C] Do nothing** — test 16 may accidentally pass (if test data has no qualifiers) while
  the real-world qualified 2-level case silently produces wrong output

**Recommendation: A** — Rule 5 provides no value and introduces contradictions. The normal
path handles all cases correctly. Simpler spec, same behavior, no edge case bugs.

---

#### Section: X.I — Integration Contract with `mutate.survey_base()`

**Issue 4: Section X.I is factually wrong — `mutate.survey_base()` already warns on all design variables, not just weights**
Severity: REQUIRED
Factual error introduced by methodology resolution Option A (decisions-transform.md)

The spec states (Section X.I, "Known limitation"):

> "The existing `mutate.survey_base()` protection covers weight columns only
> (`surveytidy_warning_mutate_weight_col`). Applying transform functions to `strata`, `ids`
> (PSU), or `fpc` columns inside `mutate()` is not warned against."

This is incorrect as of the current codebase. `R/mutate.R` Step 1b already implements
`surveytidy_warning_mutate_structural_var` for structural design variables (strata, PSU, FPC,
repweights):

```r
# R/mutate.R lines 156–171
if (length(changed_structural) > 0L) {
  cli::cli_warn(
    c("!" = "mutate() modified structural design variable(s): ..."),
    class = "surveytidy_warning_mutate_structural_var"
  )
}
```

This warning is also in `plans/error-messages.md`. The spec's "known limitation" paragraph
was added to address methodology review Issue 1 (decisions-transform.md, 2026-03-13), but
the limitation it documents was already addressed in the implementation before that review
ran.

The note is now actively misleading: it tells implementers there is no structural-var
protection, which is false.

Options:
- **[A]** Remove the "Known limitation" paragraph from Section X.I; replace with an accurate
  statement: "Applying transform functions to design variables inside `mutate()` triggers
  the existing warnings (`surveytidy_warning_mutate_weight_col` for weight columns,
  `surveytidy_warning_mutate_structural_var` for strata/PSU/FPC/repweights)." — Effort: low,
  Risk: low, Impact: spec accurately describes the integration contract
- **[B] Do nothing** — spec is wrong; implementers who read it may be confused about which
  warnings to test for in integration tests

**Recommendation: A** — a one-sentence correction; the misleading paragraph should not ship
to the implementer.

---

#### Section: VIII — Testing

**Issue 5: `test_invariants()` not specified as the first assertion in integration tests 40–44**
Severity: REQUIRED
Violates testing-surveytidy.md: "`test_invariants()` required as FIRST assertion in every verb test block"

Tests 40–44 are integration tests that call `mutate()` on a survey design object. The result
of `mutate()` is a survey design object. Per `testing-surveytidy.md`, `test_invariants()`
must be the first assertion in any test block that creates or transforms a survey object.

The test plan descriptions for tests 42–44 specify what is checked (`@metadata updated
correctly`, `@data stripped of haven attrs`, `all 3 design types`) but none mention
`test_invariants()`. An implementer writing these tests from the spec will produce
conforming tests that miss the invariant check.

Options:
- **[A]** Add explicit note to Section VIII: "For tests 42–44 (and any integration test
  that calls `mutate()` on a design object), `test_invariants(result)` must be the first
  assertion inside the loop body." — Effort: low, Risk: low, Impact: ensures the invariant
  check is not omitted
- **[B] Do nothing** — the testing-surveytidy.md rule applies globally, but spec-level
  reminder prevents the error in practice

**Recommendation: A** — this is a persistent source of omissions across feature branches;
the spec should spell it out.

---

**Issue 6: Test #18 says "NA_integer_" but `make_dicho()` returns a factor**
Severity: REQUIRED
Factual error in test plan

Test #18: `make_dicho() — .exclude: excluded rows become NA_integer_ in result`

`make_dicho()` output contract is "Returns a 2-level R factor." When `.exclude` sets rows to
NA, those rows become `NA` within a factor — not `NA_integer_`. `NA_integer_` is the missing
value type for integer vectors; it appears in `make_binary()` output (which converts to
integer), not `make_dicho()` output.

An implementer writing test 18 who asserts `expect_true(is.na(result[excluded_row]))` would
pass correctly. One who reads "NA_integer_" and asserts
`expect_identical(result[excluded_row], NA_integer_)` would fail because factors and integers
are not identical.

Options:
- **[A]** Change test 18 description to: `"make_dicho() — .exclude: excluded rows become NA
  in the 2-level factor result"` — Effort: minimal, Risk: none, Impact: eliminates misleading
  description
- **[B] Do nothing** — description is wrong; implementer likely figures it out from context

**Recommendation: A** — one-word fix; no reason to leave it wrong.

---

**Issue 7: Domain preservation not explicitly required in integration tests**
Severity: REQUIRED
Violates testing-surveytidy.md: "After existing domain — verb applied to a filtered design;
domain preserved"

Tests 40–44 describe integration scenarios (inside mutate(), all 3 design types) but none
specify asserting that the domain column is preserved after the mutate() call. While the
domain column should flow through `mutate.survey_base()` automatically, this is an
assumption — not a tested guarantee.

`testing-surveytidy.md` is explicit: every verb test block that transforms a survey object
must verify domain preservation when a domain column is present. These are integration tests
(tests 42–44) that call `mutate()` on design objects.

Suggested test addition: one test block that calls `filter(d, ...)` to establish a domain,
then calls `mutate(d, new_col = make_factor(...))` inside that domain context, and asserts
that `..surveycore_domain..` is present and unchanged.

Options:
- **[A]** Add to test plan: `"44b. Integration — domain column preserved after make_factor()
  inside mutate() on a filtered design"` (can be folded into the loop for test 44) —
  Effort: low, Risk: low, Impact: closes the domain preservation test gap per spec rules
- **[B] Do nothing** — domain preservation is not tested; a regression that drops the domain
  column inside mutate() would go undetected

**Recommendation: A** — this is a mandatory check per the testing rules; add it.

---

#### Section: I (Scope) — Open Questions Carried into Stage 3

**Issue 8: Open question #1 — `make_factor()` character input level order needs a decision**
Severity: SUGGESTION
Pre-flagged in spec Section XI as requiring Stage 3 judgment

The spec specifies alphabetical level order for character input. The open question asks
whether first-appearance order is more appropriate for survey data.

**Judgment call:**

- **Alphabetical (current spec):** Reproducible; not sensitive to data ordering; consistent
  with `base::factor()`. Bad for survey data because survey response options have a natural
  order (e.g., "Disagree", "Agree" not "Agree", "Disagree").
- **First-appearance order (`factor(x, levels = unique(x))`):** Preserves the order in which
  values appear in the data, which for survey data usually matches the questionnaire order.
  But it is sensitive to row ordering, which makes tests brittle (sort order of `@data` can
  vary).
- **Retain alphabetical with a note:** The most common character-to-factor use case in
  surveytidy is recoding labelled vectors via `make_factor()` — which uses numeric order, not
  alphabetical. Character input is rare and likely for already-clean data. Alphabetical is a
  predictable fallback.

Options:
- **[A]** Keep alphabetical; add a `@details` note in roxygen: "For character input, levels
  are assigned alphabetically. If a specific order is required, convert to an ordered factor
  manually." — Effort: none (current behavior), Risk: low, Impact: resolves open question
  with clear documentation
- **[B]** Switch to first-appearance order; update tests accordingly — Effort: low,
  Risk: low, Impact: more survey-appropriate but tests become sensitive to row order

**Recommendation: A** — character input is the edge case (not the primary use); alphabetical
is more predictable and easier to test. Documenting the limitation is sufficient.

---

**Issue 9: Test gap — `ordered = TRUE` on a factor pass-through input is not explicitly covered**
Severity: SUGGESTION
Violates testing-standards.md §2 (test all combinations of argument interactions)

Test 3 covers factor pass-through (levels preserved); test 6 covers `ordered = TRUE` for
numeric input. Behavior rule 1 explicitly mentions that `ordered` is applied for factor
pass-through, but no test verifies this combination.

A factor pass-through + `ordered = TRUE` should return an ordered factor (class =
`c("ordered", "factor")`). If the implementer uses `factor(x, ordered = TRUE)` on an already-
ordered factor with `ordered = FALSE`, it should convert from ordered to unordered — also
not tested.

Options:
- **[A]** Add two test entries after test 3: `"3a. make_factor() — ordered = TRUE on factor
  pass-through returns ordered factor"` and `"3b. make_factor() — ordered = FALSE on an
  ordered factor removes ordered class"` — Effort: low, Risk: none, Impact: covers the
  interaction called out explicitly in behavior rule 1
- **[B] Do nothing** — gap exists; these are derived behaviors that fall out of the rule

**Recommendation: A** — rule 1 explicitly mentions this case; it should have a test.

---

**Issue 10: `.get_labels_attr` / `.get_label_attr` naming is a one-character bug risk**
Severity: SUGGESTION
Violates engineering-preferences.md §5 (explicit over clever)

The two helper names differ by a single letter:
- `.get_labels_attr(x)` → `attr(x, "labels", exact = TRUE)` (plural — the value-label mapping)
- `.get_label_attr(x)` → `attr(x, "label", exact = TRUE)` (singular — the variable label string)

These helpers appear in the same file and are called from similar contexts. A one-character
typo — using `.get_label_attr` where `.get_labels_attr` was intended — reads the wrong
attribute silently. In a function like `make_factor()` that reads both attributes, this is a
realistic bug path.

Additionally, both are one-line wrappers around `attr()`. The abstraction adds almost no
value while adding the naming-confusion risk.

Options:
- **[A]** Remove both helpers; inline `attr(x, "labels", exact = TRUE)` and
  `attr(x, "label", exact = TRUE)` directly at call sites. The `exact = TRUE` is the only
  important behavior and it's self-documenting inline — Effort: low, Risk: low, Impact:
  eliminates the confusion source
- **[B]** Rename to `attr_val_labels()` / `attr_var_label()` with the full intent in the
  name — Effort: low, Risk: low, Impact: reduces confusion
- **[C] Keep as-is** — names are documented in the spec; implementer should be careful

**Recommendation: A** — one-line helpers that create confusion are a net negative; inline
the two `attr()` calls.

---

## Summary (Pass 1)

| Severity | Count |
|----------|-------|
| BLOCKING | 2 |
| REQUIRED | 5 |
| SUGGESTION | 4 |

**Total issues:** 11

**Overall assessment:** The core vector-level semantics are sound and the integration
contract with `mutate()` is well-understood. Two blocking issues prevent correct
implementation: `make_factor()` has a direct contradiction between behavior rules 1 and 2 on
whether `drop_levels` applies to factor pass-through, and `make_dicho()`'s rule 5 (2-level
short-circuit) both contradicts the title-casing contract and silently produces wrong output
for the most common real-world qualified-2-level input. Remove rule 5 entirely — the normal
path handles it. The five required issues are targeted fixes: one factual error in the
integration note (mutate() already protects structural vars), two test plan gaps
(test_invariants + domain preservation), one wrong type in a test description, and one
behavior bug in rule 5. The suggestions address argument validation consistency, a test
coverage gap, and a naming hazard in the helper design.

---

## Spec Review: transform — Pass 2 (2026-03-16)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|-------|--------|
| 1 | `drop_levels` for factor pass-through contradicted between rules 1 and 2 | ✅ Resolved |
| 2 | No error specified for bad `ordered`/`drop_levels`/`na.rm` argument types | ✅ Resolved |
| 3 | `make_dicho()` Rule 5 (2-level short-circuit) contradicts title-casing and breaks qualifier-stripping | ✅ Resolved |
| 4 | Section X.I factually wrong — `mutate.survey_base()` already warns on all design variables | ✅ Resolved |
| 5 | `test_invariants()` not specified as first assertion in integration tests | ✅ Resolved |
| 6 | Test #18 says "NA_integer_" but `make_dicho()` returns a factor | ✅ Resolved |
| 7 | Domain preservation not explicitly required in integration tests | ✅ Resolved |
| 8 | Open question #1 — `make_factor()` character input level order needs a decision | ✅ Resolved |
| 9 | Test gap — `ordered = TRUE` on factor pass-through not explicitly covered | ✅ Resolved |
| 10 | `.get_labels_attr` / `.get_label_attr` naming is a one-character bug risk | ✅ Resolved |

All 10 Pass 1 issues resolved. Spec updated to v0.3.

---

### New Issues

#### Section: II — Architecture / Shared Internal Helpers

No new issues found.

#### Section: III — `make_factor()` Behavior Rules

**Issue 1: All-NA numeric input with `drop_levels = TRUE` produces 0-level factor — behavior unspecified**
Severity: REQUIRED

Behavior rule 4 states: "NA values in `x` never require a label." This means an all-NA
numeric vector with a `labels` attribute (e.g., `x = c(NA, NA, NA)` with
`attr(x, "labels") = c("Agree"=1, "Disagree"=2)`) passes all validation:

- No non-NA values → label-completeness check trivially passes
- `drop_levels = TRUE` → no observed values → 0 levels → `factor(character(0))` result

A 0-level factor is valid R but unusual. When it flows downstream into `make_dicho()` or
`make_binary()`, the error is `surveytidy_error_make_dicho_too_few_levels` — a confusing
failure that gives no hint that the root cause is all-NA input. The spec is silent on this
path, leaving the implementer to guess whether to warn, error, or silently return a 0-level
factor.

Options:
- **[A]** Add a behavior note to Section III: "If all values are `NA` and `drop_levels = TRUE`,
  the result is a 0-level factor. No warning is issued; NA rows remain NA. Downstream functions
  requiring ≥2 levels (e.g., `make_dicho()`) will error at that layer." — Effort: minimal,
  Risk: low, Impact: documents the edge case without a new warning class
- **[B]** Add `surveytidy_warning_make_factor_all_na` (paralleling `make_rev()`'s all-NA
  warning) when all non-excluded values are NA — Effort: low (adds warning + test),
  Risk: low, Impact: users get immediate feedback for what is likely an input error
- **[C] Do nothing** — behavior unspecified; implementer guesses; confusing downstream errors

**Recommendation: A** — keeps the spec minimal (no new class) while closing the specification
gap. Option B can be added after user feedback if the all-NA-vector case proves common in
practice.

---

**Issue 2: `force = TRUE` "return early" creates ambiguity about when `.set_recode_attrs()` is called**
Severity: SUGGESTION

Section III, Behavior Rule 1 (numeric path, `force = TRUE`) states:
> "warn `surveytidy_warning_make_factor_forced`, coerce via `as.factor(x)`, **return early**
> (skip label-completeness check)."

"Return early" implies the function exits from within the numeric dispatch branch before
reaching the final `.set_recode_attrs()` call. An implementer reading this may write:

```r
if (force) {
  cli::cli_warn(...)
  result <- as.factor(x)
  return(result)  # .set_recode_attrs() never called
}
```

This violates the Section II guarantee (".set_recode_attrs() at the end of every function,
on every code path") and Quality Gate 14 ("attr(result, 'surveytidy_recode') set on every
code path through every function"). The quality gate is the correct backstop, but the
behavior rule itself creates a misleading reading.

Options:
- **[A]** Revise the `force = TRUE` branch description to: "warn, coerce via `as.factor(x)`,
  call `.set_recode_attrs(result, ...)`, then return (skip label-completeness check)" —
  Effort: minimal, Risk: none, Impact: removes the ambiguity
- **[B] Do nothing** — Quality Gate 14 is the backstop; implementer who reads both will
  reconcile it

**Recommendation: A** — the quality gate is correct but the behavior rule should not
contradict it. One-line fix.

---

#### Section: IV–VII — `make_dicho()`, `make_binary()`, `make_rev()`, `make_flip()`

**Issue 3: `.label`/`.description` and boolean flag argument validation contracts missing in `make_dicho()`, `make_binary()`, and `make_rev()`**
Severity: REQUIRED

`make_factor()` has an explicit Argument Validation section specifying:
- `.label`/`.description` validated by `.validate_label_args()` → `surveytidy_error_make_factor_bad_arg`
- `ordered`, `drop_levels`, `force`, `na.rm` must each be `logical(1)` → same error class

None of the other three functions with `.label`/`.description` arguments have a validation
contract:

| Function | `.label`/`.description` validation | Flag arg validation |
|----------|-------------------------------------|---------------------|
| `make_factor()` | ✅ Specified (`.validate_label_args()`) | ✅ Specified (`logical(1)` check) |
| `make_dicho()` | ❌ Not specified | ❌ `flip_levels = logical(1)` — no validation |
| `make_binary()` | ❌ Not specified | ❌ `flip_values = logical(1)` — no validation |
| `make_rev()` | ❌ Not specified | N/A (no flag args) |
| `make_flip()` | `.description` not specified; `label` ✅ via `surveytidy_error_make_flip_missing_label` | N/A |

Critically, `.label`/`.description` in `make_dicho()` and `make_binary()` are explicitly NOT
passed to the internal `make_factor()` call (rule 1 for `make_dicho()`: ".label and
.description are NOT passed to the internal `make_factor()` call; they are applied at the
end"). So those arguments never pass through `make_factor()`'s validation. If a user passes
`make_dicho(x, .label = 123)` or `make_dicho(x, flip_levels = "yes")`, the failure is
either a confusing base R type error or a downstream failure with no indication of which
argument is wrong.

Options:
- **[A]** Add an Argument Validation paragraph to `make_dicho()`, `make_binary()`,
  `make_rev()`, and `make_flip()` specifying: (1) `.label`/`.description` validated via
  `.validate_label_args()` raising `surveytidy_error_{fn}_bad_arg` (one new class per
  function, or reuse a shared class); (2) boolean flag args must be `logical(1)` with the
  same error — Effort: low, Risk: low, Impact: consistent API across all 5 functions; clear
  user-facing errors for bad arguments
- **[B]** Add `.label`/`.description` validation only (reuse `.validate_label_args()`);
  leave boolean flag arg validation to base R error handling — Effort: low, Risk: low,
  Impact: partial consistency; `flip_levels = "yes"` still errors but not cleanly
- **[C] Do nothing** — 3 of 5 functions have unspecified validation; implementers will
  decide inconsistently; users get confusing errors

**Recommendation: A** — `make_factor()` already establishes the pattern; all functions with
`.label`/`.description` or boolean flag args should follow it. Option A requires adding new
error classes; if the error class proliferation is undesirable, one shared class
`surveytidy_error_transform_bad_arg` could cover all five functions.

---

#### Section: IX — Testing

**Issue 4: `test_invariants()` required on wrong test range — tests 56–57 are vector pipelines, not design objects**
Severity: REQUIRED

Section IX "Integration Test Requirements" states:
> "For tests 56–59, `test_invariants(result)` **must be the first assertion**."

Tests 56 and 57:
- `# 56. Integration — make_factor() |> make_dicho() pipeline` — output is a plain 2-level
  factor, not a survey design object
- `# 57. Integration — make_factor() |> make_rev() pipeline is an error (factor input)` —
  this throws `surveytidy_error_make_rev_not_numeric`; there is no `result` to assert on

`test_invariants()` is defined for survey design objects. Calling it on a plain factor (test
56) will fail at runtime with an unexpected error. Test 57 has no result at all.

Tests 58, 58b, and 59 are the integration tests that operate on survey design objects via
`mutate()` — these are the tests where `test_invariants()` applies.

Options:
- **[A]** Change the Integration Test Requirements note to: "For tests 58, 58b, and 59
  (which call `mutate()` on a survey design object), `test_invariants(result)` must be the
  first assertion inside the loop body. Tests 56–57 are vector-level pipelines and do not
  produce design objects." — Effort: minimal, Risk: none, Impact: correct specification
- **[B] Do nothing** — implementer calling `test_invariants()` on a factor gets an immediate
  test failure that they must diagnose from first principles

**Recommendation: A** — one-sentence correction; the wrong range here causes immediate and
misleading test failures.

---

#### Section: X — Quality Gates

**Issue 5: Quality gates do not mention `library(dplyr)` requirement for `@examples` using `mutate()`**
Severity: SUGGESTION

Quality Gate item 10 states: "All 5 functions have `@examples` that run during `R CMD check`."

These are vector-level functions — their examples likely demonstrate standalone vector
operations (no `library(dplyr)` needed) and integration with `mutate()` (which requires
`library(dplyr)`). Per CLAUDE.md:
> "Every `@examples` block that calls a dplyr or tidyr verb must begin with an explicit
> `library()` call."

An implementer writing integration examples like `mutate(d, new_col = make_factor(q1))`
without `library(dplyr)` will produce an R CMD check failure — the most common CI failure
pattern in this codebase (per MEMORY.md "CI / R CMD check Gotchas — CRITICAL").

Options:
- **[A]** Add to Quality Gates: "For any `@examples` block demonstrating use inside
  `mutate()`, include `library(dplyr)` as the first line — dplyr is in Imports but not
  re-exported." — Effort: minimal, Impact: prevents a predictable R CMD check failure
- **[B] Do nothing** — CLAUDE.md covers this globally; quality gates don't need to repeat it

**Recommendation: A** — MEMORY.md flags this as a persistent failure pattern; one line in
the quality gates pays for itself the first time examples are written.

---

## Summary (Pass 2)

| Severity | Count |
|----------|-------|
| BLOCKING | 0 |
| REQUIRED | 3 |
| SUGGESTION | 2 |

**Total new issues:** 5

**Overall assessment:** Pass 1 resolution was thorough — all blocking and required issues
from that pass are closed and the spec is significantly stronger. Three required issues
remain: a validation contract gap that leaves 3 of 5 functions without specified argument
validation (implementers will produce inconsistent behavior), a wrong test range for
`test_invariants()` that would cause immediate test failures if followed literally, and an
unspecified all-NA edge case in `make_factor()`. Two suggestions address a misleading
"return early" phrase and a missing library() gate in the quality checklist. The spec is
close to implementable — resolve issues 3 and 4 (both quick fixes) before coding begins;
issue 1 requires a minor architectural decision about how many error classes to introduce.
