# R/drop-na.R
#
# drop_na() for survey design objects.
#
# drop_na() physically removes rows where specified columns contain NA.
# Like slice_*(), it always warns (surveycore_warning_physical_subset) and
# errors on 0-row results (surveytidy_error_subset_empty_result).
#
# Dispatch wiring: registered in .onLoad() via registerS3method().
# See R/zzz.R for the registration calls.

# ── drop_na() ─────────────────────────────────────────────────────────────────

#' Remove rows containing missing values from a survey design object
#'
#' @description
#' Physically removes rows where the specified columns contain `NA`. If no
#' columns are specified, any `NA` in any column triggers removal. Always
#' issues `surveycore_warning_physical_subset`. Errors if all rows would be
#' removed.
#'
#' Prefer [filter()] with `!is.na(col)` for subpopulation analyses — it keeps
#' all rows and gives correct variance estimates.
#'
#' @param data A survey design object.
#' @param ... <[`tidy-select`][tidyselect::language]> Columns to inspect for
#'   `NA`. If empty, all columns are checked.
#'
#' @return The survey object with rows containing `NA` in the selected columns
#'   removed.
#'
#' @examples
#' library(tidyr)
#' df <- data.frame(y = c(rnorm(99), NA), wt = runif(100, 1, 5))
#' d  <- surveycore::as_survey(df, weights = wt)
#'
#' # Remove rows with NA in y
#' d2 <- suppressWarnings(drop_na(d, y))
#' nrow(d2@data)  # 99
#'
#' @family row operations
#' @seealso [filter()] for domain-aware row marking (preferred)
drop_na.survey_base <- function(data, ...) {
  .warn_physical_subset("drop_na")

  # Resolve which columns to check for NA
  if (...length() == 0L) {
    # No column spec: any NA in any column triggers removal
    target_cols <- names(data@data)
  } else {
    pos <- tidyselect::eval_select(rlang::expr(c(...)), data@data)
    target_cols <- names(pos)
  }

  keep_mask <- !rowSums(is.na(data@data[, target_cols, drop = FALSE])) > 0

  if (!any(keep_mask)) {
    cli::cli_abort(
      c(
        "x" = "{.fn drop_na} produced 0 rows.",
        "i" = "Survey objects require at least 1 row.",
        "v" = "Use {.fn filter} for domain estimation (keeps all rows)."
      ),
      class = "surveytidy_error_subset_empty_result"
    )
  }

  data@data <- data@data[keep_mask, , drop = FALSE]
  data
}
