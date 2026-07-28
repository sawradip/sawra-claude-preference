---
name: personal-preferences
description: Sawradip's standing personal and cross-project working preferences (task-tracking workflow, ClickUp workspace, general working style). Load this at the start of a session, or whenever you'd benefit from knowing how this specific user likes to work — applies in ANY project or repo, not just one codebase.
---

# Personal preferences

This is a growing, user-maintained note of how Sawradip likes to work with Claude, kept outside any single project so it applies everywhere. Treat it as standing instruction, not a one-off task. If the user states a new durable preference in conversation, add it here (in the right section, or a new one) rather than only remembering it for the current session — then let them know it was saved here so they can review/edit it later.

This file is synced via GitHub (see bottom) so the same preferences follow the user across machines. If you edit this file, and this directory is a git repo with a configured remote, commit the change (don't push automatically — let the user decide when to push, unless they've said otherwise).

## Who this is

Works across several concurrent engagements at once, not a single job:
- **FlowGenX** — day job, hands-on engineering work (this is the codebase most of these sessions happen in).
- **Government / tender work** — separate track, tracked as "GovTech".
- A couple of **startups** he works with on the side ("Intelsense", "Stepping").
- **Personal** projects/admin.

Because of that spread, don't assume "the current repo" is the whole picture — ask or infer which hat is relevant if it's ambiguous, and keep work for different engagements clearly separated (e.g. in task tracking, see below).

## Daily task tracking — ClickUp

Sawradip uses ClickUp (MCP server `clickup`, already configured) as the single place to track what he's working on across all the engagements above, specifically so he can prep for meetings without reconstructing the day from memory.

- Workspace `90182917834`, single Space `901812142207` ("Space"), one List per engagement:
  - `FlowGenX` — list id `901819936781`
  - `GovTech` — list id `901819936796`
  - `Intelsense` — list id `901819936784`
  - `Stepping` — list id `901819936795`
  - `Personal` — list id `901819936800`
- Statuses per list: `not started` → `in progress` → `completed`.
- **When you finish a real piece of work** (a fix, a feature, a diagnosis, anything meeting-report-worthy) in one of these engagements, create/update a ClickUp task in the matching list — don't just describe it in chat and let it evaporate. Default to the `FlowGenX` list when working in a FlowGenX repo unless told otherwise. Include what was done, root cause if it was a bug, and links (PRs, docs).
- **When asked for a "status update" / "evening update" / similar**, pull from what's actually logged in ClickUp for that day (`clickup_filter_tasks`, `clickup_get_task_comments`, etc.) and answer as a bullet-pointed list — not a recap of the chat conversation.

## General working style

_(Add more here as it comes up — this section is intentionally sparse right now.)_

---
Synced at: https://github.com/sawradip/claude-personal-preferences (private). To use on another machine: clone that repo, then symlink or copy its `SKILL.md` into `~/.claude/skills/personal-preferences/SKILL.md` on that machine so it loads automatically in every project there too.
