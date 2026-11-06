# embryoIFquant (R)

Embryo-level quantification of nuclear immunofluorescence from Fiji intensity
tables. Part of [drosophila-quant](https://github.com/khushi-biology/drosophila-quant).

```r
remotes::install_github("khushi-biology/drosophila-quant", subdir = "r/embryoIFquant")
res <- embryoIFquant::run_experiment("config.R")
```

Configuration template: `system.file("config", "config_template.R", package = "embryoIFquant")`.
Documentation: [../../docs/r-package.md](../../docs/r-package.md) and
[../../docs/statistics.md](../../docs/statistics.md).

Author: Khushi Singh. Licence: MIT.
