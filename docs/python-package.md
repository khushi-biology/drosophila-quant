# Python package `embryo_ifquant`: module reference

```python
import embryo_ifquant as eq
```

## `embryo_ifquant.io`

| Function | Purpose |
|---|---|
| `read_stack(path)` | Fiji TIFF → (C, Y, X) array and pixel size (µm) |
| `pixel_size_um(path)` | Pixel size from the TIFF resolution tag |
| `read_intensity_csv(path)` / `write_intensity_csv(path, image, rows)` | Fiji Multi-Measure tables |
| `parse_label(label)` | `<image>_ROI<k>_C<n>` → (image, roi, channel) |
| `io.fiji.read_rois(path)`, `io.fiji.roi_mask(roi, shape)` | ImageJ ROI sets and their masks |
| `io.czi.read_czi`, `dye_names`, `channel_index`, `stage_position`, `max_projection` | Zeiss CZI |

## `embryo_ifquant.imaging`

| Function | Purpose |
|---|---|
| `segment_nuclei(dna, pixel_size_um, ...)` | Gaussian, Otsu, distance-transform watershed, border nuclei removed |
| `measure_labels(stack, labels, pixel_size_um)` | Area, mean, min, max per nucleus and channel |
| `resegment_image(path, out_dir, dna_channel)` | Both, written as a Fiji-style table |
| `locate_crop(stack, crop)` | Exact position of a crop in the original stack |
| `measure_masks(channels, masks)` | Mean and max of named channels in masks |
| `embryo_mask`, `embryo_angle`, `render_overview`, `locate_field` | Whole-embryo overviews |
| `measure_whole_animal(fluor, trans)` | Background-subtracted whole-animal fluorescence |
| `box_mean`, `otsu_threshold`, `component_at`, `largest_component`, `downsample` | Filters |

## `embryo_ifquant.figures`

| Function | Purpose |
|---|---|
| `display_window`, `normalise`, `colourise`, `composite`, `centre_crop` | Display |
| `BLUE`, `RED`, `GREEN`, `GREY`, `MAGENTA` | Pseudo-colours (DNA blue, H3 red, mark green) |
| `image_grid(images, rows, pixel_size_um, out_path)` with `GridRow` | Genotype × channel grids, one window per row from the control |
| `compose_panels(rows, out_path)` | Multi-panel figures with panel letters |
| `save_png_and_svg`, `pdf_to_svg`, `fix_svg_for_office` | Editable vector figures |

## `embryo_ifquant.office`

See [documents.md](documents.md).

## Command-line tool

```
embryo-ifquant resegment SRC OUT --dna-channel N [--only-from DIR]
embryo-ifquant wholebody "data/*_GFP.tif" flies.csv [--trans-suffix _TRANS.tif]
embryo-ifquant svg-fix figures/*.svg
embryo-ifquant pdf2svg plot.vec.pdf [plot.svg]
embryo-ifquant pdf-links report.pdf report_links.pdf
embryo-ifquant pdf-compress report.pdf report_small.pdf --quality 75 --dpi 300
```
