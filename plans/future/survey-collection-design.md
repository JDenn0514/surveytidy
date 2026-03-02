# survey_collection — Design Sketch

**Status:** Draft concept — not yet scheduled for implementation
**Depends on:** Phase 1 estimation functions (e.g., `get_freqs()`) existing first

---

## Problem

Analysts frequently need to run the same analysis across multiple independent
surveys (e.g., NHANES waves, international comparisons, parallel surveys) and
compare results. The naive approaches are all bad:

- `bind_rows(survey1, survey2)` — invalid; combines rows without re-specifying
  the design, breaks variance estimation
- Manual `lapply(list(d1, d2), get_freqs, x)` — works but is ergonomically poor
  and produces a list, not a tidy data frame

`survey_collection` is the correct alternative: a named container that holds
multiple independent survey objects without touching any of their designs.

---

## Concept

```r
waves <- survey_collection(
  "2017-18" = nhanes_2017_design,
  "2019-20" = nhanes_2019_design,
  "2021-22" = nhanes_2021_design
)
```

Each survey keeps its own `@data`, `@variables`, `@metadata`, and design
structure. The collection is a named list with an S7 class wrapper. The names
become the identifier column in combined output.

---

## How Estimation Functions Would Work

An estimation function like `get_freqs()` dispatches on `survey_collection`,
runs the analysis on each survey independently, then binds results with a
`.survey` identifier column:

```r
get_freqs(waves, health_status)

# .survey    health_status    n    prop    se
# 2017-18    Excellent       120  0.25    0.02
# 2017-18    Very Good       180  0.38    0.03
# 2019-20    Excellent       115  0.24    0.02
# 2019-20    Very Good       175  0.37    0.03
# ...
```

No pooling, no combined design. Each survey is analyzed independently. The
`.survey` column is how the caller compares across them.

The pattern inside estimation functions:

```r
get_freqs.survey_collection <- function(design, ...) {
  results <- lapply(names(design@surveys), function(nm) {
    result <- get_freqs(design@surveys[[nm]], ...)
    result$.survey <- nm
    result
  })
  dplyr::bind_rows(results)
}
```

---

## dplyr Verbs Propagating Through the Collection

If surveytidy implements `filter.survey_collection`, `select.survey_collection`,
etc., users can pre-process the whole collection before analysis:

```r
waves |>
  filter(ridageyr >= 18) |>        # domain filter applied to each survey
  select(health_status, income) |>  # columns selected in each survey
  get_freqs(health_status)          # analyzes each, returns combined result
```

Each verb applies to every survey in the collection and returns a new
`survey_collection`. The estimation function at the end collapses it into a
tidy data frame.

---

## Relationship to bind_rows

`survey_collection` is the explicit alternative to `bind_rows(survey1, survey2)`,
which surveytidy errors on. The error message for `bind_rows` should point here:

> Use `survey_collection()` to hold multiple surveys together for comparative
> analysis, or extract `@data` from each, bind manually, and re-specify the
> design with `as_survey()`.

---

## Where It Lives

| Component | Package | Rationale |
|---|---|---|
| `survey_collection` S7 class | surveycore | Core data structure; estimation functions dispatch on it |
| `as_survey_collection()` constructor | surveycore | Pairs with `as_survey()`, `as_survey_rep()` |
| `filter.survey_collection`, `select.survey_collection`, etc. | surveytidy | Same pattern as `filter.survey_base` |

---

## Open Design Questions

**Q1: Heterogeneous surveys (missing variables)**

What if the surveys don't all have the same variables? Should
`filter(collection, ridageyr >= 18)` error on surveys missing `ridageyr`, or
skip them silently?

- Option A: Error, naming which surveys are affected
- Option B: Skip with a warning (returns a smaller collection)
- Option C: Propagate the error from that survey only

Option A is safest. Option B is more useful for exploratory work across surveys
with known structural differences.

**Q2: Output identifier column name**

`.survey` is natural but conflicts if the survey data already has a `.survey`
column. Options:

- Default to `.survey`; error if it conflicts with an existing column name
- Make it configurable: `get_freqs(waves, health_status, .id = "wave")`
- Always configurable with no default (forces the caller to be explicit)

**Q3: Mixed design types**

Should `survey_collection` allow mixing taylor, replicate, and twophase designs?
Probably yes — the designs are never combined, so type heterogeneity is fine.
The only constraint is that each element must be a `survey_base` subclass.

**Q4: Printing**

`print(waves)` should summarize the collection, not dump all the data:

```
A survey_collection with 3 surveys:
  "2017-18": survey_taylor, 9,254 rows, 48 variables
  "2019-20": survey_taylor, 8,704 rows, 48 variables
  "2021-22": survey_taylor, 7,208 rows, 50 variables
```

**Q5: Subsetting**

Should `waves[["2017-18"]]` return the individual survey object? That would make
`survey_collection` behave like a named list, which is intuitive.

**Q6: Modifying the collection**

Should there be a way to add/remove surveys from an existing collection?
Something like `add_survey(waves, "2023-24" = nhanes_2023_design)` or just
rebuild the whole collection from scratch each time.

---

## Sketch of Class Definition (surveycore)

```r
survey_collection <- S7::new_class(
  "survey_collection",
  properties = list(
    surveys = S7::class_list
  ),
  validator = function(self) {
    if (length(self@surveys) == 0) {
      return("Collection must contain at least one survey.")
    }
    if (is.null(names(self@surveys)) || any(names(self@surveys) == "")) {
      return("All surveys in the collection must be named.")
    }
    not_surveys <- !vapply(
      self@surveys,
      function(x) S7::S7_inherits(x, survey_base),
      logical(1)
    )
    if (any(not_surveys)) {
      bad <- names(self@surveys)[not_surveys]
      return(paste0(
        "All elements must be survey_base objects. Bad elements: ",
        paste(bad, collapse = ", ")
      ))
    }
  }
)

as_survey_collection <- function(...) {
  surveys <- list(...)
  survey_collection(surveys = surveys)
}
```

---

## Summary

`survey_collection` is a lightweight named container for multiple independent
survey objects. It enables comparative analysis across surveys without combining
their designs. The key invariant: **the collection never modifies the surveys it
holds**. All analysis runs each survey independently and combines the tidy output.
