"""TIFF stacks as written by Fiji (channels first) with their pixel size.

Author: Khushi Singh
"""

from __future__ import annotations

import numpy as np
import tifffile


def pixel_size_um(path: str) -> float:
    """Pixel size in micrometres from the TIFF XResolution tag (pixels per micrometre in Fiji files)."""
    with tifffile.TiffFile(path) as t:
        num, den = t.pages[0].tags["XResolution"].value
    return den / num


def read_stack(path: str, dtype=np.float32) -> tuple[np.ndarray, float]:
    """Read a Fiji TIFF as a (C, Y, X) array and return it with the pixel size in micrometres.

    A single-channel image is returned with a leading channel axis of length 1.
    """
    with tifffile.TiffFile(path) as t:
        a = t.asarray()
        num, den = t.pages[0].tags["XResolution"].value
    a = np.asarray(a, dtype=dtype)
    if a.ndim == 2:
        a = a[None]
    return a, den / num
