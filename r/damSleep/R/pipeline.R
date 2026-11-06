# One-call pipeline from a configuration file.
# Author: Khushi Singh

#' Default configuration
#'
#' Every setting of [run_dam_experiment()] with its default. A configuration
#' file only needs the settings that differ.
#'
#' @return A named list.
#' @export
dam_config_defaults <- function() {
  list(
    data_dir = NULL,              # folder with the monitor files and the metadata
    metadata = "metadata.csv",    # metadata file, relative to data_dir
    out_dir = "dam_results",      # tables/ and figures/ are written here
    group_col = "condition",      # genotype column in the metadata
    genotypes = NULL,             # plotting order (NULL: as in the metadata)
    controls = NULL,              # control genotypes
    tests = NULL,                 # test genotypes (NULL: all non-controls)
    extra_comparisons = NULL,     # data.frame(group, control), e.g. control vs control
    recode = NULL,                # label corrections, c(old = "new")
    start_datetime = NULL,        # override the metadata dates
    stop_datetime = NULL,
    analysis_days = 7,            # days analysed from ZT0
    min_lifespan_days = 2,        # flies that died earlier are removed
    end_tolerance_days = 1,       # death calls this close to the end = trailing sleep
    min_immobile_min = 5,         # immobility that counts as sleep (min)
    light_hours = 12,             # light phase (h)
    period_hours = 24,            # cycle length (h)
    latency_day = 2,              # day used for the light-phase bout summary
    metrics = default_metrics(),  # measures that are tested
    figures = TRUE,               # write the figures
    dpi = 300
  )
}

read_config <- function(config) {
  cfg <- dam_config_defaults()
  if (is.character(config)) {
    env <- new.env()
    sys.source(config, envir = env)
    user <- as.list(env)
  } else user <- config
  unknown <- setdiff(names(user), names(cfg))
  if (length(unknown)) warning("unknown configuration setting(s): ", paste(unknown, collapse = ", "))
  cfg[names(user)] <- user
  if (is.null(cfg$data_dir)) stop("data_dir must be set")
  if (is.null(cfg$controls)) stop("controls must be set")
  cfg
}

#' Run a complete DAM sleep and activity analysis
#'
#' Reads the metadata and monitor files, removes dead animals, summarises each
#' fly, compares each test genotype with each control (by sex) and writes
#' tables and figures to `out_dir`:
#'
#' * `tables/`: `sample_sizes.csv`, `excluded_or_truncated_animals.csv`,
#'   `per_animal_summary.csv`, `light_phase_bouts_day<k>.csv`,
#'   `daily_sleep.csv`, `group_summary.csv`, `stats_vs_controls.csv`,
#'   `R_sessionInfo.txt`;
#' * `figures/`: quality-control tiles, sleep and activity profiles, sleep
#'   fractions, bout lengths, actograms (population and per fly), profiles of
#'   each test genotype against the controls, daily sleep and the summary
#'   statistics.
#'
#' @param config Path of a configuration file (R code assigning the settings
#'   of [dam_config_defaults()]) or a named list.
#' @return Invisibly, a list with `config`, `data` (curated), `excluded`,
#'   `sample_sizes`, `summary`, `bouts`, `light_bouts`, `daily`, `stats` and
#'   `group_summary`.
#' @export
run_dam_experiment <- function(config) {
  cfg <- read_config(config)
  tab_dir <- file.path(cfg$out_dir, "tables"); fig_dir <- file.path(cfg$out_dir, "figures")
  dir.create(tab_dir, recursive = TRUE, showWarnings = FALSE)
  if (cfg$figures) dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
  out_tab <- function(x, name) data.table::fwrite(x, file.path(tab_dir, name))
  out_fig <- function(p, name, w, h) ggplot2::ggsave(file.path(fig_dir, name), p, width = w, height = h,
                                                     dpi = cfg$dpi, bg = "white")

  md <- read_dam_metadata(file.path(cfg$data_dir, cfg$metadata), group_col = cfg$group_col,
                          recode = cfg$recode, start_datetime = cfg$start_datetime,
                          stop_datetime = cfg$stop_datetime)
  genotypes <- cfg$genotypes %||% unique(md$genotype)
  tests <- cfg$tests %||% setdiff(genotypes, cfg$controls)
  dt <- load_dam_sleep(md, cfg$data_dir, genotype_levels = genotypes, min_immobile_min = cfg$min_immobile_min)
  bin_s <- bin_seconds(dt)

  cur <- curate_animals(dt, cfg$analysis_days, cfg$min_lifespan_days, cfg$end_tolerance_days)
  dc <- cur$data
  n <- sample_sizes(dt, dc)
  out_tab(cur$excluded, "excluded_or_truncated_animals.csv")
  out_tab(n, "sample_sizes.csv")

  s <- per_animal_summary(dc, cfg$light_hours, cfg$period_hours, bin_s)
  bouts <- sleep_bouts(dc)
  lb <- light_phase_bouts(bouts, cfg$latency_day, cfg$light_hours, cfg$period_hours)
  daily <- daily_sleep(dc, cfg$analysis_days, period_hours = cfg$period_hours, bin_s = bin_s)
  cmp <- make_comparisons(tests, cfg$controls, cfg$extra_comparisons)
  st <- compare_to_controls(s, cmp, cfg$metrics)
  gs <- group_summary(s, cfg$metrics)
  out_tab(s, "per_animal_summary.csv")
  out_tab(s[, list(id, genotype, sex)][lb, on = "id"], sprintf("light_phase_bouts_day%d.csv", cfg$latency_day))
  out_tab(daily, "daily_sleep.csv")
  out_tab(st, "stats_vs_controls.csv")
  out_tab(gs, "group_summary.csv")
  writeLines(utils::capture.output(utils::sessionInfo()), file.path(tab_dir, "R_sessionInfo.txt"))

  if (cfg$figures) {
    ng <- length(genotypes); h <- max(6, 1.6 * ng)
    out_fig(plot_tiles(dt, "activity"), "fig01_QC_activity_tile.png", 10, 3 * ng)
    out_fig(plot_tiles(dt, "asleep"), "fig02_QC_sleep_tile.png", 10, 3 * ng)
    out_fig(plot_population(dc, "asleep"), "fig03_sleep_profile.png", 11, h)
    out_fig(plot_population(dc, "asleep", cfg$period_hours), "fig04_sleep_profile_wrapped.png", 7, h)
    out_fig(plot_phase_fractions(s), "fig05_sleep_fraction_LD_boxplot.png", 7, h + 1)
    out_fig(plot_bout_length(bouts, cfg$period_hours), "fig06_bout_length_wrapped.png", 7, h)
    out_fig(plot_light_bouts(lb, s, cfg$latency_day), sprintf("fig07_bouts_vs_length_day%d.png", cfg$latency_day), 6, h)
    out_fig(plot_population(dc, "activity", cfg$period_hours,
                            ylab = sprintf("Activity (beam crossings / %g s)", bin_s)),
            "fig08_activity_profile_wrapped.png", 7, h)
    out_fig(plot_population(dc, "activity", ylab = sprintf("Activity (beam crossings / %g s)", bin_s)),
            "fig09_activity_profile.png", 11, h)
    out_fig(plot_actogram(dc), "fig10_actogram_double_plotted.png", 11, 7)
    write_individual_actograms(dc, file.path(fig_dir, "supp_actograms_individual.pdf"))
    out_fig(plot_profiles_vs_controls(dc, tests, cfg$controls, light_hours = cfg$light_hours,
                                      period_hours = cfg$period_hours),
            "fig11_sleep_profile_tests_vs_controls.png", 3 * length(tests), 6)
    out_fig(plot_daily_sleep(daily, genotype_colours(genotypes, cfg$controls)), "fig12_daily_total_sleep.png", 10, 4.5)
    groups <- list(c("total_sleep_min_day", "day_sleep_min", "night_sleep_min"),
                   c("n_bouts_L_day", "n_bouts_D_day", "mean_bout_L_min", "mean_bout_D_min"),
                   c("latency_night_min", "activity_per_day", "activity_per_wake_min"))
    names(groups) <- c("fig13_sleep_amount_stats.png", "fig14_sleep_architecture_stats.png",
                       "fig15_latency_activity_stats.png")
    for (f in names(groups)) {
      ms <- intersect(groups[[f]], names(cfg$metrics))
      if (length(ms)) out_fig(plot_metric_stats(s, st, cfg$metrics[ms], cfg$controls, tests), f, 9,
                              2.6 * length(ms) + 1)
    }
  }
  message("DAM analysis written to ", normalizePath(cfg$out_dir))
  invisible(list(config = cfg, data = dc, excluded = cur$excluded, sample_sizes = n, summary = s,
                 bouts = bouts, light_bouts = lb, daily = daily, stats = st, group_summary = gs))
}
