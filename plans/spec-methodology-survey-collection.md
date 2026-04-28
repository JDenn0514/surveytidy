## Methodology Review: survey-collection — Pass 1 (2026-04-27)

### Scope Assessment

This feature implements `verb.survey_collection` methods for every dplyr/tidyr
verb that surveytidy already provides for `survey_base`, plus collapsing
verbs (`pull`, `glimpse`) and join error stubs. Per the assessment checklist:

- Verbs that create/read/modify the domain column: yes — `filter`,
  `filter_out`, `drop_na` per V4 propagate per-member domain semantics.
- Verbs that change row count: yes — `slice`, `slice_*`, `distinct`,
  plus `.if_missing_var = "skip"` drops members from the collection itself.
- Verbs that affect design variable columns: yes — `rename`, `select`,
  `mutate` operate per-member on whatever the user names, including
  weight/strata/PSU columns.
- Verbs that change `@variables`, `@metadata`, `@groups`, `visible_vars`:
  yes — propagated per-member; collection-level `@groups` is also synced.
- Verbs that affect row count or order: yes — `arrange`, `slice_*`,
  `distinct` within members; the collection itself can shrink under skip.

All five lenses apply.

---

### New Issues

#### Lens 1 — Domain Semantics

**Issue 1: Pre-check via `all.vars()` falsely flags environment-bound names as missing variables**
Severity: BLOCKING
Lens: 1 — Domain Semantics
Resolution type: UNAMBIGUOUS

§II.3.1 step 2 (pre-check path) says: "extract referenced bare names from
the captured `...` quosures via `all.vars()` and compare them to
`names(collection@surveys[[nm]]@data)` BEFORE calling `fn(survey, ...)`."

This heuristic is too aggressive. `all.vars()` returns every bare name in
argument position — including names that the data mask resolves from the
quosure's enclosing environment, not from `@data`. Concrete example:

```r
allowed_ages <- c(18, 21, 65)
filter(coll, age %in% allowed_ages)
```

`all.vars(quote(age %in% allowed_ages))` returns `c("age", "allowed_ages")`.
Under the spec, the pre-check sees `allowed_ages` is not in
`names(survey@data)` and synthesizes a missing-variable signal. Under
`.if_missing_var = "error"` the verb errors naming a column that does not
exist in the user's intent. Under `"skip"` the survey is silently dropped.
Both are wrong: the `survey_base` filter would resolve `allowed_ages` from
the enclosing env via standard data-masking semantics.

The same defect breaks any expression that references locally-defined
constants, helper functions, or parameters in a function that wraps a
survey verb call. Since the pre-check sits on the hot path for every
data-masking verb (`filter`, `filter_out`, `mutate`, `arrange`, `group_by`,
`slice_min`, `slice_max`, `pull`), this corrupts the contract for the
majority of verbs.

**Fix:** the pre-check must filter `all.vars()` output through the
quosure's calling environment. For each bare name, check
`exists(name, envir = rlang::quo_get_env(quo), inherits = TRUE)`. If the
name resolves in the env, treat it as a non-data-mask reference and
exclude it from the pre-check. Only names that are unresolved in the env
AND absent from `@data` are missing-variable signals.

Also exclude pronoun guards — `.data` and `.env` should never be flagged.

**Recommendation: rewrite §II.3.1 step 2** — Specify that the pre-check
filters through `rlang::quo_get_env(quo)` AND excludes `.data` / `.env`
pronouns before checking against `names(survey@data)`.

---

**Issue 2: `glimpse.survey_collection` default mode exposes `..surveycore_domain..` as a visible column**
Severity: REQUIRED
Lens: 1 — Domain Semantics
Resolution type: JUDGMENT CALL

§V.2 default mode (`bind_rows(map(@surveys, function(s) s@data))`) directly
binds member `@data` frames. Each filtered member's `@data` carries the
internal `..surveycore_domain..` (`surveycore::SURVEYCORE_DOMAIN_COL`)
logical column. The combined glimpse output exposes it as a user-visible
column named `..surveycore_domain..` with TRUE/FALSE values.

This leaks an implementation detail into a diagnostic surface. Users who
filtered upstream see a column they didn't add; users who didn't filter
don't see it (since the column is absent until the first `filter()` call,
per surveycore). The inconsistency itself is confusing.

Options:
- **A** Drop `..surveycore_domain..` from the glimpse render. Glimpse becomes
  a "data view"; users wanting to see domain status use a separate verb.
  Effort: low. Risk: low. Impact: cleaner default.
- **B** Rename to `.in_domain` for display only (leave member `@data`
  untouched). Effort: low. Risk: low. Impact: more discoverable.
- **C** Leave as-is and document. Effort: zero. Risk: low. Impact: user
  confusion remains.

**Recommendation: B** — Renaming for display preserves the diagnostic
value (users can see which rows are out of domain) without exposing the
internal column name. Drop the rename only if `@data` already lacks the
column in every member.

---

**Issue 3: Spec is silent on transitive domain preservation for non-domain verbs**
Severity: SUGGESTION
Lens: 1 — Domain Semantics
Resolution type: UNAMBIGUOUS

The Stage 2 reference asks: "For verbs that don't touch the domain: does
the spec state explicitly that an existing domain column passes through
unchanged?"

The spec does not say this. The behavior is correct *by transitive
property of per-member dispatch* (per-member `select`, `mutate`, `arrange`,
`rename` all preserve the domain column), but the contract is implicit.

**Fix:** add one sentence to §III.3 ("Output Contract") stating that for
every standard verb, the per-member domain column (if present) is
preserved on every member that survives `.if_missing_var = "skip"`.

**Recommendation: A** — Add the explicit sentence; aligns with the V4
"domain emptiness is a per-survey signal" principle.

---

**Issue 4: `pull.survey_collection` silent on out-of-domain row inclusion**
Severity: SUGGESTION
Lens: 1 — Domain Semantics
Resolution type: JUDGMENT CALL

§V.1 specifies that `pull.survey_collection` calls `dplyr::pull(survey, ...)`
per member and combines results via `vctrs::vec_c()`. The spec does not
state whether out-of-domain rows are included.

This is fundamentally a `pull.survey_base` contract question — but
`pull.survey_collection`'s combined-vector output is the user-facing
result, and the user has no way to tell which elements were in-domain vs
out-of-domain. If the per-member `pull` returns the entire `@data[[var]]`
column without respect to domain, the collection-level pull silently
mixes domain and non-domain values.

Options:
- **A** Inherit `pull.survey_base` semantics whatever they are; spec
  cross-references that contract.
- **B** Filter to in-domain rows at the collection layer (or document
  that the collection layer relies on `pull.survey_base` doing it).
- **C** Add a `.domain_only = TRUE` argument with documented default.

**Recommendation: A** — verify `pull.survey_base`'s domain handling and
add a one-line note in §V.1 cross-referencing it. If `pull.survey_base`
does not filter, surface this as a known issue at the verb level (not the
collection level).

---

#### Lens 2 — Row Universe Integrity

**Issue 5: `slice_*.survey_collection` silent on per-member `surveycore_warning_physical_subset` propagation**
Severity: REQUIRED
Lens: 2 — Row Universe Integrity
Resolution type: UNAMBIGUOUS

§IV.6 covers `arrange.survey_collection`, `slice.survey_collection`, and
`slice_*`. The spec says "per-member operation" but does not state that
each member's `slice_*.survey_base` call fires
`surveycore_warning_physical_subset` per-member, just as V4 does for
`surveycore_warning_empty_domain`.

This matters because:
1. A 5-member collection sliced via `slice_head(5)` raises 5 warnings.
2. The spec's V4 explicitly addresses this for empty-domain (per-survey,
   not collection-rebranded). The same principle should be stated
   explicitly for physical-subset.
3. Tests should assert the warning class is preserved, not silently
   wrapped.

**Fix:** add a sentence to §IV.6 mirroring V4's treatment:
"Each `slice_*.survey_base` call emits `surveycore_warning_physical_subset`
per member; the dispatcher does not interpose. Class is preserved so
`withCallingHandlers()` consumers see the same signal as for single-survey
slices."

**Recommendation: A** — Add the explicit sentence; mirrors V4 and
§IX.5's typed-warning testing requirement.

---

**Issue 6: `.if_missing_var` advertised on `slice` / `slice_head` / `slice_tail` / `slice_sample` (no `weight_by`) but detection mode is `n/a` — argument is inert**
Severity: REQUIRED
Lens: 2 — Row Universe Integrity
Resolution type: UNAMBIGUOUS

§II.4 verb matrix shows `.if_missing_var = "yes"` for these four verbs
*and* detection mode `n/a`. §III.2 also says "`.if_missing_var = NULL` at
the end of optional scalars" for every verb method. Combining these:
these four verbs accept `.if_missing_var` as an argument but it does
nothing — they reference no user columns, so detection never triggers.

This is an API design hazard: a user passing `.if_missing_var = "skip"`
to `slice_head(coll, 5)` will assume the argument has effect, but every
member is processed regardless. Worse, no warning fires to indicate the
arg was ignored.

Options:
- **A** Drop `.if_missing_var` from the signatures of `slice`,
  `slice_head`, `slice_tail`, and `slice_sample` (when `weight_by` is
  unset). Keep on `slice_min`/`slice_max` (their `order_by` IS a column
  reference) and `slice_sample` only when `weight_by` is set.
- **B** Keep `.if_missing_var` everywhere for API uniformity and
  document explicitly that it is a no-op on these verbs.
- **C** Keep on every verb and emit a typed warning if the user passes
  a non-NULL value to a verb where it has no effect.

**Recommendation: A** — API consistency arguments are weaker than the
"never advertise an argument that doesn't do anything" rule from
`engineering-preferences.md` ("Don't add error handling, fallbacks, or
validation for scenarios that can't happen"). Symmetry across verbs
isn't worth a silently-inert argument.

---

**Issue 7: `slice_head(coll, n = 0)` produces 0-row members; spec does not address the per-member S7 validator collision**
Severity: REQUIRED
Lens: 2 — Row Universe Integrity
Resolution type: JUDGMENT CALL

`slice_head(coll, n = 0)` (and `slice_tail(0)`, `slice_sample(n = 0)`,
`slice(coll, integer(0))`, etc.) cause every per-member `@data` to have
0 rows. `test_invariants()` requires `@data` has ≥ 1 row, and the surveycore
validator on each member's `survey_base` class will fail.

What happens under the spec:
1. The dispatcher applies `dplyr::slice_head(survey, n = 0)` to the first
   member.
2. The S7 validator on the rebuilt `survey_base` member errors.
3. The dispatcher does not catch this error (it's not a missing-variable
   signal), so it propagates up.
4. The user sees a `survey_base` validator error from the *first* member,
   with no indication that the underlying problem is `n = 0` applied to
   the entire collection.

Compare to `filter(coll, age > 9999)` where every member's domain becomes
all-FALSE: per V4 the surveys remain in the collection (with empty
domain) — domain emptiness is a per-survey signal, not a removal trigger.
Slice with n=0 has the analogous structure but a different outcome
because slice physically removes rows.

Options:
- **A** Reject `n = 0` (or empty integer index) at the collection layer
  with a typed error (`surveytidy_error_collection_slice_zero`) before
  dispatch.
- **B** Document the pass-through behavior; the user sees the
  `survey_base` validator error and infers the cause.
- **C** Wrap the per-member validator failure in a collection-aware
  error class that names the verb and the offending arg.

**Recommendation: A** — The collection layer can intercept this
inexpensively, the error is more diagnostic, and users do not need to
understand survey class internals to debug. This mirrors D3's pattern
of "pre-flight at the collection layer when the consequences are
structurally unrecoverable."

---

#### Lens 3 — Design Variable Integrity

**Issue 8: `select.survey_collection` removing a group column produces an unhelpful G1b error that does not name the verb**
Severity: REQUIRED
Lens: 3 — Design Variable Integrity
Resolution type: JUDGMENT CALL

D3 added a pre-flight to `rename.survey_collection` /
`rename_with.survey_collection` for group-column safety, raising
`surveytidy_error_collection_rename_group_partial` BEFORE any member is
touched. The reasoning: the post-rename G1b invariant is structurally
unrecoverable (skipping the offending member silently drops the user's
grouping; allowing it through violates G1).

The same problem exists for `select.survey_collection` /
`relocate.survey_collection`. Examples:

```r
select(coll, -region)              # region is in coll@groups
select(coll, age, income)          # region (in @groups) is excluded
```

Per V2, each member evaluates tidyselect against its own data. After
per-member select, every member's `@data` lacks `region`. The validator
G1b (`surveycore_error_collection_group_not_in_member_data`) fires on
the rebuilt collection. The error message says "group column 'region'
not in member 'X'@data" — which is accurate but misleading: the actual
cause is `select(-region)`, not member X.

Options:
- **A** Add a verb-layer pre-flight: before dispatch, resolve the
  tidyselect against any member's data (uniformity + V2 permits) and
  check whether any column in `coll@groups` would be removed. If yes,
  raise `surveytidy_error_collection_select_group_removed` naming the
  group column and the verb.
- **B** Defer to the validator. Document the validator's error in select's
  roxygen so the user knows what triggers it.
- **C** Allow select to drop group columns and silently update
  `coll@groups` to the surviving subset. Rejected by D3's reasoning.

**Recommendation: A** — Symmetric with D3 and the same structural
argument applies. Cost is low (one pre-flight check); diagnostic value
is high.

---

**Issue 9: `rename` of a non-group design variable produces N copies of `surveytidy_warning_rename_design_var`**
Severity: SUGGESTION
Lens: 3 — Design Variable Integrity
Resolution type: JUDGMENT CALL

`rename.survey_base` warns with `surveytidy_warning_rename_design_var`
when the user renames a design variable (weights, ids, strata, fpc). On
a 5-member collection, the user sees 5 warnings — the same warning for
the same rename, multiplied by membership.

This is methodologically harmless (the rename is applied correctly) but
UX-noisy. Worse, it makes `withCallingHandlers()` consumers harder to
reason about: a single user-intention triggers N condition firings.

Options:
- **A** Document the per-member multiplicity and leave as-is.
- **B** Batch the warning at the collection layer: one warning naming
  every member that triggered it.
- **C** Suppress the per-member warning and emit one collection-level
  warning instead.

**Recommendation: A** — Per-member dispatch is the architectural
contract; rebatching at the verb layer adds complexity for marginal UX
gain and breaks symmetry with the empty-domain warning (V4) which
likewise fires per-member.

---

#### Lens 4 — Variance Estimation Validity

**Issue 10: Dispatcher reads `@groups` from `results[[1]]` without invariance check for non-grouping verbs**
Severity: REQUIRED
Lens: 4 — Variance Estimation Validity
Resolution type: UNAMBIGUOUS

§II.3.1 step 5 says: `out_coll@groups <- results[[1]]@groups`. §III.4
justifies this for `group_by`, `ungroup`, and `rename`-of-group-col
because the per-member methods all update their own `@groups`
synchronously (G1).

For non-grouping verbs (`filter`, `mutate`, `arrange`, `select`,
`distinct`, `slice_*`, etc.), the contract is that `@groups` is
unchanged. The dispatcher does not enforce this — it reads
`results[[1]]@groups` and trusts it. A buggy per-member method that
silently mutates `@groups` would corrupt the collection invisibly. The
G1 validator catches *uniformly* divergent groups (all members agree but
differ from the input), but not the non-grouping-verb invariance
contract.

Concrete failure mode: a future surveytidy verb method has a bug that
clears `@groups` to `character(0)`. Every per-member call clears
synchronously (so G1 holds). The collection's `@groups` silently goes
from `c("region")` to `character(0)`. Phase 1 estimation downstream then
runs ungrouped without error.

**Fix:** in the dispatcher, after step 5, assert that for verbs in a
documented non-grouping set, `out_coll@groups` equals
`collection@groups`. If not, raise an internal error
(`surveytidy_error_internal_groups_mutation`). Document the
grouping-verb whitelist (`group_by`, `ungroup`, `rename`,
`rename_with`).

Alternative: have the dispatcher take an explicit
`.expect_groups_change = c("group_by", "ungroup", "rename", "rename_with")`
flag, and assert no-op otherwise.

**Recommendation: B** — Make the dispatcher accept an explicit
`.may_change_groups` boolean flag (default `FALSE`). When `FALSE`,
assert `out_coll@groups == collection@groups` after step 5. Set `TRUE`
only for `group_by`, `ungroup`, `rename`, `rename_with`. This catches
silent corruption without dragging the verb name into the dispatcher.

---

**Issue 11: `mutate` of a weight column produces N copies of `surveytidy_warning_mutate_weight_col` on an N-member collection**
Severity: SUGGESTION
Lens: 4 — Variance Estimation Validity
Resolution type: JUDGMENT CALL

Symmetric to Issue 9 (rename design variable). Per-member dispatch
multiplies the warning count.

**Recommendation: A** — Document and accept; same reasoning as Issue 9.

---

#### Lens 5 — Structural Transformation Validity

**Issue 12: Pre-check sentinel format is unspecified**
Severity: REQUIRED
Lens: 5 — Structural Transformation Validity
Resolution type: UNAMBIGUOUS

§II.3.1 step 2 says the pre-check synthesizes "an internal sentinel
condition." §II.3.1 step 2 also says the dispatcher re-raises with
`parent = cnd` where "for the pre-check path, `cnd` is the internal
sentinel synthesized by the dispatcher." §IX.3 references this in the
test contract: "with the original tidyselect/rlang condition as parent
(... or the dispatcher's pre-check sentinel — see D1)."

But the spec does not specify:
- The sentinel's class (a typed condition class? `simpleCondition`?
  unclassed list?).
- What fields the sentinel carries (column name? survey name? quosure?).
- Whether the sentinel is exported / part of any public API.
- Whether tests can rely on a stable sentinel class in
  `expect_error(class = ...)`.

§IX.3's `surveytidy_error_collection_verb_failed` test category requires
a snapshot of the message text. If the sentinel class is unstable, the
snapshot will diff with each implementation tweak.

**Fix:** specify the sentinel as a typed condition with a stable class.
Recommended:

```r
class = c("surveytidy_pre_check_missing_var", "rlang_error", "error", "condition")
```

Fields: `$missing_vars` (character), `$survey_name` (character),
`$quosure` (the offending quosure for diagnostics).

Add to §VII.1 as an internal-only typed condition (parallel to the
existing `surveytidy_message_collection_skipped_surveys`).

**Recommendation: A** — Specify the sentinel class and fields in
§II.3.1 and add it to §VII.1's table marked "internal — not part of
public condition API but stable for parent-chain testing."

---

**Issue 13: `glimpse.survey_collection` default mode prepends `.survey` (or `coll@id`) which collides with a user-named column**
Severity: SUGGESTION
Lens: 5 — Structural Transformation Validity
Resolution type: JUDGMENT CALL

§V.2 default mode: "`combined <- dplyr::bind_rows(...)`, prepending a
`.survey` column resolved from `x@id`."

If the user has a `.survey` column in any member's `@data` (or whatever
`coll@id` resolves to), `bind_rows` will produce two columns with the
same name — undefined behavior or coercion fail. The spec is silent on
this collision.

Options:
- **A** Pre-check: if `coll@id` exists as a column in any member, error
  with `surveytidy_error_collection_glimpse_id_collision` before
  binding.
- **B** Detect the collision and rename the prepended column to
  `<id>_member` or similar.
- **C** Document and let `bind_rows` raise its own error.

**Recommendation: A** — Mirrors surveycore's
`surveycore_error_collection_id_collision` (mentioned in the design
sketch at line 110). Same problem, same solution.

---

**Issue 14: Inconsistency between §II.3.1 step 4 (proactive empty-result check) and §VII.2 (validator-catch description)**
Severity: SUGGESTION
Lens: 5 — Structural Transformation Validity
Resolution type: UNAMBIGUOUS

§II.3.1 step 4: "If `length(results) == 0L`, raise
`surveytidy_error_collection_verb_emptied`" — proactive check before
construction.

§VII.2: `surveycore_error_collection_empty` "raised by the surveycore
validator if `out_coll@surveys` is length 0. The dispatcher catches this
at step 4 and re-raises..." — implies the validator fires and dispatcher
catches.

These describe the same outcome via different mechanisms. If the
dispatcher proactively checks, the validator never fires. If the
dispatcher relies on the validator, step 4 should describe a
`tryCatch(... surveycore_error_collection_empty = ...)`. Pick one.

**Fix:** decide which mechanism is canonical and update the other section.

**Recommendation: A — proactive** (per §II.3.1 step 4). The validator is
a safety net; the dispatcher should never produce a state where it
fires. Simpler, faster, and the verb name + `.if_missing_var` source
template (§VII.3) is owned by the dispatcher anyway. Update §VII.2 to
say: "The dispatcher's step-4 check prevents this from ever reaching
the validator. The validator class is documented as a safety net only."

---

**Issue 15: §II.3.1 step 4 references "fn's name" but `fn` is a function object without an intrinsic name**
Severity: SUGGESTION
Lens: 5 — Structural Transformation Validity
Resolution type: UNAMBIGUOUS

§II.3.1 step 4 says the dispatcher reports "the verb name (passed in via
`fn`'s name)." But `fn` is a function (e.g., `dplyr::filter`), and
function objects do not carry their bound name intrinsically — the only
ways to recover "filter" from `fn` are heuristic (deparse the call,
match against a known set, etc.).

The cleaner fix is to add an explicit `verb_name` parameter to
`.dispatch_verb_over_collection()`, as the verb name is needed by:
- The empty-result error message (§VII.3).
- The skipped-surveys message (§II.3.1 step 3).
- The re-raise via `surveytidy_error_collection_verb_failed` (§II.3.1
  step 2).

**Fix:** add `verb_name = chr(1)` (required) to the dispatcher
signature in §II.3.1. Each verb method passes its own name as a literal
string.

**Recommendation: A** — Add the parameter; trivially fixes all three
message-generation paths.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 8 |
| SUGGESTION | 6 |

**Total issues:** 15

**Overall assessment:** The methodology is largely sound — the V1–V9
design decisions are coherent, the dispatcher's six-step contract
addresses the right concerns, and the per-member dispatch model
correctly inherits per-survey verb semantics. However, the pre-check
implementation as specified (Issue 1) silently corrupts the
contract for any data-masking verb that references environment-bound
helpers — a defect that affects the majority of verbs and would cause
production code to error or silently skip surveys. Beyond that, two
patterns recur: (a) the spec under-specifies what happens at structural
boundaries where the per-member abstraction leaks into the collection
layer (`select` removing a group column, `slice` with `n = 0`, glimpse's
`.survey` collision) — Issues 7, 8, 13 each propose a D3-style verb-layer
pre-flight; (b) several internal contracts (the pre-check sentinel
format, `verb_name` plumbing, the empty-result mechanism) are described
in two places with subtle inconsistencies. The methodology becomes
implementable once Issue 1 is fixed and Issues 7, 8, 10, 12 are
resolved with explicit pre-flights and contract specifications.
