---
name: handoff
description: Write a compact handoff document for a fresh session when hitting context limits or pausing work, then point a new session to it.
disable-model-invocation: true
---

# Handoff

Write the document a competent stranger needs to take the *next* action on this
task correctly, without repeating your dead ends and without re-litigating
decisions the user already made.

A handoff is not a summary of the conversation. Compaction already produces a
lossy summary, and what it drops is precisely what is expensive: the paths that
failed and *why*, the constraints the user stated once in passing, and the
half-formed hypothesis you were about to test. Those took real tokens and real
wall-clock to earn. Everything a fresh agent can cheaply re-derive by reading a
file or running `git log` does not belong here.

The successor will trust this document completely and will not have the
transcript to check it against. That makes a confident wrong claim in a handoff
much more damaging than an omission. Mark what you verified as verified, and
what you assumed as assumed.

## 1. Gather facts before writing

Your recollection of a long session is lossy in the exact places that matter
(which fix landed, which was reverted, whether that test actually passed). Spend
a few tool calls re-grounding first, in parallel:

- `git status --short` and `git log --oneline -10`: what actually landed vs what
  is still uncommitted. Note the branch and whether you are in a worktree.
- `git diff --stat` (and `git diff` on the files you touched): the real shape of
  the change, not the shape you intended.
- Re-read the user's original request, verbatim, wherever it appears in the
  conversation. Handoffs drift toward what you *did* and away from what was
  *asked*; the successor needs the ask.
- Check anything still running: background jobs, `sbatch`/`squeue` job IDs, open
  PRs, servers you started. An orphaned process the successor does not know about
  is a nasty surprise.
- Re-check your last claim of success. If you said a test passed, confirm it
  still does, or say plainly that it passed once and has not been re-run.

## 2. Write it

Save to `~/.local/share/nexus/handoffs/<project-slug>/<YYYY-MM-DD-HHMM>-<topic>.md`,
where `<project-slug>` is the absolute cwd with every `/` replaced by `-` (so
`/home/u/repo` becomes `-home-u-repo`), which the resume hook in step 3 looks
for. Keep handoffs out of the repo checkout so they never show up in
`git status`. Create the directory with `mkdir -p`.

Use this structure. Drop sections that are genuinely empty rather than padding
them with "N/A". On a long session, empty "Dead ends" or "Decisions" sections
usually mean you did not look hard enough.

```markdown
# Handoff: <topic in one line>

Written <date time> | cwd `<absolute path>` | branch `<branch>`<, worktree>
Model/session context: <anything unusual: background job, plan mode, effort>

## The ask
<The user's actual request, in their framing. Quote the key sentence if short.
If the scope was renegotiated mid-session, say what it is NOW and what changed.>

## Where things stand
- **Done and verified:** <thing>, verified by `<command>` / <observation>
- **Done, unverified:** <thing>, <what check is still owed>
- **In flight:** <thing>, <exactly how far it got>
- **Not started:** <thing>

## Anchors and map
<The 3-8 files that matter, with line numbers: `path/to/file.py:120-160` and why
they matter *for this task*. Plus job IDs, PR/branch URLs, output dirs, config
names.>

<Then the understandings that cost you tool calls to earn: the call path you
traced end to end, where the real logic lives versus where it looks like it
lives, which of two similarly-named files is the live one, the invariant you
inferred, the gotcha that is not written in any comment, and searches that came
back empty (`no other caller of X` is a finding). This is the part that saves
the successor the most reading.>

## How to verify / reproduce
<Exact commands, copy-pasteable, in order. Include the setup that is not
obvious: env vars, container paths, which host to run on. If the successor's
first move is to reproduce a failure, give the command that fails and the
error it prints.>

## Dead ends - do not redo
<Each: what was tried, what happened, and the inference. The inference is the
valuable part: "raising the timeout cannot help, the process is genuinely dead"
is worth more than "tried raising timeout, did not work".>

## Decisions and constraints from the user
<Choices the user made, with their reasoning where you know it, and hard
constraints they stated. This stops the successor from proposing an approach
the user already rejected. Include preferences that sound minor; they were
stated for a reason.>

## Working hypothesis
<What you currently believe is going on, how confident you are, and what
evidence would confirm or kill it. Say "unknown" if you do not have one; a
fabricated hypothesis sends the successor down a false trail.>

## Next action
<One concrete first move, specific enough to execute without deciding anything:
the file to edit, the command to run, the question to answer. Then a short
ordered list of what follows.>

## Open questions for the user
<Anything you would have asked if the session had continued. Flag which ones
block progress and which can be assumed past.>
```

**What earns a place in the map:** ask whether learning it cost you tool calls,
and whether it is still true. Working out which of four `load_config` call sites
actually runs is expensive; the body of `load_config` is one file read away.
Write down the *conclusions* of your searching, not the material you searched. A
successor who opens the right three files at the right line ranges has inherited
an hour of your reading for the price of a paragraph. Paste code only when the
successor needs the exact current text to reason about a change that has not
been made yet; otherwise a path and line range is strictly better, because a
quoted snippet silently goes stale and a path cannot.

Write for an agent reader: paths over prose, exact commands over descriptions of
commands, no hedging and no preamble. Length follows the work. A two-hour
debugging session earns a page; a small feature earns a few paragraphs. Padding
costs the successor context, which is the one thing this whole exercise exists
to conserve.

## 3. Start the fresh session

Never run interactive `claude` or `agy` from a tool call, because a nested interactive subprocess is not a session the user can talk to. In Claude Code, only `scripts/spawn_claude.sh` (which uses `claude --bg`) may launch a successor session.

**Route C: automated background continuation (Claude Code, `claude --bg`)**:

Run Route C automatically in Claude Code when triggered by the 150k context warning (or when the user asks to hand off and continue automatically), only when all of these hold:
- You are a main session (not a subagent).
- You are not an `/unattended-run` orchestrator (which follows `MISSION.md` and `tools/launch_orchestrator.sh`).
- `Next action` has concrete autonomous work not blocked on a user decision.

Use Route A or Route B instead when the user ran `/handoff` to pause work, when the next step needs a user decision, when running in Antigravity CLI (`agy` has no `--bg` attachable session mode), or when `spawn_claude.sh` fails or hits the chain cap.

To run Route C:
1. Cancel your own wait loops, timers, and monitors before spawning.
2. Run `~/.claude/skills/handoff/scripts/spawn_claude.sh <handoff-path>` (passing `--tag <tag> --gen <N+1> --max <max>` when continuing a chain).
3. Stop working immediately. Report the handoff path, new session name and ID, and `claude attach <id>`, `claude agents`, and `claude stop <id>`.
4. If already-running subagents report late, do not resume task work; note their report paths only.

`spawn_claude.sh` atomically claims `.md` to `.md.done` before launching `claude --bg` (avoiding races with Route B's `SessionStart` hook), rolls back to `.md` if launch fails, and enforces a default chain limit of 5 (`HANDOFF_MAX_GEN`).

**Route A: new terminal, handoff as the opening message** (nothing to install;
skip Route A if you already installed Route B's hook so the new session does not
receive the handoff twice):

```bash
# Claude Code:
claude "$(cat "$HOME/.local/share/nexus/handoffs/<slug>/<file>.md")"

# Antigravity CLI:
agy -i "$(cat "$HOME/.local/share/nexus/handoffs/<slug>/<file>.md")"
```

**Route B: auto-injected via `SessionStart` hook**: a `SessionStart` hook
points the fresh session at the newest unconsumed handoff and tells it to read
the file in full, then marks it `.md.done` (along with any older stale `.md`
files in that directory) so it never leaks into later sessions. It does *not*
`cat` the handoff into stdout, because large hook outputs can be truncated.
`scripts/resume_hook.sh` in this skill handles both Claude Code and Antigravity
CLI. Install once (idempotent, updates `~/.claude/settings.json` and/or
`~/.gemini/config/hooks.json` via `python3`; read the script before running it):

```bash
# From the skill directory (Claude: ~/.claude/skills/handoff, Antigravity: ~/.gemini/config/skills/handoff):
bash scripts/install_hook.sh
```

Once installed, run `/clear` (or `/new` in Antigravity CLI, or open a new session
in the same workspace) and the fresh agent opens with the handoff pointer
already in context. Offer the install once; if the user declines, Route A covers
everything.

## Notes

- If the user wants the handoff for a *human* (a colleague, or their future self
  next week) rather than an agent, keep the same structure but expand the "why"
  and drop the copy-pasteable-command density. Say what you are doing and let
  them redirect you.
- A handoff naming a file, function, or flag that no longer exists is worse than
  no handoff. Verify anchors exist before writing them down.
- Worth saving to memory instead of the handoff: durable facts about the user,
  the project, or a root cause that will still be true next month. The handoff
  is for the perishable state of *this* task.
