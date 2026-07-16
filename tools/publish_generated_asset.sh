#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ROOT="${1:?bundle root required}"
SLUG="${2:?asset slug required}"
LOG_FILE="${3:-build/game-asset/logs/publish.log}"
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

SOURCE_BUNDLE="$BUNDLE_ROOT/$SLUG"
if [[ ! -d "$SOURCE_BUNDLE" ]]; then
  echo "Generated bundle not found: $SOURCE_BUNDLE"
  exit 1
fi

TEMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEMP_ROOT"' EXIT
cp -a "$SOURCE_BUNDLE" "$TEMP_ROOT/bundle"

echo "Publishing validated asset: $SLUG"
git config user.name "blackout-asset-bot"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

for attempt in 1 2 3; do
  echo "Publish attempt $attempt/3"
  git fetch origin main
  git reset --hard origin/main

  mkdir -p "$BUNDLE_ROOT"
  rm -rf "$BUNDLE_ROOT/$SLUG"
  cp -a "$TEMP_ROOT/bundle" "$BUNDLE_ROOT/$SLUG"

  python3 tools/update_generated_asset_catalog.py \
    --catalog "$BUNDLE_ROOT/catalog.json" \
    --asset "$BUNDLE_ROOT/$SLUG/$SLUG.asset.json"

  git add "$BUNDLE_ROOT/$SLUG" "$BUNDLE_ROOT/catalog.json"
  if git diff --cached --quiet; then
    echo "Asset already matches main; nothing to publish."
    exit 0
  fi

  git commit -m "Generate validated game asset $SLUG"
  if git push origin HEAD:main; then
    echo "Asset $SLUG published to main."
    exit 0
  fi

  echo "Main changed during publication; rebuilding the catalog from the newest main."
  sleep $((attempt * 3))
done

echo "Unable to publish $SLUG after three synchronized attempts."
exit 1
