# R/05-arrange.R
#
# arrange() and the slice_*() family for survey design objects.
#
# arrange() sorts rows in @data. The domain column moves correctly with the
# rows — it is just another column. No update to @variables$domain quosures
# is needed (they are audit-only; the column is authoritative).
#
# slice_*() functions physically remove rows. They always issue
# surveycore_warning_physical_subset and error on 0-row results. A factory
# function is used to avoid repetition across the six slice variants.
#
# Dispatch wiring: registered in .onLoad() via registerS3method().
# See R/00-zzz.R for the registration calls.
#
# Functions defined here:
#   arrange.survey_base()        — row sorting
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


# ── arrange() ─────────────────────────────────────────────────────────────────

#' Sort rows and physically select rows of a survey design object
#'
#' @description
#' * `arrange()` sorts rows in `@data`. The domain column moves with the rows —
#'   no update to `@variables$domain` is needed. Supports `.by_group = TRUE`
#'   using `@groups` set by [group_by()].
#' * `slice()`, `slice_head()`, `slice_tail()`, `slice_min()`, `slice_max()`,
#'   and `slice_sample()` **physically remove rows** and always issue
#'   `surveycore_warning_physical_subset`. They error if the result would have
#'   0 rows. Prefer [filter()] for subpopulation analyses.
#' * `slice_sample(weight_by = )` additionally warns with
#'   `surveytidy_warning_slice_sample_weight_by` because the `weight_by`
#'   column is independent of the survey design weights.
#'
#' @param .data A survey design object.
#' @param ... For `arrange()`: <[`data-masking`][rlang::args_data_masking]>
#'   variables or expressions to sort by. For `slice_*()`: passed to the
#'   corresponding `dplyr::slice_*()` function.
#' @param .by_group Logical. If `TRUE` and `@groups` is set, rows are sorted
#'   by the grouping variables first, then by `...`.
#'
#' @return The survey object with rows reordered (`arrange()`) or a physical
#'   subset of rows (`slice_*()`).
#'
#' @examples
#' df <- data.frame(y = rnorm(100), wt = runif(100, 1, 5),
#'                  g = sample(c("A","B"), 100, TRUE))
#' d  <- surveycore::as_survey(df, weights = wt)
#'
#' # Sort rows
#' d2 <- arrange(d, y)
#' d3 <- arrange(d, desc(y))
#'
#' # Physical row selection (issues warning)
#' d4 <- suppressWarnings(slice_head(d, n = 20))
#'
#' @family row operations
#' @seealso [filter()] for domain-aware row marking (preferred)
arrange.survey_base <- function(.data, ..., .by_group = FALSE) {
  # When .by_group = TRUE and @groups is non-empty, prepend the group columns
  # to the sort order. dplyr's native .by_group = TRUE would silently do
  # nothing because @data has no grouped_df attribute — groups are stored in
  # @groups on the survey object, not as a data frame attribute.
  if (isTRUE(.by_group) && length(.data@groups) > 0L) {
    new_data <- dplyr::arrange(
      .data@data,
      dplyr::across(dplyr::all_of(.data@groups)),
      ...
    )
  } else {
    new_data <- dplyr::arrange(.data@data, ..., .by_group = .by_group)
  }
  .data@data <- new_data
  .data
}


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
    if (!is.null(check_fn)) check_fn(...)
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

#' @describeIn arrange.survey_base Select rows by position.
slice.survey_base <- .make_slice_method(
  "slice", dplyr::slice
)
#' @describeIn arrange.survey_base Select first `n` rows.
slice_head.survey_base <- .make_slice_method(
  "slice_head", dplyr::slice_head
)
#' @describeIn arrange.survey_base Select last `n` rows.
slice_tail.survey_base <- .make_slice_method(
  "slice_tail", dplyr::slice_tail
)
#' @describeIn arrange.survey_base Select rows with the smallest values.
slice_min.survey_base <- .make_slice_method(
  "slice_min", dplyr::slice_min
)
#' @describeIn arrange.survey_base Select rows with the largest values.
slice_max.survey_base <- .make_slice_method(
  "slice_max", dplyr::slice_max
)
#' @describeIn arrange.survey_base Randomly sample rows.
slice_sample.survey_base <- .make_slice_method(
  "slice_sample", dplyr::slice_sample,
  check_fn = .check_slice_sample_weight_by
)
