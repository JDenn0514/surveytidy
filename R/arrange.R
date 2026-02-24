# R/arrange.R
#
# arrange() for survey design objects.
#
# arrange() sorts rows in @data. The domain column moves correctly with the
# rows — it is just another column. No update to @variables$domain quosures
# is needed (they are audit-only; the column is authoritative).
#
# Dispatch wiring: registered in .onLoad() via registerS3method().
# See R/zzz.R for the registration calls.
#
# Functions defined here:
#   arrange.survey_base() — row sorting

# ── arrange() ─────────────────────────────────────────────────────────────────

#' Order rows using column values
#'
#' @description
#' `arrange()` orders the rows of a [`survey_base`][surveycore::survey_base]
#' object by the values of selected columns.
#'
#' Unlike most other verbs, `arrange()` largely ignores grouping — use
#' `.by_group = TRUE` to sort by grouping variables first.
#'
#' @details
#' ## Missing values
#' Unlike base [sort()], `NA` values are always sorted to the end, even when
#' using [desc()].
#'
#' ## Domain column
#' The domain column moves with the rows — row reordering does not affect which
#' rows are in or out of the survey domain.
#'
#' @param .data A [`survey_base`][surveycore::survey_base] object.
#' @param ... <[`data-masking`][rlang::args_data_masking]> Variables, or
#'   functions of variables. Use [desc()] to sort a variable in descending
#'   order.
#' @param .by_group If `TRUE`, sorts first by the grouping variables set by
#'   [group_by()].
#' @param .locale The locale to use for ordering strings. If `NULL`, uses the
#'   `"C"` locale. See [stringi::locale()] for available locales.
#'
#' @return
#' An object of the same type as `.data` with the following properties:
#'
#' * All rows appear in the output, usually in a different position.
#' * Columns are not modified.
#' * Groups are not modified.
#' * Survey design attributes are preserved.
#'
#' @examples
#' library(surveytidy)
#' library(surveycore)
#' d <- as_survey(pew_npors_2025, weights = weight, strata = stratum)
#'
#' # Sort by age category ascending
#' arrange(d, agecat)
#'
#' # Sort by age category descending
#' arrange(d, dplyr::desc(agecat))
#'
#' # Sort by multiple variables
#' arrange(d, gender, dplyr::desc(agecat))
#'
#' # Sort by grouping variables first
#' d_grouped <- group_by(d, gender)
#' arrange(d_grouped, .by_group = TRUE, agecat)
#'
#' @family single table verbs
#' @seealso [filter()] for domain-aware row marking,
#'   [slice()] for physical row selection
arrange.survey_base <- function(.data, ..., .by_group = FALSE, .locale = NULL) {
  # When .by_group = TRUE and @groups is non-empty, prepend the group columns
  # to the sort order. dplyr's native .by_group = TRUE would silently do
  # nothing because @data has no grouped_df attribute — groups are stored in
  # @groups on the survey object, not as a data frame attribute.
  if (isTRUE(.by_group) && length(.data@groups) > 0L) {
    new_data <- dplyr::arrange(
      .data@data,
      dplyr::across(dplyr::all_of(.data@groups)),
      ...,
      .locale = .locale
    )
  } else {
    new_data <- dplyr::arrange(
      .data@data,
      ...,
      .by_group = .by_group,
      .locale = .locale
    )
  }
  .data@data <- new_data
  .data
}
