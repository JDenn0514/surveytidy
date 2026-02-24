# R/zzz.R
#
# Package startup hook.
#
# S3 dispatch does NOT work for S7 objects using plain method names because
# S7 uses namespaced class names ("surveycore::survey_base"). S3 dispatch
# looks for "filter.surveycore::survey_base" which is not a valid function
# name and can never be found.
#
# Solution: use registerS3method() in .onLoad() with the exact namespaced
# class string as the `class` argument. This is the mechanism by which
# surveytidy dplyr verbs are wired to survey design objects.
#
# Reference: plans/phase-0.5-formal-specification.md — Section 2.7

.onLoad <- function(libname, pkgname) {
  # Register S7 methods for S7-aware generics (print, summary, format, etc.)
  S7::methods_register()

  # Register dplyr verb S3 methods for S7 survey classes.
  # "surveycore::survey_base" matches all subclasses (taylor, replicate,
  # twophase) via S3's class hierarchy walk.
  ns <- asNamespace(pkgname)

  # ── feature/distinct ──────────────────────────────────────────────────────

  registerS3method(
    "distinct",
    "surveycore::survey_base",
    get("distinct.survey_base", envir = ns),
    envir = asNamespace("dplyr")
  )

  # ── feature/filter ────────────────────────────────────────────────────────

  registerS3method(
    "filter",
    "surveycore::survey_base",
    get("filter.survey_base", envir = ns),
    envir = asNamespace("dplyr")
  )

  registerS3method(
    "filter_out",
    "surveycore::survey_base",
    get("filter_out.survey_base", envir = ns),
    envir = asNamespace("dplyr")
  )

  registerS3method(
    "dplyr_reconstruct",
    "surveycore::survey_base",
    get("dplyr_reconstruct.survey_base", envir = ns),
    envir = asNamespace("dplyr")
  )

  registerS3method(
    "subset",
    "surveycore::survey_base",
    get("subset.survey_base", envir = ns),
    envir = baseenv()
  )

  # ── feature/select ────────────────────────────────────────────────────────

  registerS3method(
    "select",
    "surveycore::survey_base",
    get("select.survey_base", envir = ns),
    envir = asNamespace("dplyr")
  )

  registerS3method(
    "relocate",
    "surveycore::survey_base",
    get("relocate.survey_base", envir = ns),
    envir = asNamespace("dplyr")
  )

  registerS3method(
    "pull",
    "surveycore::survey_base",
    get("pull.survey_base", envir = ns),
    envir = asNamespace("dplyr")
  )

  registerS3method(
    "glimpse",
    "surveycore::survey_base",
    get("glimpse.survey_base", envir = ns),
    envir = asNamespace("dplyr")
  )

  # ── feature/mutate ────────────────────────────────────────────────────────

  registerS3method(
    "mutate",
    "surveycore::survey_base",
    get("mutate.survey_base", envir = ns),
    envir = asNamespace("dplyr")
  )

  # ── feature/rename ────────────────────────────────────────────────────────

  registerS3method(
    "rename",
    "surveycore::survey_base",
    get("rename.survey_base", envir = ns),
    envir = asNamespace("dplyr")
  )

  registerS3method(
    "rename_with",
    "surveycore::survey_base",
    get("rename_with.survey_base", envir = ns),
    envir = asNamespace("dplyr")
  )

  # ── feature/arrange ───────────────────────────────────────────────────────

  registerS3method(
    "arrange",
    "surveycore::survey_base",
    get("arrange.survey_base", envir = ns),
    envir = asNamespace("dplyr")
  )

  registerS3method(
    "slice",
    "surveycore::survey_base",
    get("slice.survey_base", envir = ns),
    envir = asNamespace("dplyr")
  )

  registerS3method(
    "slice_head",
    "surveycore::survey_base",
    get("slice_head.survey_base", envir = ns),
    envir = asNamespace("dplyr")
  )

  registerS3method(
    "slice_tail",
    "surveycore::survey_base",
    get("slice_tail.survey_base", envir = ns),
    envir = asNamespace("dplyr")
  )

  registerS3method(
    "slice_min",
    "surveycore::survey_base",
    get("slice_min.survey_base", envir = ns),
    envir = asNamespace("dplyr")
  )

  registerS3method(
    "slice_max",
    "surveycore::survey_base",
    get("slice_max.survey_base", envir = ns),
    envir = asNamespace("dplyr")
  )

  registerS3method(
    "slice_sample",
    "surveycore::survey_base",
    get("slice_sample.survey_base", envir = ns),
    envir = asNamespace("dplyr")
  )

  # ── feature/group-by ──────────────────────────────────────────────────────

  registerS3method(
    "group_by",
    "surveycore::survey_base",
    get("group_by.survey_base", envir = ns),
    envir = asNamespace("dplyr")
  )

  registerS3method(
    "ungroup",
    "surveycore::survey_base",
    get("ungroup.survey_base", envir = ns),
    envir = asNamespace("dplyr")
  )

  # ── feature/drop-na ───────────────────────────────────────────────────────

  registerS3method(
    "drop_na",
    "surveycore::survey_base",
    get("drop_na.survey_base", envir = ns),
    envir = asNamespace("tidyr")
  )
}
