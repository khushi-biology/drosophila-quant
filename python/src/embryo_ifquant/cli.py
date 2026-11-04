"""Command-line interface: ``embryo-ifquant <command> ...``.

Commands
--------
resegment     segment nuclei on DNA in Fiji TIFF crops and write Fiji-style intensity tables
wholebody     background-subtracted whole-animal fluorescence for a set of images -> CSV
svg-fix       make SVG figures convert cleanly in PowerPoint
pdf2svg       vector PDF -> SVG with text kept as text
pdf-links     make citation links in a Word-exported PDF open at the cited reference
pdf-compress  shrink a PDF by re-encoding its raster images

Author: Khushi Singh
"""

from __future__ import annotations

import argparse
import csv
import glob
import os
import sys


def _resegment(a):
    from .imaging.nuclei import resegment_image

    files = sorted(glob.glob(os.path.join(a.src, "*.tif")))
    if a.only_from:
        wanted = {os.path.basename(f)[:-len("_intensity.csv")]
                  for f in glob.glob(os.path.join(a.only_from, "*.tif_intensity.csv"))}
        files = [f for f in files if os.path.basename(f) in wanted]
    if not files:
        sys.exit("no TIFF files to segment")
    for f in files:
        n = resegment_image(f, a.out, a.dna_channel, min_peak_distance_um=a.min_peak_distance_um,
                            min_area_um2=a.min_area_um2)
        print(f"{os.path.basename(f)}: {n} nuclei")


def _wholebody(a):
    import tifffile
    from .imaging.wholebody import measure_whole_animal

    rows = []
    for f in sorted(glob.glob(a.pattern)):
        trans = None
        if a.trans_suffix:
            tp = f.replace(a.fluor_suffix, a.trans_suffix)
            trans = tifffile.imread(tp) if os.path.exists(tp) else None
        values, _ = measure_whole_animal(tifffile.imread(f), trans)
        rows.append(dict(file=os.path.basename(f), **values))
    with open(a.out, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=["file", "mean", "p90", "background", "area_px"])
        w.writeheader()
        w.writerows(rows)
    print(f"{len(rows)} images -> {a.out}")


def _svg_fix(a):
    from .figures.vector import fix_svg_for_office

    print("SVGs changed:", sum(fix_svg_for_office(p) for p in a.files))


def _pdf2svg(a):
    from .figures.vector import pdf_to_svg

    print(pdf_to_svg(a.pdf, a.svg))


def _pdf_links(a):
    from .office.pdf import retarget_citation_links

    print(retarget_citation_links(a.src, a.dst, heading=a.heading))


def _pdf_compress(a):
    from .office.pdf import compress_pdf

    size = compress_pdf(a.src, a.dst, quality=a.quality, dpi=a.dpi,
                        small_quality=None if a.small_quality <= 0 else a.small_quality)
    print(f"{a.dst}: {size / 1e6:.2f} MB")


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="embryo-ifquant", description=__doc__.split("\n\n")[0])
    sub = p.add_subparsers(dest="command", required=True)

    s = sub.add_parser("resegment", help="segment nuclei on DNA and write Fiji-style intensity tables")
    s.add_argument("src", help="folder of Fiji TIFF crops (channels first)")
    s.add_argument("out", help="output folder for *.tif_intensity.csv")
    s.add_argument("--dna-channel", type=int, required=True, help="0-based index of the DNA channel")
    s.add_argument("--only-from", help="only crops that have an intensity table in this folder")
    s.add_argument("--min-peak-distance-um", type=float, default=2.5)
    s.add_argument("--min-area-um2", type=float, default=5.0)
    s.set_defaults(func=_resegment)

    s = sub.add_parser("wholebody", help="whole-animal fluorescence per image -> CSV")
    s.add_argument("pattern", help='glob of fluorescence images, e.g. "data/*_GFP.tif"')
    s.add_argument("out", help="output CSV")
    s.add_argument("--fluor-suffix", default="_GFP.tif")
    s.add_argument("--trans-suffix", default=None, help='e.g. "_TRANS.tif" (animal dark in transmitted light)')
    s.set_defaults(func=_wholebody)

    s = sub.add_parser("svg-fix", help="make SVGs convert cleanly in PowerPoint")
    s.add_argument("files", nargs="+")
    s.set_defaults(func=_svg_fix)

    s = sub.add_parser("pdf2svg", help="vector PDF -> SVG (text as text)")
    s.add_argument("pdf")
    s.add_argument("svg", nargs="?")
    s.set_defaults(func=_pdf2svg)

    s = sub.add_parser("pdf-links", help="citation links open at the cited reference")
    s.add_argument("src")
    s.add_argument("dst")
    s.add_argument("--heading", default="References")
    s.set_defaults(func=_pdf_links)

    s = sub.add_parser("pdf-compress", help="re-encode raster images to shrink a PDF")
    s.add_argument("src")
    s.add_argument("dst")
    s.add_argument("--quality", type=int, default=75)
    s.add_argument("--dpi", type=int, default=300)
    s.add_argument("--small-quality", type=int, default=88, help="0 keeps small images unchanged")
    s.set_defaults(func=_pdf_compress)
    return p


def main(argv=None) -> None:
    args = build_parser().parse_args(argv)
    args.func(args)


if __name__ == "__main__":
    main()
