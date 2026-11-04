# Word, PowerPoint and PDF helpers (`embryo_ifquant.office`)

Install with `pip install "embryo-ifquant[office]"`.

## References (`office.references`)

Molecular Biology of the Cell (MBoC) style:

* list entries `Author AB, Author CD (Year). Title. Journal Volume, pages.`,
  alphabetical; every author if there are 10 or fewer, otherwise the first 10
  followed by "et al.";
* in-text citations `(Smith, 2001)`, `(Smith and Jones, 2001)`,
  `(Smith et al., 2001)`, several in one bracket in chronological order.

```python
from embryo_ifquant.office.references import fetch_crossref, format_mboc, citation_label, sort_key
meta = fetch_crossref("10.1016/0092-8674(94)90361-1")
print(format_mboc(meta))
```

`sentence_case()` lower-cases titles while protecting acronyms, gene names and
words you list (e.g. genus names); always check the result.

## Word (`office.word`)

| Function | Purpose |
|---|---|
| `add_bookmark(paragraph, name)` | Bookmark a reference entry |
| `add_internal_link(paragraph, text, bookmark)` | Citation that jumps to the bookmark |
| `add_external_link(paragraph, url)` | Clickable DOI / URL |
| `set_fonts(document, family, body_pt, heading_pt)` | One font family for text and headings |
| `style_table(table)` | Booktabs-style table: rules only, no fills, header repeated, rows not split |
| `insert_tracked(paragraph, text, author)`, `delete_tracked(run, author)` | Tracked changes by a named reviewer |

## PowerPoint (`office.powerpoint`)

| Function | Purpose |
|---|---|
| `embed_svg(slide, picture, svg_path)` | Vector version of a picture (PNG stays as fallback); *Convert to Shape* makes it editable |
| `add_click_fades(slide, steps)` | Click-by-click fade-in; a step lists shape ids or `(shape_id, paragraph)` |
| `set_notes(slide, text)` | Speaker notes |
| `set_font_family(presentation, family)` | Unify fonts |

## PDF (`office.pdf`)

* `retarget_citation_links(src, dst)`: Word for Mac writes links to bookmarks so
  that they open one reference too low. This points every citation link at the
  top of the cited reference, matched by first author and year.
* `compress_pdf(src, dst, quality=75, dpi=300, small_quality=88)`: re-encodes
  raster images (large ones downsampled to the target resolution); text, vector
  graphics and links are untouched.

Always export PDFs from Word with *File → Save As → PDF* (best for electronic
distribution); printing to PDF removes every link.
