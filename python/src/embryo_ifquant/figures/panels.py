"""Multi-panel figures from finished images, with bold lowercase panel letters.

Author: Khushi Singh
"""

from __future__ import annotations

from PIL import Image, ImageDraw, ImageFont


def _font(path: str | None, size: int):
    for p in ([path] if path else []) + ["/System/Library/Fonts/Supplemental/Arial Bold.ttf",
                                          "/Library/Fonts/Arial Bold.ttf", "DejaVuSans-Bold.ttf"]:
        try:
            return ImageFont.truetype(p, size)
        except OSError:
            continue
    return ImageFont.load_default()


def compose_panels(rows: list[list[tuple[str, str]]], out_path: str, width_in: float = 6.5, dpi: int = 300,
                   gap_in: float = 0.07, label_band_px: int = 52, font_path: str | None = None,
                   font_size: int = 46, max_row_height_in: float | None = None) -> tuple[int, int]:
    """Assemble images into a figure of fixed width.

    ``rows`` is a list of rows, each a list of ``(letter, image_path)``. The
    images of a row share one height and fill the width, unless that would make
    the row taller than ``max_row_height_in``, in which case the row is centred.
    Returns the figure size in pixels.
    """
    W, g = int(width_in * dpi), int(gap_in * dpi)
    font = _font(font_path, font_size)
    built = []
    for row in rows:
        ims = [Image.open(p).convert("RGB") for _, p in row]
        h = int((W - g * (len(ims) - 1)) / sum(i.width / i.height for i in ims))
        if max_row_height_in and h > max_row_height_in * dpi:
            h = int(max_row_height_in * dpi)
        used = sum(round(i.width * h / i.height) for i in ims) + g * (len(ims) - 1)
        canvas = Image.new("RGB", (W, h + label_band_px), "white")
        draw = ImageDraw.Draw(canvas)
        x = (W - used) // 2
        for (letter, _), im in zip(row, ims):
            w = round(im.width * h / im.height)
            canvas.paste(im.resize((w, h), Image.LANCZOS), (x, label_band_px))
            draw.text((x + 4, 0), letter, font=font, fill="black")
            x += w + g
        built.append(canvas)
    fig = Image.new("RGB", (W, sum(b.height for b in built) + g * (len(built) - 1)), "white")
    y = 0
    for b in built:
        fig.paste(b, (0, y))
        y += b.height + g
    fig.save(out_path, dpi=(dpi, dpi))
    return fig.size
