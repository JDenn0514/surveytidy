# R/utils.R
#
# Internal shared helpers used by 2+ verb files.
# Single-use helpers live at the top of their own source file.


# ── Column protection ─────────────────────────────────────────────────────────

# Returns all column names that must never be removed from @data.
# Used by select(), rename(), mutate(), arrange(), and group_by() to enforce
# design variable protection.
#
# Protected columns are:
#   - All design variable columns (.get_design_vars_flat() from surveycore)
#   - The domain indicator column (SURVEYCORE_DOMAIN_COL), if present
.protected_cols <- function(design) {
  c(
    surveycore::.get_design_vars_flat(design),
    surveycore::SURVEYCORE_DOMAIN_COL
  )
}


# ── Physical subset warning ───────────────────────────────────────────────────

# Issues the standard warning for operations that physically remove rows.
# Used by subset.survey_base() (R/01-filter.R) and slice_*.survey_base()
# (R/05-arrange.R) and drop_na.survey_base() (R/07-tidyr.R).
#
# fn_name: the function name shown in the warning message, e.g. "slice_head"
.warn_physical_subset <- function(fn_name) {
  cli::cli_warn(
    c(
      "!" = "{.fn {fn_name}} physically removes rows from the survey data.",
      "i" = paste0(
        "This is different from {.fn filter}, which preserves all rows ",
        "for correct variance estimation."
      ),
      "v" = "Use {.fn filter} for subpopulation analyses instead."
    ),
    class = "surveycore_warning_physical_subset"
  )
}
