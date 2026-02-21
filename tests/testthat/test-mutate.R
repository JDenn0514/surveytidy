# tests/testthat/test-mutate.R
#
# Behavioral tests for mutate().
# Every test that returns a survey object calls test_invariants().

# ── mutate() — happy path ─────────────────────────────────────────────────────

test_that("mutate() returns the same survey class for all design types", {
  designs <- make_all_designs()
  for (nm in names(designs)) {
    d      <- designs[[nm]]
    result <- mutate(d, z = y1 * 2)
    expect_true(
      inherits(result, class(d)[[1L]]),
      label = paste0(nm, ": class preserved")
    )
    test_invariants(result)
  }
})

test_that("mutate() adds the new column to @data", {
  d      <- make_all_designs()$taylor
  result <- mutate(d, z = y1 * 2)
  expect_true("z" %in% names(result@data))
  expect_equal(result@data$z, result@data$y1 * 2)
  test_invariants(result)
})

test_that("mutate() preserves all existing columns", {
  d       <- make_all_designs()$taylor
  result  <- mutate(d, z = y1 + 1)
  original_cols <- names(d@data)
  for (col in original_cols) {
    expect_true(col %in% names(result@data),
                label = paste0("'", col, "' still present"))
  }
  test_invariants(result)
})

test_that("mutate() passes @groups through unchanged", {
  d      <- make_all_designs()$taylor
  d2     <- group_by(d, group)
  result <- mutate(d2, z = y1 * 2)
  expect_identical(result@groups, d2@groups)
  test_invariants(result)
})

# ── mutate() — visible_vars ───────────────────────────────────────────────────

test_that("mutate() adds new column to visible_vars when visible_vars is set", {
  d  <- make_all_designs()$taylor
  d2 <- select(d, y1, y2)           # visible_vars = c("y1", "y2")
  d3 <- mutate(d2, z = y1 * 2)
  expect_true("z" %in% d3@variables$visible_vars)
  expect_true("y1" %in% d3@variables$visible_vars)
  test_invariants(d3)
})

test_that("mutate() does not change visible_vars when it is NULL", {
  d      <- make_all_designs()$taylor
  expect_null(d@variables$visible_vars)
  result <- mutate(d, z = y1 * 2)
  expect_null(result@variables$visible_vars)
  test_invariants(result)
})

# ── mutate() — .keep argument ────────────────────────────────────────────────

test_that("mutate(.keep = 'none') re-attaches design variables", {
  d      <- make_all_designs()$taylor
  result <- mutate(d, z = y1 * 2, .keep = "none")
  # z should be present
  expect_true("z" %in% names(result@data))
  # all design vars should be re-attached
  for (v in surveycore::.get_design_vars_flat(d)) {
    expect_true(v %in% names(result@data),
                label = paste0("design var '", v, "' re-attached after .keep='none'"))
  }
  test_invariants(result)
})

test_that("mutate(.keep = 'none') updates visible_vars to drop removed columns", {
  d  <- make_all_designs()$taylor
  d2 <- select(d, y1, y2)  # visible_vars = c("y1", "y2")
  d3 <- mutate(d2, z = y1 * 2, .keep = "none")
  # y2 was not used in mutation and .keep = "none" drops it
  # visible_vars should reflect what's left
  expect_false("y2" %in% (d3@variables$visible_vars %||% character(0)))
  test_invariants(d3)
})

test_that("mutate(.keep = 'used') re-attaches design variables", {
  d      <- make_all_designs()$taylor
  result <- mutate(d, z = y1 * 2, .keep = "used")
  for (v in surveycore::.get_design_vars_flat(d)) {
    expect_true(v %in% names(result@data),
                label = paste0("design var '", v, "' present with .keep='used'"))
  }
  test_invariants(result)
})

# ── mutate() — design variable warning ───────────────────────────────────────

test_that("mutate() warns when a design variable is modified by name", {
  d <- make_all_designs()$taylor

  expect_warning(
    result <- mutate(d, wt = wt * 1.1),
    class = "surveytidy_warning_mutate_design_var"
  )
  expect_snapshot({
    invisible(mutate(d, wt = wt * 1.1))
  })
  test_invariants(result)
})

test_that("mutate() design variable warning names the modified variable", {
  d <- make_all_designs()$taylor
  expect_warning(
    mutate(d, wt = wt * 1.1),
    regexp = "wt"
  )
})

# ── mutate() — grouped mutate via @groups ─────────────────────────────────────

test_that("group_by() + mutate() computes group means correctly", {
  d  <- make_all_designs()$taylor
  d2 <- group_by(d, group)
  d3 <- mutate(d2, group_mean_y1 = mean(y1))

  # Each row's group_mean_y1 should equal the mean of y1 within its group
  expected <- ave(d@data$y1, d@data$group, FUN = mean)
  expect_equal(d3@data$group_mean_y1, expected, tolerance = 1e-10)
  test_invariants(d3)
})

# ── mutate() — metadata tracking ─────────────────────────────────────────────

test_that("mutate() records transformation expression in @metadata for new columns", {
  d      <- make_all_designs()$taylor
  result <- mutate(d, z = y1 * 2)
  expect_equal(result@metadata@transformations[["z"]], "y1 * 2")
})

test_that("mutate() does not record transformation for columns created by across()", {
  d      <- make_all_designs()$taylor
  result <- mutate(d, across(c(y1, y2), ~ .x * 2))
  # across() names don't appear in mutations list — no entry expected
  # (limitation documented in spec; verify no crash)
  expect_true(is.list(result@metadata@transformations))
  test_invariants(result)
})

# ── mutate() — domain and @groups preservation ───────────────────────────────

test_that("mutate() does not alter the domain column", {
  d  <- make_all_designs()$taylor
  d2 <- filter(d, y1 > 0)
  d3 <- mutate(d2, z = y1 * 2)
  expect_identical(
    d3@data[[surveycore::SURVEYCORE_DOMAIN_COL]],
    d2@data[[surveycore::SURVEYCORE_DOMAIN_COL]]
  )
  test_invariants(d3)
})
