# distinct() rejects a bare selection helper in ... (all three designs)

    Code
      distinct(d, tidyselect::all_of("y1"))
    Condition
      Error in `distinct()`:
      x `distinct()` received the selection helper `tidyselect::all_of("y1")` directly in `...`.
      i `distinct()` uses data-masking, so a selection helper outside `dplyr::pick()` or `dplyr::across()` gives one constant value for every row.
      v Wrap the helper in `dplyr::pick()`: `pick(tidyselect::all_of("y1"))`.

---

    Code
      distinct(d, tidyselect::all_of("y1"))
    Condition
      Error in `distinct()`:
      x `distinct()` received the selection helper `tidyselect::all_of("y1")` directly in `...`.
      i `distinct()` uses data-masking, so a selection helper outside `dplyr::pick()` or `dplyr::across()` gives one constant value for every row.
      v Wrap the helper in `dplyr::pick()`: `pick(tidyselect::all_of("y1"))`.

---

    Code
      distinct(d, tidyselect::all_of("y1"))
    Condition
      Error in `distinct()`:
      x `distinct()` received the selection helper `tidyselect::all_of("y1")` directly in `...`.
      i `distinct()` uses data-masking, so a selection helper outside `dplyr::pick()` or `dplyr::across()` gives one constant value for every row.
      v Wrap the helper in `dplyr::pick()`: `pick(tidyselect::all_of("y1"))`.

