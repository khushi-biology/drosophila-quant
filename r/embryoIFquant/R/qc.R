# Per-nucleus table, quality control and readouts.
# Author: Khushi Singh

#' One row per nucleus with one column per marker
#'
#' @param d Output of [parse_names()].
#' @param channels Named character vector mapping Fiji channels to markers,
#'   e.g. `c(C1 = "H3", C2 = "H3K18la", C3 = "DAPI")`. Always check this
#'   against the image file: cropping in Fiji can drop and renumber channels.
#' @return A wide tibble: identifiers, `area`, one mean-intensity column per
#'   marker and one `max_<marker>` column per marker.
#' @export
to_nuclei <- function(d, channels) {
  miss <- setdiff(unique(d$channel), names(channels))
  if (length(miss)) message("ignoring unmapped channels: ", paste(miss, collapse = ", "))
  d <- dplyr::filter(d, .data$channel %in% names(channels))
  d <- dplyr::mutate(d, marker = unname(channels[.data$channel]))
  chk <- dplyr::filter(dplyr::count(d, .data$file, .data$roi), .data$n != length(channels))
  if (nrow(chk)) stop("ROIs without every channel (first: ", chk$file[1], " ROI", chk$roi[1], ")")
  d <- dplyr::select(d, "file", "genotype", "session", "embryo", "embryo_id", "image", "roi",
                     "area", "marker", "mean", "max")
  d <- tidyr::pivot_wider(d, names_from = "marker", values_from = c("mean", "max"))
  dplyr::rename_with(d, ~ stringr::str_remove(.x, "^mean_"), dplyr::starts_with("mean_"))
}

#' Flag saturated nuclei and area outliers
#'
#' A nucleus fails QC if any channel reaches `saturation`, or if its area lies
#' outside the `area_quantile` range of the whole experiment.
#'
#' @param n Output of [to_nuclei()].
#' @param markers Marker names (the values of `channels`).
#' @param saturation Maximum pixel value treated as saturated (16-bit: 65000).
#' @param area_quantile Lower and upper area quantiles kept.
#' @return `n` with logical columns `flag_saturated`, `flag_area`, `qc_pass`.
#' @export
qc_nuclei <- function(n, markers, saturation = 65000, area_quantile = c(0.005, 0.995)) {
  maxcols <- paste0("max_", markers)
  lim <- stats::quantile(n$area, area_quantile, na.rm = TRUE)
  mx <- do.call(pmax, unname(as.list(n[maxcols])))
  dplyr::mutate(n,
    flag_saturated = mx >= saturation,
    flag_area = .data$area < lim[1] | .data$area > lim[2],
    qc_pass = !.data$flag_saturated & !.data$flag_area)
}

#' Long table of raw channels and within-nucleus ratios
#'
#' @param n Nuclei that passed QC.
#' @param markers Marker names.
#' @param ratios Character vector of `"A / B"` readouts with `A`, `B` marker
#'   names, e.g. `c("H3K18la / H3", "H3K18la / DAPI", "H3 / DAPI")`.
#' @return A tibble with `genotype`, `session`, `embryo`, `image`, `readout`,
#'   `value`; non-finite and non-positive values are removed.
#' @export
make_long <- function(n, markers, ratios = character(0)) {
  raw <- purrr::map_dfr(markers, function(m)
    dplyr::transmute(n, .data$genotype, .data$session, .data$embryo, .data$image,
                     readout = m, value = .data[[m]]))
  rat <- purrr::map_dfr(ratios, function(r) {
    ab <- parse_ratio(r, markers)
    dplyr::transmute(n, .data$genotype, .data$session, .data$embryo, .data$image,
                     readout = r, value = .data[[ab[1]]] / .data[[ab[2]]])
  })
  dplyr::filter(dplyr::bind_rows(raw, rat), is.finite(.data$value), .data$value > 0)
}

parse_ratio <- function(r, markers) {
  ab <- stringr::str_split(r, " / ")[[1]]
  if (length(ab) != 2 || !all(ab %in% markers))
    stop("ratio '", r, "' must be 'A / B' with A and B among: ", paste(markers, collapse = ", "))
  ab
}
