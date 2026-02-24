# R/group-by.R
#
# group_by(), ungroup(), and group_vars() for survey design objects.
#
# Grouping state is stored exclusively in @groups — a character vector of
# column names. dplyr's grouped_df attribute is NOT added to @data.
# Phase 1 estimation functions will read @groups to perform stratified
# estimation. mutate() reads @groups to perform grouped mutations.
#
# group_by() delegates grouping resolution to dplyr::group_by() on @data so
# that all dplyr edge cases (computed expressions, tidy-select helpers, etc.)
# are handled identically to dplyr's own behaviour. The resulting grouped_df
# is used only to extract column names via dplyr::group_vars() — it is
# discarded afterward.
#
# ungroup() with no arguments removes all groups and exits rowwise mode.
# With column arguments, it removes only the named columns from @groups
# (partial ungroup), matching dplyr semantics exactly — rowwise mode is NOT
# cleared by partial ungroup.
#
# group_by() with .add = FALSE (default) replaces @groups and clears rowwise
# keys. With .add = TRUE when in rowwise mode, it promotes rowwise id_cols to
# @groups, then appends the new groups, then exits rowwise mode.
#
# group_vars.survey_base() returns @groups directly — no filtering needed
# because @groups never contains a sentinel value.
#
# Dispatch wiring: registered in .onLoad() via registerS3method().
# See R/zzz.R for the registration calls.

# ── group_by() ────────────────────────────────────────────────────────────────

#' Group and ungroup a survey design object
#'
#' @description
#' `group_by()` stores grouping columns on the survey object for use in
#' grouped operations like [mutate()]. `ungroup()` removes the grouping.
#' `group_vars()` returns the current grouping column names.
#'
#' Unlike dplyr, groups are not attached to the underlying data frame —
#' they are stored on the survey object itself and applied when needed by
#' verbs that support grouping.
#'
#' @details
#' ## Grouped operations
#' After calling `group_by()`, [mutate()] computes within groups. Future
#' estimation functions will also use grouping to perform stratified analysis.
#'
#' ## Adding to existing groups
#' By default, `group_by()` replaces existing groups. Use `.add = TRUE` to
#' append to the current grouping instead.
#'
#' ## Rowwise mode and group_by()
#' `group_by(.add = FALSE)` (the default) exits rowwise mode — it clears
#' `@variables$rowwise` and `@variables$rowwise_id_cols`. `group_by(.add =
#' TRUE)` when the design is rowwise promotes the rowwise id columns to
#' `@groups`, appends the new groups, then clears rowwise mode — mirroring
#' dplyr's behaviour exactly.
#'
#' ## Partial ungroup
#' `ungroup()` with no arguments removes all groups and exits rowwise mode.
#' With column arguments, it removes only the specified columns from the
#' grouping — rowwise mode is **not** affected.
#'
#' @param .data A [`survey_base`][surveycore::survey_base] object.
#' @param x A [`survey_base`][surveycore::survey_base] object (for
#'   `ungroup()` and `group_vars()`).
#' @param ... <[`data-masking`][rlang::args_data_masking]> For `group_by()`:
#'   columns to group by. Computed expressions (e.g.,
#'   `cut(ridageyr, breaks = c(0, 18, 65, Inf))`) are supported. For
#'   `ungroup()`: columns to remove from the current grouping. Omit to
#'   remove all groups.
#' @param .add When `FALSE` (default), replaces existing groups. Use
#'   `.add = TRUE` to add to the current grouping instead.
#' @param .drop Accepted for compatibility with the dplyr interface; has no
#'   effect on survey design objects.
#'
#' @return
#' An object of the same type as the input with the following properties:
#'
#' * Rows, columns, and survey design attributes are unchanged.
#' * For `group_by()`: grouping columns are set or updated; rowwise keys
#'   are cleared.
#' * For `ungroup()`: all or specified grouping columns are removed; rowwise
#'   keys are cleared on full ungroup only.
#' * For `group_vars()`: a character vector of current grouping column names.
#'
#' @examples
#' library(surveytidy)
#' library(surveycore)
#' library(dplyr)
#' d <- as_survey(pew_npors_2025, weights = weight, strata = stratum)
#'
#' # Group by a column
#' group_by(d, gender)
#'
#' # Grouped mutate — within-group mean centring
#' d |>
#'   group_by(gender) |>
#'   mutate(econ_centred = econ1mod - mean(econ1mod, na.rm = TRUE))
#'
#' # Add a second grouping variable with .add = TRUE
#' d |>
#'   group_by(gender) |>
#'   group_by(cregion, .add = TRUE)
#'
#' # Remove all groups
#' d |> group_by(gender) |> ungroup()
#'
#' # Partial ungroup — remove only gender, keep cregion
#' d |>
#'   group_by(gender, cregion) |>
#'   ungroup(gender)
#'
#' # Get current grouping column names
#' d |> group_by(gender, cregion) |> group_vars()
#'
#' @family grouping
group_by.survey_base <- function(
  .data,
  ...,
  .add = FALSE,
  .drop = dplyr::group_by_drop_default(.data)
) {
  # Delegate to dplyr to resolve column names — handles bare names, computed
  # expressions (e.g., cut(age, breaks)), tidy-select helpers, and any future
  # dplyr group_by() extensions. The grouped_df is used only to extract names.
  grouped <- dplyr::group_by(.data@data, ...)
  group_names <- dplyr::group_vars(grouped)

  if (isTRUE(.add)) {
    if (isTRUE(.data@variables$rowwise)) {
      # .add = TRUE when rowwise: promote id_cols to @groups first, then
      # append new groups, then exit rowwise mode. Mirrors dplyr behaviour.
      base_groups <- .data@variables$rowwise_id_cols %||% character(0)
      .data@variables$rowwise <- NULL
      .data@variables$rowwise_id_cols <- NULL
      .data@groups <- unique(c(base_groups, group_names))
    } else {
      # .add = TRUE when NOT rowwise: append to existing groups as before
      .data@groups <- unique(c(.data@groups, group_names))
    }
  } else {
    # .add = FALSE (default): replace @groups and exit rowwise mode
    .data@variables$rowwise <- NULL
    .data@variables$rowwise_id_cols <- NULL
    .data@groups <- group_names
  }

  .data
}


# ── ungroup() ─────────────────────────────────────────────────────────────────

#' @rdname group_by.survey_base
ungroup.survey_base <- function(x, ...) {
  if (...length() == 0L) {
    # No arguments: remove ALL groups and exit rowwise mode
    x@groups <- character(0)
    x@variables$rowwise <- NULL
    x@variables$rowwise_id_cols <- NULL
  } else {
    # Column arguments: partial ungroup — remove only the specified columns
    # from @groups. Rowwise mode is NOT cleared (matches dplyr behaviour).
    pos <- tidyselect::eval_select(rlang::expr(c(...)), x@data)
    to_remove <- names(pos)
    x@groups <- setdiff(x@groups, to_remove)
  }
  x
}


# ── group_vars() ──────────────────────────────────────────────────────────────

#' @rdname group_by.survey_base
#' @noRd
group_vars.survey_base <- function(x) {
  x@groups
}
