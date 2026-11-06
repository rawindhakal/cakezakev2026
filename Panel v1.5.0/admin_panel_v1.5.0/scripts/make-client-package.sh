#!/usr/bin/env bash
#
# Build a FULL CakeZake package (.zip) to hand to a client for a fresh install —
# the whole project, minus dev-only / machine-specific / sensitive files.
#
# EXCLUDED (per delivery policy):
#   node_modules/            — client runs `npm install` if they build assets
#   config/firebase.json     — private service-account credentials
#   storage/installed        — install marker (so the client's installer runs)
#   storage/app/public/*     — uploaded media / images (client starts clean; the
#                              folder itself ships via its .gitignore so storage:link works)
#   storage/app/pwa-icons/*  — icons rendered from OUR logo; regenerated on demand
#   plugin runtime state     — which plugins booted here, what was quarantined, and any
#                              half-finished install. It describes THIS machine, names
#                              plugins the client has not bought, and a stale quarantine
#                              entry would disable a plugin on their server that is
#                              perfectly fine on it.
#   public/hot               — vite dev-server marker; its presence makes the panel
#                              load assets from localhost:5173 and show nothing
#   runtime junk             — logs, framework cache/sessions/views, debugbar,
#                              bootstrap/cache, .git, .DS_Store, existing zips
#
# KEPT: vendor/ (so it runs without composer), public/build (built assets),
#       .env, .env.example, everything else.
#
# The shipped .env is rewritten on the way in: APP_ENV=production, APP_DEBUG=false, and
# an empty APP_KEY / Pusher / Reverb values. See sanitize_env_in_zip.
#
# BEFORE running: rebuild the frontend so public/build is current:  npm run build
#
# Usage:  bash scripts/make-client-package.sh [output.zip]

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="unknown"
if [ -f version.txt ]; then
  VERSION="$(tr -d '[:space:]' < version.txt)"
fi

OUT="${1:-$ROOT/admin_panel_v${VERSION#v}.zip}"

if [ ! -d public/build ]; then
  echo "WARNING: public/build missing — run 'npm run build' first (shipping stale/no assets)." >&2
fi
if [ ! -d vendor ]; then
  echo "WARNING: vendor/ missing — run 'composer install' first (client package won't run out of the box)." >&2
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

# The .env the client receives must read as a fresh production server, not as this build
# box. Rewritten inside the zip rather than on disk, so the one here keeps working.
#
#   APP_ENV=production   a client install is never 'local'
#   APP_KEY=             empty, so `php artisan key:generate` writes their own; one shared
#                        key would let every client decrypt every other client's data
#   APP_DEBUG=false      a stack trace on a live store leaks paths, queries and env values
#   PUSHER_ / REVERB_    values emptied, keys kept: the client fills in their own, and
#                        our credentials in their file would push their store through our
#                        account. The key stays so they can see what to fill in.
sanitize_env_in_zip() {
  local zip="$1"
  local tmp report

  tmp="$(mktemp -d)"
  report="$(python3 - "$tmp/.env" <<'ENVPY'
import sys

out_path = sys.argv[1]
forced = {'APP_ENV': 'production', 'APP_KEY': '', 'APP_DEBUG': 'false'}
# Emptied, not removed: the client needs to see which keys to fill in.
blank_prefixes = ('PUSHER_', 'REVERB_', 'VITE_REVERB_')

lines = []
seen = set()
blanked = 0
for raw in open('.env', encoding='utf-8').read().splitlines():
    key = raw.split('=', 1)[0].strip() if '=' in raw else ''
    if key.startswith(blank_prefixes):
        if raw.split('=', 1)[1].strip() != '':
            blanked += 1
        raw = key + '='
    elif key in forced:
        raw = key + '=' + forced[key]
        seen.add(key)
    lines.append(raw)

# A key the file never had still has to be stated, not left to the framework.
missing = [k for k in forced if k not in seen]
for key in reversed(missing):
    lines.insert(0, key + '=' + forced[key])

# Nothing is dropped any more, but an env file with a run of blank lines reads badly.
cleaned = []
for line in lines:
    if line.strip() == '' and cleaned and cleaned[-1].strip() == '':
        continue
    cleaned.append(line)
while cleaned and cleaned[-1].strip() == '':
    cleaned.pop()

with open(out_path, 'w', encoding='utf-8') as fh:
    fh.write('\n'.join(cleaned) + '\n')

print('%d value(s) emptied, %d forced%s' % (
    blanked, len(forced), (', ' + ', '.join(missing) + ' added') if missing else ''))
ENVPY
)"

  ( cd "$tmp" && zip -q "$zip" .env )
  rm -rf "$tmp"
  echo "  ok: .env sanitized (${report})"
}

rm -f "$OUT"
echo "Packaging FULL client build ${VERSION} -> ${OUT}"

# Zip the whole project, excluding the delivery-policy paths + runtime junk.
#
# app/Modules is excluded because a plugin is a separate purchase: whatever is
# installed on this machine is licensed to this domain, so shipping it would hand
# every client paid code they did not buy, along with a licence that refuses them.
zip -r -q "$OUT" . \
  -x '.git/*' \
  -x '.vscode/*' \
  -x '.cursor/*' \
  -x '.claude/*' \
  -x '.well-known/*' \
  -x 'node_modules/*' \
  -x '.env.local' \
  -x '.env.backup' \
  -x '.env.testing' \
  -x 'config/firebase.json' \
  -x 'public/hot' \
  -x 'public/storage' \
  -x 'public/storage/*' \
  -x 'storage/installed' \
  -x 'storage/installed/*' \
  -x 'storage/app/public/[!.]*' \
  -x 'storage/app/pwa-icons/[!.]*' \
  -x 'storage/app/plugins_install/[!.]*' \
  -x 'storage/app/addons/[!.]*' \
  -x 'storage/app/addons_install/[!.]*' \
  -x 'storage/app/addon-packages/[!.]*' \
  -x 'storage/*.key' \
  -x 'storage/oauth-private.key' \
  -x 'storage/oauth-public.key' \
  -x 'storage/logs/[!.]*' \
  -x 'storage/debugbar/[!.]*' \
  -x 'storage/framework/cache/data/[!.]*' \
  -x 'storage/framework/sessions/[!.]*' \
  -x 'storage/framework/views/[!.]*' \
  -x 'bootstrap/cache/[!.]*' \
  -x 'app/Modules/*' \
  -x 'cakezake-*.zip' \
  -x 'admin_panel_*.zip' \
  -x "$(basename "$OUT")" \
  -x '.DS_Store' \
  -x '*/.DS_Store'

strip_plugin_lang_from_zip "$OUT"
sanitize_env_in_zip "$OUT"

echo "Done: $OUT"
ls -lh "$OUT" | awk '{print $5, $9}'

# Compare against the archive's path list, not a substring of the whole listing line.
PATHS="$(unzip -Z1 "$OUT")"
leaked=0

echo "Sanity — excluded paths must NOT appear:"
for p in 'config/firebase.json' 'storage/installed' 'public/hot'; do
  if printf '%s\n' "$PATHS" | grep -qxF "$p"; then
    echo "  !! LEAKED: $p is in the zip"
    leaked=1
  else
    echo "  ok: $p excluded"
  fi
done
# A paid plugin installed on this machine must never reach a client's package.
if printf '%s\n' "$PATHS" | grep -q '^app/Modules/.'; then
  echo "  !! LEAKED: an installed plugin is in the zip"
  leaked=1
else
  echo "  ok: app/Modules/ (installed plugins) excluded"
fi

# Plugin runtime state must arrive EMPTY: a client's install decides for itself what
# booted and what is quarantined. Shipping ours would carry our plugin names and, worse,
# a quarantine entry that switches a working plugin off on their server.
for f in 'storage/app/addons/booted.json' 'storage/app/addons/quarantine.json'; do
  if printf '%s\n' "$PATHS" | grep -qxF "$f"; then
    echo "  !! LEAKED: $f is in the zip"
    leaked=1
  fi
done
echo "  ok: plugin boot/quarantine state not shipped"

for prefix in 'node_modules/' 'storage/app/public/' 'storage/app/pwa-icons/' 'storage/app/plugins_install/'; do
  # The folder and its .gitignore placeholder are meant to ship; only real files leak.
  n="$(printf '%s\n' "$PATHS" | grep -E "^${prefix}.+" | grep -vE "^${prefix}\.gitignore$" | grep -c . || true)"
  if [ "$n" -gt 0 ]; then
    echo "  !! LEAKED: $n file(s) under $prefix"
    leaked=1
  else
    echo "  ok: $prefix empty (folder kept)"
  fi
done

# Read the env file back OUT of the finished zip: the point is what the client receives,
# not what the rewrite believed it wrote.
echo "Sanity — shipped .env:"
SHIPPED_ENV="$(unzip -p "$OUT" .env)"
for expected in 'APP_ENV=production' 'APP_KEY=' 'APP_DEBUG=false'; do
  if printf '%s\n' "$SHIPPED_ENV" | grep -qxF "$expected"; then
    echo "  ok: $expected"
  else
    echo "  !! WRONG: $expected missing — shipped value: $(printf '%s\n' "$SHIPPED_ENV" | grep -E "^${expected%%=*}=" || echo '(key absent)')"
    leaked=1
  fi
done
still_set="$(printf '%s\n' "$SHIPPED_ENV" | grep -cE '^(PUSHER_|REVERB_|VITE_REVERB_)[A-Z_]*=.+' || true)"
if [ "$still_set" -gt 0 ]; then
  echo "  !! LEAKED: $still_set Pusher / Reverb value(s) still filled in"
  leaked=1
else
  echo "  ok: Pusher / Reverb keys kept, values empty"
fi

if [ "$leaked" -ne 0 ]; then
  echo "Package NOT safe to hand over — fix the exclusions above." >&2
  exit 1
fi
