#!/usr/bin/env python3
"""Tiny RSS -> JSON proxy for the Garmin podcast app + show-list admin UI.

Usage:
    python3 proxy/server.py [--port 8000]

Endpoints:
    GET  /episodes           -> {"podcasts":[{"id","name","episodes":[...]}]}
    GET  /episodes?limit=5   -> cap per-podcast episodes (newest first)
    GET  /admin              -> browser UI to manage proxy/feeds.json
    POST /admin/add          -> add a show (id, name, feed, limit)
    POST /admin/delete       -> remove a show (id)
    POST /admin/regenerate   -> rebuild feed/episodes.json from feeds.json
    GET  /admin/test?feed=U  -> validate an RSS URL (count + first titles)

Only audio/mpeg|mp3|x-m4a enclosures are included. The /admin page runs
locally only (binds 127.0.0.1) — a Pages-hosted page could never write
feeds.json, so show management stays a localhost tool. After changes,
commit + push; the hourly workflow regenerates feed/episodes.json too.
"""
import argparse
import html
import json
import os
import re
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs
import xml.etree.ElementTree as ET

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
FEEDS_FILE = os.path.join(BASE_DIR, "feeds.json")
PROJECT_DIR = os.path.dirname(BASE_DIR)
EPISODES_OUT = os.path.join(PROJECT_DIR, "feed", "episodes.json")
CACHE_SECONDS = 600

_cache = {"at": 0, "body": b""}


def load_feeds():
    with open(FEEDS_FILE) as f:
        return json.load(f)


def save_feeds(feeds):
    with open(FEEDS_FILE, "w") as f:
        json.dump(feeds, f, indent=2)
        f.write("\n")


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
        # Stable id: ART19 episode UUID from .../episodes/<uuid>.mp3,
        # else the full enclosure URL (stable + unique per show).
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


def fetch_url(url, timeout=30):
    req = urllib.request.Request(
        url, headers={"User-Agent": "GarminPodcastProxy/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def build_podcasts(limit_override=None):
    """Fetch every show in feeds.json -> podcasts list for the watch."""
    feeds = load_feeds()
    podcasts = []
    for pid, spec in feeds.items():
        limit = limit_override or spec.get("limit", 10)
        eps = parse_rss(fetch_url(spec["feed"]))[:limit]
        for ep in eps:
            ep.setdefault("podcast", spec["name"])
        podcasts.append({"id": pid, "name": spec["name"], "episodes": eps})
    return podcasts


def regenerate_episodes_file():
    podcasts = build_podcasts()
    with open(EPISODES_OUT, "w") as f:
        json.dump({"podcasts": podcasts}, f)
    total = sum(len(p["episodes"]) for p in podcasts)
    return len(podcasts), total


def search_podcasts(term, limit=8):
    """Search Apple Podcasts (free, no key) -> [{name, author, feedUrl}]."""
    from urllib.parse import urlencode
    url = ("https://itunes.apple.com/search?" + urlencode(
        {"media": "podcast", "term": term, "limit": limit}))
    with urllib.request.urlopen(url, timeout=20) as r:
        data = json.load(r)
    out = []
    for item in data.get("results", []):
        feed = item.get("feedUrl")
        if not feed:
            continue
        out.append({
            "name": item.get("collectionName") or item.get("trackName") or "Untitled",
            "author": item.get("artistName", ""),
            "feedUrl": feed,
        })
    return out


def slugify(name):
    slug = re.sub(r"[^a-z0-9]+", "", name.lower().replace(" ", ""))[:12]
    return slug or "show"


ADMIN_CSS = ("body{font-family:sans-serif;max-width:720px;margin:2em auto;"
             "padding:0 1em}table{border-collapse:collapse;width:100%}"
             "td,th{border:1px solid #ccc;padding:.4em;text-align:left}"
             "input[type=text],input[type=url],input[type=number]{width:100%;"
             "box-sizing:border-box}.row{display:flex;gap:.5em;margin:.5em 0}"
             ".row>*{flex:1}.note{color:#555;font-size:.9em}")


def admin_page(msg="", query="", results=None):
    feeds = load_feeds()
    rows = []
    for pid, spec in feeds.items():
        rows.append(
            "<tr><td>{id}</td><td>{name}</td>"
            "<td><a href=\"{feed}\">{feedshort}</a></td><td>{limit}</td>"
            "<td><form method=\"post\" action=\"/admin/delete\">"
            "<input type=\"hidden\" name=\"id\" value=\"{id}\">"
            "<button type=\"submit\">Remove</button></form></td></tr>".format(
                id=html.escape(pid),
                name=html.escape(spec.get("name", "")),
                feed=html.escape(spec.get("feed", "")),
                feedshort=html.escape(spec.get("feed", "")[:40]),
                limit=html.escape(str(spec.get("limit", 10)))))
    if results:
        rrows = []
        for r in results:
            rrows.append(
                "<tr><td>{name}<br><span class=\"note\">{author}</span></td>"
                "<td><form method=\"post\" action=\"/admin/add\">"
                "<input type=\"hidden\" name=\"name\" value=\"{name}\">"
                "<input type=\"hidden\" name=\"feed\" value=\"{feed}\">"
                "<input type=\"text\" name=\"id\" value=\"{slug}\" required "
                "style=\"width:7em\" title=\"Short id for this show\">"
                "<input type=\"number\" name=\"limit\" value=\"10\" min=\"1\" "
                "max=\"500\" style=\"width:4em\" title=\"Episode limit\">"
                "<button type=\"submit\">Add</button></form></td></tr>".format(
                    name=html.escape(r["name"]),
                    author=html.escape(r.get("author", "")),
                    feed=html.escape(r["feedUrl"]),
                    slug=html.escape(slugify(r["name"]))))
        results_html = ("<h3>Search results</h3><table>" + "".join(rrows) +
                        "</table>")
    elif query:
        results_html = "<p class=\"note\">No results with RSS feeds.</p>"
    else:
        results_html = ""
    return ("<!doctype html><html><head><meta charset=\"utf-8\">"
            "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">"
            "<title>Podcast shows</title><style>" + ADMIN_CSS + "</style></head>"
            "<body><h1>Podcast shows</h1>"
            + (("<p><b>" + html.escape(msg) + "</b></p>") if msg else "") +
            "<table><tr><th>ID</th><th>Name</th><th>RSS</th><th>Limit</th>"
            "<th></th></tr>" + "".join(rows) + "</table>"
            "<h2>Add a show</h2>"
            "<form method=\"get\" action=\"/admin\">"
            "<div class=\"row\"><input type=\"text\" name=\"q\" placeholder=\"Search podcasts...\" value=\"" + html.escape(query) + "\">"
            "<button type=\"submit\" style=\"flex:0 0 auto\">Search</button></div></form>"
            + results_html +
            "<form method=\"post\" action=\"/admin/add\">"
            "<div class=\"row\"><input type=\"text\" name=\"id\" placeholder=\"id (e.g. tvbb)\" required>"
            "<input type=\"text\" name=\"name\" placeholder=\"Display name\" required></div>"
            "<div class=\"row\"><input type=\"url\" name=\"feed\" placeholder=\"https://... RSS URL\" required>"
            "<input type=\"number\" name=\"limit\" value=\"10\" min=\"1\" max=\"500\"></div>"
            "<button type=\"submit\">Add show by URL</button></form>"
            "<h2>Publish</h2>"
            "<form method=\"post\" action=\"/admin/regenerate\">"
            "<button type=\"submit\">Regenerate feed/episodes.json</button></form>"
            "<p class=\"note\">Edits save to proxy/feeds.json and rebuild "
            "feed/episodes.json. Then <code>git commit + push</code> to go live "
            "(the hourly workflow regenerates it too). Validate an RSS URL first: "
            "<code>/admin/test?feed=URL</code></p>"
            "</body></html>")


class Handler(BaseHTTPRequestHandler):
    default_limit = None

    def log_message(self, *a):
        pass

    def _send(self, body, ctype="application/json", status=200):
        if isinstance(body, str):
            body = body.encode()
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parts = urlparse(self.path)
        if parts.path == "/episodes":
            try:
                q = parse_qs(parts.query).get("limit", [None])[0]
                limit = int(q) if q else self.default_limit
            except ValueError:
                limit = self.default_limit
            if limit is not None:
                limit = max(1, min(limit, 500))
            import time
            now = time.time()
            if _cache["body"] and (now - _cache["at"] < CACHE_SECONDS):
                return self._send(_cache["body"])
            try:
                podcasts = build_podcasts(limit)
            except Exception as e:  # noqa: BLE001 - report as JSON
                return self._send(json.dumps({"error": str(e)[:200]}),
                                  status=502)
            body = json.dumps({"podcasts": podcasts}).encode()
            _cache.update(at=now, body=body)
            return self._send(body)
        if parts.path == "/admin":
            q = parse_qs(parts.query).get("q", [""])[0].strip()
            results = None
            if q:
                try:
                    results = search_podcasts(q)
                except Exception as e:  # noqa: BLE001 - show error inline
                    return self._send(admin_page("Search failed: " + str(e)[:120], query=q),
                                      ctype="text/html", status=502)
            return self._send(admin_page(query=q, results=results),
                              ctype="text/html")
        if parts.path == "/admin/test":
            url = parse_qs(parts.query).get("feed", [None])[0]
            if not url:
                return self._send("missing ?feed=URL", ctype="text/plain",
                                  status=400)
            try:
                all_eps = parse_rss(fetch_url(url))
            except Exception as e:  # noqa: BLE001
                return self._send(json.dumps({"error": str(e)[:200]}),
                                  status=502)
            return self._send(json.dumps({
                "count": len(all_eps),
                "first": [e["name"] for e in all_eps[:5]]}))
        self.send_error(404)

    def do_POST(self):
        parts = urlparse(self.path)
        length = int(self.headers.get("Content-Length", 0))
        form = parse_qs(self.rfile.read(length).decode())
        get = lambda k, d="": form.get(k, [d])[0]
        if parts.path == "/admin/add":
            pid = re.sub(r"[^a-z0-9_-]", "", get("id").strip().lower())
            name = get("name").strip()
            feed = get("feed").strip()
            try:
                limit = max(1, min(int(get("limit", "10")), 500))
            except ValueError:
                limit = 10
            if not pid or not name or not feed:
                return self._send(admin_page("All fields are required."),
                                  ctype="text/html", status=400)
            # Validate the RSS before saving.
            try:
                eps = parse_rss(fetch_url(feed))
            except Exception as e:  # noqa: BLE001
                return self._send(admin_page("Feed fetch failed: " + str(e)[:150]),
                                  ctype="text/html", status=502)
            if not eps:
                return self._send(admin_page("No audio enclosures found in that feed."),
                                  ctype="text/html", status=400)
            feeds = load_feeds()
            feeds[pid] = {"name": name, "feed": feed, "limit": limit}
            save_feeds(feeds)
            msg = "Added %s (%d episodes found)." % (name, len(eps))
            return self._send(admin_page(msg), ctype="text/html")
        if parts.path == "/admin/delete":
            feeds = load_feeds()
            pid = get("id")
            if pid in feeds:
                del feeds[pid]
                save_feeds(feeds)
                msg = "Removed %s." % pid
            else:
                msg = "Unknown id."
            return self._send(admin_page(msg), ctype="text/html")
        if parts.path == "/admin/regenerate":
            try:
                nshows, total = regenerate_episodes_file()
                msg = "Regenerated: %d episodes in %d podcasts." % (total, nshows)
            except Exception as e:  # noqa: BLE001
                return self._send(admin_page("Regenerate failed: " + str(e)[:150]),
                                  ctype="text/html", status=502)
            return self._send(admin_page(msg), ctype="text/html")
        self.send_error(404)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8000)
    args = ap.parse_args()
    srv = HTTPServer(("127.0.0.1", args.port), Handler)
    print("episodes: http://127.0.0.1:%d/episodes" % args.port)
    print("admin:    http://127.0.0.1:%d/admin" % args.port)
    srv.serve_forever()


if __name__ == "__main__":
    main()
