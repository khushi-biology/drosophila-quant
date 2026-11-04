# Pipeline configuration

`embryoIFquant::run_experiment()` takes a list or the path of an R file that
assigns the settings below (lower or upper case). Relative paths are resolved
against the configuration file. Start from the template:

```r
file.copy(system.file("config", "config_template.R", package = "embryoIFquant"), "config.R")
```

| Setting | Required | Default | Meaning |
|---|---|---|---|
| `experiment` | | `"experiment"` | Name written to the log |
| `data_dir` | yes | | Folder with the `*.tif_intensity.csv` tables |
| `out_dir` | yes | | Output folder (`tables/`, `figures/`, `log.txt`) |
| `channels` | yes | | `c(C1 = "H3", C2 = "MARK", C3 = "DAPI")` |
| `genotype_rules` | yes | | Ordered `genotype = regex` on the file name |
| `control` | yes | | Reference genotype (one of the rule names) |
| `ratios` | | none | `"A / B"` readouts with A, B among the markers |
| `control_readouts` | | `H3`, `DAPI`, `H3 / DAPI` | Readouts expected not to change; changes are flagged |
| `exclude_files` | | none | Regexes of files to skip |
| `session_rules` | | `NULL` | Ordered `session = regex`, kept as a column |
| `saturation` | | `65000` | Pixel value treated as saturated |
| `area_quantile` | | `c(0.005, 0.995)` | Nuclear area range kept |
| `centre` | | `"median"` | `"median"` or `"mean"` for nucleus → image → embryo |
| `mixed_model` | | `TRUE` | Fit the lmerTest check |
| `show_p` | | `FALSE` | Print P values on the superplots |
| `plot_family` | | `""` | Font family of the plots |
| `palette` | | colour-blind-safe | Named colours; also sets the genotype order |

## Outputs

| File | Content |
|---|---|
| `tables/nuclei_all.csv` | Every nucleus: identifiers, area, channel means and maxima, QC flags |
| `tables/design_qc.csv` | Per embryo: images, nuclei, nuclei passing QC, saturated, area outliers |
| `tables/embryo_values.csv` | The biological replicates, per readout |
| `tables/effects_vs_control.csv` | Fold change, 95% CI, P, Holm P, mixed-model check, control flags |
| `figures/<readout>.png` | Superplot per readout |
| `figures/forest_all_readouts.png` | All effects at a glance |
| `log.txt` | Design, effects and warnings |

## Several configurations

```bash
Rscript "$(Rscript -e 'cat(system.file("scripts", "run_pipeline.R", package = "embryoIFquant"))')" configs/*.R
```
