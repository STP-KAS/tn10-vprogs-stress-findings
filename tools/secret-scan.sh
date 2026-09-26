#!/bin/bash
# Pre-push secret scan (run from the repo root). Fails on extended private keys, key-like JSON fields with values,
# 64-hex strings next to key-ish words, and 12+ word lowercase mnemonic-like runs. Optionally set SECRET_DIR to a local
# directory of secret files: any 64-hex / mnemonic / xprv value found there must not appear in the repo (values never printed).
set -u; bad=0
files=$(git ls-files -co --exclude-standard)
[ -z "$files" ] && { echo "secret-scan: no files"; exit 0; }
echo "$files" | xargs rg -n -i '\b[xtk]prv[0-9A-Za-z]{20,}' && { echo "FAIL: extended private key"; bad=1; }
echo "$files" | xargs rg -n -i '"(priv(ate)?_?key|secret|mnemonic|seed|phrase)"\s*:\s*"' && { echo "FAIL: key field with value"; bad=1; }
echo "$files" | xargs rg -n -i '(key|priv|secret|seed).{0,20}[0-9a-f]{64}' && { echo "FAIL: 64-hex near key word"; bad=1; }
echo "$files" | xargs rg -n -P '(?<![a-z])([a-z]{3,8} ){11}[a-z]{3,8}(?![a-z])' | rg -v -i 'the|and|with|that|for|this|from|when|was|are|not' && { echo "FAIL: mnemonic-like run"; bad=1; }
if [ -n "${SECRET_DIR:-}" ] && [ -d "$SECRET_DIR" ]; then
  python3 - "$SECRET_DIR" "$files" <<'PY' || bad=1
import sys, os, re
d, files = sys.argv[1], sys.argv[2].split("\n"); needles = set()
for f in os.listdir(d):
    try: t = open(os.path.join(d, f), errors="ignore").read()
    except Exception: continue
    needles.update(re.findall(r"[0-9a-fA-F]{64}|[a-z]+(?: [a-z]+){11,23}|[xtk]prv\w+", t))
hit = 0
for p in files:
    try: c = open(p, errors="ignore").read()
    except Exception: continue
    if any(n in c for n in needles): print(f"FAIL: secret material found in {p} (value not shown)"); hit = 1
sys.exit(hit)
PY
fi
[ $bad = 0 ] && echo "secret-scan: OK" || { echo "secret-scan: FAILED"; exit 1; }
