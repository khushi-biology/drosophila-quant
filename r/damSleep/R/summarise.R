# Per-fly sleep and activity summaries.
# Author: Khushi Singh

meta_table <- function(dt) {
  m <- data.table::copy(dt[meta = TRUE])
  if ("file_info" %in% names(m)) m[, file_info := NULL]
  m
}

#' Sleep bouts of every fly
#'
#' @param dt A curated `behavr` table with the column `asleep`.
#' @return A `behavr` table with one row per sleep bout: `id`, `t` (bout onset,
#'   s from ZT0) and `duration` (s).
#' @export
sleep_bouts <- function(dt) {
  b <- sleepr::bout_analysis(asleep, dt)
  b[asleep == TRUE, -"asleep"]
}

#' Per-fly sleep and activity summary
#'
#' Light (L) is the first `light_hours` of every `period_hours` from ZT0, dark
#' (D) the rest. For each fly:
#'
#' * `sleep_fraction_all`, `sleep_fraction_l`, `sleep_fraction_d`: fraction of
#'   time asleep overall, in the light and in the dark;
#' * `total_sleep_min_day`, `day_sleep_min`, `night_sleep_min`: the same in
#'   minutes per day, per light phase and per dark phase;
#' * `days_recorded`, `total_activity`, `mean_activity`, `max_activity`,
#'   `awake_min`, `activity_per_day`, `activity_per_wake_min`: beam crossings;
#' * `n_bouts_L_day`, `n_bouts_D_day`: sleep bouts starting in the light or the
#'   dark, per recorded day; `mean_bout_L_min`, `mean_bout_D_min`: their mean
#'   length (min);
#' * `latency_night_min`: time from lights-off to the first sleep bout, mean
#'   over nights (min).
#'
#' @param dt A curated `behavr` table with the columns `asleep` and `activity`.
#' @param light_hours Length of the light phase (h).
#' @param period_hours Length of one light-dark cycle (h).
#' @param bin_s Sampling interval (s); estimated from the data if `NULL`.
#' @return A `data.table` with the metadata and the measures, one row per fly.
#' @export
per_animal_summary <- function(dt, light_hours = 12, period_hours = 24, bin_s = NULL) {
  if (is.null(bin_s)) bin_s <- bin_seconds(dt)
  per <- hours(period_hours); light <- hours(light_hours)
  x <- data.table(id = dt$id, t = dt$t, asleep = dt$asleep, activity = dt$activity)
  x[, phase := ifelse(t %% per < light, "L", "D")]
  s <- x[, list(
    sleep_fraction_all = mean(asleep),
    sleep_fraction_l = mean(asleep[phase == "L"]),
    sleep_fraction_d = mean(asleep[phase == "D"]),
    days_recorded = .N * bin_s / 86400,
    total_activity = sum(activity),
    mean_activity = mean(activity),
    max_activity = max(activity),
    awake_min = sum(!asleep) * bin_s / 60), by = id]
  s[, `:=`(
    total_sleep_min_day = sleep_fraction_all * period_hours * 60,
    day_sleep_min = sleep_fraction_l * light_hours * 60,
    night_sleep_min = sleep_fraction_d * (period_hours - light_hours) * 60,
    activity_per_day = total_activity / days_recorded,
    activity_per_wake_min = total_activity / awake_min)]

  b <- sleep_bouts(dt)
  bd <- data.table(id = b$id, t = b$t, duration = b$duration)
  bd[, phase := factor(ifelse(t %% per < light, "L", "D"), levels = c("D", "L"))]
  bp <- bd[, list(n = .N, mean_len = mean(duration) / 60), by = list(id, phase)]
  bp <- data.table::dcast(bp, id ~ phase, value.var = c("n", "mean_len"), drop = FALSE)
  s <- merge(s, bp, by = "id", all.x = TRUE)
  s[is.na(n_L), n_L := 0]
  s[is.na(n_D), n_D := 0]
  s[, `:=`(n_bouts_L_day = n_L / days_recorded, n_bouts_D_day = n_D / days_recorded,
           mean_bout_L_min = mean_len_L, mean_bout_D_min = mean_len_D)]

  bd[, night := floor(t / per)]
  nl <- bd[t %% per >= light, list(lat = min(t) - (night[1] * per + light)), by = list(id, night)]
  nl <- nl[, list(latency_night_min = mean(lat) / 60), by = id]
  s <- merge(s, nl, by = "id", all.x = TRUE)
  meta_table(dt)[s, on = "id"]
}

#' Sleep bouts in the light phase of one day
#'
#' The sleep latency and bout structure in the light phase of day `day`
#' (day 1 starts at ZT0), with times relative to that day's lights-on.
#'
#' @param bouts Bouts from [sleep_bouts()].
#' @param day Day to analyse (1 = first day).
#' @param light_hours Length of the light phase (h).
#' @param period_hours Length of one cycle (h).
#' @return A `data.table`, one row per fly with at least one bout: `latency`,
#'   `first_bout_length`, `latency_to_longest_bout`, `length_longest_bout`,
#'   `n_bouts`, `mean_bout_length` (all in s).
#' @export
light_phase_bouts <- function(bouts, day = 2, light_hours = 12, period_hours = 24) {
  start <- (day - 1) * hours(period_hours)
  b <- data.table(id = bouts$id, t = bouts$t, duration = bouts$duration)
  b <- b[t >= start & t <= start + hours(light_hours)]
  b[, t := t - start]
  b[, list(latency = t[1], first_bout_length = duration[1],
           latency_to_longest_bout = t[which.max(duration)], length_longest_bout = max(duration),
           n_bouts = .N, mean_bout_length = mean(duration)), by = id]
}

#' Total sleep on each day of the recording
#'
#' @param dt A curated `behavr` table.
#' @param n_days Number of days to report.
#' @param min_coverage Days with less than this fraction of the expected bins
#'   (e.g. the day a fly died) are left out.
#' @param period_hours Length of one cycle (h).
#' @param bin_s Sampling interval (s); estimated if `NULL`.
#' @return A `data.table` with `id`, `day`, `sleep_min`, `genotype`, `sex`.
#' @export
daily_sleep <- function(dt, n_days, min_coverage = 0.9, period_hours = 24, bin_s = NULL) {
  if (is.null(bin_s)) bin_s <- bin_seconds(dt)
  per <- hours(period_hours)
  d <- data.table(id = dt$id, day = floor(dt$t / per) + 1, asleep = dt$asleep)
  d <- d[day <= n_days, list(sleep_min = mean(asleep) * period_hours * 60, n = .N), by = list(id, day)]
  d <- d[n >= min_coverage * per / bin_s][, n := NULL]
  m <- meta_table(dt)[, list(id, genotype, sex)]
  m[d, on = "id"]
}

#' Mean profile over the light-dark cycle
#'
#' Each fly's `var` is averaged in bins of `bin_min` minutes of zeitgeber time
#' over all days; the flies are then averaged per genotype and sex.
#'
#' @param dt A curated `behavr` table.
#' @param var Column to average (`"asleep"` or `"activity"`).
#' @param bin_min Bin length (min).
#' @param period_hours Length of one cycle (h).
#' @return A `data.table` with `genotype`, `sex`, `zt` (h), `mean`, `se`, `n`.
#' @export
zt_profile <- function(dt, var = "asleep", bin_min = 30, period_hours = 24) {
  p <- data.table(id = dt$id, t = dt$t, v = as.numeric(dt[[var]]))
  p[, zt := floor((t %% hours(period_hours)) / mins(bin_min)) * bin_min / 60]
  p <- p[, list(v = mean(v)), by = list(id, zt)]
  p <- meta_table(dt)[, list(id, genotype, sex)][p, on = "id"]
  p[, list(mean = mean(v), se = stats::sd(v) / sqrt(.N), n = .N), by = list(genotype, sex, zt)]
}
