---
paths:
  - "rules/**"
  - "skills/**"
  - "claude/**"
  - "antigravity/**"
  - "bin/**"
---

# Authoring conventions

## Privacy

- This repo is public. Write no person names, private project names, or absolute local paths. Use `my-project` and `~/nexus` in examples.
- In `claude/settings.json`, write paths with the `{{HOME}}`, `{{CLAUDE_CONFIG_DIR}}`, and `{{NEXUS}}` tokens.

## Global rules

- Shared instructions live in `rules/global.md` as plain Markdown with no frontmatter. Both Claude Code and Antigravity CLI load it via `nexus-global.md` links installed by `./install.sh`.
- Harness-specific instructions (such as delegation syntax) live in `claude/CLAUDE.md` and `antigravity/rules/AGENTS.md`.

## Skills

- Shared skills live in `skills/<name>/SKILL.md`. Claude-only skills live in `claude/skills/<name>/SKILL.md`.
- Every `SKILL.md` needs YAML frontmatter with `name` matching the folder name and a non-empty `description`. Antigravity drops skills without both fields.
- Keep `description` under two lines, because every session loads it.
- Set `disable-model-invocation: true` (for Claude Code) or `disable-slash-command: true` (for Antigravity) when appropriate on user-started workflows.
- Put helper scripts in `scripts/` inside the skill folder.
- Run `./install.sh` after adding a skill folder.

## Sub-agents

- Claude Code sub-agents live in `claude/agents/<name>.md` with `name`, `description`, `tools`, and `model`. Set `omitClaudeMd: true` on agents that need no project conventions. No install step is needed, because `~/.claude/agents/nexus` links to the whole folder.
- Antigravity sub-agents live in `antigravity/agents/<name>.md` with `name`, `description`, `subagent: true`, `mainAgent: false`, and an explicit native `tools` list (`read_file`, `edit_file`, `write_file`, `run_command`, `manage_task`). Omitting `tools` restricts the agent to a small read-only default set.

## Hooks and mods

- Put Claude Code hook scripts in `claude/hooks/` and register them in `claude/settings.json` as `{{CLAUDE_CONFIG_DIR}}/hooks/<file>`, then run `./install.sh`.
- Put Antigravity hook scripts in `antigravity/hooks/` and register them in `antigravity/hooks.json` with a relative path like `./hooks/<file>`, because Antigravity runs plugin hooks from the plugin root.
- Claude Code mods live in `claude/mods/<name>/`. Run `./install.sh` after adding a mod folder.
- After editing anything under `antigravity/`, run `agy plugin validate antigravity --strict`.

## CLI tools

- Put executable CLI tools in `bin/`. Run `./install.sh` after adding a file so it links into `~/.local/bin` (or `$NEXUS_BIN_DIR`).

## Settings

- Claude Code rewrites `~/.claude/settings.json`. Run `./capture.sh` to copy it back.

## Rules

- Every file in `.claude/rules/` needs `paths:` frontmatter, and every file in `.agents/rules/` needs `trigger: glob` with a comma-separated `**/`-prefixed `globs` string. A rule without path/glob scoping loads in every project session under `repos/`.

## Branches

- The main clone stays on `main`, because `~/.claude` and `~/.gemini/config` link into it. Edit through a git worktree, then open a PR.
