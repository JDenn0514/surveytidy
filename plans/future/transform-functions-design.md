# Plan: Survey Variable Transformation Functions

## Context

Phase 0.5 (dplyr/tidyr verbs) is complete. `recode-functions-design.md` covers
wrapping dplyr's recoding utilities (case_when_survey, recode_values_survey, etc.)
with @metadata integration.

This plan adds a **complementary layer**: high-level convenience functions for
the most common survey variable transformations — type conversion and scale
manipulation. These are "simple fixes for common problems" that a researcher
reaches for immediately:

- "I need to convert this labelled numeric to a factor for tabulation"
- "I need to collapse a 4-point Likert into agree/disagree"
- "I need a binary indicator from this dichotomous variable"
- "I need to reverse this scale because it was negatively worded"

These functions can call into the recode_*_survey functions under the hood
(when those are implemented), but they are user-facing shortcuts — not the
building blocks themselves.

**Inspired by:** `adlgraphs` package (make_binary, make_factor, make_dicho,
num_rev, flip_val) but redesigned for the surveytidy/surveycore architecture.

---

## Functions in Scope

### 1. `make_factor(x, ordered = FALSE, drop_levels = TRUE, na.rm = FALSE)`

**What it does:** Converts a labelled vector or plain numeric into an R factor
using value labels for level names.

**Inputs**: haven_labelled, plain numeric (labels from @metadata pre-attached),
R factor (pass-through), plain character.

**Output**: R factor (or ordered factor if `ordered = TRUE`).

**@metadata**: Sets `value_labels` if labels were used to define levels; records
a transformation note.

**Key behavior:**
- Errors if any observed value lacks a label (user must provide complete label coverage)
- `drop_levels = TRUE`: removes factor levels for unobserved values (default)
- `na.rm = FALSE`: values in `attr(x, "na_values")` / `attr(x, "na_range")`
  included as factor levels by default; set TRUE to convert them to NA instead

---

### 2. `make_dicho(x, flip_levels = FALSE, .exclude = NULL)`

**What it does:** Collapses a multi-level factor or labelled variable into a
2-level (dichotomous) factor. Designed for Likert-style scales.

**Inputs**: Same as make_factor.

**Output**: 2-level factor.

**Auto-collapse logic** (default): Strips single-word qualifier prefixes from
level labels ("Strongly Agree" → "Agree", "Somewhat Disagree" → "Disagree").
Comparison is case-insensitive; output levels are title-cased stripped stems.
Qualifiers stripped: Strongly, Somewhat, Very, Moderately, Extremely, Quite,
Mostly, Generally, Fairly, and multi-word prefixes "A little", "A great deal",
"A bit".

**Open design question:** Should the auto-collapse approach be the only option,
or should there be an explicit-groups argument (e.g., `group1 = c("Strongly
Agree", "Agree")`)? Start with auto-strip only; add explicit grouping in a later
version if users ask.

**`.exclude` argument:** Character vector of level names to treat as `NA`.
Intended for middle categories ("Neither agree nor disagree") and "Not sure" /
"Don't know" / "Refused" responses. Excluded rows become NA in the output vector
(not marked out-of-domain — see open questions).

**`flip_levels`**: Reverses the order of the resulting two levels (useful for
ensuring the "positive" level is first).

**@metadata**: Records the collapse mapping (original levels → new groups) as
a transformation note.

---

### 3. `make_binary(x, flip_values = FALSE, .exclude = NULL)`

**What it does:** Converts a dichotomous variable to a numeric 0/1 indicator.

**Inputs**: Same as make_factor. Expects (or produces) exactly 2 levels after
any exclusions.

**Output**: Numeric vector (0 or 1). Not a factor — intended for use in
regression or arithmetic.

**Implementation**: Calls `make_dicho()` internally to normalize to 2 levels,
then maps first level → 1, second level → 0 (or reversed if `flip_values = TRUE`).

**Errors** if more than 2 levels remain after `.exclude` is applied (user must
resolve ambiguity — this error is raised inside `make_dicho()`).

**@metadata**: Variable label and a note describing the binary mapping.

---

### 4. `make_rev(x)`

**What it does:** Reverses the numeric values of a scale variable. For a
1–4 scale: 1 → 4, 2 → 3, 3 → 2, 4 → 1. Formula: `new_val = min(x) + max(x) - x`.

**Inputs**: Numeric vector (with or without value labels), haven_labelled.
Accepts any vector where `typeof(x) %in% c("double", "integer")`.

**Output**: Numeric vector with reversed values. If a `labels` attribute is
present, value labels are remapped so each label stays semantically tied to the
same concept (the label that was at 1 moves to 4, etc.). Output labels are sorted
by new value for correct display with `make_factor()`.

**Use case**: Negatively-worded items where the numeric direction is inverted
relative to the rest of the scale.

**@metadata**: Records the reversal transformation.

**Naming decision:** `make_rev` (consistent `make_*` prefix over `num_rev`).

---

### 5. `flip_val` — DEFERRED

Include if `make_rev` alone is insufficient for the negatively-worded-item use
case. Defer until `make_rev` is used in practice and the gap is confirmed.

---

## Architecture & Integration

### Dual-mode design
Each function works in two contexts:

1. **Standalone (plain vectors)**: Works on any R vector, no survey object
   required. Labels come from `attr(x, "labels")` / `attr(x, "label")` (haven
   attribute convention).

2. **Survey-integrated (inside mutate())**: When called inside
   `mutate.survey_base()`, the pre-attachment step (from recode-functions plan)
   makes @metadata labels available as haven attrs on the column. The function
   reads them, transforms, and returns the result. The post-detection step then
   extracts the output back into @metadata.

### haven dependency
These functions do NOT need to import `haven`. They read and set standard
attributes (`attr(x, "labels")`, `attr(x, "label")`, `attr(x, "na_values")`,
`attr(x, "na_range")`) directly. No `:::` or haven function calls needed.
Use `typeof(x) %in% c("double", "integer")` instead of `is.numeric()` for type
checks to work correctly with haven_labelled vectors (which vctrs makes
`is.numeric()` return FALSE for).

### Relationship to recode-functions-design.md
These functions sit *above* the recode_*_survey functions in the abstraction
hierarchy. They can proceed **independently** of recode-functions-design.md —
no dependency on dplyr development versions or the recode layer.

---

## Open Design Questions

1. **`make_dicho` collapse logic**: Auto-strip qualifiers only for now; add
   explicit `group1 =` / `group2 =` argument in a later version if users ask.

2. **`.exclude` behavior**: When a level is excluded:
   - (a) Set to `NA` in the output vector ← **recommended for now**
   - (b) Also mark out-of-domain in the survey's domain column ← more powerful
     but requires knowing we're inside a survey mutate
   Start with option (a); option (b) can be added later with the recode layer.

3. **`flip_val` inclusion**: Defer. See §5 above.

4. **Factor output metadata**: Should `make_dicho`/`make_binary` also accept a
   `.label` / `.value_labels` passthrough for richer @metadata? Defer until
   recode-functions layer exists.

5. **Warn on unknown `.exclude` levels**: `make_dicho(.exclude = c("Neutral"))`
   when "Neutral" is not a level — warn or silently ignore? Recommendation: warn
   with `surveytidy_warning_make_dicho_unknown_exclude`.

---

## Files This Plan Would Touch

| File | Change |
|------|--------|
| `R/transform.R` | New file — all 4 functions + internal helpers |
| `R/utils.R` | Any shared helpers (label extraction, qualifier stripping) if 2+ files use them |
| `DESCRIPTION` | No new packages required (haven attrs read directly) |
| `tests/testthat/test-transform.R` | New test file |
| `plans/error-messages.md` | Add new error/warning classes (see below) |

---

## New Error and Warning Classes

Add to `plans/error-messages.md` before implementing:

### Errors

| Class | Source file | Trigger |
|-------|-------------|---------|
| `surveytidy_error_make_factor_unsupported_type` | `R/transform.R` | `x` is not numeric, labelled, factor, or character |
| `surveytidy_error_make_factor_no_labels` | `R/transform.R` | `x` is numeric but has no `labels` attribute |
| `surveytidy_error_make_factor_incomplete_labels` | `R/transform.R` | One or more observed values in `x` have no label |
| `surveytidy_error_make_dicho_too_few_levels` | `R/transform.R` | Fewer than 2 levels remain after `.exclude` is applied |
| `surveytidy_error_make_dicho_collapse_ambiguous` | `R/transform.R` | Auto-stripping qualifiers does not yield exactly 2 unique stems |
| `surveytidy_error_make_rev_not_numeric` | `R/transform.R` | `x` is not a double or integer vector |

### Warnings

| Class | Source file | Trigger |
|-------|-------------|---------|
| `surveytidy_warning_make_dicho_unknown_exclude` | `R/transform.R` | One or more levels in `.exclude` not found in `x` |

---

## Test File Sections (`test-transform.R`)

```
# 1. make_factor() — happy paths (haven_labelled, plain numeric with labels,
#                   factor passthrough, character conversion)
# 2. make_factor() — drop_levels = FALSE
# 3. make_factor() — ordered = TRUE
# 4. make_factor() — na.rm = TRUE (na_values / na_range handling)
# 5. make_factor() — error: unsupported type
# 6. make_factor() — error: no labels
# 7. make_factor() — error: incomplete labels
# 8. make_dicho()  — already-2-level factor (pass-through)
# 9. make_dicho()  — auto-collapse 4-level Likert
# 10. make_dicho() — .exclude removes neutral middle level
# 11. make_dicho() — flip_levels reverses output order
# 12. make_dicho() — warning: unknown .exclude level
# 13. make_dicho() — error: too few levels after .exclude
# 14. make_dicho() — error: collapse ambiguous (e.g. 4 distinct stems)
# 15. make_binary() — basic 0/1 mapping
# 16. make_binary() — flip_values reverses mapping
# 17. make_binary() — .exclude passed through to make_dicho
# 18. make_binary() — NA propagates correctly
# 19. make_rev()   — reverses 1–4 scale
# 20. make_rev()   — remaps value labels correctly
# 21. make_rev()   — preserves variable label attribute
# 22. make_rev()   — all-NA input returns all-NA
# 23. make_rev()   — error: non-numeric input
# 24. Integration  — make_factor() |> make_dicho() pipeline
# 25. Integration  — works inside dplyr::mutate() on survey object
```

---

## Comparison With Other Future Plans

| Plan | Complexity | Dependencies | Standalone? |
|------|------------|--------------|-------------|
| `recode-functions-design.md` | High — 6 functions + mutate changes | dplyr recode_values/replace_when (dev) | No (needs mutate changes first) |
| `survey-collection-design.md` | Unknown | surveycore collection API | Unknown |
| `joins-design.md` | Medium | dplyr join infrastructure | Mostly yes |
| **This plan (transform)** | Medium — 4 focused functions | none (haven attrs read directly) | Yes |

**Easiest to implement next**: This plan has the narrowest scope, the most
self-contained logic, and no dependency on dplyr development versions or other
plans. `joins-design.md` would be second easiest.
