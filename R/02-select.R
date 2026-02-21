# R/02-select.R
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
# See R/00-zzz.R for the registration calls.
#
# Functions defined here:
#   select.survey_base()   — column selection with design-var preservation
#   relocate.survey_base() — column reordering (via visible_vars or @data)
#   pull.survey_base()     — extract a column as a vector
#   glimpse.survey_base()  — print a concise column summary


# ── select() ──────────────────────────────────────────────────────────────────

#' @noRd
select.survey_base <- function(.data, ...) {
  # Step 1: resolve the user's column selection
  user_pos  <- tidyselect::eval_select(rlang::expr(c(...)), .data@data)
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
    .data@metadata@variable_labels[[col]]   <- NULL
    .data@metadata@value_labels[[col]]      <- NULL
    .data@metadata@question_prefaces[[col]] <- NULL
    .data@metadata@notes[[col]]             <- NULL
    .data@metadata@transformations[[col]]   <- NULL
  }

  # Step 8: normalise visible_vars
  # NULL means "show everything in @data" — use NULL when the selection
  # is empty OR when the user selected every column in @data (e.g. everything())
  .data@variables$visible_vars <- if (
    length(visible) == 0L || setequal(visible, final_cols)
  ) NULL else visible

  .data
}


# ── relocate() ────────────────────────────────────────────────────────────────

#' @noRd
relocate.survey_base <- function(.data, ..., .before = NULL, .after = NULL) {
  # Capture .before and .after as quosures to avoid evaluating NSE expressions
  # (e.g. .before = y1) in the wrong environment. rlang::inject() then inlines
  # the expression into the dplyr::relocate() call where tidyselect can
  # evaluate it against the data frame.
  # Also: dplyr 1.2.0 errors when BOTH .before and .after are explicit (even
  # NULL), so only pass the ones that are actually provided.
  before_quo <- rlang::enquo(.before)
  after_quo  <- rlang::enquo(.after)
  has_before <- !rlang::quo_is_null(before_quo)
  has_after  <- !rlang::quo_is_null(after_quo)

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
    vv_df   <- .data@data[, .data@variables$visible_vars, drop = FALSE]
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
#' @noRd
pull.survey_base <- function(.data, var = -1, name = NULL, ...) {
  dplyr::pull(.data@data, var = {{ var }}, name = {{ name }}, ...)
}


# ── glimpse() ─────────────────────────────────────────────────────────────────

#' @noRd
glimpse.survey_base <- function(x, width = NULL, ...) {
  if (!is.null(x@variables$visible_vars)) {
    dplyr::glimpse(x@data[, x@variables$visible_vars, drop = FALSE], width, ...)
  } else {
    dplyr::glimpse(x@data, width, ...)
  }
  invisible(x)
}
