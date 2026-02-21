# rename() warns when renaming a design variable

    Code
      invisible(rename(d, weight = wt))
    Condition
      Warning:
      ! rename() renamed design variable(s): wt.
      i The survey design has been updated to use the new name(s).

