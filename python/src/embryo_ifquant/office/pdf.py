"""PDF helpers (PyMuPDF): correct citation links and shrink file size.

:func:`retarget_citation_links`
    Word for Mac exports internal links to bookmarks one entry too low: a click
    on a citation lands on the reference *after* the cited one. This rewrites
    every internal link so that it opens at the top of the cited reference,
    identified from the author and year in the citation text.

:func:`compress_pdf`
    Re-encodes large raster images as JPEG at a target resolution and small
    images (e.g. micrograph tiles) at high JPEG quality, keeping text, vector
    graphics and links untouched.

Author: Khushi Singh
"""

from __future__ import annotations

import io
import re
import unicodedata

_CITE = re.compile(r"([A-ZÀ-Þ][\w'À-ÿ\- ]+?)(?: et al\.| and [A-Z][\w'\-]+)?,? (\d{4})")


def _norm(s: str) -> str:
    return unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower()


def reference_entries(doc, first_page: int) -> list[dict]:
    """Reference entries from ``first_page`` on: the first line of each entry starts at the
    left margin, continuation lines carry the hanging indent."""
    entries = []
    for pi in range(first_page, len(doc)):
        lines = [(ln["bbox"], "".join(s["text"] for s in ln["spans"]))
                 for b in doc[pi].get_text("dict")["blocks"] for ln in b.get("lines", [])]
        lines = [x for x in lines if x[1].strip()]
        if not lines:
            continue
        left = min(x[0][0] for x in lines)
        cur = None
        for bb, t in sorted(lines, key=lambda x: (x[0][1], x[0][0])):
            if t.strip() == "References" or re.fullmatch(r"\d+", t.strip()):
                continue
            if abs(bb[0] - left) < 3:
                cur = {"page": pi, "y": bb[1], "x": bb[0], "text": t}
                entries.append(cur)
            elif cur is not None and cur["page"] == pi:
                cur["text"] += " " + t
    for e in entries:
        m = re.match(r"(.+?) \((\d{4})\)", e["text"])
        first = m.group(1).split(",")[0].rsplit(" ", 1)[0] if m else ""
        e["first"], e["year"] = _norm(first), (m.group(2) if m else "")
    return entries


def retarget_citation_links(src: str, dst: str, heading: str = "References", offset_pt: float = 6) -> dict:
    """Point every internal link before the reference list at the top of its reference.

    Links are grouped by their original destination (so the two halves of a
    citation broken over a line share a target); each group is matched to the
    entry with the same first author and year, falling back to the entry just
    before the original destination. Returns counts of links and groups.
    """
    import fitz

    doc = fitz.open(src)
    ref_page = next(i for i in range(len(doc) - 1, -1, -1)
                    if any(ln.strip() == heading for ln in doc[i].get_text().splitlines()))
    entries = reference_entries(doc, ref_page)
    links = [(pi, ln, doc[pi].get_textbox(fitz.Rect(ln["from"])).strip().replace("\n", " "))
             for pi in range(ref_page + 1) for ln in doc[pi].get_links()
             if ln.get("kind") == fitz.LINK_GOTO and (pi < ref_page or ln["page"] >= ref_page)]
    groups: dict = {}
    for item in links:
        groups.setdefault((item[1]["page"], round(item[1]["to"].y, 1)), []).append(item)
    fallback = 0
    for (page, y), items in groups.items():
        target = None
        for _, _, text in items:
            m = _CITE.search(text)
            if not m:
                continue
            name, year = _norm(m.group(1).strip()), m.group(2)
            hits = [e for e in entries if e["year"] == year and (name.startswith(e["first"]) or e["first"].startswith(name))]
            if len(hits) == 1:
                target = hits[0]
                break
        if target is None:
            before = [e for e in entries if (e["page"], e["y"]) < (page, y - 2)]
            if not before:
                continue
            target, fallback = before[-1], fallback + 1
        for _, ln, _ in items:
            ln.update(page=target["page"], to=fitz.Point(target["x"], max(target["y"] - offset_pt, 0)), zoom=0)
    # rebuild link annotations page by page (some exported links are inline objects that cannot be edited)
    changed = {(pi, tuple(round(v, 2) for v in ln["from"])): ln for pi, ln, _ in links}
    for pi in range(len(doc)):
        page = doc[pi]
        if list(page.annots()):
            raise ValueError(f"page {pi + 1} has non-link annotations; not rewriting")
        keep = [changed.get((pi, tuple(round(v, 2) for v in ln["from"])), ln) for ln in page.get_links()]
        doc.xref_set_key(page.xref, "Annots", "[]")
        page = doc.reload_page(page)
        for ln in keep:
            page.insert_link({k: v for k, v in ln.items() if k not in ("xref", "id")})
    doc.save(dst, garbage=3, deflate=True)
    return dict(links=len(links), targets=len(groups), fallback=fallback, entries=len(entries))


def compress_pdf(src: str, dst: str, quality: int = 75, dpi: int = 300, small_quality: int | None = 88,
                 small_px: int = 400) -> int:
    """Re-encode raster images and save a smaller PDF. Returns the new size in bytes.

    Images at least ``small_px`` wide are downsampled to ``dpi`` at their size on
    the page and saved as JPEG at ``quality``; smaller images are saved as JPEG at
    ``small_quality`` (``None`` keeps them unchanged). Smooth scaling is kept on.
    """
    import os

    import fitz
    from PIL import Image

    doc = fitz.open(src)
    done = set()
    for page in doc:
        for im in page.get_images(full=True):
            xref, width = im[0], im[2]
            small = width < small_px
            if xref in done or (small and small_quality is None):
                continue
            done.add(xref)
            rects = page.get_image_rects(xref)
            if not rects:
                continue
            pix = fitz.Pixmap(doc, xref)
            if pix.alpha or pix.n not in (1, 3):
                pix = fitz.Pixmap(fitz.csRGB, pix)
            img = Image.frombytes("RGB" if pix.n == 3 else "L", (pix.width, pix.height), pix.samples)
            want = int(max(r.width for r in rects) / 72 * dpi)
            if not small and img.width > want * 1.05:
                img = img.resize((want, round(img.height * want / img.width)), Image.LANCZOS)
            buf = io.BytesIO()
            img.save(buf, "JPEG", quality=small_quality if small else quality, subsampling=0, optimize=True)
            page.replace_image(xref, stream=buf.getvalue())
            doc.xref_set_key(xref, "Interpolate", "true")
    doc.save(dst, garbage=4, deflate=True, deflate_images=True, deflate_fonts=True, clean=True)
    return os.path.getsize(dst)
