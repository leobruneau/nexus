# Nexus

Nexus is the home repo for the shared Claude Code setup. Project repos are cloned in `repos/`, each its own git repo, gitignored here.

`install.sh` links `claude/` into `~/.claude` and merges its settings, so the skills, agents and settings here are already loaded in every repo. Never copy them into a project. Edit them here.

Paths are relative to the nexus root, the folder that holds this file.

| Need | Path |
|---|---|
| Global instructions | `claude/CLAUDE.md` |
| Settings, hooks | `claude/settings.json`, `claude/hooks/` |
| Skills | `claude/skills/<name>/SKILL.md` |
| Sub-agents | `claude/agents/<name>.md` |
| CLI tools | `bin/` |
| Projects | `repos/<name>/` |
| Machine setup | `SETUP.md` |

- In `repos/<name>`, stay in that repo. Its own `CLAUDE.md` and `README.md` describe it. Touch other repos only when asked.
- Search from the narrowest folder. A search from the nexus root skips `repos/`. List projects with `ls repos/`.
- Skill and agent descriptions are already in context. Open a body only to edit it.
- Before editing anything under `claude/`, read `.claude/rules/authoring.md` at the nexus root.
- Nexus and each project commit separately. Run `git` in the repo you changed.
