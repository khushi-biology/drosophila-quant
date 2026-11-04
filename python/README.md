# embryo_ifquant (Python)

Image analysis, figures and document tools for quantifying nuclear
immunofluorescence in *Drosophila* embryos. Part of
[embryo-ifquant](https://github.com/khushi-biology/embryo-ifquant); the
statistics are in the companion R package `embryoIFquant`.

```bash
pip install -e ".[all]"      # from this folder
embryo-ifquant --help
pytest                       # with the [dev] extra
```

| Subpackage | Content |
|---|---|
| `io` | TIFF and CZI images, Fiji intensity tables, ImageJ ROI sets |
| `imaging` | nuclear segmentation, re-measurement, embryo overviews, whole-animal fluorescence |
| `figures` | display windows, micrograph grids, multi-panel figures, SVG export |
| `office` | Word, PowerPoint and PDF helpers; MBoC references |

Documentation: [../docs/python-package.md](../docs/python-package.md).

Author: Khushi Singh. Licence: MIT.
