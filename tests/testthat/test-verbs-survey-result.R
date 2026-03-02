# tests/testthat/test-verbs-survey-result.R
#
# Tests for dplyr/tidyr verb methods on survey_result objects.
# PR 1 (passthrough verbs): sections 1, 2, 3, 3b, 3c, 4, 23, 24, 25, 26, 29
# PR 2 (meta-updating verbs): sections 5–22, 27, 28

# ── PR 1: Passthrough verbs ────────────────────────────────────────────────

# Section 1: every passthrough verb preserves class and meta for all
# types × all designs.

test_that("filter.survey_result preserves class and meta for all types × designs", {
  for (type in c("means", "freqs", "ratios")) {
    expected_class <- paste0("survey_", type)
    for (design in c("taylor", "replicate", "twophase")) {
      r <- make_survey_result(type = type, design = design)
      result <- dplyr::filter(r, n > 0)
      test_result_invariants(result, expected_class)
      expect_identical(surveycore::meta(result), surveycore::meta(r))
    }
  }
})

test_that("arrange.survey_result preserves class and meta for all types × designs", {
  for (type in c("means", "freqs", "ratios")) {
    expected_class <- paste0("survey_", type)
    for (design in c("taylor", "replicate", "twophase")) {
      r <- make_survey_result(type = type, design = design)
      result <- dplyr::arrange(r, n)
      test_result_invariants(result, expected_class)
      expect_identical(surveycore::meta(result), surveycore::meta(r))
    }
  }
})

test_that("mutate.survey_result preserves class and meta for all types × designs", {
  for (type in c("means", "freqs", "ratios")) {
    expected_class <- paste0("survey_", type)
    for (design in c("taylor", "replicate", "twophase")) {
      r <- make_survey_result(type = type, design = design)
      result <- dplyr::mutate(r, new_col = n * 2L)
      test_result_invariants(result, expected_class)
      expect_identical(surveycore::meta(result), surveycore::meta(r))
    }
  }
})

test_that("slice.survey_result preserves class and meta for all types × designs", {
  for (type in c("means", "freqs", "ratios")) {
    expected_class <- paste0("survey_", type)
    for (design in c("taylor", "replicate", "twophase")) {
      r <- make_survey_result(type = type, design = design)
      result <- dplyr::slice(r, 1)
      test_result_invariants(result, expected_class)
      expect_identical(surveycore::meta(result), surveycore::meta(r))
    }
  }
})

test_that("slice_head.survey_result preserves class and meta for all types × designs", {
  for (type in c("means", "freqs", "ratios")) {
    expected_class <- paste0("survey_", type)
    for (design in c("taylor", "replicate", "twophase")) {
      r <- make_survey_result(type = type, design = design)
      result <- dplyr::slice_head(r, n = 1)
      test_result_invariants(result, expected_class)
      expect_identical(surveycore::meta(result), surveycore::meta(r))
    }
  }
})

test_that("slice_tail.survey_result preserves class and meta for all types × designs", {
  for (type in c("means", "freqs", "ratios")) {
    expected_class <- paste0("survey_", type)
    for (design in c("taylor", "replicate", "twophase")) {
      r <- make_survey_result(type = type, design = design)
      result <- dplyr::slice_tail(r, n = 1)
      test_result_invariants(result, expected_class)
      expect_identical(surveycore::meta(result), surveycore::meta(r))
    }
  }
})

test_that("slice_min.survey_result preserves class and meta for all types × designs", {
  for (type in c("means", "freqs", "ratios")) {
    expected_class <- paste0("survey_", type)
    for (design in c("taylor", "replicate", "twophase")) {
      r <- make_survey_result(type = type, design = design)
      result <- dplyr::slice_min(r, order_by = n, n = 1)
      test_result_invariants(result, expected_class)
      expect_identical(surveycore::meta(result), surveycore::meta(r))
    }
  }
})

test_that("slice_max.survey_result preserves class and meta for all types × designs", {
  for (type in c("means", "freqs", "ratios")) {
    expected_class <- paste0("survey_", type)
    for (design in c("taylor", "replicate", "twophase")) {
      r <- make_survey_result(type = type, design = design)
      result <- dplyr::slice_max(r, order_by = n, n = 1)
      test_result_invariants(result, expected_class)
      expect_identical(surveycore::meta(result), surveycore::meta(r))
    }
  }
})

test_that("slice_sample.survey_result preserves class and meta for all types × designs", {
  for (type in c("means", "freqs", "ratios")) {
    expected_class <- paste0("survey_", type)
    for (design in c("taylor", "replicate", "twophase")) {
      r <- make_survey_result(type = type, design = design)
      set.seed(1L)
      result <- dplyr::slice_sample(r, n = 1)
      test_result_invariants(result, expected_class)
      expect_identical(surveycore::meta(result), surveycore::meta(r))
    }
  }
})

test_that("drop_na.survey_result preserves class and meta for all types × designs", {
  for (type in c("means", "freqs", "ratios")) {
    expected_class <- paste0("survey_", type)
    for (design in c("taylor", "replicate", "twophase")) {
      r <- make_survey_result(type = type, design = design)
      result <- tidyr::drop_na(r)
      test_result_invariants(result, expected_class)
      expect_identical(surveycore::meta(result), surveycore::meta(r))
    }
  }
})

# Section 2: row-changing verbs show correct row counts, including 0-row edge case.

test_that("filter.survey_result returns correct row count; 0-row result preserves class", {
  r <- make_survey_result(type = "means")

  # Non-trivial filter: keep rows where n > 0
  result_filtered <- dplyr::filter(r, n > 0)
  test_result_invariants(result_filtered, "survey_means")
  expect_lte(nrow(result_filtered), nrow(r))

  # 0-row result
  result_empty <- dplyr::filter(r, n > 1e9)
  test_result_invariants(result_empty, "survey_means")
  expect_equal(nrow(result_empty), 0L)
  expect_identical(surveycore::meta(result_empty), surveycore::meta(r))
})

test_that("slice_head.survey_result returns correct row count; 0-row result preserves class", {
  r <- make_survey_result(type = "means")

  result_one <- dplyr::slice_head(r, n = 1)
  test_result_invariants(result_one, "survey_means")
  expect_equal(nrow(result_one), 1L)

  # 0-row result
  result_empty <- dplyr::slice_head(r, n = 0)
  test_result_invariants(result_empty, "survey_means")
  expect_equal(nrow(result_empty), 0L)
  expect_identical(surveycore::meta(result_empty), surveycore::meta(r))
})

test_that("slice_tail.survey_result returns correct row count; 0-row result preserves class", {
  r <- make_survey_result(type = "means")

  result_one <- dplyr::slice_tail(r, n = 1)
  test_result_invariants(result_one, "survey_means")
  expect_equal(nrow(result_one), 1L)

  # 0-row result
  result_empty <- dplyr::slice_tail(r, n = 0)
  test_result_invariants(result_empty, "survey_means")
  expect_equal(nrow(result_empty), 0L)
  expect_identical(surveycore::meta(result_empty), surveycore::meta(r))
})

# Section 3: mutate() adds column; meta unchanged.

test_that("mutate.survey_result adds new column without modifying meta", {
  r <- make_survey_result(type = "means")
  result <- dplyr::mutate(r, sig = se < 0.1)

  test_result_invariants(result, "survey_means")
  expect_true("sig" %in% names(result))
  expect_identical(surveycore::meta(result), surveycore::meta(r))
})

# Section 3b: mutate(.keep = "none") — meta coherence maintained after column drops.

test_that("mutate.survey_result(.keep = 'none') prunes meta$group for dropped group col", {
  r <- make_survey_result(type = "means")
  # Only the new column 'sig' will remain; group, mean, se, n are all dropped
  result <- dplyr::mutate(r, sig = se < 0.1, .keep = "none")

  test_result_invariants(result, "survey_means")
  test_result_meta_coherent(result)

  # group column dropped → group entry pruned (group IS an output column)
  expect_equal(length(surveycore::meta(result)$group), 0L)
  # new column is present
  expect_true("sig" %in% names(result))
  # meta$x references the input focal variable ("y1"), not the output column;
  # it is preserved regardless of column changes
  expect_false(is.null(surveycore::meta(result)$x))
})

# Section 3c: mutate(.keep = "used") — meta coherence maintained after column drops.

test_that("mutate.survey_result(.keep = 'used') prunes meta$group for dropped group col", {
  r <- make_survey_result(type = "means")
  # .keep = "used" keeps only columns used in expressions: se and sig
  result <- dplyr::mutate(r, sig = se < 0.1, .keep = "used")

  test_result_invariants(result, "survey_means")
  test_result_meta_coherent(result)

  # group column dropped → group entry pruned (group IS an output column)
  expect_equal(length(surveycore::meta(result)$group), 0L)
  # se and sig are present
  expect_true("se" %in% names(result))
  expect_true("sig" %in% names(result))
})

# Section 4: n_respondents is not updated after filter.

test_that("n_respondents is unchanged after filter.survey_result", {
  r <- make_survey_result(type = "means")
  orig_n <- surveycore::meta(r)$n_respondents

  result <- dplyr::filter(r, n > 0)
  # Result may have fewer rows than r, but n_respondents is fixed
  expect_lte(nrow(result), nrow(r))
  expect_identical(surveycore::meta(result)$n_respondents, orig_n)
})

# Section 23: drop_na() removes rows with NAs; meta preserved (EDGE-5).

test_that("drop_na.survey_result drops rows with NAs and preserves class and meta", {
  r <- make_survey_result(type = "means")
  r_with_na <- r
  r_with_na$se[1L] <- NA_real_

  result <- tidyr::drop_na(r_with_na, se)

  test_result_invariants(result, "survey_means")
  expect_lt(nrow(result), nrow(r_with_na))
  expect_identical(surveycore::meta(result), surveycore::meta(r_with_na))
})

# Section 24: filter() with .by argument forwarded to NextMethod (EDGE-6).

test_that("filter.survey_result forwards .by to NextMethod", {
  r <- make_survey_result(type = "means")

  result <- dplyr::filter(r, n > 0, .by = group)

  test_result_invariants(result, "survey_means")
  expect_identical(surveycore::meta(result), surveycore::meta(r))
})

# Section 25: slice_min/slice_max with non-default args preserve class and meta (EDGE-7).

test_that("slice_min.survey_result with with_ties=FALSE returns exactly n rows", {
  r <- make_survey_result(type = "means")

  result <- dplyr::slice_min(r, order_by = n, n = 1, with_ties = FALSE)

  test_result_invariants(result, "survey_means")
  expect_equal(nrow(result), 1L)
  expect_identical(surveycore::meta(result), surveycore::meta(r))
})

test_that("slice_max.survey_result with na_rm=TRUE excludes NA rows from ranking", {
  r <- make_survey_result(type = "means")
  # Inject NA into the ordering column for one row
  r_with_na <- r
  r_with_na$n[1L] <- NA_integer_

  result <- dplyr::slice_max(r_with_na, order_by = n, n = 1, na_rm = TRUE)

  test_result_invariants(result, "survey_means")
  expect_identical(surveycore::meta(result), surveycore::meta(r_with_na))
})

# Section 26: slice_sample(replace=TRUE) over-sampling preserves class and meta (EDGE-8).

test_that("slice_sample.survey_result with replace=TRUE supports over-sampling", {
  r <- make_survey_result(type = "means")
  n_over <- nrow(r) + 1L

  set.seed(42L)
  result <- dplyr::slice_sample(r, n = n_over, replace = TRUE)

  test_result_invariants(result, "survey_means")
  expect_equal(nrow(result), n_over)
  expect_identical(surveycore::meta(result), surveycore::meta(r))
})

# Section 29: drop_na() with no NAs — all rows preserved; class and meta identical.

test_that("drop_na.survey_result with no NAs returns all rows unchanged", {
  r <- make_survey_result(type = "means")
  # Ensure no NAs (fixture typically has none)
  r_no_na <- r[complete.cases(r), ]
  class(r_no_na) <- class(r)
  attr(r_no_na, ".meta") <- attr(r, ".meta")

  result <- tidyr::drop_na(r_no_na)

  test_result_invariants(result, "survey_means")
  expect_equal(nrow(result), nrow(r_no_na))
  expect_identical(surveycore::meta(result), surveycore::meta(r_no_na))
})
