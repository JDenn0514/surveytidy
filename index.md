# surveytidy

surveytidy provides dplyr and tidyr verbs for survey design objects
created with the [surveycore](https://github.com/JDenn0514/surveycore)
package. It makes survey analysis feel natural to tidyverse users:

``` r
library(surveycore)
library(surveytidy)

# Build a survey design
d <- as_survey(nhanes, ids = sdmvpsu, strata = sdmvstra,
               weights = wtmec2yr, nest = TRUE)

# Use familiar dplyr verbs — survey design is preserved automatically
adults <- d |>
  filter(ridageyr >= 18) |>        # domain estimation, not row removal
  select(ridageyr, bmxbmi, riagendr) |>
  group_by(riagendr) |>
  mutate(bmi_centered = bmxbmi - mean(bmxbmi, na.rm = TRUE))
```

## Key idea: `filter()` marks rows, never removes them

The most important statistical feature of surveytidy is that
[`filter()`](https://rdrr.io/r/stats/filter.html) uses **domain
estimation** rather than physical subsetting:

``` r
# This keeps all 9,756 rows — variance estimation stays correct
women <- d |> filter(riagendr == 2)
nrow(women@data)  #> 9756

# This physically removes rows — variance estimates for women would be wrong
wrong <- subset(d, riagendr == 2)  # issues a warning
```

When you call [`filter()`](https://rdrr.io/r/stats/filter.html),
surveytidy writes a logical column `..surveycore_domain..` to the data.
Phase 1 estimation functions read this column to restrict calculations
to the domain while retaining all rows for correct variance estimation.

## Installation

``` r
# install.packages("pak")
pak::pak("JDenn0514/surveycore")  # required first
pak::pak("JDenn0514/surveytidy")
```

## Usage

### Filtering (domain estimation)

``` r
# Single condition
adults <- d |> filter(ridageyr >= 18)

# Chained filters AND the conditions together
adult_women <- d |>
  filter(ridageyr >= 18) |>
  filter(riagendr == 2)

# Equivalent — both produce identical domain columns
adult_women2 <- d |> filter(ridageyr >= 18, riagendr == 2)
```

### Selecting columns

``` r
# Design variables (weights, strata, PSU) are always kept in @data
# even when not selected — they are required for variance estimation
d2 <- select(d, ridageyr, bmxbmi, riagendr)

# Design variables are hidden from print() but still present
print(d2)     # shows ridageyr, bmxbmi, riagendr only
d2@data$wt    # still accessible

# Reorder visible columns
d3 <- relocate(d2, riagendr, .before = ridageyr)
```

### Mutating

``` r
# Add new columns
d |> mutate(bmi_kg_m2 = bmxbmi,
            age_group  = cut(ridageyr, c(0, 18, 40, 65, Inf)))

# Modifying a design variable warns you
d |> mutate(wtmec2yr = wtmec2yr * 0.5)
#> Warning: mutate() modified design variable(s): `wtmec2yr`

# Grouped mutate via group_by()
d |>
  group_by(riagendr) |>
  mutate(bmi_pctile = rank(bmxbmi) / n())
```

### Renaming

``` r
# @variables and @metadata stay in sync automatically
d |> rename(age = ridageyr, bmi = bmxbmi)
```

### Sorting

``` r
# Rows sort; domain column moves with them
d |>
  filter(ridageyr >= 18) |>
  arrange(bmxbmi)

# Sort by group first, then by value
d |>
  group_by(riagendr) |>
  arrange(bmxbmi, .by_group = TRUE)
```

### Grouping

``` r
d2 <- group_by(d, riagendr)         # set groups
d3 <- group_by(d2, ridageyr, .add = TRUE)  # add to groups
d4 <- ungroup(d3, riagendr)         # partial ungroup
d5 <- ungroup(d3)                   # remove all groups
```

### Physical row operations (use sparingly)

``` r
# These physically remove rows and always issue a warning.
# Use filter() instead for subpopulation analyses.
slice_head(d, n = 100)    # first 100 rows
drop_na(d, bmxbmi)        # remove rows with NA in bmxbmi
```

## Relationship to surveycore

surveytidy is an add-on layer. surveycore provides:

- S7 survey design classes (`survey_taylor`, `survey_replicate`,
  `survey_twophase`)
- Constructors
  ([`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.html),
  [`as_survey_rep()`](https://jdenn0514.github.io/surveycore/reference/as_survey_rep.html),
  [`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.html))
- Metadata system (variable labels, value labels, question prefaces)

surveytidy provides the dplyr/tidyr interface on top of those classes.
Phase 1 (in development) will add estimation functions (`get_mean()`,
`get_total()`, etc.) that respect the domain column and `@groups` set by
surveytidy verbs.

## License

GPL-3
