# Plan

Approach: <how the run will reach the goal in MISSION.md, in a few sentences>.

Ordering reasons:
- <why the first items go first, e.g. an item that deletes code others touch, or one every check needs>

## Queue

Orchestrators take the first `todo` item whose dependencies are `done`. Status is `todo`, `running`,
`review` (the subagent finished, the orchestrator hasn't reviewed it yet), `done` or `blocked`. An item is
blocked after <RETRIES> failed attempts, or when it needs a human decision, a credential or an outside
action MISSION.md doesn't allow. If the clock runs short, this order is the priority order.

| id | item | depends on | status | attempts | note (result, output path, files touched or blocking reason) |
|---|---|---|---|---|---|
| 1 | <unit of work> | | todo | 0 | |
| I | <when items make separate branches> Integrate: scan for conflicting pairs, remove hotspots, group what still conflicts, merge every final branch into a scratch branch and run the full checks and an app check on it | all others done or blocked, or <latest start time> | todo | 0 | |
| V | <when items make separate branches> Review the combined branch following ~/.claude/skills/review/SKILL.md (multi-axis Standards and Spec, interrogate, blast-radius, no-comments, hygiene), plus checks for data loss, first minutes after deploy, races, regressions, and any repo verify-* skill. Fix what they find | I | todo | 0 | |
| D | <if the user asked for it> Open the combined pull request from the proven branch following ~/.claude/skills/pr/SKILL.md, with a deploy checklist in its body | V | todo | 0 | |

## Changes

- <date time> orchestrator <N>: <what changed in the queue or approach> because <reason>.
