# R/drop-na.R
#
# drop_na() for survey design objects.
#
# drop_na() marks rows where the specified columns contain NA as out-of-domain,
# without removing them. This is equivalent to filter(!is.na(col1), !is.na(col2), ...)
# and gives correct variance estimates for downstream regression analyses.
#
# Dispatch wiring: registered in .onLoad() via registerS3method().
# See R/zzz.R for the registration calls.

# ── drop_na() ─────────────────────────────────────────────────────────────────

#' Mark rows with missing values as out-of-domain in a survey design object
#'
#' @description
#' Marks rows where the specified columns contain `NA` as out-of-domain,
#' without removing them. If no columns are specified, any `NA` in any column
#' marks the row out-of-domain.
#'
#' This is equivalent to `filter(!is.na(col1), !is.na(col2), ...)` and gives
#' correct variance estimates for downstream analyses. Successive `drop_na()`
#' calls AND their conditions together.
#'
#' @param data A survey design object.
#' @param ... <[`tidy-select`][tidyselect::language]> Columns to inspect for
#'   `NA`. If empty, all columns are checked.
#'
#' @return The survey object with rows containing `NA` in the selected columns
#'   marked out-of-domain. Row count is **unchanged**.
#'
#' @examples
#' library(tidyr)
#' df <- data.frame(y = c(rnorm(99), NA), wt = runif(100, 1, 5))
#' d  <- surveycore::as_survey(df, weights = wt)
#'
#' # Mark rows with NA in y as out-of-domain
#' d2 <- drop_na(d, y)
#' nrow(d2@data)  # still 100
#' d2@data[[surveycore::SURVEYCORE_DOMAIN_COL]]  # FALSE for the last row
#'
#' @family row operations
#' @seealso [filter()] for domain-aware row marking
drop_na.survey_base <- function(data, ...) {
  # Resolve which columns to check for NA
  if (...length() == 0L) {
    target_cols <- names(data@data)
  } else {
    pos <- tidyselect::eval_select(rlang::expr(c(...)), data@data)
    target_cols <- names(pos)
  }

  # Build !is.na() mask for selected columns, ANDed together
  domain_mask <- !rowSums(is.na(data@data[, target_cols, drop = FALSE])) > 0

  # Chain with existing domain column (same logic as filter())
  domain_col <- surveycore::SURVEYCORE_DOMAIN_COL
  if (domain_col %in% names(data@data)) {
    domain_mask <- data@data[[domain_col]] & domain_mask
  }

  # Warn if empty domain (mirrors filter() behavior — no error)
  if (!any(domain_mask)) {
    cli::cli_warn(
      c(
        "!" = "{.fn drop_na} resulted in an empty domain (0 in-domain rows).",
        "i" = "All rows have {.code NA} in at least one of the selected columns.",
        "v" = paste0(
          "Check the column selection or inspect the data for ",
          "pervasive missingness."
        )
      ),
      class = "surveycore_warning_empty_domain"
    )
  }

  # Store constructed !is.na() quosures in @variables$domain (for introspection)
  na_quos <- lapply(target_cols, function(col) {
    rlang::quo(!is.na(!!rlang::sym(col)))
  })
  data@variables$domain <- c(data@variables$domain, na_quos)

  data@data[[domain_col]] <- domain_mask
  data
}
