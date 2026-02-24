# R/rename.R
#
# rename() and rename_with() for survey design objects.
#
# Both verbs share the atomic-update helper .apply_rename_map(), which:
#   - Warns on design variable renames (surveytidy_warning_rename_design_var)
#   - Silently blocks renaming the domain column (SURVEYCORE_DOMAIN_COL)
#   - Atomically updates @data, @variables, @metadata, visible_vars, @groups
#
# Dispatch wiring: registered in .onLoad() via registerS3method().
# See R/zzz.R for the registration calls.

# ── .apply_rename_map() ───────────────────────────────────────────────────────

# Shared atomic-update helper used by rename() and rename_with().
#
# Arguments:
#   .data      — survey_base object
#   rename_map — named character vector; names = old col names, values = new
#
# Returns the modified .data object. S7 validation is called once at the end.
#
# @keywords internal
# @noRd
.apply_rename_map <- function(.data, rename_map) {
  old_names <- names(rename_map)
  new_names <- unname(rename_map)

  # Step 1: silently block renaming the domain column.
  # SURVEYCORE_DOMAIN_COL has a fixed identity used by filter() and estimation.
  # Renaming it would silently break those verbs. Other design variables (strata,
  # PSU, weights) are warned about but still renamed — users may legitimately
  # rename their own columns.
  domain_col <- surveycore::SURVEYCORE_DOMAIN_COL
  is_domain <- old_names == domain_col
  if (any(is_domain)) {
    rename_map <- rename_map[!is_domain]
    old_names <- names(rename_map)
    new_names <- unname(rename_map)
  }

  # If nothing remains after removing the domain column, warn and return.
  if (length(rename_map) == 0L) {
    # Only the domain col was in the map — issue the design var warning for it
    cli::cli_warn(
      c(
        "!" = "Renamed design variable{?s} {.field {domain_col}}.",
        "i" = "{cli::qty(1L)}The survey design has been updated to track the new name{?s}."
      ),
      class = "surveytidy_warning_rename_design_var"
    )
    return(.data)
  }

  # Step 2: warn if any design variable is being renamed (including domain col
  # that was stripped — combine for a single warning).
  protected <- intersect(.protected_cols(.data), names(.data@data))
  is_design_var <- old_names %in% protected
  all_design_cols <- c(
    if (any(is_domain)) domain_col else character(0),
    old_names[is_design_var]
  )
  if (length(all_design_cols) > 0L) {
    n_design_cols <- length(all_design_cols)
    cli::cli_warn(
      c(
        "!" = "Renamed design variable{?s} {.field {all_design_cols}}.",
        "i" = "{cli::qty(n_design_cols)}The survey design has been updated to track the new name{?s}."
      ),
      class = "surveytidy_warning_rename_design_var"
    )
  }

  # Steps 3–6: atomically update @data, @variables, @metadata, visible_vars,
  # and @groups. Use attr() to bypass per-assignment S7 validation, then call
  # S7::validate() once on the fully consistent final state.

  # Step 3: rename columns in @data
  new_data <- .data@data
  name_positions <- match(old_names, names(new_data))
  names(new_data)[name_positions] <- new_names
  attr(.data, "data") <- new_data

  # Step 4: update @variables (design spec + visible_vars)
  new_variables <- .sc_update_design_var_names(.data@variables, rename_map)

  # .sc_update_design_var_names() does not handle twophase nested phase1/phase2
  # variables or the $subset column — update those here.
  .update_phase_vars <- function(phase) {
    if (is.null(phase)) {
      return(phase)
    }
    for (slot in c("ids", "weights", "strata", "fpc", "probs")) {
      if (!is.null(phase[[slot]])) {
        matched <- phase[[slot]] %in% names(rename_map)
        phase[[slot]][matched] <- rename_map[phase[[slot]][matched]]
      }
    }
    phase
  }
  new_variables$phase1 <- .update_phase_vars(new_variables$phase1)
  new_variables$phase2 <- .update_phase_vars(new_variables$phase2)

  if (
    !is.null(new_variables$subset) &&
      new_variables$subset %in% names(rename_map)
  ) {
    new_variables$subset <- rename_map[[new_variables$subset]]
  }

  # Update visible_vars within new_variables — replace old names with new names
  vv <- new_variables$visible_vars
  if (!is.null(vv)) {
    for (i in seq_along(old_names)) {
      vv[vv == old_names[[i]]] <- new_names[[i]]
    }
    new_variables$visible_vars <- vv
  }
  attr(.data, "variables") <- new_variables

  # Step 5: update @metadata keys across all slots
  new_metadata <- .sc_rename_metadata_keys(.data@metadata, rename_map)
  attr(.data, "metadata") <- new_metadata

  # Step 6 (NEW): update @groups — replace old column names with new names
  old_groups <- .data@groups
  if (length(old_groups) > 0L) {
    new_groups <- old_groups
    for (i in seq_along(old_names)) {
      new_groups[new_groups == old_names[[i]]] <- new_names[[i]]
    }
    attr(.data, "groups") <- new_groups
  }

  # Final validation on the fully consistent state
  S7::validate(.data)

  .data
}


# ── rename() ──────────────────────────────────────────────────────────────────

#' Rename columns of a survey design object
#'
#' @description
#' `rename()` and `rename_with()` change column names in the underlying data
#' and automatically keep the survey design in sync. Variable labels, value
#' labels, and other metadata follow the rename — no manual bookkeeping
#' required.
#'
#' Use `rename()` for `new_name = old_name` pairs; use `rename_with()` to
#' apply a function across a selection of column names.
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
#' * **Groups** — if a renamed column is in the active grouping, `@groups`
#'   is updated to use the new name.
#'
#' ## Renaming design variables
#' Renaming a design variable (e.g., the weights column) is intentionally
#' allowed. A `surveytidy_warning_rename_design_var` warning is issued as a
#' reminder that the design specification has been updated — not to indicate
#' an error.
#'
#' ## rename_with() function forms
#' `.fn` can be any of:
#' * A bare function: `rename_with(d, toupper)`
#' * A formula: `rename_with(d, ~ toupper(.))`
#' * A lambda: `rename_with(d, \(x) paste0(x, "_v2"))`
#'
#' Extra arguments to `.fn` can be passed via `...`:
#' ```r
#' rename_with(d, stringr::str_replace, .cols = starts_with("y"),
#'             pattern = "y", replacement = "outcome")
#' ```
#'
#' `.cols` uses tidy-select syntax. The default `dplyr::everything()` applies
#' `.fn` to all columns including design variables — which will trigger a
#' `surveytidy_warning_rename_design_var` warning for each renamed design
#' variable.
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
#' * Renamed columns are updated in `@data`, `@variables`, `@metadata`, and
#'   `@groups`.
#' * Survey design attributes are preserved.
#'
#' @examples
#' library(dplyr)
#' library(surveytidy)
#' library(surveycore)
#' d <- as_survey(pew_npors_2025, weights = weight, strata = stratum)
#'
#' # rename() ----------------------------------------------------------------
#'
#' # Rename an outcome column
#' rename(d, financial_situation = fin_sit)
#'
#' # Rename multiple columns at once
#' rename(d, region = cregion, education = educcat)
#'
#' # Rename a design variable — warns and updates the design specification
#' rename(d, survey_weight = weight)
#'
#' # rename_with() -----------------------------------------------------------
#'
#' # Apply a function to all outcome columns
#' rename_with(d, toupper, .cols = starts_with("econ"))
#'
#' # Use a formula
#' rename_with(d, ~ paste0(., "_v2"), .cols = starts_with("econ"))
#'
#' @family modification
#' @seealso [mutate()] to add or modify column values, [select()] to drop
#'   columns
rename.survey_base <- function(.data, ...) {
  # map: named integer vector; names = new names, values = column positions
  map <- tidyselect::eval_rename(rlang::expr(c(...)), .data@data)
  new_names <- names(map)
  old_names <- names(.data@data)[map]

  # rename_map: names = old column names, values = new column names
  rename_map <- stats::setNames(new_names, old_names)

  .apply_rename_map(.data, rename_map)
}


# ── rename_with() ─────────────────────────────────────────────────────────────

#' @rdname rename.survey_base
#' @param .fn A function (or formula/lambda) applied to selected column names.
#'   Must return a character vector of the same length as its input, with no
#'   duplicates and no conflicts with existing non-renamed column names.
#' @param .cols <[`tidy-select`][tidyselect::language]> Columns whose names
#'   `.fn` will transform. Defaults to all columns.
rename_with.survey_base <- function(
  .data,
  .fn,
  .cols = dplyr::everything(),
  ...
) {
  # Step 1: resolve .cols to column names (NOT eval_rename — .cols is a
  # selection expression, not a new = old rename spec).
  # enquo() captures the caller's expression + environment so that tidyselect
  # helpers like starts_with() are found correctly.
  selected <- tidyselect::eval_select(rlang::enquo(.cols), .data@data)
  old_names <- names(selected)

  # Step 2: apply .fn to produce new column names
  .fn <- rlang::as_function(.fn)
  new_names <- rlang::exec(.fn, old_names, !!!rlang::list2(...))

  # Step 3: validate .fn output
  non_renamed <- setdiff(names(.data@data), old_names)

  if (!is.character(new_names)) {
    cli::cli_abort(
      c(
        "x" = "{.arg .fn} must return a character vector.",
        "i" = "Got {.cls {class(new_names)[[1L]]}} of length {length(new_names)}.",
        "v" = "Check that {.arg .fn} returns a plain character vector and handles all column names uniformly."
      ),
      class = "surveytidy_error_rename_fn_bad_output"
    )
  }

  if (length(new_names) != length(old_names)) {
    cli::cli_abort(
      c(
        "x" = "{.arg .fn} must return a character vector of the same length as its input.",
        "i" = "Input had {length(old_names)} name{?s}; {.arg .fn} returned {length(new_names)}.",
        "v" = "Check that {.arg .fn} returns a plain character vector and handles all column names uniformly."
      ),
      class = "surveytidy_error_rename_fn_bad_output"
    )
  }

  if (anyDuplicated(new_names) > 0L) {
    dupes <- new_names[duplicated(new_names)]
    cli::cli_abort(
      c(
        "x" = "{.arg .fn} must return a character vector with no duplicate names.",
        "i" = "Duplicate name{?s}: {.field {unique(dupes)}}.",
        "v" = "Check that {.arg .fn} returns a plain character vector and handles all column names uniformly."
      ),
      class = "surveytidy_error_rename_fn_bad_output"
    )
  }

  conflicts <- intersect(new_names, non_renamed)
  if (length(conflicts) > 0L) {
    n_conflicts <- length(conflicts)
    cli::cli_abort(
      c(
        "x" = "{cli::qty(n_conflicts)}{.arg .fn} returned name{?s} that conflict with existing columns.",
        "i" = "Conflicting name{?s}: {.field {conflicts}}.",
        "v" = "Check that {.arg .fn} returns a plain character vector and handles all column names uniformly."
      ),
      class = "surveytidy_error_rename_fn_bad_output"
    )
  }

  # Step 4: build rename_map and delegate to .apply_rename_map()
  rename_map <- stats::setNames(new_names, old_names)
  .apply_rename_map(.data, rename_map)
}
