---
name: codex-review-loop
description: Adversarial code review using the Codex CLI as an independent second-model reviewer, iterating fix-and-re-review until LGTM. Supports fast (one tight pass) vs standard vs thorough (multi-round, multi-lens) depth, and inline (blocking, in this conversation) vs background (autonomous subagent that pushes fixes to the PR and reports back) execution. Invoke when the user asks to "review this with Codex", "run the review loop", "adversarially review my changes/PR", or similar — on a PR, a branch, or the current worktree's diff.
---

# Codex review loop

Runs Codex CLI as an independent adversarial reviewer against a diff (PR, branch, or
current worktree), then fixes what it finds and re-reviews, until Codex says LGTM or a
round cap is hit. Codex is a genuinely different model family from the one running this
skill — that's the point. Don't substitute a self-review for it.

## Reading the request

Two independent axes. Infer both from phrasing; ask only if truly ambiguous (e.g. a bare
"review this" with no other signal — default to **standard + inline** rather than asking).

**Depth** (token/time vs. confidence):
- **fast** — "quick check", "just a fast look", "sanity check this" → one tight round, no
  resume-nudging tolerated.
- **standard** (default) — no qualifier given → up to 3 rounds, single reviewer per round.
- **thorough** — "this is critical", "look into this properly", "take your time", "be
  thorough" → up to 5 rounds, multi-lens per round (see below), findings adversarially
  re-checked before fixing.

**Mode** (blocking vs. not):
- **inline** (default) — runs in this conversation, reports each round as it happens.
- **background** — "don't block me on this", "run it in the background", "I don't want to
  wait", or the user says they need to keep moving on a stacked/dependent branch → spawn a
  single self-contained subagent (see §5) that does the whole loop unattended and pushes
  fixes straight to the PR. Report back only a short "kicked off, I'll let you know" and
  rely on its completion notification — don't fabricate progress in between.

## 1. Setup

- Work in a **dedicated git worktree** checked out at the target branch/PR head — never
  the user's live working tree. If resuming work on an existing PR, fetch and check out
  fresh; don't assume yesterday's worktree is still accurate.
- Confirm what's actually being reviewed before dispatching Codex: `git diff
  <base>...<head>` (or the PR's diff via `gh pr diff <N>`) — know the file list and rough
  size before writing the prompt, so the budget in §2 is calibrated to the actual change,
  not guessed.

## 2. The Codex prompt — the fix for the failure mode this skill exists to avoid

Every round this skill has been run without the following two things, Codex wandered
past its own judgment point and needed 2-3 manual "stop exploring and write NOW" nudges
before it would commit to a verdict — that's the dominant cost of running this loop, and
it must be engineered out at the prompt level, not patched reactively per round:

1. **An explicit tool-call budget**, sized to depth:
   - fast: ~6 calls
   - standard: ~12 calls
   - thorough: ~20 calls per lens
   State it directly: *"You have at most N tool calls. Once you reach that budget, or once
   you're confident, STOP exploring immediately and emit the verdict block below — do not
   keep investigating past that point."*

2. **A mandatory, exactly-delimited verdict block**, required as the literal last thing in
   the response:
   ```
   ---VERDICT---
   STATUS: LGTM | CHANGES_NEEDED
   FINDINGS:
   - [severity: high|medium|low] file:line — one-sentence description of the defect and why it's wrong
   (leave FINDINGS empty if STATUS is LGTM)
   ---END---
   ```
   This is a prompt convention, not a tool-call — the Codex CLI isn't given a structured-
   output tool here. Parse it back out with a plain `sed`/`grep` between the two markers;
   don't try to interpret free-form prose as a verdict.

Launch detached so this doesn't block the turn:
```bash
setsid codex exec --sandbox read-only --skip-git-repo-check - \
  > /path/to/round-N-output.txt 2>&1 < prompt.txt &
```
run via Bash with `run_in_background: true`.

**Retrieve the verdict from the session log, not the redirected stdout file** — the stdout
file has been observed truncated/incomplete relative to the real transcript. Parse the
last `role: assistant` message with text content out of `~/.codex/sessions/**/*.jsonl`
(most recent file), then extract the `---VERDICT---...---END---` block from it.

If a round genuinely produces no parseable verdict block even with the above (rare once
the prompt convention is used consistently) — resume once with `codex exec resume --last
"Emit the VERDICT block now, in the exact format specified, with zero further tool
calls."` Don't chain more than one resume; if it still doesn't converge, treat that round
as CHANGES_NEEDED with an empty findings list and note the tooling failure to the user
rather than looping indefinitely.

## 3. Thorough mode: parallel lenses instead of one generalist

For **thorough** depth, don't run one generic reviewer per round — dispatch several
concurrently, each with a narrow focus, then merge findings before fixing:

- **correctness** — does the logic do what it claims; edge cases, off-by-one, race
  conditions, wrong assumptions about state/timing
- **security / data-integrity** — injection, auth bypass, secrets, anything that could
  corrupt or leak persisted data
- **consistency-with-existing-patterns** — does this match how the rest of the codebase
  already solves the same problem, or does it quietly introduce a second way to do the
  same thing (the exact failure class this whole practice was born to catch — see the
  session note in the skill's origin below)

Each lens gets its own budgeted, verdict-terminated prompt (§2) and its own background
`codex exec` invocation, launched together, not sequentially. If the Workflow tool is
available and the user has opted into multi-agent orchestration for this task, this maps
directly onto its `parallel()`/adversarial-verify patterns — use it there instead of
hand-rolling the concurrency. Otherwise, just fire the 2-3 `setsid` background Bash calls
in the same turn and read each one's `.jsonl` once all have completed.

Before spending time fixing a thorough-mode finding, treat it as unverified — Codex can
produce false positives too. A quick sanity pass (does the flagged file:line actually say
what the finding claims?) before implementing a fix is cheap insurance, especially the
first time this skill is used against a given codebase.

## 4. The fix-and-loop step

On `CHANGES_NEEDED`: fix each finding directly (normal Edit/Write work — Codex only
reviews, it never writes code in this workflow), commit with a message describing what the
round found and fixed, then start the next round *from the updated diff*, up to the round
cap for the chosen depth. On `LGTM`, or when the round cap is reached without one: stop.

**Always write the full review trail into the PR description** before finishing — what
each round found, what got fixed, and the final verdict. This is what makes the loop
auditable later and is not optional in either mode.

**Push verification**: after every push in this loop, confirm with `git ls-remote
<remote> <branch>` against local `git rev-parse HEAD` — an exact SHA match, not just a
zero exit code — before treating anything as landed. A push can silently fail to land
even when the command itself doesn't error.

## 5. Background mode

Spawn exactly one `Agent` call: `isolation: "worktree"`, `run_in_background: true`. The
prompt must be fully self-contained (the agent has no memory of this conversation) —
include: the PR/branch to review, the chosen depth and its round cap, the full loop
mechanics from §§2-4 above (or a pointer to this skill file's path, if the subagent type
can load skills), and an explicit instruction to push fixes and update the PR description
itself rather than just reporting findings back. Its final message must state: final
verdict, how many rounds it took, a one-line summary of what was fixed each round, and the
PR URL.

Once launched, tell the user in one sentence that it's running in the background and stop
— do not poll it, do not guess at its progress, and do not fabricate intermediate status.
When its completion notification arrives (a separate turn), relay the summary to the user
directly ("PR #N is at LGTM after 3 rounds — see the PR for the full trail") rather than
re-deriving or re-checking it yourself unless something in the report looks wrong.

## Origin

This pattern was developed ad hoc across several review rounds on real PRs before being
written up as a skill. It caught genuine bugs each time it was used seriously (an API
name collision, persisted-placeholder data, edit loss on a late-arriving id, existing
data mistreated as new, cross-entity state leakage on remount) — the adversarial,
different-model property is doing real work, not just theater. The one thing that made it
slow rather than fast was Codex wandering past convergence every round without an
explicit budget and forced verdict format; §2 exists specifically to fix that at the
prompt level instead of patching it per round with manual nudges.
