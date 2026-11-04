"""Display windows, pseudo-colours and composites for micrographs.

Convention used throughout: DNA blue, total histone red, histone modification
green. Display windows are taken from the control image and applied to every
genotype, so that brightness differences between panels are real.

Author: Khushi Singh
"""

from __future__ import annotations

import numpy as np

BLUE = np.array([0.15, 0.35, 1.00])
RED = np.array([1.00, 0.12, 0.12])
GREEN = np.array([0.10, 1.00, 0.20])
GREY = np.array([1.00, 1.00, 1.00])
MAGENTA = np.array([1.00, 0.20, 1.00])


def display_window(img: np.ndarray, low_pct: float = 1.0, high_pct: float = 99.7) -> tuple[float, float]:
    """(low, high) intensity window from percentiles of ``img``."""
    return float(np.percentile(img, low_pct)), float(np.percentile(img, high_pct))


def normalise(img: np.ndarray, low: float, high: float) -> np.ndarray:
    """Scale ``img`` linearly so that ``low`` -> 0 and ``high`` -> 1, clipped to [0, 1]."""
    return np.clip((np.asarray(img, np.float32) - low) / max(high - low, 1e-9), 0, 1)


def colourise(img: np.ndarray, window: tuple[float, float], rgb) -> np.ndarray:
    """(Y, X, 3) float image: ``img`` scaled by ``window`` and tinted with colour ``rgb``."""
    return normalise(img, *window)[..., None] * np.asarray(rgb, np.float32)


def composite(layers) -> np.ndarray:
    """Additive overlay of ``(img, window, rgb)`` layers, clipped to [0, 1]."""
    return np.clip(sum(colourise(i, w, c) for i, w, c in layers), 0, 1)


def centre_crop(img: np.ndarray, size: int) -> np.ndarray:
    """Central ``size`` x ``size`` region (smaller if the image is smaller)."""
    h, w = img.shape[:2]
    n = min(size, h, w)
    y, x = (h - n) // 2, (w - n) // 2
    return img[y:y + n, x:x + n]


def add_scale_bar(ax, image_px: int, pixel_size_um: float, length_um: float = 10, colour: str = "white",
                  fontsize: float = 5.5, label: bool = True) -> None:
    """Draw a scale bar in the lower-right corner of a square image shown with ``ax.imshow``."""
    from matplotlib.patches import Rectangle

    n = image_px
    bar = length_um / pixel_size_um
    ax.add_patch(Rectangle((n - bar - 0.06 * n, n - 0.09 * n), bar, n * 0.025, color=colour, lw=0))
    if label:
        ax.text(n - bar / 2 - 0.06 * n, n - 0.12 * n, f"{length_um:g} µm", color=colour, ha="center",
                va="bottom", fontsize=fontsize)
