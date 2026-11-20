#!/usr/bin/env python3
"""Create the internal TestFlight group "Jack" with Jack as its only tester. Safe to rerun."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_lib

BUNDLE = "com.jackwallner.writing"
JACK_TESTER = "79e15078-d36d-4943-8b7b-a26013e201ce"


def main() -> None:
    c = asc_lib.ASCClient.from_credentials()
    app = asc_lib.find_app(c, BUNDLE)
    groups = asc_lib.list_all(c, f"/apps/{app['id']}/betaGroups")
    group = next((g for g in groups if g["attributes"]["name"] == "Jack"), None)
    if not group:
        group = c.post("/betaGroups", {"data": {"type": "betaGroups", "attributes": {
            "name": "Jack", "isInternalGroup": True, "hasAccessToAllBuilds": True,
        }, "relationships": {"app": {"data": {"type": "apps", "id": app["id"]}}}}})["data"]
        print("group created")
    testers = {t["id"] for t in asc_lib.list_all(c, f"/betaGroups/{group['id']}/betaTesters")}
    if JACK_TESTER not in testers:
        c.post(f"/betaGroups/{group['id']}/relationships/betaTesters", {"data": [{"type": "betaTesters", "id": JACK_TESTER}]})
        print("Jack added")
    print("group Jack ready")


if __name__ == "__main__":
    main()
