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

#' @noRd
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

#' @noRd
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
