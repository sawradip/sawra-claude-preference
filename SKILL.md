---
name: personal-preferences
description: Sawradip's standing personal and cross-project working preferences (task-tracking workflow, ClickUp workspace, general working style). Load this at the start of a session, or whenever you'd benefit from knowing how this specific user likes to work — applies in ANY project or repo, not just one codebase.
---

# Personal preferences

This is a growing, user-maintained record of how Sawradip likes to work with Claude, kept outside any single project so it applies everywhere — any repo, any machine, any Claude Code session. Treat it as standing instruction, not a one-off task.

## How to use and update this file

- **Reading it:** load this early in a session, or whenever behavior should be tailored to this specific user rather than generic defaults.
- **Adding to it:** when the user states a new durable preference — in *any* session, on *any* project, on *any* machine — add it under the matching `##` section below, or create a new `##` section if it doesn't fit an existing one. Don't let decisions from one session/project/computer stay siloed there; they belong here so every future session sees them too.
- **Syncing it:** this directory is a git repo (remote: https://github.com/sawradip/sawra-claude-preference, private). After editing, commit the change with a clear message. Don't `git push` automatically — leave that to the user unless they've said otherwise — but do tell them a change is committed and ready to push.
- **New machine setup:** don't duplicate setup steps here — see the repo's `README.md`, which is the single source for that.

## Identity

Works across several concurrent engagements at once, not a single job:
- **FlowGenX** — day job, hands-on engineering work.
- **Government / tender work** — separate track, tracked as "GovTech".
- A couple of **startups** he works with on the side ("Intelsense", "Stepping").
- **Personal** projects/admin.

Because of that spread, don't assume "the current repo" is the whole picture — ask or infer which hat is relevant if it's ambiguous, and keep work for different engagements clearly separated (e.g. in task tracking, below).

## ClickUp — task tracking

Uses ClickUp (MCP server `clickup`, already configured) as the single place to track what he's working on across all the engagements above, specifically so he can prep for meetings without reconstructing the day from memory.

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

_(Empty for now — add sections here as new preferences come up.)_

---

New-machine setup, prerequisites, and how the sync works: see this repo's `README.md`.
