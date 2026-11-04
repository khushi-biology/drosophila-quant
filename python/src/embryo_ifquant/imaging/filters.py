"""Small, dependency-free image filters used by the embryo and whole-animal tools.

Author: Khushi Singh
"""

from __future__ import annotations

import numpy as np
from scipy import ndimage as ndi


def downsample(img: np.ndarray, factor: int) -> np.ndarray:
    """Mean of ``factor`` x ``factor`` blocks (edges that do not fill a block are dropped)."""
    h, w = img.shape
    return img[: h // factor * factor, : w // factor * factor].reshape(
        h // factor, factor, w // factor, factor).mean((1, 3))


def upsample_mask(mask: np.ndarray, factor: int, shape: tuple[int, int]) -> np.ndarray:
    """Inverse of :func:`downsample` for masks, padded with False to ``shape``."""
    full = np.kron(mask, np.ones((factor, factor), bool))
    return np.pad(full, ((0, shape[0] - full.shape[0]), (0, shape[1] - full.shape[1])))


def box_mean(img: np.ndarray, k: int) -> np.ndarray:
    """Mean over a k x k box (reflected edges), computed with an integral image."""
    pad = k // 2
    a = np.pad(img, pad, mode="reflect")
    c = np.pad(np.cumsum(np.cumsum(a, 0), 1), ((1, 0), (1, 0)))
    s = c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]
    return s[: img.shape[0], : img.shape[1]] / (k * k)


def otsu_threshold(x: np.ndarray, bins: int = 256) -> float:
    """Otsu threshold of the values in ``x``."""
    hist, edges = np.histogram(x, bins=bins)
    p = hist / hist.sum()
    w = np.cumsum(p)
    mu = np.cumsum(p * edges[:-1])
    sb = (mu[-1] * w - mu) ** 2 / (w * (1 - w) + 1e-12)
    return float(edges[np.argmax(sb)])


def component_at(mask: np.ndarray, seed: tuple[float, float]) -> np.ndarray:
    """4-connected component of ``mask`` containing the foreground pixel nearest ``seed`` (y, x)."""
    ys, xs = np.nonzero(mask)
    if not len(ys):
        return mask.copy()
    i = np.argmin((ys - seed[0]) ** 2 + (xs - seed[1]) ** 2)
    lab, _ = ndi.label(mask)
    return lab == lab[ys[i], xs[i]]


def largest_component(mask: np.ndarray) -> np.ndarray:
    """Largest 4-connected component of ``mask``."""
    lab, n = ndi.label(mask)
    if n == 0:
        return mask.copy()
    sizes = np.bincount(lab.ravel())
    sizes[0] = 0
    return lab == np.argmax(sizes)
