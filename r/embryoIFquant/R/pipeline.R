# Configuration and the one-call pipeline.
# Author: Khushi Singh

#' Default pipeline settings
#'
#' @return A named list of every setting with its default value.
#' @export
default_config <- function() {
  list(experiment = "experiment", data_dir = NULL, out_dir = NULL,
       channels = NULL, genotype_rules = NULL, control = NULL, ratios = character(0),
       session_rules = NULL, exclude_files = character(0),
       control_readouts = c("H3", "DAPI", "H3 / DAPI"),
       saturation = 65000, area_quantile = c(0.005, 0.995), centre = "median",
       mixed_model = TRUE, palette = NULL, show_p = FALSE, plot_family = "")
}

#' Read a configuration file
#'
#' A configuration is a small R file that assigns the settings, either in
#' lower case (`channels <- ...`) or in upper case (`CHANNELS <- ...`). Paths
#' are taken relative to the configuration file if they are not absolute.
#'
#' @param path Path of the configuration file.
#' @return A validated configuration list (see [default_config()]).
#' @export
read_config <- function(path) {
  env <- new.env()
  sys.source(path, envir = env)
  cfg <- default_config()
  for (k in names(cfg)) {
    for (nm in c(k, toupper(k))) if (exists(nm, envir = env, inherits = FALSE)) cfg[[k]] <- get(nm, envir = env)
  }
  base <- dirname(normalizePath(path))
  for (k in c("data_dir", "out_dir"))
    if (!is.null(cfg[[k]]) && !grepl("^(/|~|[A-Za-z]:)", cfg[[k]])) cfg[[k]] <- file.path(base, cfg[[k]])
  validate_config(cfg)
}

#' Check a configuration
#'
#' @param cfg A configuration list.
#' @return `cfg`, with missing optional settings filled in.
#' @export
validate_config <- function(cfg) {
  cfg <- utils::modifyList(default_config(), cfg)
  need <- c("data_dir", "out_dir", "channels", "genotype_rules", "control")
  miss <- need[vapply(need, function(k) is.null(cfg[[k]]), logical(1))]
  if (length(miss)) stop("configuration is missing: ", paste(miss, collapse = ", "))
  if (is.null(names(cfg$channels)) || !all(grepl("^C\\d+$", names(cfg$channels))))
    stop("channels must be named C1, C2, ... e.g. c(C1 = \"H3\", C2 = \"H3K18la\", C3 = \"DAPI\")")
  if (!cfg$control %in% names(cfg$genotype_rules))
    stop("control '", cfg$control, "' is not one of the genotype_rules names")
  for (r in cfg$ratios) parse_ratio(r, unname(cfg$channels))
  if (is.null(cfg$palette)) cfg$palette <- default_palette(names(cfg$genotype_rules))
  cfg
}

#' Run the whole pipeline for one experiment
#'
#' Reads the intensity tables, applies QC, computes readouts, embryo values and
#' genotype effects, and writes tables, figures and a log to `cfg$out_dir`:
#'
#' * `tables/nuclei_all.csv`, `tables/design_qc.csv`,
#'   `tables/embryo_values.csv`, `tables/effects_vs_control.csv`
#' * `figures/<readout>.png` (superplots) and `figures/forest_all_readouts.png`
#' * `log.txt`
#'
#' @param cfg A configuration list, or the path of a configuration file.
#' @param plots Write figures.
#' @return A list with `nuclei`, `embryo` and `effects`, invisibly.
#' @export
run_experiment <- function(cfg, plots = TRUE) {
  if (is.character(cfg)) cfg <- read_config(cfg) else cfg <- validate_config(cfg)
  out <- cfg$out_dir
  for (s in c("tables", "figures")) dir.create(file.path(out, s), recursive = TRUE, showWarnings = FALSE)
  logf <- file(file.path(out, "log.txt"), open = "wt")
  sink(logf, split = TRUE)
  on.exit({ sink(); close(logf) })
  cat("Experiment:", cfg$experiment, "\nData:", cfg$data_dir, "\nRun:", format(Sys.time()), "\n\n")

  raw <- parse_names(read_intensity_folder(cfg$data_dir, cfg$exclude_files),
                     cfg$genotype_rules, cfg$session_rules)
  markers <- unname(cfg$channels)
  nuc <- qc_nuclei(to_nuclei(raw, cfg$channels), markers, cfg$saturation, cfg$area_quantile)
  readr::write_csv(nuc, file.path(out, "tables", "nuclei_all.csv"))

  design <- design_table(nuc)
  cat("Design and QC per embryo:\n"); print(as.data.frame(design))
  readr::write_csv(design, file.path(out, "tables", "design_qc.csv"))

  keep <- dplyr::filter(nuc, .data$qc_pass)
  long <- make_long(keep, markers, cfg$ratios)
  emb <- embryo_values(long, cfg$centre)
  readr::write_csv(emb, file.path(out, "tables", "embryo_values.csv"))

  eff <- welch_vs_control(emb, cfg$control)
  mm <- if (isTRUE(cfg$mixed_model)) mixed_vs_control(long, cfg$control) else NULL
  if (!is.null(mm) && nrow(mm)) eff <- dplyr::left_join(eff, mm, by = c("readout", "genotype"))
  eff <- flag_control_readouts(eff, cfg$control_readouts)
  readr::write_csv(eff, file.path(out, "tables", "effects_vs_control.csv"))
  cat("\nEmbryo-level effects (Welch t on log2 embryo values):\n")
  shown <- dplyr::select(eff, "readout", "genotype", "n", "n_ctrl", "fc", "fc_lo", "fc_hi", "p", "p_holm")
  print(as.data.frame(dplyr::mutate(shown, dplyr::across(dplyr::where(is.numeric), ~ signif(.x, 3)))))
  bad <- dplyr::filter(eff, .data$control_failed)
  if (nrow(bad))
    cat("\nWARNING: control readout changed (ratios using it are not interpretable):\n",
        paste(bad$genotype, bad$readout, sprintf("%.2f", bad$fc), collapse = "\n "), "\n")

  if (plots) {
    pal <- cfg$palette[intersect(names(cfg$palette), unique(emb$genotype))]
    for (ro in unique(long$readout)) {
      p <- superplot(long, emb, ro, cfg$control, pal, eff, show_p = cfg$show_p, base_family = cfg$plot_family)
      save_plot(file.path(out, "figures", paste0(gsub("[ /]+", "_", ro), ".png")), p,
                width = 0.6 + 0.55 * length(pal), height = 2.4)
    }
    save_plot(file.path(out, "figures", "forest_all_readouts.png"),
              forest_plot(eff, pal, base_family = cfg$plot_family),
              width = 1.4 + 1.6 * dplyr::n_distinct(eff$readout),
              height = 0.8 + 0.3 * dplyr::n_distinct(eff$genotype))
  }
  cat("\nDone:", nrow(keep), "of", nrow(nuc), "nuclei passed QC.\n")
  invisible(list(nuclei = nuc, embryo = emb, effects = eff))
}
