# sawra-claude-preference

Sawradip's personal, cross-machine Claude Code skills — synced via this repo. It's meant
to live at `~/.claude/sawra-claude-preference/` on every machine, with each skill
subdirectory symlinked into `~/.claude/skills/<name>/` (that's where Claude Code actually
looks — it scans `~/.claude/skills/` regardless of which project a session is working in).

## What's in here

- **One subdirectory per skill**, each with its own `SKILL.md` — frontmatter (`name`/
  `description`) controls when it gets surfaced; the body is the real content.
  - `personal-preferences/` — standing personal/work preferences (task tracking, ClickUp
    workspace, general working style). Grows over time as new durable preferences come up.
  - `codex-review-loop/` — adversarial code review via the Codex CLI, fix-and-re-review
    until LGTM, with fast/standard/thorough depth and inline/background execution modes.
- **`install.sh`** — idempotent setup script that symlinks every skill subdirectory into
  `~/.claude/skills/` and makes sure `~/.claude/CLAUDE.md` points at each one. Safe to
  re-run any time; automatically picks up any new skill subdirectory added later without
  needing an update itself.
- **`README.md`** — this file. The single place for "how do I set this up / how does
  syncing work" — not duplicated elsewhere.

## Set up on a new machine

**Prerequisite:** `gh` (GitHub CLI) installed and authenticated (`gh auth login`) on that
machine. This is a private repo, so anonymous `curl`/`git clone` won't work.

```bash
( [ -d ~/.claude/sawra-claude-preference/.git ] && git -C ~/.claude/sawra-claude-preference pull ) || \
  gh repo clone sawradip/sawra-claude-preference ~/.claude/sawra-claude-preference
bash ~/.claude/sawra-claude-preference/install.sh
```

What this does:
1. If `~/.claude/sawra-claude-preference` already exists (already set up before), just
   `git pull` the latest. Otherwise, clone it fresh.
2. Run `install.sh`, which symlinks every skill subdirectory into `~/.claude/skills/` and
   makes sure `~/.claude/CLAUDE.md` has a pointer to each one. Without those pointers, a
   skill exists on disk but nothing guarantees a session actually notices it. Both steps
   are idempotent — safe to re-run, won't duplicate anything, won't clobber a pointer or
   symlink that's already correct.

**Migrating a machine set up before this repo held multiple skills:** that older layout
cloned straight to `~/.claude/skills/personal-preferences`. `install.sh` detects that and
leaves it alone rather than guessing — it prints the exact `rm -rf` to run once you've
confirmed the new checkout at `~/.claude/sawra-claude-preference` looks right, then
re-running `install.sh` will symlink it into place normally.

## Updating a skill, or adding a new one

1. Edit the relevant `SKILL.md` directly. For `personal-preferences`, add to an existing
   `##` section if it fits, or start a new one if it doesn't — decisions made in *any*
   session, on *any* project, on *any* machine, belong here rather than staying siloed to
   wherever they came up.
2. To add a brand-new skill: create a new subdirectory with its own `SKILL.md`, then run
   `install.sh` — it picks up new subdirectories automatically, no script changes needed.
3. Commit with a clear message.
4. `git push` when ready. This is a manual step on purpose — a change made in one session
   on one machine shouldn't silently go live everywhere without you choosing to sync it.

Other machines pick up the change with a plain `git pull` inside
`~/.claude/sawra-claude-preference/` (re-run `install.sh` too if a *new* skill
subdirectory was added, so it gets symlinked).
