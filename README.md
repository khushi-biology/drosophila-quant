# drosophila-quant

Analysis tools for *Drosophila* experiments, from raw data to statistics,
publication figures and the documents that report them:

* **nuclear immunofluorescence in embryos** (for example histone
  modifications) imaged by confocal microscopy, quantified at the level of the
  embryo;
* **sleep and locomotor activity** of single flies recorded in Drosophila
  Activity Monitors (DAM).

The immunofluorescence tools share one data format, the per-nucleus intensity
table written by Fiji (ROI Manager → *Multi Measure*):

| Part | Language | What it does |
|---|---|---|
| [`r/embryoIFquant`](r/embryoIFquant) | R | Reads the Fiji tables, quality-controls nuclei, forms within-nucleus ratios, summarises nuclei → images → **embryos** (the biological replicates), tests each genotype against the control, combines imaging sessions, draws superplots and forest plots, estimates sample size. |
| [`python/`](python) (`embryo_ifquant`) | Python | Reads TIFF/CZI images and Fiji ROI sets, segments nuclei automatically (robustness check), re-measures channels, documents embryo stage from low-magnification overviews, measures whole-animal sensor fluorescence, builds micrograph grids and multi-panel figures, exports editable SVG, and automates Word / PowerPoint / PDF details (clickable citations, reference formatting, tracked changes, slide animations, PDF size). |

```
 confocal stacks ──► Fiji: crop, draw nuclear ROIs, Multi Measure
        │                         │
        │                         ▼
        │              <image>.tif_intensity.csv   ◄── embryo-ifquant resegment (automatic ROIs)
        │                         │
        │                         ▼
        │            embryoIFquant::run_experiment(config)
        │              QC → readouts → embryo values → effects → plots
        ▼                         │
 embryo_ifquant.figures ◄─────────┘  grids, panels, SVG
        │
        ▼
 embryo_ifquant.office: Word / PowerPoint / PDF
```

The sleep tools are a separate R package:

| Part | Language | What it does |
|---|---|---|
| [`r/damSleep`](r/damSleep) | R | Reads DAM monitor files and the plate layout, annotates sleep (≥ 5 min immobility), removes dead flies without mistaking a final long sleep for death, summarises each fly (total, day and night sleep, bout number and length, latency, activity per waking minute), compares each mutant with each control by sex (Wilcoxon, Holm) and writes QC tiles, sleep and activity profiles, actograms and annotated summary plots. See [docs/dam-sleep.md](docs/dam-sleep.md). |

## Installation

**R package**

```r
# install.packages("remotes")
remotes::install_github("khushi-biology/drosophila-quant", subdir = "r/embryoIFquant")
remotes::install_github("khushi-biology/drosophila-quant", subdir = "r/damSleep")   # DAM sleep
```

**Python package** (Python ≥ 3.9)

```bash
pip install "embryo-ifquant[all] @ git+https://github.com/khushi-biology/drosophila-quant.git#subdirectory=python"
```

The extras are `czi` (Zeiss files), `roi` (ImageJ ROI sets), `office` (Word,
PowerPoint, PDF) and `all`. See [docs/installation.md](docs/installation.md).

## Quick start

1. Export one intensity table per image from Fiji, named
   `<genotype>_<stain>_<embryo>-<field>[-<crop>].tif_intensity.csv`
   ([docs/file-naming.md](docs/file-naming.md)).
2. Copy the configuration template and edit the channels, genotypes and ratios:

   ```r
   file.copy(system.file("config", "config_template.R", package = "embryoIFquant"), "config.R")
   ```

3. Run the pipeline:

   ```r
   res <- embryoIFquant::run_experiment("config.R")
   res$effects   # fold change vs control, 95% CI, P, Holm P, mixed-model check
   ```

   Tables, superplots, a forest plot and a log are written to `out_dir`.

4. Optional checks and figures in Python:

   ```bash
   embryo-ifquant resegment crops/ auto_rois/ --dna-channel 2   # ROI-independent re-analysis
   ```

   ```python
   from embryo_ifquant.figures import GridRow, image_grid, BLUE, GREEN
   image_grid(images, [GridRow("DNA", "DAPI", BLUE), GridRow("Mark", "MARK", GREEN), GridRow("Merge", None)],
              pixel_size_um=0.13, out_path="grid.png")
   ```

A complete example on synthetic data is in [examples/](examples).

## Statistical design in brief

* **QC**: a nucleus is dropped if any channel is saturated (≥ 65000 in 16-bit)
  or its area lies outside the 0.5th–99.5th percentile of the experiment.
* **Readouts**: raw channel means and within-nucleus ratios (mark / total H3,
  mark / DNA, H3 / DNA). Ratios cancel imaging depth, illumination and nuclear
  volume because both channels come from the same nucleus.
* **Replicate**: the embryo. Embryo value = median over images of the median
  over nuclei. Nuclei are never used as independent replicates.
* **Test**: Welch t test on log2 embryo values, each genotype against the
  control, Holm correction across genotypes; a mixed model on all nuclei
  (`log2 value ~ genotype + (1|embryo) + (1|image)`) as a check.
* **Sessions**: raw intensities are never pooled across imaging sessions; each
  embryo is expressed relative to the control of its own session.

Details and the reasoning: [docs/statistics.md](docs/statistics.md).

## Documentation

| Page | Content |
|---|---|
| [docs/workflow.md](docs/workflow.md) | End-to-end workflow from acquisition to figures |
| [docs/file-naming.md](docs/file-naming.md) | File names the parser understands |
| [docs/configuration.md](docs/configuration.md) | Every pipeline setting |
| [docs/statistics.md](docs/statistics.md) | QC, replicate hierarchy, tests, combining sessions, power |
| [docs/r-package.md](docs/r-package.md) | R function reference |
| [docs/python-package.md](docs/python-package.md) | Python module reference and command-line tool |
| [docs/documents.md](docs/documents.md) | Word, PowerPoint and PDF helpers |
| [docs/dam-sleep.md](docs/dam-sleep.md) | DAM sleep and activity: input, curation, measures, statistics, figures |

## Repository layout

```
drosophila-quant/
├── r/embryoIFquant/          R package: embryo immunofluorescence (R/, man/, tests/, inst/)
├── r/damSleep/               R package: DAM sleep and activity (R/, man/, tests/, inst/)
├── python/                   Python package
│   ├── src/embryo_ifquant/
│   │   ├── io/               TIFF, CZI, Fiji tables and ROI sets
│   │   ├── imaging/          nuclei, re-measurement, embryo overviews, whole animal
│   │   ├── figures/          display, grids, panels, vector export
│   │   ├── office/           Word, PowerPoint, PDF, references
│   │   └── cli.py            command-line tool
│   └── tests/
├── examples/                 synthetic data generator and example configuration
└── docs/                     documentation
```

No raw data, results or images are kept in this repository.

## Testing

```bash
cd python && pip install -e ".[dev]" && pytest
Rscript -e 'testthat::test_local("r/embryoIFquant")'
Rscript -e 'testthat::test_local("r/damSleep")'
```

## Citation

If you use this code, please cite it as described in [CITATION.cff](CITATION.cff).

## Licence

MIT © 2026 Khushi Singh. See [LICENSE](LICENSE).
