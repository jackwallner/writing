#!/usr/bin/env python3
"""Merge the prompt writer's batches into the app's library.

Writes Inkling/prompts.json and one HEIC per artwork into Inkling/Art. Each day's
three choices mix kinds of art (painting, photograph, print, watercolor) and
forms of prompt. macOS only (sips).
"""
from __future__ import annotations

import json
import random
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CANDIDATES = ROOT / "catalog" / "candidates" / "candidates.json"
RAW = ROOT / "catalog" / "raw"
REVIEW = ROOT / "catalog" / "review"
ART = ROOT / "Inkling" / "Art"
OUT = ROOT / "Inkling" / "prompts.json"
MIN_DAYS = 366
BANNED = re.compile(r"[—–;!]|this painting|this image|\bimagine\b.*\bimagine\b", re.I)


def clean_title(title: str) -> str:
    title = re.sub(r"\s+", " ", title).strip()
    # Long series titles ("..., from the series ...") keep only the work's own name.
    return re.split(r",? from the series|\s\(", title)[0].strip()[:80]


def main() -> None:
    meta = {item["id"]: item for item in json.loads(CANDIDATES.read_text())}
    kept: list[dict] = []
    seen: set[int] = set()
    for path in sorted(REVIEW.glob("batch-*.json")):
        for row in json.loads(path.read_text()):
            art_id = row.get("id")
            text = (row.get("prompt") or "").strip()
            if not row.get("keep") or art_id not in meta or art_id in seen or not text:
                continue
            if BANNED.search(text) or not 6 <= len(text.split()) <= 40:
                print(f"skip {art_id}: {text}")
                continue
            if not (RAW / f"{art_id}.jpg").exists():
                continue
            seen.add(art_id)
            kept.append({**meta[art_id], "prompt": text, "form": row.get("form") or "story"})
    days = len(kept) // 3
    print(f"{len(kept)} kept, {days} days")
    if days < MIN_DAYS:
        raise SystemExit(f"need {MIN_DAYS * 3} prompts for a year, have {len(kept)}")

    # Deal each day one artwork from each of the three fullest kinds, preferring three different forms.
    rng = random.Random(20261120)
    buckets: dict[str, list[dict]] = {}
    for item in kept:
        buckets.setdefault(item["type"], []).append(item)
    for bucket in buckets.values():
        rng.shuffle(bucket)
    ordered: list[dict] = []
    for _ in range(days):
        kinds = sorted((k for k in buckets if buckets[k]), key=lambda k: -len(buckets[k]))
        day: list[dict] = []
        while len(day) < 3:
            for kind in kinds:
                if len(day) == 3 or not buckets[kind]:
                    continue
                forms = {item["form"] for item in day}
                pick = next((i for i, item in enumerate(buckets[kind][:6]) if item["form"] not in forms), 0)
                day.append(buckets[kind].pop(pick))
            kinds = [k for k in buckets if buckets[k]]
        rng.shuffle(day)
        ordered.extend(day)

    ART.mkdir(parents=True, exist_ok=True)
    for old in ART.glob("*.heic"):
        old.unlink()
    library = []
    for index, item in enumerate(ordered):
        name = f"aic-{item['id']}"
        subprocess.run(
            ["sips", "-s", "format", "heic", "-s", "formatOptions", "60", "-Z", "900",
             str(RAW / f"{item['id']}.jpg"), "--out", str(ART / f"{name}.heic")],
            capture_output=True, check=True,
        )
        library.append({
            "id": f"p{index + 1:04d}",
            "text": item["prompt"],
            "art": name,
            "title": clean_title(item["title"]),
            "artist": item["artist"],
            "date": item.get("date"),
        })
    OUT.write_text(json.dumps(library, indent=1, ensure_ascii=False) + "\n")
    size = sum(f.stat().st_size for f in ART.glob("*.heic")) / 1e6
    print(f"wrote {len(library)} prompts ({days} days) and {size:.1f} MB of art")


if __name__ == "__main__":
    main()
