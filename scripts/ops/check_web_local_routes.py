#!/usr/bin/env python3
"""Serve web/ like Cloudflare Pages and fail closed on broken public routes."""

from __future__ import annotations

import json
import socket
import sys
import threading
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
WEB = ROOT / "web"
REQUIRED_ROUTES = (
    "/",
    "/guides/",
    "/guides/aqi-explained/",
    "/guides/exercise-in-heat/",
    "/guides/when-to-open-windows/",
    "/for-families/",
    "/for-runners/",
    "/air-quality-sensitive/",
    "/methodology/",
    "/about/",
    "/contact/",
    "/privacy/",
    "/terms/",
    "/robots.txt",
    "/sitemap.xml",
    "/site.webmanifest",
    "/styles.css",
    "/content.css",
    "/js/main.js",
    "/js/store-links.js",
    "/config/store-links.json",
    "/assets/badges/download-on-the-app-store.svg",
    "/assets/badges/app-store-qr.svg",
)


class PagesHandler(SimpleHTTPRequestHandler):
    def log_message(self, format: str, *args: object) -> None:
        return

    def do_GET(self) -> None:
        requested = self.path.split("?", 1)[0].split("#", 1)[0]
        path = Path(self.translate_path(requested))
        if requested == "/this-page-does-not-exist" or not path.exists():
            body = (WEB / "404.html").read_bytes()
            self.send_response(404)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        super().do_GET()


def fetch(base: str, path: str) -> tuple[int, bytes, str]:
    request = urllib.request.Request(base + path, method="GET")
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            return response.status, response.read(), response.headers.get_content_type()
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read(), exc.headers.get_content_type() if exc.headers else ""


def main() -> int:
    errors: list[str] = []
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.bind(("127.0.0.1", 0))
    host, port = sock.getsockname()
    sock.close()
    handler = partial(PagesHandler, directory=str(WEB))
    server = ThreadingHTTPServer((host, port), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    base = f"http://{host}:{port}"

    try:
        for path in REQUIRED_ROUTES:
            status, body, content_type = fetch(base, path)
            if status != 200:
                errors.append(f"{path}: expected HTTP 200, got {status}")
                continue
            if path.endswith(".xml") and "xml" not in content_type:
                errors.append(f"{path}: expected XML content type, got {content_type}")
            if path.endswith(".webmanifest"):
                json.loads(body.decode("utf-8"))
            if path.endswith(".xml"):
                ET.fromstring(body)
            if path.endswith("/") or path == "/":
                text = body.decode("utf-8")
                if "<h1" not in text:
                    errors.append(f"{path}: HTML 200 response is missing an h1")

        status, body, _ = fetch(base, "/this-page-does-not-exist")
        if status != 404:
            errors.append(f"/this-page-does-not-exist: expected HTTP 404, got {status}")
        elif "noindex" not in body.decode("utf-8"):
            errors.append("404 response is missing noindex")
    finally:
        server.shutdown()
        server.server_close()

    if errors:
        print("WEB ROUTE SMOKE: FAIL", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(f"WEB ROUTE SMOKE: PASS ({len(REQUIRED_ROUTES)} routes + 404)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
