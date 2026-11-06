# Sleep and activity from DAM recordings (`damSleep`)

`r/damSleep` analyses sleep and locomotor activity of single flies recorded in
Drosophila Activity Monitors (TriKinetics DAM2). It builds on the Rethomics
packages behavr, damr, sleepr and ggetho (Geissmann et al., 2019) and adds
curation, per-fly measures, statistics and figure export in one configurable
pipeline.

## Input

* **Monitor files** `Monitor<k>.txt` as written by the DAM system: one row per
  time bin, the date (`29 Sep 26`) and time in columns 2–3 and the beam
  crossings of channels 1–32 in columns 11–42.
* **Metadata** (`.csv`, comma or semicolon separated), one row per channel:

  | file | region_id | start_datetime | stop_datetime | condition | sex |
  |---|---|---|---|---|---|
  | Monitor1.txt | 1 | 2026-09-29 09:30:00 | 2026-10-06 09:30:00 | WT | F |

  The **time of `start_datetime` is ZT0 (lights-on)**: every day/night measure
  depends on it, so use the incubator's real lights-on time. Leave genotype and
  sex empty (or write `EMPTY`) for empty tubes. `make_metadata_template()`
  writes an empty table.

If the recording computer had the wrong date, `shift_monitor_dates()` writes a
corrected copy of a monitor file (clock times unchanged); the raw file is never
changed.

## Running

```r
file.copy(system.file("config", "dam_config_template.R", package = "damSleep"), "dam_config.R")
# edit data_dir, metadata, out_dir, genotypes, controls, tests, analysis_days ...
res <- damSleep::run_dam_experiment("dam_config.R")
```

or `Rscript r/damSleep/inst/scripts/run_dam.R dam_config.R`. Every setting
and its default is listed by `damSleep::dam_config_defaults()`.

## What the pipeline does

1. **Sleep annotation.** A fly is asleep during any period of at least
   `min_immobile_min` (default 5) minutes without a beam crossing.
2. **Curation.**
   * Flies dead or inactive from the start are removed
     (`sleepr::curate_dead_animals`: 24 h with < 1 % moving).
   * A death call made at least `end_tolerance_days` (1) before the end of the
     analysis window is accepted: the fly is kept up to its death if it lived
     longer than `min_lifespan_days` (2), otherwise removed.
   * A death call closer to the end is a long final sleep, not death (there are
     no later data to show the fly woke up), so that fly's full data are kept.
   * Data are trimmed to `[0, analysis_days]` days from ZT0.
   Every removed, truncated or restored fly is listed with the reason in
   `excluded_or_truncated_animals.csv`.
3. **Per-fly measures** (`per_animal_summary.csv`). Light = first
   `light_hours` of each `period_hours` cycle.

   | Measure | Definition |
   |---|---|
   | `total_sleep_min_day` | fraction of time asleep × 1440 |
   | `day_sleep_min`, `night_sleep_min` | fraction asleep in light / dark × minutes of that phase |
   | `n_bouts_L_day`, `n_bouts_D_day` | sleep bouts starting in light / dark, per recorded day |
   | `mean_bout_L_min`, `mean_bout_D_min` | mean length of those bouts |
   | `latency_night_min` | lights-off to first sleep bout, mean over nights |
   | `activity_per_day` | beam crossings per recorded day |
   | `activity_per_wake_min` | beam crossings per minute awake (separates hypoactivity from more sleep) |

   Also written: the light-phase bout summary of one day
   (`light_phase_bouts_day2.csv`: latency, first and longest bout) and the
   total sleep of each day (`daily_sleep.csv`, days with ≥ 90 % of the bins).
4. **Statistics** (`stats_vs_controls.csv`, `group_summary.csv`). For each
   measure and sex: Kruskal–Wallis across genotypes, and a two-sided Wilcoxon
   rank-sum test of every test genotype against every control (plus any extra
   pairs, e.g. one control against the other), with Holm correction across the
   comparisons of that measure and sex. The fly is the replicate.
5. **Figures** (`figures/`): activity and sleep tiles of every fly (QC),
   population sleep and activity over the whole recording and folded over one
   cycle, sleep fraction overall / light / dark, bout length over the cycle,
   bouts against bout length, double-plotted actograms (per genotype and per
   fly), each test genotype's daily sleep profile against the controls, daily
   total sleep, and box plots of the measures with significance symbols
   (`*` vs the first control, `#` vs the second, ...).

## Checks before trusting a result

* **ZT0.** In the profile figures the evening activity peak should be just
  before ZT12 and the morning peak just before ZT0/24. If the peaks are shifted,
  `start_datetime` is not the lights-on time and the day/night measures are
  wrong.
* **Controls.** If the two controls differ from each other as much as the
  mutants differ from them, genetic background, not the mutation, may explain
  the difference.
* **Sex.** Females and males sleep differently and are always analysed
  separately.

## Functions

| Step | Functions |
|---|---|
| Metadata and files | `read_dam_metadata`, `make_metadata_template`, `shift_monitor_dates` |
| Loading and curation | `load_dam_sleep`, `bin_seconds`, `curate_animals`, `sample_sizes` |
| Measures | `per_animal_summary`, `sleep_bouts`, `light_phase_bouts`, `daily_sleep`, `zt_profile` |
| Statistics | `default_metrics`, `make_comparisons`, `compare_to_controls`, `group_summary` |
| Figures | `plot_tiles`, `plot_population`, `plot_phase_fractions`, `plot_bout_length`, `plot_light_bouts`, `plot_actogram`, `write_individual_actograms`, `plot_profiles_vs_controls`, `plot_daily_sleep`, `plot_metric_stats`, `theme_dam`, `genotype_colours`, `sex_colours` |
| Pipeline | `dam_config_defaults`, `run_dam_experiment` |

Each function is documented in R (`?damSleep::per_animal_summary`).

## References

* Geissmann Q, Garcia Rodriguez L, Beckwith EJ, Gilestro GF (2019). Rethomics:
  an R framework to analyse high-throughput behavioural data. PLoS One 14,
  e0209331.
* Hendricks JC et al. (2000). Rest in Drosophila is a sleep-like state.
  Neuron 25, 129–138.
* Shaw PJ, Cirelli C, Greenspan RJ, Tononi G (2000). Correlates of sleep and
  waking in Drosophila melanogaster. Science 287, 1834–1837.
