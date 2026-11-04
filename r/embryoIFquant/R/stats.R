# Genotype effects, combining sessions, count data and power.
# Author: Khushi Singh

#' Each genotype versus the control: Welch t on log2 embryo values
#'
#' For every readout, each genotype is compared with the control by a
#' two-sided Welch t test on log2 embryo values. The fold change is the ratio
#' of geometric means with its 95% confidence interval; P values are Holm-
#' adjusted across genotypes within a readout.
#'
#' @param emb Output of [embryo_values()].
#' @param control Control genotype.
#' @return A tibble with `readout`, `genotype`, `n`, `n_ctrl`, `fc`, `fc_lo`,
#'   `fc_hi`, `p`, `p_holm`.
#' @export
welch_vs_control <- function(emb, control) {
  out <- dplyr::group_modify(dplyr::group_by(emb, .data$readout), function(d, k) {
    y <- log2(d$value[d$genotype == control])
    purrr::map_dfr(setdiff(unique(d$genotype), control), function(g) {
      x <- log2(d$value[d$genotype == g])
      if (length(x) < 2 || length(y) < 2)
        return(tibble::tibble(genotype = g, n = length(x), n_ctrl = length(y),
                              fc = NA_real_, fc_lo = NA_real_, fc_hi = NA_real_, p = NA_real_))
      t <- stats::t.test(x, y, var.equal = FALSE)
      tibble::tibble(genotype = g, n = length(x), n_ctrl = length(y), fc = 2^(mean(x) - mean(y)),
                     fc_lo = 2^t$conf.int[1], fc_hi = 2^t$conf.int[2], p = t$p.value)
    })
  })
  out <- dplyr::mutate(dplyr::group_by(dplyr::ungroup(out), .data$readout),
                       p_holm = stats::p.adjust(.data$p, "holm"))
  dplyr::ungroup(out)
}

#' Mixed-model check on all nuclei
#'
#' Fits `log2(value) ~ genotype + (1 | embryo) + (1 | image)` per readout as a
#' check of the embryo-level test. Requires the lmerTest package; returns
#' `NULL` if it is not installed.
#'
#' @param long Output of [make_long()].
#' @param control Control genotype.
#' @return A tibble with `readout`, `genotype`, `mm_fc`, `mm_lo`, `mm_hi`,
#'   `mm_p` and `embryo_var_zero` (singular fit on the embryo term), or `NULL`.
#' @export
mixed_vs_control <- function(long, control) {
  if (!requireNamespace("lmerTest", quietly = TRUE)) return(NULL)
  out <- dplyr::group_modify(dplyr::group_by(long, .data$readout), function(d, k) {
    d$genotype <- stats::relevel(factor(d$genotype), control)
    fit <- try(suppressMessages(lmerTest::lmer(log2(value) ~ genotype + (1 | embryo) + (1 | image),
                                               data = d)), silent = TRUE)
    if (inherits(fit, "try-error")) return(tibble::tibble())
    co <- summary(fit)$coefficients
    co <- co[grepl("^genotype", rownames(co)), , drop = FALSE]
    vc <- as.data.frame(lme4::VarCorr(fit))
    tibble::tibble(genotype = sub("^genotype", "", rownames(co)), mm_fc = 2^co[, 1],
                   mm_lo = 2^(co[, 1] - 1.96 * co[, 2]), mm_hi = 2^(co[, 1] + 1.96 * co[, 2]),
                   mm_p = co[, 5], embryo_var_zero = vc$vcov[vc$grp == "embryo"] < 1e-8)
  })
  dplyr::ungroup(out)
}

#' Flag control readouts that changed
#'
#' Readouts such as total H3, DAPI or H3/DAPI should not differ between
#' genotypes. A significant change means that ratios using them as the
#' denominator cannot be interpreted.
#'
#' @param eff Output of [welch_vs_control()].
#' @param control_readouts Readouts expected not to change.
#' @param alpha Significance level of the flag.
#' @return `eff` with logical columns `control_readout` and `control_failed`.
#' @export
flag_control_readouts <- function(eff, control_readouts = c("H3", "DAPI", "H3 / DAPI"), alpha = 0.05) {
  dplyr::mutate(eff,
    control_readout = .data$readout %in% control_readouts,
    control_failed = .data$control_readout & !is.na(.data$p) & .data$p < alpha)
}

#' Combine independent experiments on a relative scale
#'
#' Raw intensities are never pooled across imaging sessions. Each embryo is
#' expressed relative to the control geometric mean of its own experiment and
#' the combined effect is estimated by `lm(log2(rel) ~ experiment + genotype)`,
#' so that the experiment enters as a fixed effect. Heterogeneity between
#' experiments is tested with the experiment x genotype interaction.
#'
#' @param d Embryo values of several experiments with columns `experiment`,
#'   `readout`, `genotype` and `value`.
#' @param control Control genotype.
#' @param genotypes Genotypes to compare with the control (default: all).
#' @return A tibble per readout and genotype with `fc`, `fc_lo`, `fc_hi`, `p`,
#'   `n_experiments`, `n_embryos`, `n_embryos_control` and `p_heterogeneity`.
#' @export
combine_experiments <- function(d, control, genotypes = NULL) {
  if (!is.null(genotypes)) d <- dplyr::filter(d, .data$genotype %in% c(control, genotypes))
  d <- relative_to_control(dplyr::group_by(d, .data$readout, .data$experiment), control)
  out <- dplyr::group_modify(dplyr::group_by(dplyr::ungroup(d), .data$readout), function(x, k) {
    x$genotype <- stats::relevel(factor(x$genotype), control)
    x$experiment <- factor(x$experiment)
    x$log2rel <- log2(x$rel)
    n_exp <- nlevels(x$experiment)
    fit <- if (n_exp > 1) stats::lm(log2rel ~ experiment + genotype, data = x)
           else stats::lm(log2rel ~ genotype, data = x)
    cf <- summary(fit)$coefficients
    ci <- stats::confint(fit)
    rows <- grep("^genotype", rownames(cf), value = TRUE)
    het <- NA_real_
    if (n_exp > 1 && nlevels(x$genotype) > 1) {
      full <- try(stats::lm(log2rel ~ experiment * genotype, data = x), silent = TRUE)
      if (!inherits(full, "try-error")) {
        a <- try(stats::anova(fit, full), silent = TRUE)
        if (!inherits(a, "try-error")) het <- a$`Pr(>F)`[2]
      }
    }
    tibble::tibble(genotype = sub("^genotype", "", rows),
                   fc = 2^cf[rows, "Estimate"], fc_lo = 2^ci[rows, 1], fc_hi = 2^ci[rows, 2],
                   p = cf[rows, "Pr(>|t|)"], n_experiments = n_exp,
                   n_embryos = as.integer(table(x$genotype)[sub("^genotype", "", rows)]),
                   n_embryos_control = sum(x$genotype == control), p_heterogeneity = het)
  })
  dplyr::ungroup(out)
}

#' Combine sessions analysed separately
#'
#' Convenience wrapper around [combine_experiments()] for `embryo_values.csv`
#' files written by [run_experiment()].
#'
#' @param emb_files Named character vector, `session = path`.
#' @param control Control genotype.
#' @param genotype Genotype(s) to compare with the control.
#' @return See [combine_experiments()]; only readouts present in more than one
#'   session are kept.
#' @export
combine_sessions <- function(emb_files, control, genotype) {
  d <- purrr::imap_dfr(emb_files, function(path, id)
    dplyr::mutate(readr::read_csv(path, show_col_types = FALSE), experiment = id))
  d <- dplyr::filter(dplyr::group_by(d, .data$readout),
                     dplyr::n_distinct(.data$experiment) > 1)
  combine_experiments(dplyr::ungroup(d), control, genotype)
}

#' Count data per individual versus the control
#'
#' For counts with zeros (for example eggs laid per female), each genotype is
#' compared with the control by a two-sided Wilcoxon rank-sum test with Holm
#' correction. The individual is the replicate.
#'
#' @param d A tibble with `genotype` and `value` (one row per individual).
#' @param control Control genotype.
#' @return A tibble with `genotype`, `n`, `ratio_of_means`, `zeros`, `p`, `p_holm`.
#' @export
counts_vs_control <- function(d, control) {
  ctrl <- d$value[d$genotype == control]
  out <- purrr::map_dfr(setdiff(unique(d$genotype), control), function(g) {
    x <- d$value[d$genotype == g]
    tibble::tibble(genotype = g, n = length(x), ratio_of_means = mean(x) / mean(ctrl),
                   zeros = sum(x == 0), p = stats::wilcox.test(x, ctrl, exact = FALSE)$p.value)
  })
  dplyr::mutate(out, p_holm = stats::p.adjust(.data$p, "holm"))
}

#' Embryos needed per genotype
#'
#' Uses the between-embryo standard deviation of log2 control values, pooled
#' across sessions, and a two-sided two-sample t test.
#'
#' @param emb Embryo values with `readout`, `genotype`, `value` and optionally
#'   `session`.
#' @param control Control genotype.
#' @param fold_changes Effects to detect.
#' @param power,sig_level Target power and significance level.
#' @param n_current Group sizes for which the smallest detectable change is reported.
#' @return A tibble per readout with the pooled s.d., embryos needed per fold
#'   change (`n_fc_<x>`) and the smallest detectable fold change per `n_current`.
#' @export
power_embryos <- function(emb, control, fold_changes = c(0.9, 0.8, 0.7, 0.6, 0.5),
                          power = 0.8, sig_level = 0.05, n_current = c(3, 6)) {
  if (!"session" %in% names(emb)) emb$session <- "all"
  sd_tab <- dplyr::summarise(
    dplyr::group_by(dplyr::filter(emb, .data$genotype == control), .data$readout, .data$session),
    n = dplyr::n(), v = stats::var(log2(.data$value)), .groups = "drop")
  sd_tab <- dplyr::summarise(dplyr::group_by(dplyr::filter(sd_tab, .data$n >= 2), .data$readout),
    sd_log2 = sqrt(sum(.data$v * (.data$n - 1)) / sum(.data$n - 1)),
    df = sum(.data$n - 1), sessions = dplyr::n(), .groups = "drop")
  for (fc in fold_changes)
    sd_tab[[paste0("n_fc_", fc)]] <- vapply(sd_tab$sd_log2, function(s)
      ceiling(stats::power.t.test(delta = abs(log2(fc)), sd = s, sig.level = sig_level, power = power)$n), 1)
  for (n in n_current)
    sd_tab[[paste0("min_fc_n", n)]] <- vapply(sd_tab$sd_log2, function(s)
      2^-stats::power.t.test(n = n, sd = s, sig.level = sig_level, power = power)$delta, 1)
  sd_tab
}
