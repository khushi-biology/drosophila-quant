# Figures: quality control, profiles, actograms and summary statistics.
# Author: Khushi Singh

#' Plot theme used by the package
#'
#' @param base_size Base font size (pt).
#' @return A ggplot2 theme.
#' @export
theme_dam <- function(base_size = 11) {
  ggplot2::theme_bw(base_size = base_size) +
    ggplot2::theme(strip.background = ggplot2::element_rect(fill = "grey95", colour = NA),
                   panel.grid.minor = ggplot2::element_blank())
}

#' Default colours
#'
#' `sex_colours()` gives one colour per sex. `genotype_colours()` gives greys
#' for the controls and distinct colours (colour-blind safe) for the other
#' genotypes.
#'
#' @param genotypes Genotypes in plotting order.
#' @param controls Control genotypes.
#' @return A named character vector of colours.
#' @export
genotype_colours <- function(genotypes, controls = character(0)) {
  greys <- grDevices::colorRampPalette(c("#3a3a38", "#b5b3ae"))(max(2, length(controls)))
  pal <- c("#2a78d6", "#eb6834", "#1baf7a", "#4a3aa7", "#CC79A7", "#E69F00", "#56B4E9", "#D55E00")
  tests <- setdiff(genotypes, controls)
  cols <- c(stats::setNames(greys[seq_along(controls)], controls),
            stats::setNames(rep_len(pal, length(tests)), tests))
  cols[genotypes]
}

#' @rdname genotype_colours
#' @export
sex_colours <- function() c(F = "#2a78d6", M = "#eb6834")

#' Activity or sleep of every fly as tiles (quality control)
#'
#' Dark rows breaking the daily rhythm usually mean a dead fly.
#'
#' @param dt A `behavr` table.
#' @param var `"activity"` or `"asleep"`.
#' @return A ggplot.
#' @export
plot_tiles <- function(dt, var = "activity") {
  ggetho::ggetho(dt, ggplot2::aes(z = !!as.name(var))) +
    ggetho::stat_tile_etho() +
    ggetho::stat_ld_annotations(height = if (var == "asleep") 1 else 0.03) +
    ggplot2::facet_grid(genotype ~ ., scales = "free_y", space = "free_y") +
    theme_dam() + ggplot2::theme(axis.text.y = ggplot2::element_text(size = 4))
}

#' Population sleep or activity over time
#'
#' Mean +/- SEM per genotype (rows) and sex (colour), either over the whole
#' recording or folded over one cycle (`wrap_hours = 24`).
#'
#' @param dt A curated `behavr` table.
#' @param var `"asleep"` or `"activity"`.
#' @param wrap_hours Fold the time axis over this period, or `NULL`.
#' @param colours Colours of the sexes.
#' @param ylab Axis label.
#' @return A ggplot.
#' @export
plot_population <- function(dt, var = "asleep", wrap_hours = NULL, colours = sex_colours(), ylab = NULL) {
  aes <- ggplot2::aes(x = t, y = !!as.name(var), colour = sex)
  p <- if (is.null(wrap_hours)) ggetho::ggetho(dt, aes) else ggetho::ggetho(dt, aes, time_wrap = hours(wrap_hours))
  y <- if (var == "asleep") {
    ggplot2::scale_y_continuous(ylab %||% "Fraction of time sleeping", labels = scales::percent)
  } else ggplot2::scale_y_continuous(ylab %||% "Activity (beam crossings per bin)")
  p + ggetho::stat_pop_etho() + ggetho::stat_ld_annotations() +
    ggplot2::facet_grid(genotype ~ .) +
    ggplot2::scale_colour_manual(values = colours) + ggplot2::scale_fill_manual(values = colours) +
    y + theme_dam()
}

#' Sleep fraction overall, in the light and in the dark
#'
#' @param summary Per-fly table from [per_animal_summary()].
#' @param colours Colours of the sexes.
#' @return A ggplot.
#' @export
plot_phase_fractions <- function(summary, colours = sex_colours()) {
  s <- data.table::as.data.table(summary)
  long <- data.table::melt(s[, list(id, genotype, sex, sleep_fraction_all, sleep_fraction_l, sleep_fraction_d)],
                           id.vars = c("id", "genotype", "sex"), variable.name = "phase",
                           value.name = "sleep_fraction")
  long[, phase := factor(phase, levels = c("sleep_fraction_all", "sleep_fraction_l", "sleep_fraction_d"),
                         labels = c("All", "Light (day)", "Dark (night)"))]
  ggplot2::ggplot(long, ggplot2::aes(phase, sleep_fraction, fill = sex)) +
    ggplot2::geom_boxplot(outlier.colour = NA, alpha = 0.6) +
    ggplot2::geom_point(ggplot2::aes(colour = sex), size = 0.8, alpha = 0.6,
                        position = ggplot2::position_jitterdodge(jitter.width = 0.15)) +
    ggplot2::facet_grid(genotype ~ .) +
    ggplot2::scale_fill_manual(values = colours) + ggplot2::scale_colour_manual(values = colours) +
    ggplot2::scale_y_continuous("Fraction of time sleeping", labels = scales::percent) +
    ggplot2::xlab(NULL) + theme_dam()
}

#' Sleep-bout length over the cycle
#'
#' @param bouts Bouts from [sleep_bouts()].
#' @param period_hours Period to fold over (h).
#' @param colours Colours of the sexes.
#' @return A ggplot.
#' @export
plot_bout_length <- function(bouts, period_hours = 24, colours = sex_colours()) {
  ggetho::ggetho(bouts, ggplot2::aes(y = duration / 60, colour = sex), time_wrap = hours(period_hours)) +
    ggetho::stat_pop_etho() + ggplot2::facet_grid(genotype ~ .) +
    ggplot2::scale_colour_manual(values = colours) + ggplot2::scale_fill_manual(values = colours) +
    ggplot2::scale_y_continuous("Bout length (min)") + theme_dam()
}

#' Number against mean length of sleep bouts in one light phase
#'
#' @param light_bouts Table from [light_phase_bouts()].
#' @param summary Per-fly table (for genotype and sex).
#' @param day Day shown, for the axis label.
#' @param colours Colours of the sexes.
#' @return A ggplot.
#' @export
plot_light_bouts <- function(light_bouts, summary, day = 2, colours = sex_colours()) {
  d <- data.table::as.data.table(summary)[, list(id, genotype, sex)][light_bouts, on = "id"]
  ggplot2::ggplot(d, ggplot2::aes(n_bouts, mean_bout_length / 60, colour = sex)) +
    ggplot2::geom_point(alpha = 0.7) + ggplot2::facet_grid(genotype ~ .) +
    ggplot2::scale_colour_manual(values = colours) +
    ggplot2::scale_x_continuous(sprintf("Number of bouts (day %d, light phase)", day)) +
    ggplot2::scale_y_continuous("Average bout duration (min)") + theme_dam()
}

#' Double-plotted actogram per genotype (population mean)
#'
#' @param dt A curated `behavr` table.
#' @param ncol Number of panel columns.
#' @return A ggplot.
#' @export
plot_actogram <- function(dt, ncol = 3) {
  ggetho::ggetho(dt, ggplot2::aes(x = t, z = activity), multiplot = 2) +
    ggetho::stat_bar_tile_etho() + ggplot2::facet_wrap(~ genotype, ncol = ncol) + theme_dam()
}

#' Double-plotted actograms of every fly, one PDF page per genotype
#'
#' @param dt A curated `behavr` table.
#' @param file Output PDF.
#' @param ncol Panels per row.
#' @return `file`, invisibly.
#' @export
write_individual_actograms <- function(dt, file, ncol = 6) {
  short_id <- function(x) sub("\\.txt", "", sub("^[^|]*\\|", "", x))
  grDevices::pdf(file, width = 14, height = 11)
  on.exit(grDevices::dev.off())
  for (g in levels(droplevels(dt[meta = TRUE]$genotype))) {
    sub <- dt[xmv(genotype) == g]
    print(ggetho::ggetho(sub, ggplot2::aes(x = t, z = activity), multiplot = 2) +
            ggetho::stat_bar_tile_etho() +
            ggplot2::facet_wrap(~ id, ncol = ncol, labeller = ggplot2::labeller(id = short_id)) +
            ggplot2::ggtitle(paste("Double-plotted actograms -", g)) + theme_dam() +
            ggplot2::theme(strip.text = ggplot2::element_text(size = 6)))
  }
  invisible(file)
}

#' Daily sleep profile of each test genotype against the controls
#'
#' One panel per test genotype and sex, with the controls drawn in every
#' panel; mean +/- SEM of the flies in bins of `bin_min` minutes.
#'
#' @param dt A curated `behavr` table.
#' @param tests Test genotypes (one panel each).
#' @param controls Control genotypes.
#' @param bin_min Bin length (min).
#' @param light_hours,period_hours Light phase and cycle length (h).
#' @return A ggplot.
#' @export
plot_profiles_vs_controls <- function(dt, tests, controls, bin_min = 30, light_hours = 12, period_hours = 24) {
  prof <- zt_profile(dt, "asleep", bin_min = bin_min, period_hours = period_hours)
  panels <- data.table::rbindlist(lapply(tests, function(m) {
    x <- prof[genotype %in% c(m, controls)]
    x[, panel := m]
    x[, line := ifelse(genotype %in% controls, as.character(genotype), "Test genotype")]
    x
  }))
  panels[, panel := factor(panel, levels = tests)]
  panels[, line := factor(line, levels = c(controls, "Test genotype"))]
  cols <- c(genotype_colours(controls, controls), "Test genotype" = "#4a3aa7")
  ggplot2::ggplot(panels, ggplot2::aes(zt, mean, colour = line, fill = line)) +
    ggplot2::annotate("rect", xmin = light_hours, xmax = period_hours, ymin = -Inf, ymax = Inf,
                      fill = "grey85", alpha = 0.5) +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = mean - se, ymax = mean + se), colour = NA, alpha = 0.2) +
    ggplot2::geom_line(linewidth = 0.7) +
    ggplot2::facet_grid(sex ~ panel) +
    ggplot2::scale_colour_manual(values = cols, name = NULL,
                                 labels = c(paste(controls, "(control)"), "Test genotype (panel title)")) +
    ggplot2::scale_fill_manual(values = cols, guide = "none") +
    ggplot2::scale_x_continuous("Zeitgeber time (h)", breaks = seq(0, period_hours, 6)) +
    ggplot2::scale_y_continuous(sprintf("Fraction of time asleep (%g-min bins)", bin_min),
                                labels = scales::percent) +
    theme_dam() + ggplot2::theme(legend.position = "top")
}

#' Total sleep on each day
#'
#' @param daily Table from [daily_sleep()].
#' @param colours Colours of the genotypes.
#' @return A ggplot.
#' @export
plot_daily_sleep <- function(daily, colours) {
  d <- daily[, list(mean = mean(sleep_min), se = stats::sd(sleep_min) / sqrt(.N)), by = list(genotype, sex, day)]
  ggplot2::ggplot(d, ggplot2::aes(day, mean, colour = genotype)) +
    ggplot2::geom_line() + ggplot2::geom_point(size = 1.5) +
    ggplot2::geom_errorbar(ggplot2::aes(ymin = mean - se, ymax = mean + se), width = 0.15) +
    ggplot2::facet_grid(. ~ sex) +
    ggplot2::scale_colour_manual(values = colours, name = NULL) +
    ggplot2::scale_x_continuous("Day of recording", breaks = sort(unique(d$day))) +
    ggplot2::ylab("Total sleep (min/day, mean +/- SEM)") + theme_dam()
}

#' Box plots of several measures with significance against the controls
#'
#' One row per measure and one column per sex. Above each test genotype, one
#' symbol per control marks significance after Holm correction (one symbol
#' P < 0.05, two P < 0.01, three P < 0.001): `*` for the first control, `#`
#' for the second, and so on.
#'
#' @param summary Per-fly table from [per_animal_summary()].
#' @param stats Table from [compare_to_controls()].
#' @param metrics Measures to show (names of [default_metrics()] or a named
#'   vector of labels).
#' @param controls Control genotypes, in the order of their symbols.
#' @param tests Test genotypes that get symbols.
#' @param colours Colours of the sexes.
#' @param symbols One symbol per control.
#' @return A ggplot.
#' @export
plot_metric_stats <- function(summary, stats, metrics, controls, tests, colours = sex_colours(),
                              symbols = c("*", "#", "$", "&")) {
  labels <- if (is.null(names(metrics))) default_metrics()[metrics] else metrics
  ms <- names(labels)
  s <- data.table::as.data.table(summary)
  long <- data.table::melt(s[, c("id", "genotype", "sex", ms), with = FALSE],
                           id.vars = c("id", "genotype", "sex"), variable.name = "metric")
  long <- long[!is.na(value)]
  long[, metric := as.character(metric)]
  ypos <- long[, list(y = max(value) * 1.08), by = list(metric, sex)]
  long[, metric := factor(metric, levels = ms, labels = labels)]
  st <- data.table::as.data.table(stats)[metric %in% ms & control %in% controls & group %in% tests]
  st[, sym := symbols[match(control, controls)]]
  st[, mark := ifelse(signif == "ns", "", gsub("\\*", sym[1], signif)), by = seq_len(nrow(st))]
  st[, control := factor(control, levels = controls)]
  data.table::setorder(st, metric, sex, group, control)
  lab <- st[, list(label = paste(mark, collapse = "\n")), by = list(metric, sex, group)]
  lab[, label := sub("^\n+", "", sub("\n+$", "", label))]
  lab <- merge(lab, ypos, by = c("metric", "sex"))
  lab[, metric := factor(metric, levels = ms, labels = labels)]
  lab[, genotype := factor(group, levels = levels(s$genotype))]
  caption <- paste0(paste(sprintf("%s vs %s", symbols[seq_along(controls)], controls), collapse = ", "),
                    " (Wilcoxon rank-sum, Holm-adjusted): 1 symbol P < 0.05, 2 P < 0.01, 3 P < 0.001")
  ggplot2::ggplot(long, ggplot2::aes(genotype, value, fill = sex)) +
    ggplot2::geom_boxplot(outlier.colour = NA, alpha = 0.6, width = 0.7) +
    ggplot2::geom_point(ggplot2::aes(colour = sex), position = ggplot2::position_jitter(width = 0.15),
                        size = 0.8, alpha = 0.6) +
    ggplot2::geom_text(data = lab, ggplot2::aes(genotype, y, label = label), inherit.aes = FALSE,
                       size = 3, vjust = 0, lineheight = 0.8) +
    ggplot2::facet_grid(metric ~ sex, scales = "free_y", switch = "y") +
    ggplot2::scale_fill_manual(values = colours, guide = "none") +
    ggplot2::scale_colour_manual(values = colours, guide = "none") +
    ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0.05, 0.2))) +
    ggplot2::labs(x = NULL, y = NULL, caption = caption) +
    theme_dam() + ggplot2::theme(strip.placement = "outside",
                                 axis.text.x = ggplot2::element_text(angle = 30, hjust = 1))
}

`%||%` <- function(a, b) if (is.null(a)) b else a
