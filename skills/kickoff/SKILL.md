---
name: kickoff
description: Run discovery, domain modeling, architecture, spec synthesis, and ticket slicing to take an idea to ready work.
disable-model-invocation: true
---

# Kickoff

Turn a rough idea or request into a shared domain model, settled architecture, spec, and vertical-slice ticket backlog.

## Workflow

### 1. Ground on repo state

Read `AGENTS.md` or `CLAUDE.md`, `GLOSSARY.md` or `GLOSSARY-MAP.md`, and any existing ADRs under `docs/adr/`. Dispatch a read-only subagent to gather codebase facts such as existing modules, patterns, seams, and tests, so you ask the user only for decisions and never for facts the repo already holds.

### 2. Grill and model the domain in rounds

Read and run `../grilling/SKILL.md` and `../domain-modeling/SKILL.md` together.

- Work the decision tree one frontier round at a time, giving a recommended answer for every question.
- Challenge fuzzy or conflicting terms against `GLOSSARY.md`, invent concrete edge-case scenarios to test boundaries, and cross-check claims against the code.
- Write new glossary entries to `GLOSSARY.md` and sparse ADRs to `docs/adr/` inline as each decision settles.

Repeat rounds until the frontier is empty and the user confirms shared understanding.

### 3. Prototype forks and shape modules

- When a technical or UX fork is better settled empirically than by debate, branch to `../prototype/SKILL.md` and fold the settled takeaways back into the plan.
- When core module boundaries or interfaces are non-trivial, read and run `../architect/SKILL.md` using the deep-module vocabulary from `../codebase-design/SKILL.md`. Record constraining choices as short ADRs under `docs/adr/`.

Skip either branch if the change fits cleanly into existing modules with no open empirical questions.

### 4. Synthesize the spec

Read and run `../to-spec/SKILL.md` to turn the settled conversation, glossary terms, ADRs, and key prototype decisions into a spec. Confirm the proposed testing seams with the user before moving on.

### 5. Slice into tickets

Read and run `../to-tickets/SKILL.md` to break the spec into tracer-bullet vertical slices with explicit blocking edges, or expand-contract batches when the work is a wide mechanical refactor. Present the breakdown, confirm granularity and blocking edges with the user, and publish the tickets.

### 6. Close with concrete handoff pointers

End with a compact handoff listing:

- The spec path or issue URL.
- Each ticket path or ID, marking the unblocked initial frontier.
- The recommended next command:
  - `/execute-plan` for single-session builds that fit in one orchestrator run.
  - `/unattended-run` for larger or overnight builds across multiple sessions.
  - `/create-verification-skill` first if the repo has no `verify-*` skill yet.
