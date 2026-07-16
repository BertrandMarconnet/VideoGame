#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ROOT="${1:?bundle root required}"
SLUG="${2:?asset slug required}"
LOG_FILE="${3:-build/game-asset/logs/publish.log}"
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Publishing validated asset: $SLUG"
git config user.name "blackout-asset-bot"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git config rebase.autoStash true

git add "$BUNDLE_ROOT/$SLUG" "$BUNDLE_ROOT/catalog.json"
if git diff --cached --quiet; then
  echo "No generated asset changes to publish."
  exit 0
fi

git commit -m "Generate validated game asset $SLUG"

for attempt in 1 2 3; do
  echo "Publish attempt $attempt/3"
  git fetch origin main
  if ! git rebase --autostash origin/main; then
    echo "Rebase failed on attempt $attempt"
    git rebase --abort || true
    if [[ "$attempt" -eq 3 ]]; then
      exit 1
    fi
    sleep $((attempt * 3))
    continue
  fi
  if git push origin HEAD:main; then
    echo "Asset $SLUG published to main."
    exit 0
  fi
  echo "Push rejected on attempt $attempt; retrying after refreshing main."
  sleep $((attempt * 3))
done

echo "Unable to publish $SLUG after three attempts."
exit 1
