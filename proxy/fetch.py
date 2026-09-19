#!/usr/bin/env python3
"""Fetch Defector RSS -> static episodes.json for GitHub Pages.

Run locally:  python3 proxy/fetch.py --out feed/episodes.json
In CI:         scheduled workflow commits the result daily/hourly.
"""
import argparse
import html
import json
import re
import urllib.request
import xml.etree.ElementTree as ET

FEED = "https://rss.art19.com/the-distraction"

# Multi-podcast source list. Each key becomes the podcast id in episodes.json.
# Add new podcasts here as {"name": ..., "feed": ...} — the watch shows the
# podcast picker when more than one entry has episodes.
FEEDS = {
    "defector": {"name": "All Ball", "feed": FEED},
    "tvbb": {"name": "Ten Very Big Books",
             "feed": "https://feeds.transistor.fm/tenverybigbooks"},
}


def parse_rss(data, limit):
    root = ET.fromstring(data)
    out = []
    for item in root.find("channel").findall("item"):
        enc = item.find("enclosure")
        if enc is None:
            continue
        if (enc.get("type") or "") not in ("audio/mpeg", "audio/mp3",
                                            "audio/x-m4a"):
            continue
        url = enc.get("url") or ""
        m = re.search(r"/episodes/([0-9a-f-]{36})\.mp", url)
        ep_id = m.group(1) if m else url
        title = html.unescape((item.findtext("title") or "Untitled").strip())
        try:
            length = int(enc.get("length") or 0)
        except ValueError:
            length = 0
        out.append({
            "id": ep_id,
            "name": title[:60],
            "url": url,
            "canSkip": True,
            "type": "mp3" if ".mp3" in url else "m4a",
            "length": length,
        })
        if len(out) >= limit:
            break
    return out


def fetch_feed(url):
    req = urllib.request.Request(
        url, headers={"User-Agent": "GarminPodcastFeed/1.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--feed", default=None,
                    help="single RSS URL (overrides FEEDS, id 'defector')")
    ap.add_argument("--limit", type=int, default=10)
    ap.add_argument("--out", default="feed/episodes.json")
    args = ap.parse_args()
    feeds = {"defector": {"name": "All Ball", "feed": args.feed}} \
        if args.feed else FEEDS
    podcasts = []
    for pid, spec in feeds.items():
        try:
            data = fetch_feed(spec["feed"])
        except Exception as e:
            print(f"skip {pid}: {e}")
            continue
        eps = parse_rss(data, args.limit)
        podcasts.append({"id": pid, "name": spec["name"], "episodes": eps})
    with open(args.out, "w") as f:
        json.dump({"podcasts": podcasts}, f)
    total = sum(len(p["episodes"]) for p in podcasts)
    print(f"wrote {total} episodes in {len(podcasts)} podcasts -> {args.out}")


if __name__ == "__main__":
    main()
