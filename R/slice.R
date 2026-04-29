# R/slice.R
#
# slice_*() family for survey design objects.
#
# slice_*() functions physically remove rows. They always issue
# surveycore_warning_physical_subset and error on 0-row results. A factory
# function is used to avoid repetition across the six slice variants.
#
# Dispatch wiring: registered in .onLoad() via registerS3method().
# See R/zzz.R for the registration calls.
#
# Functions defined here:
#   slice.survey_base()            — row selection by position
#   slice.survey_result()          — class/meta preservation for survey_result
#   slice_head.survey_base()       — first n rows
#   slice_head.survey_result()     — class/meta preservation for survey_result
#   slice_tail.survey_base()       — last n rows
#   slice_tail.survey_result()     — class/meta preservation for survey_result
#   slice_min.survey_base()        — n rows with lowest values of a variable
#   slice_min.survey_result()      — class/meta preservation for survey_result
#   slice_max.survey_base()        — n rows with highest values of a variable
#   slice_max.survey_result()      — class/meta preservation for survey_result
#   slice_sample.survey_base()     — random sample of rows
#   slice_sample.survey_result()   — class/meta preservation for survey_result

# `check_fn` is a free variable in functions created by .make_slice_method().
# R CMD check cannot determine from static analysis that it is always defined
# in the enclosing environment via the factory — suppress the note here.
utils::globalVariables("check_fn")


# ── slice_*() factory ─────────────────────────────────────────────────────────

# Inline helper: warn when slice_sample() is called with weight_by =
# The weight_by column is independent of the survey design weights — it samples
# proportional to arbitrary values, not the probability-weighted design.
# Uses ...names() to detect the weight_by argument without evaluating it
# (weight_by is a tidy-select/NSE argument and evaluating it here would fail).
.check_slice_sample_weight_by <- function(...) {
  # Body runs only via the .make_slice_method() closure (passed as `check_fn`);
  # covr cannot trace closure execution back to source lines. Verified covered
  # by test-arrange.R "slice_sample() with weight_by = issues additional warning".
  # nocov start
  if ("weight_by" %in% ...names()) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "{.fn slice_sample} was called with {.arg weight_by} on a survey ",
          "object."
        ),
        "i" = paste0(
          "The {.arg weight_by} column samples rows proportional to its ",
          "values, independently of the survey design weights."
        ),
        "v" = paste0(
          "If you intend probability-proportional sampling, use the survey ",
          "design weights instead."
        )
      ),
      class = "surveytidy_warning_slice_sample_weight_by"
    )
  }
  # nocov end
}

# Factory that produces a slice_*.survey_base function.
#   fn_name:  character; shown in warnings and errors (e.g. "slice_head")
#   dplyr_fn: the corresponding dplyr function (e.g. dplyr::slice_head)
#   check_fn: optional extra check run before slicing (NULL for most variants)
.make_slice_method <- function(fn_name, dplyr_fn, check_fn = NULL) {
  # force() the closure variables so R CMD check understands they are
  # intentional free variables in the returned function, not typos.
  # The factory body and its returned closure execute under indirection
  # (assigned at top-level, then invoked via dplyr's S3 dispatch); covr
  # cannot trace that execution back to source lines. Verified covered by
  # every slice_*() test in test-arrange.R (including the n=0 error path
  # exercised at lines 191–217).
  # nocov start
  force(fn_name)
  force(dplyr_fn)
  force(check_fn)
  function(.data, ...) {
    .warn_physical_subset(fn_name)
    if (!is.null(check_fn)) {
      check_fn(...)
    }
    new_data <- dplyr_fn(.data@data, ...)
    if (nrow(new_data) == 0L) {
      cli::cli_abort(
        c(
          "x" = "{.fn {fn_name}} produced 0 rows.",
          "i" = "Survey objects require at least 1 row.",
          "v" = "Use {.fn filter} for domain estimation (keeps all rows)."
        ),
        class = "surveytidy_error_subset_empty_result"
      )
    }
    .data@data <- new_data
    .data
  }
  # nocov end
}

#' Physically select rows of a survey design object
#'
#' @description
#' `slice()`, `slice_head()`, `slice_tail()`, `slice_min()`, `slice_max()`,
#' and `slice_sample()` **physically remove rows** from a survey design
#' object. For subpopulation analyses, use [filter()] instead — it marks
#' rows as out-of-domain without removing them, preserving valid variance
#' estimation.
#'
#' All slice functions always issue `surveycore_warning_physical_subset`
#' and error if the result would have 0 rows.
#'
#' @details
#' ## Physical subsetting
#' Unlike [filter()], slice functions actually remove rows. This changes
#' the survey design — unless the design was explicitly built for the
#' subset population, variance estimates may be incorrect.
#'
#' ## `slice_sample()` and survey weights
#' `slice_sample(weight_by = )` samples rows proportional to a column's
#' values, independently of the survey design weights. A
#' `surveytidy_warning_slice_sample_weight_by` warning is issued as a
#' reminder. If you intend probability-proportional sampling, use the
#' design weights directly.
#'
#' @param .data A [`survey_base`][surveycore::survey_base] object, or a
#'   `survey_result` object returned by a surveycore estimation function.
#' @param ... Passed to the corresponding `dplyr::slice_*()` function.
#' @param .by Accepted for interface compatibility; not used by survey methods.
#' @param .preserve Accepted for interface compatibility; not used by survey
#'   methods.
#'
#' @return
#' An object of the same type as `.data` with the following properties:
#'
#' * A subset of rows is retained; unselected rows are permanently removed.
#' * Columns and survey design attributes are unchanged.
#' * Always issues `surveycore_warning_physical_subset`.
#'
#' @examples
#' library(surveytidy)
#' library(surveycore)
#' d <- as_survey(pew_npors_2025, weights = weight, strata = stratum)
#'
#' # First 10 rows (issues a physical subset warning)
#' slice_head(d, n = 10)
#'
#' # Rows with the 5 lowest survey weights
#' slice_min(d, order_by = weight, n = 5)
#'
#' # Random sample of 50 rows
#' slice_sample(d, n = 50)
#'
#' @family row operations
#' @seealso [filter()] for domain-aware row marking (preferred for
#'   subpopulation analyses), [arrange()] for row sorting
#' @name slice
NULL

#' @rdname slice
#' @method slice survey_base
slice.survey_base <- .make_slice_method(
  "slice",
  dplyr::slice
)
#' @rdname slice
#' @method slice_head survey_base
slice_head.survey_base <- .make_slice_method(
  "slice_head",
  dplyr::slice_head
)
#' @rdname slice
#' @method slice_tail survey_base
slice_tail.survey_base <- .make_slice_method(
  "slice_tail",
  dplyr::slice_tail
)
#' @rdname slice
#' @method slice_min survey_base
slice_min.survey_base <- .make_slice_method(
  "slice_min",
  dplyr::slice_min
)
#' @rdname slice
#' @method slice_max survey_base
slice_max.survey_base <- .make_slice_method(
  "slice_max",
  dplyr::slice_max
)
#' @rdname slice
#' @method slice_sample survey_base
slice_sample.survey_base <- .make_slice_method(
  "slice_sample",
  dplyr::slice_sample,
  check_fn = .check_slice_sample_weight_by
)

# ── survey_result passthrough variants ────────────────────────────────────────

#' @rdname slice
#' @method slice survey_result
slice.survey_result <- function(.data, ...) {
  old_class <- class(.data)
  old_meta <- attr(.data, ".meta")
  NextMethod() |> .restore_survey_result(old_class, old_meta)
}

#' @rdname slice
#' @method slice_head survey_result
slice_head.survey_result <- function(.data, ...) {
  old_class <- class(.data)
  old_meta <- attr(.data, ".meta")
  NextMethod() |> .restore_survey_result(old_class, old_meta)
}

#' @rdname slice
#' @method slice_tail survey_result
slice_tail.survey_result <- function(.data, ...) {
  old_class <- class(.data)
  old_meta <- attr(.data, ".meta")
  NextMethod() |> .restore_survey_result(old_class, old_meta)
}

#' @rdname slice
#' @method slice_min survey_result
slice_min.survey_result <- function(.data, ...) {
  old_class <- class(.data)
  old_meta <- attr(.data, ".meta")
  NextMethod() |> .restore_survey_result(old_class, old_meta)
}

#' @rdname slice
#' @method slice_max survey_result
slice_max.survey_result <- function(.data, ...) {
  old_class <- class(.data)
  old_meta <- attr(.data, ".meta")
  NextMethod() |> .restore_survey_result(old_class, old_meta)
}

#' @rdname slice
#' @method slice_sample survey_result
slice_sample.survey_result <- function(.data, ...) {
  old_class <- class(.data)
  old_meta <- attr(.data, ".meta")
  NextMethod() |> .restore_survey_result(old_class, old_meta)
}
