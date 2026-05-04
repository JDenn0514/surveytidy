# Spec Review — survey-collection verb dispatch

## Spec Review: survey-collection — Pass 1 (2026-04-27)

### New Issues

#### Section: §II.3.1 `.dispatch_verb_over_collection()` (dispatcher contract)

**Issue 1: `.detect_missing` enum has no value for "no column references"**
Severity: BLOCKING
Violates `engineering-preferences.md` §5 (explicit over clever) and the
contract-completeness lens.

The Parameters table in §II.3.1 declares `.detect_missing` is a required
`chr(1)` whose only valid values are `"pre_check"` or `"class_catch"`. But
§II.4 lists six verbs whose detection mode is `"n/a"` because they reference
no user columns: `slice`, `slice_head`, `slice_tail`, `slice_sample` (with
`weight_by = NULL`), `ungroup`, `glimpse` (and `group_vars`, which doesn't
use the dispatcher).

For verbs like `ungroup` and the no-`weight_by` `slice_*` family that DO
use the dispatcher, the spec is silent on what value to pass. `class_catch`
would install handlers that never fire; `pre_check` would scan a quosure
list that's empty or non-NSE. Functionally equivalent for these verbs, but
neither is documented as the canonical choice, and the dispatcher's
parameter contract forbids passing nothing.

Options:
- **[A] Add a `"none"` value** — explicit third mode that skips both
  pre-check and class-catch logic. Update §II.3.1 parameters table, the
  step 2 description, and §II.4 to use `"none"` everywhere it currently
  says `"n/a"`. Effort: low. Risk: low. Impact: removes the silent
  ambiguity and the `.detect_missing` arg becomes truly required.
- **[B] Default `.detect_missing` to `"class_catch"`** for all verbs that
  don't reference columns — safe because the handlers never match. Update
  §II.4's "n/a" rows to `class_catch`. Effort: low.
- **[C] Do nothing** — implementer guesses; spec contradicts itself.

**Recommendation: A** — explicit "none" mode mirrors the explicit
`.may_change_groups = FALSE` default and avoids implying behaviour that
the verb doesn't have.

---

**Issue 2: `id_from_stored` referenced in error template but never tracked**
Severity: BLOCKING
Violates the contract-completeness lens.

§VII.3's `surveytidy_error_collection_verb_emptied` template uses three
runtime values: `verb_name`, `resolved_if_missing_var`, and
`id_from_stored`. The dispatcher's step list (§II.3.1, steps 1–6) tracks
`resolved_if_missing_var` from step 1 but never computes a flag for
"override came from per-call vs from stored property". The implementer
would have to invent that tracking — exactly the architectural guess the
BLOCKING tier is meant to prevent.

Options:
- **[A] Add explicit step 1.5** — "track `id_from_stored <- is.null(.if_missing_var)`"
  alongside `resolved_if_missing_var`. Plumb both into the empty-result
  error site. Effort: low.
- **[B] Drop the per-call/stored distinction from the message** — use a
  single message body that doesn't depend on the override source. Less
  diagnostic but simpler.
- **[C] Do nothing** — implementer guesses or omits the bullet.

**Recommendation: A** — the "where did this value come from" bullet is
genuinely useful when a user has set `coll@if_missing_var = "skip"` and is
surprised their pipeline emptied; preserve it but document the tracking.

---

**Issue 3: Sentinel condition class chain claims `rlang_error` falsely**
Severity: REQUIRED
Violates `engineering-preferences.md` §5 (explicit over clever) and creates
a downstream test-correctness hazard.

§II.3.1 step 2.1 specifies the synthesized pre-check sentinel has class
chain `c("surveytidy_pre_check_missing_var", "rlang_error", "error", "condition")`.
But the condition is constructed by surveytidy via `cli::cli_abort()` or
`rlang::abort()` — it is not produced by the rlang internals that own the
`rlang_error` class. Asserting `inherits(cnd, "rlang_error")` for tests
becomes meaningless because every surveytidy-synthesized condition would
also need to declare it.

§IX.3's "`.if_missing_var = "error"` … with the original tidyselect/rlang
condition as `parent`" relies on this chain to be honest. A test that
asserts `inherits(cnd$parent, "rlang_error")` to distinguish
"surveytidy synthesized it" from "rlang produced it" cannot work if both
flavours carry the class.

Options:
- **[A] Drop `rlang_error`** — chain becomes
  `c("surveytidy_pre_check_missing_var", "error", "condition")`. Tests
  pattern-match on `surveytidy_pre_check_missing_var` only. Effort: low.
- **[B] Keep it but document the divergence** — note that surveytidy
  intentionally borrows the class for parent-chain compatibility with
  tidyselect-path errors. Risk: future drift if rlang's contract changes.
- **[C] Do nothing** — silent footgun.

**Recommendation: A** — the typed surveytidy class is sufficient for
`expect_error(class = ...)` and `parent`-chain tests; borrowing rlang's
class is unnecessary mimicry.

---

#### Section: §III.1 / §III.4 grouping-verb whitelist

**Issue 4: §IV.10 contradicts surveytidy: `rowwise()` does NOT touch `@groups`**
Severity: REQUIRED
Violates the contract-completeness lens.

§IV.10 says: "Per-member `rowwise()`. The dispatcher pattern applies.
`@groups` is updated per-member and lifted to the collection."

`R/rowwise.R` (lines 1–48) explicitly states rowwise mode lives in
`@variables$rowwise` and `@variables$rowwise_id_cols`. The header comment
reads: "`@data`, `@groups`, and `@metadata` are all unchanged." This
contradicts §IV.10.

The downstream effect: with `@groups` unchanged on every member,
`rowwise.survey_collection` is correctly NOT in the
`.may_change_groups = TRUE` whitelist (§II.3.1 step 5 lists only
`group_by`, `ungroup`, `rename`, `rename_with`). But §IV.10's wording
will mislead the implementer to expect a `@groups` update.

Options:
- **[A] Rewrite §IV.10** — rowwise mode is per-member via
  `@variables$rowwise`; `@groups` is unchanged. Document that the
  collection layer itself has no rowwise marker (state lives entirely
  per-member, like every other verb). Effort: low.
- **[B] Change `rowwise.survey_base` to set `@groups`** — out of scope;
  would cascade through Phase 0.5 tests.
- **[C] Do nothing.**

**Recommendation: A** — the spec must reflect what the per-member method
actually does.

---

**Issue 5: `is_rowwise()` predicate behaviour on collections undefined**
Severity: SUGGESTION
Edge-case lens.

`R/rowwise.R` exports `is_rowwise()` as a predicate. The spec doesn't
specify what `is_rowwise(coll)` returns. Three plausible answers: error
(no S3 method), TRUE if any member is rowwise, TRUE only if all members
are rowwise.

Options:
- **[A] Add a `is_rowwise.survey_collection` method** that returns TRUE
  iff every member is rowwise (the G1-style invariant — rowwise should
  be uniform across members because `rowwise.survey_collection` always
  applies per-member uniformly). Effort: low.
- **[B] Document that `is_rowwise()` does not dispatch on collections**
  and users must check per-member.
- **[C] Do nothing.**

**Recommendation: A** — symmetric with `group_vars.survey_collection`,
which does have a one-line method per §IV.9.

---

#### Section: §IV.6 slice family — pre-flight ambiguity

**Issue 6: `slice.survey_collection` pre-flight evaluation context is undefined**
Severity: BLOCKING
Violates the contract-completeness lens.

§IV.6 says: "`slice.survey_collection`: when the integer index `...`
evaluates to `integer(0)` (or all positions are negative selectors that
exclude every row)." But `slice()` accepts NSE: `slice(coll, 1:5)` is a
literal, while `slice(coll, n())` and `slice(coll, x)` reference the
data mask. At the collection layer, before per-member dispatch, the
evaluation context for `...` is undefined. Three options:

- Evaluate `...` against the first member's `@data`.
- Only pre-flight when `...` is a static literal; defer NSE to per-member.
- Pre-flight against an arbitrary scratch frame (zero rows) and check.

Each yields different behaviour for `slice(coll, n())` (returns the row
count of the first member; doesn't fire pre-flight; returns 0). The
implementer cannot guess.

Options:
- **[A] Restrict pre-flight to literal-index slices** — evaluate `...`
  in an empty environment with `tryCatch`; if the result is an integer
  vector and equals `integer(0)`, raise. If evaluation fails (NSE
  reference to a column), skip pre-flight. Effort: low.
- **[B] Evaluate against the first member's `@data`** — symmetric with
  the §IV.3 pre-flight for `select`. Effort: low. Risk: behavior differs
  if first member has different row count from others.
- **[C] Drop the pre-flight for `slice.survey_collection`** — keep it
  for `slice_head`/`slice_tail`/`slice_sample`/`slice_min`/`slice_max`
  where args are scalar. Effort: lowest.
- **[D] Do nothing.**

**Recommendation: A** — only literal `slice(coll, integer(0))` and
literal negative-everything cases trigger; NSE references are punted to
per-member behaviour. Symmetric with how the dispatcher treats data-mask
expressions in pre-check.

---

**Issue 7: Slice pre-flight wording omits `slice_min`/`slice_max`**
Severity: REQUIRED
Contract-completeness lens.

§IV.6 lists `slice`, `slice_head`/`slice_tail`, and `slice_sample` in the
pre-flight verb-specific list, then a separate sentence: "`slice_min` /
`slice_max` follow the same rule when their `n` or `prop` argument would
empty every member." But §VII.1's row for `surveytidy_error_collection_slice_zero`
says it fires from "`slice.survey_collection` / `slice_head` / `slice_tail`
/ `slice_sample` (and `slice_min` / `slice_max` when their `n`/`prop`
would empty every member)" — consistent. The decisions log entry for
Issue 7 doesn't mention `slice_min`/`slice_max` at all.

The pre-flight rule for `slice_min`/`slice_max` should be stated with the
same verb-specific clarity as the others (i.e., a bullet, not a trailing
sentence). Otherwise an implementer reading the bullet list may miss it.

Options:
- **[A] Add explicit bullets** for `slice_min` and `slice_max` to the
  §IV.6 verb-specific list. Effort: trivial.
- **[B] Do nothing.**

**Recommendation: A** — a uniform bullet list reads cleaner than a
heterogeneous mix.

---

#### Section: §IV.10 rowwise — see Issue 4

(Subsumed by Issue 4.)

---

#### Section: §V.1 `pull.survey_collection`

**Issue 8: Missing-column behaviour for `name = "<other_column>"` undefined**
Severity: REQUIRED
Edge-case lens.

§V.1 step 4 says `name = "<other_column>"` "passes through to
`dplyr::pull`'s `name` arg unchanged (per-row names from another column
inside each member)". But what happens when the named column exists in
some members and not others? The spec doesn't say:

- Does `.if_missing_var = "skip"` drop those members from the combined
  vector?
- Does `.if_missing_var = "error"` re-raise as
  `surveytidy_error_collection_verb_failed`?
- Does the missing-column condition route through pre-check (because
  `var` is data-mask) or class-catch (because `name` is a string)?

The detection mode entry in §II.4 for `pull` says "pre-check" — applies
to `var`. But `name = "<other_column>"` is a separate column reference
that may also fail.

Options:
- **[A] Document that both `var` and `name` flow through the same
  detection path** — pre-check sees both as referenced columns. Effort:
  low.
- **[B] Document that `name` is class-catch** — `dplyr::pull` raises
  `vctrs_error_subscript_oob` for the unknown name string. Verify
  empirically.
- **[C] Document that `name` is not subject to `.if_missing_var`** — if
  the user passes a column-name string, it must exist in every member or
  the verb errors. Simpler but inconsistent.
- **[D] Do nothing.**

**Recommendation: B** — `dplyr::pull(@data, .y, name = "z")` raises a
tidyselect error when `"z"` is missing; that fits class-catch. Spec
should clarify and a test should pin the behaviour.

---

#### Section: §V.2 `glimpse.survey_collection`

**Issue 9: Signature `...` argument has no documented role**
Severity: SUGGESTION
Contract-completeness lens.

§V.2 declares `glimpse.survey_collection(x, width = NULL, ..., .by_survey = FALSE)`.
What does `...` carry? `dplyr::glimpse` (and `pillar::glimpse`) does not
accept extra arguments meaningfully. If the verb forwards `...` to
nothing, the dot-dot-dot is dead weight.

Options:
- **[A] Drop `...`** from the signature. Effort: trivial.
- **[B] Keep `...` and document explicitly that it's ignored** — for
  forward compatibility with future `glimpse()` extensions.
- **[C] Do nothing.**

**Recommendation: A** — match the underlying generic; no need for
forward-compat dots that aren't used.

---

**Issue 10: Coercion footer width truncation rule unresolved (D7)**
Severity: SUGGESTION
Engineering-level lens (under-engineered for collections >5 members).

D7 in §XI.D7 acknowledges the footer can be unwieldy on large collections
with many type conflicts but defers the truncation rule. With the
implementation plan's PR 3 covering `glimpse.survey_collection`, this
must resolve before that PR is opened.

Options:
- **[A] Truncate at 5 columns** with `+ N more conflicting columns`. Cap
  at 80 cols width.
- **[B] Wrap each column block** without truncation.
- **[C] Defer to Stage 4** — but this would block PR 3 if not resolved
  first.

**Recommendation: A** — width-bounded truncation is the standard pillar
behaviour and the most predictable.

---

#### Section: §VI Re-exports

**Issue 11: `add_survey` and `remove_survey` re-exports unverified**
Severity: SUGGESTION
Engineering-level lens.

§VI lists `add_survey` and `remove_survey` as re-exports. The spec
should pin a minimum surveycore version that exports them, otherwise a
user with an older surveycore install hits a load-time error
(`object 'add_survey' is not exported by 'namespace:surveycore'`).

Options:
- **[A] Add a surveycore minimum-version line** to §XIII.1 and the
  Quality Gates checklist (verify pin in DESCRIPTION via `Imports`).
  Effort: low.
- **[B] Do nothing** — surveycore is already pinned in DESCRIPTION; trust
  the developer to keep it current.

**Recommendation: A** — the pin should be explicit because the
collection methods (specifically `as_survey_collection`,
`set_collection_id`, etc.) are recently shipped (per §I.2's reference to
PRs #97, #98, #111, #112, #113); the version pin is the only mechanism
that prevents a half-functional surveytidy install.

---

#### Section: §VII.1 New error classes

**Issue 12: `surveytidy_error_internal_groups_mutation` is contract-defensive over-engineering**
Severity: SUGGESTION
Violates `engineering-preferences.md` §3 (engineered enough — flag
over-engineering: defensive checks for impossible conditions).

§II.3.1 step 5 introduces a runtime invariance check: "if a per-member
method silently mutated `@groups` such that the post-dispatch groups
differ from the input collection's groups, raise
`surveytidy_error_internal_groups_mutation`." §VII.1 documents the class
as "Should never fire in correct code; surfaces a regression rather than
a user-actionable condition."

This is a guard against a future bug in surveytidy itself, not a
condition triggered by user input. Per `engineering-preferences.md` §3,
defensive code for impossible conditions is over-engineered. The check
adds complexity (a condition that "should never fire" still needs a
test, an entry in `error-messages.md`, and a snapshot — see §IX.5
"Every error class has … a snapshot test").

Options:
- **[A] Keep the check; note it's covered by a test that asserts NO
  trigger** — i.e., test that `.may_change_groups = FALSE` verbs don't
  in fact mutate `@groups`. Effort: low. Adds one test per non-grouping
  verb.
- **[B] Replace the runtime check with a `stopifnot()` assertion or
  `Recall` debug-only message** — runtime cost for an internal contract
  becomes lighter; doesn't appear in the error-messages registry.
- **[C] Drop the check** — rely on the per-member contract (each verb's
  `survey_base` method is responsible for its own `@groups` discipline).
  Per-verb tests already assert `@groups` invariance.
- **[D] Do nothing.**

**Recommendation: B** — `stopifnot()` keeps the regression catch but
removes it from the public-condition surface and the error-messages
registry. Tests can `expect_error(class = "simpleError")` if needed.

---

#### Section: §IX Testing

**Issue 13: Pre-check env-filter step has no test coverage**
Severity: REQUIRED
Test-completeness lens.

§II.3.1 step 2's pre-check pseudo-code (substeps 1–4) is the load-bearing
fix for D1's BLOCKING issue. Without tests pinning the env-filter logic,
the implementation could easily regress to a naive `all.vars()` check
that flags every enclosing-scope reference as "missing". §IX.3's per-verb
test categories don't call out env-filter coverage.

Test cases that must appear (likely in `test-collection-dispatch.R`):

- `filter(coll, age %in% allowed_ages)` where `allowed_ages` is in the
  enclosing env — must not flag `allowed_ages` as missing.
- `filter(coll, age > threshold)` where `threshold` exists in the global
  env — must not flag.
- `filter(coll, .data$age > 5)` where `.data` is dropped from the
  candidate set — must not flag.
- `filter(coll, age > 5)` where `age` is in `@data` — passes.
- `filter(coll, ghost_col > 5)` where `ghost_col` is in neither env nor
  `@data` — flagged.

Options:
- **[A] Add a §IX.4 dispatcher test row** for env-aware pre-check, with
  the four cases above. Effort: low.
- **[B] Do nothing** — implementer infers from §II.3.1 substeps.

**Recommendation: A** — the env-filter step is the methodology fix that
unblocked D1; testing it is essential.

---

**Issue 14: Domain-column preservation has no per-verb test**
Severity: REQUIRED
Test-completeness lens.

§III.3's "Domain column preservation" paragraph states every standard
verb (except `filter`/`filter_out`/`drop_na`) preserves the per-member
domain column transitively from the per-survey verb. §IX.3's category
list does not include "every verb preserves the per-member domain
column". `testing-surveytidy.md` lists this as a required check for
every verb.

Options:
- **[A] Add a row to §IX.3** requiring every per-verb test to: (i)
  pre-filter the collection to create a domain column, (ii) apply the
  verb, (iii) assert `surveycore::SURVEYCORE_DOMAIN_COL` is present and
  unchanged on every member that survives `.if_missing_var = "skip"`.
  Effort: low.
- **[B] Do nothing.**

**Recommendation: A** — required by `testing-surveytidy.md` and the
category exists for `survey_base`-level tests; symmetric coverage at the
collection layer is non-negotiable.

---

**Issue 15: `visible_vars` propagation and per-member `@metadata` not in test plan**
Severity: REQUIRED
Test-completeness lens.

`testing-surveytidy.md` requires:

- **`visible_vars` behavior** — if `select()` is involved, state is
  asserted.
- **`@metadata` contract** — metadata updates specified and tested.

§IX.3's category list omits both. For `select.survey_collection`:
- After `select(coll, y1, y2)`, every member's
  `@variables$visible_vars` should equal `c("y1", "y2")`.
- After `select(coll, psu, strata)` (only design vars), every member's
  `@variables$visible_vars` should be NULL.

For `rename.survey_collection`:
- After `rename(coll, new = old)`, every member's `@metadata` keys for
  `old` are renamed to `new`.

Options:
- **[A] Add two rows to §IX.3** — one for `visible_vars`, one for
  `@metadata`. Effort: low.
- **[B] Do nothing.**

**Recommendation: A** — these are existing testing-surveytidy.md
requirements; the collection layer must inherit them.

---

**Issue 16: `surveytidy_message_collection_skipped_surveys` has no test row**
Severity: REQUIRED
Test-completeness lens.

§IX.5's quality gate says "Every error class has a typed
`expect_error(class = ...)` test AND a snapshot test. Every warning
class has an `expect_warning(class = ...)` test." Messages aren't
listed. The skipped-surveys class is a `cli::cli_inform()` (registered
typed message). No test row in §IX.3 or §IX.4 covers it.

A test must verify:
- Message fires when `.if_missing_var = "skip"` drops at least one
  member.
- Message class is `surveytidy_message_collection_skipped_surveys`.
- Message body names every skipped survey.
- Snapshot pins the wording.

Options:
- **[A] Add a row in §IX.4** covering the message class — same pattern
  as warning class tests, with `expect_message(class = ...)` and a
  snapshot. Effort: low.
- **[B] Do nothing.**

**Recommendation: A** — registered typed messages need the same testing
discipline as registered errors and warnings.

---

**Issue 17: Mixed-subclass design-variable rename not in edge cases**
Severity: REQUIRED
Edge-case lens.

A collection may mix `survey_taylor`, `survey_replicate`, and
`survey_twophase` members (per §I.3). `survey_replicate` has a
`repweights` design variable that the other subclasses do NOT have.
What happens when a user runs `rename(coll, new = repweights)`?

- Per-member: errors on `survey_taylor` and `survey_twophase` (column
  doesn't exist), succeeds on `survey_replicate`.
- Under `.if_missing_var = "skip"`: drops the non-replicate members,
  output collection is reduced to just the replicate.
- Under `.if_missing_var = "error"` (default): re-raises with parent.

This is exactly the case `make_test_collection()` would produce. The
spec doesn't call out subclass-specific design vars, and §IX.3's
"Cross-design" row only says "every assertion above runs on the mixed
collection" — generic. A specific test for subclass-asymmetric design
columns is missing.

Options:
- **[A] Add an edge-case test** in `test-collection-rename.R`: rename
  `repweights` in a mixed collection under both `.if_missing_var`
  modes; assert per the dispatch contract. Effort: low.
- **[B] Do nothing** — implementer may not realize this case differs
  from "column missing in some members".

**Recommendation: A** — this is a real-world case (mixing wave designs)
and the test pins the contract.

---

#### Section: §XII Implementation plan

**Issue 18: PR 2 bundles 15 verbs into one logical unit**
Severity: SUGGESTION
Violates `github-strategy.md` ("One PR per logical unit of work").

PR 2 (`feature/survey-collection-verbs-standard`) covers all 15 standard
verbs (filter, filter_out, drop_na, select, relocate, rename,
rename_with, mutate, arrange, slice family, group_by, ungroup,
group_vars, rowwise, distinct). Per `github-strategy.md`, PR granularity
is "One PR per logical unit of work" — this is a single PR with ~15
exported method additions, ~15 test files, and pre-flight logic in 4
verbs.

Options:
- **[A] Split PR 2 into thematic PRs** — e.g., (i) data-masking verbs
  (filter, mutate, arrange, drop_na), (ii) tidyselect verbs (select,
  rename, relocate, rename_with, distinct, rowwise), (iii) grouping
  verbs (group_by, ungroup, group_vars), (iv) slice family. Effort: low
  (just renumbering). Risk: low. Impact: smaller code reviews; faster
  CI feedback.
- **[B] Keep PR 2 as one** — argue that the dispatcher (PR 1) is the
  hard part and the verbs are mechanical mirrors.
- **[C] Defer the decision to `/implementation-workflow` Stage 1**.

**Recommendation: A** — the spec already groups verbs by detection mode
and pre-flight requirements; PR splits along those lines minimize
reviewer load.

---

**Issue 19: `vctrs` Imports addition not in DESCRIPTION update list**
Severity: SUGGESTION
Contract-completeness lens.

§XIII.1 says "surveytidy also takes an explicit Imports dependency on
`vctrs`" but §I.1's deliverables list does not mention DESCRIPTION as a
modified file, and §X's quality gates don't include verification that
`Imports: vctrs` was added.

Options:
- **[A] Add `DESCRIPTION` to §I.1 deliverables** with "MODIFIED — add
  `vctrs (>= 0.7.0)` to Imports." Add a checklist row in §X for the
  Imports addition. Effort: trivial.
- **[B] Do nothing** — implementer figures it out at PR-3 time.

**Recommendation: A** — explicit deliverable lists prevent forgotten
package metadata changes.

---

#### Section: §VIII Roxygen — D6

**Issue 20: D6 `@inheritParams` from a `@noRd` stub is unverified**
Severity: SUGGESTION
Engineering-level lens.

§VIII proposes a `survey_collection_args` stub with `@noRd` from which
all collection verbs `@inheritParams`. The spec acknowledges in D6 that
this "may not work" and the fallback is per-method param copies. Per
`engineering-preferences.md` §3, leaving an unresolved roxygen mechanic
in the spec is engineered-just-enough — but Stage 4 is the documented
verification window; D6 is currently parked.

Options:
- **[A] Resolve D6 in Stage 4** — five-minute experiment with
  `roxygen2::roxygenise()` on a toy package will confirm. Add the result
  to the spec. Effort: trivial.
- **[B] Defer to implementation** and accept the fallback risk. If
  `@inheritParams` doesn't work from `@noRd`, every verb roxygen needs
  a hand-copied `@param` block — adds ~10 LOC per verb across 15 verbs.

**Recommendation: A** — verify in Stage 4 before implementation begins.

---

#### Section: §III.1 method signature ordering

No new issues found.

---

#### Section: §IV.3 select pre-flight — relocate handling

**Issue 21: `relocate` pre-flight conditions are under-specified**
Severity: SUGGESTION
Edge-case lens.

§IV.3 says: "`relocate` is included because its tidyselect can also be
used to reorder-only or drop columns depending on `.before` / `.after`
arguments — when the resolved column set excludes a group column, the
same pre-flight fires."

But `relocate(d, x, .before = y)` doesn't drop columns at all — it only
reorders. The pre-flight description is correct only if "the resolved
column set excludes a group column" means "the user explicitly named a
group column in `...` to be moved without `.before`/`.after`" — which
isn't dropping. Spec wording suggests `relocate` can drop, which it
can't (per `dplyr::relocate` 1.1+ docs).

The actual hazard is `relocate(d, -psu, .before = strata)` — negative
selection. Need to verify whether dplyr's `relocate` even accepts
negative selectors that drop.

Options:
- **[A] Verify and rewrite §IV.3** — likely conclusion: `relocate` does
  NOT drop columns and does NOT need the pre-flight. The pre-flight is
  for `select` only. Effort: low.
- **[B] Document the relocate edge case more carefully** if dplyr 1.2+
  does accept negative selectors that drop.
- **[C] Do nothing.**

**Recommendation: A** — verify with `dplyr::relocate(mtcars, -cyl)` (in
practice this fails, confirming relocate doesn't drop). Drop relocate
from the pre-flight scope.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 3 |
| REQUIRED | 8 |
| SUGGESTION | 10 |

**Total issues:** 21

**Overall assessment:** The spec is methodology-locked and
substantively complete after Stage 2's resolutions. The remaining
issues fall into three buckets: (1) three BLOCKING ambiguities in
the dispatcher contract — the `.detect_missing` enum's missing "no
column refs" mode, the unbacked `id_from_stored` reference in the
empty-result error template, and the slice pre-flight evaluation
context — must be resolved before coding. (2) Test-plan gaps —
domain-column preservation, env-aware pre-check, `visible_vars`,
`@metadata`, and the typed message class are all required by
`testing-surveytidy.md` but missing from §IX.3. (3) Spec-level
contradictions and minor over/under-engineering — §IV.10 contradicts
`R/rowwise.R`, the `surveytidy_pre_check_missing_var` class chain
falsely claims `rlang_error`, and `surveytidy_error_internal_groups_mutation`
adds defensive infrastructure for an impossible condition. None of
the issues require re-litigating Stage 2's methodology decisions.

---

## Spec Review: survey-collection — Pass 2 (2026-04-27)

### Prior Issues (Pass 1)

All 21 Pass 1 issues are recorded as resolved in
`plans/decisions-survey-collection.md` (Stage 3 spec-review resolution
session). Verified against the current spec text:

| # | Title | Status | Spec evidence |
|---|---|---|---|
| 1 | `.detect_missing` enum has no value for "no column references" | ✅ Resolved | §II.3.1 parameters table now lists `"pre_check"`, `"class_catch"`, `"none"`; §II.4 uses `"none"` |
| 2 | `id_from_stored` referenced but never tracked | ✅ Resolved | §II.3.1 has explicit Step 1.5 |
| 3 | Sentinel class chain claims `rlang_error` falsely | ✅ Resolved | §II.3.1 Step 2.1 chain is `c("surveytidy_pre_check_missing_var", "error", "condition")` and explicitly omits `rlang_error` |
| 4 | §IV.10 rowwise contradiction | ✅ Resolved | §IV.10 rewritten — rowwise state in `@variables$rowwise`; `@groups` invariant; `.may_change_groups = FALSE` |
| 5 | `is_rowwise()` predicate undefined | ✅ Resolved | §IV.10 sub-section adds `is_rowwise.survey_collection` |
| 6 | slice pre-flight evaluation context | ✅ Resolved | §IV.6 specifies `tryCatch(eval_tidy(quo, data = NULL))` for literal-only pre-flight |
| 7 | slice_min/slice_max bullets | ✅ Resolved | §IV.6 has explicit bullets |
| 8 | `name = "<other_column>"` undefined | ✅ Resolved | §V.1 step 2 documents class-catch path for `name` (but see new Issue 22) |
| 9 | glimpse `...` argument unused | ✅ Resolved | §V.2 signature now `(x, width = NULL, .by_survey = FALSE)` |
| 10 | Coercion footer truncation rule | ✅ Resolved | §XI.D7 specifies truncate-at-5 with `+ N more` |
| 11 | add_survey/remove_survey re-exports unverified | ✅ Resolved | §XIII.1 has Minimum surveycore version pin section; §X has DESCRIPTION pin checklist |
| 12 | `surveytidy_error_internal_groups_mutation` over-engineering | ✅ Resolved | §II.3.1 step 5 uses `stopifnot()`; class dropped from §VII.1 |
| 13 | Pre-check env-filter has no test coverage | ✅ Resolved | §IX.4 "Env-aware pre-check" test row added with five named cases |
| 14 | Domain-column preservation has no per-verb test | ✅ Resolved | §IX.3 has Domain column preservation row |
| 15 | visible_vars / @metadata not in test plan | ✅ Resolved | §IX.3 has two new rows |
| 16 | typed message class no test row | ✅ Resolved | §IX.4 row added; §IX.5 quality gate covers messages |
| 17 | Mixed-subclass design-variable rename | ✅ Resolved | §IX.3 has Subclass-asymmetric design columns row |
| 18 | PR 2 bundles 15 verbs | ✅ Resolved | §XII split into PRs 2a/2b/2c/2d |
| 19 | vctrs Imports addition not in deliverables | ✅ Resolved | §I.1 lists DESCRIPTION MODIFIED with `vctrs (>= 0.7.0)`; §X checklist updated |
| 20 | D6 @inheritParams from `@noRd` stub unverified | ✅ Resolved | §XI.D6 status DECIDED with verification reference |
| 21 | relocate pre-flight under-specified | ✅ Resolved | §IV.3 documents `relocate` is exempt from pre-flight; verified empirically |

### New Issues

#### Section: §V.1 `pull.survey_collection`

**Issue 22: `pull.survey_collection` detection mode contradicts the decisions log**
Severity: BLOCKING
Violates the contract-completeness lens; creates a load-bearing
inconsistency between the spec and the decisions log.

The decisions log (entry "2026-04-27 — Stage 3 spec-review resolution",
question for Pass-1 Issue 8) records:

> **Decision: B.** ... matches `pull.survey_base`'s actual evaluation
> semantics. Pre-checking with `all.vars()` would misclassify tidyselect
> helpers (`last_col()`, `where()`) as missing variables.

And the same entry's Outcome states: "`pull.survey_collection` uses
class_catch detection (Issue 8)".

But the current spec at §V.1 step 2 reads:

> - **`var` (pre-check).** A data-mask reference. Missing columns
>   surface only as a generic `rlang_error`, so the pre-check from
>   §II.3.1 step 2 (env-aware `all.vars()` on the captured quosure)
>   applies before the per-member `dplyr::pull` call.

And §II.4's verb matrix row for `pull` says: "pre-check + class-catch
| `var` is data-mask (pre-check); ...".

`dplyr::pull(.data, var = -1, ...)`'s `var` is documented `<tidy-select>`
and is internally resolved via `tidyselect::eval_select()`, not via
data-masking. A user calling `pull(coll, last_col())` would have
`last_col` flagged as a missing variable by the pre-check (because
`all.vars()` returns `"last_col"`, which is not in `@data` and won't
resolve in the calling env unless dplyr is on the search path) — exactly
the misclassification the decisions log cites as the reason for choosing
class-catch.

Options:
- **[A] Align spec to decisions log** — rewrite §V.1 step 2 and §II.4 to
  specify class-catch only for `pull`, with one handler covering both
  `var` (tidyselect failures → `vctrs_error_subscript_oob` or
  `rlang_error_data_pronoun_not_found`) and `name = "<column>"` (string
  subscript → `vctrs_error_subscript_oob`). Effort: low. Risk: low.
  Impact: implementer follows the decisions log; tests align.
- **[B] Re-litigate Decision B in Stage 4** — revert to pre-check for
  `var` if hybrid is genuinely needed. Effort: medium (Stage 4
  amendment). Risk: tidyselect-helper false positives (`last_col()`,
  `where(is.numeric)` flagged as missing).
- **[C] Do nothing** — spec contradicts log; implementer follows
  whichever they read second.

**Recommendation: A** — the decisions log is the authoritative record of
Stage 3 resolutions; the spec must reflect the decision. `var` in
`dplyr::pull` is unambiguously tidyselect, so class-catch is the
technically correct mode.

---

#### Section: §II.3.1 dispatcher step 5

**Issue 23: Atomic property update order on `out_coll` is unspecified**
Severity: REQUIRED
Violates the contract-completeness lens.

Step 5 of the dispatcher describes:

> Build `out_coll`:
> - `out_coll@surveys <- results`, in the original order minus skipped.
> - `out_coll@id <- collection@id`.
> - `out_coll@if_missing_var <- collection@if_missing_var`.
> - `out_coll@groups <- results[[1]]@groups`.

The spec does not specify how `out_coll` is created or how the four
`@<-` assignments interact with S7 validation. Two failure modes are
reachable depending on the implementer's choice:

**Failure mode A (clone-and-update).** If
`out_coll <- collection` (S7 clone) and properties are then updated in
the listed order, S7 validates after each `@<-`. For grouping verbs
(`group_by`, `ungroup`, `rename` of a group col), per-member methods
have already updated each member's `@groups` to the new value. After
`out_coll@surveys <- results`, the validator runs G1 against
`out_coll@groups` (still the OLD groups) — fails, because every member
now has the NEW groups.

**Failure mode B (constructor rebuild).** If
`out_coll <- as_survey_collection(!!!results, ...)`, the constructor
re-derives `@groups` from members. This works for grouping verbs but
adds a constructor round-trip on every dispatch.

CLAUDE.md memory documents the analogous "S7 validator bypass for
rename()" pattern (`attr(.data, "data") <- new_data` + `S7::validate()`
at the end) for exactly this kind of cross-property atomicity. The spec
is silent on whether to use that pattern, the constructor, or a different
approach.

Options:
- **[A] Specify constructor rebuild** —
  `out_coll <- surveycore::as_survey_collection(!!!results, .id = collection@id, .if_missing_var = collection@if_missing_var)`.
  Effort: low. Risk: low (one extra constructor call per dispatch).
  Impact: clean atomic update; validator runs once on consistent state.
- **[B] Specify attr-bypass + final validate** — mirrors
  `rename.survey_base`: clone, set properties via `attr()`, then
  `S7::validate(out_coll)`. Effort: low. Risk: medium (relies on S7
  internal behavior; CLAUDE.md memory notes the pattern works for
  rename's `@data`/`@variables` but not all S7 properties may behave
  identically).
- **[C] Specify ordered `@<-` updates with pre-update of `@groups` for
  grouping verbs** — for `.may_change_groups = TRUE`, set `@groups`
  first via attr-bypass, then `@surveys`. For `.may_change_groups = FALSE`,
  the listed order works. Effort: medium (two code paths). Risk: medium.
- **[D] Do nothing** — implementer guesses; non-grouping verbs work,
  grouping verbs hit a validator failure during implementation.

**Recommendation: A** — constructor rebuild is the simplest contract and
matches the surveycore-owns-construction architecture (surveytidy
doesn't reach into S7 internals on a class it doesn't own). The minor
overhead is acceptable for clarity.

---

#### Section: §IV.5, §IV.6 — `.by` argument handling

**Issue 24: `.by` argument handling for non-filter data-masking verbs is unspecified**
Severity: REQUIRED
Violates the contract-completeness lens.

§IV.1 (and §III.1's filter template) explicitly rejects `.by` on
`filter.survey_collection` with `surveytidy_error_filter_by_unsupported`.
But several other verbs in the dplyr 1.1+ API accept `.by`:

- `dplyr::mutate(.data, ..., .by = NULL, ...)` — `<tidy-select>`.
- `dplyr::slice_min(.data, order_by, n, by = NULL, ...)` — `.by` in dplyr ≥ 1.1.
- `dplyr::slice_max(...)` — same.
- `dplyr::slice_sample(.data, n, prop, weight_by = NULL, by = NULL, ...)` — same.
- `dplyr::summarise(.data, ..., .by = NULL, ...)` — same (not yet covered, but tracked
  as a future verb).

§IV.5 (`mutate.survey_collection`), §IV.6 (slice family), and the §III.1
method body template do not mention `.by`. Three plausible behaviors:

1. Forward `.by` through `...` to per-member calls.
2. Reject `.by` at the collection layer with a typed error.
3. Reject `.by` only when it would conflict with `coll@groups`.

CLAUDE.md memory ("dplyr 1.2.0 Compatibility Gotchas") notes that
`mutate.survey_base` requires careful handling of `.by` (only include
the arg in the dplyr call when non-NULL, to avoid tidyselect deprecation
warnings). The collection-layer behavior is undefined.

Options:
- **[A] Reject `.by` across all collection verbs that take it** —
  symmetric with filter. Add a row to §III.1 describing the rejection
  pattern and list the affected verbs (mutate, slice_min, slice_max,
  slice_sample). New shared error class
  `surveytidy_error_collection_by_unsupported`. Effort: low. Risk: low.
  Impact: prevents ambiguous semantics; users with `.by` intent set
  `coll@groups` instead.
- **[B] Forward `.by` to per-member with a documented contract note** —
  `.by` on the collection means "additionally group within each member";
  `coll@groups` already provides cross-survey-aware grouping. Effort:
  medium. Risk: medium (semantic ambiguity with `coll@groups`).
- **[C] Do nothing** — implementer chooses; users see inconsistent
  behavior across collection verbs.

**Recommendation: A** — the collection layer already has `coll@groups`
for grouping intent; `.by` is a per-call grouping override that doesn't
compose cleanly with collection-level groups. Rejecting it is the
simplest, safest contract and is symmetric with filter. Reusing
`surveytidy_error_filter_by_unsupported` is also viable but the class
name implies filter-only; a collection-scoped class is cleaner.

---

#### Section: §IX.2 helper contract

**Issue 25: `make_heterogeneous_collection()` contract is underspecified**
Severity: REQUIRED
Violates the contract-completeness lens.

§IX.2 introduces `make_heterogeneous_collection(seed)` with one sentence:

> "A second helper `make_heterogeneous_collection(seed)` returns a
> collection whose members have different column sets — used to test
> `.if_missing_var = "skip"` and `any_of()` behavior under V2."

The implementer must invent: how many members; which design subclasses;
which columns differ; which columns are common; whether group columns
are uniform across members (G1b requires this, so they must be);
whether member names are deterministic. Without this contract,
`.if_missing_var = "skip"` tests, V2 `any_of()` tests, and the §IX.3
cross-design tests have no shared, reproducible fixture.

By contrast, `make_test_collection()` is fully specified (§IX.2's first
paragraph: 3 members, one of each design subclass, sharing
`make_all_designs()` schema, `.id = ".survey"`,
`.if_missing_var = "error"`).

Options:
- **[A] Add a full contract for `make_heterogeneous_collection()`** —
  e.g., 3 members, all `survey_taylor`, schemas: member 1 has
  `c(psu, strata, fpc, wt, y1, y2, y3, group)`, member 2 has
  `c(psu, strata, fpc, wt, y1, group)` (drops y2, y3), member 3 has
  `c(psu, strata, fpc, wt, y2, y3, group, region)` (drops y1, adds
  region). Group column `group` is uniform across members per G1b.
  Effort: low.
- **[B] Inline the test data per test** — heterogeneity construct happens
  inside each test that needs it. Effort: medium (boilerplate). Risk:
  drift across tests.
- **[C] Do nothing** — implementer guesses.

**Recommendation: A** — a shared fixture with explicit contract is
cheaper to maintain than per-test inline construction, and ensures the
V2 `any_of()` test and the `.if_missing_var = "skip"` tests are
exercising the same heterogeneity pattern.

---

#### Section: §IX (Testing — invariant helper)

**Issue 26: `test_invariants()` is not defined or specified for `survey_collection`**
Severity: REQUIRED
Violates `testing-surveytidy.md` (which mandates `test_invariants()` as
the first assertion in every verb test block) and the test-completeness
lens.

`testing-surveytidy.md` declares:

> Every `test_that()` block that creates or transforms a survey object
> must call `test_invariants(design)` as its **first** assertion.

The existing `test_invariants(design)` helper (per `helper-test-data.R`
and CLAUDE.md memory) asserts six properties on a `survey_base`
instance: `@data` is a data.frame, has ≥ 1 row, no duplicate column
names, design vars exist, weights numeric+positive, every `visible_vars`
exists. None of these apply to a `survey_collection` (which has
`@surveys`, `@id`, `@if_missing_var`, `@groups`, no `@data`).

The spec (§IX.1, §IX.2, §IX.3, §IX.4) does not define a collection-level
analog (e.g., `test_collection_invariants()`) and does not say whether
per-verb collection tests should: iterate `test_invariants()` over each
member; skip the rule because the helper doesn't apply; or define a new
helper.

Options:
- **[A] Define `test_collection_invariants()` in `helper-test-data.R`** —
  assert: every member is `survey_base`; every member's `@groups` equals
  collection's `@groups` (G1); collection's `@id` is character(1);
  `@if_missing_var ∈ {"error", "skip"}`; for each group column, every
  member contains it (G1b); `length(@surveys) ≥ 1`. Then update §IX.1 /
  §IX.3 to require `test_collection_invariants(coll)` as the first
  assertion in every collection verb test, AND `test_invariants(member)`
  iterated over `coll@surveys`. Effort: low. Impact: tests inherit
  per-member discipline + collection discipline.
- **[B] Specify "iterate `test_invariants()` over `@surveys`" only** —
  no new helper. Risk: collection-specific invariants (G1, G1b at the
  collection level, @id format) go unchecked.
- **[C] Document that collection tests skip `test_invariants()`** —
  explicit opt-out. Risk: regression in member-level invariants would
  slip through.
- **[D] Do nothing** — implementer guesses.

**Recommendation: A** — adds the helper. It's the only option that
preserves the testing-surveytidy.md invariant-first discipline at the
collection layer while also asserting member-level invariants. Effort
is trivial; the helper is ~10 lines.

---

#### Section: §I.3 Design Support Matrix

**Issue 27: §I.3 misstates which surveycore invariants enforce member-class type**
Severity: SUGGESTION
Violates `engineering-preferences.md` §5 (explicit over clever).

§I.3 says:

> "The class invariant (G1 / G1b / G1c, enforced in surveycore)
> requires every member of a `survey_collection` to be a `survey_base`
> instance."

Per §VII.2: G1 is the `@groups` invariance check, G1b is "every group
column exists in every member's `@data`", G1c is "group vector is
well-formed". None of these enforce member class type. The "every
member is a `survey_base`" check is a separate property-type validation
enforced by surveycore's S7 class definition.

Misreading risk: a future surveytidy contributor reads §I.3 and assumes
the G1 family is what guards member class — then writes a test that
asserts G1 fires when a non-`survey_base` is added, when actually a
different class would fire. Or "simplifies" the type-check thinking
they're touching G1.

Options:
- **[A] Rewrite §I.3** — separate the two invariants: "Member type
  validation (separate from G1/G1b/G1c, enforced by surveycore's S7
  class definition) requires every member to be a `survey_base`
  instance. The G1/G1b/G1c invariants are about `@groups` consistency
  across members." Effort: trivial.
- **[B] Do nothing.**

**Recommendation: A** — accurate spec wording prevents future
contributor confusion at trivial cost.

---

#### Section: §II.3.1 dispatcher signature

**Issue 28: Dispatcher signature has a required argument after optional arguments**
Severity: SUGGESTION
Violates `code-style.md` §4 argument-order convention.

The dispatcher signature:

```r
.dispatch_verb_over_collection <- function(
  fn,
  verb_name,
  collection,
  ...,
  .if_missing_var = NULL,
  .detect_missing,            # required, no default
  .may_change_groups = FALSE
)
```

`.detect_missing` is required (no default per the parameters table). It
appears at position 7, AFTER `...` (position 4) and
`.if_missing_var = NULL` (optional, position 5). The convention:

> 3. Required scalar arguments (non-NSE arguments with no default)
> 5. Optional scalar control arguments

`.detect_missing` belongs at position 3 but sits at position 7. This
is internal and the convention's enforcement is softer for private
helpers, but a required arg buried after optional args is easy to
forget at call sites — the `stopifnot()` checks specified for
`.may_change_groups` would silently mask the omission depending on
match.arg behavior.

Options:
- **[A] Give `.detect_missing` a default of `"none"`** — verb methods
  with detection always pass an explicit value; callers that forget get
  the safest no-op default. Effort: trivial.
- **[B] Move `.detect_missing` ahead of `...`** — all per-verb method
  calls already use named args (per §III.1 template) so this is a
  signature-only change. Effort: trivial.
- **[C] Do nothing** — internal helper; convention is advisory.

**Recommendation: A** — defaulting to `"none"` is the safest and most
explicit choice; verbs that need detection must opt in.

---

#### Section: §IV.4 rename group-partial pre-flight

**Issue 29: `surveytidy_error_collection_rename_group_partial` is unreachable for plain `rename` given G1b**
Severity: SUGGESTION
Edge-case lens; `engineering-preferences.md` §3 (engineered enough —
flag over-engineering for cases that can't fire).

§IV.4 specifies a pre-flight for both `rename.survey_collection` and
`rename_with.survey_collection` that raises
`surveytidy_error_collection_rename_group_partial` when "any `old_name`
in the rename map is in `coll@groups`" and "every member must contain
the column".

For plain `rename`: the rename map is identical across members (it's
the user's bare-name mapping). If `old_name ∈ coll@groups`, then by G1b,
`old_name` exists in every member's `@data`. The "members lacking it"
case cannot fire — G1b already guarantees member coverage of group
columns.

For `rename_with`: the rename map can differ per member because `.cols`
is tidyselect-resolved per-member. A `.cols = where(is.factor)` could
resolve to `psu` in member A (factor) and not in member B (numeric).
If `psu` is in `coll@groups`, the rename map includes psu→new for A
but not B — the partial-rename scenario. This is genuinely reachable.

The spec applies the same pre-flight to both verbs without distinguishing
reachability. For plain `rename`, the check is dead code — though cheap;
for `rename_with`, it's load-bearing. A future contributor reading
"`rename` has a check for group-column coverage" might "simplify" the
plain-`rename` branch away thinking it's redundant.

Options:
- **[A] Document the rename-vs-rename_with reachability difference** —
  add a note in §IV.4: "the plain-`rename` pre-flight is structurally
  redundant given G1b (group columns are guaranteed to exist in every
  member by class invariant) but kept as defense-in-depth at trivial
  cost. The `rename_with` pre-flight is load-bearing because `.cols`
  can resolve differently per member." Effort: trivial.
- **[B] Scope the pre-flight to `rename_with` only** — `rename.survey_collection`
  skips it (G1b is sufficient). Effort: trivial.
- **[C] Do nothing.**

**Recommendation: A** — the redundancy is a feature (defense-in-depth at
trivial cost) but the reasoning belongs in the spec so a future
contributor doesn't "simplify" away the protective branch.

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 4 |
| SUGGESTION | 3 |

**Total new issues:** 8

**Overall assessment:** The spec is in very good shape after Stage 3
Pass 1's resolutions — all 21 prior issues are closed and reflected in
the spec. Pass 2 surfaces one BLOCKING contradiction between the
decisions log and the spec for `pull.survey_collection`'s detection
mode (Issue 22 — log says class-catch only; spec says pre-check for
`var` + class-catch for `name`). Four REQUIRED issues are contract
gaps that would surface at implementation time: dispatcher property
update atomicity for grouping verbs (Issue 23), `.by` argument handling
on non-filter verbs (Issue 24), `make_heterogeneous_collection()`
contract (Issue 25), and `test_invariants()` for collections
(Issue 26). The remaining three SUGGESTIONs are spec-precision
improvements. After Issue 22 is resolved and the four REQUIRED gaps are
closed, the spec should be implementation-ready.
