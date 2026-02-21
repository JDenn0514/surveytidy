# R/01-filter.R
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
# See R/00-zzz.R for the registration.
#
# Functions defined here:
#   filter.survey_base()   — domain estimation (all verbs route here)
#   subset.survey_base()   — physical row removal (with warning)
#
# Note: dplyr_reconstruct.survey_base() was moved to R/utils.R on
# feature/select so it is co-located with the other multi-verb helpers.


# ── filter() ─────────────────────────────────────────────────────────────────

# Domain estimation: marks rows matching the condition as in-domain.
# nrow(@data) is UNCHANGED. Variance estimation uses all rows.
# Registered in .onLoad() — see R/00-zzz.R.
#' @noRd
filter.survey_base <- function(.data, ..., .by = NULL, .preserve = FALSE) {
  if (!is.null(.by)) {
    cli::cli_abort(
      c(
        "x" = "{.arg .by} is not supported for survey design objects.",
        "i" = "Use {.fn group_by} to add grouping to a survey design."
      ),
      class = "surveycore_error_filter_by_unsupported"
    )
  }

  # Evaluate filter conditions against @data.
  # Quosures already capture the user's environment — no need to pass env.
  conditions <- rlang::quos(...)

  if (length(conditions) == 0L) {
    # No conditions — trivial domain (all rows in-domain)
    domain_mask <- rep(TRUE, nrow(.data@data))
  } else {
    evaluated <- vector("list", length(conditions))
    for (i in seq_along(conditions)) {
      q      <- conditions[[i]]
      result <- rlang::eval_tidy(q, data = .data@data)
      if (!is.logical(result)) {
        the_class <- class(result)[[1L]]
        cli::cli_abort(
          c(
            "x" = "Filter condition {i} must be logical, not {.cls {the_class}}.",
            "i" = "Condition: {.code {rlang::quo_text(q)}}.",
            "v" = "Add a comparison operator, e.g. {.code > 0}."
          ),
          class = "surveytidy_error_filter_non_logical"
        )
      }
      # NA conditions map to FALSE (outside domain)
      result[is.na(result)] <- FALSE
      evaluated[[i]] <- result
    }
    domain_mask <- Reduce(`&`, evaluated)
  }

  # AND with existing domain column if present (chained filters)
  domain_col <- surveycore::SURVEYCORE_DOMAIN_COL
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
  .data@data[[domain_col]]  <- domain_mask
  .data@variables$domain    <- c(.data@variables$domain, conditions)
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
#' @export
subset.survey_base <- function(x, condition, ...) {
  .warn_physical_subset("subset")

  cond_quo  <- rlang::enquo(condition)
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
