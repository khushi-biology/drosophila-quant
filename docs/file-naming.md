# File naming

The R pipeline reads genotype, embryo and image from the file name of each Fiji
intensity table, so consistent names are essential.

## Intensity tables

```
<genotype prefix>_<anything>_<embryo>-<field>[-<crop>].tif_intensity.csv
```

| Example | Embryo | Image |
|---|---|---|
| `WT_H3K18la_4-1.tif_intensity.csv` | 4 | field 1 |
| `WT_H3K18la_4-1-2.tif_intensity.csv` | 4 | field 1, crop 2 |
| `MutA_H3K18la_6.2-1-1.tif_intensity.csv` | 6.2 (kept as text) | field 1, crop 1 |
| `MutA_H3K18la_3.2_czi-1.tif_intensity.csv` | 3.2 | field 1 |
| `WT_H3K18la_snap_1-1.tif_intensity.csv` | 1 | field 1 |

Inside each table the `Label` column must read `<image name>_ROI<k>_C<n>`, which
is what Fiji writes when each ROI is measured in every channel. `embryo-ifquant
resegment` writes the same format.

## Genotypes

Genotypes are assigned by ordered regular expressions on the file name
(`genotype_rules`); the first rule that matches wins. Anchor the patterns at the
start of the name and put more specific prefixes first, e.g.

```r
genotype_rules <- c(WT = "^W2?_", MutA = "^MutA1?_", MutB = "^MutB_")
```

`W2_` (a second control slide) is then still WT, and `MutA1_` is MutA.

## Channels

`channels` maps Fiji channel numbers to markers. Fiji numbers channels in the
order of the saved TIFF. When a crop is saved without a channel the remaining
channels are renumbered; always check the mapping against the image.
