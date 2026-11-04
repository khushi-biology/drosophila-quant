"""embryo-ifquant: quantification of nuclear immunofluorescence in Drosophila embryos.

Subpackages
-----------
io        read TIFF and CZI images and Fiji intensity tables / ROI sets
imaging   nuclear segmentation, re-measurement, embryo overviews, whole-animal readouts
figures   display windows, micrograph grids, multi-panel figures, vector (SVG) export
office    Word, PowerPoint and PDF helpers (links, references, tracked changes, compression)

The statistics (nucleus -> image -> embryo, genotype effects) are in the
companion R package ``embryoIFquant`` in the same repository.
"""

__version__ = "0.1.0"
__author__ = "Khushi Singh"
