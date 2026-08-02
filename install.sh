#!/usr/bin/env bash
# Sets up all skills in this repo on a new machine.
# Safe to re-run: idempotent, never overwrites unrelated content, never clobbers a
# pre-migration checkout (see the "already a real directory" case below).
#
# Usage (from a machine with nothing set up yet):
#   ( [ -d ~/.claude/sawra-claude-preference/.git ] && git -C ~/.claude/sawra-claude-preference pull ) || \
#     gh repo clone sawradip/sawra-claude-preference ~/.claude/sawra-claude-preference
#   bash ~/.claude/sawra-claude-preference/install.sh
#
# Layout: this repo holds one subdirectory per skill (personal-preferences,
# codex-review-loop, ...), each with its own SKILL.md. This script symlinks every one of
# them into ~/.claude/skills/<name>, which is where Claude Code actually looks.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SKILLS_DIR="$CLAUDE_DIR/skills"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"

mkdir -p "$SKILLS_DIR"

# --- One-time migration: older machines may still have the pre-multi-skill layout,
# where this repo was cloned straight to ~/.claude/skills/personal-preferences. ---
OLD_PP="$SKILLS_DIR/personal-preferences"
if [ -d "$OLD_PP/.git" ] && [ ! -L "$OLD_PP" ]; then
  echo "Found the old single-skill checkout at $OLD_PP -- this is now $REPO_DIR, so it's redundant."
  echo "Not deleting it automatically. Once you've confirmed $REPO_DIR looks right, remove it yourself:"
  echo "  rm -rf $OLD_PP"
  echo "Skipping the personal-preferences symlink until that's cleared, to avoid clobbering it."
else
  for skill_dir in "$REPO_DIR"/*/; do
    name="$(basename "$skill_dir")"
    [ -f "$skill_dir/SKILL.md" ] || continue
    target="$SKILLS_DIR/$name"
    if [ -L "$target" ]; then
      ln -sfn "$skill_dir" "$target"
      echo "Updated symlink: $target -> $skill_dir"
    elif [ -e "$target" ]; then
      echo "Skipping $name: $target already exists and isn't a symlink -- leaving it alone."
    else
      ln -s "${skill_dir%/}" "$target"
      echo "Linked: $target -> $skill_dir"
    fi
  done
fi

MARKER="sawra-claude-preference"
POINTER_PP='- A `personal-preferences` skill exists at `~/.claude/skills/personal-preferences/SKILL.md` (synced from https://github.com/sawradip/sawra-claude-preference — the personal-preferences skill). It holds Sawradip'"'"'s standing personal/work preferences — how he likes tasks tracked, his ClickUp workspace, general working style — and applies regardless of which project or repo the current session is in. Load/read it early when it would help, and keep it updated (with his review) as new durable preferences come up in conversation.'
POINTER_CRL='- A `codex-review-loop` skill exists at `~/.claude/skills/codex-review-loop/SKILL.md` (same repo). Adversarial code review via the Codex CLI as an independent reviewer, iterating fix-and-re-review until LGTM. Invoke it when asked to review a PR/branch/diff with Codex, or for phrases like "run the review loop" / "adversarially review this."'

mkdir -p "$CLAUDE_DIR"

if [ -f "$CLAUDE_MD" ] && grep -q "$MARKER" "$CLAUDE_MD" 2>/dev/null; then
  echo "~/.claude/CLAUDE.md already points at this repo's skills -- checking each pointer individually."
  if ! grep -qF 'codex-review-loop' "$CLAUDE_MD" 2>/dev/null; then
    { echo; echo "$POINTER_CRL"; } >> "$CLAUDE_MD"
    echo "Appended codex-review-loop pointer to existing $CLAUDE_MD."
  fi
else
  if [ ! -f "$CLAUDE_MD" ]; then
    {
      echo "# Global instructions"
      echo
      echo "This file applies across every project on this machine."
      echo
      echo "$POINTER_PP"
      echo
      echo "$POINTER_CRL"
    } > "$CLAUDE_MD"
    echo "Created $CLAUDE_MD with pointers to both skills."
  else
    {
      echo
      echo "$POINTER_PP"
      echo
      echo "$POINTER_CRL"
    } >> "$CLAUDE_MD"
    echo "Appended both skill pointers to existing $CLAUDE_MD."
  fi
fi

echo "Done."
