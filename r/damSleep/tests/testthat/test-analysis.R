load_synthetic <- function() {
  d <- synthetic_dir()
  md <- read_dam_metadata(file.path(d, "metadata.csv"))
  list(dir = d, dt = load_dam_sleep(md, d, genotype_levels = c("WT", "ctl2", "mut")))
}

test_that("dead, dying and healthy flies are curated correctly", {
  x <- load_synthetic()
  expect_equal(bin_seconds(x$dt), 60)
  cur <- curate_animals(x$dt, analysis_days = 4)
  ids <- as.character(cur$data[meta = TRUE]$id)
  ch <- as.integer(sub(".*\\|", "", ids))
  expect_setequal(ch, c(1:12, 14))
  life14 <- max(cur$data[id == ids[ch == 14]]$t)
  expect_lt(life14, behavr::days(2.6))
  expect_true(all(c("Dead or inactive from the start", "Died later (kept, data truncated at death)")
                  %in% cur$excluded$reason))
  expect_true(max(cur$data$t) <= behavr::days(4))
  n <- sample_sizes(x$dt, cur$data)
  expect_equal(sum(n$loaded), 15); expect_equal(sum(n$analysed), 13)
})

test_that("per-fly measures match the simulated behaviour", {
  x <- load_synthetic()
  dc <- curate_animals(x$dt, analysis_days = 4)$data
  s <- per_animal_summary(dc)
  s[, ch := as.integer(region_id)]
  wt <- s[ch %in% 1:4][order(ch)]
  expect_true(all(wt$sleep_fraction_l < 0.01))
  expected_night <- (720 - c(30, 45, 60, 75)) / 720
  expect_equal(wt$sleep_fraction_d, expected_night, tolerance = 0.02)
  expect_equal(wt$latency_night_min, c(30, 45, 60, 75), tolerance = 0.05)
  expect_equal(wt$n_bouts_D_day, rep(1, 4), tolerance = 0.05)
  mut <- s[ch %in% 5:8]
  expect_equal(mut$night_sleep_min, rep(360, 4), tolerance = 0.03)
  expect_true(all(mut$activity_per_day > wt$activity_per_day))
  daily <- daily_sleep(dc, n_days = 4)
  expect_true(all(daily$day %in% 1:4))
  prof <- zt_profile(dc)
  expect_equal(prof[genotype == "mut" & zt == 20, unique(mean)], 1)
  lb <- light_phase_bouts(sleep_bouts(dc), day = 2)
  expect_true(all(lb$n_bouts >= 1) || nrow(lb) == 0)
})

test_that("statistics compare each test group with each control", {
  x <- load_synthetic()
  s <- per_animal_summary(curate_animals(x$dt, analysis_days = 4)$data)
  cmp <- make_comparisons("mut", c("WT", "ctl2"), extra = data.frame(group = "ctl2", control = "WT"))
  expect_equal(nrow(cmp), 3)
  st <- compare_to_controls(s, cmp, metrics = c(night_sleep_min = "Night sleep"))
  expect_equal(nrow(st), 3 * 2)
  expect_true(all(st$p_holm >= st$p_wilcox))
  expect_true(all(st[group == "mut"]$pct_change < -40))
  gs <- group_summary(s, metrics = "night_sleep_min")
  expect_equal(sum(gs$n), nrow(s[!is.na(night_sleep_min)]))
})

test_that("the pipeline writes tables and figures", {
  d <- synthetic_dir()
  out <- file.path(d, "results")
  res <- suppressMessages(run_dam_experiment(list(
    data_dir = d, out_dir = out, genotypes = c("WT", "ctl2", "mut"), controls = c("WT", "ctl2"),
    tests = "mut", analysis_days = 4, dpi = 60)))
  expect_true(all(file.exists(file.path(out, "tables", c(
    "per_animal_summary.csv", "stats_vs_controls.csv", "sample_sizes.csv",
    "excluded_or_truncated_animals.csv", "group_summary.csv", "daily_sleep.csv")))))
  expect_true(file.exists(file.path(out, "figures", "fig13_sleep_amount_stats.png")))
  expect_true(file.exists(file.path(out, "figures", "supp_actograms_individual.pdf")))
  expect_equal(nrow(res$summary), 13)
})
