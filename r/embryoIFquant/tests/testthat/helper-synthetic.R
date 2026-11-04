# Synthetic Fiji intensity tables: 3 genotypes x 3 embryos x 2 images x 30 nuclei,
# channels C1 = H3, C2 = MARK, C3 = DAPI. MutA has 1.5x MARK, MutB is unchanged.
write_synthetic <- function(dir, seed = 1) {
  set.seed(seed)
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  effect <- c(WT = 1, MutA = 1.5, MutB = 1)
  for (g in names(effect)) for (e in 1:3) for (i in 1:2) {
    stem <- sprintf("%s_stain_%d-%d.tif", g, e, i)
    emb <- exp(rnorm(1, 0, 0.05))
    rows <- list(); k <- 0
    for (r in 1:30) {
      h3 <- 1000 * emb * exp(rnorm(1, 0, 0.1)); dapi <- 800 * exp(rnorm(1, 0, 0.1))
      mark <- 0.5 * h3 * effect[[g]] * exp(rnorm(1, 0, 0.1))
      area <- runif(1, 15, 25)
      mx <- if (g == "WT" && e == 1 && i == 1 && r == 1) 65535 else 30000
      for (c in 1:3) {
        k <- k + 1
        rows[[k]] <- data.frame(` ` = k, Label = sprintf("%s_ROI%d_C%d", stem, r, c), Area = area,
                                Mean = c(h3, mark, dapi)[c], Min = 0, Max = mx, check.names = FALSE)
      }
    }
    utils::write.csv(do.call(rbind, rows), file.path(dir, paste0(stem, "_intensity.csv")), row.names = FALSE)
  }
  dir
}

synthetic_config <- function(dir, out) {
  list(data_dir = dir, out_dir = out, channels = c(C1 = "H3", C2 = "MARK", C3 = "DAPI"),
       genotype_rules = c(WT = "^WT_", MutA = "^MutA_", MutB = "^MutB_"), control = "WT",
       ratios = c("MARK / H3", "MARK / DAPI", "H3 / DAPI"), mixed_model = FALSE)
}
