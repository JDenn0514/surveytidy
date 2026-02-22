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

#' Sort rows of a survey design object
#'
#' @description
#' `arrange()` sorts rows in `@data`. The domain column moves with the rows —
#' no update to `@variables$domain` is needed. Supports `.by_group = TRUE`
#' using `@groups` set by [group_by()].
#'
#' For physically removing rows, see [slice()]. Prefer [filter()] for
#' subpopulation analyses.
#'
#' @param .data A survey design object.
#' @param ... <[`data-masking`][rlang::args_data_masking]> Variables or
#'   expressions to sort by.
#' @param .by_group Logical. If `TRUE` and `@groups` is set, rows are sorted
#'   by the grouping variables first, then by `...`.
#'
#' @return The survey object with rows reordered.
#'
#' @examples
#' library(dplyr)
#' df <- data.frame(y = rnorm(100), wt = runif(100, 1, 5),
#'                  g = sample(c("A","B"), 100, TRUE))
#' d  <- surveycore::as_survey(df, weights = wt)
#'
#' # Sort rows
#' d2 <- arrange(d, y)
#' d3 <- arrange(d, desc(y))
#'
#' @family row operations
#' @seealso [filter()] for domain-aware row marking (preferred),
#'   [slice()] for physical row selection
arrange.survey_base <- function(.data, ..., .by_group = FALSE) {
  # When .by_group = TRUE and @groups is non-empty, prepend the group columns
  # to the sort order. dplyr's native .by_group = TRUE would silently do
  # nothing because @data has no grouped_df attribute — groups are stored in
  # @groups on the survey object, not as a data frame attribute.
  if (isTRUE(.by_group) && length(.data@groups) > 0L) {
    new_data <- dplyr::arrange(
      .data@data,
      dplyr::across(dplyr::all_of(.data@groups)),
      ...
    )
  } else {
    new_data <- dplyr::arrange(.data@data, ..., .by_group = .by_group)
  }
  .data@data <- new_data
  .data
}
