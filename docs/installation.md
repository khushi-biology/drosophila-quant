# Installation

## R package `embryoIFquant`

Requires R ≥ 4.1 and the packages dplyr, tidyr, readr, stringr, purrr, tibble,
ggplot2 and rlang. Optional: ggbeeswarm (nicer point layout), lmerTest and lme4
(mixed-model check), testthat (tests).

```r
install.packages("remotes")
remotes::install_github("khushi-biology/drosophila-quant", subdir = "r/embryoIFquant")
```

From a local copy of the repository:

```bash
R CMD INSTALL r/embryoIFquant
```

## R package `damSleep` (DAM sleep and activity)

Requires the Rethomics packages behavr, damr, sleepr and ggetho, plus
data.table, ggplot2 and scales.

```r
install.packages(c("behavr", "damr", "sleepr", "ggetho", "data.table", "ggplot2", "scales"))
# if a Rethomics package is not available from CRAN:
# remotes::install_github(c("rethomics/behavr", "rethomics/damr", "rethomics/sleepr", "rethomics/ggetho"))
remotes::install_github("khushi-biology/drosophila-quant", subdir = "r/damSleep")
```

## Python package `embryo_ifquant`

Requires Python ≥ 3.9. Core dependencies: numpy, scipy, scikit-image,
tifffile, Pillow, matplotlib.

```bash
pip install "embryo-ifquant[all] @ git+https://github.com/khushi-biology/drosophila-quant.git#subdirectory=python"
```

| Extra | Adds | Needed for |
|---|---|---|
| `czi` | czifile, imagecodecs | Zeiss `.czi` files |
| `roi` | roifile | ImageJ ROI sets (`.zip`, `.roi`) |
| `office` | python-docx, python-pptx, lxml, PyMuPDF | Word, PowerPoint, PDF helpers, PDF → SVG |
| `all` | all of the above | |
| `dev` | all + pytest | running the tests |

For development:

```bash
cd python
python -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"
pytest
```

The command-line tool `embryo-ifquant` is installed with the package
(`embryo-ifquant --help`).
