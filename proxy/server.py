#!/usr/bin/env python3
"""Tiny RSS -> JSON proxy for the Garmin podcast app.

Fetches the Defector/ART19 RSS feed, extracts the latest episodes,
and serves them as compact JSON the watch can fetch with
Communications.makeWebRequest (responseType JSON).

Usage:
    python3 proxy/server.py [--port 8000] [--feed URL] [--limit 10]

Endpoints:
    GET /episodes           -> {"podcasts":[{"id","name","episodes":[...]}]}
    GET /episodes?limit=5   -> first N episodes (newest first)

Episode `id` is the ART19 episode UUID (stable across fetches).
Only episodes with an audio/mpeg enclosure are included.
"""
import argparse
import html
import json
import re
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs
import xml.etree.ElementTree as ET

DEFAULT_FEED = "https://rss.art19.com/the-distraction"
CACHE_SECONDS = 600

_cache = {"at": 0, "episodes": []}


def fetch_episodes(feed_url, limit):
    import time
    now = time.time()
    if _cache["episodes"] and (now - _cache["at"] < CACHE_SECONDS):
        return _cache["episodes"][:limit]
    req = urllib.request.Request(
        feed_url, headers={"User-Agent": "GarminPodcastProxy/1.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        data = r.read()
    episodes = parse_rss(data)
    _cache.update(at=now, episodes=episodes)
    return episodes[:limit]


def parse_rss(data):
    root = ET.fromstring(data)
    channel = root.find("channel")
    out = []
    for item in channel.findall("item"):
        enc = item.find("enclosure")
        if enc is None:
            continue
        if (enc.get("type") or "") not in ("audio/mpeg", "audio/mp3",
                                            "audio/x-m4a"):
            continue
        url = enc.get("url") or ""
        # Stable id: ART19 episode UUID from .../episodes/<uuid>.mp3
        m = re.search(r"/episodes/([0-9a-f-]{36})\.mp", url)
        ep_id = m.group(1) if m else url
        title = html.unescape((item.findtext("title") or "Untitled").strip())
        try:
            length = int(enc.get("length") or 0)
        except ValueError:
            length = 0
        out.append({
            "id": ep_id,
            "name": title[:60],  # watch UI truncates; keep it short
            "url": url,
            "canSkip": True,
            "type": "mp3" if ".mp3" in url else "m4a",
            "length": length,
        })
    return out


class Handler(BaseHTTPRequestHandler):
    feed_url = DEFAULT_FEED
    default_limit = 10

    def log_message(self, *a):
        pass

    def do_GET(self):
        parts = urlparse(self.path)
        if parts.path != "/episodes":
            self.send_error(404)
            return
        try:
            limit = int(parse_qs(parts.query).get("limit", [self.default_limit])[0])
        except ValueError:
            limit = self.default_limit
        limit = max(1, min(limit, 25))
        try:
            eps = fetch_episodes(self.feed_url, limit)
        except Exception as e:  # noqa: BLE001 - report fetch errors as JSON
            body = json.dumps({"error": str(e)[:200]}).encode()
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        for ep in eps:
            ep["podcast"] = "All Ball"
        body = json.dumps({"podcasts": [{"id": "defector", "name": "All Ball",
                                         "episodes": eps}]}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8000)
    ap.add_argument("--feed", default=DEFAULT_FEED)
    ap.add_argument("--limit", type=int, default=10)
    args = ap.parse_args()
    Handler.feed_url = args.feed
    Handler.default_limit = args.limit
    srv = HTTPServer(("127.0.0.1", args.port), Handler)
    print(f"proxy: {args.feed} -> http://127.0.0.1:{args.port}/episodes")
    srv.serve_forever()


if __name__ == "__main__":
    main()
