# Statistics: each test group against each control, by sex.
# Author: Khushi Singh

#' Default sleep and activity measures
#'
#' @return A named character vector: column name = axis label.
#' @export
default_metrics <- function() {
  c(total_sleep_min_day = "Total sleep (min/day)",
    day_sleep_min = "Day sleep (min/light phase)",
    night_sleep_min = "Night sleep (min/dark phase)",
    n_bouts_L_day = "Day sleep bouts (per day)",
    n_bouts_D_day = "Night sleep bouts (per night)",
    mean_bout_L_min = "Mean day bout length (min)",
    mean_bout_D_min = "Mean night bout length (min)",
    latency_night_min = "Sleep latency after lights-off (min)",
    activity_per_day = "Activity (beam crossings/day)",
    activity_per_wake_min = "Activity per waking minute")
}

#' Build the list of comparisons
#'
#' Every test group against every control, plus any extra pairs (for example
#' one control against the other).
#'
#' @param groups Test genotypes.
#' @param controls Control genotypes.
#' @param extra Optional `data.frame` with columns `group` and `control`.
#' @return A `data.table` with columns `group` and `control`.
#' @export
#' @examples
#' make_comparisons(c("mutA", "mutB"), c("WT", "w1118"),
#'                  extra = data.frame(group = "w1118", control = "WT"))
make_comparisons <- function(groups, controls, extra = NULL) {
  cmp <- data.table::CJ(group = groups, control = controls, sorted = FALSE)
  if (!is.null(extra)) cmp <- rbind(cmp, data.table::as.data.table(extra)[, list(group, control)])
  cmp[]
}

#' Compare each group with its controls
#'
#' For each measure and sex: a Kruskal-Wallis test across all genotypes, and a
#' two-sided Wilcoxon rank-sum test for every comparison, with Holm correction
#' across the comparisons of that measure and sex. Flies are the replicates.
#'
#' @param summary Per-fly table from [per_animal_summary()].
#' @param comparisons Pairs from [make_comparisons()].
#' @param metrics Measures to test (column names, or a named vector as in
#'   [default_metrics()]).
#' @param by Column to split by (usually `"sex"`); `NULL` for no split.
#' @return A `data.table` with medians, % change of the median, `p_wilcox`,
#'   `p_holm`, `kruskal_p` and a significance label (`signif`).
#' @export
compare_to_controls <- function(summary, comparisons, metrics = default_metrics(), by = "sex") {
  labels <- if (is.null(names(metrics))) stats::setNames(metrics, metrics) else metrics
  s <- data.table::as.data.table(summary)
  if (is.null(by)) { s[, .all := "all"]; by <- ".all" }
  levels_by <- unique(as.character(s[[by]]))
  out <- data.table::rbindlist(lapply(names(labels), function(m) {
    data.table::rbindlist(lapply(levels_by, function(lv) {
      d <- s[as.character(s[[by]]) == lv & !is.na(s[[m]])]
      kw <- tryCatch(stats::kruskal.test(d[[m]] ~ droplevels(factor(d$genotype)))$p.value,
                     error = function(e) NA_real_)
      res <- data.table::rbindlist(lapply(seq_len(nrow(comparisons)), function(i) {
        g <- comparisons$group[i]; ctl <- comparisons$control[i]
        x <- d[genotype == g][[m]]; y <- d[genotype == ctl][[m]]
        p <- if (length(x) && length(y)) stats::wilcox.test(x, y, exact = FALSE)$p.value else NA_real_
        data.table(metric = m, metric_label = labels[[m]], by_value = lv, group = g, control = ctl,
                   n_group = length(x), n_control = length(y),
                   median_group = if (length(x)) stats::median(x) else NA_real_,
                   median_control = if (length(y)) stats::median(y) else NA_real_,
                   p_wilcox = p)
      }))
      res[, pct_change := 100 * (median_group - median_control) / median_control]
      res[, p_holm := stats::p.adjust(p_wilcox, method = "holm")]
      res[, kruskal_p := kw]
      res
    }))
  }))
  out[, signif := data.table::fcase(p_holm < 0.001, "***", p_holm < 0.01, "**", p_holm < 0.05, "*",
                                    default = "ns")]
  if (by == ".all") out[, by_value := NULL] else data.table::setnames(out, "by_value", by)
  out[]
}

#' Mean, SEM, median and quartiles per group
#'
#' @param summary Per-fly table from [per_animal_summary()].
#' @param metrics Measures to summarise.
#' @param by Extra grouping column besides `genotype` (usually `"sex"`).
#' @return A long `data.table` with one row per measure, genotype and `by`.
#' @export
group_summary <- function(summary, metrics = default_metrics(), by = "sex") {
  m <- if (is.null(names(metrics))) metrics else names(metrics)
  s <- data.table::as.data.table(summary)
  long <- data.table::melt(s[, c("id", "genotype", by, m), with = FALSE],
                           id.vars = c("id", "genotype", by), variable.name = "metric")
  g <- long[!is.na(value), list(n = .N, mean = mean(value), sem = stats::sd(value) / sqrt(.N),
                                median = stats::median(value), q1 = stats::quantile(value, 0.25),
                                q3 = stats::quantile(value, 0.75)), by = c("metric", "genotype", by)]
  data.table::setorderv(g, c("metric", "genotype", by))
  g[]
}
