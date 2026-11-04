"""Re-measuring Fiji ROIs, including channels that were not exported with a crop.

Typical use: a crop was saved from Fiji without the DNA channel. The crop is
located exactly inside the original acquisition (:func:`locate_crop`), the
missing channel is cut from the same position, and every channel is measured
in the Fiji ROIs (:func:`measure_masks`).

Author: Khushi Singh
"""

from __future__ import annotations

import numpy as np


def locate_crop(stack: np.ndarray, crop: np.ndarray, key_len: int = 8,
                key_offset: int = 50) -> tuple[int, int, int, int] | None:
    """Exact position of a 2-D ``crop`` inside a (C, Z, Y, X) ``stack``.

    A short row segment from the middle of the crop is searched in every
    channel and plane, and candidate positions are confirmed by comparing the
    whole crop. Returns (channel, z, y0, x0) or None.
    """
    h, w = crop.shape
    r = h // 2
    off = min(key_offset, max(0, w - key_len))
    key = crop[r, off:off + key_len]
    for c in range(stack.shape[0]):
        for z in range(stack.shape[1]):
            plane = stack[c, z]
            ys, xs = np.nonzero(plane[:, :-key_len] == key[0])
            for y, x in zip(ys, xs):
                if not np.array_equal(plane[y, x:x + key_len], key):
                    continue
                y0, x0 = y - r, x - off
                if (y0 >= 0 and x0 >= 0 and y0 + h <= plane.shape[0] and x0 + w <= plane.shape[1]
                        and np.array_equal(plane[y0:y0 + h, x0:x0 + w], crop)):
                    return c, z, int(y0), int(x0)
    return None


def measure_masks(channels: dict[str, np.ndarray], masks: list[np.ndarray]) -> list[dict]:
    """Mean and max of every named channel inside every mask.

    Returns one dict per mask: ``roi`` (1-based), ``area_px`` and, per channel,
    ``<name>`` (mean) and ``<name>_max``. Empty masks are skipped.
    """
    out = []
    for i, m in enumerate(masks, start=1):
        if not m.any():
            continue
        row = dict(roi=i, area_px=int(m.sum()))
        for name, img in channels.items():
            v = np.asarray(img, np.float64)[m]
            row[name] = float(v.mean())
            row[name + "_max"] = float(v.max())
        out.append(row)
    return out
