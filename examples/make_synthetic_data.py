#!/usr/bin/env python3
"""Make a small synthetic experiment to try the whole workflow without real data.

Writes three-channel TIFF crops (C1 = H3, C2 = MARK, C3 = DAPI) of round nuclei
for three genotypes x 3 embryos x 2 fields into ``examples/data/crops`` and the
matching Fiji-style intensity tables into ``examples/data/intensity_tables``.
MutA has 1.5x more MARK per H3 than WT; MutB is unchanged.

Usage:  python examples/make_synthetic_data.py
Author: Khushi Singh
"""

import os

import numpy as np
import tifffile

from embryo_ifquant.imaging import measure_labels, segment_nuclei
from embryo_ifquant.io.fiji import write_intensity_csv

HERE = os.path.dirname(os.path.abspath(__file__))
CROPS = os.path.join(HERE, "data", "crops")
TABLES = os.path.join(HERE, "data", "intensity_tables")
PIXEL_UM = 0.13
EFFECT = {"WT": 1.0, "MutA": 1.5, "MutB": 1.0}


def field(rng, mark_factor, n=256, radius_px=22):
    """One field of a blastoderm-like monolayer of nuclei."""
    yy, xx = np.mgrid[:n, :n]
    chans = np.zeros((3, n, n)) + rng.normal(60, 6, (3, n, n))
    for cy in range(30, n - 20, 50):
        for cx in range(30 + (cy // 50 % 2) * 25, n - 20, 50):
            d = (yy - cy - rng.normal(0, 3)) ** 2 + (xx - cx - rng.normal(0, 3)) ** 2
            disk = d <= (radius_px * rng.uniform(0.9, 1.1)) ** 2
            h3 = 1500 * rng.lognormal(0, 0.1)
            chans[0][disk] += h3
            chans[1][disk] += 0.5 * h3 * mark_factor * rng.lognormal(0, 0.1)
            chans[2][disk] += 1200 * rng.lognormal(0, 0.1)
    return np.clip(chans, 0, 65535).astype(np.uint16)


def main():
    os.makedirs(CROPS, exist_ok=True)
    os.makedirs(TABLES, exist_ok=True)
    rng = np.random.default_rng(1)
    for g, k in EFFECT.items():
        for embryo in range(1, 4):
            emb_factor = rng.lognormal(0, 0.05)
            for f in range(1, 3):
                name = f"{g}_MARK_{embryo}-{f}.tif"
                img = field(rng, k * emb_factor)
                tifffile.imwrite(os.path.join(CROPS, name), img, imagej=True,
                                 resolution=(1 / PIXEL_UM, 1 / PIXEL_UM), metadata={"unit": "um"})
                lab = segment_nuclei(img[2], PIXEL_UM)
                write_intensity_csv(os.path.join(TABLES, name + "_intensity.csv"), name,
                                    measure_labels(img.astype(float), lab, PIXEL_UM))
    print("synthetic data in", os.path.join(HERE, "data"))


if __name__ == "__main__":
    main()
