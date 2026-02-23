# R/rename.R
#
# rename() for survey design objects.
#
# Renames columns in @data, then keeps @variables and @metadata in sync:
#   - @variables: updated via surveycore:::.update_design_var_names() when a
#     design variable is renamed
#   - @metadata: keys renamed across all slots via
#     surveycore:::.rename_metadata_keys()
#   - @variables$visible_vars: old column names replaced with new names
#
# Renaming a design variable is allowed with a warning. The design specification
# is automatically kept in sync — this is a normal, valid operation.
#
# Dispatch wiring: registered in .onLoad() via registerS3method().
# See R/zzz.R for the registration calls.

# ── rename() ──────────────────────────────────────────────────────────────────

#' Rename columns of a survey design object
#'
#' @description
#' `rename()` changes column names in the underlying data and automatically
#' keeps the survey design in sync. Variable labels, value labels, and other
#' metadata follow the rename — no manual bookkeeping required.
#'
#' Renaming a design variable (weights, strata, PSUs) is fully supported:
#' the design specification updates automatically and a
#' `surveytidy_warning_rename_design_var` warning is issued to confirm the
#' change.
#'
#' @details
#' ## What gets updated
#' * **Column names in `@data`** — the rename takes effect immediately.
#' * **Design specification** — if a renamed column is a design variable
#'   (weights, strata, PSU, FPC, or replicate weights), `@variables` is
#'   updated to track the new name.
#' * **Metadata** — variable labels, value labels, question prefaces, notes,
#'   and transformation records in `@metadata` are re-keyed to the new name.
#' * **`visible_vars`** — any occurrence of the old name in
#'   `@variables$visible_vars` is replaced with the new name, so
#'   [select()] + `rename()` pipelines work correctly.
#'
#' ## Renaming design variables
#' Renaming a design variable (e.g., the weights column) is intentionally
#' allowed. A `surveytidy_warning_rename_design_var` warning is issued as a
#' reminder that the design specification has been updated — not to indicate
#' an error.
#'
#' @param .data A [`survey_base`][surveycore::survey_base] object.
#' @param ... <[`tidy-select`][tidyselect::language]> Use `new_name = old_name`
#'   pairs to rename columns. Any number of columns can be renamed in a
#'   single call.
#'
#' @return
#' An object of the same type as `.data` with the following properties:
#'
#' * Rows are not added or removed.
#' * Column order is preserved.
#' * Renamed columns are updated in `@data`, `@variables`, and `@metadata`.
#' * Groups and survey design attributes are preserved.
#'
#' @examples
#' library(surveytidy)
#' library(surveycore)
#' d <- as_survey(nhanes_2017,
#'   ids = sdmvpsu, weights = wtmec2yr, strata = sdmvstra, nest = TRUE
#' )
#'
#' # Rename an outcome column
#' rename(d, sbp = bpxsy1)
#'
#' # Rename multiple columns at once
#' rename(d, sbp = bpxsy1, dbp = bpxdi1)
#'
#' # Rename a design variable — warns and updates the design specification
#' rename(d, weights = wtmec2yr)
#'
#' @family modification
#' @seealso [mutate()] to add or modify column values, [select()] to drop columns
rename.survey_base <- function(.data, ...) {
  # Step 1: resolve the rename map via tidyselect
  # map: named integer vector, names = new names, values = column positions
  map <- tidyselect::eval_rename(rlang::expr(c(...)), .data@data)
  new_names <- names(map)
  old_names <- names(.data@data)[map]

  # rename_map: names = old column names, values = new column names
  # This is the convention expected by .update_design_var_names() and
  # .rename_metadata_keys().
  rename_map <- stats::setNames(new_names, old_names)

  # Step 2: warn if any design variable is being renamed
  protected <- intersect(.protected_cols(.data), names(.data@data))
  is_design_var <- old_names %in% protected
  if (any(is_design_var)) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "rename() renamed design variable(s): ",
          "{.field {old_names[is_design_var]}}."
        ),
        "i" = "The survey design has been updated to use the new name(s)."
      ),
      class = "surveytidy_warning_rename_design_var"
    )
  }

  # Steps 3-6: update @data, @variables, @metadata, and visible_vars atomically.
  #
  # Problem: S7's @<- operator runs the class validator after EVERY property
  # assignment. Renaming a design variable requires changing BOTH @data (the
  # column name) and @variables (the design spec) — and neither intermediate
  # state is valid: @data would have the new name while @variables still has
  # the old one, or vice versa.
  #
  # Solution: use attr() to bypass validation for each individual property
  # write, then call S7::S7_validate() once at the end on the fully consistent
  # final state.

  # Step 3: rename columns in @data (via attr to skip validation)
  new_data <- .data@data
  name_positions <- match(old_names, names(new_data))
  names(new_data)[name_positions] <- new_names
  attr(.data, "data") <- new_data

  # Step 4: update @variables (via attr to skip validation)
  new_variables <- .sc_update_design_var_names(.data@variables, rename_map)

  # Step 6 (visible_vars done here together with @variables):
  # update visible_vars within new_variables — replace old names with new names
  vv <- new_variables$visible_vars
  if (!is.null(vv)) {
    for (i in seq_along(old_names)) {
      vv[vv == old_names[[i]]] <- new_names[[i]]
    }
    new_variables$visible_vars <- vv
  }
  attr(.data, "variables") <- new_variables

  # Step 5: update @metadata keys across all slots
  # @metadata is a survey_metadata S7 object; update its internal properties
  # the same way to avoid triggering surveycore's metadata validator mid-update
  new_metadata <- .sc_rename_metadata_keys(.data@metadata, rename_map)
  attr(.data, "metadata") <- new_metadata

  # Final validation: ensure the fully assembled object is consistent.
  # S7::validate() re-runs the class validator on the complete object.
  S7::validate(.data)

  .data
}
