# R package `embryoIFquant`: function reference

Full help for every function: `help(package = "embryoIFquant")`.

| Step | Function | Purpose |
|---|---|---|
| Read | `read_intensity_folder(dir, exclude)` | All Fiji tables of a folder |
| | `read_intensity_table(file)` | One table |
| | `parse_names(d, genotype_rules, session_rules)` | Genotype, embryo, image, ROI, channel |
| | `match_rules(x, rules)` | Ordered regex classification |
| QC | `to_nuclei(d, channels)` | One row per nucleus, one column per marker |
| | `qc_nuclei(n, markers, saturation, area_quantile)` | Saturation and area flags |
| Readouts | `make_long(n, markers, ratios)` | Raw channels and within-nucleus ratios |
| Replicates | `embryo_values(long, centre)` | Nucleus → image → embryo |
| | `design_table(nuclei)` | Images, nuclei and QC per embryo |
| | `geometric_mean(x)`, `relative_to_control(d, control)` | Helpers |
| Statistics | `welch_vs_control(emb, control)` | Fold change, 95% CI, P, Holm P |
| | `mixed_vs_control(long, control)` | Mixed-model check (lmerTest) |
| | `flag_control_readouts(eff, control_readouts)` | Flags changed control readouts |
| | `combine_experiments(d, control, genotypes)` | Sessions combined on a relative scale |
| | `combine_sessions(emb_files, control, genotype)` | Same, from `embryo_values.csv` files |
| | `counts_vs_control(d, control)` | Wilcoxon + Holm for counts |
| | `power_embryos(emb, control, fold_changes)` | Embryos needed; smallest detectable change |
| Plots | `superplot(long, emb, readout, control, palette)` | Nuclei + embryos + geometric mean ± s.d. |
| | `forest_plot(eff, palette)` | All effects |
| | `theme_pub()`, `default_palette()`, `format_p_plotmath()` | Styling |
| | `save_plot(file, plot, width, height, vector)` | PNG and optional vector PDF |
| Pipeline | `default_config()`, `read_config(path)`, `validate_config(cfg)` | Settings |
| | `run_experiment(cfg)` | Everything above in one call |

## Example: step by step

```r
library(embryoIFquant)
raw <- parse_names(read_intensity_folder("intensity_tables"),
                   c(WT = "^WT_", MutA = "^MutA_"))
nuc <- qc_nuclei(to_nuclei(raw, c(C1 = "H3", C2 = "MARK", C3 = "DAPI")), c("H3", "MARK", "DAPI"))
long <- make_long(subset(nuc, qc_pass), c("H3", "MARK", "DAPI"), c("MARK / H3", "MARK / DAPI"))
emb <- embryo_values(long)
eff <- welch_vs_control(emb, "WT")
superplot(long, emb, "MARK / H3", "WT", default_palette(c("WT", "MutA")))
```
