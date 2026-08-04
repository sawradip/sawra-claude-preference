# sawra-claude-preference

Sawradip's Claude Code skills and global instructions, synced across machines.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/sawradip/sawra-claude-preference/main/install.sh | bash
```

That is the whole thing. It clones the repo to `~/.claude/sawra-claude-preference`,
symlinks every skill into `~/.claude/skills/`, and writes a managed block into
`~/.claude/CLAUDE.md`.

**Re-run it any time** — to update after a `git pull`, or just to check. It is
idempotent: nothing is duplicated, and if there is nothing to do it says so.

```
sawra-claude-preference

  CLAUDE.md: managed block already current

Already set up and up to date. Nothing to do.
```

Requires `git` and `curl`. Nothing else — the repo is public, so no auth.

## What it touches

| Path | What happens |
|---|---|
| `~/.claude/sawra-claude-preference/` | The clone. Pulled on re-run. |
| `~/.claude/skills/<name>` | A symlink per skill. Existing real directories are never overwritten. |
| `~/.claude/CLAUDE.md` | One managed block. Created if absent, appended if the file exists, replaced in place on later runs. |

Everything outside the markers in `CLAUDE.md` is yours and is never touched:

```markdown
<!-- BEGIN sawra-claude-preference — managed by install.sh, do not edit between markers -->
...
<!-- END sawra-claude-preference -->
```

Edit inside the markers and the next run overwrites it. Change the source in
this repo instead.

## The skills

One directory per skill, each with a `SKILL.md`. The frontmatter `description`
decides when Claude surfaces it; the body is the content.

- **`personal-preferences`** — standing preferences that apply in any repo:
  task tracking and the ClickUp workspace, working style, and how code should
  be written and commented.
- **`codex-review-loop`** — adversarial review via the Codex CLI, iterating
  fix-and-re-review until LGTM.

## Adding or changing a skill

1. Edit the relevant `SKILL.md`, or create a new directory with one.
2. Run `install.sh`. New skills are picked up automatically — the CLAUDE.md
   pointers are generated from each skill's frontmatter, so the script never
   needs editing.
3. Commit, then `git push` when you want it live.

Pushing is deliberately manual. A preference captured in one session on one
machine should not go live everywhere until you have looked at it.

Other machines: re-run the install command. It pulls and re-syncs in one step.

## Migrating an older machine

Machines set up before this repo held multiple skills cloned it straight to
`~/.claude/skills/personal-preferences`. The installer detects that, refuses to
link over it, and prints the exact command to clear it. Nothing is deleted for
you.
