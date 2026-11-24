@nexus-global.md

@skills/unslop/SKILL.md

# Delegation

When spawning Explore subagents, pass `model: "haiku"`.

Whenever asked to carry out a task, break it down into smaller scoped tasks and delegate them to `model: "sonnet"` subagents to reduce context window usage. If the task is small enough, complete it yourself. When you delegate, ask the subagent to return a concise summary of the result with relevant paths and diffs so you can review the work before reporting to me. Spawn multiple subagents in parallel only when goals and context justify it.
