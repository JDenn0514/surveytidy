# Domain Estimation in surveytidy: Vignette / Blog Post Plan

**Status:** Draft outline — not yet written
**Intended audience:** Applied researchers who know R and have used dplyr, but may
not be familiar with the variance-estimation consequences of subsetting survey data.
**Potential homes:** surveytidy pkgdown vignette, Tidyverse blog post, or both.

---

## Working Title

**"Why `filter()` Doesn't Remove Rows: Domain Estimation in surveytidy"**

Alternative titles:
- "Subpopulations, Domains, and Why Your Survey Standard Errors Are Wrong"
- "The Right Way to Analyze Survey Subgroups"

---

## Narrative Arc

Most readers will arrive having done something like this:

```r
# Looks harmless. Is not.
nhanes_women <- nhanes_2017 |> filter(riagendr == 2)
d <- as_survey(nhanes_women, ids = sdmvpsu, weights = wtmec2yr,
               strata = sdmvstra, nest = TRUE)
get_means(d, bpxsy1)
```

The point estimates are correct. The standard errors are not — typically
too small, sometimes dramatically so. The post should explain why, what the
correct approach is, and show that surveytidy's `filter()` handles this
transparently.

---

## Sections

### 1. The Setup: What Is a Domain?

A domain (also called a subpopulation or analytic subgroup) is any subset of
the population defined by a characteristic: women, people over 65, residents
of a specific state, respondents who answer "yes" to a screening question.

Domain estimation is ubiquitous: virtually every survey analysis targets some
subgroup. Getting the standard errors right matters for inference.

Key point: the domain is *defined by the data*, not by the sampling design. The
sampling design was not stratified by "women only" — it was stratified by
geography. This distinction drives everything.

### 2. Why Physical Subsetting Gives Wrong Standard Errors

#### The core issue: subpopulation sample size is a random variable

When the survey was designed, the sample was drawn from the full population. In
any given stratum or PSU, the number of women is *not fixed* — it varies from
one hypothetical sample draw to the next. The variance formula must account for
this randomness.

Formally, a domain mean is a **ratio estimator**:

$$\bar{y}_D = \frac{\sum_i w_i d_i y_i}{\sum_i w_i d_i}$$

where $d_i = 1$ if unit $i$ is in the domain, $0$ otherwise.

The $d_i$ are *observed data*, not design constants. When you apply Taylor
linearization to this ratio, the linearized influence function is:

$$z_i = \frac{d_i (y_i - \bar{y}_D)}{\hat{N}_D}$$

where $\hat{N}_D = \sum_i w_i d_i$ is the estimated domain population size.

**$z_i = 0$ for out-of-domain units** — but "zero contribution" ≠ "absent." The
variance formula sums $z_i$ over PSUs within strata over the *full sample*. PSUs
that had no domain members contribute zero to the numerator but still count
toward the PSU total in each stratum's variance calculation.

#### What goes wrong when you physically drop rows

Consider a stratified cluster sample of 15 school districts. Your domain is
"high schools only." Seven districts contain zero high schools.

If you drop those rows before calling `as_survey()`:

1. The design now appears to be a cluster sample of 8 districts.
2. The `n/(n−1)` degrees-of-freedom factor uses 8 instead of 15.
3. The seven zero-contribution districts never enter the variance calculation.
4. Some strata may collapse to a single PSU — the "lonely PSU" problem,
   artificially created by filtering rather than by the actual design.
5. The result is typically **underestimated standard errors** — the confidence
   intervals are too narrow and the design appears more efficient than it is.

#### The Stata documentation puts it plainly

> "If the data set is subset (meaning that observations not to be included in
> the subpopulation are deleted from the data set), the standard errors of the
> estimates cannot be calculated correctly."
> — Stata Survey Data Reference Manual

#### When physical subsetting IS safe

Two narrow exceptions:

1. The domain spans **entire strata**: strata are independent samples; removing
   whole strata loses no design information.
2. **Every cluster contains at least one domain member**: no PSUs vanish, so the
   PSU count per stratum is unchanged.

In real analyses (analyze only women, only one racial group, one age band), these
conditions almost never hold. The general rule: always use domain estimation.

### 3. The Correct Approach: Indicator Variables

The correct method replaces $y_i$ with $y_i \cdot d_i$ in the estimand:

```r
# These are numerically identical — both correct:
svytotal(~enroll, subset(dclus1, stype == "H"))
svytotal(~I(enroll * (stype == "H")), dclus1)
```

The second form makes the mechanism explicit: out-of-domain units contribute
$y \cdot d = 0$, and the full PSU structure remains intact in the variance
computation.

### 4. How surveytidy Handles This: `filter()` as Domain Marker

surveytidy's `filter()` implements the indicator variable approach directly:

```r
library(surveytidy)
library(surveycore)

d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtmec2yr,
               strata = sdmvstra, nest = TRUE)

# filter() marks the domain — does NOT remove rows
d_women <- d |> filter(riagendr == 2)
nrow(d_women@data)  # same as nrow(d@data) — all rows still present

# The domain is stored as a logical column in @data
head(d_women@data[[surveycore::SURVEYCORE_DOMAIN_COL]])
```

Internally, `filter()` writes a logical column `..surveycore_domain..` to
`@data`. This column is `TRUE` for domain rows, `FALSE` for out-of-domain rows.
The full data — including out-of-domain rows — is preserved and passed to the
variance engine. Out-of-domain rows contribute zero to the estimand; their PSUs
still appear in the variance calculation.

Chaining works as expected:

```r
# These are identical:
d |> filter(riagendr == 2, ridageyr >= 18)
d |> filter(riagendr == 2) |> filter(ridageyr >= 18)
```

### 5. Physical Subsetting: `subset()` with a Warning

surveytidy also provides `subset()` for the rare cases where you explicitly want
to change the design — for example, when restricting to respondents who completed
a specific module (e.g., NHANES MEC exam vs. interview-only):

```r
# NHANES: wtmec2yr is 0 for interview-only respondents (ridstatr == 1)
# This is a genuine design restriction, not a domain analysis
d_mec <- subset(d, ridstatr == 2)
```

`subset()` always emits a warning:

```
! subset() physically removes rows from the survey design.
ℹ Variance estimates will be based on the subset only.
ℹ Use filter() for domain estimation with correct standard errors.
```

### 6. Replicate Weight Designs

The same logic applies to replicate weight designs (BRR, jackknife, bootstrap,
successive-difference). The indicator variable approach means computing domain
statistics per replicate:

$$\bar{y}_{D,r} = \frac{\sum_i w_{r,i} d_i y_i}{\sum_i w_{r,i} d_i}$$

All rows remain in each replicate computation; the domain indicator zeros out
the non-domain contributions. surveytidy's `filter()` handles this consistently
across design types.

### 7. Two-Phase Designs

For two-phase designs, the domain indicator interacts with the phase 2 selection.
`filter()` marks domain membership in the full phase 1 dataset; analysis functions
apply both the phase 2 inclusion probability and the domain indicator when computing
estimates.

### 8. Frequencies and Proportions

Domain proportions are a special case of a ratio of domain totals:

$$\hat{p} = \frac{\hat{N}_{D \cap A}}{\hat{N}_D}$$

Both numerator and denominator are domain totals estimated from the full sample
with the indicator variable approach. The delta method gives the correct SE.

### 9. Regression in Domains

Domain regression is handled the same way: the outcome and predictors are
multiplied by the domain indicator before estimation, and the full sample
variance structure is used for the coefficient SEs.

---

## Code Examples to Develop

All examples should use `nhanes_2017` (stratified cluster) and `acs_pums_wy`
(replicate weights) from the surveycore package.

```r
# 1. The wrong way (to show the problem)
nhanes_women <- nhanes_2017 |> dplyr::filter(riagendr == 2)
d_wrong <- as_survey(nhanes_women, ids = sdmvpsu, weights = wtmec2yr,
                     strata = sdmvstra, nest = TRUE)

# 2. The right way
d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtmec2yr,
               strata = sdmvstra, nest = TRUE)
d_women <- d |> filter(riagendr == 2)

# 3. Compare SEs
# get_means(d_wrong, bpxsy1)   # SE too small
# get_means(d_women, bpxsy1)   # SE correct

# 4. Chained conditions
d_older_women <- d |> filter(riagendr == 2, ridageyr >= 45)

# 5. Replicate design domain
d_rep <- as_survey_rep(acs_pums_wy, weights = pwgtp,
                       repweights = pwgtp1:pwgtp80,
                       type = "successive-difference")
d_veterans <- d_rep |> filter(mil == 1)
```

---

## References

### Foundational Statistics

- **Korn, E. L., & Graubard, B. I. (1999).** *Analysis of Health Surveys.*
  Wiley. Chapter 2: "Basic Survey Statistics." The standard graduate-level
  reference on domain estimation in health surveys. Derives the ratio estimator
  and its Taylor linearization for domains.

- **Wolter, K. M. (2007).** *Introduction to Variance Estimation* (2nd ed.).
  Springer. Chapter 2: "The Taylor Series Method." Proves that the domain mean
  must be treated as a ratio and gives the exact variance formula.

- **Lohr, S. L. (2021).** *Sampling: Design and Analysis* (3rd ed.). Chapman
  and Hall/CRC. Chapter 11: "Estimating the Size of a Population." Clearest
  textbook treatment of subpopulation estimation; includes worked examples
  showing the effect of physical subsetting.

- **Cochran, W. G. (1977).** *Sampling Techniques* (3rd ed.). Wiley. Chapter 6:
  "Stratified Random Sampling." The original derivation of why stratum structure
  must be preserved.

- **Kalton, G., & Anderson, D. W. (1986).** "Sampling rare populations."
  *Journal of the Royal Statistical Society: Series A*, 149(1), 65–82.
  Establishes the theoretical framework for subpopulation estimation and
  identifies when the subpopulation sample size being a random variable matters
  for variance.

### Applied Methods Papers

- **West, B. T., Berglund, P., & Heeringa, S. G. (2008).** "A closer
  examination of subpopulation analysis of complex-sample survey data."
  *The Stata Journal*, 8(4), 520–531.
  https://journals.sagepub.com/doi/10.1177/1536867X0800800404
  Empirical comparison of physical subsetting vs. domain estimation using
  real health survey data. Shows the SE bias from physical subsetting is
  substantial (not just theoretical) and varies by domain size.

- **Heeringa, S. G., West, B. T., & Berglund, P. A. (2010).** *Applied Survey
  Data Analysis.* Chapman and Hall/CRC. Chapter 4: "Subpopulation Analysis."
  The most accessible applied treatment; gives code in multiple software
  packages.

### R Package Documentation and Software

- **Lumley, T. (2021).** "Subsets and Subpopulations in Survey Inference."
  *NotStatschat* blog, July 22, 2021.
  https://notstatschat.rbind.io/2021/07/22/subsets-and-subpopulations-in-survey-inference/
  The authoritative short explanation by the `survey` package author. Shows
  code demonstrating the correct and incorrect approaches, and explains why
  `survey::subset()` gives correct SEs while redesigning from filtered data
  does not.

- **Lumley, T. (2010).** *Complex Surveys: A Guide to Analysis Using R.* Wiley.
  Chapter 3: "Domain Estimation." The R-specific reference for `survey` package
  domain estimation.

- **Lumley, T. (2004–2024).** *survey: Analysis of Complex Survey Samples.*
  R package version 4.4.x.
  https://cran.r-project.org/package=survey
  Implements `subset.survey.design()` and `svyby()` for domain estimation.

- **Freedman Ellis, G., & Schneider, B. (2021).** *srvyr: 'dplyr'-Like Syntax
  for Summary Statistics of Survey Data.* R package.
  https://cran.r-project.org/package=srvyr
  srvyr's `filter()` behavior: uses physical row removal for non-calibrated
  Taylor designs (adapted from `[.survey.design2`); uses zero-weight approach
  for calibrated/PPS designs. See `R/subset_svy_vars.R` in the srvyr source
  for implementation details.

### Software Manuals

- **Stata Corp. (2023).** *Stata Survey Data Reference Manual.* StataCorp.
  https://www.stata.com/manuals/svy.pdf
  Stata's `svy: ... , subpop()` option implements domain estimation correctly.
  The manual has a clear statement about why physical subsetting fails
  (quoted above).

- **SAS Institute. (2009).** "Repeated Replication Methods and Subpopulation
  Analysis." WUSS 2009 Proceedings.
  https://support.sas.com/resources/papers/proceedings09/246-2009.pdf
  SAS `PROC SURVEYMEANS` with `DOMAIN` statement vs. `WHERE` clause.

- **AHRQ (Medical Expenditure Panel Survey).** "Accuracy of Estimates in
  Subpopulations." MEPS Methodology Report 26.
  https://meps.ahrq.gov/data_files/publications/mr26/mr26.pdf
  Government statistical agency guidance on domain estimation for health
  survey data. Directly states: "if the full file is not used, the variance
  is generally underestimated."

### Academic Papers on Specific Methods

- **Demnati, A., & Rao, J. N. K. (2004).** "Linearization variance estimators
  for survey data." *Survey Methodology*, 30(1), 17–26.
  Proves the linearization approach is correct for domain estimators. The
  survey package's Taylor variance is based on this approach.

- **Binder, D. A. (1983).** "On the variances of asymptotically normal
  estimators from complex surveys." *International Statistical Review*, 51(3),
  279–292. The foundational paper for Taylor linearization variance in complex
  surveys; establishes that domain means are handled correctly by the
  linearization approach.

---

## Technical Notes for the Implementation Section

### Why surveytidy's `filter()` is more explicit than `survey::subset()`

Both `survey::subset()` and surveytidy's `filter()` give correct SEs. The
difference is in transparency:

- `survey::subset()` physically removes rows but preserves the `sampsize`
  matrix so the variance engine can add zeros back. The mechanism is hidden
  inside the variance computation.
- surveytidy's `filter()` keeps all rows and marks domain membership with an
  explicit column. The mechanism is visible at the API level. The analysis
  functions explicitly compute $y_i \cdot d_i$ rather than relying on the
  variance engine to recover zero contributions.

Both are correct; surveytidy's approach is more auditable and works consistently
across all design types without branching on calibration status.

### srvyr `filter()` behavior (for comparison / warning)

srvyr's `filter()` behavior differs by design type in a way that is not
documented in the user-facing API:

| Design type | srvyr behavior | Correct? |
|---|---|---|
| Taylor, non-calibrated (most common) | Physical row removal | Depends on variance engine recovering zeros |
| Taylor, calibrated/PPS | `prob = Inf` (zero-weight) | Always correct |
| Replicate weights | Physical row removal | Depends on replicate engine |
| Twophase | `prob = Inf` (zero-weight) | Always correct |

Source: `srvyr/R/subset_svy_vars.R` comments: "Adapted from
`survey:::[.survey.design2`".

### The `..surveycore_domain..` column

The domain column name is exported as `SURVEYCORE_DOMAIN_COL` from surveycore.
It uses the double-dot sentinel convention (`..name..`) to avoid colliding with
user data columns. The analysis functions check for this column and implement
the ratio estimator; when the column is absent, they compute over the full
sample.

---

## Potential Structure as a Vignette

```
vignette("domain-estimation", package = "surveytidy")
```

Sections:
1. Introduction: what is a domain?
2. The problem with physical subsetting (with a working example showing wrong SEs)
3. The domain indicator approach (math + code)
4. Using `filter()` in surveytidy
5. Chaining conditions
6. Physical subsetting with `subset()` (and when it's appropriate)
7. Works cited / further reading

## Potential Structure as a Blog Post

Target: ~1,500 words for a Tidyverse-style blog post. Focus on the user-facing
story with one empirical example (NHANES systolic blood pressure by sex/age).
Link to vignette for full math treatment.

---

*Created: 2026-02-22*
*To be updated when Phase 1 analysis functions are implemented*
