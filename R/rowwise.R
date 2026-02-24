# R/rowwise.R
#
# rowwise() for survey design objects.
#
# rowwise() sets @variables$rowwise = TRUE and stores optional id columns in
# @variables$rowwise_id_cols. These two keys are the only change to the object
# — @data, @groups, and @metadata are all unchanged.
#
# mutate() checks @variables$rowwise and routes to dplyr::rowwise(@data) in
# the rowwise branch, enabling row-by-row computation. See R/mutate.R.
#
# Rowwise mode is exited by:
#   - ungroup() (full): clears both @variables$rowwise and $rowwise_id_cols
#   - group_by(.add = FALSE): clears rowwise keys (default group_by)
#   - group_by(.add = TRUE): promotes id_cols to @groups, clears rowwise keys
#
# Predicates is_rowwise() and is_grouped() are exported from this file.
# group_vars.survey_base() is in R/group-by.R (alongside group_by/ungroup).
#
# Dispatch wiring: registered in .onLoad() via registerS3method().
# See R/zzz.R for the registration calls.

# ── rowwise() ─────────────────────────────────────────────────────────────────

#' Compute row-wise on a survey design object
#'
#' @description
#' `rowwise()` enables row-by-row computation in [mutate()]. Each row is
#' treated as an independent group, so expressions like
#' `mutate(d, row_max = max(c_across(starts_with("y"))))` compute the maximum
#' across columns for each row independently.
#'
#' Use [ungroup()] or [group_by()] to exit rowwise mode.
#'
#' @details
#' ## Storage
#' Rowwise mode is stored in `@variables$rowwise` (logical `TRUE`) and
#' `@variables$rowwise_id_cols` (character vector of id column names).
#' `@groups` is **not** modified — rowwise mode is independent of grouping.
#'
#' ## Exiting rowwise mode
#' * `ungroup(d)` — exits rowwise mode and removes all groups.
#' * `group_by(d, ...)` — exits rowwise mode and sets new groups.
#' * `group_by(d, ..., .add = TRUE)` — promotes id columns to groups, then
#'   appends the new groups, then exits rowwise mode.
#'
#' ## mutate() behaviour
#' [mutate()] detects rowwise mode and routes internally through
#' `dplyr::rowwise(@data)` before calling `dplyr::mutate()`. The `rowwise_df`
#' class is stripped from `@data` after mutation so subsequent operations
#' are not accidentally rowwise.
#'
#' @param data A [`survey_base`][surveycore::survey_base] object.
#' @param ... <[`tidy-select`][tidyselect::language]> Optional id columns that
#'   identify each row (used with [dplyr::c_across()]). Commonly omitted.
#'
#' @return `data` with `@variables$rowwise = TRUE` and
#'   `@variables$rowwise_id_cols` set. All other properties are unchanged.
#'
#' @examples
#' library(surveytidy)
#' library(surveycore)
#' library(dplyr)
#' d <- as_survey(pew_npors_2025, weights = weight, strata = stratum)
#'
#' # Row-wise max across several columns
#' d |>
#'   rowwise() |>
#'   mutate(row_max = max(c_across(starts_with("econ")), na.rm = TRUE))
#'
#' # Exit rowwise mode
#' d |> rowwise() |> ungroup()
#'
#' @family grouping
rowwise.survey_base <- function(data, ...) {
  if (...length() == 0L) {
    id_cols <- character(0)
  } else {
    pos <- tidyselect::eval_select(rlang::expr(c(...)), data@data)
    id_cols <- names(pos)
  }

  data@variables$rowwise <- TRUE
  data@variables$rowwise_id_cols <- id_cols
  data
}


# ── is_rowwise() ──────────────────────────────────────────────────────────────

#' Test whether a survey design is in rowwise mode
#'
#' @description
#' Returns `TRUE` if the design was created (or passed through) `rowwise()`.
#' Use this predicate in estimation functions to detect and handle (or
#' disallow) rowwise mode.
#'
#' @param design A [`survey_base`][surveycore::survey_base] object.
#'
#' @return A scalar logical.
#'
#' @examples
#' library(surveytidy)
#' library(surveycore)
#' d <- as_survey(pew_npors_2025, weights = weight, strata = stratum)
#'
#' is_rowwise(d)           # FALSE
#' is_rowwise(rowwise(d))  # TRUE
#'
#' @family grouping
#' @export
is_rowwise <- function(design) {
  isTRUE(design@variables$rowwise)
}


# ── is_grouped() ──────────────────────────────────────────────────────────────

#' Test whether a survey design has active grouping
#'
#' @description
#' Returns `TRUE` if the design has one or more grouping columns set via
#' [group_by()]. Returns `FALSE` for ungrouped or rowwise (but not grouped)
#' designs.
#'
#' @param design A [`survey_base`][surveycore::survey_base] object.
#'
#' @return A scalar logical.
#'
#' @examples
#' library(surveytidy)
#' library(surveycore)
#' library(dplyr)
#' d <- as_survey(pew_npors_2025, weights = weight, strata = stratum)
#'
#' is_grouped(d)                   # FALSE
#' is_grouped(group_by(d, gender)) # TRUE
#' is_grouped(rowwise(d))          # FALSE (rowwise != grouped)
#'
#' @family grouping
#' @export
is_grouped <- function(design) {
  length(design@groups) > 0L
}
