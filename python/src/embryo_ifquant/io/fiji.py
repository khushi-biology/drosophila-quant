"""Fiji ROI Manager tables (Multi Measure) and ROI sets.

A Fiji intensity table has one row per nucleus and channel::

     ,Label,Area,Mean,Min,Max
    1,WT_stain_4-1.tif_ROI1_C1,20.1,812.4,301,1950

Author: Khushi Singh
"""

from __future__ import annotations

import csv
import re

import numpy as np

_LABEL = re.compile(r"^(?P<image>.+?)_ROI(?P<roi>\d+)_C(?P<channel>\d+)$")


def parse_label(label: str) -> tuple[str, int, int]:
    """Split a Fiji label ``<image>_ROI<k>_C<n>`` into (image, roi, channel)."""
    m = _LABEL.match(label)
    if not m:
        raise ValueError(f"not a Fiji ROI label: {label!r}")
    return m.group("image"), int(m.group("roi")), int(m.group("channel"))


def read_intensity_csv(path: str) -> list[dict]:
    """Read a Fiji intensity table into dictionaries with numeric Area/Mean/Min/Max and parsed labels."""
    rows = []
    with open(path, newline="") as fh:
        for r in csv.DictReader(fh):
            image, roi, ch = parse_label(r["Label"])
            rows.append(dict(label=r["Label"], image=image, roi=roi, channel=ch, area=float(r["Area"]),
                             mean=float(r["Mean"]), min=float(r["Min"]), max=float(r["Max"])))
    return rows


def write_intensity_csv(path: str, image_name: str, measurements: list[dict]) -> None:
    """Write measurements in the Fiji table format so the R pipeline can read them unchanged.

    ``measurements`` holds one dict per nucleus and channel with keys ``roi``, ``channel`` (1-based),
    ``area``, ``mean``, ``min`` and ``max``.
    """
    with open(path, "w", newline="") as fh:
        fh.write(" ,Label,Area,Mean,Min,Max\n")
        for i, m in enumerate(measurements, start=1):
            fh.write(f'{i},{image_name}_ROI{m["roi"]}_C{m["channel"]},{m["area"]:.3f},{m["mean"]:.3f},'
                     f'{int(m["min"])},{int(m["max"])}\n')


def roi_mask(roi, shape: tuple[int, int]) -> np.ndarray:
    """Boolean mask of a traced ImageJ ROI (pixel centre inside the polygon, as ImageJ does).

    ``roi`` is a ``roifile.ImagejRoi`` (or anything with ``coordinates()`` returning (x, y) vertices).
    """
    from matplotlib.path import Path

    poly = roi.coordinates()
    yy, xx = np.mgrid[0:shape[0], 0:shape[1]]
    pts = np.column_stack([xx.ravel() + 0.5, yy.ravel() + 0.5])
    return Path(poly).contains_points(pts).reshape(shape)


def read_rois(path: str) -> list:
    """Read an ImageJ ROI set (``.zip``) or single ROI (``.roi``); needs the ``roifile`` package."""
    import roifile

    rois = roifile.ImagejRoi.fromfile(path)
    return rois if isinstance(rois, list) else [rois]
