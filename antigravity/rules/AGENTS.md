# Nexus workspace

Project repos are cloned in `~/nexus/repos/<name>`, each its own git repo. Shared rules, skills, subagents, hooks, and CLI tools live in `~/nexus` and reach sessions through `~/.gemini/config`. Never copy them into a project; edit them in `~/nexus`.

- In `~/nexus/repos/<name>`, stay in that repo. Its own `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, and `README.md` describe it. Touch other repos only when asked.
- Search from the narrowest folder. A search from the `~/nexus` root skips `repos/` via `.gitignore`.
- Nexus and each project commit separately. Run `git` in the repo you changed.

# Delegation

When spawning `research` subagents to explore codebases, pass `Model: "flash_lite"`.

Whenever asked to carry out a task, break it down into smaller scoped tasks and delegate them using `invoke_subagent` (passing `Model: "flash"` or using the `implementer`, `reviewer`, and `test-runner` subagents) to reduce context window usage. If the task is small enough, complete it yourself. When you delegate, ask the subagent to return a concise summary of the result with relevant paths and diffs so you can review the work before reporting to me. Spawn multiple subagents in parallel only when goals and context justify it.

@[Global instructions](~/.gemini/config/nexus-global.md)

@[Unslop rules](~/.gemini/config/skills/unslop/SKILL.md)
