# sawra-claude-preference

Sawradip's personal, cross-project Claude Code preferences — synced across machines. This repo doubles as the `personal-preferences` Claude Code skill: it's meant to live at `~/.claude/skills/personal-preferences/` on every machine, so it's available in every project automatically (Claude Code scans `~/.claude/skills/` regardless of which repo a session is working in).

## What's in here

- **`SKILL.md`** — the actual skill Claude Code reads. Frontmatter (`name`/`description`) controls when it gets surfaced; the body is the real content, organized into `##` sections (Identity, ClickUp — task tracking, General working style, and whatever gets added over time). This is the file that grows.
- **`install.sh`** — idempotent setup script, see below. Safe to re-run any time.
- **`README.md`** — this file. The single place for "how do I set this up / how does syncing work" — not duplicated elsewhere.

## Set up on a new machine

**Prerequisite:** `gh` (GitHub CLI) installed and authenticated (`gh auth login`) on that machine. This is a private repo, so anonymous `curl`/`git clone` won't work.

```bash
( [ -d ~/.claude/skills/personal-preferences/.git ] && git -C ~/.claude/skills/personal-preferences pull ) || \
  gh repo clone sawradip/sawra-claude-preference ~/.claude/skills/personal-preferences
bash ~/.claude/skills/personal-preferences/install.sh
```

What this does:
1. If `~/.claude/skills/personal-preferences` already exists (already set up before), just `git pull` the latest. Otherwise, clone straight into that path — it's exactly where Claude Code expects to find a user-level skill.
2. Run `install.sh`, which makes sure `~/.claude/CLAUDE.md` (loaded automatically in every session, every project, on that machine) has a pointer to this skill. Without that pointer, the skill exists on disk but nothing guarantees a session actually notices it. `install.sh` won't add a duplicate pointer if one's already there — checks by content, not just file existence.

The whole block is safe to paste again later (e.g. after `SKILL.md` gets new content pushed from elsewhere) — both steps are idempotent, nothing gets overwritten or duplicated.

## Updating preferences

1. Edit `SKILL.md` directly — add to an existing `##` section if it fits, or start a new `##` section if it doesn't. Decisions made in *any* Claude Code session, on *any* project, on *any* machine, belong here rather than staying siloed to wherever they came up.
2. Commit with a clear message.
3. `git push` when ready. This is a manual step on purpose — a preference decided in one session on one machine shouldn't silently go live everywhere without you choosing to sync it.

Other machines pick up the change by running the setup block above again (pull instead of clone, since it's already there) — or just a plain `git pull` inside `~/.claude/skills/personal-preferences/` if `install.sh` has already run once on that machine.
