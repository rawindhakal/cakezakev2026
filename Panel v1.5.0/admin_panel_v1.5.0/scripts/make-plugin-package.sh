#!/usr/bin/env bash
# Build a CakeZake plugin package (.zip) for a product's Plugins page.
#
# The package format is shared by every CakeZake product, so this script checks the
# things the format fixes rather than anything CakeZake-specific:
#
#   * module.json at the root, with slug, version, type and main_class
#   * the slug matching the folder name, because the folder is the identity
#   * main_class inside the plugin's own namespace, and the file actually present
#   * PHP only under app/, which is where the installer allows it
#
# The zip carries the version in its name: cakezake-plugin-<slug>-<x.y.z>.zip. The
# installer still reads the version from module.json — the file name is for people, so
# an update can be told from the build it replaces without opening the archive.
#
# Usage:  bash scripts/make-plugin-package.sh app/Modules/shiprocket [out.zip]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ $# -lt 1 ]; then
  echo "Usage: bash scripts/make-plugin-package.sh <plugin-folder> [output.zip]" >&2
  exit 1
fi

SRC="$(cd "$1" && pwd)"
FOLDER="$(basename "$SRC")"
MANIFEST="$SRC/module.json"

if [ ! -f "$MANIFEST" ]; then
  echo "ERROR: $MANIFEST not found — not a plugin folder." >&2
  exit 1
fi

read_json() { php -r '$m=json_decode(file_get_contents($argv[1]),true); echo $m[$argv[2]] ?? "";' "$MANIFEST" "$1"; }

SLUG="$(read_json slug)"
VERSION="$(read_json version)"
TYPE="$(read_json type)"
MAIN_CLASS="$(read_json main_class)"
SCOPE="$(read_json scope)"
[ -n "$SCOPE" ] || SCOPE="universal"

if ! printf '%s' "$SLUG" | grep -qE '^[a-z][a-z0-9]*(-[a-z0-9]+)*$'; then
  echo "ERROR: module.json slug '$SLUG' is not a valid kebab-case slug." >&2
  exit 1
fi

# The folder names the namespace and the licence, so the two must agree.
if [ "$SLUG" != "$FOLDER" ]; then
  echo "ERROR: module.json slug '$SLUG' does not match folder '$FOLDER'." >&2
  exit 1
fi

if ! printf '%s' "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "ERROR: module.json version must be semver like 1.0.0 (got '$VERSION')." >&2
  exit 1
fi

case "$TYPE" in
  payment|shipping) ;;
  *) echo "ERROR: module.json type must be payment or shipping (got '$TYPE')." >&2; exit 1 ;;
esac

# main_class must live inside this plugin's own namespace, or a package could point a
# host at any class in the application and have it built with the plugin's credentials.
STUDLY="$(php -r '$p=array_map("ucfirst", explode("-", $argv[1])); echo implode("", $p);' "$SLUG")"
PREFIX="App\\Modules\\${STUDLY}\\"

case "$MAIN_CLASS" in
  "$PREFIX"*) ;;
  *) echo "ERROR: main_class '$MAIN_CLASS' is not under '$PREFIX'." >&2; exit 1 ;;
esac

REL_PATH="app/$(printf '%s' "${MAIN_CLASS#"$PREFIX"}" | tr '\\' '/').php"
if [ ! -f "$SRC/$REL_PATH" ]; then
  echo "ERROR: main_class file $REL_PATH is missing from the package." >&2
  exit 1
fi

# PHP only where the installer allows it. A product-scoped plugin may also ship
# migrations; a universal one may not, because a host that knows nothing about what
# the plugin does has nowhere to put its tables.
if [ "$SCOPE" = "product" ]; then
  STRAY_PHP="$(cd "$SRC" && find . -name '*.php' -not -path './app/*' -print)"
else
  STRAY_PHP="$(cd "$SRC" && find . -name '*.php' -not -path './app/*' -print)"
fi
if [ -n "$STRAY_PHP" ]; then
  echo "ERROR: PHP files outside app/:" >&2
  echo "$STRAY_PHP" >&2
  exit 1
fi

# Files a plugin may never ship.
for forbidden in .env composer.json composer.lock .htaccess vendor .git; do
  if [ -e "$SRC/$forbidden" ]; then
    echo "ERROR: $forbidden must not be part of a plugin package." >&2
    exit 1
  fi
done

# Symlinks break the installer's safety checks.
LINKS="$(cd "$SRC" && find . -type l -print)"
if [ -n "$LINKS" ]; then
  echo "ERROR: symbolic links are not allowed:" >&2
  echo "$LINKS" >&2
  exit 1
fi

# Migrations: allowed for a product-scoped plugin, refused for a universal one.
# A plugin ships no schema. Core owns every table, so a package carrying migrations is
# a package built against an older idea of the platform — refused here rather than
# installed and silently ignored.
if [ -d "$SRC/database" ]; then
  echo "ERROR: a plugin must not ship migrations — core owns the schema." >&2
  exit 1
fi

# Every PHP file has to parse.
while IFS= read -r f; do
  php -l "$f" > /dev/null || { echo "ERROR: syntax error in $f" >&2; exit 1; }
done < <(find "$SRC" -name '*.php' -print)

OUT="${2:-$ROOT/cakezake-plugin-${SLUG}-${VERSION}.zip}"
rm -f "$OUT"
echo "Packaging plugin ${SLUG} ${VERSION} (${TYPE}, ${SCOPE}) -> ${OUT}"

# Zipped from inside the folder, so module.json sits at the zip root.
(cd "$SRC" && zip -r -q "$OUT" . \
  -x '.*' \
  -x '**/.DS_Store' \
  -x 'node_modules/*' \
  -x 'tests/*')

echo "Done: $OUT"
ls -lh "$OUT" | awk '{print $5, $9}'

echo "Sanity:"
PATHS="$(unzip -Z1 "$OUT")"
printf '%s\n' "$PATHS" | grep -qxF 'module.json' \
  && echo "  ok: module.json at zip root" \
  || { echo "  !! module.json is not at the zip root"; exit 1; }
printf '%s\n' "$PATHS" | grep -qxF "$REL_PATH" \
  && echo "  ok: $REL_PATH present" \
  || { echo "  !! $REL_PATH missing"; exit 1; }
