# mutate() warns when a design variable is modified by name

    Code
      invisible(mutate(d, wt = wt * 1.1))
    Condition
      Warning:
      ! mutate() modified design variable(s): wt.
      i The survey design has been updated to reflect the new values.
      v Use `update_design()` if you intend to modify design variables. Modifying them via `mutate()` may produce unexpected variance estimates.

