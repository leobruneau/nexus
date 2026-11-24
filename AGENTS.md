# Nexus

Nexus is the home repo for the shared Claude Code and Antigravity CLI setup. Project repos are cloned in `repos/`, each its own git repo, gitignored here.

`install.sh` links shared rules and skills, the Claude Code config in `claude/`, and the Antigravity plugin in `antigravity/` into `~/.claude` and `~/.gemini/config`. Never copy them into a project. Edit them here.

Paths are relative to the nexus root, the folder that holds this file.

| Need | Path |
|---|---|
| Shared global instructions | `rules/global.md` |
| Shared skills | `skills/<name>/SKILL.md` |
| Claude Code config | `claude/CLAUDE.md`, `claude/settings.json`, `claude/hooks/`, `claude/agents/`, `claude/mods/`, `claude/skills/unattended-run/` |
| Antigravity CLI plugin | `antigravity/plugin.json`, `antigravity/rules/AGENTS.md`, `antigravity/agents/`, `antigravity/hooks.json`, `antigravity/hooks/` |
| CLI tools | `bin/` |
| Projects | `repos/<name>/` |
| Machine setup | `SETUP.md` |

- In `repos/<name>`, stay in that repo. Its own `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, and `README.md` describe it. Touch other repos only when asked.
- Search from the narrowest folder. A search from the nexus root skips `repos/`. List projects with `ls repos/`.
- Skill and agent descriptions are already in context. Open a body only to edit it.
- Before editing anything under `rules/`, `skills/`, `claude/`, `antigravity/`, or `bin/`, read `.claude/rules/authoring.md` (or `.agents/rules/authoring.md`) at the nexus root.
- Nexus and each project commit separately. Run `git` in the repo you changed.
