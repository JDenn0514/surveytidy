# filter() rejects .by argument with typed error

    Code
      dplyr::filter(d, y1 > 0, .by = "group")
    Condition
      Error in `dplyr::filter()`:
      x `.by` is not supported for survey design objects.
      i Use `group_by()` to add grouping to a survey design.

# filter() rejects a non-logical condition result

    Code
      dplyr::filter(d, y1)
    Condition
      Error in `dplyr::filter()`:
      x Filter condition 1 must be logical, not <numeric>.
      i Condition: `y1`.
      v Add a comparison operator, e.g. `> 0`.

# filter() warns and marks all rows out-of-domain when no rows match

    Code
      invisible(dplyr::filter(d, y1 > 1e+09))
    Condition
      Warning:
      ! filter() produced an empty domain — no rows match the condition.
      i Variance estimation on this domain will fail.

# dplyr_reconstruct() errors when a design variable is removed

    Code
      dplyr::dplyr_reconstruct(data_no_wt, d)
    Condition
      Error in `dplyr_reconstruct_dispatch()`:
      x Required design variable(s) removed: wt.
      i Design variables cannot be removed from a survey object.
      v Use `select()` to hide columns without removing them.

# subset() warning snapshot matches expected message

    Code
      invisible(subset(d, y1 > 0))
    Condition
      Warning:
      ! `subset()` physically removes rows from the survey data.
      i This is different from `filter()`, which preserves all rows for correct variance estimation.
      v Use `filter()` for subpopulation analyses instead.

# subset() errors when condition matches 0 rows

    Code
      subset(d, y1 > 1e+09)
    Condition
      Warning:
      ! `subset()` physically removes rows from the survey data.
      i This is different from `filter()`, which preserves all rows for correct variance estimation.
      v Use `filter()` for subpopulation analyses instead.
      Error in `subset()`:
      x subset() condition matched 0 rows.
      i Survey objects require at least 1 row.
      v Use `filter()` for domain estimation (keeps all rows).

