"""Zeiss CZI files (needs the ``czifile`` package): pixels, dye names and stage position.

Author: Khushi Singh
"""

from __future__ import annotations

import re

import numpy as np


def read_czi(path: str, dtype=np.float32) -> np.ndarray:
    """Pixel data with singleton axes removed, typically (C, Z, Y, X) or (C, Y, X)."""
    import czifile

    return np.squeeze(czifile.imread(path)).astype(dtype)


def metadata(path: str) -> str:
    """The CZI XML metadata as a string."""
    import czifile

    return czifile.CziFile(path).metadata()


def dye_names(path: str) -> list[str]:
    """Dye name of every channel, in acquisition order."""
    return re.findall(r"<DyeName>([^<]+)</DyeName>", metadata(path))


def channel_index(path: str, name: str, default: int | None = None) -> int:
    """Index of the first channel whose dye name contains ``name`` (e.g. ``"DAPI"``)."""
    for i, d in enumerate(dye_names(path)):
        if name.lower() in d.lower():
            return i
    if default is None:
        raise KeyError(f"no channel matching {name!r} in {path}")
    return default


def stage_position(path: str) -> tuple[float, float]:
    """Stage X, Y position (micrometres) of the acquisition."""
    m = re.search(r'X="([-\d.]+)" Y="([-\d.]+)"', metadata(path))
    if not m:
        raise ValueError(f"no stage position in {path}")
    return float(m.group(1)), float(m.group(2))


def max_projection(stack: np.ndarray, channel: int | None = None) -> np.ndarray:
    """Maximum projection over Z of a (C, Z, Y, X) or (Z, Y, X) stack; 2-D input is returned unchanged."""
    a = stack if channel is None else stack[channel]
    return a.max(0) if a.ndim == 3 else a
