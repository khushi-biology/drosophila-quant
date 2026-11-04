"""Whole-embryo overviews: segmentation, orientation and display.

A low-magnification DNA image of the whole embryo documents its developmental
stage. The embryo is segmented on smoothed DNA (Otsu threshold), the component
nearest the field centre (or the high-magnification field) is kept, its long
axis is rotated to horizontal and the image is cropped around it. Contrast is
set per image because overviews document morphology and are not quantified.

Author: Khushi Singh
"""

from __future__ import annotations

import numpy as np
from PIL import Image

from .filters import box_mean, component_at, downsample, otsu_threshold, upsample_mask

BLUE = np.array([0.15, 0.35, 1.00])


def embryo_mask(img: np.ndarray, seed: tuple[float, float] | None = None, factor: int = 2) -> np.ndarray:
    """Mask of the embryo at full resolution.

    The image is downsampled by ``factor``, smoothed and thresholded; touching
    embryos are split by erosion (the dark gap between them survives light
    smoothing), the core under ``seed`` (y, x in full-resolution pixels; default
    image centre) is kept and grown back inside the threshold mask.
    """
    h, w = img.shape
    small = downsample(img.astype(np.float32), factor)
    sm = box_mean(small, 3)
    mask = sm > otsu_threshold(sm)
    seed_s = (small.shape[0] / 2, small.shape[1] / 2) if seed is None else (seed[0] / factor, seed[1] / factor)
    core = box_mean(mask.astype(np.float32), 15) > 0.9
    comp = component_at(core, seed_s) if core.any() else component_at(mask, seed_s)
    comp = (box_mean(comp.astype(np.float32), 17) > 0.01) & mask
    comp = box_mean(comp.astype(np.float32), 9) > 0.3
    return upsample_mask(comp, factor, (h, w))


def embryo_angle(mask: np.ndarray) -> tuple[float, float, float]:
    """Angle (degrees) of the long axis of ``mask`` from principal components, and its centre (y, x)."""
    ys, xs = np.nonzero(mask)
    cy, cx = ys.mean(), xs.mean()
    ev, evec = np.linalg.eigh(np.cov(np.vstack([xs - cx, ys - cy])))
    vx, vy = evec[:, np.argmax(ev)]
    return float(np.degrees(np.arctan2(vy, vx))), float(cy), float(cx)


def locate_field(overview: np.ndarray, field: np.ndarray, overview_px_um: float,
                 field_px_um: float) -> tuple[int, int, int, float]:
    """Find a high-magnification field inside a low-magnification overview.

    ``field`` (e.g. a 63x DNA max projection) is resized to the overview pixel
    size and matched by normalised cross-correlation. Returns (y, x, size) of
    the field in overview pixels and the peak correlation.
    """
    n = int(field.shape[0] * field_px_um / overview_px_um)
    t = np.array(Image.fromarray(field.astype(np.float32)).resize((n, n), Image.BILINEAR))
    t = (t - t.mean()) / (t.std() + 1e-9)
    img = overview.astype(np.float32)
    c1 = np.pad(np.cumsum(np.cumsum(img, 0), 1), ((1, 0), (1, 0)))
    c2 = np.pad(np.cumsum(np.cumsum(img * img, 0), 1), ((1, 0), (1, 0)))
    corr = np.fft.irfft2(np.fft.rfft2(img) * np.fft.rfft2(t[::-1, ::-1], s=img.shape), s=img.shape)[n - 1:, n - 1:]
    s1 = c1[n:, n:] - c1[:-n, n:] - c1[n:, :-n] + c1[:-n, :-n]
    s2 = c2[n:, n:] - c2[:-n, n:] - c2[n:, :-n] + c2[:-n, :-n]
    var = s2 - s1 ** 2 / (n * n)
    ncc = corr[: s1.shape[0], : s1.shape[1]] / np.sqrt(np.maximum(var, 1e-6) * n * n)
    y, x = np.unravel_index(np.argmax(ncc), ncc.shape)
    return int(y), int(x), n, float(ncc[y, x])


def render_overview(img: np.ndarray, pixel_size_um: float, out_h_px: int = 300, aspect: float = 2.6,
                    colour=BLUE, field: tuple[int, int, int] | None = None,
                    percentiles: tuple[float, float] = (1, 99.8)) -> tuple[np.ndarray, float]:
    """RGB image of the embryo, long axis horizontal, padded to ``aspect`` (width / height).

    ``field`` = (y, x, size) from :func:`locate_field` draws the high-magnification
    field as a white square. Returns the uint8 RGB array and micrometres per output pixel.
    """
    h, w = img.shape
    seed = (field[0] + field[2] / 2, field[1] + field[2] / 2) if field else None
    mask = embryo_mask(img, seed)
    angle, cy, cx = embryo_angle(mask)
    lo, hi = np.percentile(img, percentiles[0]), np.percentile(img, percentiles[1])
    g = np.clip((img - lo) / max(hi - lo, 1e-9), 0, 1) * (box_mean(mask.astype(np.float32), 41) > 0.01)
    if field:
        y0, x0, n = field[:3]
        lw = 3
        g[y0:y0 + lw, x0:x0 + n] = g[y0 + n - lw:y0 + n, x0:x0 + n] = 1.0
        g[y0:y0 + n, x0:x0 + lw] = g[y0:y0 + n, x0 + n - lw:x0 + n] = 1.0
    im = Image.fromarray((g * 255).astype(np.uint8)).rotate(angle, resample=Image.BICUBIC, center=(cx, cy))
    mk = np.array(Image.fromarray((mask * 255).astype(np.uint8)).rotate(angle, resample=Image.NEAREST,
                                                                         center=(cx, cy))) > 0
    ys, xs = np.nonzero(mk)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    my, mx = int(0.12 * (y1 - y0)), int(0.06 * (x1 - x0))
    crop = np.array(im)[max(0, y0 - my):min(h, y1 + my), max(0, x0 - mx):min(w, x1 + mx)].astype(np.float32) / 255
    ch, cw = crop.shape
    tw = max(cw, int(round(ch * aspect)))
    th = max(ch, int(round(tw / aspect)))
    canvas = np.zeros((th, tw), np.float32)
    canvas[(th - ch) // 2:(th - ch) // 2 + ch, (tw - cw) // 2:(tw - cw) // 2 + cw] = crop
    rgb = np.clip(canvas[..., None] * np.asarray(colour), 0, 1)
    rgb[canvas >= 0.999] = 1.0
    out = Image.fromarray((rgb * 255).astype(np.uint8)).resize((int(out_h_px * aspect), out_h_px), Image.LANCZOS)
    return np.array(out), pixel_size_um * th / out_h_px
