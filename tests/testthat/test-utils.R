# Direct unit tests for internal surveycore wrapper helpers in R/utils.R.
#
# `.sc_propagate_or_match()` and `.sc_check_groups_match()` exist to avoid
# `:::` (which raises an "Unexported objects imported by ':::' calls" R CMD
# check NOTE). Each wrapper does two things: looks up the surveycore internal
# via `get(..., envir = asNamespace("surveycore"))` and forwards the call.
# These tests cover both lines by calling the wrapper and asserting its
# return value is identical to a direct call against the surveycore internal.

# ── .sc_propagate_or_match() ─────────────────────────────────────────────────

test_that(".sc_propagate_or_match() forwards to surveycore::.propagate_or_match()", {
  coll <- make_test_collection(seed = 42L)
  member_name <- names(coll@surveys)[[1L]]
  member <- coll@surveys[[1L]]

  wrapper <- .sc_propagate_or_match(
    candidate_groups = member@groups,
    target_groups = coll@groups,
    name = member_name,
    error_class = "surveycore_error_collection_group_conflict"
  )

  direct <- get(".propagate_or_match", envir = asNamespace("surveycore"))(
    candidate_groups = member@groups,
    target_groups = coll@groups,
    name = member_name,
    error_class = "surveycore_error_collection_group_conflict"
  )

  expect_identical(wrapper, direct)
})

# ── .sc_check_groups_match() ─────────────────────────────────────────────────

test_that(".sc_check_groups_match() forwards to surveycore::.check_groups_match()", {
  coll <- make_test_collection(seed = 42L)
  member_name <- names(coll@surveys)[[1L]]
  member <- coll@surveys[[1L]]

  wrapper <- .sc_check_groups_match(
    candidate_groups = member@groups,
    target_groups = coll@groups,
    error_class = "surveycore_error_collection_groups_invariant",
    context = member_name
  )

  direct <- get(".check_groups_match", envir = asNamespace("surveycore"))(
    candidate_groups = member@groups,
    target_groups = coll@groups,
    error_class = "surveycore_error_collection_groups_invariant",
    context = member_name
  )

  expect_identical(wrapper, direct)
})

# ── .formula_rhs_values() ────────────────────────────────────────────────────
# Public-API trigger: recode_values() with the formula interface +
# .factor = TRUE and no `to` arg falls through to the
# `factor_source <- .formula_rhs_values(...)` branch in R/recode-values.R.
# This exercises the formula-iteration path (R/utils.R L335-343) and the
# unique/unlist tail (L343).

test_that("recode_values() formula interface + .factor = TRUE uses formula RHS for levels", {
  designs <- make_all_designs(seed = 42)
  for (d in designs) {
    result <- mutate(
      d,
      y3_f = recode_values(
        y3,
        0L ~ "no",
        1L ~ "yes",
        .factor = TRUE
      )
    )
    test_invariants(result)
    expect_true(is.factor(result@data$y3_f))
    # Levels come from formula RHS values in formula appearance order.
    expect_identical(levels(result@data$y3_f), c("no", "yes"))
  }
})

test_that(".formula_rhs_values() returns NULL when no formulas are supplied", {
  # All non-formula args — `.formula_rhs_values()` filters them out and
  # returns NULL via the early-exit branch (R/utils.R L340-342).
  expect_null(.formula_rhs_values(1, "x", list(2, 3)))
})

# ── .merge_value_labels() ────────────────────────────────────────────────────
# Direct tests for the four branches of the merge helper. Each branch is a
# distinct return statement at the top of the function body.

test_that(".merge_value_labels() returns NULL when both inputs are NULL", {
  expect_null(.merge_value_labels(NULL, NULL))
})

test_that(".merge_value_labels() returns override unchanged when base is NULL", {
  override <- c("Yes" = 1L, "No" = 0L)
  expect_identical(.merge_value_labels(NULL, override), override)
})

test_that(".merge_value_labels() returns base unchanged when override is NULL", {
  base <- c("Yes" = 1L, "No" = 0L)
  expect_identical(.merge_value_labels(base, NULL), base)
})

test_that(".merge_value_labels() merges base + override; override wins on shared values", {
  base <- c("Yes" = 1L, "No" = 0L, "Maybe" = 2L)
  override <- c("Maybe/Other" = 2L, "Missing" = 9L)
  merged <- .merge_value_labels(base, override)
  # Override entry replaces the base "Maybe" = 2L; "Yes" and "No" preserved.
  expect_true("Maybe/Other" %in% names(merged))
  expect_false("Maybe" %in% names(merged))
  expect_true(all(c("Yes", "No", "Missing") %in% names(merged)))
})

# ── .apply_result_rename_map() ──────────────────────────────────────────────
# Direct unit tests for branches that the public rename.survey_result and
# rename_with.survey_result paths cannot reach because their rename maps are
# always sourced from existing tibble columns.

test_that(".apply_result_rename_map() returns the result unchanged for an empty rename map", {
  r <- make_survey_result(type = "means")
  result <- .apply_result_rename_map(r, character(0L))
  expect_identical(result, r)
})

test_that(".apply_result_rename_map() updates meta$numerator$name when in rename map", {
  r <- make_survey_result(type = "ratios")
  num_name <- surveycore::meta(r)$numerator$name
  expect_false(is.null(num_name)) # sanity: ratios fixture has $numerator$name

  # The rename map references `num_name` (an INPUT variable) which is not a
  # column in the result tibble — eval_rename would reject this from the
  # public API. The match() in .apply_result_rename_map() returns NA for
  # non-columns, so the tibble columns are untouched, but the
  # m$numerator$name branch (R/utils.R L495-497) runs.
  rename_map <- stats::setNames("input_num", num_name)
  result <- .apply_result_rename_map(r, rename_map)

  expect_identical(surveycore::meta(result)$numerator$name, "input_num")
  # Tibble columns were not renamed (num_name not present).
  expect_identical(names(result), names(r))
})

test_that(".apply_result_rename_map() updates meta$denominator$name when in rename map", {
  r <- make_survey_result(type = "ratios")
  denom_name <- surveycore::meta(r)$denominator$name
  expect_false(is.null(denom_name))

  rename_map <- stats::setNames("input_denom", denom_name)
  result <- .apply_result_rename_map(r, rename_map)

  expect_identical(surveycore::meta(result)$denominator$name, "input_denom")
  expect_identical(names(result), names(r))
})
