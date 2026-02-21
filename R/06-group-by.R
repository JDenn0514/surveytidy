# R/06-group-by.R
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
# See R/00-zzz.R for the registration calls.


# ── group_by() ────────────────────────────────────────────────────────────────

#' Group and ungroup a survey design object
#'
#' @description
#' * `group_by()` stores grouping column names in `@groups`. Unlike dplyr,
#'   **no `grouped_df` attribute** is attached to `@data` — grouping is kept on
#'   the survey object itself. Phase 1 estimation functions and [mutate()] read
#'   `@groups` to apply grouped calculations.
#' * `ungroup()` with no arguments removes all groups. With column arguments it
#'   performs a **partial ungroup**, removing only the named columns from
#'   `@groups`.
#'
#' @param .data A survey design object.
#' @param ... <[`data-masking`][rlang::args_data_masking]> Variables to group
#'   by. Computed expressions (e.g., `cut(age, breaks)`) are supported.
#' @param .add Logical. If `TRUE`, add to existing groups rather than
#'   replacing them.
#' @param .drop Passed to `dplyr::group_by_drop_default()`.
#' @param x A survey design object (for `ungroup()`).
#'
#' @return The survey object with `@groups` updated.
#'
#' @examples
#' df <- data.frame(y = rnorm(100), wt = runif(100, 1, 5),
#'                  region = sample(c("N","S","E","W"), 100, TRUE))
#' d  <- surveycore::as_survey(df, weights = wt)
#'
#' # Group and then compute group means via mutate()
#' d2 <- d |>
#'   group_by(region) |>
#'   mutate(region_mean = mean(y))
#'
#' # Partial ungroup
#' d3 <- group_by(d, region)
#' d4 <- ungroup(d3)          # remove all groups
#'
#' @family grouping
group_by.survey_base <- function(
  .data,
  ...,
  .add  = FALSE,
  .drop = dplyr::group_by_drop_default(.data)
) {
  # Delegate to dplyr to resolve column names — handles bare names, computed
  # expressions (e.g., cut(age, breaks)), tidy-select helpers, and any future
  # dplyr group_by() extensions. The grouped_df is used only to extract names.
  grouped     <- dplyr::group_by(.data@data, ...)
  group_names <- dplyr::group_vars(grouped)

  if (isTRUE(.add)) {
    .data@groups <- unique(c(.data@groups, group_names))
  } else {
    .data@groups <- group_names
  }

  .data
}


# ── ungroup() ─────────────────────────────────────────────────────────────────

#' @describeIn group_by.survey_base Remove grouping variables.
ungroup.survey_base <- function(x, ...) {
  if (...length() == 0L) {
    # No arguments: remove ALL groups
    x@groups <- character(0)
  } else {
    # Column arguments: partial ungroup — remove only the specified columns
    pos       <- tidyselect::eval_select(rlang::expr(c(...)), x@data)
    to_remove <- names(pos)
    x@groups  <- setdiff(x@groups, to_remove)
  }
  x
}
