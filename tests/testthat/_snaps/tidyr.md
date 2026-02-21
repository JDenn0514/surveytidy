# drop_na() errors when all rows would be removed

    Code
      suppressWarnings(drop_na(d, y1))
    Condition
      Error in `drop_na()`:
      x `drop_na()` produced 0 rows.
      i Survey objects require at least 1 row.
      v Use `filter()` for domain estimation (keeps all rows).

