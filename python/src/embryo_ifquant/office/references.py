"""References: Crossref metadata, Molecular Biology of the Cell (MBoC) formatting and citation labels.

MBoC style, as used by many cell-biology theses:

* list:  ``Rottner K, Hall A, Small JV (1999). Title. Curr Biol 9, 640-648.``
  alphabetical; all authors if 10 or fewer, otherwise the first 10 followed by "et al."
* text:  ``(Smith, 2001)``, ``(Smith and Jones, 2001)``, ``(Smith et al., 2001)``;
  several citations in one bracket in chronological order.

Author: Khushi Singh
"""

from __future__ import annotations

import json
import re
import unicodedata
import urllib.parse
import urllib.request


def fetch_crossref(doi: str, mailto: str | None = None, timeout: float = 30) -> dict:
    """Metadata of one DOI from the Crossref REST API (the ``message`` object)."""
    url = "https://api.crossref.org/works/" + urllib.parse.quote(doi, safe="/")
    agent = "embryo-ifquant" + (f" (mailto:{mailto})" if mailto else "")
    req = urllib.request.Request(url, headers={"User-Agent": agent})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.load(r)["message"]


def initials(given: str) -> str:
    """Initials without full stops: ``"Richard G.W."`` -> ``"RGW"``, ``"Xiao-Yong"`` -> ``"XY"``."""
    out = ""
    for part in re.split(r"\s+", given.replace(".", " ").strip()):
        for sub in part.split("-"):
            if sub:
                out += sub[0].upper()
    return out


def author_names(meta: dict) -> list[str]:
    """Authors of a Crossref record as ``"Family AB"`` strings."""
    names = []
    for a in meta.get("author", []):
        fam = a.get("family") or a.get("name", "")
        names.append(f"{fam} {initials(a.get('given', ''))}".strip())
    return names


def format_authors(names: list[str], max_authors: int = 10) -> str:
    """MBoC author list: all names if ``len(names) <= max_authors``, else the first ``max_authors`` + "et al."."""
    if len(names) <= max_authors:
        return ", ".join(names)
    return ", ".join(names[:max_authors]) + ", et al."


def format_mboc(meta: dict, max_authors: int = 10, title: str | None = None, journal: str | None = None,
                include_doi: bool = True) -> str:
    """One reference in MBoC style from a Crossref record.

    ``title`` and ``journal`` override the Crossref values (use them for sentence case
    and NLM journal abbreviations). The DOI is appended as a URL if ``include_doi``.
    """
    year = (meta.get("issued", {}).get("date-parts") or [[None]])[0][0]
    title = title or re.sub(r"\s+", " ", re.sub(r"<[^>]+>", "", (meta.get("title") or [""])[0])).strip()
    journal = journal or (meta.get("short-container-title") or meta.get("container-title") or [""])[0]
    journal = journal.replace(".", "")
    pages = (meta.get("page") or meta.get("article-number") or "").replace("-", "–")
    s = f"{format_authors(author_names(meta), max_authors)} ({year}). {title.rstrip('.')}. {journal} " \
        f"{meta.get('volume', '')}, {pages}."
    s = re.sub(r"\s+,", ",", s)
    if include_doi and meta.get("DOI"):
        s += f" https://doi.org/{meta['DOI']}"
    return s


def citation_label(family_names: list[str], year: int | str) -> str:
    """In-text label: ``Smith, 2001``, ``Smith and Jones, 2001`` or ``Smith et al., 2001``."""
    if len(family_names) == 1:
        return f"{family_names[0]}, {year}"
    if len(family_names) == 2:
        return f"{family_names[0]} and {family_names[1]}, {year}"
    return f"{family_names[0]} et al., {year}"


def chronological(labels: list[str]) -> list[str]:
    """Order in-text citation labels by year (stable for equal years), as MBoC requires."""
    def year(lab):
        m = re.search(r"(\d{4})[a-z]?$", lab.strip())
        return int(m.group(1)) if m else 0
    return sorted(labels, key=year)


def sort_key(reference: str) -> tuple:
    """Alphabetical key: first author surname (accents ignored), initials, year."""
    m = re.match(r"(.+?) \((\d{4})\)", reference)
    first = (m.group(1) if m else reference).split(",")[0].split(";")[0].strip()
    parts = first.rsplit(" ", 1)
    surname, ini = (parts[0], parts[1]) if len(parts) == 2 and parts[1].isupper() and len(parts[1]) <= 3 \
        else (first, "")
    plain = unicodedata.normalize("NFKD", surname).encode("ascii", "ignore").decode().lower()
    return plain, ini, m.group(2) if m else ""


def sentence_case(title: str, keep: set[str] | None = None) -> str:
    """Sentence case for a title: lower-case every word except the first, words in ``keep``
    (e.g. genus names) and acronyms or gene names (any digit, or two or more capitals)."""
    keep = keep or set()
    out = []
    for i, w in enumerate(title.split(" ")):
        core = re.sub(r"[^\w-]", "", w)
        protect = i == 0 or core in keep or re.search(r"\d", core) or sum(c.isupper() for c in core) >= 2
        out.append(w if protect else w.lower())
    return " ".join(out)
