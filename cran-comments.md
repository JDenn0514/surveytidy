## Test environments

* local macOS 14 (Sonoma), R 4.5.2
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
* This package depends on 'surveycore', which is being submitted to CRAN
  separately. The 'Remotes:' field in DESCRIPTION is present only to
  support pre-CRAN local installation; it will be removed before the
  final submission once 'surveycore' is on CRAN.
* There are no published references describing the methods in this
  package. The domain estimation approach implemented in filter() follows
  standard survey statistics practice as described in Lumley (2010),
  "Complex Surveys: A Guide to Analysis Using R" (Wiley).
