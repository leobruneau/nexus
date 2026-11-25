# Nexus

Nexus is the home repo for the shared Claude Code and Antigravity CLI setup. Project repos are cloned in `repos/`, each its own git repo, gitignored here.

`install.sh` links shared rules and skills, the Claude Code config in `claude/`, and the Antigravity plugin in `antigravity/` into `~/.claude` and `~/.gemini/config`. Never copy them into a project. Edit them here.

Paths are relative to the nexus root, the folder that holds this file.

| Need | Path |
|---|---|
| Shared global instructions | `rules/global.md` |
| Shared skills | `skills/<name>/SKILL.md` |
| Claude Code config | `claude/CLAUDE.md`, `claude/settings.json`, `claude/hooks/`, `claude/agents/`, `claude/mods/` |
| Antigravity CLI plugin | `antigravity/plugin.json`, `antigravity/rules/AGENTS.md`, `antigravity/agents/`, `antigravity/skills/`, `antigravity/hooks.json`, `antigravity/hooks/` |
| CLI tools | `bin/` |
| Projects | `repos/<name>/` (optional local index in `repos/INDEX.md`) |
| Machine setup | `SETUP.md` |

- In `repos/<name>`, stay in that repo. Its own `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, and `README.md` describe it. Touch other repos only when asked.
- Search from the narrowest folder. A search from the nexus root skips `repos/`. To locate or switch projects from `~/nexus`, read `repos/INDEX.md` if present, or run `ls repos/`.
- Skill and agent descriptions are already in context. Workflow routing (`/kickoff`, `/execute-plan`, `/unattended-run`, `/review`, `/improve-setup`) and shared sub-agent roles live in `rules/global.md`. Open a skill body only to edit or run it.
- Before editing anything under `rules/`, `skills/`, `claude/`, `antigravity/`, or `bin/`, read `.claude/rules/authoring.md` (or `.agents/rules/authoring.md`) at the nexus root.
- Keep the main clone on `main`. Edit Nexus in a git worktree and open a PR. Run `./install.sh` only from `~/nexus` on `main`, never bare inside a worktree.
- Nexus and each project commit separately. Run `git` in the repo you changed.
