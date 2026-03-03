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

# ── PR 2: Meta-updating verbs ──────────────────────────────────────────────
#
# These verbs actively update .meta to reflect column-level changes:
#   select.survey_result  — subset columns + prune stale $group entries
#   rename.survey_result  — rename columns + update $group/$x/$numerator/$denominator keys
#   rename_with.survey_result — apply .fn to column names + propagate to meta keys

# select: subset columns and prune meta$group for dropped columns.
# Inline renames (select(r, grp = group)) are handled by applying the rename
# map before subsetting so that .apply_result_rename_map can update meta keys.
#' @noRd
select.survey_result <- function(.data, ...) {
  tbl <- tibble::as_tibble(.data)
  old_class <- class(.data)

  # Step 1: Resolve selection → named integer: output_name → column position
  selected_cols <- tidyselect::eval_select(rlang::expr(c(...)), tbl)

  # Step 2: Extract original and output column names
  original_names <- names(tbl)[unname(selected_cols)]
  output_names <- names(selected_cols)

  # Step 3: Detect and apply any inline renames (e.g., select(r, grp = group))
  rename_mask <- original_names != output_names
  if (any(rename_mask)) {
    rename_map <- stats::setNames(
      output_names[rename_mask],
      original_names[rename_mask]
    )
    .data <- .apply_result_rename_map(.data, rename_map)
  }

  # Step 4: Subset to selected columns
  result <- .data[, output_names, drop = FALSE]

  # Step 5: Prune meta for dropped columns ($group keys only — $x keys are
  # input variable names that don't correspond to output columns for most
  # result types, so pruning by column presence would be incorrect)
  new_meta <- .prune_result_meta(attr(.data, ".meta"), output_names)

  # Step 6: Assign and restore
  attr(result, ".meta") <- new_meta
  class(result) <- old_class
  result
}

# rename: rename columns and propagate to all meta key references.
#' @noRd
rename.survey_result <- function(.data, ...) {
  tbl <- tibble::as_tibble(.data)

  # Build rename map: eval_rename returns named integer (new_name → position)
  # Convert to c(old_name = "new_name") format for .apply_result_rename_map
  map <- tidyselect::eval_rename(rlang::expr(c(...)), tbl)
  rename_map <- stats::setNames(names(map), names(tbl)[map])

  .apply_result_rename_map(.data, rename_map)
}

# rename_with: apply .fn to selected column names and propagate to meta keys.
#' @noRd
rename_with.survey_result <- function(.data, .fn, .cols = dplyr::everything(), ...) {
  tbl <- tibble::as_tibble(.data)

  # Step 1: Resolve .cols
  resolved_cols <- tidyselect::eval_select(rlang::enquo(.cols), tbl)
  old_names <- names(resolved_cols)

  # Zero-match .cols — no-op
  if (length(old_names) == 0L) return(.data)

  # Step 2: Apply .fn
  new_names <- .fn(old_names, ...)

  # Step 3: Validate all four bad-output conditions
  # Build the full column list with renames applied (for duplicate check)
  full_new_names <- names(tbl)
  full_new_names[match(old_names, full_new_names)] <- new_names

  if (
    !is.character(new_names) ||
      length(new_names) != length(old_names) ||
      anyNA(new_names) ||
      anyDuplicated(full_new_names) > 0L
  ) {
    cli::cli_abort(
      c(
        "x" = "{.arg .fn} must return a character vector the same length as
               its input with no {.code NA} or duplicate names.",
        "i" = "Got class {.cls {class(new_names)}} of length {length(new_names)}."
      ),
      class = "surveytidy_error_rename_fn_bad_output"
    )
  }

  # Step 4: Build rename map and delegate
  rename_map <- stats::setNames(new_names, old_names)
  .apply_result_rename_map(.data, rename_map)
}
