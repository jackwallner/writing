#!/usr/bin/env python3
"""Collect public-domain (CC0) artworks from the Art Institute of Chicago API.

Writes catalog/candidates/candidates.json: works with an image, a usable shape
and no blocked subject, in a mix of paintings, photographs, watercolors and
color prints. A vision pass (tools/write_prompts.py) then looks at each one,
drops what does not suit, and writes its prompt.
"""
from __future__ import annotations

import json
import re
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "catalog" / "candidates" / "candidates.json"
API = "https://api.artic.edu/api/v1/artworks/search"
FIELDS = [
    "id", "title", "artist_title", "date_display", "image_id", "thumbnail", "classification_title",
    "subject_titles", "medium_display", "artwork_type_title", "is_boosted",
]
UA = "writing-prompts-catalog/1.0"

# (artwork type, how many to keep, a medium filter or None)
MIX = [
    ("Painting", 1300, None),
    ("Photograph", 400, None),
    ("Drawing and Watercolor", 400, re.compile(r"watercolor|pastel|gouache", re.I)),
    ("Print", 500, re.compile(r"color woodblock|in colors|color lithograph|chromolithograph", re.I)),
]

BLOCK = re.compile(
    r"\b(nude|nudes|naked|undress|bare[- ]breast|breast|erotic|crucif|christ|jesus|saint|madonna|virgin|"
    r"martyr|apostle|angel|god|goddess|biblical|holy|annunciation|nativity|resurrection|lamentation|"
    r"death|dead|dying|corpse|skull|skeleton|grave|tomb|funeral|battle|war|soldier|army|blood|"
    r"execution|murder|kill|hunt|slave|weapon|gun|rifle|sword|spear|fight|violence|wound|torture|"
    r"demon|devil|hell|satan|lynch|massacre|prisoner|captive|cupid|venus|bacchus|kiss|bather|bathing|"
    r"seduc|harem|odalisque|caricature|minstrel|indian|indigenous|savage|mourning|widow|courtesan|"
    r"shunga|actor|kabuki|samurai|warrior|ghost|kill)\w*",
    re.I,
)


def search(body: dict) -> dict:
    request = urllib.request.Request(
        API, data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "User-Agent": UA, "AIC-User-Agent": UA},
    )
    for attempt in range(5):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                return json.load(response)
        except Exception as error:  # noqa: BLE001
            print(f"  retry {attempt + 1}: {error}", flush=True)
            time.sleep(3 * (attempt + 1))
    return {"data": []}


def accept(item: dict, medium: re.Pattern | None) -> bool:
    thumb = item.get("thumbnail") or {}
    width, height = thumb.get("width") or 0, thumb.get("height") or 0
    if not item.get("image_id") or min(width, height) < 900:
        return False
    if not 0.62 <= width / height <= 1.75:
        return False
    text = " ".join([item.get("title") or "", thumb.get("alt_text") or "", " ".join(item.get("subject_titles") or [])])
    if BLOCK.search(text):
        return False
    if medium and not medium.search(item.get("medium_display") or item.get("classification_title") or ""):
        return False
    return True


def main() -> None:
    found: list[dict] = []
    # The API pages only through the first 1,000 hits of a query, so each type is read in date slices.
    eras = [(-5000, 1700), (1700, 1800), (1800, 1840), (1840, 1870), (1870, 1890), (1890, 1910), (1910, 3000)]
    for kind, keep, medium in MIX:
        kept: list[dict] = []
        seen: set[int] = set()
        for start, end in eras:
          page = 0
          while len(kept) < keep and page < 10:
            data = search({
                "query": {"bool": {
                    "must": [
                        {"term": {"is_public_domain": True}},
                        {"match_phrase": {"artwork_type_title": kind}},
                        {"exists": {"field": "image_id"}},
                        {"range": {"date_start": {"gte": start, "lt": end}}},
                    ],
                    "should": [{"term": {"is_boosted": {"value": True, "boost": 5}}}],
                }},
                "fields": FIELDS,
                "limit": 100,
                "from": page * 100,
            })
            rows = data.get("data", [])
            if not rows:
                break
            for item in rows:
                if item["id"] not in seen and accept(item, medium):
                    seen.add(item["id"])
                    thumb = item["thumbnail"]
                    kept.append({
                        "id": item["id"],
                        "title": (item.get("title") or "Untitled").strip(),
                        "artist": item.get("artist_title") or "Unknown artist",
                        "date": item.get("date_display"),
                        "type": kind,
                        "medium": item.get("medium_display"),
                        "image_id": item["image_id"],
                        "alt": (thumb.get("alt_text") or "").strip(),
                        "width": thumb["width"],
                        "height": thumb["height"],
                        "boosted": bool(item.get("is_boosted")),
                    })
            page += 1
            time.sleep(1.0)
        print(f"{kind}: kept {len(kept[:keep])}", flush=True)
        found.extend(kept[:keep])
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(found, indent=1))
    print(f"wrote {len(found)} candidates to {OUT}", flush=True)


if __name__ == "__main__":
    main()
