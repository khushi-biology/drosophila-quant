"""Automatic nuclear segmentation on DNA staining and per-nucleus measurement.

Used to check that results do not depend on manual ROI drawing: the same crops
are re-segmented identically for every image and measured in all channels, and
the measurements are written as Fiji-style tables that the R pipeline reads
unchanged.

Author: Khushi Singh
"""

from __future__ import annotations

import os

import numpy as np
from scipy import ndimage as ndi
from skimage import feature, filters, measure, morphology, segmentation

from ..io.fiji import write_intensity_csv
from ..io.tiff import read_stack


def segment_nuclei(dna: np.ndarray, pixel_size_um: float, sigma_px: float = 1.0,
                   min_peak_distance_um: float = 2.5, hole_area_um2: float = 2.0,
                   clear_border: bool = True) -> np.ndarray:
    """Label image of nuclei from a DNA (e.g. DAPI) channel.

    Gaussian smoothing, Otsu threshold, filling of small holes, then a
    distance-transform watershed seeded at local maxima at least
    ``min_peak_distance_um`` apart. Nuclei touching the image border are removed.
    """
    dna = filters.gaussian(np.asarray(dna, float), sigma_px, preserve_range=True)
    fg = dna > filters.threshold_otsu(dna)
    fg = morphology.remove_small_holes(fg, int(hole_area_um2 / pixel_size_um ** 2))
    dist = ndi.distance_transform_edt(fg)
    peaks = feature.peak_local_max(dist, min_distance=max(2, int(round(min_peak_distance_um / pixel_size_um))),
                                   labels=measure.label(fg), exclude_border=False)
    markers = np.zeros(fg.shape, int)
    markers[tuple(peaks.T)] = np.arange(1, len(peaks) + 1)
    lab = segmentation.watershed(-dist, markers, mask=fg)
    return segmentation.clear_border(lab) if clear_border else lab


def measure_labels(stack: np.ndarray, labels: np.ndarray, pixel_size_um: float,
                   min_area_um2: float = 5.0) -> list[dict]:
    """Area, mean, min and max of every channel in every labelled nucleus.

    Nuclei smaller than ``min_area_um2`` are skipped; the remaining nuclei are
    numbered 1, 2, ... in label order. Returns one dict per nucleus and channel
    (channels 1-based), ready for :func:`embryo_ifquant.io.fiji.write_intensity_csv`.
    """
    stack = stack[None] if stack.ndim == 2 else stack
    rows, k = [], 0
    for r in measure.regionprops(labels):
        area = r.area * pixel_size_um ** 2
        if area < min_area_um2:
            continue
        k += 1
        for c in range(stack.shape[0]):
            v = stack[c][r.coords[:, 0], r.coords[:, 1]]
            rows.append(dict(roi=k, channel=c + 1, area=area, mean=float(v.mean()),
                             min=float(v.min()), max=float(v.max())))
    return rows


def resegment_image(path: str, out_dir: str, dna_channel: int, **kwargs) -> int:
    """Segment one Fiji TIFF on its DNA channel, measure all channels and write
    ``<out_dir>/<file>_intensity.csv``. Returns the number of nuclei."""
    stack, px = read_stack(path, dtype=np.float64)
    min_area = kwargs.pop("min_area_um2", 5.0)
    lab = segment_nuclei(stack[dna_channel], px, **kwargs)
    rows = measure_labels(stack, lab, px, min_area_um2=min_area)
    name = os.path.basename(path)
    os.makedirs(out_dir, exist_ok=True)
    write_intensity_csv(os.path.join(out_dir, name + "_intensity.csv"), name, rows)
    return max((r["roi"] for r in rows), default=0)
