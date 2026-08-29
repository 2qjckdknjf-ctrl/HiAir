#!/usr/bin/env python3
"""Fail closed when the static HiAir website loses basic SEO integrity."""

from __future__ import annotations

import json
import re
import sys
import xml.etree.ElementTree as ET
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parents[2]
WEB = ROOT / "web"
ORIGIN = "https://hiair.io"
FORBIDDEN_SITEMAP_SUFFIXES = (".css", ".js", ".png", ".svg", ".xml", ".txt", ".webmanifest", ".toml")
REQUIRED_OG = ("og:type", "og:url", "og:title", "og:description", "og:image", "og:site_name")
REQUIRED_TWITTER = ("twitter:card", "twitter:title", "twitter:description", "twitter:image")
BANNED_JSONLD_KEYS = {"aggregateRating", "review", "reviewRating"}
SAFETY_CLAIM_PATTERNS = (
    r"know when the air is safe for your body",
    r"guarantees? (you|the user) (are|is) safe",
    r"hiAir is a medical device",
)
PLACEHOLDER_COPY = (
    "Draft for closed beta",
    "Official support and legal contact will be published",
)
STALE_PRELAUNCH_PHRASES = (
    "coming soon",
    "launching soon",
    "in development",
    "under development",
    "join early access for ios and android",
    "website under development",
    "app store coming soon",
    "play store coming soon",
    "ios & android coming soon",
)
STORE = json.loads((WEB / "config" / "store-links.json").read_text(encoding="utf-8"))


class PageParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.title = ""
        self.description = ""
        self.canonical = ""
        self.robots = ""
        self.h1_count = 0
        self.h1_text = ""
        self.links: list[str] = []
        self.json_ld: list[str] = []
        self.meta: dict[str, str] = {}
        self.ids: list[str] = []
        self.lang = ""
        self._capture_title = False
        self._capture_json_ld = False
        self._capture_h1 = False
        self._buffer: list[str] = []
        self._h1_buffer: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = dict(attrs)
        element_id = values.get("id")
        if element_id:
            self.ids.append(element_id)
        if tag == "html":
            self.lang = values.get("lang", "") or ""
        elif tag == "title":
            self._capture_title = True
        elif tag == "meta":
            name = values.get("name") or values.get("property")
            content = values.get("content", "") or ""
            if name == "description":
                self.description = content
            elif name == "robots":
                self.robots = content
            if name:
                self.meta[name] = content
        elif tag == "link" and values.get("rel") == "canonical":
            self.canonical = values.get("href", "") or ""
        elif tag == "h1":
            self.h1_count += 1
            self._capture_h1 = True
            self._h1_buffer = []
        elif tag == "a" and values.get("href"):
            self.links.append(values["href"] or "")
        elif tag == "script" and values.get("type") == "application/ld+json":
            self._capture_json_ld = True
            self._buffer = []

    def handle_endtag(self, tag: str) -> None:
        if tag == "title":
            self._capture_title = False
        elif tag == "h1":
            self._capture_h1 = False
            if not self.h1_text:
                self.h1_text = "".join(self._h1_buffer).strip()
        elif tag == "script" and self._capture_json_ld:
            self._capture_json_ld = False
            self.json_ld.append("".join(self._buffer).strip())

    def handle_data(self, data: str) -> None:
        if self._capture_title:
            self.title += data
        if self._capture_h1:
            self._h1_buffer.append(data)
        if self._capture_json_ld:
            self._buffer.append(data)


def path_for_url(url: str) -> Path:
    parsed = urlparse(url)
    relative = parsed.path.strip("/")
    return WEB / relative / "index.html" if relative else WEB / "index.html"


def walk_json(value: object) -> list[dict[str, object]]:
    found: list[dict[str, object]] = []
    if isinstance(value, dict):
        found.append(value)
        for item in value.values():
            found.extend(walk_json(item))
    elif isinstance(value, list):
        for item in value:
            found.extend(walk_json(item))
    return found


def main() -> int:
    errors: list[str] = []
    sitemap_path = WEB / "sitemap.xml"
    root = ET.parse(sitemap_path).getroot()
    namespace = {"s": "http://www.sitemaps.org/schemas/sitemap/0.9"}
    url_nodes = root.findall("s:url", namespace)
    urls = [(node.findtext("s:loc", default="", namespaces=namespace) or "").strip() for node in url_nodes]
    lastmods = [(node.findtext("s:lastmod", default="", namespaces=namespace) or "").strip() for node in url_nodes]
    if len(urls) < 10:
        errors.append(f"sitemap must expose at least 10 useful URLs, found {len(urls)}")
    if len(urls) != len(set(urls)):
        errors.append("sitemap contains duplicate URLs")

    titles: dict[str, str] = {}
    descriptions: dict[str, str] = {}
    h1s: dict[str, str] = {}
    indexed_files: set[Path] = set()
    inbound: dict[str, int] = {}
    if not any(path.is_file() and path.suffix == ".txt" and re.fullmatch(r"[0-9a-f]{64}", path.stem) for path in WEB.iterdir()):
        errors.append("IndexNow key file missing from web/ (64-hex filename .txt)")

    for url, lastmod in zip(urls, lastmods):
        if not url.startswith(f"{ORIGIN}/"):
            errors.append(f"non-canonical sitemap origin: {url}")
            continue
        if any(url.endswith(suffix) for suffix in FORBIDDEN_SITEMAP_SUFFIXES):
            errors.append(f"sitemap includes a non-indexable asset: {url}")
        if not lastmod:
            errors.append(f"{url}: sitemap lastmod is missing")
        elif not re.fullmatch(r"\d{4}-\d{2}-\d{2}", lastmod):
            errors.append(f"{url}: sitemap lastmod is not an ISO date: {lastmod!r}")
        page_path = path_for_url(url)
        indexed_files.add(page_path.resolve())
        if not page_path.is_file():
            errors.append(f"sitemap URL has no HTML file: {url}")
            continue

        text = page_path.read_text(encoding="utf-8")
        parser = PageParser()
        parser.feed(text)
        rel = page_path.relative_to(WEB)

        if parser.lang != "en":
            errors.append(f"{rel}: expected html lang='en'")
        if parser.h1_count != 1:
            errors.append(f"{rel}: expected exactly one h1, found {parser.h1_count}")
        if parser.h1_text:
            if parser.h1_text in h1s:
                errors.append(f"{rel}: duplicate h1 with {h1s[parser.h1_text]}")
            else:
                h1s[parser.h1_text] = str(rel)
        if not parser.title.strip():
            errors.append(f"{rel}: missing title")
        elif parser.title in titles:
            errors.append(f"{rel}: duplicate title with {titles[parser.title]}")
        else:
            titles[parser.title] = str(rel)
        if not parser.description.strip():
            errors.append(f"{rel}: missing meta description")
        elif len(parser.description) < 50:
            errors.append(f"{rel}: meta description is too thin ({len(parser.description)} chars)")
        elif parser.description in descriptions:
            errors.append(f"{rel}: duplicate description with {descriptions[parser.description]}")
        else:
            descriptions[parser.description] = str(rel)
        if parser.canonical != url:
            errors.append(f"{rel}: canonical {parser.canonical!r} does not match {url!r}")
        if "index" not in parser.robots.lower() or "follow" not in parser.robots.lower():
            errors.append(f"{rel}: robots meta must include index, follow")
        if "noindex" in parser.robots.lower():
            errors.append(f"{rel}: indexable sitemap URL is marked noindex")
        for placeholder in PLACEHOLDER_COPY:
            if placeholder in text:
                errors.append(f"{rel}: public placeholder copy remains")
        lowered = text.lower()
        for phrase in STALE_PRELAUNCH_PHRASES:
            if phrase in lowered:
                errors.append(f"{rel}: stale pre-launch copy remains: {phrase!r}")
        for pattern in SAFETY_CLAIM_PATTERNS:
            if re.search(pattern, text, flags=re.I):
                errors.append(f"{rel}: unsafe or overclaiming copy matches {pattern!r}")
        if re.search(r"<meta[^>]+name=[\"']keywords[\"']", text, flags=re.I):
            errors.append(f"{rel}: meta keywords must not be used")
        generated_content = str(rel) not in {"index.html", "privacy/index.html", "terms/index.html"}
        if generated_content:
            if "BreadcrumbList" not in text:
                errors.append(f"{rel}: missing BreadcrumbList JSON-LD")
            if 'aria-label="Breadcrumb"' not in text:
                errors.append(f"{rel}: missing visible breadcrumbs")
        if str(rel).startswith("guides/") and str(rel) != "guides/index.html" and "related-reading" not in text:
            errors.append(f"{rel}: missing related reading")
        if str(rel) == "for-runners/index.html" and "/guides/exercise-in-heat/" not in text:
            errors.append(f"{rel}: runners page must link to the heat-exercise guide")
        if str(rel) == "for-families/index.html" and "/guides/when-to-open-windows/" not in text:
            errors.append(f"{rel}: families page must link to the ventilation guide")
        if str(rel) == "air-quality-sensitive/index.html" and "/guides/aqi-explained/" not in text:
            errors.append(f"{rel}: sensitive page must link to the AQI guide")
        if str(rel) == "index.html":
            if '"@type": "WebSite"' not in text and '"@type":"WebSite"' not in text:
                errors.append(f"{rel}: homepage must include WebSite JSON-LD")
            if '"@type": "FAQPage"' not in text and '"@type":"FAQPage"' not in text:
                errors.append(f"{rel}: homepage must include FAQPage JSON-LD matching visible FAQ")
            if 'href="/air-quality-sensitive/"' not in text:
                errors.append(f"{rel}: homepage nav must include /air-quality-sensitive/")

        for key in REQUIRED_OG:
            if not parser.meta.get(key):
                errors.append(f"{rel}: missing {key}")
        if parser.meta.get("og:url") and parser.meta["og:url"] != url:
            errors.append(f"{rel}: og:url {parser.meta['og:url']!r} does not match {url!r}")
        if parser.meta.get("og:image") and not parser.meta["og:image"].startswith(f"{ORIGIN}/"):
            errors.append(f"{rel}: og:image must be an absolute hiair.io URL")
        for key in REQUIRED_TWITTER:
            if not parser.meta.get(key):
                errors.append(f"{rel}: missing {key}")
        if not parser.json_ld:
            errors.append(f"{rel}: missing JSON-LD")

        duplicate_ids = sorted({item for item in parser.ids if parser.ids.count(item) > 1})
        if duplicate_ids:
            errors.append(f"{rel}: duplicate ids {duplicate_ids}")

        if not parser.json_ld:
            errors.append(f"{rel}: missing JSON-LD")

        duplicate_ids = sorted({item for item in parser.ids if parser.ids.count(item) > 1})
        if duplicate_ids:
            errors.append(f"{rel}: duplicate ids {duplicate_ids}")

        page_nodes: list[dict] = []
        for payload in parser.json_ld:
            try:
                data = json.loads(payload)
            except json.JSONDecodeError as exc:
                errors.append(f"{rel}: invalid JSON-LD: {exc}")
                continue
            nodes = walk_json(data)
            page_nodes.extend(nodes)
            if not any(node.get("@context") == "https://schema.org" for node in nodes):
                errors.append(f"{rel}: JSON-LD is missing schema.org context")
            for node in nodes:
                banned = BANNED_JSONLD_KEYS.intersection(node)
                if banned:
                    errors.append(f"{rel}: JSON-LD contains forbidden social-proof keys {sorted(banned)}")
                offers = node.get("offers")
                if isinstance(offers, dict) and str(offers.get("price", "")).strip() in {"0", "0.00"}:
                    errors.append(f"{rel}: JSON-LD must not advertise a fake free price")
                operating_system = str(node.get("operatingSystem") or "")
                if (
                    "android" in operating_system.lower()
                    and STORE.get("android", {}).get("status") != "PUBLIC_CONFIRMED"
                ):
                    errors.append(f"{rel}: JSON-LD advertises Android before a public Play listing")
        if page_nodes and not any(node.get("inLanguage") == "en" for node in page_nodes):
            errors.append(f"{rel}: JSON-LD is missing inLanguage=en")
        if page_nodes and not any(node.get("url") == url for node in page_nodes):
            errors.append(f"{rel}: JSON-LD url does not match canonical")

        for href in parser.links:
            if href.startswith("mailto:"):
                if not href.lower().startswith("mailto:hello@hiair.io"):
                    errors.append(f"{rel}: unexpected mailto {href}")
                continue
            if href.startswith("https://play.google.com/"):
                if STORE.get("android", {}).get("status") != "PUBLIC_CONFIRMED":
                    errors.append(f"{rel}: Google Play URL is not verified yet: {href}")
                elif STORE["android"].get("packageId") and STORE["android"]["packageId"] not in href:
                    errors.append(f"{rel}: Google Play URL package mismatch: {href}")
                continue
            if href.startswith("https://apps.apple.com/"):
                ios = STORE.get("ios") or {}
                if ios.get("status") != "PUBLIC_CONFIRMED":
                    errors.append(f"{rel}: App Store URL present but iOS is not public: {href}")
                elif f"id{ios.get('appId', '')}" not in href:
                    errors.append(f"{rel}: unexpected App Store URL {href}")
                elif ios.get("url") and not href.startswith(ios["url"]):
                    errors.append(f"{rel}: App Store URL does not use the canonical listing: {href}")
                continue
            if href.startswith("http://"):
                errors.append(f"{rel}: insecure external link {href}")
                continue
            if not href.startswith("/") or href.startswith("//"):
                continue
            clean = href.split("#", 1)[0].split("?", 1)[0]
            if not clean:
                continue
            inbound[clean] = inbound.get(clean, 0) + 1
            target = path_for_url(f"{ORIGIN}{clean}")
            if not target.exists() and not (WEB / clean.lstrip("/")).exists():
                errors.append(f"{rel}: broken internal link {href}")

    orphan_candidates = {
        path.resolve()
        for path in WEB.glob("**/index.html")
        if path.parent.name not in {"privacy", "terms"} or path.resolve() in indexed_files
    }
    for orphan in sorted(orphan_candidates - indexed_files):
        errors.append(f"indexable HTML missing from sitemap: {orphan.relative_to(WEB)}")

    for url in urls:
        path = urlparse(url).path
        if path not in {"/", "/privacy/", "/terms/"} and inbound.get(path, 0) < 1:
            errors.append(f"orphan sitemap URL has no inbound internal links: {url}")

    robots = (WEB / "robots.txt").read_text(encoding="utf-8")
    if "Sitemap: https://hiair.io/sitemap.xml" not in robots:
        errors.append("robots.txt does not advertise the canonical sitemap")
    if re.search(r"(?im)^\s*Disallow:\s*/\s*$", robots):
        errors.append("robots.txt blocks the whole site")
    if "hiair.io" not in robots:
        errors.append("robots.txt must use the canonical production host")

    not_found = WEB / "404.html"
    if not not_found.is_file():
        errors.append("404.html is missing")
    else:
        not_found_text = not_found.read_text(encoding="utf-8")
        if "noindex" not in not_found_text:
            errors.append("404.html must be marked noindex")
        if "<h1" not in not_found_text:
            errors.append("404.html must expose one h1")

    if "https://hiair.io/404" in " ".join(urls) or "https://hiair.io/404.html" in urls:
        errors.append("sitemap must not include the 404 page")

    manifest = json.loads((WEB / "site.webmanifest").read_text(encoding="utf-8"))
    if manifest.get("name", "").lower().find("safety assistant") >= 0:
        errors.append("site.webmanifest must not claim HiAir is a safety assistant")
    if manifest.get("start_url") != "/":
        errors.append("site.webmanifest start_url must be /")

    js = (WEB / "js" / "main.js").read_text(encoding="utf-8")
    if "https://api.hiair.io" not in js or "/api/waitlist" not in js:
        errors.append("waitlist client does not post to the production waitlist API")

    store_js = WEB / "js" / "store-links.js"
    if not store_js.is_file():
        errors.append("web/js/store-links.js is missing")
    else:
        store_js_text = store_js.read_text(encoding="utf-8")
        ios_url = STORE.get("ios", {}).get("url") or ""
        if ios_url and ios_url not in store_js_text:
            errors.append("store-links.js does not contain the canonical iOS App Store URL")
        if STORE.get("ios", {}).get("status") == "PUBLIC_CONFIRMED" and "PUBLIC_CONFIRMED" not in store_js_text:
            errors.append("store-links.js is missing PUBLIC_CONFIRMED for iOS")
        if STORE.get("android", {}).get("status") != "PUBLIC_CONFIRMED" and re.search(
            r'"url":\s*"https://play\.google\.com/store/apps/details', store_js_text
        ):
            errors.append("store-links.js must not publish a Google Play details URL while Android is not public")

    workflow = (ROOT / ".github" / "workflows" / "hiair-io-pages.yml").read_text(encoding="utf-8")
    validate_match = re.search(r"(?ms)^  validate:(.*?)^  deploy:", workflow)
    if "pull_request:" not in workflow:
        errors.append("Pages workflow is missing a pull_request trigger")
    if "needs: validate" not in workflow:
        errors.append("Pages deploy job does not depend on validate")
    if "github.event_name != 'pull_request'" not in workflow:
        errors.append("Pages deploy job is not blocked for pull_request events")
    if "refs/heads/main" not in workflow:
        errors.append("Pages deploy job is not limited to main")
    if "git diff --exit-code -- web" not in workflow:
        errors.append("Pages workflow is missing a generated-file drift check")
    if not validate_match:
        errors.append("Pages workflow is missing distinct validate and deploy jobs")
    elif re.search(r"(?m)^    environment: production\s*$", validate_match.group(1)):
        errors.append("validate job must not use the production environment")

    if errors:
        print("WEB SEO CHECK: FAIL", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(f"WEB SEO CHECK: PASS ({len(urls)} sitemap URLs, {len(titles)} unique titles)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
