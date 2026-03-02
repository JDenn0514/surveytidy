# Vignette Plan: Domain Estimation vs. Physical Row Removal

**Version:** 1.0
**Date:** 2026-02-24
**Status:** Approved outline — ready to implement
**Output file:** `vignettes/domain-estimation.qmd`

---

## Summary of Decisions

| Decision | Choice |
|----------|--------|
| File format | Quarto (`.qmd`) |
| Title | `"Domain Estimation: Why filter() Preserves Rows"` |
| Primary dataset | `surveycore::nhanes_2017` (stratified cluster, blood pressure) |
| Analysis scenario | Mean systolic blood pressure among adults 40+ |
| Audience | All levels — tidyverse newcomers, srvyr migrants, methodologists |
| Depth | Three tiers: practical → intuitive → numerical deep-dive |
| Comparisons | surveytidy-only; no srvyr/survey package comparison (separate vignette) |
| Physical removal section | Yes — clear "when it IS appropriate" section included |
| Doc position | Entry-level; referenced from README / Get Started |

**Open question before writing code chunks:** Phase 1 estimation functions
are not yet implemented. The numerical comparison section (Section 5) should
use `survey::svymean()` with an explicit note that Phase 1 surveytidy
functions will replace it. Add `survey` to `Suggests` in DESCRIPTION if not
already present.

---

## Learning Outcomes

After reading this vignette, the user can:

1. **Recognize the mistake** — know the warning signs that they're about to
   remove rows instead of marking a domain
2. **Write correct code** — produce domain-filtered estimates using
   `surveytidy::filter()`
3. **Explain the "why"** — tell a colleague why removing rows gives wrong SEs
4. **Know when physical removal IS appropriate** — identify the legitimate
   use cases for `subset()` vs. `filter()`

---

## Section-by-Section Outline

### YAML front matter

```yaml
---
title: "Domain Estimation: Why filter() Preserves Rows"
vignette: >
  %\VignetteIndexEntry{Domain Estimation: Why filter() Preserves Rows}
  %\VignetteEngine{quarto::html}
  %\VignetteEncoding{UTF-8}
---
```

---

### Setup chunk (hidden, `echo: false`)

Load packages and create the NHANES design object once; all sections reuse `d`.

```r
library(surveytidy)
library(surveycore)
library(dplyr)
```

---

### Section 1 — The Setup (~150 words)

**Goal:** Frame the problem with the running example. A domain is any
subgroup defined by the data, not by the sampling design.

**Content:**

- One-paragraph intro: almost every real analysis targets a subgroup —
  women, adults over 40, people below the poverty line
- Introduce the running example: estimating mean systolic blood pressure
  among adults 40 and older using NHANES
- Show `nhanes_2017` being turned into a survey design with `as_survey()`
- Pose the natural question: *"Should I just keep the rows I want?"*
- Show the intuitive (wrong) approach — filtering the data frame *before*
  calling `as_survey()`:

```r
# Looks harmless. The point estimates will be fine.
# The standard errors will not be.
nhanes_40plus <- nhanes_2017 |>
  dplyr::filter(ridageyr >= 40)

d_wrong <- surveycore::as_survey(
  nhanes_40plus,
  ids     = sdmvpsu,
  strata  = sdmvstra,
  weights = wtmec2yr,
  nest    = TRUE
)
```

---

### Section 2 — Why This Gives Wrong Standard Errors (~250 words)

**Goal:** Build intuition for the problem. No formulas in the main text;
math lives in the collapsible deep-dive in Section 5.

**Content:**

- Mental model in one sentence: *"Variance estimators need to see the full
  sampling structure — clusters, strata, PSUs — even for the rows you're
  not analyzing."*
- Concrete explanation: NHANES was designed across 30+ strata and 60+ PSUs.
  When you drop under-40s before building the design, some PSUs may disappear
  entirely from certain strata. The variance calculation now acts as if the
  survey was designed across fewer units than it really was — it thinks the
  design is more efficient than it is.
- The result: SEs are **underestimated** — confidence intervals are too
  narrow and p-values are misleadingly small
- Key insight: *"Point estimates are often very close to correct. The bias
  is in the uncertainty, not the estimate."*

**Callout box:**
> The domain is defined by who people *are*, not by who was *sampled*. The
> sampling design didn't know in advance how many 40+ adults would fall in
> each cluster. That randomness must be reflected in the variance.

**The Stata quote (always lands well):**
> "If the data set is subset … the standard errors of the estimates cannot
> be calculated correctly." — Stata Survey Data Reference Manual

---

### Section 3 — The Right Way: `filter()` as Domain Marker (~200 words)

**Goal:** Show the correct approach and explain what `filter()` actually does
internally.

**Content:**

- The correct pattern:

```r
d <- surveycore::as_survey(
  nhanes_2017,
  ids     = sdmvpsu,
  strata  = sdmvstra,
  weights = wtmec2yr,
  nest    = TRUE
)

adults_40plus <- d |> filter(ridageyr >= 40)
```

- Show that row count is unchanged:
  `nrow(adults_40plus@data)` equals `nrow(d@data)` — all 9,254 rows present
- Explain the domain column: `filter()` writes `..surveycore_domain..` — a
  logical column, `TRUE` for in-domain rows, `FALSE` for out-of-domain rows
- Key statement: out-of-domain rows contribute zero to the estimate, but their
  PSUs still appear in the variance calculation — that's the whole point
- Chaining: show that multiple conditions AND together:

```r
# These two are identical:
d |> filter(ridageyr >= 40, riagendr == 2)
d |> filter(ridageyr >= 40) |> filter(riagendr == 2)
```

---

### Section 4 — A Visual Summary (~100 words + table)

**Goal:** Give readers a quick scannable reference they can return to.

| | `filter()` | Pre-filter then `as_survey()` |
|---|---|---|
| Rows in object | All 9,254 | Only 40+ subset |
| Design structure visible to variance engine | Full | Incomplete |
| Standard errors | Correct | Typically too small |
| Point estimates | Correct | Usually similar |
| Reversible | Yes | No |
| surveytidy recommendation | ✓ Always | ✗ Avoid |

---

### Section 5 — Seeing It Numerically (collapsible) (~300 words)

**Goal:** Show the actual numerical difference for readers who want proof.
Kept collapsible so it doesn't overwhelm entry-level readers.

**Quarto collapsible block:**
```markdown
::: {.callout-note collapse="true"}
## The numbers: how different are the SEs?
...
:::
```

**Content:**

- Compute mean systolic BP among adults 40+ two ways:
  1. Domain estimation via `filter()` — correct SE
  2. Pre-filter then build design — SE too small

```r
# --- Correct: domain estimation ---
adults_40plus <- d |> filter(ridageyr >= 40)
# [surveytidy estimation function TBD — using survey::svymean() for now]
survey::svymean(~bpxsy1, subset(survey::svydesign(...), ridageyr >= 40))

# --- Wrong: pre-filter then build ---
d_wrong <- surveycore::as_survey(
  dplyr::filter(nhanes_2017, ridageyr >= 40),
  ids = sdmvpsu, strata = sdmvstra, weights = wtmec2yr, nest = TRUE
)
survey::svymean(~bpxsy1, d_wrong)
```

- Show the output side by side — point estimates are similar, SEs diverge
- Explain the mechanism: when PSUs disappear from a stratum, the `n/(n-1)`
  degrees-of-freedom correction uses the wrong `n`; some strata may become
  "lonely PSUs" — artifacts of the filtering, not the actual design

**Math (inside the collapsible, for methodologists):**

The domain mean is a ratio estimator:

$$\bar{y}_D = \frac{\sum_i w_i d_i y_i}{\sum_i w_i d_i}$$

where $d_i = 1$ if unit $i$ is in the domain, $0$ otherwise. Under Taylor
linearization, the influence function is $z_i = d_i(y_i - \bar{y}_D) /
\hat{N}_D$. Out-of-domain units have $z_i = 0$ — but "zero contribution" is
not the same as "absent." The variance formula sums $z_i$ over PSUs within
strata over the *full sample*. Dropping rows changes which PSUs are present
per stratum, corrupting the variance calculation.

---

### Section 6 — When Physical Row Removal IS Appropriate (~250 words)

**Goal:** Give readers the complete mental model. Prevents overcorrecting
to "all row removal is always wrong."

**Content:**

**Case 1: Defining the eligible population before building the design**

NHANES includes both interview-only and MEC exam respondents. Blood pressure
was only measured for MEC respondents (`ridstatr == 2`). Removing
interview-only respondents *before* building the design is correct — you're
defining who could have provided the outcome, not analyzing a subgroup of the
full population:

```r
# Appropriate: restricting to MEC exam participants BEFORE design creation
d_exam <- surveycore::as_survey(
  dplyr::filter(nhanes_2017, ridstatr == 2),
  ids     = sdmvpsu,
  strata  = sdmvstra,
  weights = wtmec2yr,
  nest    = TRUE
)
```

**Case 2: `subset()` with the warning**

surveytidy also exports `subset()` for cases where you explicitly want to
change the design object's row set. It always warns:

```r
d_subset <- subset(d, ridstatr == 2)
#> Warning: subset() physically removes rows from the survey design.
#> ℹ Variance estimates will be based on the subset only.
#> ℹ Use filter() for domain estimation with correct standard errors.
```

**The decision rule:**

> - **Defining eligibility** (removing people who couldn't have the outcome):
>   filter the data frame, then call `as_survey()`.
> - **Analyzing a subgroup** of an already-defined population:
>   use `filter()` on the design object.
> - **Deliberately changing the design** and you know what you're doing:
>   `subset()` will warn you and proceed.

---

### Section 7 — Quick Reference (~50 words)

**Goal:** One-glance decision guide. Readers can screenshot this.

```
Analyzing a subgroup of your survey population?
  → filter() on the design object

Removing ineligible respondents before building the design?
  → dplyr::filter() on the data frame, then as_survey()

Got a warning from subset()?
  → Switch to filter()
```

---

### Further Reading

Links (not a full bibliography — keep it short for a vignette):

- `?filter.survey_base` — reference page with argument details
- `?surveycore::as_survey` — design object documentation
- West, Berglund & Heeringa (2008), *The Stata Journal* — empirical
  demonstration that SE bias from physical subsetting is substantial
- Lumley (2021), *NotStatschat* — short authoritative explanation by the
  `survey` package author

---

## Acceptance Criteria

- [ ] `vignettes/domain-estimation.qmd` renders without errors via
  `devtools::build_vignettes()`
- [ ] All code chunks run successfully; no `eval: false` except deliberate
  "wrong way" demos (use `error: true` if needed)
- [ ] Numerical comparison in Section 5 shows actually different SEs —
  verify the numbers manually before committing
- [ ] `survey` added to `Suggests` in DESCRIPTION (needed for Section 5)
- [ ] `VignetteBuilder` in DESCRIPTION includes `quarto` (or `knitr`)
- [ ] `_pkgdown.yml` updated to list this vignette under `articles:`
- [ ] `pkgdown::build_site()` renders the vignette correctly

---

## Implementation Notes

### NHANES design
Use `wtmec2yr` (MEC exam weight) throughout — the outcome is blood pressure,
an examination measurement. Note in the text that `wtint2yr` is correct for
interview-only variables.

```r
d <- surveycore::as_survey(
  nhanes_2017,
  ids     = sdmvpsu,
  strata  = sdmvstra,
  weights = wtmec2yr,
  nest    = TRUE
)
```

### Domain column reference
Always use the exported constant, never the raw string:
```r
# Good
adults_40plus@data[[surveycore::SURVEYCORE_DOMAIN_COL]]

# Bad — fragile if the constant name ever changes
adults_40plus@data[["..surveycore_domain.."]]
```

### Phase 1 placeholder
Until Phase 1 estimation functions (`get_mean()`, etc.) are built, use
`survey::svymean()` for the numerical comparison. Add this comment inline:

```r
# surveytidy estimation functions (get_mean(), get_total(), etc.) are
# coming in Phase 1. Replaced with survey::svymean() here for now.
```

Update this section — and remove `survey` from `Suggests` if no longer
needed — once Phase 1 ships.

---

*Created: 2026-02-24*
*Update the numerical comparison section when Phase 1 estimation functions
are implemented — replace `survey::svymean()` with surveytidy equivalents.*
