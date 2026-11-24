---
name: to-tickets
description: Break a spec, plan, or conversation into tracer-bullet vertical-slice tickets with blocking edges, saved as local markdown files or GitHub issues.
disable-model-invocation: true
---

# To tickets

Break a plan, spec, or conversation into a set of **tickets**: tracer-bullet vertical slices, each declaring the tickets that **block** it.

## Process

### 1. Gather context

Work from whatever is already in the conversation context. If the user passes a reference (a spec path, an issue number, or a URL) as an argument, read or fetch its full body and comments.

### 2. Explore the codebase (optional)

If you have not already explored the codebase, do so to understand the current state of the code. Ticket titles and descriptions should use the project's domain glossary vocabulary (`GLOSSARY.md`), and respect ADRs (`docs/adr/`) in the area you are touching.

Look for opportunities to prefactor the code to make the implementation easier: "Make the change easy, then make the easy change."

### 3. Draft vertical slices

Break the work into **tracer bullet** tickets.

<vertical-slice-rules>

- Each slice cuts a narrow, complete path through every layer (schema, API, UI, tests): vertical, NOT a horizontal slice of one layer.
- A completed slice is demoable or verifiable on its own.
- Each slice is sized to fit in a single fresh context window.
- Any prefactoring comes first.

</vertical-slice-rules>

Give each ticket its **blocking edges**: the other tickets that must complete before it can start. A ticket with no blockers can start immediately.

**Wide refactors are the exception to vertical slicing.** A **wide refactor** is one mechanical change (such as renaming a column or retyping a shared symbol) whose **blast radius** spans the codebase, so a single edit breaks many call sites at once and no vertical slice can land green. Do not force it into a tracer bullet; sequence it as **expand and contract**. First expand: add the new form beside the old so nothing breaks. Then migrate the call sites in batches sized by blast radius (per package or directory), each batch its own ticket blocked by the expand ticket, keeping CI green batch by batch because the old form still exists. Finally contract: delete the old form once no caller remains, in a ticket blocked by every migrate batch. When even batches cannot stay green alone, let them share an integration branch that all block a final integrate-and-verify ticket, where green is required.

### 4. Quiz the user

Present the proposed breakdown as a numbered list. For each ticket, show:

- **Title**: short descriptive name
- **Blocked by**: which other tickets (if any) must complete first
- **What it delivers**: the end-to-end behaviour this ticket makes work

Ask the user:

- Does the granularity feel right (too coarse or too fine)?
- Are the blocking edges correct, meaning each ticket only depends on tickets that genuinely gate it?
- Should any tickets be merged or split further?

Iterate until the user approves the breakdown.

### 5. Write or publish the tickets

Save or publish the approved tickets. The tickets stay the same either way; only the output destination and blocking-edge syntax change:

- **Local files (default).** Write one file per ticket under `.scratch/<feature-slug>/issues/<NN>-<slug>.md` (or `docs/specs/<feature-slug>/tickets/<NN>-<slug>.md` if the user wants them committed), numbered from `01` in dependency order with blockers first. Each file's `Blocked by:` line lists the ticket numbers and titles it depends on. Use the local ticket template below: one ticket per file, never a single combined file. Because each file is self-contained with its blocking edges and acceptance criteria, `/execute-plan` and `/unattended-run` can consume the folder directly as a work queue.
- **GitHub issues (when requested).** When the user asks to publish to an issue tracker, create one issue per ticket with `gh issue create` in dependency order (blockers first) so each ticket's `Blocked by:` section can reference real issue numbers (or native blocking / sub-issue links if available). If the source was an existing issue, reference it in `Parent`. Apply `ready-for-agent` or the repo's configured triage label if used.

Work the **frontier**: any ticket whose blockers are all done. For a purely linear chain that means top to bottom.

Do NOT close or modify any parent issue.

<local-ticket-template>

# <NN>: <Ticket title>

**What to build:** the end-to-end behaviour this ticket makes work, from the user's perspective, not a layer-by-layer implementation list.

**Blocked by:** the numbers and titles of the tickets that gate this one, or "None (can start immediately)".

**Status:** ready-for-agent

- [ ] Acceptance criterion 1
- [ ] Acceptance criterion 2

</local-ticket-template>

<issue-template>

## Parent

A reference to the parent issue on GitHub (if the source was an existing issue, otherwise omit this section).

## What to build

The end-to-end behaviour this ticket makes work, from the user's perspective, not layer-by-layer implementation.

## Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2

## Blocked by

- A reference to each blocking issue, or "None (can start immediately)". Omit this section when blockers are set as native links.

</issue-template>

In either form, avoid specific file paths or code snippets because they go stale fast. Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (such as a state machine, reducer, schema, or type shape), inline it and note briefly that it came from a prototype. Trim to the decision-rich parts rather than pasting a working demo.
