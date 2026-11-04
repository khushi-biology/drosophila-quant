# Nucleus -> image -> embryo summaries.
# Author: Khushi Singh

#' Embryo values: the biological replicates
#'
#' Nuclei are summarised per image, then images per embryo, so that an embryo
#' with many images or many nuclei does not dominate. The embryo is the
#' replicate for all statistics; nuclei and images are technical levels.
#'
#' @param long Output of [make_long()].
#' @param centre `"median"` (default) or `"mean"`.
#' @return A tibble with `readout`, `genotype`, `session`, `embryo`, `value`,
#'   `n_images`, `n_nuclei`.
#' @export
embryo_values <- function(long, centre = c("median", "mean")) {
  centre <- match.arg(centre)
  f <- if (centre == "median") stats::median else mean
  img <- dplyr::summarise(
    dplyr::group_by(long, .data$readout, .data$genotype, .data$session, .data$embryo, .data$image),
    img = f(.data$value), n_nuc = dplyr::n(), .groups = "drop")
  dplyr::summarise(
    dplyr::group_by(img, .data$readout, .data$genotype, .data$session, .data$embryo),
    value = f(.data$img), n_images = dplyr::n(), n_nuclei = sum(.data$n_nuc), .groups = "drop")
}

#' Per-embryo design and QC counts
#'
#' @param nuclei Output of [qc_nuclei()].
#' @return A tibble with images, nuclei, nuclei passing QC, saturated nuclei
#'   and area outliers per embryo.
#' @export
design_table <- function(nuclei) {
  dplyr::summarise(dplyr::group_by(nuclei, .data$genotype, .data$embryo),
    images = dplyr::n_distinct(.data$image), nuclei = dplyr::n(), qc_pass = sum(.data$qc_pass),
    saturated = sum(.data$flag_saturated), area_outlier = sum(.data$flag_area), .groups = "drop")
}

#' Geometric mean
#'
#' @param x Positive numeric vector.
#' @return `exp(mean(log(x)))`.
#' @export
geometric_mean <- function(x) exp(mean(log(x)))

#' Express values relative to the control geometric mean
#'
#' @param d A tibble with `genotype` and `value`, optionally grouped (e.g. by
#'   readout and session) so that each group gets its own reference.
#' @param control Control genotype.
#' @return `d` with a column `rel`.
#' @export
relative_to_control <- function(d, control) {
  dplyr::mutate(d, rel = .data$value / geometric_mean(.data$value[.data$genotype == control]))
}
