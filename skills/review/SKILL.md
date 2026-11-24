---
name: review
description: Run parallel isolated review passes for standards, spec, proven bugs, blast radius, hygiene, and optional architecture.
disable-model-invocation: true
---

# Review

Run independent, read-only review axes in parallel, aggregate findings without cross-axis reranking, and resolve accepted fixes cleanly.

## Workflow

### 1. Pin the fixed point and locate the spec

Resolve the base ref with `git rev-parse <base>`. Capture the review scope using `git diff <base>...HEAD` plus any uncommitted working-tree changes from `git status --short` and `git diff`.

Locate the originating spec in this order:

1. Issue references in commit messages.
2. A path or ID passed as an argument.
3. A spec under `docs/specs/`, `docs/`, or `.scratch/` matching the branch or feature.

Stop early and report clearly if the base ref fails to resolve or both the branch diff and working tree are empty.

### 2. Fan out parallel fresh read-only subagents

Launch **4 parallel fresh read-only subagents** so findings on one axis never bias another and concurrent edits never collide:

1. **Standards and Spec.** Read and follow `../code-review/SKILL.md`. Keep Standards findings and Spec findings separate.
2. **Adversarial bug hunt.** Read and follow `../interrogate/SKILL.md` inside an isolated temporary git worktree created from the reviewed state, then remove the worktree when done. Only bugs backed by a runnable reproduction survive.
3. **Blast radius.** Read and follow `../blast-radius/SKILL.md` to prove the core safety invariant by running code, using an isolated temporary worktree if execution writes files or mutates state.
4. **Code and repo hygiene.** Run `comment-sicko` in read-only report mode per `../no-comments/SKILL.md`. In the same pass, check for dead code, leftover debug logs, untracked cruft, missing tests for changed behavior, doc or config drift, and unslop issues on changed prose.

If the user passes `--deep` or asks for a repo audit, add a fifth parallel subagent for architecture that references `../improve-codebase-architecture/SKILL.md` across the touched modules.

### 3. Aggregate without merging or reranking

Collect every subagent report and present findings under separate headings in this order:

- `## Standards`
- `## Spec`
- `## Proven bugs`
- `## Blast radius`
- `## Hygiene`
- `## Architecture`, included only when `--deep` or repo-audit ran

Start each section with the finding count and its single worst finding. Keep each axis intact. Never merge findings across headings or rerank one axis against another.

### 4. Resolve findings

Resolve findings based on how `/review` was invoked:

- **Interactive session.** Present the aggregated report and ask the user which findings to fix. Wait for their selection before dispatching edits.
- **Automated caller.** When invoked from `/execute-plan` or `/unattended-run`, apply the resolution policy without waiting for user input. Fix all proven bugs, spec gaps, standard violations, and narration or dead comments. Reject scope creep, speculative abstractions, and unrelated refactors. Dispatch one fresh `implementer` subagent sequentially with the accepted fix list, then re-verify with `test-runner`.
