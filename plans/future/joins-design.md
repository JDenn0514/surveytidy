# Join Functions in surveytidy — Design Plan

**Status:** Draft — not yet scheduled for implementation
**Relates to:** `R/08-joins.R` (stretch goal in Phase 0.5 build order)

---

## 1. Scope

Eight dplyr join functions fall into two categories:

**Mutating joins** (add columns): `left_join`, `inner_join`, `right_join`, `full_join`, `bind_cols`

**Filtering joins** (filter rows, no new columns): `semi_join`, `anti_join`, `bind_rows`

---

## 2. The Core Tension

Plain `left_join(df1, df2)` is an unrestricted data operation. For survey objects,
every operation must answer: *does this preserve the validity of variance estimation?*

The survey-specific constraints:

- **Row count is sacred** — adding rows with NA design variables produces an invalid
  design; row expansion (duplicated respondents) invalidates variance estimation
- **Design variables cannot be removed** — any join that overwrites a strata/PSU/weight
  column corrupts the design
- **Domain column travels with rows** — any row-altering operation must update
  `..surveycore_domain..`
- **Twophase designs have a two-tier row structure** — phase1 rows (all) + phase2 rows
  (subset); even a "safe" left join must not break that invariant

---

## 3. Proposed Behavior by Function

### `left_join(survey, data.frame, ...)` — Supported

This is the primary use case: adding lookup data to a survey (geographic codes,
administrative variables, reference tables). All survey rows are preserved; new
columns are added from the right-hand side.

**Constraints:**

1. `y` must not be a survey object (→ error: `surveytidy_error_join_survey_to_survey`)
2. `y` must not have columns named the same as design variables (→ warning:
   `surveytidy_warning_join_col_conflict`; drop conflicting cols from `y` before joining)
3. Row count must not expand (→ error: `surveytidy_error_join_row_expansion`; tells user
   to `distinct(y, key_col)` first)

**Metadata handling:** New columns from `y` get no labels in `@metadata` (metadata comes
from surveycore's haven import; externally joined data doesn't carry SPSS/Stata labels).
If `visible_vars` was set, new columns are appended to it.

**Domain column:** Unchanged — left join preserves all survey rows.

---

### `inner_join(survey, data.frame, ...)` — Physical subset + warn

Inner join removes unmatched survey rows. This is the same as `subset()` — it
physically removes rows, which can bias variance estimates.

**Proposed behavior:** Issue `surveycore_warning_physical_subset`. Return a survey object
with fewer rows.

**Why not error?** Inner join is legitimately used when the analyst *knows* the lookup
table covers exactly the rows they want to analyze. Blocking it entirely is too
restrictive. But the warning makes the consequence explicit.

**Alternative worth considering:** Implement inner_join as `semi_join(survey, y) |>
left_join(y)` — domain-aware filtering + column addition. This is more survey-correct but
surprising to users who expect inner_join semantics. See Open Question Q1 below.

**Empty result:** If all rows are unmatched → `surveycore_warning_empty_domain`.

---

### `right_join(survey, data.frame, ...)` — Error

Right join would add rows from `y` that have no match in the survey. Those rows would
have `NA` for all design variables (weights, PSUs, strata), producing a structurally
invalid object. There is no meaningful survey interpretation.

Error class: `surveytidy_error_join_adds_rows`

*Tell users: use `left_join()` to add lookup columns, or `filter()` for domain
restriction.*

---

### `full_join(survey, data.frame, ...)` — Error

Same problem as `right_join`: can add rows from `y` with NA design variables.
Additionally creates ambiguity about which rows are "in the survey."

Error class: `surveytidy_error_join_adds_rows` (same class, different message)

---

### `semi_join(survey, data.frame, ...)` — Domain-aware (like `filter()`)

Semi join keeps only survey rows that have a match in `y`. Rather than physically
removing rows, implement this as a domain filter: unmatched rows get `domain = FALSE`.

This is the preferred survey approach:

```r
# What it does internally:
matched_rows <- which(x@data has a match in y)
new_domain <- existing_domain & (row_index %in% matched_rows)
x@data[[SURVEYCORE_DOMAIN_COL]] <- new_domain
```

This preserves variance estimation validity. The analyst can still see (and count)
out-of-domain rows; variance estimators treat them as zero-weight.

**Edge case:** If `y` has duplicate keys, the same survey row could match multiple times
— but since we're only computing a logical mask, duplicates in `y` collapse to a single
`TRUE`. No row expansion possible.

---

### `anti_join(survey, data.frame, ...)` — Domain-aware (like `filter()`)

Mirror of `semi_join`: rows *without* a match in `y` stay in-domain; matching rows get
`domain = FALSE`.

Implementation is identical to `semi_join` with the mask inverted.

---

### `bind_cols(survey, data.frame, ...)` — Supported (survey × data.frame only)

Adds columns from a data frame to the survey's `@data`. Semantically equivalent to doing
a `left_join` on an implicit row-index key.

**Constraints:**

1. Row counts must match exactly (→ error: `surveytidy_error_bind_cols_row_mismatch`)
2. `y` must not be a survey object (→ error)
3. `y` must not have columns named the same as design variables (→ warn + drop, same as
   `left_join`)

---

### `bind_rows(survey, ...)` — Error always

Stacking two surveys row-wise fundamentally changes the design. The combined object would
require a new design specification (e.g., adding a survey-wave variable as a new
stratum). There is no valid default behavior.

Error class: `surveytidy_error_bind_rows_survey`

**Helpful message:** Explain the correct workflow — extract `@data` from each, bind the
raw data, re-specify the combined design with `as_survey()`.

---

## 4. Survey × Survey Joins — Uniformly Errors

All join functions error when both `x` and `y` are survey objects. The one narrow
exception (joining two surveys over the same sample to combine variable sets) requires
manual validation that surveytidy cannot perform automatically.

Error class: `surveytidy_error_join_survey_to_survey`

---

## 5. Twophase Edge Cases

Twophase designs have a two-tier structure: all rows live in `@data`, but only
`subset == TRUE` rows are in phase 2. Even a "safe" `left_join` or `semi_join` on a
twophase design needs careful handling:

- **left_join**: Safe — phase1/phase2 row structure is unchanged since no rows are
  added/removed
- **inner_join** (physical): Dangerous — physically removing rows from a twophase design
  can orphan phase2 rows or corrupt the phase1 sample. Elevate to error (not just
  warning) for twophase: `surveytidy_error_join_twophase_row_removal`
- **semi_join/anti_join**: Domain-aware mask is fine — same approach as for
  taylor/replicate

---

## 6. Metadata, visible_vars, and @groups Handling

| Property | left_join | inner_join | semi_join/anti_join | bind_cols |
|---|---|---|---|---|
| `@metadata` | New cols get no labels | Same as left_join | Unchanged (no new cols) | New cols get no labels |
| `visible_vars` | Append new col names if set | Same | Unchanged | Append new col names if set |
| `@groups` | Preserved from `x` | Preserved from `x` | Preserved from `x` | Preserved from `x` |

---

## 7. Open Questions

These need explicit decisions before implementation:

**Q1: Should `inner_join` be domain-aware or physical-subset?**

- Option A: Physical subset + `surveycore_warning_physical_subset` (current plan above)
- Option B: Domain-aware (implement as `semi_join` + `left_join` under the hood)

Option B is more survey-correct but confusing because the result has the same number of
rows as the original (out-of-domain rows are still there). Users who expect inner_join
semantics (fewer rows) would be surprised. Option A is more intuitive but compromises
variance estimation if used carelessly.

**Q2: Should `semi_join`/`anti_join` warn or be silent?**

Domain modification is a meaningful operation. Should it issue an informational message
like "Marking N rows as out-of-domain based on join condition" or stay silent (consistent
with `filter()`, which is also silent)?

**Q3: What happens with `left_join` and one-to-many keys?**

Currently the plan is to error on row expansion. An alternative is to allow it but warn
loudly. Row expansion means the same survey respondent appears multiple times, which
invalidates variance estimation — error seems right, but it blocks legitimate uses (e.g.,
building a long-format dataset for non-survey purposes using the survey data as a base).

**Q4: What happens to `@variables$domain` (the quosure audit trail) after
semi_join/anti_join?**

`filter()` appends quosures to `@variables$domain`. Semi/anti joins don't have a quosure
expression — they have a data-driven mask. Should we store something in
`@variables$domain` to represent this? Or leave it as-is (the actual
`..surveycore_domain..` column in `@data` is the authoritative state anyway)?

---

## 8. New Error/Warning Classes Needed

These would need to be added to `plans/error-messages.md` before implementation:

| Class | Trigger |
|---|---|
| `surveytidy_error_join_survey_to_survey` | `y` is a survey object in any join |
| `surveytidy_error_join_adds_rows` | `right_join` or `full_join` on a survey |
| `surveytidy_error_join_row_expansion` | `left_join` where y has duplicate keys → row count increases |
| `surveytidy_error_join_twophase_row_removal` | `inner_join` on a twophase design |
| `surveytidy_error_bind_rows_survey` | `bind_rows` with a survey on either side |
| `surveytidy_error_bind_cols_row_mismatch` | `bind_cols` where row counts differ |
| `surveytidy_warning_join_col_conflict` | y has column names matching design variables |

---

## 9. Implementation Notes

**S3 registration** (in `R/00-zzz.R`): Each join function needs a `registerS3method()`
call in `.onLoad()` — same pattern as `filter`, `select`, etc.

**`dplyr_reconstruct.survey_base`** (in `R/utils.R`) handles dplyr's internal join path
for complex pipelines. The explicit method implementations (`left_join.survey_base`,
etc.) are the primary entry point, but `dplyr_reconstruct` acts as a backstop.

**File layout:**

```
R/08-joins.R      # left_join, right_join, inner_join, full_join,
                  # semi_join, anti_join, bind_rows, bind_cols
```

`bind_rows` and `bind_cols` could alternatively live in `R/08-binds.R` if the file grows
large. Since they're conceptually distinct from key-based joins, a separate file may be
cleaner.

**Test file:** `tests/testthat/test-joins.R` — same cross-design loop pattern as all
other verbs.

---

## 10. Priority Order

If implemented, the natural build order:

1. `left_join` — highest value, cleanest semantics, most common use case
2. `semi_join` + `anti_join` — relatively simple (domain mask only)
3. `bind_cols` — simple, common utility
4. `inner_join` — needs decision on Q1 before implementing
5. `right_join` + `full_join` — error-only; trivial to implement
6. `bind_rows` — error-only; trivial to implement

---

## 11. Summary Table

| Function | Survey × Data.frame | Survey × Survey |
|---|---|---|
| `bind_rows` | Error | Error |
| `bind_cols` | Supported | Error |
| `left_join` | Supported | Error |
| `inner_join` | Physical subset + warn (see Q1) | Error |
| `right_join` | Error (would add rows) | Error |
| `full_join` | Error (would add rows) | Error |
| `semi_join` | Domain-aware (like filter) | Error |
| `anti_join` | Domain-aware (like filter) | Error |
