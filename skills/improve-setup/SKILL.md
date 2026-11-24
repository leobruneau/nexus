---
name: improve-setup
description: Mine a session or unattended run for repeated mistakes, then propose repo guardrails and Nexus skill improvements.
disable-model-invocation: true
---

# Improve setup

Turn pain from a completed session or unattended run into structural repo guardrails and sharper Nexus skills. Propose changes and wait for approval before editing anything.

## Workflow

### 1. Gather run evidence

Read the current session transcript. If the user points to an unattended run directory instead, read its `FINAL_SUMMARY.md`, `COORDINATOR.md`, and `decisions.tsv`, plus `LOG.md` where timelines need checking.

Extract concrete failures, retries, wasted explorations, manual rescues, and specification gaps with file, command, or log citations.

### 2. Repo guardrails pass

Read and follow `../correct/SKILL.md`. Group repeated mistakes into root-cause classes and propose fixes in strict enforcement order:

1. **Architecture and types.** Make invalid states or wrong calls fail to compile or structure cleanly.
2. **Linters and CI.** Catch repeated style, boundary, or hygiene errors automatically.
3. **Tests.** Lock down regressions at the highest practical seam.
4. **Repo docs last.** Update `AGENTS.md`, `CLAUDE.md`, or `GLOSSARY.md` only for rules tooling cannot enforce.

Also check verification coverage in the target repo. If no `verify-*` skill exists for end-to-end checks, propose creating one with `../create-verification-skill/SKILL.md`. If an existing `verify-*` skill missed failures or drifted from the codebase, propose updating it with `../maintain-verification-skill/SKILL.md`.

### 3. Nexus skills pass

Read and follow `../reflect/SKILL.md` together with `../writing-for-agents/SKILL.md`, plus `../writing-for-agents/SKILL-MECHANICS.md` when changing frontmatter or invocation.

Identify durable, cross-project improvements for skills in `~/nexus/skills/` or `~/nexus/claude/skills/`. Keep repo-specific conventions out of shared Nexus skills, prefer positive framing, and cut redundant lines instead of piling on rules.

### 4. Present triage and wait for approval

Present all candidates under four headings:

- **Accepted, repo guardrails.** Concrete fixes in the target repo, ordered by the enforcement hierarchy above, including any `verify-*` skill work.
- **Accepted, Nexus skill edits.** Concrete edits to `~/nexus/skills/` or `~/nexus/claude/skills/`.
- **Rejected.** Candidates dropped as one-off noise, already enforced, or low-value bloat, with a one-line reason each.
- **Backlog.** Real issues worth tracking later that fall outside this pass.

Stop after presenting the triage and wait for the user's explicit approval before editing any files.
