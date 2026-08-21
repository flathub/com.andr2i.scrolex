#!/usr/bin/env bash
# Update this Flathub packaging repo to an upstream scrolex release.
# Usage: ./update-release.sh 0.11.5

set -euo pipefail

UPSTREAM_URL="https://github.com/molecule-man/scrolex.git"
RAW_BASE="https://raw.githubusercontent.com/molecule-man/scrolex"
MANIFEST="com.andr2i.scrolex.yml"
CARGO_SOURCES="cargo-sources.json"

if [ $# -ne 1 ]; then
    echo "usage: $0 <version>   e.g. $0 0.11.5" >&2
    exit 2
fi
TAG="$1"

cd "$(dirname "$0")"

echo "Resolve tag $TAG"
COMMIT="$(git ls-remote --tags "$UPSTREAM_URL" "refs/tags/$TAG" | cut -f1)"
if [ -z "$COMMIT" ]; then
    echo "error: tag $TAG does not exist in $UPSTREAM_URL" >&2
    exit 1
fi
echo "commit $COMMIT"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

for f in "$MANIFEST" "$CARGO_SOURCES"; do
    curl -sfL -o "$TMP/$f" "$RAW_BASE/$COMMIT/packaging/flatpak/$f"
done

awk -v url="$UPSTREAM_URL" -v tag="$TAG" -v commit="$COMMIT" '
    match($0, /^ *path: \.\.\/\.\.$/) {
        indent = substr($0, 1, index($0, "path") - 1)
        print indent "url: " url
        print indent "tag: " tag
        print indent "commit: " commit
        replaced = 1
        next
    }
    /^ *branch: / { next }
    { print }
    END { if (!replaced) exit 1 }
' "$TMP/$MANIFEST" > "$TMP/out.yml" || {
    echo "error: upstream manifest has no 'path: ../..' source. Update this script." >&2
    exit 1
}

grep -q "commit: $COMMIT" "$TMP/out.yml"
! grep -q 'path: \.\./\.\.' "$TMP/out.yml"

mv "$TMP/out.yml" "$MANIFEST"
mv "$TMP/$CARGO_SOURCES" "$CARGO_SOURCES"

echo
git --no-pager diff --stat
