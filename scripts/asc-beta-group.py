#!/usr/bin/env python3
"""Create the internal TestFlight group "Jack" with Jack as its only tester. Safe to rerun."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_lib

BUNDLE = "com.jackwallner.writing"


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
    # Jack is the account holder, the one App Store Connect user with the ACCOUNT_HOLDER role.
    jack = next(u["attributes"] for u in c.get("/users?limit=200")["data"]
                if "ACCOUNT_HOLDER" in u["attributes"]["roles"])
    members = {t["attributes"]["email"] for t in asc_lib.list_all(c, f"/betaGroups/{group['id']}/betaTesters")}
    if jack["username"] not in members:
        c.post("/betaTesters", {"data": {"type": "betaTesters", "attributes": {
            "email": jack["username"], "firstName": jack["firstName"], "lastName": jack["lastName"],
        }, "relationships": {"betaGroups": {"data": [{"type": "betaGroups", "id": group["id"]}]}}}})
        print("Jack added")
    # Adding a tester to a group sends no email; an invitation does, once a build exists.
    builds = c.get(f"/builds?filter[app]={app['id']}&filter[processingState]=VALID&limit=1")["data"]
    for t in asc_lib.list_all(c, f"/betaGroups/{group['id']}/betaTesters"):
        if builds and t["attributes"].get("state") == "NOT_INVITED":
            c.post("/betaTesterInvitations", {"data": {"type": "betaTesterInvitations", "relationships": {
                "app": {"data": {"type": "apps", "id": app["id"]}},
                "betaTester": {"data": {"type": "betaTesters", "id": t["id"]}}}}})
            print("Jack invited")
    print("group Jack ready" if builds else "group Jack ready; no processed build yet, rerun to invite")


if __name__ == "__main__":
    main()
