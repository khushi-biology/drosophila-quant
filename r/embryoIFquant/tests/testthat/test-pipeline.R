test_that("the pipeline recovers a known effect", {
  dir <- write_synthetic(file.path(tempdir(), "syn"))
  cfg <- synthetic_config(dir, file.path(tempdir(), "syn_out"))
  res <- suppressMessages(run_experiment(cfg, plots = FALSE))
  expect_true(any(res$nuclei$flag_saturated))
  emb <- res$embryo
  expect_equal(nrow(dplyr::filter(emb, readout == "MARK / H3")), 9)
  eff <- res$effects
  a <- dplyr::filter(eff, readout == "MARK / H3", genotype == "MutA")
  b <- dplyr::filter(eff, readout == "MARK / H3", genotype == "MutB")
  expect_gt(a$fc, 1.35); expect_lt(a$fc, 1.65); expect_lt(a$p, 0.01)
  expect_gt(b$fc, 0.85); expect_lt(b$fc, 1.15)
  expect_true(all(c("p_holm", "control_failed") %in% names(eff)))
  expect_true(file.exists(file.path(cfg$out_dir, "tables", "effects_vs_control.csv")))
})

test_that("ratios must use known markers", {
  cfg <- synthetic_config("x", "y"); cfg$ratios <- "MARK / NOPE"
  expect_error(validate_config(cfg), "ratio")
})

test_that("combine_experiments removes session offsets", {
  set.seed(2)
  d <- expand.grid(experiment = c("e1", "e2"), genotype = c("WT", "MUT"), rep = 1:4,
                   stringsAsFactors = FALSE)
  d$readout <- "r"
  d$value <- ifelse(d$experiment == "e2", 10, 1) * ifelse(d$genotype == "MUT", 2, 1) * exp(rnorm(nrow(d), 0, 0.05))
  res <- combine_experiments(tibble::as_tibble(d), "WT")
  expect_equal(res$fc, 2, tolerance = 0.1)
  expect_equal(res$n_experiments, 2)
})

test_that("counts_vs_control and power_embryos return sensible values", {
  d <- tibble::tibble(genotype = rep(c("WT", "MUT"), each = 10), value = c(rep(50, 10), rep(10, 10)) + 0:9)
  expect_lt(counts_vs_control(d, "WT")$p, 0.001)
  emb <- tibble::tibble(readout = "r", genotype = "WT", value = 2^rnorm(6, 0, 0.2))
  pw <- power_embryos(emb, "WT", fold_changes = 0.5, n_current = 3)
  expect_true(pw$n_fc_0.5 >= 2)
})
