#!/usr/bin/env bash
#
# One-command setup. Works two ways:
#
#   curl -fsSL https://raw.githubusercontent.com/sawradip/sawra-claude-preference/main/install.sh | bash
#   bash ~/.claude/sawra-claude-preference/install.sh
#
# Piped, it clones or pulls the repo first. From a clone, it uses that clone.
#
# Re-running is a no-op when nothing has changed: it reports "already up to
# date" rather than appending anything a second time.

set -euo pipefail

REPO_URL="https://github.com/sawradip/sawra-claude-preference.git"
CLAUDE_DIR="$HOME/.claude"
REPO_DIR="$CLAUDE_DIR/sawra-claude-preference"
SKILLS_DIR="$CLAUDE_DIR/skills"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"

BEGIN_MARK="<!-- BEGIN sawra-claude-preference — managed by install.sh, do not edit between markers -->"
END_MARK="<!-- END sawra-claude-preference -->"

changed=0
note() { printf '  %s\n' "$1"; }

# When piped through bash, BASH_SOURCE is not a readable path, so fetch the repo.
if [ -f "${BASH_SOURCE[0]:-}" ]; then
  REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  mkdir -p "$CLAUDE_DIR"
  if [ -d "$REPO_DIR/.git" ]; then
    note "Updating $REPO_DIR"
    git -C "$REPO_DIR" pull --quiet --ff-only
  else
    note "Cloning into $REPO_DIR"
    git clone --quiet "$REPO_URL" "$REPO_DIR"
  fi
fi

printf '\nsawra-claude-preference\n\n'

# ---------------------------------------------------------------- skills ----
mkdir -p "$SKILLS_DIR"

# Pre-multi-skill machines cloned this repo straight to the skill path. Linking
# over it would destroy an un-pushed checkout, so stop and let the user clear it.
legacy="$SKILLS_DIR/personal-preferences"
if [ -d "$legacy/.git" ] && [ ! -L "$legacy" ]; then
  printf 'Old single-skill checkout found at %s\n' "$legacy"
  printf 'It is superseded by %s. Once that looks right:\n\n' "$REPO_DIR"
  printf '  rm -rf %s && bash %s/install.sh\n\n' "$legacy" "$REPO_DIR"
  exit 1
fi

skills=()
for dir in "$REPO_DIR"/*/; do
  [ -f "$dir/SKILL.md" ] || continue
  name="$(basename "$dir")"
  skills+=("$name")
  target="$SKILLS_DIR/$name"
  want="${dir%/}"

  if [ -L "$target" ] && [ "$(readlink "$target")" = "$want" ]; then
    continue
  elif [ -e "$target" ] && [ ! -L "$target" ]; then
    note "skill $name: $target exists and is not a symlink, leaving it alone"
    continue
  fi
  ln -sfn "$want" "$target"
  note "skill $name: linked"
  changed=1
done

# --------------------------------------------------------------- CLAUDE.md ----
# Pointers are generated from each SKILL.md's frontmatter, so a new skill needs
# no edit here.
skill_line() {
  local dir="$1" name desc
  name="$(basename "$dir")"
  desc="$(awk '/^description:/{sub(/^description:[ ]*/,""); print; exit}' "$dir/SKILL.md")"
  printf -- '- **`%s`** (`~/.claude/skills/%s/SKILL.md`) — %s\n' "$name" "$name" "$desc"
}

block="$BEGIN_MARK
## Skills

Synced from <$REPO_URL>. Re-run \`install.sh\` after pulling changes.

"
for name in "${skills[@]}"; do
  block+="$(skill_line "$REPO_DIR/$name")
"
done

block+="
## Writing code

Applies to every project on this machine.

- **Make the code self-explanatory first.** Clear names, small functions,
  obvious structure. If something needs explaining, change the code so it does
  not before reaching for a comment.
- **Comments are the fallback, capped at one or two lines.** A paragraph means
  the code is wrong, or the explanation belongs in the commit message.
- **Never narrate history in a comment** — what the code used to be, what
  changed, why it changed. The reader cannot see the old code and git already
  has it. That belongs in the commit.

Detail and examples: the \`personal-preferences\` skill.
$END_MARK"

mkdir -p "$CLAUDE_DIR"

if [ ! -f "$CLAUDE_MD" ]; then
  printf '# Global instructions\n\n%s\n' "$block" > "$CLAUDE_MD"
  note "CLAUDE.md: created"
  changed=1
elif ! grep -qF "$BEGIN_MARK" "$CLAUDE_MD"; then
  printf '\n%s\n' "$block" >> "$CLAUDE_MD"
  note "CLAUDE.md: managed block appended, your existing content untouched"
  changed=1
else
  current="$(awk -v b="$BEGIN_MARK" -v e="$END_MARK" \
    'index($0,b){f=1} f{print} index($0,e){f=0}' "$CLAUDE_MD")"
  if [ "$current" = "$block" ]; then
    note "CLAUDE.md: managed block already current"
  else
    before="$(awk -v b="$BEGIN_MARK" 'index($0,b){exit} {print}' "$CLAUDE_MD")"
    after="$(awk -v e="$END_MARK" 'f{print} index($0,e){f=1}' "$CLAUDE_MD")"
    printf '%s\n%s\n%s\n' "$before" "$block" "$after" > "$CLAUDE_MD.tmp"
    mv "$CLAUDE_MD.tmp" "$CLAUDE_MD"
    note "CLAUDE.md: managed block updated in place"
    changed=1
  fi
fi

printf '\n'
if [ "$changed" -eq 0 ]; then
  printf 'Already set up and up to date. Nothing to do.\n\n'
else
  printf 'Done. Restart any running Claude Code session to pick up the changes.\n\n'
fi
