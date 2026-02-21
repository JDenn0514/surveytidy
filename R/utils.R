# R/utils.R
#
# Internal shared helpers used by 2+ verb files.
# Single-use helpers live at the top of their own source file.
#
# Functions defined here:
#   .protected_cols()               — columns that must never leave @data
#   .warn_physical_subset()         — standard warning for row-removal verbs
#   dplyr_reconstruct.survey_base() — class preservation in complex pipelines
#                                     (moved from R/01-filter.R on feature/select)


# ── surveycore internal wrappers ─────────────────────────────────────────────

# Wrappers around surveycore internal functions used by rename().
# Using get() + asNamespace() rather than surveycore::: avoids the
# "Unexported objects imported by ':::' calls" R CMD check NOTE.
#
# These wrappers are defined once here (R/utils.R) to avoid duplicating the
# get() calls in R/04-rename.R.

.sc_update_design_var_names <- function(variables, rename_map) {
  fn <- get(".update_design_var_names", envir = asNamespace("surveycore"))
  fn(variables, rename_map)
}

.sc_rename_metadata_keys <- function(metadata, rename_map) {
  fn <- get(".rename_metadata_keys", envir = asNamespace("surveycore"))
  fn(metadata, rename_map)
}


# ── Column protection ─────────────────────────────────────────────────────────

# Returns all column names that must never be removed from @data.
# Used by select(), rename(), mutate(), arrange(), and group_by() to enforce
# design variable protection.
#
# Protected columns are:
#   - All design variable columns (.get_design_vars_flat() from surveycore)
#   - The domain indicator column (SURVEYCORE_DOMAIN_COL), if present
.protected_cols <- function(design) {
  c(
    surveycore::.get_design_vars_flat(design),
    surveycore::SURVEYCORE_DOMAIN_COL
  )
}


# ── dplyr_reconstruct() ───────────────────────────────────────────────────────

# dplyr 1.1.0+ calls dplyr_reconstruct(new_data, template) after many verbs
# (joins, across(), slice, etc.) to rebuild the output class. Without this,
# pipelines silently return a tibble instead of a survey object.
#
# Also cleans up visible_vars when dplyr internally removes non-design columns
# (e.g., via .keep = "none" mutations routed through dplyr's machinery).
# Registered in .onLoad() — see R/00-zzz.R.
#' @noRd
dplyr_reconstruct.survey_base <- function(data, template) {
  design_vars  <- surveycore::.get_design_vars_flat(template)
  missing_vars <- setdiff(design_vars, names(data))
  if (length(missing_vars) > 0L) {
    cli::cli_abort(
      c(
        "x" = "Required design variable(s) removed: {.field {missing_vars}}.",
        "i" = "Design variables cannot be removed from a survey object.",
        "v" = "Use {.fn select} to hide columns without removing them."
      ),
      class = "surveycore_error_design_var_removed"
    )
  }
  # Clean up visible_vars if dplyr removed any referenced non-design columns
  if (!is.null(template@variables$visible_vars)) {
    vv <- intersect(template@variables$visible_vars, names(data))
    template@variables$visible_vars <- if (length(vv) == 0L) NULL else vv
  }
  template@data <- data
  template
}


# ── Physical subset warning ───────────────────────────────────────────────────

# Issues the standard warning for operations that physically remove rows.
# Used by subset.survey_base() (R/01-filter.R) and slice_*.survey_base()
# (R/05-arrange.R) and drop_na.survey_base() (R/07-tidyr.R).
#
# fn_name: the function name shown in the warning message, e.g. "slice_head"
.warn_physical_subset <- function(fn_name) {
  cli::cli_warn(
    c(
      "!" = "{.fn {fn_name}} physically removes rows from the survey data.",
      "i" = paste0(
        "This is different from {.fn filter}, which preserves all rows ",
        "for correct variance estimation."
      ),
      "v" = "Use {.fn filter} for subpopulation analyses instead."
    ),
    class = "surveycore_warning_physical_subset"
  )
}
