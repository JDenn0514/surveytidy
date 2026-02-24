# R/reexports.R
#
# Re-exports of dplyr and tidyr generics so that library(surveytidy) is
# sufficient — users do not need to separately load dplyr or tidyr to use
# these verbs on survey design objects.
#
# surveytidy registers S3 methods for all of these generics in .onLoad()
# (see R/zzz.R). Re-exporting the generics here makes them available on the
# search path when surveytidy is loaded.
#
# Internal dplyr machinery (dplyr_reconstruct, tidyselect::eval_select) is
# NOT re-exported — those are imported in R/surveytidy-package.R.

# ── dplyr verbs ───────────────────────────────────────────────────────────────

#' @export
dplyr::distinct

#' @export
dplyr::filter

#' @export
dplyr::filter_out

#' @export
dplyr::select

#' @export
dplyr::mutate

#' @export
dplyr::rename

#' @export
dplyr::relocate

#' @export
dplyr::arrange

#' @export
dplyr::group_by

#' @export
dplyr::ungroup

#' @export
dplyr::pull

#' @export
dplyr::glimpse

#' @export
dplyr::slice

#' @export
dplyr::slice_head

#' @export
dplyr::slice_tail

#' @export
dplyr::slice_min

#' @export
dplyr::slice_max

#' @export
dplyr::slice_sample

# ── tidyr verbs ───────────────────────────────────────────────────────────────

#' @export
tidyr::drop_na
