# damSleep

Sleep and locomotor activity of single *Drosophila* recorded in Drosophila
Activity Monitors (DAM2), built on the Rethomics packages.

```r
remotes::install_github("khushi-biology/embryo-ifquant", subdir = "r/damSleep")
file.copy(system.file("config", "dam_config_template.R", package = "damSleep"), "dam_config.R")
damSleep::run_dam_experiment("dam_config.R")
```

See [docs/dam-sleep.md](../../docs/dam-sleep.md) for the input format, the
curation rules, the measures, the statistics and the figures.
