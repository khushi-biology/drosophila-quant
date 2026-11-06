# Package documentation.
# Author: Khushi Singh

#' damSleep: sleep and activity from Drosophila Activity Monitor recordings
#'
#' The workflow, in order of use:
#'
#' 1. [read_dam_metadata()] reads the plate layout (one row per monitor
#'    channel), drops empty wells and corrects labels;
#'    [make_metadata_template()] writes an empty layout and
#'    [shift_monitor_dates()] corrects the date of a monitor file whose clock
#'    was wrong.
#' 2. [load_dam_sleep()] links the metadata to the monitor files and annotates
#'    sleep (immobility of at least 5 min).
#' 3. [curate_animals()] removes dead animals, truncates flies that died during
#'    the run and restores flies that were only asleep at the end; it also
#'    trims the data to the analysis window.
#' 4. [per_animal_summary()], [sleep_bouts()], [light_phase_bouts()],
#'    [daily_sleep()] and [zt_profile()] summarise each fly.
#' 5. [compare_to_controls()] and [group_summary()] give the statistics.
#' 6. The `plot_*()` functions draw the figures.
#'
#' [run_dam_experiment()] runs steps 1-6 from one configuration file.
#'
#' The time axis is the one used by Rethomics: `t` in seconds from ZT0, the
#' lights-on time given in `start_datetime` of the metadata.
#'
#' @keywords internal
#' @import data.table
#' @importFrom behavr rejoin xmv days hours mins
"_PACKAGE"

.datatable.aware <- TRUE

utils::globalVariables(c(
  ".", ".N", ".SD", "id", "t", "asleep", "activity", "moving", "phase", "duration",
  "lifespan", "reason", "file_info", "region_id", "sex", "night", "lat", "n", "n_L", "n_D",
  "mean_len_L", "mean_len_D", "days_recorded", "total_activity", "awake_min",
  "sleep_fraction_all", "sleep_fraction_l", "sleep_fraction_d", "sleep_fraction",
  "zt", "panel", "line", "value", "metric", "day", "sleep_min", "se", "y", "label",
  "group", "control", "signif", "p_holm", "p_wilcox", "curated_lifespan_h",
  "hours_trimmed_by_curation", "v", ".all", "by_value", "pct_change", "median_group",
  "median_control", "kruskal_p", "sym", "mark", "n_bouts", "mean_bout_length", "d"))
