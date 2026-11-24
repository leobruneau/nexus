---
name: interrogate
description: Adversarial review where independent subagents try to break a change or design, and only findings proven by a run survive. Use for /interrogate or "challenge this".
disable-model-invocation: true
---

# Interrogate

Adversaries try to break a change or a design. A finding survives only when a run proves it. Report the findings without applying fixes.

## Frame

The scope is what the user names. Otherwise it is the branch diff from its merge base with the default branch, through the working tree. Restate the intent in plain prose from the user's message, commits, and PR description. Ask the user only when the intent is unclear.

## Fan out

Spawn 2 independent fresh subagents in parallel, each in its own isolated git worktree with any uncommitted changes in scope copied over. Keep each adversary independent without sharing findings between them. Give each adversary the scope, the restated intent, and this brief:

> Break this change. Prove every finding by running real code, such as a failing test, a repro script, or command output showing wrong behavior. For a design or plan, run a prototype or probe the current tree. Keep repros in your own worktree. Report each finding with a title, the exact command, the output it printed, and the output the intent requires. Omit anything you did not run, along with style, naming, structure, and unproven risks that need a future change to matter. No findings is a valid result.

## Verify

Verify each reported finding by rerunning its command against the code. Keep a finding only when the output reproduces the failure and the failure breaks the stated intent. Drop unproven or irrelevant findings. Merge findings that share a root cause. Keep every verified finding across both adversaries rather than picking one adversary's list.

## Output

- **Intent.** Plain restatement of what the change should do.
- **Verified findings.** For each verified finding, include the command, its output, how it breaks the intent, and which adversaries found it. Write "No verified findings" when none survive.
- **Dropped.** For each adversary, list the count of dropped findings and the reason each was dropped.
