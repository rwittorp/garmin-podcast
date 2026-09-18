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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--feed", default=FEED)
    ap.add_argument("--limit", type=int, default=10)
    ap.add_argument("--out", default="feed/episodes.json")
    args = ap.parse_args()
    req = urllib.request.Request(
        args.feed, headers={"User-Agent": "GarminPodcastFeed/1.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = r.read()
    eps = parse_rss(data, args.limit)
    with open(args.out, "w") as f:
        json.dump({"episodes": eps}, f)
    print(f"wrote {len(eps)} episodes -> {args.out}")


if __name__ == "__main__":
    main()
