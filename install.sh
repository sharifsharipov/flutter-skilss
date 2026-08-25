#!/usr/bin/env bash
# Install this repo as the `flutter-master` Claude skill.
#
# The skill directory becomes a SYMLINK to this repo, so there is exactly one
# copy of every file. Editing a reference here is instantly live in the skill —
# no sync step, no drift.
#
# Usage:  ./install.sh            install (symlink)
#         ./install.sh --copy     install by copying instead (no symlink)
#         ./install.sh --uninstall
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_NAME="flutter-master"
SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
TARGET="$SKILLS_DIR/$SKILL_NAME"

die() { printf 'error: %s\n' "$1" >&2; exit 1; }

[ -f "$REPO_DIR/SKILL.md" ] || die "SKILL.md not found in $REPO_DIR"
[ -d "$REPO_DIR/references" ] || die "references/ not found in $REPO_DIR"

backup_existing() {
  [ -e "$TARGET" ] || [ -L "$TARGET" ] || return 0
  if [ -L "$TARGET" ]; then
    printf 'replacing existing symlink -> %s\n' "$(readlink "$TARGET")"
    rm "$TARGET"
    return 0
  fi
  # NOTE: the backup must land OUTSIDE $SKILLS_DIR — every directory in there is
  # discovered as a skill, dot-prefixed or not, and a stale copy would load as a
  # duplicate of this one.
  local backup_dir="${CLAUDE_SKILL_BACKUP_DIR:-$HOME/.claude/skill-backups}"
  local backup="$backup_dir/$SKILL_NAME.$(date +%Y%m%d%H%M%S)"
  mkdir -p "$backup_dir"
  printf 'backing up existing directory -> %s\n' "$backup"
  mv "$TARGET" "$backup"
}

case "${1:-}" in
  --uninstall)
    [ -e "$TARGET" ] || [ -L "$TARGET" ] || die "nothing installed at $TARGET"
    if [ -L "$TARGET" ]; then rm "$TARGET"; else backup_existing; fi
    printf 'uninstalled %s\n' "$TARGET"
    exit 0
    ;;
  --copy)
    mkdir -p "$SKILLS_DIR"
    backup_existing
    mkdir -p "$TARGET/references"
    cp "$REPO_DIR/SKILL.md" "$TARGET/SKILL.md"
    cp "$REPO_DIR"/references/*.md "$TARGET/references/"
    printf 'copied to %s (re-run after every edit — prefer the symlink install)\n' "$TARGET"
    ;;
  ""|--symlink)
    # The skill directory is real; only SKILL.md and references/ are links back
    # to the repo. Symlinking the whole repo would also expose .git, the build
    # scripts, and the packaged bundle inside the skill folder.
    mkdir -p "$SKILLS_DIR"
    backup_existing
    mkdir -p "$TARGET"
    ln -sfn "$REPO_DIR/SKILL.md" "$TARGET/SKILL.md"
    ln -sfn "$REPO_DIR/references" "$TARGET/references"
    printf 'linked %s -> %s (SKILL.md + references/)\n' "$TARGET" "$REPO_DIR"
    ;;
  *)
    die "unknown option: $1 (use --copy, --uninstall, or no argument)"
    ;;
esac

printf 'SKILL.md      : %s\n' "$(test -f "$TARGET/SKILL.md" && echo ok || echo MISSING)"
printf 'references/   : %s file(s)\n' "$(ls -1 "$TARGET"/references/*.md 2>/dev/null | wc -l | tr -d ' ')"
printf '\nRestart Claude Code (or start a new session) to pick up the skill.\n'
