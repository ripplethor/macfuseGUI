#!/usr/bin/env python3
"""Validate static docs SEO invariants for macfusegui.app."""

from __future__ import annotations

import re
import sys
import xml.etree.ElementTree as ET
from html.parser import HTMLParser
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"

EXPECTED_URLS = {
    "index.html": "https://www.macfusegui.app/",
    "macfuse-gui.html": "https://www.macfusegui.app/macfuse-gui.html",
    "sshfs-gui-mac.html": "https://www.macfusegui.app/sshfs-gui-mac.html",
    "install-macfuse-sshfs-mac.html": "https://www.macfusegui.app/install-macfuse-sshfs-mac.html",
    "macfusegui-troubleshooting.html": "https://www.macfusegui.app/macfusegui-troubleshooting.html",
}


class PageInspector(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.title_count = 0
        self.meta_description_count = 0
        self.canonical_hrefs: list[str] = []
        self.h1_count = 0
        self.breadcrumb_nav_count = 0
        self.related_guides_count = 0

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attr_map = dict(attrs)
        if tag == "title":
            self.title_count += 1
        elif tag == "meta" and attr_map.get("name") == "description":
            self.meta_description_count += 1
        elif tag == "link" and attr_map.get("rel") == "canonical":
            href = attr_map.get("href")
            if href:
                self.canonical_hrefs.append(href)
        elif tag == "h1":
            self.h1_count += 1
        elif tag == "nav" and attr_map.get("aria-label") == "Breadcrumb":
            self.breadcrumb_nav_count += 1
        elif tag == "section" and attr_map.get("data-related-guides") == "true":
            self.related_guides_count += 1


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def inspect_html(page: Path, expected_url: str, errors: list[str]) -> None:
    content = page.read_text(encoding="utf-8")
    parser = PageInspector()
    parser.feed(content)

    if parser.title_count != 1:
        fail(errors, f"{page.name}: expected 1 <title>, found {parser.title_count}")
    if parser.meta_description_count != 1:
        fail(
            errors,
            f"{page.name}: expected 1 meta description, found {parser.meta_description_count}",
        )
    if len(parser.canonical_hrefs) != 1:
        fail(
            errors,
            f"{page.name}: expected 1 canonical link, found {len(parser.canonical_hrefs)}",
        )
    elif parser.canonical_hrefs[0] != expected_url:
        fail(
            errors,
            f"{page.name}: canonical {parser.canonical_hrefs[0]!r} != {expected_url!r}",
        )
    if parser.h1_count != 1:
        fail(errors, f"{page.name}: expected 1 <h1>, found {parser.h1_count}")

    if "@tailwindcss/browser" in content:
        fail(errors, f"{page.name}: still references @tailwindcss/browser")
    if 'type="text/tailwindcss"' in content:
        fail(errors, f"{page.name}: still contains text/tailwindcss block")

    if page.name != "index.html":
        if parser.breadcrumb_nav_count != 1:
            fail(
                errors,
                f"{page.name}: expected 1 breadcrumb nav, found {parser.breadcrumb_nav_count}",
            )
        if parser.related_guides_count != 1:
            fail(
                errors,
                f"{page.name}: expected 1 related guides section, found {parser.related_guides_count}",
            )

    if not re.search(r'<script type="application/ld\+json">', content):
        fail(errors, f"{page.name}: missing JSON-LD block")


def inspect_sitemap(errors: list[str]) -> None:
    sitemap = DOCS / "sitemap.xml"
    root = ET.fromstring(sitemap.read_text(encoding="utf-8"))
    ns = {"sm": "http://www.sitemaps.org/schemas/sitemap/0.9"}
    urls = {
        node.text.strip()
        for node in root.findall("sm:url/sm:loc", ns)
        if node.text and node.text.strip()
    }

    expected = set(EXPECTED_URLS.values())
    missing = sorted(expected - urls)
    extra = sorted(urls - expected)

    if missing:
        fail(errors, f"sitemap.xml: missing URLs: {', '.join(missing)}")
    if extra:
        fail(errors, f"sitemap.xml: unexpected URLs: {', '.join(extra)}")


def main() -> int:
    errors: list[str] = []
    for filename, expected_url in EXPECTED_URLS.items():
        page = DOCS / filename
        if not page.exists():
            fail(errors, f"missing page: {filename}")
            continue
        inspect_html(page, expected_url, errors)

    inspect_sitemap(errors)

    if errors:
        for error in errors:
            print(f"FAIL: {error}")
        return 1

    print("PASS: docs SEO checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
