---
name: time-machine
description: Trace back and report on work done over a past period by mining stored Claude Code, Antigravity CLI, and git history.
disable-model-invocation: true
---

# Time machine

Reconstruct what was worked on over a past time window and write it up as a
plain, detailed report. The truth lives in stored session transcripts (Claude
Code and Antigravity CLI) and, for git repos, commit history. This skill reads
both and turns them into one dry, readable account of progress.

## How the data is laid out

- Claude Code stores one JSONL transcript per session under
  `~/.claude/projects/<encoded-cwd>/<session>.jsonl`.
- Antigravity CLI stores one JSONL transcript per conversation under
  `~/.gemini/antigravity-cli/brain/<conversation-id>/.system_generated/logs/transcript.jsonl`.
- Git history adds commit-level detail that transcripts do not capture, such as
  work done outside agents or squashed into clean commits.

You do not parse the JSONL by hand. `scripts/extract.py` reads both sources
and normalizes them into one digest.

## Workflow

### 1. Settle the scope and the window

Two things define a run: **which projects** and **what time window**.

- Project: a single one, a named few, or all. If the user names a project, pass
  it as a `--project` substring filter. If they say "everything" or "across
  projects", run with no project filter.
- Window: inclusive dates. If the user gives one ("last week", "since the 1st",
  "in June"), convert it to concrete dates (today's date is in your context).
  If they give none, default to the **last 7 days** and say so in the report.

Pick the sensible reading, state the scope and window at the top of the report,
and proceed. The user can correct a wrong guess faster than they can answer a
question up front.

### 2. See what is there

Run `extract.py` from the installed skill directory (`~/.claude/skills/time-machine/scripts/extract.py`
or `~/.gemini/config/skills/time-machine/scripts/extract.py`):

```bash
python3 ~/.gemini/config/skills/time-machine/scripts/extract.py --list
# or under Claude Code:
python3 ~/.claude/skills/time-machine/scripts/extract.py --list
```

This lists every project in history with its session count, sources (`claude`,
`antigravity`), active date range, and whether it is a git repo. Use it to
confirm the scope and spot projects the user did not name precisely.

### 3. Pull the transcript digest

```bash
# focused: one project, full detail (prompts + assistant summaries + actions):
python3 <skill-dir>/scripts/extract.py --since 2026-06-01 --until 2026-06-15 --project my-project

# wide: many projects / long window, compact (--brief):
python3 <skill-dir>/scripts/extract.py --days 30 --brief

# optional source filter: --source claude | antigravity | all (default: all)
```

`--project` is repeatable and matches a substring of the project path.
`--days N` is shorthand for the last N days. Output is grouped by project, then
by session, showing the user's prompts, assistant summaries, and concrete
actions taken (files read, edited, written, and commands run).

**Match the mode to the scope so you do not drown in tokens.** Full mode is
rich but large. `--brief` drops assistant prose summaries and collapses actions
to a touched-file list plus a command count, keeping wide scans compact.

A good default for wide scopes is to run `--brief` across everything first to
see where the work concentrated, then re-run full mode on the one or two
projects that matter. If a single project's full digest is too large, fall back
to `--brief` and read raw transcripts only where needed.

If a session looks pivotal and the digest is too terse, read the raw transcript
at the `_path: ..._` line printed under that session's header.

### 4. Add git history for repo projects

For every project the digest marks as a git repo (and whose directory still
exists on disk), get the commit-level view across **all branches**:

```bash
git -C "<project-cwd>" log --all --since="<start> 00:00:00" --until="<end> 23:59:59" \
    --pretty=format:'%h %ad %an %d %s' --date=short
```

For central branches or commits, drill in with `git -C "<cwd>" show --stat <sha>`
or `git -C "<cwd>" log --all --stat --since="<start> 00:00:00"` to see which
files moved and by how much. Note merges, branch topology, and commits that do
not correspond to any transcript.

### 5. Write the report

Synthesize the digest and git history into one account. Write the file, then
give the user a short summary in chat.

## Report style

Dry, simple, clearly understandable. State what was done, when, and why it
mattered, in the order it happened. No marketing adjectives, no "successfully",
no padding. Prefer concrete nouns (file names, features, bugs, commit subjects)
over vague ones ("various improvements"). If the work is unclear or you are
inferring intent, say so plainly rather than dressing it up.

Group by project. Within a project, narrate chronologically. Do not invent
structure the work does not have.

## Report structure

Use this template. Drop sections that do not apply (e.g. omit "Commits" for a
non-git project, omit the cross-project roll-up for a single project).

```markdown
# Work report: <scope> (<start> to <end>)

Scope: <which projects, and the window; note if the window was defaulted>.
Sources: <Claude Code / Antigravity CLI> session history<, and git history for N repo(s)>.

## Summary
<3 to 6 plain sentences covering the main things that got done across the window.>

## <Project name / path>
Active: <dates> | Branches touched: <list> | Sessions: <n>

### What was done
<Chronological account. Each entry: what changed and why. Group naturally by
day or by piece of work. Name the files, features, and bugs involved.>

### Commits   <!-- only for git repos -->
<Notable commits across all branches in the window: short sha, date, subject,
and the files or area they touched. Flag commits with no matching transcript.>

### State at end of window
<Where things stood when the window closed: what is finished, what is in
progress, and what is left open or broken.>

## Cross-project notes   <!-- only when several projects -->
<Themes spanning projects, where time concentrated, and anything notable about
how the work split across them.>
```

## Output

Write the report to `~/time-machine-reports/` with a descriptive, timestamped
name, e.g. `~/time-machine-reports/2026-06-29_my-project_jun.md` (create
the directory if needed). Then print a short summary in chat and the path to
the full file. Do not paste the whole report into chat.

## Notes

- Subagent chatter is filtered out on purpose: Claude sidechains and Antigravity
  subagent conversations are skipped so the main thread is not doubled.
- Resumed Claude sessions replay earlier messages; the script dedupes them by
  message id.
- If `--list` finds no history at `~/.claude/projects/` or
  `~/.gemini/antigravity-cli/brain/`, say so rather than guessing.
