#!/usr/bin/env bash
# Sets up the personal-preferences skill on a new machine.
# Safe to re-run: idempotent, never overwrites unrelated content.
#
# Usage (from a machine with nothing set up yet):
#   ( [ -d ~/.claude/skills/personal-preferences/.git ] && git -C ~/.claude/skills/personal-preferences pull ) || \
#     gh repo clone sawradip/sawra-claude-preference ~/.claude/skills/personal-preferences
#   bash ~/.claude/skills/personal-preferences/install.sh

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
MARKER="sawra-claude-preference"
POINTER_LINE='- A `personal-preferences` skill exists at `~/.claude/skills/personal-preferences/SKILL.md` (synced from https://github.com/sawradip/sawra-claude-preference — the personal-preferences skill). It holds Sawradip'"'"'s standing personal/work preferences — how he likes tasks tracked, his ClickUp workspace, general working style — and applies regardless of which project or repo the current session is in. Load/read it early when it would help, and keep it updated (with his review) as new durable preferences come up in conversation.'

mkdir -p "$CLAUDE_DIR"

if [ -f "$CLAUDE_MD" ] && grep -q "$MARKER" "$CLAUDE_MD" 2>/dev/null; then
  echo "~/.claude/CLAUDE.md already points at personal-preferences — nothing to change there."
else
  if [ ! -f "$CLAUDE_MD" ]; then
    {
      echo "# Global instructions"
      echo
      echo "This file applies across every project on this machine."
      echo
      echo "$POINTER_LINE"
    } > "$CLAUDE_MD"
    echo "Created $CLAUDE_MD with a pointer to personal-preferences."
  else
    {
      echo
      echo "$POINTER_LINE"
    } >> "$CLAUDE_MD"
    echo "Appended personal-preferences pointer to existing $CLAUDE_MD."
  fi
fi

echo "personal-preferences skill is set up at $HOME/.claude/skills/personal-preferences"
echo "Done."
