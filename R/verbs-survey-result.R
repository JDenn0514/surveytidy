# R/verbs-survey-result.R
#
# dplyr/tidyr verb methods for survey_result objects.
#
# survey_result objects are S3 tibble subclasses returned by surveycore
# analysis functions (get_means(), get_freqs(), get_totals(),
# get_quantiles(), get_corr(), get_ratios()). Without verb methods, some
# dplyr/tidyr verbs (notably drop_na) strip the custom class and/or .meta
# attribute. These methods preserve both class and .meta across all supported
# operations, with active meta updates for column-touching verbs.
#
# All methods are registered for "survey_result" (the shared base class) in
# R/zzz.R. S3 dispatch walks survey_freqs -> survey_result -> tbl_df, so one
# registration per verb covers all six subclasses automatically.
#
# PR 1: Passthrough verbs (this file, partial) — filter, arrange, mutate,
#        slice, slice_head, slice_tail, slice_min, slice_max, slice_sample,
#        drop_na
# PR 2: Meta-updating verbs (extends this file) — select, rename, rename_with
#
# Spec: plans/spec-survey-result-verbs.md

# ── Inline helpers (all call sites in this one file) ──────────────────────

# Restore class and .meta after NextMethod() strips them.
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

# ── PR 1: Passthrough verbs ────────────────────────────────────────────────
#
# All passthrough verbs:
#   1. Capture class and .meta before NextMethod()
#   2. Call NextMethod() to get the row/column-modified tibble
#   3. Restore class and .meta via .restore_survey_result()
#
# mutate diverges by also calling .prune_result_meta() after restoration to
# maintain the meta coherence invariant when .keep drops columns.

# filter: simplified signature — .by is NSE and must flow through ... for
# proper tidy-select forwarding via NextMethod().
#' @noRd
filter.survey_result <- function(.data, ...) {
  old_class <- class(.data)
  old_meta <- attr(.data, ".meta")
  NextMethod() |> .restore_survey_result(old_class, old_meta)
}

# arrange: .by_group is a plain logical (not NSE), safe to name explicitly.
#' @noRd
arrange.survey_result <- function(.data, ..., .by_group = FALSE) {
  old_class <- class(.data)
  old_meta <- attr(.data, ".meta")
  NextMethod() |> .restore_survey_result(old_class, old_meta)
}

# mutate: simplified signature — .before/.after are NSE; .keep flows through
# ... so NextMethod() can evaluate it. Always call .prune_result_meta() after
# restoration to maintain the coherence invariant — it is a no-op when no
# meta-referenced columns are dropped (the .keep = "all" common case).
#' @noRd
mutate.survey_result <- function(.data, ...) {
  old_class <- class(.data)
  old_meta <- attr(.data, ".meta")
  result <- NextMethod() |> .restore_survey_result(old_class, old_meta)
  new_meta <- .prune_result_meta(attr(result, ".meta"), names(result))
  attr(result, ".meta") <- new_meta
  result
}

# slice variants: all NSE/scalar arguments flow through ... via NextMethod().
#' @noRd
slice.survey_result <- function(.data, ...) {
  old_class <- class(.data)
  old_meta <- attr(.data, ".meta")
  NextMethod() |> .restore_survey_result(old_class, old_meta)
}

#' @noRd
slice_head.survey_result <- function(.data, ...) {
  old_class <- class(.data)
  old_meta <- attr(.data, ".meta")
  NextMethod() |> .restore_survey_result(old_class, old_meta)
}

#' @noRd
slice_tail.survey_result <- function(.data, ...) {
  old_class <- class(.data)
  old_meta <- attr(.data, ".meta")
  NextMethod() |> .restore_survey_result(old_class, old_meta)
}

#' @noRd
slice_min.survey_result <- function(.data, ...) {
  old_class <- class(.data)
  old_meta <- attr(.data, ".meta")
  NextMethod() |> .restore_survey_result(old_class, old_meta)
}

#' @noRd
slice_max.survey_result <- function(.data, ...) {
  old_class <- class(.data)
  old_meta <- attr(.data, ".meta")
  NextMethod() |> .restore_survey_result(old_class, old_meta)
}

#' @noRd
slice_sample.survey_result <- function(.data, ...) {
  old_class <- class(.data)
  old_meta <- attr(.data, ".meta")
  NextMethod() |> .restore_survey_result(old_class, old_meta)
}

# tidyr's drop_na generic uses `data`, not `.data`.
#' @noRd
drop_na.survey_result <- function(data, ...) {
  old_class <- class(data)
  old_meta <- attr(data, ".meta")
  NextMethod() |> .restore_survey_result(old_class, old_meta)
}
