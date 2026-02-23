# R/filter.R
#
# Domain-aware filter() for survey design objects.
#
# filter() MARKS rows as in-domain rather than removing them.
# This is essential for correct variance estimation of subpopulation
# statistics. Removing rows changes the design; marking them does not.
#
# Domain state:
#   - Stored as a logical column "..surveycore_domain.." in @data
#   - Also stored as an accumulated quosure list in @variables$domain
#   - Chained filters AND the domain columns together; conditions accumulate
#   - "domain" key is ABSENT from @variables until first filter() call
#     (formal exception to "all keys always present" rule — see decisions log)
#
# Dispatch wiring: these functions use plain names (filter.survey_base,
# dplyr_reconstruct.survey_base) and are registered in .onLoad() via
# registerS3method() with the namespaced class string
# "surveycore::survey_base". S3 dispatch finds them because the class
# vector for S7 objects includes "surveycore::survey_base".
# See R/zzz.R for the registration.
#
# Functions defined here:
#   filter.survey_base()   — domain estimation (all verbs route here)
#   filter_out()           — domain exclusion (complement of filter)
#   subset.survey_base()   — physical row removal (with warning)
#
# Note: dplyr_reconstruct.survey_base() was moved to R/utils.R on
# feature/select so it is co-located with the other multi-verb helpers.

# ── filter() ─────────────────────────────────────────────────────────────────

#' Filter survey data using domain estimation
#'
#' @description
#' Mark rows as in-domain without removing them. Unlike `base::subset()` or a
#' plain data-frame filter, `filter()` **never removes rows** from the survey
#' object. Instead it writes a logical column `..surveycore_domain..` to
#' `@data`. Variance estimation therefore uses all rows — the full design is
#' intact — while analysis is restricted to the domain.
#'
#' Chained `filter()` calls AND their conditions together:
#' `filter(d, A) |> filter(d, B)` is identical to `filter(d, A, B)`.
#'
#' @param .data A `survey_taylor`, `survey_replicate`, or `survey_twophase`
#'   object created by [surveycore::as_survey()].
#' @param ... <[`data-masking`][rlang::args_data_masking]> Logical conditions
#'   evaluated against `@data`. Multiple conditions are AND-ed together.
#'   `NA` results are treated as `FALSE` (outside domain). Supports dplyr
#'   helpers like [dplyr::if_any()] and [dplyr::if_all()].
#' @param .by Not supported for survey objects. Use [group_by()] instead.
#' @param .preserve Ignored (included for compatibility with the dplyr
#'   generic signature).
#'
#' @return The survey object with an updated `..surveycore_domain..` column in
#'   `@data`. Row count is **unchanged**.
#'
#' @section Domain estimation vs. physical subsetting:
#' `filter()` is the correct tool for subpopulation analyses. Physically
#' removing rows (via `base::subset()`, [subset()], or [slice()]) changes
#' which units contribute to variance estimation and yields incorrect standard
#' errors. See Thomas Lumley's note for details:
#' <https://notstatschat.rbind.io/2021/07/22/subsets-and-subpopulations-in-survey-inference>
#'
#' @examples
#' library(dplyr)
#' df <- data.frame(y = rnorm(100), x = runif(100),
#'                  wt = runif(100, 1, 5), g = sample(c("A","B"), 100, TRUE))
#' d  <- surveycore::as_survey(df, weights = wt)
#'
#' # Single condition
#' d_pos <- filter(d, y > 0)
#'
#' # Multiple conditions (AND-ed)
#' d_sub <- filter(d, y > 0, g == "A")
#'
#' # Chained filters produce the same domain column
#' d_chain <- filter(d, y > 0) |> filter(g == "A")
#' identical(d_sub@data[[surveycore::SURVEYCORE_DOMAIN_COL]],
#'           d_chain@data[[surveycore::SURVEYCORE_DOMAIN_COL]])
#'
#' # Multi-column helpers: if_any() and if_all()
#' df2 <- data.frame(a = c(1,2,NA,4), b = c(NA,2,3,4), wt = rep(1,4))
#' d2  <- surveycore::as_survey(df2, weights = wt)
#' d_any <- filter(d2, if_any(c(a, b), ~ !is.na(.x)))
#' d_all <- filter(d2, if_all(c(a, b), ~ !is.na(.x)))
#'
#' @family filtering
#' @seealso [subset()] for physical row removal (with a warning)
filter.survey_base <- function(.data, ..., .by = NULL, .preserve = FALSE) {
  if (!is.null(.by)) {
    cli::cli_abort(
      c(
        "x" = "{.arg .by} is not supported for survey design objects.",
        "i" = "Use {.fn group_by} to add grouping to a survey design."
      ),
      class = "surveytidy_error_filter_by_unsupported"
    )
  }

  # Capture quosures for accumulation in @variables$domain (done at the end).
  conditions <- rlang::quos(...)

  domain_col <- surveycore::SURVEYCORE_DOMAIN_COL
  n <- nrow(.data@data)

  if (length(conditions) == 0L) {
    # No conditions — trivial domain (all rows in-domain)
    domain_mask <- rep(TRUE, n)
  } else {
    # Evaluate conditions via dplyr::filter() so that dplyr helpers like
    # if_any() and if_all() work. These functions require dplyr's internal
    # data-masking context, which rlang::eval_tidy() alone does not provide.
    #
    # Strategy: attach a sentinel row-ID column, run dplyr::filter(), then
    # use set membership to determine which rows are in-domain.
    row_id_col <- "..surveytidy_filter_id.."
    while (row_id_col %in% names(.data@data)) {
      row_id_col <- paste0(".", row_id_col, ".")
    }
    tmp <- .data@data
    tmp[[row_id_col]] <- seq_len(n)
    kept <- dplyr::filter(tmp, ...)
    domain_mask <- seq_len(n) %in% kept[[row_id_col]]
  }

  # AND with existing domain column if present (chained filters)
  if (domain_col %in% names(.data@data)) {
    domain_mask <- .data@data[[domain_col]] & domain_mask
  }

  # Warn on empty domain
  if (!any(domain_mask)) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "filter() produced an empty domain \u2014 no rows match ",
          "the condition."
        ),
        "i" = "Variance estimation on this domain will fail."
      ),
      class = "surveycore_warning_empty_domain"
    )
  }

  # Store domain column in @data; accumulate condition quosures in @variables
  .data@data[[domain_col]] <- domain_mask
  .data@variables$domain <- c(.data@variables$domain, conditions)
  .data
}


# ── filter_out() ─────────────────────────────────────────────────────────────

#' Exclude rows from a survey domain
#'
#' @description
#' The complement of [filter()]. `filter_out()` marks rows **matching** the
#' condition as out-of-domain while leaving all other rows in-domain. Like
#' [filter()], it **never removes rows** from the survey object.
#'
#' `filter_out(.data, cond)` is equivalent to `filter(.data, !cond)` but
#' reads more naturally when the intent is exclusion.
#'
#' Chained calls accumulate via AND: rows must satisfy all prior in-domain
#' conditions and none of the exclusion conditions to remain in-domain.
#'
#' @param .data A `survey_taylor`, `survey_replicate`, or `survey_twophase`
#'   object created by [surveycore::as_survey()].
#' @param ... <[`data-masking`][rlang::args_data_masking]> Logical conditions
#'   evaluated against `@data`. Rows where **all** conditions are `TRUE` are
#'   marked as out-of-domain. `NA` results are treated as `FALSE`
#'   (the row stays in-domain).
#'
#' @return The survey object with an updated `..surveycore_domain..` column in
#'   `@data`. Row count is **unchanged**.
#'
#' @examples
#' library(dplyr)
#' df <- data.frame(y = rnorm(100), x = runif(100),
#'                  wt = runif(100, 1, 5), g = sample(c("A","B"), 100, TRUE))
#' d <- surveycore::as_survey(df, weights = wt)
#'
#' # Exclude negative y values
#' d_out <- filter_out(d, y < 0)
#'
#' # Equivalent to negating the condition in filter()
#' d_inv <- filter(d, !(y < 0))
#' identical(d_out@data[[surveycore::SURVEYCORE_DOMAIN_COL]],
#'           d_inv@data[[surveycore::SURVEYCORE_DOMAIN_COL]])
#'
#' # Chain with filter() — only x > 0.5 rows that are NOT in group B
#' d_chain <- filter(d, x > 0.5) |> filter_out(g == "B")
#'
#' @family filtering
#' @seealso [filter()] for including rows in the domain
#' @noRd
filter_out.survey_base <- function(.data, ..., .by = NULL, .preserve = FALSE) {
  if (!is.null(.by)) {
    cli::cli_abort(
      c(
        "x" = "{.arg .by} is not supported for survey design objects.",
        "i" = "Use {.fn group_by} to add grouping to a survey design."
      ),
      class = "surveytidy_error_filter_by_unsupported"
    )
  }

  domain_col <- surveycore::SURVEYCORE_DOMAIN_COL
  n <- nrow(.data@data)

  if (...length() == 0L) {
    # No conditions — exclude nothing; all rows remain in-domain
    domain_mask <- rep(TRUE, n)
  } else {
    # Evaluate conditions via dplyr::filter() to support if_any()/if_all().
    # Rows that survive the filter MATCH the exclusion condition, so those
    # are the rows to mark out-of-domain.
    row_id_col <- "..surveytidy_filter_id.."
    while (row_id_col %in% names(.data@data)) {
      row_id_col <- paste0(".", row_id_col, ".")
    }
    tmp <- .data@data
    tmp[[row_id_col]] <- seq_len(n)
    kept <- dplyr::filter(tmp, ...)
    # In-domain = rows NOT matching the exclusion condition
    # (dplyr treats NA conditions as FALSE → those rows are NOT in kept →
    #  they stay in-domain, matching the documented behaviour)
    domain_mask <- !(seq_len(n) %in% kept[[row_id_col]])
  }

  # AND with existing domain column if present (chained calls)
  if (domain_col %in% names(.data@data)) {
    domain_mask <- .data@data[[domain_col]] & domain_mask
  }

  # Warn on empty domain
  if (!any(domain_mask)) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "filter_out() produced an empty domain \u2014 all rows were excluded."
        ),
        "i" = "Variance estimation on this domain will fail."
      ),
      class = "surveycore_warning_empty_domain"
    )
  }

  .data@data[[domain_col]] <- domain_mask
  .data
}


# ── subset() ─────────────────────────────────────────────────────────────────

#' Physically Remove Rows from a Survey Design Object
#'
#' Physically removes rows from the survey data where `condition` evaluates
#' to `FALSE`. Unlike [filter()], this changes the underlying design and can
#' bias variance estimates.
#'
#' For subpopulation analyses, use [filter()] instead. Only use `subset()`
#' when you have explicitly built the survey design for the subset population.
#'
#' @param x A `survey_taylor`, `survey_replicate`, or `survey_twophase` object.
#' @param condition A logical expression evaluated against `x@data`.
#' @param ... Ignored (for compatibility with the base `subset()` signature).
#' @return A survey object of the same class with only matching rows retained.
#' @describeIn filter.survey_base Physically remove rows (use sparingly).
#'   Always issues `surveycore_warning_physical_subset`. Prefer `filter()` for
#'   subpopulation analyses.
#' @param x A survey design object.
#' @param condition A logical expression evaluated against `x@data`.
#' @export
subset.survey_base <- function(x, condition, ...) {
  .warn_physical_subset("subset")

  cond_quo <- rlang::enquo(condition)
  keep_mask <- rlang::eval_tidy(cond_quo, data = x@data)
  keep_mask[is.na(keep_mask)] <- FALSE

  if (!any(keep_mask)) {
    cli::cli_abort(
      c(
        "x" = "subset() condition matched 0 rows.",
        "i" = "Survey objects require at least 1 row.",
        "v" = "Use {.fn filter} for domain estimation (keeps all rows)."
      ),
      class = "surveytidy_error_subset_empty_result"
    )
  }

  x@data <- x@data[keep_mask, , drop = FALSE]
  x
}
