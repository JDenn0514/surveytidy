# R/select.R
#
# Column-selection verbs for survey design objects.
#
# select() physically removes non-selected, non-design columns from @data and
# records the user's visible selection in @variables$visible_vars. Design
# variables are always preserved — they are required for variance estimation.
#
# relocate() reorders visible_vars when it is set; reorders @data when NULL.
#
# pull() and glimpse() are thin wrappers around dplyr internals.
#
# Dispatch wiring: registered in .onLoad() via registerS3method().
# See R/zzz.R for the registration calls.
#
# Functions defined here:
#   select.survey_base()   — column selection with design-var preservation
#   relocate.survey_base() — column reordering (via visible_vars or @data)
#   pull.survey_base()     — extract a column as a vector
#   glimpse.survey_base()  — print a concise column summary

# ── select() ──────────────────────────────────────────────────────────────────

#' Keep or drop columns using their names and types
#'
#' @description
#' `select()` keeps the named columns and drops all others, using the
#' [tidyselect mini-language][tidyselect::language] to describe column sets.
#' Design variables (weights, strata, PSU, FPC, replicate weights) are
#' **always retained** even when not explicitly selected — they are required
#' for variance estimation. After `select()`, `print()` shows only the columns
#' you selected; design variables remain in the object but are hidden from
#' display.
#'
#' `select()` is irreversible: dropped columns are permanently removed from
#' the survey object and cannot be recovered within the same pipeline.
#'
#' @details
#' ## Design variable preservation
#' Regardless of what you select, the following are always kept in the
#' survey object: weights, strata, PSUs, FPC columns, replicate weights,
#' and the domain column (if set by [filter()]). They are hidden from
#' `print()` output but remain available for variance estimation.
#'
#' ## Metadata
#' Variable labels, value labels, and other metadata for dropped columns
#' are removed. Metadata for retained columns is preserved.
#'
#' @param .data A [`survey_base`][surveycore::survey_base] object.
#' @param ... <[`tidy-select`][tidyselect::language]> One or more unquoted
#'   column names or tidy-select expressions.
#'
#' @return
#' An object of the same type as `.data` with the following properties:
#'
#' * Rows are not modified.
#' * Non-selected, non-design columns are permanently removed.
#' * Design variables are always retained.
#' * Survey design attributes are preserved.
#'
#' @examples
#' library(surveytidy)
#' library(surveycore)
#' d <- as_survey(nhanes_2017,
#'   ids = sdmvpsu, weights = wtmec2yr, strata = sdmvstra, nest = TRUE
#' )
#'
#' # Select by name
#' select(d, ridageyr, riagendr)
#'
#' # Select by name pattern
#' select(d, dplyr::starts_with("bpx"))
#'
#' # Select by type
#' select(d, dplyr::where(is.numeric))
#'
#' # Drop columns with !
#' select(d, !dplyr::starts_with("bpx"))
#'
#' @family selecting
#' @seealso [relocate()] to reorder columns, [rename()] to rename them,
#'   [mutate()] to add new ones
select.survey_base <- function(.data, ...) {
  # Step 1: resolve the user's column selection
  user_pos <- tidyselect::eval_select(rlang::expr(c(...)), .data@data)
  user_cols <- names(user_pos)

  # Step 2: protected columns that are already present in @data
  # (intersect guards against domain col not yet existing before first filter())
  protected <- intersect(.protected_cols(.data), names(.data@data))

  # Step 3: visible columns = the user's explicit selection only
  # (design variables are preserved in @data but are hidden from print unless
  # the user explicitly named them)
  visible <- user_cols

  # Step 4: final data columns — user's order first, then any protected cols
  # that were not in the user's selection appended at the end
  final_cols <- union(user_cols, protected)

  # Step 5: columns to physically remove (never in final_cols)
  dropped <- setdiff(names(.data@data), final_cols)

  # Step 6: update @data
  .data@data <- .data@data[, final_cols, drop = FALSE]

  # Step 7: delete @metadata entries for physically removed columns
  # surveycore:::.delete_metadata_col() does not exist; delete manually.
  for (col in dropped) {
    .data@metadata@variable_labels[[col]] <- NULL
    .data@metadata@value_labels[[col]] <- NULL
    .data@metadata@question_prefaces[[col]] <- NULL
    .data@metadata@notes[[col]] <- NULL
    .data@metadata@transformations[[col]] <- NULL
  }

  # Step 8: normalise visible_vars
  # NULL means "show everything in @data" — use NULL when the selection
  # is empty OR when the user selected every column in @data (e.g. everything())
  .data@variables$visible_vars <- if (
    length(visible) == 0L || setequal(visible, final_cols)
  ) {
    NULL
  } else {
    visible
  }

  .data
}


# ── relocate() ────────────────────────────────────────────────────────────────

#' Change column order in a survey design object
#'
#' @description
#' Move columns to a new position. When `@variables$visible_vars` is set
#' (i.e. after a `select()` call), only the visible columns are reordered —
#' design variables keep their position in `@data`. When `visible_vars` is
#' `NULL`, the full `@data` column order is updated.
#'
#' @param .data A survey design object.
#' @param ... <[`tidy-select`][tidyselect::language]> Columns to move.
#' @param .before,.after <[`tidy-select`][tidyselect::language]> Destination
#'   for the selected columns. At most one of `.before` and `.after` may be
#'   supplied.
#'
#' @return The survey object with `@variables$visible_vars` or `@data` column
#'   order updated.
#'
#' @examples
#' library(dplyr)
#' df <- data.frame(y1 = rnorm(50), y2 = rnorm(50), y3 = rnorm(50),
#'                  wt = runif(50, 1, 5))
#' d  <- surveycore::as_survey(df, weights = wt)
#'
#' # Move y3 before y1
#' d2 <- relocate(d, y3, .before = y1)
#'
#' # Works on visible_vars too (after a select())
#' d3 <- select(d, y1, y2, y3) |> relocate(y2, .after = y3)
#' d3@variables$visible_vars    # c("y1", "y3", "y2")
#'
#' @family selecting
#' @seealso [select()] to keep or drop columns
relocate.survey_base <- function(.data, ..., .before = NULL, .after = NULL) {
  # Capture .before and .after as quosures to avoid evaluating NSE expressions
  # (e.g. .before = y1) in the wrong environment. rlang::inject() then inlines
  # the expression into the dplyr::relocate() call where tidyselect can
  # evaluate it against the data frame.
  # Also: dplyr 1.2.0 errors when BOTH .before and .after are explicit (even
  # NULL), so only pass the ones that are actually provided.
  before_quo <- rlang::enquo(.before)
  after_quo <- rlang::enquo(.after)
  has_before <- !rlang::quo_is_null(before_quo)
  has_after <- !rlang::quo_is_null(after_quo)

  .do_relocate <- function(df) {
    if (has_before && has_after) {
      rlang::inject(
        dplyr::relocate(df, ..., .before = !!before_quo, .after = !!after_quo)
      )
    } else if (has_before) {
      rlang::inject(dplyr::relocate(df, ..., .before = !!before_quo))
    } else if (has_after) {
      rlang::inject(dplyr::relocate(df, ..., .after = !!after_quo))
    } else {
      dplyr::relocate(df, ...)
    }
  }

  if (!is.null(.data@variables$visible_vars)) {
    # When visible_vars is set, relocate applies to the visible columns only.
    # @data column order has no display meaning — only visible_vars does.
    vv_df <- .data@data[, .data@variables$visible_vars, drop = FALSE]
    ordered <- .do_relocate(vv_df)
    .data@variables$visible_vars <- names(ordered)
  } else {
    # No visible_vars: reorder @data directly
    .data@data <- .do_relocate(.data@data)
  }
  .data
}


# ── pull() ────────────────────────────────────────────────────────────────────

# pull() is a terminal operation — the result is a plain vector, not a survey
# object. No invariant checks, @groups, or @metadata considerations apply.
#' Extract a column from a survey design object
#'
#' @description
#' Pull a single column out of a survey design object as a plain vector.
#' This is a terminal operation — the result is not a survey object and cannot
#' be piped back into survey verbs.
#'
#' @param .data A survey design object.
#' @param var <[`data-masking`][rlang::args_data_masking]> Column to extract.
#'   Defaults to the last column.
#' @param name <[`data-masking`][rlang::args_data_masking]> Optional column
#'   whose values are used as names for the returned vector.
#' @param ... Passed to `dplyr::pull()`.
#'
#' @return A plain vector (not a survey object).
#'
#' @examples
#' library(dplyr)
#' df <- data.frame(y1 = rnorm(50), wt = runif(50, 1, 5))
#' d  <- surveycore::as_survey(df, weights = wt)
#'
#' # Extract y1 as a numeric vector
#' pull(d, y1)
#'
#' @family selecting
#' @seealso [select()] to keep columns in the survey object
pull.survey_base <- function(.data, var = -1, name = NULL, ...) {
  dplyr::pull(.data@data, var = {{ var }}, name = {{ name }}, ...)
}


# ── glimpse() ─────────────────────────────────────────────────────────────────

#' Get a glimpse of a survey design object
#'
#' @description
#' Print a transposed, condensed summary of the survey object's columns and
#' their types. Respects `@variables$visible_vars` — if set (i.e. after a
#' `select()` call), only the user-selected columns are shown, not the
#' design variables.
#'
#' @param x A survey design object.
#' @param width Width of the output. Defaults to the console width.
#' @param ... Passed to `dplyr::glimpse()`.
#'
#' @return `x` invisibly.
#'
#' @examples
#' library(dplyr)
#' df <- data.frame(y1 = rnorm(50), y2 = rnorm(50),
#'                  wt = runif(50, 1, 5), g = sample(c("A","B"), 50, TRUE))
#' d  <- surveycore::as_survey(df, weights = wt)
#'
#' # Shows all columns
#' glimpse(d)
#'
#' # After select(), shows only visible columns
#' glimpse(select(d, y1, y2))
#'
#' @family selecting
#' @seealso [select()] to control which columns are visible
glimpse.survey_base <- function(x, width = NULL, ...) {
  if (!is.null(x@variables$visible_vars)) {
    dplyr::glimpse(x@data[, x@variables$visible_vars, drop = FALSE], width, ...)
  } else {
    dplyr::glimpse(x@data, width, ...)
  }
  invisible(x)
}
