"""PowerPoint (.pptx) helpers built on python-pptx and lxml.

* :func:`embed_svg` attaches an SVG to a picture, so PowerPoint shows the vector
  version ("Convert to Shape" makes it editable) and keeps the PNG as fallback.
* :func:`add_click_fades` builds a click-by-click fade-in animation sequence.
* :func:`set_notes` writes speaker notes; :func:`set_font_family` unifies fonts.

Author: Khushi Singh
"""

from __future__ import annotations

from lxml import etree
from pptx.opc.constants import RELATIONSHIP_TYPE as RT
from pptx.opc.package import Part
from pptx.opc.packuri import PackURI
from pptx.oxml.ns import qn

P_NS = "http://schemas.openxmlformats.org/presentationml/2006/main"
SVG_EXT_URI = "{96DAC541-7B7A-43D3-8B79-37D633B846F1}"
SVG_NS = "http://schemas.microsoft.com/office/drawing/2016/SVG/main"
_svg_count = [0]


def embed_svg(slide, picture, svg_path: str) -> None:
    """Attach ``svg_path`` to an existing picture shape (its PNG stays as the fallback image)."""
    blip = picture._element.find(qn("p:blipFill")).find(qn("a:blip"))
    _svg_count[0] += 1
    with open(svg_path, "rb") as fh:
        part = Part(PackURI(f"/ppt/media/embedded_svg_{_svg_count[0]}.svg"), "image/svg+xml",
                    slide.part.package, fh.read())
    rid = slide.part.relate_to(part, RT.IMAGE)
    old = next(blip.iter(f"{{{SVG_NS}}}svgBlip"), None)
    if old is not None:
        old.set(qn("r:embed"), rid)
        return
    ext_lst = blip.find(qn("a:extLst"))
    if ext_lst is None:
        ext_lst = blip.makeelement(qn("a:extLst"), {})
        blip.append(ext_lst)
    ext = ext_lst.makeelement(qn("a:ext"), {"uri": SVG_EXT_URI})
    svg = etree.SubElement(ext, f"{{{SVG_NS}}}svgBlip", nsmap={"asvg": SVG_NS})
    svg.set(qn("r:embed"), rid)
    ext_lst.append(ext)


def set_notes(slide, text: str) -> None:
    """Replace the speaker notes of ``slide`` with ``text``."""
    slide.notes_slide.notes_text_frame.text = text


def set_font_family(presentation, family: str, keep: tuple[str, ...] = ("Symbol", "Wingdings")) -> int:
    """Set the Latin font of every text run in every slide to ``family`` (except symbol fonts).
    Returns the number of runs changed."""
    n = 0
    for slide in presentation.slides:
        for shape in slide.shapes:
            frames = [shape.text_frame] if shape.has_text_frame else []
            if getattr(shape, "has_table", False) and shape.has_table:
                frames += [c.text_frame for row in shape.table.rows for c in row.cells]
            for tf in frames:
                for par in tf.paragraphs:
                    for run in par.runs:
                        if run.font.name not in keep:
                            run.font.name = family
                            n += 1
    return n


def _el(tag, attrib=None, children=()):
    el = etree.Element(f"{{{P_NS}}}{tag}", {k: str(v) for k, v in (attrib or {}).items()})
    for c in children:
        el.append(c)
    return el


def _target(t):
    if isinstance(t, tuple):
        sp = _el("spTgt", {"spid": t[0]}, [_el("txEl", None, [_el("pRg", {"st": t[1], "end": t[1]})])])
    else:
        sp = _el("spTgt", {"spid": t})
    return _el("tgtEl", None, [sp])


def add_click_fades(slide, steps: list[list], duration_ms: int = 400) -> int:
    """Fade-in animation: each step appears on one click.

    ``steps`` is a list of clicks; each click is a list of targets that appear
    together, a target being a shape id (``shape.shape_id``) or a tuple
    ``(shape_id, paragraph_index)`` for one paragraph of a text box. Any existing
    animation on the slide is replaced. Returns the number of animated targets.
    """
    counter = iter(range(1, 10 ** 6))
    nid = lambda: next(counter)  # noqa: E731
    cond0 = lambda: _el("stCondLst", None, [_el("cond", {"delay": 0})])  # noqa: E731

    def effect(t, first):
        setb = _el("set", None, [
            _el("cBhvr", None, [_el("cTn", {"id": nid(), "dur": 1, "fill": "hold"}, [cond0()]), _target(t),
                                _el("attrNameLst", None, [_el("attrName")])]),
            _el("to", None, [_el("strVal", {"val": "visible"})])])
        setb.find(f".//{{{P_NS}}}attrName").text = "style.visibility"
        anim = _el("animEffect", {"transition": "in", "filter": "fade"}, [
            _el("cBhvr", None, [_el("cTn", {"id": nid(), "dur": duration_ms}), _target(t)])])
        ctn = _el("cTn", {"id": nid(), "presetID": 10, "presetClass": "entr", "presetSubtype": 0, "fill": "hold",
                          "grpId": 0, "nodeType": "clickEffect" if first else "withEffect"},
                  [cond0(), _el("childTnLst", None, [setb, anim])])
        return _el("par", None, [ctn])

    root_id, seq_id = nid(), nid()
    clicks = []
    for step in steps:
        outer, inner = nid(), nid()
        effects = [effect(t, k == 0) for k, t in enumerate(step)]
        par_inner = _el("par", None, [_el("cTn", {"id": inner, "fill": "hold"},
                                          [cond0(), _el("childTnLst", None, effects)])])
        clicks.append(_el("par", None, [_el("cTn", {"id": outer, "fill": "hold"},
                                            [_el("stCondLst", None, [_el("cond", {"delay": "indefinite"})]),
                                             _el("childTnLst", None, [par_inner])])]))
    slide_cond = lambda evt: _el("cond", {"evt": evt, "delay": 0}, [_el("tgtEl", None, [_el("sldTgt")])])  # noqa
    seq = _el("seq", {"concurrent": 1, "nextAc": "seek"}, [
        _el("cTn", {"id": seq_id, "dur": "indefinite", "nodeType": "mainSeq"}, [_el("childTnLst", None, clicks)]),
        _el("prevCondLst", None, [slide_cond("onPrev")]), _el("nextCondLst", None, [slide_cond("onNext")])])
    tn = _el("tnLst", None, [_el("par", None, [_el("cTn", {"id": root_id, "dur": "indefinite", "restart": "never",
                                                          "nodeType": "tmRoot"}, [_el("childTnLst", None, [seq])])])])
    # build list: text paragraph-wise (or whole), other shapes as background, tables as a graphic
    paras = {}
    for step in steps:
        for t in step:
            sid, p = t if isinstance(t, tuple) else (t, None)
            paras.setdefault(sid, set()).add(p)
    shapes = {s.shape_id: s for s in slide.shapes}
    bld = _el("bldLst")
    for sid, ps in paras.items():
        shape = shapes.get(sid)
        if shape is None:
            raise KeyError(f"shape id {sid} not on this slide")
        tag = etree.QName(shape._element).localname
        if tag == "sp" and shape.has_text_frame and shape.text_frame.text.strip():
            bld.append(_el("bldP", {"spid": sid, "grpId": 0, "build": "p" if None not in ps else "whole"}))
        elif tag == "sp":
            bld.append(_el("bldP", {"spid": sid, "grpId": 0, "animBg": 1}))
        elif tag == "graphicFrame":
            bld.append(_el("bldGraphic", {"spid": sid, "grpId": 0}, [_el("bldAsOne")]))
    timing = _el("timing", None, [tn] + ([bld] if len(bld) else []))
    el = slide._element
    old = el.find(f"{{{P_NS}}}timing")
    if old is not None:
        el.remove(old)
    anchor = el.find(f"{{{P_NS}}}transition")
    if anchor is None:
        anchor = el.find(f"{{{P_NS}}}clrMapOvr")
    (anchor.addnext if anchor is not None else el.find(f"{{{P_NS}}}cSld").addnext)(timing)
    return sum(len(s) for s in steps)
