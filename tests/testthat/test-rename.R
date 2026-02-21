# tests/testthat/test-rename.R
#
# Behavioral tests for rename().
# Every test that returns a survey object calls test_invariants().

# ── rename() — happy path ─────────────────────────────────────────────────────

test_that("rename() returns the same survey class for all design types", {
  designs <- make_all_designs()
  for (nm in names(designs)) {
    d      <- designs[[nm]]
    result <- rename(d, outcome1 = y1)
    expect_true(
      inherits(result, class(d)[[1L]]),
      label = paste0(nm, ": class preserved")
    )
    test_invariants(result)
  }
})

test_that("rename() renames the column in @data", {
  d      <- make_all_designs()$taylor
  result <- rename(d, outcome1 = y1)
  expect_true("outcome1" %in% names(result@data))
  expect_false("y1" %in% names(result@data))
  test_invariants(result)
})

test_that("rename() preserves all other columns unchanged", {
  d       <- make_all_designs()$taylor
  result  <- rename(d, outcome1 = y1)
  other_cols <- setdiff(names(d@data), "y1")
  for (col in other_cols) {
    expect_true(col %in% names(result@data),
                label = paste0("'", col, "' still present"))
  }
  test_invariants(result)
})

test_that("rename() passes @groups through unchanged", {
  d      <- make_all_designs()$taylor
  d2     <- group_by(d, group)
  result <- rename(d2, outcome1 = y1)
  expect_identical(result@groups, d2@groups)
  test_invariants(result)
})

# ── rename() — visible_vars update ───────────────────────────────────────────

test_that("rename() updates visible_vars when renaming a visible column", {
  d  <- make_all_designs()$taylor
  d2 <- select(d, y1, y2)            # visible_vars = c("y1", "y2")
  d3 <- rename(d2, outcome1 = y1)
  expect_identical(d3@variables$visible_vars, c("outcome1", "y2"))
  test_invariants(d3)
})

test_that("rename() leaves visible_vars NULL unchanged when NULL", {
  d      <- make_all_designs()$taylor
  expect_null(d@variables$visible_vars)
  result <- rename(d, outcome1 = y1)
  expect_null(result@variables$visible_vars)
  test_invariants(result)
})

# ── rename() — design variable warning and @variables update ──────────────────

test_that("rename() warns when renaming a design variable", {
  d <- make_all_designs()$taylor
  expect_warning(
    result <- rename(d, weight = wt),
    class = "surveytidy_warning_rename_design_var"
  )
  expect_snapshot({
    invisible(rename(d, weight = wt))
  })
  test_invariants(result)
})

test_that("rename() updates @variables$weights after renaming the weight column", {
  d  <- make_all_designs()$taylor
  d2 <- suppressWarnings(rename(d, weight = wt))
  expect_identical(d2@variables$weights, "weight")
  expect_false("wt" %in% names(d2@data))
  test_invariants(d2)
})

test_that("rename() updates @variables$strata after renaming the strata column", {
  d  <- make_all_designs()$taylor
  d2 <- suppressWarnings(rename(d, stratum = strata))
  expect_identical(d2@variables$strata, "stratum")
  test_invariants(d2)
})

# ── rename() — three-way combined test (spec Section 3.7) ───────────────────

test_that("rename() handles design var + visible_vars simultaneously", {
  d  <- make_all_designs()$taylor
  d2 <- select(d, y1, wt)                  # visible_vars = c("y1", "wt")
  d3 <- suppressWarnings(rename(d2, weight = wt))

  # 1. @data has "weight", not "wt"
  expect_true("weight" %in% names(d3@data))
  expect_false("wt" %in% names(d3@data))

  # 2. @variables$weights updated
  expect_identical(d3@variables$weights, "weight")

  # 3. visible_vars updated
  expect_identical(d3@variables$visible_vars, c("y1", "weight"))

  test_invariants(d3)
})

# ── rename() — @metadata key update ──────────────────────────────────────────

test_that("rename() updates @metadata variable_labels key", {
  d  <- make_all_designs()$taylor
  d  <- surveycore::set_var_label(d, y1, "Outcome 1")
  d2 <- rename(d, outcome1 = y1)
  expect_null(d2@metadata@variable_labels[["y1"]])
  expect_identical(d2@metadata@variable_labels[["outcome1"]], "Outcome 1")
  test_invariants(d2)
})

test_that("rename() does not affect @metadata for non-renamed columns", {
  d  <- make_all_designs()$taylor
  d  <- surveycore::set_var_label(d, y2, "Outcome 2")
  d2 <- rename(d, outcome1 = y1)
  expect_identical(d2@metadata@variable_labels[["y2"]], "Outcome 2")
  test_invariants(d2)
})

# ── rename() — domain column ──────────────────────────────────────────────────

test_that("rename() does not alter the domain column", {
  d  <- make_all_designs()$taylor
  d2 <- filter(d, y1 > 0)
  d3 <- rename(d2, outcome1 = y1)
  expect_true(surveycore::SURVEYCORE_DOMAIN_COL %in% names(d3@data))
  expect_identical(
    d3@data[[surveycore::SURVEYCORE_DOMAIN_COL]],
    d2@data[[surveycore::SURVEYCORE_DOMAIN_COL]]
  )
  test_invariants(d3)
})
