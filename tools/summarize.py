#!/usr/bin/env python3
"""Print a one-line-per-round summary from data/rounds-summary.json (stdlib only)."""
import json, pathlib

data = json.loads((pathlib.Path(__file__).resolve().parent.parent / "data" / "rounds-summary.json").read_text())
print(data["_note"], "\n")
for r in data["rounds"]:
    extras = {k: v for k, v in r.items() if k not in ("round", "start", "end", "what")}
    print(f"Round {r['round']}: {r['start']} -> {r['end']}  ({r['what']})")
    for k, v in extras.items():
        print(f"    {k}: {v}")
