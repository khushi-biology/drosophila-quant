import numpy as np

from embryo_ifquant.imaging import (component_at, largest_component, measure_masks, locate_crop,
                                    measure_whole_animal, otsu_threshold, segment_nuclei)
from embryo_ifquant.imaging.embryo import embryo_angle, render_overview
from embryo_ifquant.imaging.nuclei import measure_labels, resegment_image
from embryo_ifquant.io.fiji import read_intensity_csv
from embryo_ifquant.io.tiff import read_stack

from conftest import disk_image


def test_segment_and_measure_three_nuclei():
    img = disk_image()
    lab = segment_nuclei(img, pixel_size_um=0.2)
    assert lab.max() == 3
    rows = measure_labels(np.stack([img, img * 2]), lab, 0.2)
    assert {r["roi"] for r in rows} == {1, 2, 3}
    ch2 = [r for r in rows if r["channel"] == 2]
    assert all(r["mean"] > 1500 for r in ch2)


def test_resegment_writes_fiji_table(nuclei_tiff, tmp_path):
    stack, px = read_stack(str(nuclei_tiff))
    assert stack.shape[0] == 2 and abs(px - 0.2) < 1e-6
    n = resegment_image(str(nuclei_tiff), str(tmp_path / "out"), dna_channel=1)
    assert n == 3
    rows = read_intensity_csv(str(tmp_path / "out" / (nuclei_tiff.name + "_intensity.csv")))
    assert len(rows) == 6 and rows[0]["image"] == nuclei_tiff.name


def test_filters_and_components():
    m = np.zeros((20, 20), bool)
    m[2:5, 2:5] = True
    m[10:18, 10:18] = True
    assert largest_component(m).sum() == 64
    assert component_at(m, (3, 3)).sum() == 9
    x = np.r_[np.zeros(100), np.full(100, 10.0)]
    assert (x > otsu_threshold(x)).sum() == 100


def test_locate_crop_and_measure_masks():
    rng = np.random.default_rng(3)
    stack = rng.integers(0, 4000, size=(2, 3, 200, 200)).astype(np.uint16)
    crop = stack[1, 2, 40:140, 30:130]
    assert locate_crop(stack, crop) == (1, 2, 40, 30)
    mask = np.zeros((100, 100), bool)
    mask[10:20, 10:20] = True
    out = measure_masks({"A": crop}, [mask, np.zeros_like(mask)])
    assert len(out) == 1 and out[0]["area_px"] == 100


def test_embryo_overview_is_horizontal():
    yy, xx = np.mgrid[:200, :300]
    img = ((((xx - 150) * 0.6 + (yy - 100) * 0.8) / 90) ** 2 + (((xx - 150) * 0.8 - (yy - 100) * 0.6) / 30) ** 2 <= 1)
    img = img * 1000.0 + 20
    angle, _, _ = embryo_angle(img > 500)
    assert abs(abs(angle) - 53.13) < 3
    rgb, um = render_overview(img, pixel_size_um=0.8, out_h_px=100, aspect=2.5)
    assert rgb.shape == (100, 250, 3) and um > 0


def test_whole_animal():
    img = disk_image(shape=(200, 200), centres=((100, 100),), radius=40, value=800)
    values, mask = measure_whole_animal(img)
    assert 700 < values["mean"] < 900 and mask.sum() > 3000
