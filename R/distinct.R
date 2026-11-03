# R/distinct.R
#
# distinct.survey_base() — physical row deduplication for survey design objects.
#
# distinct() physically removes duplicate rows while always retaining all
# columns in @data (including design variables). Unlike dplyr::distinct()
# which by default drops non-selected columns, this implementation always
# uses .keep_all = TRUE internally — design variables must never be lost.
#
# The .keep_all = FALSE user argument is silently ignored — this is
# intentional and documented in the spec (spec §III.3).
#
# Dispatch wiring: registered in .onLoad() via registerS3method().
# See R/zzz.R for the registration calls.
#
# `...` uses data-masking, as in dplyr::distinct(). The keys are evaluated
# apart from @data, so computed expressions never add columns to the result.
#
# Functions defined here:
#   distinct.survey_base()           — row deduplication with physical-subset
#                                      warning
#   distinct.survey_collection()     — per-member dispatch
#   .check_distinct_select_helpers() — rejects bare tidyselect helpers in ...

#' Remove duplicate rows from a survey design object
#'
#' @description
#' `distinct()` **physically removes duplicate rows** from a survey design
#' object, always issuing `surveycore_warning_physical_subset`. Unlike
#' [dplyr::distinct()], all columns in `@data` are retained regardless of
#' which columns are specified in `...` — design variables must never be
#' lost from the survey object.
#'
#' For subpopulation analyses, use [filter()] instead — it marks rows
#' out-of-domain without removing them, preserving valid variance estimation.
#'
#' @details
#' ## Column retention
#' `distinct()` always behaves as if `.keep_all = TRUE`. Specifying columns
#' in `...` controls which columns determine uniqueness — it does **not**
#' control which columns appear in the result. This is a deliberate
#' divergence from `dplyr::distinct(df, x, y)` which by default drops all
#' columns except `x` and `y`.
#'
#' ## Default deduplication (empty `...`)
#' When `...` is empty, deduplication uses all non-design columns. Design
#' variables (strata, PSU, weights, FPC) are excluded from the uniqueness
#' check — deduplicating on them would produce meaningless or
#' survey-corrupting results.
#'
#' ## Data-masking, not tidyselect
#' `...` uses data-masking, as in [dplyr::distinct()]. Bare names and
#' computed expressions (such as `y1 > 50` or `band = round(y1 / 10)`) are
#' both accepted. A computed expression is used only to find duplicates; it
#' is not added to `@data`. To use a selection helper such as
#' [tidyselect::all_of()], wrap it in [dplyr::pick()] or [dplyr::across()]:
#' `distinct(d, pick(all_of(cols)))`. A selection helper passed directly in
#' `...` raises `surveytidy_error_distinct_select_helper`.
#'
#' ## Design variable warning
#' If `...` includes a design variable, `surveytidy_warning_distinct_design_var`
#' is issued before the operation. The operation still proceeds after the
#' warning — the user is assumed to know what they are doing.
#'
#' @param .data A [`survey_base`][surveycore::survey_base] object.
#' @param ... <[`data-masking`][rlang::args_data_masking]> Optional columns
#'   or expressions used to determine uniqueness. If empty, all non-design
#'   columns are used. Wrap selection helpers in [dplyr::pick()].
#'   Note: `.keep_all` is always `TRUE` regardless of what is specified here.
#' @param .keep_all Accepted for interface compatibility; **has no effect**.
#'   The survey implementation always retains all columns in `@data`.
#'
#' @return
#' An object of the same class as `.data` with the following properties:
#'
#' * Rows physically reduced to distinct subset (fewer rows possible).
#' * All columns in `@data` are retained (`.keep_all = TRUE` always).
#' * `@variables$visible_vars` is unchanged — distinct is a pure row operation.
#' * `@metadata` is unchanged.
#' * `@groups` is unchanged.
#' * Always issues `surveycore_warning_physical_subset`.
#'
#' @examples
#' library(surveytidy)
#' library(surveycore)
#'
#' # create a survey design from the pew_npors_2025 example dataset
#' d <- as_survey(pew_npors_2025, weights = weight, strata = stratum)
#'
#' # deduplicate on all non-design columns (issues physical-subset warning)
#' distinct(d)
#'
#' # deduplicate by one column (all other columns still retained)
#' distinct(d, cregion)
#'
#' # use a selection helper inside pick()
#' distinct(d, dplyr::pick(tidyselect::all_of("cregion")))
#'
#' @family row operations
#' @seealso [filter()] for domain-aware row marking (preferred for
#'   subpopulation analyses)
#' @name distinct
NULL

#' @rdname distinct
#' @method distinct survey_base
distinct.survey_base <- function(.data, ..., .keep_all = FALSE) {
  dots <- rlang::enquos(...)

  # Step 1: Reject bare selection helpers before any side effect.
  .check_distinct_select_helpers(dots)

  # Step 2: Always warn — distinct() physically removes rows.
  .warn_physical_subset("distinct")

  if (length(dots) > 0L) {
    # Step 3: Evaluate ... with data-masking, as dplyr::distinct() does.
    # mutate(.keep = "none") returns one column per key: bare names,
    # computed expressions, and pick()/across() results. The key columns
    # are kept apart from @data, so computed keys never enter the result.
    keys <- dplyr::mutate(.data@data, !!!dots, .keep = "none")
    design_in_dots <- intersect(names(keys), .protected_cols(.data))

    if (length(design_in_dots) > 0L) {
      cli::cli_warn(
        c(
          "!" = "Deduplicating by design variable{?s} {.field {design_in_dots}} may corrupt variance estimation.",
          "i" = "Design variables define the sampling structure; removing rows that share design variable values can invalidate standard error calculations.",
          "i" = "Use {.code distinct(d)} without specifying design variables, or use {.fn subset} if physical row removal is intentional."
        ),
        class = "surveytidy_warning_distinct_design_var"
      )
    }
  } else {
    # Step 3 (empty ...): Deduplicate on non-design columns only.
    # This is the survey-safe default — design variables define sampling
    # structure and deduplicating on them would be meaningless or harmful.
    non_design <- setdiff(names(.data@data), .protected_cols(.data))
    keys <- .data@data[non_design]
  }

  # Step 4: Keep the first row of each distinct key, with all columns.
  # vctrs::vec_unique_loc() is the row-matching rule dplyr::distinct() uses.
  # @groups and @metadata propagate unchanged.
  .data@data <- vctrs::vec_slice(.data@data, vctrs::vec_unique_loc(keys))
  .data
}


# ── distinct.survey_collection (PR 2b) ────────────────────────────────────────

#' @rdname distinct
#' @method distinct survey_collection
#' @inheritParams survey_collection_args
#'
#' @section Survey collections:
#' When applied to a `survey_collection`, `distinct()` is dispatched to each
#' member independently — there is no cross-survey deduplication. Two
#' members that share a literally identical row will both retain that row
#' in their post-`distinct()` results. This is the V9 contract from the
#' survey-collection spec; collections deliberately avoid the
#' `bind_rows()` analogy here because cross-survey deduplication has no
#' coherent variance interpretation across designs.
#'
#' Each member's `distinct.survey_base` issues
#' `surveycore_warning_physical_subset` independently — N firings on an
#' N-member collection. Capture with `withCallingHandlers()`.
distinct.survey_collection <- function(
  .data,
  ...,
  .keep_all = FALSE,
  .if_missing_var = NULL
) {
  .dispatch_verb_over_collection(
    fn = dplyr::distinct,
    verb_name = "distinct",
    collection = .data,
    ...,
    .keep_all = .keep_all,
    .if_missing_var = .if_missing_var,
    .detect_missing = "pre_check",
    .may_change_groups = FALSE
  )
}


# ── helpers ──────────────────────────────────────────────────────────────────

# Under data-masking, a tidyselect helper evaluates outside a selection
# context: `all_of("x")` returns the constant string "x" (with a tidyselect
# deprecation warning), so every row would share one key. Catch the helper
# at the top level of each argument and point the user to pick().
.distinct_select_helpers <- c(
  "all_of",
  "any_of",
  "contains",
  "ends_with",
  "everything",
  "last_col",
  "matches",
  "num_range",
  "one_of",
  "starts_with",
  "where"
)

.check_distinct_select_helpers <- function(dots) {
  for (quo in dots) {
    expr <- rlang::quo_get_expr(quo)
    if (!rlang::is_call(expr, .distinct_select_helpers)) {
      next
    }
    helper_code <- rlang::expr_deparse(expr)
    cli::cli_abort(
      c(
        "x" = "{.fn distinct} received the selection helper {.code {helper_code}} directly in {.arg ...}.",
        "i" = "{.fn distinct} uses data-masking, so a selection helper outside {.fn dplyr::pick} or {.fn dplyr::across} gives one constant value for every row.",
        "v" = "Wrap the helper in {.fn dplyr::pick}: {.code pick({helper_code})}."
      ),
      class = "surveytidy_error_distinct_select_helper",
      # A fixed call: the collection dispatcher calls the generic as `fn()`
      call = rlang::call2("distinct")
    )
  }
  invisible(TRUE)
}
