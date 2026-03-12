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
# and survey_twophase but has no branch for survey_nonprob (returns
# character(0L) for that class). survey_nonprob carries only a weights
# column — no ids, strata, fpc, or repweights.
#
# This helper is the single authoritative source used by .protected_cols()
# and dplyr_reconstruct.survey_base().
.survey_design_var_names <- function(design) {
  if (S7::S7_inherits(design, surveycore::survey_nonprob)) {
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


# ── mutate() label helpers ────────────────────────────────────────────────────

# Pre-attachment: copy label attrs from @metadata into the data.frame so
# recode functions called inside mutate() can read them via attr(x, "labels")
# and attr(x, "label"). Does NOT set the "haven_labelled" class — attrs only.
# Always-on: runs on every mutate() call; fast path returns early when
# @metadata has no labels (negligible overhead for the common case).
.attach_label_attrs <- function(data, metadata) {
  if (
    length(metadata@value_labels) == 0L &&
      length(metadata@variable_labels) == 0L
  ) {
    return(data)
  }
  for (col in names(metadata@value_labels)) {
    if (col %in% names(data)) {
      attr(data[[col]], "labels") <- metadata@value_labels[[col]]
    }
  }
  for (col in names(metadata@variable_labels)) {
    if (col %in% names(data)) {
      attr(data[[col]], "label") <- metadata@variable_labels[[col]]
    }
  }
  data
}

# Post-detection: inspect changed_cols in new_data for the "surveytidy_recode"
# attribute set by recode functions. When found, extract label attrs into
# metadata. When the column was previously labelled and the new output carries
# no "surveytidy_recode" attr, clear stale labels.
#
# changed_cols : character vector — names of explicitly-named LHS expressions
#                from rlang::quos(...). Unnamed mutate expressions (e.g.,
#                across()) are not covered — accepted limitation for Phase 0.6.
# Returns updated metadata object (does NOT assign internally).
.extract_labelled_outputs <- function(data, metadata, changed_cols) {
  for (col in changed_cols) {
    if (!col %in% names(data)) {
      next
    }
    recode_attr <- attr(data[[col]], "surveytidy_recode")
    if (!is.null(recode_attr)) {
      # Recode function output: extract label attrs.
      # attr(x, "label") and attr(x, "labels") are both NULL for factor and
      # plain-with-description outputs; assigning NULL clears the entry, which
      # is correct — the old encoding labels are no longer valid.
      metadata@variable_labels[[col]] <- attr(
        data[[col]],
        "label",
        exact = TRUE
      )
      metadata@value_labels[[col]] <- attr(data[[col]], "labels", exact = TRUE)
    } else if (
      !is.null(metadata@variable_labels[[col]]) ||
        !is.null(metadata@value_labels[[col]])
    ) {
      # Non-recode overwrite of a previously-labelled column: clear stale labels.
      metadata@variable_labels[[col]] <- NULL
      metadata@value_labels[[col]] <- NULL
    }
  }
  metadata
}

# Strip: remove all haven label attrs and the surveytidy_recode attr from
# every column before storing new_data in @data. haven::zap_labels() removes
# "label", "labels", "format.spss", "display_width", and the "haven_labelled"
# class. "surveytidy_recode" is not a haven attr, so it is removed separately.
.strip_label_attrs <- function(data) {
  for (col in names(data)) {
    data[[col]] <- haven::zap_labels(data[[col]])
    # haven::zap_labels() removes "labels", "format.spss", "display_width",
    # and the "haven_labelled" class, but KEEPS the "label" attr. Remove it.
    attr(data[[col]], "label") <- NULL
    attr(data[[col]], "surveytidy_recode") <- NULL
  }
  data
}


# ── recode helpers ────────────────────────────────────────────────────────────

# Validate .label, .value_labels, and .description arguments.
# Called by all six recode functions. Returns invisible(TRUE) on success.
.validate_label_args <- function(label, value_labels, description = NULL) {
  if (!is.null(label) && !(is.character(label) && length(label) == 1L)) {
    cli::cli_abort(
      c(
        "x" = "{.arg .label} must be a single character string.",
        "i" = "Got {.cls {class(label)}} of length {length(label)}."
      ),
      class = "surveytidy_error_recode_label_not_scalar"
    )
  }
  if (!is.null(value_labels) && is.null(names(value_labels))) {
    cli::cli_abort(
      c(
        "x" = "{.arg .value_labels} must be a named vector.",
        "i" = "Got an unnamed {.cls {class(value_labels)}}.",
        "v" = "Use {.code c(\"Label\" = value, ...)} to name the entries."
      ),
      class = "surveytidy_error_recode_value_labels_unnamed"
    )
  }
  if (
    !is.null(description) &&
      !(is.character(description) && length(description) == 1L)
  ) {
    cli::cli_abort(
      c(
        "x" = "{.arg .description} must be a single character string.",
        "i" = "Got {.cls {class(description)}} of length {length(description)}."
      ),
      class = "surveytidy_error_recode_description_not_scalar"
    )
  }
  invisible(TRUE)
}

# Wrap a result vector in haven::labelled() and set the surveytidy_recode attr.
# Called when at least one of .label or .value_labels is non-NULL.
.wrap_labelled <- function(x, label, value_labels, description = NULL) {
  result <- haven::labelled(x, labels = value_labels, label = label)
  attr(result, "surveytidy_recode") <- list(description = description)
  result
}

# Convert result to a factor with levels ordered by value_labels (if provided)
# or by formula_values / unique(to) (if value_labels is NULL).
.factor_from_result <- function(x, value_labels, formula_values) {
  if (!is.null(value_labels)) {
    levels <- names(value_labels)
  } else {
    levels <- formula_values
  }
  factor(x, levels = levels)
}

# Merge base_labels (from x's attr) with override_labels (.value_labels arg).
# override_labels entries replace matching base_labels entries by name; new
# override entries are appended. When two entries share the same numeric value
# (e.g. base has "Independent" = 3 and override adds "Independent/Other" = 3),
# the later (override) entry wins and the earlier (base) entry is dropped.
# Returns NULL when both inputs are NULL.
.merge_value_labels <- function(base_labels, override_labels) {
  if (is.null(base_labels) && is.null(override_labels)) {
    return(NULL)
  }
  if (is.null(base_labels)) {
    return(override_labels)
  }
  if (is.null(override_labels)) {
    return(base_labels)
  }
  merged <- base_labels
  for (nm in names(override_labels)) {
    merged[nm] <- override_labels[[nm]]
  }
  # haven::labelled() requires unique values. When override introduced a new
  # label name for an existing value, drop the earlier (base) entry so the
  # override takes precedence. fromLast = TRUE keeps the last occurrence.
  merged[!duplicated(unname(merged), fromLast = TRUE)]
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
  if (length(rename_map) == 0L) {
    return(result)
  }

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
  if (!is.null(m$numerator$name) && m$numerator$name %in% old_names) {
    m$numerator$name <- new_names[match(m$numerator$name, old_names)]
  }
  if (!is.null(m$denominator$name) && m$denominator$name %in% old_names) {
    m$denominator$name <- new_names[match(m$denominator$name, old_names)]
  }

  attr(result, ".meta") <- m
  result
}
