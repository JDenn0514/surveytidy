## Resubmission

This is a resubmission of surveytidy, as version 0.6.2. CRAN archived
surveytidy 0.6.0 on 2026-09-27 because it requires surveycore, which was
archived on the same day. surveycore 1.2.0 is now back on CRAN.

surveycore 1.2.0 refuses a survey design with fewer than 2 rows. Six
surveytidy 0.6.0 tests built or produced a 1-row design and failed against
it. Changes in this version:

* Imports now requires `surveycore (>= 1.2.0)`.
* Verbs that reduce a design to 1 row (`distinct()`, the `slice_*()`
  family, `subset()`, and `inner_join()` with `.domain_aware = FALSE`) now
  pass surveycore's `surveycore_error_single_row` to the user. Each case has
  a test.
* Test data that had collapsed to 1 row by accident now has at least 2 rows.

The version also has three bug fixes for users. They are listed in NEWS.md
under 0.6.1 and 0.6.2.

## Test environments

* Local: Windows 11 x64, R 4.6.1 (2026-06-24 ucrt).
* GitHub Actions: ubuntu-latest (R-devel, R-release, R-oldrel-1),
  macos-latest (R-release), windows-latest (R-release).
* win-builder, Windows Server 2022 x64:
  * R-devel (2026-11-02 r90827 ucrt): `Status: 1 NOTE`; tests took 133 s.
  * R-release (R 4.6.2, 2026-10-29 ucrt): `Status: 1 NOTE`; tests took
    134 s.

  The one NOTE on both is the incoming feasibility NOTE below.

## R CMD check results

`R CMD check --as-cran --no-manual` on the built tarball:

0 errors | 0 warnings | 1 note

* checking CRAN incoming feasibility ... NOTE
  Package was archived on CRAN (see Resubmission above).

Tests: `[ FAIL 0 | WARN 0 | SKIP 95 | PASS 20019 ]`, 183 s.

## Reverse dependencies

surveycore has surveytidy in Suggests. It is the only reverse dependency
(`tools::package_dependencies("surveytidy", reverse = TRUE, which = "all")`
against the current CRAN index). `R CMD check --no-manual` of the CRAN
surveycore 1.2.0 tarball with surveytidy 0.6.2 installed: `Status: OK`,
tests `[ FAIL 0 | WARN 248 | SKIP 589 | PASS 12439 ]`.

## Method references

There are no published references describing the methods in this
package. The domain estimation approach implemented in filter() follows
standard survey statistics practice as described in Lumley (2010),
"Complex Surveys: A Guide to Analysis Using R" (Wiley).
