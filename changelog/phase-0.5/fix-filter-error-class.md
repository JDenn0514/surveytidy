# Fix filter() error class prefix; add domain estimation vignette plan

| Field | Value |
|-------|-------|
| **Package** | surveytidy |
| **Phase** | 0.5 |
| **Branch** | main (direct commit) |
| **PR** | — |
| **Date** | 2026-02-22 |

## Executive Summary

Two small fixes committed directly to main. First, a one-line bug fix: the
error thrown when a user passes `.by` to `filter()` was using the wrong package
prefix in its error class (`surveycore_error_*` instead of `surveytidy_error_*`).
This would have caused tests using `expect_error(class = "surveytidy_error_*")`
to fail silently in future. Second, a planning document for a future vignette
or blog post on domain estimation — collecting the statistical theory, code
examples, and all relevant journal and blog references in one place so the
content can be written when the time comes.

---

## Commits

### `fix(filter): correct error class prefix for .by error`

**Purpose:** The `.by` argument error in `filter.survey_base()` was classified
as a `surveycore_error_*` when it should be a `surveytidy_error_*`. Every
error thrown by surveytidy code must use the `surveytidy_` prefix so that
tests can target the right package's error class table. This was caught during
a code review of subpopulation handling.

**Key changes:**
- `R/01-filter.R` line 90: `"surveycore_error_filter_by_unsupported"` →
  `"surveytidy_error_filter_by_unsupported"`

---

### `docs(plans): add domain estimation vignette outline`

**Purpose:** The review of `filter.survey_base()` produced a detailed body of
research on subpopulation domain estimation — statistical theory, comparison
of approaches across packages, and a curated reference list. Rather than lose
that work, it is captured as a structured planning document so the vignette or
blog post can be written later without repeating the research.

**Key changes:**
- `plans/domain-estimation-vignette.md` (new): outline covering narrative arc,
  section-by-section structure, NHANES/ACS code examples, and a full reference
  list spanning foundational statistics texts (Korn & Graubard 1999, Wolter
  2007, Lohr 2021), applied methods papers (West et al. 2008), Lumley's blog
  post and book, Stata/SAS/AHRQ software documentation, and academic papers
  on Taylor linearization variance (Binder 1983, Demnati & Rao 2004).
