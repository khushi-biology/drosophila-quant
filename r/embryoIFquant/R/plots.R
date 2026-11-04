# Publication plots: superplots, forest plots and figure export.
# Author: Khushi Singh

#' Compact publication theme
#'
#' @param base_size Base font size in points.
#' @param base_family Font family (e.g. `"Arial"` or `"Times New Roman"`).
#' @return A ggplot2 theme.
#' @export
theme_pub <- function(base_size = 8, base_family = "") {
  ggplot2::theme_classic(base_size = base_size, base_family = base_family) +
    ggplot2::theme(axis.line = ggplot2::element_line(linewidth = 0.3),
                   axis.ticks = ggplot2::element_line(linewidth = 0.3),
                   axis.text = ggplot2::element_text(colour = "black"),
                   legend.position = "none", strip.background = ggplot2::element_blank(),
                   strip.text = ggplot2::element_text(face = "bold"))
}

#' Colour-blind-safe default palette
#'
#' @param genotypes Genotype names; the first is the control and is grey.
#' @return Named character vector of colours.
#' @export
default_palette <- function(genotypes) {
  cols <- c("#4D4D4D", "#E69F00", "#0072B2", "#009E73", "#CC79A7", "#D55E00", "#56B4E9", "#F0E442")
  stats::setNames(rep_len(cols, length(genotypes)), genotypes)
}

#' Superplot of one readout
#'
#' Nuclei are shown as small points, embryos (the replicates) as large circles,
#' with the geometric mean and s.d. of the embryo values. All values are
#' relative to the control geometric mean on a log2 axis.
#'
#' @param long Output of [make_long()].
#' @param emb Output of [embryo_values()].
#' @param readout Readout to plot.
#' @param control Control genotype.
#' @param palette Named colours per genotype; also sets the genotype order.
#' @param eff Optional output of [welch_vs_control()]; if given and
#'   `show_p = TRUE`, P values are printed above each genotype.
#' @param show_p Print P values on the plot.
#' @param base_size,base_family Passed to [theme_pub()].
#' @return A ggplot object.
#' @export
superplot <- function(long, emb, readout, control, palette, eff = NULL, show_p = FALSE,
                      base_size = 8, base_family = "") {
  ro <- readout
  ref <- geometric_mean(emb$value[emb$readout == ro & emb$genotype == control])
  dn <- dplyr::mutate(dplyr::filter(long, .data$readout == ro), rel = .data$value / ref)
  de <- dplyr::mutate(dplyr::filter(emb, .data$readout == ro), rel = .data$value / ref)
  lev <- c(control, setdiff(names(palette), control))
  lev <- lev[lev %in% unique(de$genotype)]
  dn$genotype <- factor(dn$genotype, lev)
  de$genotype <- factor(de$genotype, lev)
  sm <- dplyr::summarise(dplyr::group_by(de, .data$genotype),
                         m = mean(log2(.data$rel)), s = stats::sd(log2(.data$rel)))
  sm <- dplyr::mutate(sm, y = 2^.data$m, lo = 2^(.data$m - .data$s), hi = 2^(.data$m + .data$s))
  pts <- if (requireNamespace("ggbeeswarm", quietly = TRUE))
    ggbeeswarm::geom_quasirandom(ggplot2::aes(colour = .data$genotype), size = 0.3, alpha = 0.35, width = 0.3)
  else ggplot2::geom_jitter(ggplot2::aes(colour = .data$genotype), size = 0.3, alpha = 0.35,
                            width = 0.25, height = 0)
  p <- ggplot2::ggplot(dn, ggplot2::aes(.data$genotype, .data$rel)) +
    ggplot2::geom_hline(yintercept = 1, linetype = "22", colour = "grey60", linewidth = 0.25) + pts +
    ggplot2::geom_errorbar(data = sm, ggplot2::aes(x = .data$genotype, ymin = .data$lo, ymax = .data$hi),
                           inherit.aes = FALSE, width = 0.22, linewidth = 0.4) +
    ggplot2::geom_errorbar(data = sm, ggplot2::aes(x = .data$genotype, ymin = .data$y, ymax = .data$y),
                           inherit.aes = FALSE, width = 0.5, linewidth = 0.6) +
    ggplot2::geom_point(data = de, ggplot2::aes(fill = .data$genotype), shape = 21, size = 2, stroke = 0.35,
                        position = ggplot2::position_jitter(width = 0.07, height = 0, seed = 1)) +
    ggplot2::scale_colour_manual(values = palette) + ggplot2::scale_fill_manual(values = palette) +
    ggplot2::scale_y_continuous(trans = "log2") +
    ggplot2::labs(x = NULL, y = paste0(ro, "\n(relative to ", control, ")")) +
    theme_pub(base_size, base_family)
  if (show_p && !is.null(eff)) {
    top <- max(stats::quantile(dn$rel, 0.99), de$rel) * 1.15
    lab <- dplyr::filter(eff, .data$readout == ro)
    lab <- dplyr::mutate(lab, genotype = factor(.data$genotype, lev),
                         txt = ifelse(is.na(.data$p), "", sprintf("P = %.2g", .data$p)))
    p <- p + ggplot2::geom_text(data = lab, ggplot2::aes(.data$genotype, top, label = .data$txt),
                                inherit.aes = FALSE, size = 2.3, vjust = 0)
  }
  p
}

#' Forest plot of fold changes for every readout
#'
#' @param eff Output of [welch_vs_control()].
#' @param palette Named colours per genotype.
#' @param limits Range of the fold-change axis.
#' @param base_size,base_family Passed to [theme_pub()].
#' @return A ggplot object.
#' @export
forest_plot <- function(eff, palette, limits = c(1 / 8, 8), base_size = 8, base_family = "") {
  d <- dplyr::filter(eff, !is.na(.data$fc))
  d <- dplyr::mutate(d, readout = factor(.data$readout, unique(.data$readout)))
  ggplot2::ggplot(d, ggplot2::aes(.data$fc, .data$genotype, colour = .data$genotype)) +
    ggplot2::geom_vline(xintercept = 1, linetype = "22", colour = "grey55") +
    ggplot2::geom_errorbar(ggplot2::aes(xmin = pmax(.data$fc_lo, limits[1]), xmax = pmin(.data$fc_hi, limits[2])),
                           width = 0.2, orientation = "y") +
    ggplot2::geom_point(size = 2) + ggplot2::facet_wrap(~ readout, nrow = 1) +
    ggplot2::scale_colour_manual(values = palette) +
    ggplot2::scale_x_continuous(trans = "log2", limits = limits, breaks = c(0.25, 0.5, 1, 2, 4),
                                labels = c("0.25", "0.5", "1", "2", "4")) +
    ggplot2::labs(x = "Fold change vs control (embryo level, 95% CI)", y = NULL) +
    theme_pub(base_size, base_family)
}

#' P value as a plotmath expression
#'
#' @param p A P value.
#' @return A character string to use with `parse = TRUE`, e.g.
#'   `italic(P)=='0.012'` or `italic(P)=='2.5'%*%10^-5`.
#' @export
format_p_plotmath <- function(p) {
  if (p >= 0.001) return(sprintf("italic(P)=='%s'", formatC(signif(p, 2), format = "fg", digits = 2)))
  e <- floor(log10(p))
  sprintf("italic(P)=='%s'%%*%%10^%d", signif(p / 10^e, 2), e)
}

#' Save a plot as PNG and, optionally, as an editable vector PDF
#'
#' The PDF keeps text as text, so it can be converted to SVG (see the Python
#' function `embryo_ifquant.figures.vector.pdf_to_svg`) and edited in
#' PowerPoint or Illustrator.
#'
#' @param file Output `.png` path.
#' @param plot A ggplot object.
#' @param width,height Size in inches.
#' @param dpi Resolution of the PNG.
#' @param vector Also write `<file>.vec.pdf`.
#' @return `file`, invisibly.
#' @export
save_plot <- function(file, plot, width, height, dpi = 400, vector = FALSE) {
  ggplot2::ggsave(file, plot, width = width, height = height, dpi = dpi, bg = "white")
  if (vector)
    ggplot2::ggsave(sub("\\.png$", ".vec.pdf", file), plot, width = width, height = height,
                    device = grDevices::pdf, bg = "white")
  invisible(file)
}
