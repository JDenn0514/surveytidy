# R/utils.R
#
# Internal shared helpers used by 2+ verb files.
# Single-use helpers live at the top of their own source file.
#
# Functions defined here:
#   .protected_cols()               — columns that must never leave @data
#   .warn_physical_subset()         — standard warning for row-removal verbs
#   dplyr_reconstruct.survey_base() — class preservation in complex pipelines
#                                     (moved from R/filter.R on feature/select)

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

# Returns the design-variable column names for any survey type.
#
# surveycore::.get_design_vars_flat() handles survey_taylor, survey_replicate,
# and survey_twophase but has no branch for survey_calibrated (returns
# character(0L) for that class). survey_calibrated carries only a weights
# column — no ids, strata, fpc, or repweights.
#
# This helper is the single authoritative source used by .protected_cols()
# and dplyr_reconstruct.survey_base().
.survey_design_var_names <- function(design) {
  if (S7::S7_inherits(design, surveycore::survey_calibrated)) {
    unique(c(design@variables$weights))
  } else {
    surveycore::.get_design_vars_flat(design)
  }
}

# Returns all column names that must never be removed from @data.
# Used by select(), rename(), mutate(), arrange(), and group_by() to enforce
# design variable protection.
#
# Protected columns are:
#   - All design variable columns (.survey_design_var_names())
#   - The domain indicator column (SURVEYCORE_DOMAIN_COL), if present
.protected_cols <- function(design) {
  c(
    .survey_design_var_names(design),
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
  design_vars <- .survey_design_var_names(template)
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
# Used by subset.survey_base() (R/filter.R) and slice_*.survey_base()
# (R/slice.R) and drop_na.survey_base() (R/drop-na.R).
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


# ── survey_result helpers ──────────────────────────────────────────────────────

# Restore class and .meta after NextMethod() strips them.
# Called by all survey_result passthrough verb methods.
.restore_survey_result <- function(result, old_class, old_meta) {
  attr(result, ".meta") <- old_meta
  class(result) <- old_class
  result
}

# Remove meta entries for columns that are no longer present in the result.
# Called by mutate.survey_result (.keep variants) and select.survey_result.
#
# meta : the .meta list
# kept_cols : character vector of column names remaining after the operation
#
# IMPORTANT: Only $group entries are pruned based on output column presence.
# $group keys are grouping variable names that ARE output columns
# (e.g., "group" for a result grouped by the "group" variable).
#
# $x keys are input focal variable names (e.g., "y1" for get_means()),
# NOT output column names (the estimate column is named "mean", not "y1").
# Pruning $x by output column presence would always null it out for
# get_means() results, which is wrong. $x is left unchanged.
#
# $numerator/$denominator are input variable names, same situation as $x.
# They are never pruned here.
.prune_result_meta <- function(meta, kept_cols) {
  # Prune group entries not in kept_cols (group keys ARE output column names)
  meta$group <- meta$group[names(meta$group) %in% kept_cols]
  meta
}

# Apply a rename map to both tibble column names and .meta key references.
#
# rename_map : named character vector, c(old_name = "new_name")
.apply_result_rename_map <- function(result, rename_map) {
  if (length(rename_map) == 0L) return(result)

  old_names <- names(rename_map)
  new_names <- unname(rename_map)

  # 1. Rename tibble columns
  col_pos <- match(old_names, names(result))
  names(result)[col_pos[!is.na(col_pos)]] <- new_names[!is.na(col_pos)]

  # 2. Update .meta
  m <- attr(result, ".meta")

  # group keys
  for (i in seq_along(old_names)) {
    idx <- match(old_names[i], names(m$group))
    if (!is.na(idx)) names(m$group)[idx] <- new_names[i]
  }

  # x keys
  if (!is.null(m$x)) {
    for (i in seq_along(old_names)) {
      idx <- match(old_names[i], names(m$x))
      if (!is.na(idx)) names(m$x)[idx] <- new_names[i]
    }
  }

  # numerator / denominator $name (get_ratios results only)
  if (!is.null(m$numerator$name) && m$numerator$name %in% old_names)
    m$numerator$name <- new_names[match(m$numerator$name, old_names)]
  if (!is.null(m$denominator$name) && m$denominator$name %in% old_names)
    m$denominator$name <- new_names[match(m$denominator$name, old_names)]

  attr(result, ".meta") <- m
  result
}
