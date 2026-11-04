"""Editable vector figures for PowerPoint, Word and Illustrator.

* :func:`save_png_and_svg` saves a matplotlib figure as PNG and as SVG with text kept as text.
* :func:`pdf_to_svg` converts a vector PDF (e.g. from ``embryoIFquant::save_plot(vector = TRUE)``) to SVG.
* :func:`fix_svg_for_office` rewrites SVG details that Office ignores (CSS ``font:`` shorthand,
  fonts without the needed glyphs) so that "Convert to Shape" keeps the text editable.

Author: Khushi Singh
"""

from __future__ import annotations

import re


def save_png_and_svg(fig, png_path: str, dpi: int = 300, **kwargs) -> str:
    """Save ``fig`` as ``png_path`` and as the same name with ``.svg`` (text as text). Returns the SVG path."""
    import matplotlib

    fig.savefig(png_path, dpi=dpi, **kwargs)
    svg = re.sub(r"\.png$", "", png_path) + ".svg"
    with matplotlib.rc_context({"svg.fonttype": "none"}):
        fig.savefig(svg, format="svg", **kwargs)
    return svg


def pdf_to_svg(pdf_path: str, svg_path: str | None = None, page: int = 0, text_as_path: bool = False) -> str:
    """Convert one page of a vector PDF to SVG with PyMuPDF. Returns the SVG path."""
    import fitz

    svg_path = svg_path or re.sub(r"(\.vec)?\.pdf$", "", pdf_path) + ".svg"
    with fitz.open(pdf_path) as d:
        svg = d[page].get_svg_image(text_as_path=text_as_path)
    with open(svg_path, "w", encoding="utf-8") as fh:
        fh.write(svg)
    return svg_path


_STYLE = re.compile(r'style="([^"]*font:[^"]*)"')
_SHORT = re.compile(r"font:\s*(?:(italic|normal)\s+)?(?:(\d{3}|bold|normal)\s+)?([\d.]+)px\s+'([^']+)'")
_BACKGROUND = re.compile(r'<g id="patch_1">\s*<path d="M 0 [\d.]+ \s*L [\d.]+ [\d.]+ \s*L [\d.]+ 0 \s*L 0 0 \s*z\s*"'
                         r' style="fill: #ffffff[^"]*"/>\s*</g>')


def _style_to_attributes(m) -> str:
    keep, attrs = [], []
    for prop in (p.strip() for p in m.group(1).split(";") if p.strip()):
        if prop.startswith("font:"):
            f = _SHORT.match(prop)
            if not f:
                keep.append(prop)
                continue
            style, weight, size, family = f.groups()
            attrs.append(f'font-family="{family}" font-size="{size}"')
            if weight and weight != "normal":
                attrs.append('font-weight="bold"' if weight == "bold" or int(weight) >= 600 else 'font-weight="normal"')
            if style == "italic":
                attrs.append('font-style="italic"')
        elif prop.startswith("text-anchor:"):
            attrs.append(f'text-anchor="{prop.split(":", 1)[1].strip()}"')
        else:
            keep.append(prop)
    return " ".join(attrs) + (f' style="{"; ".join(keep)}"' if keep else "")


def fix_svg_for_office(path: str, font_map: dict[str, str] | None = None, drop_background: bool = True) -> bool:
    """Make an SVG render and convert cleanly in PowerPoint. Returns True if the file changed.

    matplotlib SVGs: the CSS ``font:`` shorthand becomes explicit attributes, the white
    figure background is removed and fill-only paths get ``stroke: none``.
    Other SVGs (e.g. from PDF): font families are renamed with ``font_map``
    (default Symbol and Helvetica -> Arial, so symbols such as x and minus display).
    """
    font_map = font_map if font_map is not None else {"Symbol": "Arial", "Helvetica": "Arial"}
    with open(path, encoding="utf-8") as fh:
        s = fh.read()
    original = s
    if "Matplotlib" in s:
        s = _STYLE.sub(_style_to_attributes, s)
        if drop_background:
            s = _BACKGROUND.sub("", s)
        s = re.sub(r'style="(fill: [^";]+)"', r'style="\1; stroke: none"', s)
    else:
        for old, new in font_map.items():
            s = s.replace(f'font-family="{old}"', f'font-family="{new}"')
    if s != original:
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(s)
        return True
    return False
