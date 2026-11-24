---
name: no-comments
description: Spawn the comment-sicko subagent to purge unnecessary comments, fix flagged workarounds, and encode real constraints. Supports read-only review mode.
disable-model-invocation: true
---

# No comments

Spawn `comment-sicko` and act on accepted findings. Defer to its fresh perspective.

## Scope

Use the caller's files or diff. Otherwise use the current diff against the base branch (default `main`), including the working tree.

## Steps

1. Spawn the `comment-sicko` subagent and pass the scope. Pick a reasoning level that fits the scope, and do not restate the agent's rules. When called in read-only mode (for example inside a parallel review fan-out), instruct `comment-sicko` to report findings without editing files, and stop after step 2.
2. Inspect its report and diff. Reject application-code edits, scope escapes, exception-protected deletions, misstated `MUST KILL` reasons, and flags that treat kept intentional code as guilty. Reshape flags on surprises in our own code stay actionable; do not restore those comments. A keep survives only with proof it describes something we cannot change. Audit missed scoped lint and TypeScript suppressions; correctness or safety suppressions stay actionable `MUST KILL`s. Restore deletions only with exact exceptions and scoped proof. Before accepting thin `IMPORTANT` or `do not remove` kills or keeps, trace their symbol or inspect `git log -S` and `git blame` on it. If a kill is ambiguous, do not restore it. If a keep is refuted or still ambiguous, delete it. Revert and rerun one rejected report with the failure named. Reject a second, report it open, and fail `/no-comments`. (In read-only mode, there are no edits to revert; verify claims against the tree, rerun once if needed, and output the audited report.)
3. Fix trivial accepted flags directly by deleting a dead path, dropping a parameter, or using the real API. If any fix needs structural design, follow [architect](../architect/SKILL.md) once for the accepted set and surrounding code. Stop at the sketch; step 4 implements it.
4. Implement the smallest root-cause fix in scope and remove every named workaround. Fix the root cause rather than bolting on symptom guards, without widening the scope or fixing instances outside it. If the root cause lives outside the scope, land the smallest in-scope fix and report the rest open.
5. Constraint comments say `do not remove`, `do not change wording`, or `talk to X before changing`. Leave keeps about external systems we cannot change. For in-house constraints, offer the cheapest in-scope type, runtime check, test, or CI lint rule. Wait for interactive approval (unattended runs require caller pre-approval). If approved, encode the constraint and then delete the comment. Otherwise delete the comment, report the constraint open, and sketch any out-of-scope enforcement work.
6. Report the deletion count, restored comments, reruns, architect sketch, fixes, encoding offers, encodings, unenforced constraints, and other open work (or, in read-only mode, the audited findings and `MUST KILL` targets).
