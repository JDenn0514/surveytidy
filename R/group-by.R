# R/group-by.R
#
# group_by() and ungroup() for survey design objects.
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
# ungroup() with no arguments removes all groups. With column arguments, it
# removes only the named columns from @groups (partial ungroup), matching
# dplyr semantics exactly.
#
# Dispatch wiring: registered in .onLoad() via registerS3method().
# See R/zzz.R for the registration calls.

# ── group_by() ────────────────────────────────────────────────────────────────

#' Group and ungroup a survey design object
#'
#' @description
#' `group_by()` stores grouping columns on the survey object for use in
#' grouped operations like [mutate()]. `ungroup()` removes the grouping.
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
#' ## Partial ungroup
#' `ungroup()` with no arguments removes all groups. With column arguments,
#' it removes only the specified columns from the grouping.
#'
#' @param .data A [`survey_base`][surveycore::survey_base] object.
#' @param x A [`survey_base`][surveycore::survey_base] object (for
#'   `ungroup()`).
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
#' * For `group_by()`: grouping columns are set or updated.
#' * For `ungroup()`: all or specified grouping columns are removed.
#'
#' @examples
#' library(surveytidy)
#' library(surveycore)
#' d <- as_survey(nhanes_2017,
#'   ids = sdmvpsu, weights = wtmec2yr, strata = sdmvstra, nest = TRUE
#' )
#'
#' # Group by a column
#' group_by(d, riagendr)
#'
#' # Grouped mutate — within-group mean centring
#' d |>
#'   group_by(riagendr) |>
#'   mutate(bp_centred = bpxsy1 - mean(bpxsy1, na.rm = TRUE))
#'
#' # Add a second grouping variable with .add = TRUE
#' d |>
#'   group_by(riagendr) |>
#'   group_by(ridreth3, .add = TRUE)
#'
#' # Remove all groups
#' d |> group_by(riagendr) |> ungroup()
#'
#' # Partial ungroup — remove only riagendr, keep ridreth3
#' d |>
#'   group_by(riagendr, ridreth3) |>
#'   ungroup(riagendr)
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
    .data@groups <- unique(c(.data@groups, group_names))
  } else {
    .data@groups <- group_names
  }

  .data
}


# ── ungroup() ─────────────────────────────────────────────────────────────────

#' @rdname group_by.survey_base
ungroup.survey_base <- function(x, ...) {
  if (...length() == 0L) {
    # No arguments: remove ALL groups
    x@groups <- character(0)
  } else {
    # Column arguments: partial ungroup — remove only the specified columns
    pos <- tidyselect::eval_select(rlang::expr(c(...)), x@data)
    to_remove <- names(pos)
    x@groups <- setdiff(x@groups, to_remove)
  }
  x
}
