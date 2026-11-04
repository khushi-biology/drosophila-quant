import numpy as np
import pytest
import tifffile


def disk_image(shape=(120, 120), centres=((30, 30), (30, 80), (80, 50)), radius=9, value=1000, seed=0):
    rng = np.random.default_rng(seed)
    img = rng.normal(50, 5, shape)
    yy, xx = np.mgrid[:shape[0], :shape[1]]
    for cy, cx in centres:
        img[(yy - cy) ** 2 + (xx - cx) ** 2 <= radius ** 2] += value
    return img.clip(0, 65535)


@pytest.fixture
def nuclei_tiff(tmp_path):
    """Two-channel TIFF (DNA, mark) with three round nuclei, 0.2 um pixels."""
    dna = disk_image()
    mark = disk_image(value=500, seed=1)
    path = tmp_path / "WT_stain_1-1.tif"
    tifffile.imwrite(path, np.stack([mark, dna]).astype(np.uint16), imagej=True, resolution=(5.0, 5.0))
    return path
