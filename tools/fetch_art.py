#!/usr/bin/env python3
"""Download every candidate artwork (843 px wide, the size the museum serves) and a
512 px preview for the prompt writer. Skips files already on disk. macOS only (sips).
"""
from __future__ import annotations

import json
import random
import subprocess
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CANDIDATES = ROOT / "catalog" / "candidates" / "candidates.json"
RAW = ROOT / "catalog" / "raw"
PREVIEW = RAW / "preview"
UA = "writing-prompts-catalog/1.0"


def fetch(item: dict) -> bool:
    out = RAW / f"{item['id']}.jpg"
    preview = PREVIEW / f"{item['id']}.jpg"
    if not out.exists():
        url = f"https://www.artic.edu/iiif/2/{item['image_id']}/full/843,/0/default.jpg"
        for attempt in range(4):
            try:
                request = urllib.request.Request(url, headers={"User-Agent": UA, "AIC-User-Agent": UA})
                with urllib.request.urlopen(request, timeout=60) as response:
                    data = response.read()
                if len(data) > 8_000:
                    out.write_bytes(data)
                    break
            except Exception as error:  # noqa: BLE001
                print(f"{item['id']}: {error}", flush=True)
            time.sleep(2 * (attempt + 1))
        else:
            return False
    if not preview.exists():
        subprocess.run(["sips", "-Z", "512", str(out), "--out", str(preview)], capture_output=True, check=False)
    return preview.exists()


def main() -> None:
    PREVIEW.mkdir(parents=True, exist_ok=True)
    items = json.loads(CANDIDATES.read_text())
    # The same order and limit tools/write_prompts.py reviews.
    random.Random(7).shuffle(items)
    items = items[:1650]
    with ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(fetch, items))
    print(f"{sum(results)} of {len(items)} artworks on disk", flush=True)


if __name__ == "__main__":
    main()
