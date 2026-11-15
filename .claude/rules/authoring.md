---
paths:
  - "claude/**"
  - "plugins/**"
---

# Authoring conventions

## Privacy

- This repo is public. Write no person names, private project names or absolute local paths. Use `my-project` and `~/nexus` in examples.
- In `claude/settings.json`, write paths with the `{{HOME}}` and `{{NEXUS}}` tokens.

## Skills

- A skill is a folder, `claude/skills/<name>/SKILL.md`, with `name` and `description` in the frontmatter.
- The description says when to use the skill. Keep it under two lines, because every session loads it.
- Set `disable-model-invocation: true` on workflows that only the user starts.
- Put helper scripts in `scripts/` inside the skill folder.
- Run `./install.sh` after adding a skill folder.

## Sub-agents

- A sub-agent is a file, `claude/agents/<name>.md`. `name` and `description` are required.
- Give each agent a `tools` allowlist and a `model`.
- Set `omitClaudeMd: true` on agents that need no project conventions.
- No install step is needed, because `~/.claude/agents/nexus` links to the whole folder.

## Hooks

- Put the script in `claude/hooks/`.
- Register it in `claude/settings.json` as `{{HOME}}/.claude/hooks/<file>`, then run `./install.sh`.

## Settings

- Claude Code rewrites `~/.claude/settings.json`. Run `./capture.sh` to copy it back.

## Plugins

- A plugin lives in `plugins/<name>/` with `.claude-plugin/plugin.json` and `skills/<name>/SKILL.md`.
- Add an entry to `.claude-plugin/marketplace.json`.
- Set no `version` field, so each commit on `main` counts as an update.
- Claude Code runs an installed plugin from its cache. An edit here is live only after it is on `main` and the marketplace has updated.

## Rules

- Every file in `.claude/rules/` needs `paths:` frontmatter. A file without it loads in every project session under `repos/`.

## Branches

- The main clone stays on `main`, because `~/.claude` links into it. Edit through a git worktree, then open a PR.
