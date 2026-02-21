# R/07-tidyr.R
#
# tidyr verbs for survey design objects.
#
# drop_na() physically removes rows where specified columns contain NA.
# Like slice_*(), it always warns (surveycore_warning_physical_subset) and
# errors on 0-row results (surveytidy_error_subset_empty_result).
#
# Dispatch wiring: registered in .onLoad() via registerS3method().
# See R/00-zzz.R for the registration calls.


# ── drop_na() ─────────────────────────────────────────────────────────────────

#' @noRd
drop_na.survey_base <- function(data, ...) {
  .warn_physical_subset("drop_na")

  # Resolve which columns to check for NA
  if (...length() == 0L) {
    # No column spec: any NA in any column triggers removal
    target_cols <- names(data@data)
  } else {
    pos         <- tidyselect::eval_select(rlang::expr(c(...)), data@data)
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
