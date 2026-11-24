---
name: execute-plan
description: Execute a spec and ticket graph across parallel worktree implementers, verify gates, and review before opening a PR.
disable-model-invocation: true
---

# Execute plan

Drive a settled spec and ticket graph to a verified, reviewed integration branch and PR. You act as the coordinator. Keep your own context lean by delegating implementation to `implementer` subagents and verification to `test-runner` subagents.

## Workflow

### 1. Load plan and initialize logging

Read the spec, the ticket graph with its blocking edges, `GLOSSARY.md` if present, and any repo-local `verify-*` skill. Confirm the base branch and the project's test, build, and lint commands.

When running 2 or more tickets, start a `decisions.tsv` log using `../show-me-your-work/SKILL.md` in an untracked scratch path outside git tracking, such as `.scratch/execute-<slug>/decisions.tsv` when `.scratch/` is gitignored, or `/tmp/execute-<slug>/decisions.tsv`.

### 2. Write shared grounding notes, optional

If the codebase is unfamiliar or spans many modules, dispatch one read-only exploration subagent to map entry points, existing patterns, test layout, and invariants into a short markdown file in the untracked scratch path. Point implementers to that file so each starts with lean context instead of re-reading the repo.

### 3. Create one integration branch

Create one integration branch from the base branch, for example `git checkout -b feat/<slug> <base>`. All ticket merges land on this integration branch so the base branch stays clean until verification and review pass.

### 4. Dispatch unblocked frontier batches

Compute the unblocked frontier, meaning tickets whose blockers are all merged. Filter to tickets whose expected file edits do not overlap.

For each ticket in the batch:

1. Create an isolated git worktree branched from the current integration branch head, for example under `.worktrees/<ticket-id>` or `/tmp/worktrees/<ticket-id>`.
2. Dispatch a fresh `implementer` subagent in parallel inside that worktree. Give it sparse context pointers only:
   - The spec path or ID.
   - Its single ticket path or ID.
   - The shared grounding notes path, if created.
   - `../tdd/SKILL.md` to drive the slice test-first.
   - `../diagnosing-bugs/SKILL.md` if it hits a stubborn failure.
3. State explicitly that the `implementer` works only in its assigned worktree and never commits, pushes, or opens PRs.

### 5. Gate and merge per ticket

As each `implementer` finishes, process its worktree before accepting the ticket:

1. Inspect `git diff --stat` and read risky hunks in the ticket worktree.
2. Run `test-runner` in the ticket worktree on the relevant test, build, and lint commands. If checks fail, send one targeted fix pass to an `implementer` in that worktree and re-run `test-runner`.
3. Stage and commit the verified changes on the ticket branch, merge into the integration branch, and run `test-runner` on the integration branch if multiple tickets merged in the same wave.
4. Remove the ticket worktree with `git worktree remove <path>` and delete its temporary branch.
5. Append a row to `decisions.tsv` recording the ticket ID, status, checks run, and notable trade-offs.

Recompute the frontier and repeat steps 4 and 5 until every ticket is merged.

### 6. Run end-of-run checks and review

On the integration branch:

1. Run the repo's `verify-*` skill if one exists, or run a real end-to-end app or CLI smoke check against the built artifact.
2. Read and run `../review/SKILL.md` comparing the integration branch against the base branch using `<base>...HEAD`.
3. Route accepted review findings, including proven bugs, spec gaps, standard violations, and hygiene fixes, to one fresh `implementer` subagent sequentially, then re-verify with `test-runner` and commit the fixes on the integration branch.

### 7. Audit, draft PR, and clean up

1. Audit `decisions.tsv` when present to confirm no ticket or check was skipped without an explicit reason.
2. Draft the PR body using `../pr/SKILL.md`. Open or update the PR if the user asked for one.
3. Run `git worktree list` and confirm only the main checkout and any expected integration worktree remain.
4. Report the integration branch, merged tickets, verification commands with pass and fail counts, review outcome, and PR URL or next step.
