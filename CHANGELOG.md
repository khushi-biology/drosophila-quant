# Changelog

## 0.1.0 (2026-11-04)

First release.

* R package `embryoIFquant`: Fiji intensity tables → QC → within-nucleus ratios →
  embryo values → Welch t / Holm with mixed-model check; combining sessions,
  count data, sample size; superplots and forest plots; one-call pipeline from a
  configuration file.
* Python package `embryo_ifquant`: TIFF/CZI/Fiji input, automatic nuclear
  segmentation and re-measurement, embryo overviews, whole-animal fluorescence,
  micrograph grids, multi-panel figures, editable SVG export, Word / PowerPoint /
  PDF helpers and the `embryo-ifquant` command-line tool.
