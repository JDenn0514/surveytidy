# tests/testthat/test-filter.R
#
# Behavioral tests for filter.survey_base(), dplyr_reconstruct.survey_base(),
# and subset.survey_base(). All three are defined in R/01-filter.R.
#
# test-wiring.R covers dispatch only (does dplyr route to our method?).
# This file covers what the methods actually do.


# ── filter() — happy path ─────────────────────────────────────────────────────

test_that("filter() passes test_invariants() for all design types", {
  skip_if_not_installed("dplyr")
  designs <- make_all_designs()
  for (nm in names(designs)) {
    result <- dplyr::filter(designs[[nm]], y1 > 0)
    test_invariants(result)
  }
})

test_that("filter() does not remove any rows from @data for all design types", {
  skip_if_not_installed("dplyr")
  designs <- make_all_designs()
  for (nm in names(designs)) {
    result <- dplyr::filter(designs[[nm]], y1 > 0)
    expect_equal(nrow(result@data), nrow(designs[[nm]]@data))
  }
})

test_that("filter() sets domain column to values matching the condition", {
  skip_if_not_installed("dplyr")
  d      <- make_all_designs()$taylor
  result <- dplyr::filter(d, y1 > 0)
  expect_identical(
    result@data[[surveycore::SURVEYCORE_DOMAIN_COL]],
    d@data$y1 > 0
  )
})

test_that("filter() with no conditions sets all rows in-domain", {
  skip_if_not_installed("dplyr")
  d      <- make_all_designs()$taylor
  result <- dplyr::filter(d)
  domain <- result@data[[surveycore::SURVEYCORE_DOMAIN_COL]]
  expect_true(all(domain))
})

test_that("filter() with multiple conditions applies logical AND within one call", {
  skip_if_not_installed("dplyr")
  d        <- make_all_designs()$taylor
  result   <- dplyr::filter(d, y1 > 0, y2 > 0)
  expected <- d@data$y1 > 0 & d@data$y2 > 0
  expect_identical(
    result@data[[surveycore::SURVEYCORE_DOMAIN_COL]],
    expected
  )
})

test_that("chained filter() calls AND the domain columns correctly", {
  skip_if_not_installed("dplyr")
  d        <- make_all_designs()$taylor
  chained  <- d |> dplyr::filter(y1 > 0) |> dplyr::filter(y2 > 0)
  combined <- dplyr::filter(d, y1 > 0, y2 > 0)
  expect_identical(
    chained@data[[surveycore::SURVEYCORE_DOMAIN_COL]],
    combined@data[[surveycore::SURVEYCORE_DOMAIN_COL]]
  )
})

test_that("chained filter() calls accumulate all conditions in @variables$domain", {
  skip_if_not_installed("dplyr")
  d      <- make_all_designs()$taylor
  result <- d |> dplyr::filter(y1 > 0) |> dplyr::filter(y2 > 0)
  expect_length(result@variables$domain, 2L)
})

test_that("filter() maps NA conditions to FALSE (outside domain)", {
  skip_if_not_installed("dplyr")
  d           <- make_all_designs()$taylor
  d@data$y1[1] <- NA_real_
  result      <- dplyr::filter(d, y1 > 0)
  expect_false(result@data[[surveycore::SURVEYCORE_DOMAIN_COL]][[1L]])
})

test_that("filter() preserves @groups", {
  skip_if_not_installed("dplyr")
  d        <- make_all_designs()$taylor
  d@groups <- c("group")
  result   <- dplyr::filter(d, y1 > 0)
  expect_identical(result@groups, c("group"))
})

test_that("filter() preserves @metadata variable labels", {
  skip_if_not_installed("dplyr")
  d <- make_all_designs()$taylor
  d@metadata@variable_labels[["y1"]] <- "Outcome variable 1"
  result <- dplyr::filter(d, y1 > 0)
  expect_identical(result@metadata@variable_labels[["y1"]], "Outcome variable 1")
})


# ── filter() — error paths ────────────────────────────────────────────────────

test_that("filter() rejects .by argument with typed error", {
  skip_if_not_installed("dplyr")
  d <- make_all_designs()$taylor
  expect_error(
    dplyr::filter(d, y1 > 0, .by = "group"),
    class = "surveytidy_error_filter_by_unsupported"
  )
  expect_snapshot(
    error = TRUE,
    dplyr::filter(d, y1 > 0, .by = "group")
  )
})

test_that("filter() rejects a non-logical condition result", {
  skip_if_not_installed("dplyr")
  d <- make_all_designs()$taylor
  # y1 is numeric — missing comparison operator
  expect_error(
    dplyr::filter(d, y1),
    class = "surveytidy_error_filter_non_logical"
  )
  expect_snapshot(
    error = TRUE,
    dplyr::filter(d, y1)
  )
})


# ── filter() — edge cases ─────────────────────────────────────────────────────

test_that("filter() warns and marks all rows out-of-domain when no rows match", {
  skip_if_not_installed("dplyr")
  d <- make_all_designs()$taylor
  expect_warning(
    result <- dplyr::filter(d, y1 > 1e9),
    class = "surveycore_warning_empty_domain"
  )
  expect_false(any(result@data[[surveycore::SURVEYCORE_DOMAIN_COL]]))
  # Snapshot captures the warning message text
  expect_snapshot({
    invisible(dplyr::filter(d, y1 > 1e9))
  })
})


# ── dplyr_reconstruct() ───────────────────────────────────────────────────────

test_that("dplyr_reconstruct() preserves survey class for all design types", {
  skip_if_not_installed("dplyr")
  designs <- make_all_designs()
  for (nm in names(designs)) {
    result <- dplyr::dplyr_reconstruct(designs[[nm]]@data, designs[[nm]])
    expect_true(S7::S7_inherits(result, surveycore::survey_base))
    test_invariants(result)
  }
})

test_that("dplyr_reconstruct() errors when a design variable is removed", {
  skip_if_not_installed("dplyr")
  d             <- make_all_designs()$taylor
  wt_col        <- d@variables$weights
  data_no_wt    <- d@data[, setdiff(names(d@data), wt_col), drop = FALSE]
  expect_error(
    dplyr::dplyr_reconstruct(data_no_wt, d),
    class = "surveycore_error_design_var_removed"
  )
  expect_snapshot(
    error = TRUE,
    dplyr::dplyr_reconstruct(data_no_wt, d)
  )
})


# ── subset() — happy path ─────────────────────────────────────────────────────

test_that("subset() emits surveycore_warning_physical_subset for all design types", {
  designs <- make_all_designs()
  for (nm in names(designs)) {
    expect_warning(
      subset(designs[[nm]], y1 > 0),
      class = "surveycore_warning_physical_subset"
    )
  }
})

test_that("subset() warning snapshot matches expected message", {
  d <- make_all_designs()$taylor
  expect_snapshot({
    invisible(subset(d, y1 > 0))
  })
})

test_that("subset() physically removes non-matching rows from @data", {
  d             <- make_all_designs()$taylor
  expected_rows <- sum(d@data$y1 > 0)
  result        <- suppressWarnings(subset(d, y1 > 0))
  expect_equal(nrow(result@data), expected_rows)
})

test_that("subset() preserves all design variables in @data", {
  d           <- make_all_designs()$taylor
  design_vars <- surveycore::.get_design_vars_flat(d)
  result      <- suppressWarnings(subset(d, y1 > 0))
  for (v in design_vars) {
    expect_true(v %in% names(result@data), label = paste0("'", v, "' in @data"))
  }
})

test_that("subset() result passes test_invariants() for all design types", {
  designs <- make_all_designs()
  for (nm in names(designs)) {
    result <- suppressWarnings(subset(designs[[nm]], y1 > 0))
    test_invariants(result)
  }
})


# ── subset() — error paths ────────────────────────────────────────────────────

test_that("subset() errors when condition matches 0 rows", {
  d <- make_all_designs()$taylor
  # suppressWarnings isolates the error from the physical_subset warning
  expect_error(
    suppressWarnings(subset(d, y1 > 1e9)),
    class = "surveytidy_error_subset_empty_result"
  )
  # Full snapshot captures both warning and error (complete user experience)
  expect_snapshot(
    error = TRUE,
    subset(d, y1 > 1e9)
  )
})
