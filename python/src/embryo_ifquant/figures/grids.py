"""Representative-image grids: columns = genotypes, rows = channels plus a merge.

Every row uses one display window, taken from the first (control) column, so
intensities can be compared across genotypes. All images are centre-cropped to
the same field size.

Author: Khushi Singh
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from .display import add_scale_bar, centre_crop, colourise, display_window


@dataclass
class GridRow:
    """One row of the grid: ``label`` shown on the left, ``channel`` key and colour.

    ``channel=None`` makes a merge row of all other rows.
    """
    label: str
    channel: str | None
    rgb: tuple | np.ndarray | None = None
    label_colour: str = "#333333"


def image_grid(images: dict[str, dict[str, np.ndarray]], rows: list[GridRow], pixel_size_um: float,
               out_path: str, field_um: float = 30.0, column_colours: dict[str, str] | None = None,
               column_labels: dict[str, str] | None = None, window_pct: tuple[float, float] = (1, 99.7),
               panel_in: float = 1.0, label_pt: float = 8.5, font: str | None = None,
               scale_bar_um: float = 10, dpi: int = 300) -> None:
    """Save a genotype x channel grid of micrographs.

    ``images`` maps each column (genotype, in display order; the first is the
    control) to a dict of 2-D channel images, e.g. ``{"WT": {"DAPI": a, "MARK": b}}``.
    """
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    cols = list(images)
    ctrl = cols[0]
    n = int(round(field_um / pixel_size_um))
    n = min([n] + [min(v.shape) for d in images.values() for v in d.values()])
    data = {g: {k: centre_crop(v, n) for k, v in d.items()} for g, d in images.items()}
    win = {r.channel: display_window(data[ctrl][r.channel], *window_pct) for r in rows if r.channel}
    labels = column_labels or {}
    colours = column_colours or {}
    lab_w, head = 0.32 * panel_in, 0.3
    W, H = lab_w + len(cols) * panel_in, head + len(rows) * panel_in
    rc = dict(plt.rcParams)
    if font:
        plt.rcParams["font.family"] = font
    try:
        fig = plt.figure(figsize=(W, H))
        for j, g in enumerate(cols):
            name = labels.get(g, g)
            fig.text((lab_w + (j + 0.5) * panel_in) / W, 1 - 0.15 / H, name, ha="center", va="center",
                     fontsize=label_pt if len(name) < 10 else label_pt * 0.82, fontweight="bold",
                     color=colours.get(g, "#333333"))
            for i, r in enumerate(rows):
                ax = fig.add_axes([(lab_w + j * panel_in + 0.015) / W, 1 - (head + (i + 1) * panel_in - 0.015) / H,
                                   (panel_in - 0.03) / W, (panel_in - 0.03) / H])
                if r.channel:
                    img = colourise(data[g][r.channel], win[r.channel], r.rgb)
                else:
                    img = np.clip(sum(colourise(data[g][q.channel], win[q.channel], q.rgb)
                                      for q in rows if q.channel), 0, 1)
                ax.imshow(img, interpolation="nearest")
                ax.set_xticks([]); ax.set_yticks([])
                for sp in ax.spines.values():
                    sp.set_visible(False)
                if j == 0 and i == len(rows) - 1 and scale_bar_um:
                    add_scale_bar(ax, n, pixel_size_um, scale_bar_um, fontsize=5.5 * label_pt / 8.5)
        for i, r in enumerate(rows):
            fig.text(0.16 * panel_in / W, 1 - (head + (i + 0.5) * panel_in) / H, r.label, rotation=90,
                     ha="center", va="center", fontsize=label_pt, color=r.label_colour, fontweight="bold")
        fig.savefig(out_path, dpi=dpi, facecolor="white")
        plt.close(fig)
    finally:
        plt.rcParams.update(rc)
