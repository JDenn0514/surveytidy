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
#   slice.survey_base()          — row selection by position
#   slice_head.survey_base()     — first n rows
#   slice_tail.survey_base()     — last n rows
#   slice_min.survey_base()      — n rows with lowest values of a variable
#   slice_max.survey_base()      — n rows with highest values of a variable
#   slice_sample.survey_base()   — random sample of rows

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
}

# Factory that produces a slice_*.survey_base function.
#   fn_name:  character; shown in warnings and errors (e.g. "slice_head")
#   dplyr_fn: the corresponding dplyr function (e.g. dplyr::slice_head)
#   check_fn: optional extra check run before slicing (NULL for most variants)
.make_slice_method <- function(fn_name, dplyr_fn, check_fn = NULL) {
  # force() the closure variables so R CMD check understands they are
  # intentional free variables in the returned function, not typos.
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
}

#' Physically select rows of a survey design object
#'
#' @description
#' `slice()`, `slice_head()`, `slice_tail()`, `slice_min()`, `slice_max()`,
#' and `slice_sample()` **physically remove rows** and always issue
#' `surveycore_warning_physical_subset`. They error if the result would have
#' 0 rows. Prefer [filter()] for subpopulation analyses.
#'
#' `slice_sample(weight_by = )` additionally warns with
#' `surveytidy_warning_slice_sample_weight_by` because the `weight_by`
#' column is independent of the survey design weights.
#'
#' @param .data A survey design object.
#' @param ... Passed to the corresponding `dplyr::slice_*()` function.
#'
#' @return A physical subset of the survey object's rows.
#'
#' @examples
#' library(dplyr)
#' df <- data.frame(y = rnorm(100), wt = runif(100, 1, 5))
#' d  <- surveycore::as_survey(df, weights = wt)
#'
#' # Physical row selection (issues warning)
#' d2 <- suppressWarnings(slice_head(d, n = 20))
#'
#' @family row operations
#' @seealso [filter()] for domain-aware row marking (preferred),
#'   [arrange()] for row sorting
slice.survey_base <- .make_slice_method(
  "slice",
  dplyr::slice
)
#' @describeIn slice.survey_base Select first `n` rows.
slice_head.survey_base <- .make_slice_method(
  "slice_head",
  dplyr::slice_head
)
#' @describeIn slice.survey_base Select last `n` rows.
slice_tail.survey_base <- .make_slice_method(
  "slice_tail",
  dplyr::slice_tail
)
#' @describeIn slice.survey_base Select rows with the smallest values.
slice_min.survey_base <- .make_slice_method(
  "slice_min",
  dplyr::slice_min
)
#' @describeIn slice.survey_base Select rows with the largest values.
slice_max.survey_base <- .make_slice_method(
  "slice_max",
  dplyr::slice_max
)
#' @describeIn slice.survey_base Randomly sample rows.
slice_sample.survey_base <- .make_slice_method(
  "slice_sample",
  dplyr::slice_sample,
  check_fn = .check_slice_sample_weight_by
)
