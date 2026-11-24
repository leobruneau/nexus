@nexus-global.md

@skills/unslop/SKILL.md

# Delegation

When spawning Explore subagents, pass `model: "haiku"`.

Whenever asked to carry out a task, break it down into smaller scoped tasks and delegate them to `model: "sonnet"` subagents to reduce context window usage. If the task is small enough, complete it yourself. When you delegate, ask the subagent to return a concise summary of the result with relevant paths and diffs so you can review the work before reporting to me. Spawn multiple subagents in parallel only when goals and context justify it.

# Context handoff

At 125k tokens, finish the current atomic unit cleanly and prepare to hand off.

At 150k tokens in a main session with concrete remaining autonomous work (not a subagent, not an `/unattended-run` orchestrator following `MISSION.md`, and not waiting on a user decision):
1. Read `~/.claude/skills/handoff/SKILL.md` and write the handoff file.
2. Cancel your own wait loops, timers, and monitors.
3. Spawn the continuation session with `~/.claude/skills/handoff/scripts/spawn_claude.sh <handoff-path>` (passing `--tag` and `--gen` if your launch prompt gave a chain tag and generation).
4. Report the handoff path, new session name and ID, and `claude attach <id>` to the user, then stop working.

If the task is done, blocked on a user decision, or `spawn_claude.sh` fails or hits its chain limit, do not spawn or retry in another form; write the handoff if unfinished and give the user manual resume commands.
