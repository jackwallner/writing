#!/usr/bin/env python3
"""Have Claude look at each candidate artwork, drop the ones that do not suit a calm
daily writing app, and write one prompt for each one kept.

Runs `claude -p` once per batch of artworks, a few batches at a time, and writes
catalog/review/batch-NNN.json. Finished batches are skipped on a rerun.

  python3 tools/write_prompts.py [--batch 40] [--parallel 3] [--model sonnet] [--limit 1650]
"""
from __future__ import annotations

import argparse
import json
import random
import subprocess
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CANDIDATES = ROOT / "catalog" / "candidates" / "candidates.json"
PREVIEW = ROOT / "catalog" / "raw" / "preview"
REVIEW = ROOT / "catalog" / "review"

BRIEF = """You are writing the prompt library for Inkling, a calm daily writing app. Each day it offers three
choices, and each choice is a public-domain artwork paired with one short writing prompt. The main user is a
thoughtful woman in her sixties who enjoys writing a page a day. Prompts must invite real writing and fit
the specific image.

For EACH artwork listed below: open its preview image with the Read tool and look at it carefully. Then decide.

DROP the artwork (keep=false) when any of these is true:
- any nudity or partial nudity, sexual content, violence, weapons, death, illness, blood, hunting, war
- a religious or mythological scene, saints, angels, crosses
- stereotyped or demeaning depiction of any people, or anything that could read as offensive today
- too dark, faded, blurry, damaged, mostly blank, a rough sketch, or mostly text or a diagram
- a dull image with nothing for a writer to grab onto (a stiff formal portrait, a plain vase on a plain table)
- an image a casual viewer would find unsettling or ugly
KEEP the rest: landscapes, seascapes, city and village scenes, interiors, people doing everyday things,
animals, gardens, weather, seasons, objects with a story, quiet moments, expressive faces.

For each KEPT artwork write one prompt:
- 8 to 32 words, plain warm American English, one or two sentences.
- Grounded in something you can actually see in this image (a person, a detail, the light, the weather).
- Vary the form across the batch: a story start ("The woman at the window has just read a letter. What did it say?"),
  a memory ("Write about a kitchen you remember from childhood."), a letter, a scene with dialogue, the point of
  view of a person, animal or object in the image, a list, a short poem, describing with the senses,
  what happened just before or just after, a reflection on your own life that the image calls up.
  Use each form several times; never use the same form more than four times in a row.
- Do not start more than one prompt in the batch with "Imagine". Avoid "this painting" and "this image";
  refer to what is in it ("the boat", "the man in the red coat"). Never name the artist.
- No em dashes, no en dashes, no semicolons, no exclamation marks, no emojis, no quotation of the title.
- Nothing sad for its own sake, no grief or loss prompts, no trauma. Gentle, curious, sometimes playful.

Write the result with the Write tool to OUTPUT_PATH as a JSON array, one object per artwork, in the order given:
{"id": <artwork id>, "keep": true|false, "prompt": "<prompt or empty>", "form": "<story|memory|letter|dialogue|pov|list|poem|senses|before-after|reflection>", "reason": "<short reason when dropped, else empty>"}
Every artwork listed must appear exactly once. Write only valid JSON. Do not do anything else.

Artworks (id, title, artist, date, preview path):
"""


def batches(items: list[dict], size: int) -> list[list[dict]]:
    return [items[i:i + size] for i in range(0, len(items), size)]


def run(index: int, batch: list[dict], model: str) -> str:
    out = REVIEW / f"batch-{index:03d}.json"
    if out.exists():
        try:
            if len(json.loads(out.read_text())) == len(batch):
                return f"batch {index}: done earlier"
        except json.JSONDecodeError:
            pass
    lines = [
        f"- {item['id']} | {item['title'][:90]} | {item['artist']} | {item.get('date') or ''} | {PREVIEW / (str(item['id']) + '.jpg')}"
        for item in batch
    ]
    prompt = BRIEF.replace("OUTPUT_PATH", str(out)) + "\n".join(lines)
    result = subprocess.run(
        ["claude", "-p", prompt, "--model", model, "--allowedTools", "Read,Write", "--permission-mode", "acceptEdits"],
        cwd=ROOT, capture_output=True, text=True, timeout=3600,
    )
    try:
        written = json.loads(out.read_text())
        return f"batch {index}: {sum(1 for x in written if x.get('keep'))} of {len(written)} kept"
    except Exception as error:  # noqa: BLE001
        return f"batch {index}: FAILED {error} {result.stderr[-300:]}"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--batch", type=int, default=40)
    parser.add_argument("--parallel", type=int, default=3)
    parser.add_argument("--model", default="sonnet")
    parser.add_argument("--limit", type=int, default=1650, help="artworks to review; about 80% are kept")
    args = parser.parse_args()
    REVIEW.mkdir(parents=True, exist_ok=True)
    items = [item for item in json.loads(CANDIDATES.read_text()) if (PREVIEW / f"{item['id']}.jpg").exists()]
    # Mixed batches give the writer paintings, photographs and prints side by side to vary the forms against.
    random.Random(7).shuffle(items)
    items = items[:args.limit]
    groups = batches(items, args.batch)
    print(f"{len(items)} artworks in {len(groups)} batches", flush=True)
    with ThreadPoolExecutor(max_workers=args.parallel) as pool:
        for line in pool.map(lambda pair: run(pair[0], pair[1], args.model), enumerate(groups)):
            print(line, flush=True)


if __name__ == "__main__":
    main()
