#!/usr/bin/env bash
# Package the skill into a distributable bundle: flutter-master.skill
#
# The bundle is a build artifact — it is .gitignored and regenerated from the
# markdown sources. Never edit it by hand; a stale bundle is how this repo
# ended up shipping an outdated copy of the standard.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_NAME="flutter-master"
OUT="$REPO_DIR/$SKILL_NAME.skill"

command -v zip >/dev/null || { printf 'error: zip not found\n' >&2; exit 1; }
[ -f "$REPO_DIR/SKILL.md" ] || { printf 'error: SKILL.md missing\n' >&2; exit 1; }

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

mkdir -p "$STAGE/$SKILL_NAME/references"
cp "$REPO_DIR/SKILL.md" "$STAGE/$SKILL_NAME/SKILL.md"
cp "$REPO_DIR"/references/*.md "$STAGE/$SKILL_NAME/references/"

rm -f "$OUT"
(cd "$STAGE" && zip -q -r "$OUT" "$SKILL_NAME")

printf 'built %s (%s, %s reference files)\n' \
  "$OUT" \
  "$(du -h "$OUT" | cut -f1 | tr -d ' ')" \
  "$(ls -1 "$REPO_DIR"/references/*.md | wc -l | tr -d ' ')"
