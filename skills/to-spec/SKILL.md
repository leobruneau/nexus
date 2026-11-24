---
name: to-spec
description: Synthesize the current conversation and codebase context into a spec saved to docs/specs/ or published as a GitHub issue. No interview.
disable-model-invocation: true
---

# To spec

Turn the current conversation context and codebase understanding into a spec. Do NOT interview the user; synthesize what you already know.

## Process

1. Explore the repo to understand the current state of the codebase, if you have not already. Use the project's domain glossary vocabulary (`GLOSSARY.md`) throughout the spec, and respect any ADRs (`docs/adr/`) in the area you are touching.

2. Sketch out the seams where you will test the feature. Prefer existing seams over new ones, and place any needed seam as high as you can. The fewer seams across the codebase, the better; one seam is ideal.

   Check with the user that these seams match their expectations.

3. Write the spec using the template below. By default, save it to `docs/specs/<slug>.md` (or `.scratch/<slug>/spec.md` if the user wants it untracked). When the user asks to publish to an issue tracker, create a GitHub issue with `gh issue create` (and apply `ready-for-agent` or the repo's triage label if configured).

<spec-template>

## Problem statement

The problem that the user is facing, from the user's perspective.

## Solution

The solution to the problem, from the user's perspective.

## User stories

A thorough, numbered list of user stories. Format each user story as:

1. As an <actor>, I want a <feature>, so that <benefit>

<user-story-example>
1. As a mobile bank customer, I want to see the balance on my accounts, so that I can make informed decisions about my spending.
</user-story-example>

Cover all aspects of the feature.

## Implementation decisions

List the implementation decisions that were made, including:

- The modules that will be built or modified
- The interfaces of those modules that will be modified
- Technical clarifications from the developer
- Architectural decisions
- Schema changes
- API contracts
- Specific interactions

Do NOT include specific file paths or code snippets, because they go stale quickly.

Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (such as a state machine, reducer, schema, or type shape), inline it within the relevant decision and note briefly that it came from a prototype. Trim to the decision-rich parts rather than pasting a working demo.

## Testing decisions

List the testing decisions that were made, including:

- What makes a good test (only test external behaviour, not implementation details)
- Which modules will be tested
- Prior art for the tests (similar types of tests in the codebase)

## Out of scope

Describe what is out of scope for this spec.

## Further notes

Add any further notes about the feature.

</spec-template>
