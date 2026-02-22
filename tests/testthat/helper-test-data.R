# tests/testthat/helper-test-data.R
#
# Test infrastructure for surveytidy.
# Loaded automatically by testthat before any test file runs.
#
# Re-uses make_survey_data() and test_invariants() from surveycore via the
# package's helper infrastructure. make_all_designs() is imported from
# surveycore's own helper (available after surveycore is loaded).
#
# Additional surveytidy-specific helpers:
#   - The surveycore helpers (make_survey_data, test_invariants,
#     make_all_designs) are accessible because surveytidy imports surveycore.

# Source the surveycore test helper to get make_survey_data, test_invariants,
# and make_all_designs. These functions live in surveytidy's test environment
# after devtools::load_all() + devtools::test().
#
# Note: When running tests via devtools::test() from the surveytidy project,
# surveycore's helper is NOT automatically loaded. We recreate the necessary
# helpers inline here.

make_survey_data <- function(
  n = 500L,
  n_psu = 50L,
  n_strata = 5L,
  design = c("taylor", "replicate", "twophase"),
  type = "brr",
  with_labels = FALSE,
  seed = 42L
) {
  design <- match.arg(design)
  type <- tolower(type)

  if (type %in% c("brr", "fay") && n_psu %% 2L != 0L) {
    stop(
      "n_psu must be even for BRR/Fay replicate designs. ",
      "Got n_psu = ",
      n_psu,
      "."
    )
  }

  set.seed(seed)

  psus_per_stratum <- rep(n_psu %/% n_strata, n_strata)
  remainder <- n_psu %% n_strata
  if (remainder > 0L) {
    psus_per_stratum[seq_len(remainder)] <-
      psus_per_stratum[seq_len(remainder)] + 1L
  }
  psu_stratum <- rep(seq_len(n_strata), psus_per_stratum)

  psu_sizes_raw <- sample(5:15, n_psu, replace = TRUE)
  exact <- psu_sizes_raw / sum(psu_sizes_raw) * n
  psu_sizes <- as.integer(floor(exact))
  psu_sizes <- pmax(psu_sizes, 1L)
  remaining <- n - sum(psu_sizes)
  if (remaining > 0L) {
    top_idx <- order(exact - floor(exact), decreasing = TRUE)[seq_len(
      remaining
    )]
    psu_sizes[top_idx] <- psu_sizes[top_idx] + 1L
  }

  psu_index <- rep(seq_len(n_psu), times = psu_sizes)
  strata <- psu_stratum[psu_index]

  stratum_n <- tabulate(strata, nbins = n_strata)
  stratum_pop <- round(stratum_n * runif(n_strata, 8, 15))
  fpc <- stratum_pop[strata]

  base_wt <- stratum_pop / stratum_n
  wt <- base_wt[strata] * exp(rnorm(n, mean = 0, sd = 0.2))

  y1 <- rnorm(n, mean = 50, sd = 10)
  y2 <- rnorm(n, mean = 0, sd = 1)
  y3 <- as.integer(runif(n) < 0.3)
  group <- sample(c("A", "B", "C"), n, replace = TRUE)

  df <- data.frame(
    psu = paste0("psu_", psu_index),
    strata = paste0("stratum_", strata),
    fpc = fpc,
    wt = wt,
    y1 = y1,
    y2 = y2,
    y3 = y3,
    group = group,
    stringsAsFactors = FALSE
  )

  if (design == "replicate") {
    R <- switch(
      type,
      brr = n_psu %/% 2L,
      fay = n_psu %/% 2L,
      jk1 = ,
      jk2 = ,
      jkn = ,
      bootstrap = n_psu,
      n_psu
    )
    repwt_matrix <- matrix(
      wt * exp(matrix(rnorm(n * R, mean = 0, sd = 0.1), nrow = n, ncol = R)),
      nrow = n,
      ncol = R
    )
    repwt_df <- as.data.frame(repwt_matrix)
    names(repwt_df) <- paste0("repwt_", seq_len(R))
    df <- cbind(df, repwt_df)
  }

  if (design == "twophase") {
    df$phase2_ind <- runif(n) < 0.4
  }

  if (with_labels) {
    attr(df$y1, "label") <- "Outcome variable 1 (continuous)"
    attr(df$y2, "label") <- "Outcome variable 2 (continuous)"
    attr(df$y3, "label") <- "Outcome variable 3 (binary, 0/1)"
    attr(df$y3, "labels") <- c("No" = 0L, "Yes" = 1L)
    attr(df$group, "label") <- "Demographic group"
    attr(df$group, "labels") <- c(
      "Group A" = "A",
      "Group B" = "B",
      "Group C" = "C"
    )
    attr(df$wt, "label") <- "Sampling weight"
  }

  df
}

test_invariants <- function(design) {
  testthat::expect_true(is.data.frame(design@data))
  testthat::expect_false(is.null(design@data))
  testthat::expect_gte(nrow(design@data), 1L)
  testthat::expect_false(
    anyDuplicated(names(design@data)) > 0L,
    label = "@data has no duplicate column names"
  )

  if (S7::S7_inherits(design, surveycore::survey_twophase)) {
    p1 <- design@variables$phase1
    p2 <- design@variables$phase2
    design_vars <- c(
      p1$ids,
      p1$weights,
      p1$strata,
      p1$fpc,
      if (!is.null(p2)) c(p2$ids, p2$strata, p2$probs, p2$fpc),
      design@variables$subset
    )
  } else {
    design_vars <- c(
      design@variables$ids,
      design@variables$weights,
      design@variables$strata,
      design@variables$fpc
    )
  }
  design_vars <- design_vars[!is.null(design_vars)]
  for (v in design_vars) {
    testthat::expect_true(
      v %in% names(design@data),
      label = paste0("design var '", v, "' present in @data")
    )
    testthat::expect_true(
      is.atomic(design@data[[v]]),
      label = paste0("design var '", v, "' is atomic")
    )
  }

  wt_var <- if (S7::S7_inherits(design, surveycore::survey_twophase)) {
    design@variables$phase1$weights
  } else {
    design@variables$weights
  }
  if (!is.null(wt_var)) {
    wt_col <- design@data[[wt_var]]
    testthat::expect_true(is.numeric(wt_col))
    testthat::expect_true(all(wt_col[!is.na(wt_col)] > 0))
  }

  if (S7::S7_inherits(design, surveycore::survey_replicate)) {
    for (rw in design@variables$repweights) {
      testthat::expect_true(is.numeric(design@data[[rw]]))
    }
  }

  testthat::expect_true(
    S7::S7_inherits(design@metadata, surveycore::survey_metadata)
  )

  # Invariant 6: every column listed in visible_vars must exist in @data
  vv <- design@variables$visible_vars
  if (!is.null(vv)) {
    bad <- setdiff(vv, names(design@data))
    testthat::expect_true(
      length(bad) == 0L,
      label = paste0(
        "visible_vars contains columns not in @data: ",
        paste(bad, collapse = ", ")
      )
    )
  }

  invisible(design)
}

make_all_designs <- function(seed = 42L) {
  df_t <- make_survey_data(
    n = 100L,
    n_psu = 10L,
    n_strata = 2L,
    design = "taylor",
    seed = seed
  )
  taylor <- surveycore::as_survey(
    df_t,
    ids = psu,
    weights = wt,
    strata = strata,
    fpc = fpc,
    nest = TRUE
  )

  df_r <- make_survey_data(
    n = 100L,
    n_psu = 10L,
    n_strata = 2L,
    design = "replicate",
    type = "brr",
    seed = seed
  )
  repwt_cols <- grep("^repwt_", names(df_r), value = TRUE)
  replicate <- surveycore::as_survey_rep(
    df_r,
    weights = wt,
    repweights = tidyselect::all_of(repwt_cols),
    type = "BRR"
  )

  df_p <- make_survey_data(
    n = 100L,
    n_psu = 10L,
    n_strata = 2L,
    design = "twophase",
    seed = seed
  )
  phase1 <- surveycore::as_survey(
    df_p,
    ids = psu,
    weights = wt,
    strata = strata,
    fpc = fpc,
    nest = TRUE
  )
  twophase <- suppressWarnings(
    surveycore::as_survey_twophase(phase1, subset = phase2_ind)
  )

  list(taylor = taylor, replicate = replicate, twophase = twophase)
}
