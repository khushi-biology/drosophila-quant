"""Whole-animal fluorescence (for example a genetically encoded sensor imaged in whole flies).

The animal is segmented on the fluorescence image (smoothing and Otsu threshold
on log intensity), optionally combined with a transmitted-light image in which
the animal is dark; the largest component is kept. The readout is the mean
fluorescence inside the animal minus the background (median outside a dilated
mask). The area is reported because animals may be imaged in different poses.

Author: Khushi Singh
"""

from __future__ import annotations

import numpy as np

from .filters import box_mean, downsample, largest_component, otsu_threshold, upsample_mask


def measure_whole_animal(fluor: np.ndarray, trans: np.ndarray | None = None,
                         factor: int = 4) -> tuple[dict, np.ndarray]:
    """Background-subtracted fluorescence of the animal and its mask.

    Returns ``(values, mask)`` where ``values`` has ``mean`` (mean - background),
    ``p90`` (90th percentile - background), ``background`` and ``area_px``.
    """
    g = np.asarray(fluor, np.float64)
    h, w = g.shape
    sm = box_mean(np.log1p(downsample(g, factor)), 5)
    m = sm > otsu_threshold(sm)
    if trans is not None:
        ts = box_mean(downsample(np.asarray(trans, np.float64), factor), 5)
        m &= ts < otsu_threshold(ts)
    m = box_mean(largest_component(m).astype(float), 5) > 0.5
    full = upsample_mask(m, factor, (h, w))
    halo = upsample_mask(box_mean(m.astype(float), 15) > 0.01, factor, (h, w))
    bg = float(np.median(g[~halo]))
    return dict(mean=float(g[full].mean() - bg), p90=float(np.percentile(g[full], 90) - bg),
                background=bg, area_px=int(full.sum())), full
