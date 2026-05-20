## Resubmission

This is a resubmission addressing reviewer feedback:

* Removed single quotes around `survey_collection` in the Description
  field (single quotes are reserved for package/software names).
* Replaced manual `.Random.seed` save/restore and `set.seed()` in
  `slice_sample.survey_collection` with `withr::with_seed()`, which
  eliminates both the `.GlobalEnv` write and the in-function seed setting.
  `withr` has been added to Imports accordingly.

## Test environments

* local macOS 15 (Sequoia), R 4.5.2
* GitHub Actions (ubuntu-latest, macos-latest, windows-latest)
* win-builder (R-devel)

## R CMD check results

0 errors | 0 warnings | 1 note

* checking CRAN incoming feasibility ... NOTE
  Maintainer: 'Jacob Dennen <jdenn0514@gmail.com>'
  New submission

This is the first CRAN submission of surveytidy.

## Reverse dependencies

None. This is a new package with no dependents.

## Comments

* First CRAN submission of surveytidy.
* This package depends on 'surveycore', which is available on CRAN.
* There are no published references describing the methods in this
  package. The domain estimation approach implemented in filter() follows
  standard survey statistics practice as described in Lumley (2010),
  "Complex Surveys: A Guide to Analysis Using R" (Wiley).
