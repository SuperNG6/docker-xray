#!/usr/bin/env bash
set -euo pipefail

case "$TAG_FILE" in
    ReleaseTag|PreReleaseTag) ;;
    *) echo "Unexpected tag file: $TAG_FILE" >&2; exit 1 ;;
esac
[[ "$VERSION" =~ ^v[0-9][a-zA-Z0-9._-]*$ ]]
git config --local user.email 'action@github.com'
git config --local user.name 'GitHub Action'
printf '%s\n' "$VERSION" > "$TAG_FILE"
git add -- "$TAG_FILE"
if git diff --cached --quiet; then exit 0; fi
git commit -m "Update Xray $TAG_FILE to $VERSION"
# The stable and pre-release merge jobs may finish at the same time.
for attempt in 1 2 3; do
    if git pull --rebase && git push; then exit 0; fi
    echo "Failed to record version (attempt $attempt/3)" >&2
    sleep 2
done
echo 'Image published, but version tracking could not be saved.' >&2
exit 1
