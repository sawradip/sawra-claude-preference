# sawra-claude-preference

Sawradip's personal, cross-project Claude Code preferences — synced across machines. This repo doubles as the `personal-preferences` Claude Code skill: it's meant to live at `~/.claude/skills/personal-preferences/` so it's available in every project, on every machine, automatically.

See [`SKILL.md`](./SKILL.md) for the actual content (identity, ClickUp workflow, general working style — organized into sections, growing over time).

## Set up on a new machine

Requires `gh` (GitHub CLI) installed and authenticated (`gh auth login`) — this is a private repo.

```bash
( [ -d ~/.claude/skills/personal-preferences/.git ] && git -C ~/.claude/skills/personal-preferences pull ) || \
  gh repo clone sawradip/sawra-claude-preference ~/.claude/skills/personal-preferences
bash ~/.claude/skills/personal-preferences/install.sh
```

This clones (or updates, if already cloned) straight into the skill location Claude Code expects, then `install.sh` makes sure `~/.claude/CLAUDE.md` points at it so it's picked up automatically — safe to re-run any time.

## Updating preferences

Edit `SKILL.md` directly (add to an existing `##` section, or start a new one), commit, and push when ready. Any Claude Code session — on any project, on any machine with this repo cloned into place — will pick up the change next time it reads the file.
