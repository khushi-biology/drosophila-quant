import pytest

from embryo_ifquant.office.references import (author_names, chronological, citation_label, format_authors,
                                              format_mboc, initials, sentence_case, sort_key)

META = {"author": [{"family": "Rottner", "given": "Klemens"}, {"family": "Hall", "given": "Alan"},
                   {"family": "Small", "given": "J. Victor"}],
        "issued": {"date-parts": [[1999]]}, "title": ["Interplay between Rac and Rho"],
        "short-container-title": ["Curr. Biol."], "volume": "9", "page": "640-648", "DOI": "10.1000/x"}


def test_reference_formatting():
    assert initials("Richard G.W.") == "RGW" and initials("Xiao-Yong") == "XY"
    assert author_names(META) == ["Rottner K", "Hall A", "Small JV"]
    s = format_mboc(META)
    assert s.startswith("Rottner K, Hall A, Small JV (1999). Interplay between Rac and Rho. Curr Biol 9, 640–648.")
    assert s.endswith("https://doi.org/10.1000/x")
    assert format_authors([f"A{i} B" for i in range(12)]).endswith("A9 B, et al.")
    assert format_authors([f"A{i} B" for i in range(10)]).count(",") == 9


def test_citations_and_sorting():
    assert citation_label(["Smith"], 2001) == "Smith, 2001"
    assert citation_label(["Smith", "Jones"], 2001) == "Smith and Jones, 2001"
    assert citation_label(["Smith", "Jones", "Lee"], 2001) == "Smith et al., 2001"
    assert chronological(["B et al., 2010", "A, 1999"]) == ["A, 1999", "B et al., 2010"]
    refs = ["Li XY (2014). t", "Li J (2024). t", "Öztürk A (2024). t", "Pang L (2023). t"]
    assert [r.split(" (")[0] for r in sorted(refs, key=sort_key)] == ["Li J", "Li XY", "Öztürk A", "Pang L"]


def test_sentence_case():
    assert sentence_case("Zelda Binding in the Early Drosophila Embryo", keep={"Drosophila", "Zelda"}) == \
        "Zelda binding in the early Drosophila embryo"
    assert sentence_case("Histone H3K27ac Marks Active Enhancers") == "Histone H3K27ac marks active enhancers"


def test_word_links_and_tracked_changes(tmp_path):
    docx = pytest.importorskip("docx")
    from embryo_ifquant.office.word import (add_bookmark, add_external_link, add_internal_link, delete_tracked,
                                            insert_tracked, set_fonts, style_table)
    d = docx.Document()
    p = d.add_paragraph("As shown before (")
    add_internal_link(p, "Smith et al., 2001", "ref_smith2001")
    p.add_run(").")
    ref = d.add_paragraph("Smith A (2001). Title. J 1, 1–2. ")
    add_bookmark(ref, "ref_smith2001")
    add_external_link(ref, "https://doi.org/10.1000/x")
    insert_tracked(p, " New text.", author="Reviewer")
    delete_tracked(p.runs[0], author="Reviewer")
    t = d.add_table(rows=2, cols=2)
    t.cell(0, 0).text = "Head"
    style_table(t)
    set_fonts(d, "Times New Roman", 12)
    out = tmp_path / "t.docx"
    d.save(out)
    xml = docx.Document(out).element.xml
    assert 'HYPERLINK \\l "ref_smith2001"' in xml and 'w:name="ref_smith2001"' in xml
    assert "<w:ins " in xml and "<w:del " in xml and "w:delText" in xml


def test_pptx_svg_and_animation(tmp_path):
    pptx = pytest.importorskip("pptx")
    from PIL import Image
    from embryo_ifquant.office.powerpoint import add_click_fades, embed_svg, set_notes
    png, svg = tmp_path / "a.png", tmp_path / "a.svg"
    Image.new("RGB", (20, 20), "white").save(png)
    svg.write_text('<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20"/>')
    prs = pptx.Presentation()
    s = prs.slides.add_slide(prs.slide_layouts[6])
    pic = s.shapes.add_picture(str(png), 0, 0)
    box = s.shapes.add_textbox(0, 0, 100, 100)
    box.text_frame.text = "one"
    box.text_frame.add_paragraph().text = "two"
    embed_svg(s, pic, str(svg))
    assert add_click_fades(s, [[pic.shape_id], [(box.shape_id, 0)], [(box.shape_id, 1)]]) == 3
    set_notes(s, "notes")
    prs.save(tmp_path / "t.pptx")
    xml = s._element.xml
    assert "mainSeq" in xml and 'presetID="10"' in xml and "svgBlip" in pic._element.xml


def test_pdf_links_and_compress(tmp_path):
    fitz = pytest.importorskip("fitz")
    from embryo_ifquant.office.pdf import compress_pdf, retarget_citation_links
    d = fitz.open()
    p1 = d.new_page()
    p1.insert_text((72, 100), "Text (Smith et al., 2001) and (Brown, 1999).", fontsize=11)
    p2 = d.new_page()
    p2.insert_text((72, 72), "References", fontsize=14)
    p2.insert_text((72, 110), "Brown A (1999). First. J 1, 1–2.", fontsize=10)
    p2.insert_text((72, 140), "Smith A, Lee B, Wu C (2001). Second. J 2, 3–4.", fontsize=10)
    p2.insert_text((72, 170), "Zhang Q (2005). Third. J 3, 5–6.", fontsize=10)
    # wrong targets, as Word for Mac writes them: one entry too low
    p1 = d[0]
    for text, wrong_y in (("(Smith et al., 2001)", 160), ("(Brown, 1999)", 130)):
        r = p1.search_for(text)[0]
        p1.insert_link({"kind": fitz.LINK_GOTO, "from": r, "page": 1, "to": fitz.Point(72, wrong_y)})
    src = tmp_path / "in.pdf"
    d.save(src)
    info = retarget_citation_links(str(src), str(tmp_path / "out.pdf"))
    assert info["links"] == 2 and info["fallback"] == 0
    out = fitz.open(tmp_path / "out.pdf")
    ys = sorted(round(l["to"].y) for l in out[0].get_links())
    entry_tops = sorted(round(b[1]) for b in out[1].get_text("blocks") if b[4].startswith(("Brown", "Smith")))
    assert all(abs(y - (t - 6)) <= 2 for y, t in zip(ys, entry_tops))
    assert compress_pdf(str(tmp_path / "out.pdf"), str(tmp_path / "small.pdf")) > 0
