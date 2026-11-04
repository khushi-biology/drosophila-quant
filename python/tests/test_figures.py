import numpy as np
from PIL import Image

from embryo_ifquant.figures import (BLUE, GREEN, GridRow, centre_crop, composite, compose_panels,
                                    display_window, fix_svg_for_office, image_grid, normalise)


def test_display_helpers():
    img = np.arange(100.0).reshape(10, 10)
    lo, hi = display_window(img, 0, 100)
    assert (lo, hi) == (0, 99)
    assert normalise(img, 0, 99).max() == 1
    assert centre_crop(img, 4).shape == (4, 4)
    rgb = composite([(img, (0, 99), BLUE), (img, (0, 99), GREEN)])
    assert rgb.shape == (10, 10, 3) and rgb.max() <= 1


def test_image_grid_and_panels(tmp_path):
    rng = np.random.default_rng(0)
    imgs = {g: {"DNA": rng.random((80, 80)), "MARK": rng.random((80, 80))} for g in ("WT", "MUT")}
    rows = [GridRow("DNA", "DNA", BLUE), GridRow("MARK", "MARK", GREEN), GridRow("MERGE", None)]
    grid = tmp_path / "grid.png"
    image_grid(imgs, rows, pixel_size_um=0.2, out_path=str(grid), field_um=10)
    assert grid.exists()
    other = tmp_path / "other.png"
    Image.new("RGB", (300, 200), "white").save(other)
    size = compose_panels([[("a", str(grid)), ("b", str(other))]], str(tmp_path / "fig.png"), width_in=4, dpi=100)
    assert size[0] == 400


def test_fix_svg_for_office(tmp_path):
    p = tmp_path / "f.svg"
    p.write_text('<svg><!-- Created with Matplotlib --><text style="font: 700 10px \'Arial\'; '
                 'text-anchor: middle">x</text><path style="fill: #000000"/></svg>')
    assert fix_svg_for_office(str(p))
    s = p.read_text()
    assert 'font-family="Arial"' in s and 'font-weight="bold"' in s and "stroke: none" in s
    q = tmp_path / "r.svg"
    q.write_text('<svg><text font-family="Symbol">x</text></svg>')
    fix_svg_for_office(str(q))
    assert 'font-family="Arial"' in q.read_text()
