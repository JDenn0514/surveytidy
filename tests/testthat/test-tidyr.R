# tests/testthat/test-tidyr.R
#
# Behavioral tests for drop_na().
# Every test that returns a survey object calls test_invariants().

# ── drop_na() — happy path ────────────────────────────────────────────────────

test_that("drop_na() returns the same survey class for all design types", {
  designs <- make_all_designs()
  for (nm in names(designs)) {
    d <- designs[[nm]]
    # Inject an NA into y1 so drop_na has something to remove
    d@data$y1[[1L]] <- NA_real_
    result <- suppressWarnings(drop_na(d, y1))
    expect_true(
      inherits(result, class(d)[[1L]]),
      label = paste0(nm, ": class preserved")
    )
    test_invariants(result)
  }
})

test_that("drop_na() removes rows with NA in the specified column", {
  d <- make_all_designs()$taylor
  d@data$y1[[1L]] <- NA_real_
  result <- suppressWarnings(drop_na(d, y1))
  expect_equal(nrow(result@data), nrow(d@data) - 1L)
  expect_false(any(is.na(result@data$y1)))
  test_invariants(result)
})

test_that("drop_na() with no column spec removes rows with any NA", {
  d <- make_all_designs()$taylor
  d@data$y1[[1L]] <- NA_real_
  d@data$y2[[2L]] <- NA_real_
  result <- suppressWarnings(drop_na(d))
  expect_false(any(is.na(result@data$y1)))
  expect_false(any(is.na(result@data$y2)))
  test_invariants(result)
})

test_that("drop_na() issues surveycore_warning_physical_subset", {
  d <- make_all_designs()$taylor
  d@data$y1[[1L]] <- NA_real_
  expect_warning(
    drop_na(d, y1),
    class = "surveycore_warning_physical_subset"
  )
})

test_that("drop_na() passes @groups through unchanged", {
  d <- make_all_designs()$taylor
  d2 <- group_by(d, group)
  d2@data$y1[[1L]] <- NA_real_
  result <- suppressWarnings(drop_na(d2, y1))
  expect_identical(result@groups, d2@groups)
  test_invariants(result)
})

test_that("drop_na() passes visible_vars through unchanged", {
  d <- make_all_designs()$taylor
  d2 <- select(d, y1, y2)
  d2@data$y1[[1L]] <- NA_real_
  result <- suppressWarnings(drop_na(d2, y1))
  expect_identical(result@variables$visible_vars, d2@variables$visible_vars)
  test_invariants(result)
})

# ── drop_na() — errors ────────────────────────────────────────────────────────

test_that("drop_na() errors when all rows would be removed", {
  d <- make_all_designs()$taylor
  d@data$y1 <- NA_real_ # all NAs
  expect_error(
    suppressWarnings(drop_na(d, y1)),
    class = "surveytidy_error_subset_empty_result"
  )
  expect_snapshot(
    error = TRUE,
    suppressWarnings(drop_na(d, y1))
  )
})
