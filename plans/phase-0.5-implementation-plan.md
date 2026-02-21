# Phase 0.5 Implementation Plan: surveytidy dplyr/tidyr Verbs

**Version:** 1.0
**Date:** 2026-02-21
**Status:** Ready for implementation
**Formal Specification:** `plans/phase-0.5-formal-specification.md` (authoritative)

This document is a **companion to the formal specification** — not a replacement.
The formal spec defines *what* to build and *how each verb behaves*. This plan
defines *how to build it*: file skeletons, dispatch setup, helper strategy,
per-branch checklists, and test scaffolding.

**Read the formal spec first. Come back here when you know what you're building.**

---

## 1. What Is Already in Place

`feature/filter` is merged to `main`. These files are complete and stable:

| File | Contents | Status |
|------|----------|--------|
| `R/00-zzz.R` | `.onLoad()` with S3 registrations | Complete; add to it each branch |
| `R/01-filter.R` | `filter.survey_base`, `dplyr_reconstruct.survey_base`, `subset.survey_base` | `dplyr_reconstruct` moves to utils.R on `feature/select` |
| `R/utils.R` | `.protected_cols()`, `.warn_physical_subset()` | Complete; add to it as needed |
| `R/surveytidy-package.R` | Package docs + `@importFrom` stubs | Complete; add stubs each branch |
| `tests/testthat/helper-test-data.R` | `make_survey_data()`, `make_all_designs()`, `test_invariants()` | Needs Invariant 6 added on `feature/select` |
| `tests/testthat/test-filter.R` | 22 behavioral tests + snapshots | Complete |
| `tests/testthat/test-wiring.R` | 9 dispatch-only tests | Complete |

Every new branch builds on this foundation. Do not modify `R/01-filter.R` except
to remove `dplyr_reconstruct.survey_base` during `feature/select`.

---

## 2. File Delivery Map

One row per branch — what to create or modify:

| Branch | Create | Modify |
|--------|--------|--------|
| `feature/select` | `R/02-select.R`, `tests/test-select.R`, `tests/test-pipeline.R` | `R/00-zzz.R`, `R/utils.R`, `R/01-filter.R`, `tests/helper-test-data.R`, `R/surveytidy-package.R` |
| `feature/mutate` | `R/03-mutate.R`, `tests/test-mutate.R` | `R/00-zzz.R`, `R/surveytidy-package.R` |
| `feature/rename` | `R/04-rename.R`, `tests/test-rename.R` | `R/00-zzz.R`, `tests/test-pipeline.R`, `R/surveytidy-package.R` |
| `feature/arrange` | `R/05-arrange.R`, `tests/test-arrange.R` | `R/00-zzz.R`, `R/surveytidy-package.R` |
| `feature/group-by` | `R/06-group-by.R`, `tests/test-group-by.R` | `R/00-zzz.R`, `tests/test-pipeline.R`, `R/surveytidy-package.R` |
| `feature/tidyr` (stretch) | `R/07-tidyr.R`, `tests/test-tidyr.R` | `R/00-zzz.R`, `R/surveytidy-package.R` |

---

## 3. The Dispatch Pattern

Every new verb follows the same three-step registration process.

### Step 1: Write the function

Name it `verb.survey_base`. Use `#' @noRd` (never `@export`). The function is
registered dynamically — `NAMESPACE` never sees it.

```r
#' @noRd
select.survey_base <- function(.data, ...) {
  # implementation
}
```

### Step 2: Add the registration to `.onLoad()`

In `R/00-zzz.R`, add a `registerS3method()` call inside `.onLoad()`. Use the
full namespaced class string `"surveycore::survey_base"` — this is what makes
dispatch work for S7 objects.

```r
.onLoad <- function(libname, pkgname) {
  S7::methods_register()
  ns <- asNamespace(pkgname)

  # filter, dplyr_reconstruct — already registered

  # --- feature/select ---
  registerS3method("select",            "surveycore::survey_base", get("select.survey_base",   envir = ns), envir = asNamespace("dplyr"))
  registerS3method("relocate",          "surveycore::survey_base", get("relocate.survey_base", envir = ns), envir = asNamespace("dplyr"))
  registerS3method("pull",              "surveycore::survey_base", get("pull.survey_base",     envir = ns), envir = asNamespace("dplyr"))
  registerS3method("glimpse",           "surveycore::survey_base", get("glimpse.survey_base",  envir = ns), envir = asNamespace("dplyr"))
  registerS3method("dplyr_reconstruct", "surveycore::survey_base", get("dplyr_reconstruct.survey_base", envir = ns), envir = asNamespace("dplyr"))
}
```

**Which namespace to register to:**

| Verb | Target namespace |
|------|-----------------|
| dplyr verbs: filter, select, mutate, rename, arrange, group_by, ungroup, pull, glimpse, relocate, slice_* | `asNamespace("dplyr")` |
| dplyr internal: dplyr_reconstruct | `asNamespace("dplyr")` |
| tidyr verbs: drop_na | `asNamespace("tidyr")` |
| base R: subset | `baseenv()` (already done; use `S3method(subset, survey_base)` in NAMESPACE for this one) |

### Step 3: Add `@importFrom` stub to `surveytidy-package.R`

Prevents `R CMD check` "not imported from" notes:

```r
# In surveytidy-package.R, add one line per new dplyr/tidyr verb:
#' @importFrom dplyr select relocate pull glimpse
#' @importFrom dplyr mutate
#' @importFrom dplyr rename
#' @importFrom dplyr arrange slice slice_head slice_tail slice_min slice_max slice_sample
#' @importFrom dplyr group_by ungroup
#' @importFrom tidyr drop_na
```

---

## 4. Helper Strategy

### R/utils.R: only when used in 2+ files

All helpers used in a single file stay inline in that file, defined before
their first call site. When a helper earns a second caller, move it to
`R/utils.R` in the same PR.

**Already in `R/utils.R`:**
- `.protected_cols(design)` — used by filter, dplyr_reconstruct, select, mutate, rename
- `.warn_physical_subset(fn_name)` — used by subset, slice_*, drop_na

**Will move to `R/utils.R` on `feature/select`:**
- `dplyr_reconstruct.survey_base` — current location: `R/01-filter.R`

**Will stay inline** (single-file helpers):
- `.check_slice_sample_weight_by(...)` — inline in `R/05-arrange.R`
- `.make_slice_method(fn_name, dplyr_fn, check_fn)` — inline in `R/05-arrange.R`

### tidyselect resolution pattern

Use this pattern everywhere a verb accepts a column selection:

```r
# select(), relocate(), group_by():
user_pos <- tidyselect::eval_select(rlang::expr(c(...)), .data@data)
user_cols <- names(user_pos)

# ungroup() with column args:
pos <- tidyselect::eval_select(rlang::expr(c(...)), x@data)
to_remove <- names(pos)
```

tidyselect handles negative selection (`-col`), helpers (`starts_with()`),
and all edge cases automatically. Do not write manual selection logic.

---

## 5. Pre-Implementation Checks (Each Branch)

Do these before writing any code on a new branch:

```
- [ ] Read formal spec Section for the verb(s) being implemented
- [ ] Read plans/claude-decisions-phase-0.5.md for resolved decisions
- [ ] Read R/01-filter.R as the reference implementation
- [ ] Run devtools::test() — 0 failures on main before branching
- [ ] Run devtools::check() — 0 errors, 0 warnings before branching
```

**Before `feature/select` specifically:**
```
- [ ] Verify surveycore:::.delete_metadata_col() exists:
      loadNamespace("surveycore")
      ls(envir = asNamespace("surveycore"), all.names = TRUE)
  If absent: implement manual deletion and file a surveycore issue.
  The manual fallback: delete across all known slots:
    @metadata@variable_labels[[col]] <- NULL
    @metadata@value_labels[[col]] <- NULL
    @metadata@question_prefaces[[col]] <- NULL
    @metadata@notes[[col]] <- NULL
    @metadata@transformations[[col]] <- NULL
```

---

## 6. Branch: `feature/select`

### 6.1 Files to modify first

**`R/01-filter.R`:** Remove `dplyr_reconstruct.survey_base` from this file.
Move it verbatim to `R/utils.R`.

**`R/utils.R`:** Add `dplyr_reconstruct.survey_base` after existing helpers.
Also update `dplyr_reconstruct` per the formal spec v1.1 — the current
implementation may predate the `visible_vars` cleanup logic in step 2:

```r
#' @noRd
dplyr_reconstruct.survey_base <- function(data, template) {
  missing_vars <- setdiff(
    surveycore::.get_design_vars_flat(template),
    names(data)
  )
  if (length(missing_vars) > 0L) {
    cli::cli_abort(
      c(
        "x" = "Required design variable(s) were removed from the survey object.",
        "i" = "Missing: {.field {missing_vars}}.",
        "v" = "Do not drop design variables with {.fn select} or {.fn mutate}."
      ),
      class = "surveycore_error_design_var_removed"
    )
  }
  # Clean up visible_vars if dplyr removed non-design columns
  if (!is.null(template@variables$visible_vars)) {
    vv <- intersect(template@variables$visible_vars, names(data))
    template@variables$visible_vars <- if (length(vv) == 0L) NULL else vv
  }
  template@data <- data
  template
}
```

**`tests/testthat/helper-test-data.R`:** Add Invariant 6 check at the end of
`test_invariants()`:

```r
# Invariant 6: visible_vars consistency
vv <- design@variables$visible_vars
if (!is.null(vv)) {
  expect_true(
    length(setdiff(vv, names(design@data))) == 0L,
    info = paste("visible_vars contains columns not in @data:",
                 paste(setdiff(vv, names(design@data)), collapse = ", "))
  )
}
```

### 6.2 `R/02-select.R` skeleton

```r
# ============================================================
# select(), relocate(), pull(), glimpse() for survey objects
# Registered in R/00-zzz.R via registerS3method()
# ============================================================

# select.survey_base -------------------------------------------

#' @noRd
select.survey_base <- function(.data, ...) {
  # Step 1: resolve user's selection
  user_pos  <- tidyselect::eval_select(rlang::expr(c(...)), .data@data)
  user_cols <- names(user_pos)

  # Step 2: protected columns already in data
  protected <- intersect(.protected_cols(.data), names(.data@data))

  # Step 3: visible = user selection (all of it, including design vars if explicit)
  visible <- user_cols

  # Step 4: final data columns: user order first, protected appended
  final_cols <- union(user_cols, protected)

  # Step 5: columns to drop (physically remove from @data)
  dropped <- setdiff(names(.data@data), final_cols)

  # Step 6: update @data
  .data@data <- .data@data[, final_cols, drop = FALSE]

  # Step 7: delete metadata for dropped columns
  for (col in dropped) {
    .data <- .delete_metadata_col(.data, col)  # see helper below
  }

  # Step 8: normalise visible_vars
  .data@variables$visible_vars <- if (
    length(visible) == 0L || setequal(visible, final_cols)
  ) NULL else visible

  .data
}

# Internal: delete a column from all @metadata slots
# Replace with surveycore:::.delete_metadata_col() if it exists.
.delete_metadata_col_surveytidy <- function(design, col) {
  design@metadata@variable_labels[[col]]   <- NULL
  design@metadata@value_labels[[col]]      <- NULL
  design@metadata@question_prefaces[[col]] <- NULL
  design@metadata@notes[[col]]             <- NULL
  design@metadata@transformations[[col]]   <- NULL
  design
}

# relocate.survey_base -----------------------------------------

#' @noRd
relocate.survey_base <- function(.data, ..., .before = NULL, .after = NULL) {
  if (!is.null(.data@variables$visible_vars)) {
    # Reorder visible_vars only; @data column order is irrelevant
    vv_df     <- .data@data[, .data@variables$visible_vars, drop = FALSE]
    reordered <- dplyr::relocate(vv_df, ..., .before = .before, .after = .after)
    .data@variables$visible_vars <- names(reordered)
  } else {
    # No visible_vars: reorder @data directly
    .data@data <- dplyr::relocate(.data@data, ..., .before = .before, .after = .after)
  }
  .data
}

# pull.survey_base ---------------------------------------------

#' @noRd
pull.survey_base <- function(.data, var = -1, name = NULL, ...) {
  dplyr::pull(.data@data, var = {{ var }}, name = {{ name }}, ...)
}

# glimpse.survey_base ------------------------------------------

#' @noRd
glimpse.survey_base <- function(x, width = NULL, ...) {
  if (!is.null(x@variables$visible_vars)) {
    dplyr::glimpse(x@data[, x@variables$visible_vars, drop = FALSE], width, ...)
  } else {
    dplyr::glimpse(x@data, width, ...)
  }
  invisible(x)
}
```

### 6.3 Test file skeleton (`tests/testthat/test-select.R`)

```r
# test-select.R — behavioral tests for select(), relocate(), pull(), glimpse()

test_that("select() returns the same survey class for all design types", {
  for (d in make_all_designs()) {
    result <- select(d, y1, y2)
    expect_true(inherits(result, class(d)[1]))
    test_invariants(result)
  }
})

test_that("select() keeps user-selected columns visible", { ... })

test_that("select() always preserves design variables in @data", { ... })

test_that("select() sets visible_vars to user selection", { ... })

test_that("select() normalises visible_vars to NULL for everything()", { ... })

test_that("select() domain column survives — three-part assertion", {
  d2 <- filter(d, y1 > 0)
  d3 <- select(d2, y1, y2)
  expect_true(surveycore::SURVEYCORE_DOMAIN_COL %in% names(d3@data))
  expect_identical(d3@data[[surveycore::SURVEYCORE_DOMAIN_COL]],
                   d2@data[[surveycore::SURVEYCORE_DOMAIN_COL]])
  expect_false(surveycore::SURVEYCORE_DOMAIN_COL %in%
               (d3@variables$visible_vars %||% character(0)))
})

test_that("select() before any filter() — no domain col yet", { ... })

test_that("select() deletes @metadata entries for dropped columns", { ... })

test_that("select() negative selection works", { ... })

test_that("select() with only design variables normalises visible_vars to NULL", { ... })

test_that("select() passes @groups through unchanged", { ... })

test_that("relocate() with visible_vars set reorders visible_vars only", { ... })

test_that("relocate() without visible_vars reorders @data", { ... })

test_that("pull() returns a vector (not a survey object)", { ... })

test_that("pull() works on a design variable", { ... })

test_that("pull() with name = argument works", { ... })

test_that("pull() on non-existent column errors (dplyr's error accepted)", { ... })

test_that("glimpse() with visible_vars set shows only visible columns", { ... })

test_that("glimpse() returns invisible(x)", { ... })
```

### 6.4 `tests/testthat/test-pipeline.R` (first version — tests 1 and 4)

```r
# test-pipeline.R — Integration tests across verb combinations
# Started on feature/select. Extended on feature/rename and feature/group-by.

test_that("pipeline test 1: domain column survives filter() |> select()", {
  # Filter sets domain; select must preserve the domain column
  d <- make_all_designs()$taylor
  d2 <- filter(d, y1 > 0)
  d3 <- select(d2, y1, y2)
  test_invariants(d3)
  expect_true(surveycore::SURVEYCORE_DOMAIN_COL %in% names(d3@data))
  expect_identical(d3@data[[surveycore::SURVEYCORE_DOMAIN_COL]],
                   d2@data[[surveycore::SURVEYCORE_DOMAIN_COL]])
})

test_that("pipeline test 4: chained filter() equals single filter() with AND", {
  d <- make_all_designs()$taylor
  mn <- mean(d@data$y1)
  d_chained <- d |> filter(y1 > mn) |> filter(y2 > 0)
  d_single  <- d  |> filter(y1 > mn, y2 > 0)
  test_invariants(d_chained)
  test_invariants(d_single)
  expect_identical(
    d_chained@data[[surveycore::SURVEYCORE_DOMAIN_COL]],
    d_single@data[[surveycore::SURVEYCORE_DOMAIN_COL]]
  )
})
```

### 6.5 `.onLoad()` additions for `feature/select`

```r
registerS3method("select",    "surveycore::survey_base", get("select.survey_base",    envir = ns), envir = asNamespace("dplyr"))
registerS3method("relocate",  "surveycore::survey_base", get("relocate.survey_base",  envir = ns), envir = asNamespace("dplyr"))
registerS3method("pull",      "surveycore::survey_base", get("pull.survey_base",      envir = ns), envir = asNamespace("dplyr"))
registerS3method("glimpse",   "surveycore::survey_base", get("glimpse.survey_base",   envir = ns), envir = asNamespace("dplyr"))
# Note: dplyr_reconstruct registration already present; update source location only
```

---

## 7. Branch: `feature/mutate`

### 7.1 `R/03-mutate.R` skeleton

Follow the 7-step contract in formal spec Section 3.6 exactly.

```r
#' @noRd
mutate.survey_base <- function(
  .data,
  ...,
  .by    = NULL,
  .keep  = c("all", "used", "unused", "none"),
  .before = NULL,
  .after  = NULL
) {
  .keep <- match.arg(.keep)

  # Step 1: grouped mutate — use @groups when .by is NULL
  effective_by <- if (is.null(.by) && length(.data@groups) > 0L) {
    dplyr::all_of(.data@groups)
  } else {
    .by
  }

  # Step 2: detect design variable modification (name-based)
  # NOTE: across() expressions will NOT trigger this warning — known limitation.
  mutations      <- rlang::quos(...)
  mutated_names  <- names(mutations)
  protected      <- intersect(.protected_cols(.data), names(.data@data))
  changed_design <- intersect(mutated_names, protected)
  if (length(changed_design) > 0L) {
    cli::cli_warn(
      c(
        "!" = "mutate() modified design variable(s): {.field {changed_design}}.",
        "i" = "The survey design has been updated to reflect the new values.",
        "v" = paste0(
          "Use {.fn update_design} if you intend to modify design variables. ",
          "Modifying them via {.fn mutate} may produce unexpected variance estimates."
        )
      ),
      class = "surveytidy_warning_mutate_design_var"
    )
  }

  # Step 3: run mutation
  new_data <- dplyr::mutate(
    .data@data, ...,
    .by = effective_by, .keep = .keep, .before = .before, .after = .after
  )

  # Step 4: re-attach protected columns dropped by .keep
  protected_in_data <- intersect(.protected_cols(.data), names(.data@data))
  missing           <- setdiff(protected_in_data, names(new_data))
  if (length(missing) > 0L) {
    new_data <- cbind(new_data, .data@data[, missing, drop = FALSE])
  }

  # Step 5: update visible_vars
  new_cols <- setdiff(names(new_data), names(.data@data))
  if (!is.null(.data@variables$visible_vars)) {
    vv <- .data@variables$visible_vars
    vv <- intersect(vv, names(new_data))   # remove cols dropped by .keep
    vv <- c(vv, new_cols)                   # add newly created cols
    .data@variables$visible_vars <- if (length(vv) == 0L) NULL else vv
  }

  # Step 6: track new column transformations in @metadata
  for (col in new_cols) {
    q <- mutations[[col]]
    if (!is.null(q)) {
      .data@metadata@transformations[[col]] <- rlang::quo_text(q)
    }
  }

  # Step 7: assign and return
  .data@data <- new_data
  .data
}
```

### 7.2 `.onLoad()` addition

```r
registerS3method("mutate", "surveycore::survey_base", get("mutate.survey_base", envir = ns), envir = asNamespace("dplyr"))
```

### 7.3 Key test cases (beyond the standard checklist)

- `.keep = "none"` — protected cols re-attached; visible_vars updated
- `.keep = "used"` — protected cols re-attached
- Modify a design var by name — warns with `surveytidy_warning_mutate_design_var`
- New col added when visible_vars is set — new col appears in visible_vars
- `group_by(d, g) |> mutate(z = mean(x))` — grouped computation works

---

## 8. Branch: `feature/rename`

### 8.1 Pre-implementation checks

```r
# Verify surveycore internal helpers exist before writing code:
exists(".update_design_var_names", envir = asNamespace("surveycore"))
# Expected: TRUE

exists(".rename_metadata_keys", envir = asNamespace("surveycore"))
# Expected: TRUE

# Inspect signatures:
args(surveycore:::.update_design_var_names)
args(surveycore:::.rename_metadata_keys)
```

If either is absent, stop and file a surveycore issue before proceeding.

### 8.2 `R/04-rename.R` skeleton

Follow formal spec Section 3.7. The rename_map convention used by
`.update_design_var_names()` is `setNames(old_names, new_names)` — double-check
the actual surveycore signature before implementing.

```r
#' @noRd
rename.survey_base <- function(.data, ...) {
  # Step 1: resolve rename map
  map       <- tidyselect::eval_rename(rlang::expr(c(...)), .data@data)
  new_names <- names(map)
  old_names <- names(.data@data)[map]

  # Step 2: warn if renaming design variables
  protected     <- intersect(.protected_cols(.data), names(.data@data))
  is_design     <- old_names %in% protected
  if (any(is_design)) {
    cli::cli_warn(
      c(
        "!" = "rename() renamed design variable(s): {.field {old_names[is_design]}}.",
        "i" = "The survey design has been updated to use the new name(s)."
      ),
      class = "surveytidy_warning_rename_design_var"
    )
  }

  # Step 3: rename columns in @data
  names(.data@data)[match(old_names, names(.data@data))] <- new_names

  # Step 4: update @variables for renamed design variables
  rename_map <- setNames(old_names, new_names)  # new_name -> old_name? verify surveycore signature
  .data <- surveycore:::.update_design_var_names(.data, rename_map)

  # Step 5: update @metadata keys
  for (i in seq_along(old_names)) {
    .data@metadata <- surveycore:::.rename_metadata_keys(
      .data@metadata, old_names[[i]], new_names[[i]]
    )
  }

  # Step 6: update visible_vars
  vv <- .data@variables$visible_vars
  if (!is.null(vv)) {
    for (i in seq_along(old_names)) {
      vv[vv == old_names[[i]]] <- new_names[[i]]
    }
    .data@variables$visible_vars <- vv
  }

  .data
}
```

**Important:** Verify the exact signature of `surveycore:::.update_design_var_names()`
before finalising step 4. The rename_map direction (old→new vs new→old) matters.

### 8.3 `.onLoad()` addition

```r
registerS3method("rename", "surveycore::survey_base", get("rename.survey_base", envir = ns), envir = asNamespace("dplyr"))
```

### 8.4 `test-pipeline.R` additions (tests 2 and 5)

```r
test_that("pipeline test 2: visible_vars survives select() |> mutate() |> rename()", {
  d  <- make_all_designs()$taylor
  d2 <- select(d, y1, y2)                        # visible_vars = c("y1", "y2")
  d3 <- mutate(d2, y3 = y1 * 2)                  # visible_vars = c("y1", "y2", "y3")
  d4 <- rename(d3, y_one = y1)                   # visible_vars = c("y_one", "y2", "y3")
  test_invariants(d4)
  expect_identical(d4@variables$visible_vars, c("y_one", "y2", "y3"))
})

test_that("pipeline test 5: metadata survives select() |> rename() |> mutate()", {
  d  <- make_all_designs()$taylor
  d  <- surveycore::set_var_label(d, y1, "Outcome variable 1")
  d2 <- select(d, y1, y2)
  d3 <- rename(d2, y_one = y1)
  d4 <- mutate(d3, y_sq = y_one^2)
  test_invariants(d4)
  expect_identical(
    surveycore::extract_var_label(d4, y_one),
    "Outcome variable 1"
  )
})
```

---

## 9. Branch: `feature/arrange`

### 9.1 `R/05-arrange.R` skeleton

Two parts: `arrange.survey_base` and the slice factory.

```r
# arrange.survey_base ------------------------------------------

#' @noRd
arrange.survey_base <- function(.data, ..., .by_group = FALSE) {
  if (isTRUE(.by_group) && length(.data@groups) > 0L) {
    new_data <- dplyr::arrange(
      .data@data,
      dplyr::across(dplyr::all_of(.data@groups)),
      ...
    )
  } else {
    new_data <- dplyr::arrange(.data@data, ..., .by_group = .by_group)
  }
  .data@data <- new_data
  .data
}

# slice factory ------------------------------------------------

.check_slice_sample_weight_by <- function(...) {
  if (!is.null(list(...)$weight_by)) {
    cli::cli_warn(
      c(
        "!" = "{.fn slice_sample} was called with {.arg weight_by} on a survey object.",
        "i" = paste0(
          "The {.arg weight_by} column samples rows proportional to its values, ",
          "independently of the survey design weights."
        ),
        "v" = "If you intend probability-proportional sampling, use the survey design weights instead."
      ),
      class = "surveytidy_warning_slice_sample_weight_by"
    )
  }
}

.make_slice_method <- function(fn_name, dplyr_fn, check_fn = NULL) {
  function(.data, ...) {
    .warn_physical_subset(fn_name)
    if (!is.null(check_fn)) check_fn(...)
    new_data <- dplyr_fn(.data@data, ...)
    if (nrow(new_data) == 0L) {
      cli::cli_abort(
        c(
          "x" = "{.fn {fn_name}} produced 0 rows.",
          "i" = "Survey objects require at least 1 row.",
          "v" = "Use {.fn filter} for domain estimation (keeps all rows)."
        ),
        class = "surveytidy_error_subset_empty_result"
      )
    }
    .data@data <- new_data
    .data
  }
}

slice.survey_base        <- .make_slice_method("slice",        dplyr::slice)
slice_head.survey_base   <- .make_slice_method("slice_head",   dplyr::slice_head)
slice_tail.survey_base   <- .make_slice_method("slice_tail",   dplyr::slice_tail)
slice_min.survey_base    <- .make_slice_method("slice_min",    dplyr::slice_min)
slice_max.survey_base    <- .make_slice_method("slice_max",    dplyr::slice_max)
slice_sample.survey_base <- .make_slice_method(
  "slice_sample", dplyr::slice_sample,
  check_fn = .check_slice_sample_weight_by
)
```

### 9.2 `.onLoad()` additions (7 registrations)

```r
registerS3method("arrange",      "surveycore::survey_base", get("arrange.survey_base",      envir = ns), envir = asNamespace("dplyr"))
registerS3method("slice",        "surveycore::survey_base", get("slice.survey_base",        envir = ns), envir = asNamespace("dplyr"))
registerS3method("slice_head",   "surveycore::survey_base", get("slice_head.survey_base",   envir = ns), envir = asNamespace("dplyr"))
registerS3method("slice_tail",   "surveycore::survey_base", get("slice_tail.survey_base",   envir = ns), envir = asNamespace("dplyr"))
registerS3method("slice_min",    "surveycore::survey_base", get("slice_min.survey_base",    envir = ns), envir = asNamespace("dplyr"))
registerS3method("slice_max",    "surveycore::survey_base", get("slice_max.survey_base",    envir = ns), envir = asNamespace("dplyr"))
registerS3method("slice_sample", "surveycore::survey_base", get("slice_sample.survey_base", envir = ns), envir = asNamespace("dplyr"))
```

### 9.3 Key test for arrange() (exact row-association)

From formal spec Section 3.8:

```r
test_that("arrange() keeps domain column row-associated with data rows", {
  d          <- make_all_designs()$taylor
  d2         <- filter(d, y1 > mean(d@data$y1))
  domain_col <- surveycore::SURVEYCORE_DOMAIN_COL

  original_domain <- d2@data[[domain_col]]
  original_y1     <- d2@data[["y1"]]
  d3              <- arrange(d2, y1)

  sorted_order <- order(original_y1)
  expect_identical(d3@data[[domain_col]], original_domain[sorted_order])
})
```

---

## 10. Branch: `feature/group-by`

### 10.1 `R/06-group-by.R` skeleton

```r
# group_by.survey_base -----------------------------------------

#' @noRd
group_by.survey_base <- function(.data, ..., .add = FALSE, .drop = dplyr::group_by_drop_default(.data)) {
  # Delegate to dplyr to resolve column names (handles bare names, computed
  # expressions, tidy-select helpers, future dplyr extensions)
  grouped     <- dplyr::group_by(.data@data, ...)
  group_names <- dplyr::group_vars(grouped)

  if (isTRUE(.add)) {
    .data@groups <- unique(c(.data@groups, group_names))
  } else {
    .data@groups <- group_names
  }

  .data
}

# ungroup.survey_base ------------------------------------------

#' @noRd
ungroup.survey_base <- function(x, ...) {
  if (...length() == 0L) {
    x@groups <- character(0)
  } else {
    pos       <- tidyselect::eval_select(rlang::expr(c(...)), x@data)
    to_remove <- names(pos)
    x@groups  <- setdiff(x@groups, to_remove)
  }
  x
}
```

**Important:** `group_by()` stores group names in `@groups` only. It does NOT
add dplyr's `grouped_df` attribute to `@data`. This is intentional: the
grouping is stored in the survey object, not the raw data frame.

### 10.2 `.onLoad()` additions

```r
registerS3method("group_by", "surveycore::survey_base", get("group_by.survey_base", envir = ns), envir = asNamespace("dplyr"))
registerS3method("ungroup",  "surveycore::survey_base", get("ungroup.survey_base",  envir = ns), envir = asNamespace("dplyr"))
```

### 10.3 `test-pipeline.R` additions (tests 3 and 6)

```r
test_that("pipeline test 3: @groups survives filter() |> select() |> mutate() |> arrange()", {
  d  <- make_all_designs()$taylor
  d2 <- group_by(d, group)
  d3 <- d2 |> filter(y1 > 0) |> select(y1, y2, group) |> mutate(y_sq = y1^2) |> arrange(y1)
  test_invariants(d3)
  expect_identical(d3@groups, "group")
})

test_that("pipeline test 6: full Phase 1 prep — class, invariants, @groups, domain", {
  d  <- make_all_designs()$taylor
  d2 <- d |>
    filter(y1 > 0) |>
    select(y1, y2, group) |>
    group_by(group) |>
    arrange(y1)
  test_invariants(d2)
  expect_true(inherits(d2, "surveycore::survey_taylor"))
  expect_identical(d2@groups, "group")
  expect_true(surveycore::SURVEYCORE_DOMAIN_COL %in% names(d2@data))
})
```

---

## 11. Branch: `feature/tidyr` (Stretch Goal)

Only implement if all feature/group-by quality gates pass with time to spare.

### 11.1 `R/07-tidyr.R` skeleton

```r
#' @noRd
drop_na.survey_base <- function(data, ...) {
  .warn_physical_subset("drop_na")

  # Resolve column specification
  if (...length() == 0L) {
    target_cols <- names(data@data)
  } else {
    pos         <- tidyselect::eval_select(rlang::expr(c(...)), data@data)
    target_cols <- names(pos)
  }

  keep_mask <- !rowSums(is.na(data@data[, target_cols, drop = FALSE])) > 0

  if (!any(keep_mask)) {
    cli::cli_abort(
      c(
        "x" = "{.fn drop_na} produced 0 rows.",
        "i" = "Survey objects require at least 1 row.",
        "v" = "Use {.fn filter} for domain estimation (keeps all rows)."
      ),
      class = "surveytidy_error_subset_empty_result"
    )
  }

  data@data <- data@data[keep_mask, , drop = FALSE]
  data
}
```

### 11.2 `.onLoad()` addition

```r
registerS3method("drop_na", "surveycore::survey_base", get("drop_na.survey_base", envir = ns), envir = asNamespace("tidyr"))
```

---

## 12. Pre-Merge Quality Gates (Every Branch)

Run these in order before opening a PR:

```r
# 1. Tests pass
devtools::test()
# Expected: 0 failures, 0 warnings

# 2. Full check
devtools::check()
# Expected: 0 errors, 0 warnings, ≤2 notes

# 3. Documentation rebuilt
devtools::document()
# Commit NAMESPACE and man/ changes

# 4. Snapshot review
# If any new expect_snapshot() calls exist:
testthat::snapshot_review()
# Review each diff individually before committing

# 5. Coverage (informational on each branch; blocking at Phase 0.5 exit)
covr::package_coverage()
# Target ≥98%; current branch must not drop below 95%
```

**Additionally, verify per-branch:**
- All three design types tested: taylor, replicate, twophase
- `test_invariants(result)` called for every test that returns a survey object
- `@groups` unchanged through verbs that don't manage grouping
- `visible_vars` only modified by the verbs that should modify it
- Changelog entry created at `changelog/phase-0.5/{branch-name}.md`

---

## 13. `surveytidy-package.R` — cumulative `@importFrom` stubs

Add these one branch at a time to prevent "not imported from" notes:

```r
# After feature/select:
#' @importFrom dplyr select relocate pull glimpse

# After feature/mutate:
#' @importFrom dplyr mutate

# After feature/rename:
#' @importFrom dplyr rename

# After feature/arrange:
#' @importFrom dplyr arrange slice slice_head slice_tail slice_min slice_max slice_sample

# After feature/group-by:
#' @importFrom dplyr group_by ungroup

# After feature/tidyr:
#' @importFrom tidyr drop_na
```

---

## 14. Error and Warning Classes — Implementation Checklist

Every new class must have:
- `class =` on the `cli_abort()` or `cli_warn()` call
- `expect_error(class = "...")` or `expect_warning(class = "...")` test
- `expect_snapshot(error = TRUE, ...)` or `expect_snapshot({ invisible(fn(...)) })` test

| Class | Branch | Function | Type |
|-------|--------|----------|------|
| `surveytidy_warning_mutate_design_var` | feature/mutate | `mutate.survey_base` | Warning |
| `surveytidy_warning_rename_design_var` | feature/rename | `rename.survey_base` | Warning |
| `surveytidy_warning_slice_sample_weight_by` | feature/arrange | `slice_sample.survey_base` | Warning |
| `surveytidy_error_subset_empty_result` | already in filter | `subset`, `slice_*`, `drop_na` | Error |
| `surveycore_error_design_var_removed` | already in filter | `dplyr_reconstruct` | Error |

---

## 15. Phase 0.5 Exit Criteria

After `feature/group-by` merges to `main`, verify:

```
Quality gates from formal spec Section 7:

7.1 Build
- [ ] devtools::check() → 0 errors, 0 warnings, ≤2 notes
- [ ] devtools::document() → NAMESPACE and man/ current

7.2 Tests
- [ ] devtools::test() → 0 failures, 0 warnings, 0 skips
- [ ] Line coverage ≥98%
- [ ] test-pipeline.R exists with all 6 integration tests
- [ ] Snapshot files committed and up to date
- [ ] test_invariants() checks Invariant 6 (visible_vars consistency)

7.3 Implementation completeness
- [ ] All Priority 1 verbs: filter, select, relocate, pull, glimpse,
      mutate, rename, arrange, slice (×6), group_by, ungroup
- [ ] All Priority 2 verbs: subset
- [ ] R/utils.R has .protected_cols(), .warn_physical_subset(), dplyr_reconstruct.survey_base()
- [ ] .onLoad() registers all Priority 1 + 2 verbs
- [ ] All 9 error/warning classes have class + snapshot coverage

7.4 Documentation
- [ ] Every exported function has @return and a runnable @examples block
- [ ] mutate() roxygen includes across() limitation note
- [ ] filter() roxygen includes @variables$domain audit-only note

7.5 Version
- [ ] DESCRIPTION version bumped to 0.2.0
- [ ] NEWS.md updated
- [ ] Git tag v0.2.0 on main
```

---

## Appendix: Invariant 6 Violation Debugging

If `test_invariants()` fails on Invariant 6, the `visible_vars` column no
longer exists in `@data`. Common causes:

| Cause | Verb | Fix |
|-------|------|-----|
| select() removed the column | select | Impossible — select() only removes non-protected, non-user-selected cols |
| dplyr_reconstruct() called after dplyr internally removed columns | dplyr_reconstruct | Intersect visible_vars with names(data) in step 2 |
| mutate(.keep = "none") dropped a visible column | mutate | Step 4 re-attaches protected; step 5 intersects visible_vars with new_data |
| Stale visible_vars from a previous verb | Any | Check @groups propagation — every non-managing verb must pass visible_vars through unchanged |

The `dplyr_reconstruct.survey_base()` cleanup in step 2 is the safety net for
complex pipelines. If visible_vars violations occur in integration tests, check
that `dplyr_reconstruct` is correctly intersecting before assigning.
