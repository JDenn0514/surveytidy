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
