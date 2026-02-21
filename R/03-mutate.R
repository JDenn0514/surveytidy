# R/03-mutate.R
#
# mutate() for survey design objects.
#
# Delegates the actual column computation to dplyr::mutate() on @data, then
# re-attaches any protected columns that dplyr dropped (e.g., via .keep =
# "none"), updates visible_vars, and records new column transformations in
# @metadata.
#
# Design variable modification is detected by name: if a mutation's LHS name
# matches a protected column, a warning is issued. Note that across() calls
# that modify design variables will NOT trigger this warning — the limitation
# is documented and accepted for Phase 0.5.
#
# Dispatch wiring: registered in .onLoad() via registerS3method().
# See R/00-zzz.R for the registration calls.


# ── mutate() ──────────────────────────────────────────────────────────────────

#' Add or modify columns of a survey design object
#'
#' @description
#' Delegates to `dplyr::mutate()` on `@data`, then:
#'
#' * Re-attaches any design variables dropped by `.keep = "none"` or
#'   `.keep = "used"`.
#' * Appends newly created columns to `@variables$visible_vars` when it is set.
#' * Records the transformation expression for new columns in
#'   `@metadata@transformations`.
#' * Respects `@groups` set by [group_by()] — pass `.by = NULL` (the default)
#'   and grouping from `group_by()` is applied automatically.
#'
#' @param .data A survey design object.
#' @param ... <[`data-masking`][rlang::args_data_masking]> Name-value pairs.
#'   The name gives the new column name; the value is an expression evaluated
#'   against `@data`.
#' @param .by Not used directly — use [group_by()] instead. If `@groups` is
#'   set and `.by` is `NULL`, `@groups` is used as the effective grouping.
#' @param .keep Which columns to retain. One of `"all"` (default), `"used"`,
#'   `"unused"`, or `"none"`. Design variables are always re-attached
#'   regardless of `.keep`.
#' @param .before,.after <[`tidy-select`][tidyselect::language]> Optionally
#'   position new columns before or after an existing one.
#'
#' @return The survey object with updated `@data`, `@variables$visible_vars`,
#'   and `@metadata@transformations`.
#'
#' @section Detecting design variable modification:
#' If the left-hand side of a mutation names a design variable (e.g.,
#' `mutate(d, wt = wt * 2)`), a `surveytidy_warning_mutate_design_var` warning
#' is issued. Detection is name-based — `across()` calls that happen to
#' modify design variables will **not** trigger the warning.
#'
#' @examples
#' library(dplyr)
#' df <- data.frame(y = rnorm(100), wt = runif(100, 1, 5),
#'                  g = sample(c("A","B"), 100, TRUE))
#' d  <- surveycore::as_survey(df, weights = wt)
#'
#' # Add a new column
#' d2 <- mutate(d, y_sq = y^2)
#'
#' # Grouped mutate
#' d3 <- d |>
#'   group_by(g) |>
#'   mutate(g_mean = mean(y))
#'
#' @family modification
#' @seealso [rename()] to rename columns, [select()] to drop columns
mutate.survey_base <- function(
  .data,
  ...,
  .by    = NULL,
  .keep  = c("all", "used", "unused", "none"),
  .before = NULL,
  .after  = NULL
) {
  .keep <- match.arg(.keep)

  # Step 1: Grouped mutate — when .by is NULL but @groups is non-empty, use
  # @groups as the effective grouping so group_by(d, g) |> mutate(z = mean(x))
  # works identically to dplyr's grouped_df behaviour.
  # Pass the character vector directly (not wrapped in all_of()) — dplyr's .by
  # accepts character vectors, and all_of() outside a selection context is
  # deprecated in tidyselect 1.2.0.
  effective_by <- if (is.null(.by) && length(.data@groups) > 0L) {
    .data@groups
  } else {
    .by
  }

  # Step 2: Detect design variable modification by name.
  # Only explicitly-named LHS expressions (e.g., mutate(d, wt = wt * 2)) are
  # detected. across() and other multi-output expressions are NOT detected —
  # this limitation is known and accepted for Phase 0.5.
  mutations      <- rlang::quos(...)
  mutated_names  <- names(mutations)
  protected      <- intersect(.protected_cols(.data), names(.data@data))
  changed_design <- intersect(mutated_names, protected)

  if (length(changed_design) > 0L) {
    cli::cli_warn(
      c(
        "!" = "mutate() modified design variable(s): {.field {changed_design}}.",
        "i" = "The survey design has been updated to reflect the new values.",
        "v" = paste0(
          "Use {.fn update_design} if you intend to modify design variables. ",
          "Modifying them via {.fn mutate} may produce unexpected variance ",
          "estimates."
        )
      ),
      class = "surveytidy_warning_mutate_design_var"
    )
  }

  # Step 3: Run the mutation on @data.
  # Capture .before and .after as quosures so NSE column-name expressions
  # (e.g., .before = y2) are forwarded correctly via rlang::inject().
  # Also: dplyr 1.2.0 errors when .before AND .after are both passed explicitly
  # (even as NULL), and tidyselect warns when effective_by = NULL is passed as
  # an external variable. Only include each argument when actually needed.
  before_quo  <- rlang::enquo(.before)
  after_quo   <- rlang::enquo(.after)
  has_before  <- !rlang::quo_is_null(before_quo)
  has_after   <- !rlang::quo_is_null(after_quo)
  has_by      <- !is.null(effective_by)

  new_data <- rlang::inject(
    dplyr::mutate(
      .data@data,
      ...,
      !!!if (has_by)     list(.by    = effective_by)  else list(),
      .keep = .keep,
      !!!if (has_before) list(.before = !!before_quo)  else list(),
      !!!if (has_after)  list(.after  = !!after_quo)   else list()
    )
  )

  # Step 4: Re-attach protected columns that .keep dropped
  # (e.g., .keep = "none" removes all non-mutated columns, including design vars)
  protected_in_data <- intersect(.protected_cols(.data), names(.data@data))
  missing_protected <- setdiff(protected_in_data, names(new_data))
  if (length(missing_protected) > 0L) {
    new_data <- cbind(new_data, .data@data[, missing_protected, drop = FALSE])
  }

  # Step 5: Update visible_vars — add new columns, remove dropped columns
  new_cols <- setdiff(names(new_data), names(.data@data))
  if (!is.null(.data@variables$visible_vars)) {
    vv <- .data@variables$visible_vars
    vv <- intersect(vv, names(new_data))  # remove any .keep-dropped visible cols
    vv <- c(vv, new_cols)                  # append newly created columns
    .data@variables$visible_vars <- if (length(vv) == 0L) NULL else vv
  }
  # If visible_vars is NULL, it stays NULL (all cols shown, new cols included)

  # Step 6: Record new column transformations in @metadata
  # Only explicitly-named mutations have a per-column quosure entry.
  for (col in new_cols) {
    q <- mutations[[col]]
    if (!is.null(q)) {
      .data@metadata@transformations[[col]] <- rlang::quo_text(q)
    }
  }

  # Step 7: Assign updated @data and return
  .data@data <- new_data
  .data
}
