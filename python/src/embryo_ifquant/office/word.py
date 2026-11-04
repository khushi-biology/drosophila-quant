"""Word (.docx) helpers built on python-docx and lxml.

* clickable citations: bookmarks on reference entries and HYPERLINK fields to them
* clickable URLs (e.g. DOIs) as HYPERLINK fields
* consistent fonts for body text and headings
* booktabs-style tables (rules above, below and between rows; no colour)
* tracked insertions and deletions by a named reviewer

Author: Khushi Singh
"""

from __future__ import annotations

import copy
import datetime as _dt
import itertools

from docx.oxml.ns import qn
from docx.oxml import OxmlElement

_ids = itertools.count(1000)


def _run(text: str, size_pt: float | None = None, colour: str | None = None, underline: bool = False,
         italic: bool = False):
    r = OxmlElement("w:r")
    rpr = OxmlElement("w:rPr")
    if italic:
        rpr.append(OxmlElement("w:i"))
    if colour:
        c = OxmlElement("w:color"); c.set(qn("w:val"), colour); rpr.append(c)
    if size_pt:
        for tag in ("w:sz", "w:szCs"):
            s = OxmlElement(tag); s.set(qn("w:val"), str(int(round(size_pt * 2)))); rpr.append(s)
    if underline:
        u = OxmlElement("w:u"); u.set(qn("w:val"), "single"); rpr.append(u)
    if len(rpr):
        r.append(rpr)
    t = OxmlElement("w:t"); t.text = text; t.set(qn("xml:space"), "preserve")
    r.append(t)
    return r


def _field(instruction: str, display_runs: list) -> list:
    def fld(kind):
        r = OxmlElement("w:r"); f = OxmlElement("w:fldChar"); f.set(qn("w:fldCharType"), kind); r.append(f)
        return r
    ir = OxmlElement("w:r"); it = OxmlElement("w:instrText"); it.text = instruction
    it.set(qn("xml:space"), "preserve"); ir.append(it)
    return [fld("begin"), ir, fld("separate"), *display_runs, fld("end")]


def add_bookmark(paragraph, name: str) -> None:
    """Bookmark the start of ``paragraph`` (e.g. a reference entry) so citations can link to it."""
    p = paragraph._p
    bid = str(next(_ids))
    start = OxmlElement("w:bookmarkStart"); start.set(qn("w:id"), bid); start.set(qn("w:name"), name)
    end = OxmlElement("w:bookmarkEnd"); end.set(qn("w:id"), bid)
    first = p.find(qn("w:r"))
    if first is None:
        p.append(start); p.append(end)
    else:
        first.addprevious(start); first.addnext(end)


def add_internal_link(paragraph, text: str, bookmark: str, size_pt: float | None = None) -> None:
    """Append ``text`` to ``paragraph`` as a link to ``bookmark`` (a citation pointing to its reference)."""
    for r in _field(f'HYPERLINK \\l "{bookmark}"', [_run(text, size_pt)]):
        paragraph._p.append(r)


def add_external_link(paragraph, url: str, text: str | None = None, size_pt: float | None = None,
                      colour: str = "1F4E9F") -> None:
    """Append a clickable URL (e.g. ``https://doi.org/...``), blue and underlined."""
    for r in _field(f'HYPERLINK "{url}"', [_run(text or url, size_pt, colour, underline=True)]):
        paragraph._p.append(r)


def set_fonts(document, family: str = "Times New Roman", body_pt: float = 12,
              heading_pt: dict[int, float] | None = None, heading_bold: bool = True,
              heading_colour: str = "000000") -> None:
    """One font family for body text and headings (style level, so direct formatting still wins)."""
    from docx.shared import Pt, RGBColor

    heading_pt = heading_pt or {1: 16, 2: 13, 3: 12}
    normal = document.styles["Normal"]
    normal.font.name = family
    normal.font.size = Pt(body_pt)
    normal.element.rPr.rFonts.set(qn("w:eastAsia"), family)
    for level, size in heading_pt.items():
        try:
            st = document.styles[f"Heading {level}"]
        except KeyError:
            continue
        st.font.name = family
        st.font.size = Pt(size)
        st.font.bold = heading_bold
        st.font.color.rgb = RGBColor.from_string(heading_colour)
        rfonts = st.element.rPr.rFonts
        for k in ("w:ascii", "w:hAnsi", "w:eastAsia", "w:cs"):
            rfonts.set(qn(k), family)
        for k in ("w:asciiTheme", "w:hAnsiTheme", "w:eastAsiaTheme", "w:cstheme"):
            if rfonts.get(qn(k)) is not None:
                del rfonts.attrib[qn(k)]


def style_table(table, font_pt: float = 10, header_rows: int = 1, rule_colour: str = "808080",
                width_dxa: int | None = 9360, centre: bool = True) -> None:
    """Booktabs-like table: thick rules above and below, thin rules between rows, no fills or
    vertical lines, bold header row(s) repeated on every page, rows kept from splitting."""
    from docx.shared import Pt

    tbl = table._tbl
    tblpr = tbl.tblPr
    for tag in ("w:tblStyle", "w:tblBorders", "w:jc", "w:tblW"):
        for e in tblpr.findall(qn(tag)):
            tblpr.remove(e)
    if width_dxa:
        w = OxmlElement("w:tblW"); w.set(qn("w:w"), str(width_dxa)); w.set(qn("w:type"), "dxa"); tblpr.append(w)
    if centre:
        jc = OxmlElement("w:jc"); jc.set(qn("w:val"), "center"); tblpr.append(jc)
    borders = OxmlElement("w:tblBorders")
    for side, sz in (("top", 8), ("left", 0), ("bottom", 8), ("right", 0), ("insideH", 2), ("insideV", 0)):
        b = OxmlElement(f"w:{side}")
        b.set(qn("w:val"), "single" if sz else "nil")
        if sz:
            b.set(qn("w:sz"), str(sz)); b.set(qn("w:space"), "0"); b.set(qn("w:color"), rule_colour)
        borders.append(b)
    tblpr.append(borders)
    for i, row in enumerate(table.rows):
        trpr = row._tr.get_or_add_trPr()
        if trpr.find(qn("w:cantSplit")) is None:
            trpr.append(OxmlElement("w:cantSplit"))
        if i < header_rows and trpr.find(qn("w:tblHeader")) is None:
            trpr.append(OxmlElement("w:tblHeader"))
        for cell in row.cells:
            tcpr = cell._tc.get_or_add_tcPr()
            for tag in ("w:shd", "w:tcBorders"):
                for e in tcpr.findall(qn(tag)):
                    tcpr.remove(e)
            for par in cell.paragraphs:
                for run in par.runs:
                    run.font.size = Pt(font_pt)
                    if i < header_rows:
                        run.font.bold = True


def _stamp(el, author: str, date: str | None):
    el.set(qn("w:id"), str(next(_ids)))
    el.set(qn("w:author"), author)
    el.set(qn("w:date"), date or _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))
    return el


def insert_tracked(paragraph, text: str, author: str, after_run=None, date: str | None = None):
    """Insert ``text`` as a tracked insertion by ``author`` (at the end, or after ``after_run``).

    The new run copies the formatting of ``after_run`` (or of the last run).
    """
    ins = _stamp(OxmlElement("w:ins"), author, date)
    ref = after_run._r if after_run is not None else paragraph._p.findall(qn("w:r"))[-1] \
        if paragraph._p.findall(qn("w:r")) else None
    r = _run(text)
    if ref is not None and ref.find(qn("w:rPr")) is not None:
        r.insert(0, copy.deepcopy(ref.find(qn("w:rPr"))))
    ins.append(r)
    if after_run is not None:
        after_run._r.addnext(ins)
    else:
        paragraph._p.append(ins)
    return ins


def delete_tracked(run, author: str, date: str | None = None):
    """Mark an existing run as a tracked deletion by ``author``."""
    r = run._r
    dl = _stamp(OxmlElement("w:del"), author, date)
    r.addprevious(dl)
    dl.append(r)
    for t in r.findall(qn("w:t")):
        t.tag = qn("w:delText")
    return dl
