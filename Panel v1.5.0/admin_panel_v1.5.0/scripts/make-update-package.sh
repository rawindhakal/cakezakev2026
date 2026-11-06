#!/usr/bin/env bash
#
# Build a CakeZake update package (.zip) for the panel's System Updater.
#
# The panel overlays this zip's contents onto the app root (same-path files are
# REPLACED, new files ADDED, untouched files left as-is), then runs
# `migrate --force`. The panel reads the version from the FILE NAME, which MUST
# be:   cakezake-update-<x.y.z>.zip   — any other name is rejected.
#
# Only the folders that actually change between releases are shipped:
#   app  bootstrap  config  database  public  resources  routes  version.txt
# (vendor, composer files, node_modules, storage, .env, etc. are NOT shipped —
#  those rarely change; ship them manually on the rare release that needs them.)
#
# IMPORTANT before running:
#   1. Bump version.txt to the NEW version (panel rejects <= installed version).
#   2. Rebuild the frontend so public/build is current:  npm run build
#
# Usage:  bash scripts/make-update-package.sh [output.zip]

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ ! -f version.txt ]; then
  echo "ERROR: version.txt not found at repo root." >&2
  exit 1
fi

VERSION="$(tr -d '[:space:]' < version.txt)"
if ! printf '%s' "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "ERROR: version.txt must contain a semver like 3.1.0 (got '$VERSION')." >&2
  exit 1
fi

# Name MUST match the panel's expected structure: cakezake-update-<x.y.z>.zip
OUT="${1:-$ROOT/cakezake-update-${VERSION}.zip}"

if [ ! -d public/build ]; then
  echo "WARNING: public/build missing — run 'npm run build' first (shipping stale/no assets)." >&2
fi

# A plugin keeps its own strings, but installing one merges them into the panel's
# language file — and this build box is itself such an install. Replace the bundled
# copy with one that has those keys taken back out, so core never ships wording for a
# plugin the client has not bought (and so, when they do buy it, the install owns
# those keys and a later plugin version can correct them).
strip_plugin_lang_from_zip() {
  local zip="$1"
  local tmp owned
  shopt -s nullglob
  local plugin_langs=(app/Modules/*/lang/*.json)
  shopt -u nullglob

  if [ ${#plugin_langs[@]} -eq 0 ]; then
    echo "  ok: no installed plugin strings to strip"
    return 0
  fi

  tmp="$(mktemp -d)"
  mkdir -p "$tmp/resources/lang"

  owned="$(python3 - "$tmp/resources/lang/en.json" "${plugin_langs[@]}" <<'PY'
import json, sys
out, sources = sys.argv[1], sys.argv[2:]
core = json.load(open('resources/lang/en.json'))
keys = set()
for s in sources:
    try:
        keys |= set(json.load(open(s)))
    except Exception:
        pass
removed = [k for k in core if k in keys]
for k in removed:
    del core[k]
json.dump(core, open(out, 'w'), ensure_ascii=False, indent=4)
open(out, 'a').write("\n")
print(len(removed))
PY
)"

  ( cd "$tmp" && zip -q "$zip" resources/lang/en.json )
  rm -rf "$tmp"
  echo "  ok: ${owned} plugin string(s) stripped from resources/lang/en.json"
}

rm -f "$OUT"
echo "Packaging version ${VERSION} -> ${OUT}"

# Whitelist only the folders that change between releases + version.txt.
# version.txt sits at the zip root (also carried by the overlay, but the panel
# uses the file name for the version, not this file).
# Installed plugins live in app/Modules, which sits inside the shipped `app` tree, so
# they are excluded explicitly. The overlay never deletes files, which is what lets a
# client's plugins survive an update — but anything left in a developer's own
# app/Modules would otherwise be shipped to every client as part of the core package.
zip -r -q "$OUT" \
  app bootstrap config database public resources routes version.txt \
  -x 'bootstrap/cache/*.php' \
  -x 'app/Modules/*' \
  -x 'public/storage/*' \
  -x 'public/storage' \
  -x 'public/hot' \
  -x 'config/firebase.json' \
  -x 'storage/*' \
  -x '**/.DS_Store'

strip_plugin_lang_from_zip "$OUT"

echo "Done: $OUT"
ls -lh "$OUT" | awk '{print $5, $9}'
echo "Sanity — version.txt at zip root + name structure:"
unzip -l "$OUT" | grep -E ' version\.txt$' || echo "  !! version.txt NOT at root"
printf '%s' "$(basename "$OUT")" | grep -qE '^cakezake-update-[0-9]+\.[0-9]+\.[0-9]+\.zip$' \
  && echo "  name OK: $(basename "$OUT")" \
  || echo "  !! name does not match cakezake-update-x.y.z.zip — panel will reject it"
