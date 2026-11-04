# Statistical design

## Levels of the data

```
genotype ─► embryo (biological replicate) ─► image ─► nucleus (technical)
```

Hundreds of nuclei per embryo are not independent: they share the embryo's
genotype, mother, fixation, staining and mounting. Treating nuclei as
replicates inflates the sample size and gives misleadingly small P values. The
embryo is therefore the unit of every test.

## Quality control

A nucleus is excluded if

* any channel reaches the saturation value (default 65000 for 16-bit data), or
* its area lies outside the 0.5th–99.5th percentile of the experiment
  (fragments and merged nuclei).

`design_qc.csv` reports how many nuclei each rule removed per embryo.

## Readouts

* **Raw channels**: mean intensity per nucleus.
* **Within-nucleus ratios**, e.g. mark / H3, mark / DAPI and H3 / DAPI. Both
  channels come from the same pixels, so depth, local illumination and nuclear
  volume cancel. Total H3 and DNA are *control readouts*: if they themselves
  change between genotypes, ratios using them as denominator cannot be
  interpreted, and the pipeline flags this.

## Embryo values

Embryo value = median over images of the median over nuclei of that image.
Taking image medians first keeps an embryo with many images or many nuclei per
image from dominating.

## Effects

For every readout, each genotype is compared with the control by a two-sided
Welch t test on log2 embryo values. The fold change is the ratio of geometric
means with its 95% confidence interval. P values are Holm-adjusted across the
genotypes of a readout.

As a check, a linear mixed model is fitted on all nuclei,
`log2(value) ~ genotype + (1 | embryo) + (1 | image)`. Agreement between the two
analyses is expected; a singular fit on the embryo term is reported.

## Combining sessions

Absolute intensities differ between staining and imaging sessions (antibody
lot, laser power, detector settings). Raw values are therefore never pooled.
Each embryo is divided by the control geometric mean of its own session and the
combined effect is estimated by `lm(log2(rel) ~ session + genotype)`; the
session × genotype interaction tests whether the effect differs between
sessions (`combine_experiments()`, `combine_sessions()`).

## Count data

Counts with many zeros (e.g. eggs laid per female) are compared with the
control by a two-sided Wilcoxon rank-sum test with Holm correction; the
individual is the replicate (`counts_vs_control()`).

## Sample size

`power_embryos()` pools the between-embryo standard deviation of log2 control
values across sessions and reports, for a two-sided two-sample t test (α =
0.05, power 0.8), the embryos needed per genotype to detect a given fold change
and the smallest change detectable with the current numbers.
