# Nexus

Nexus is the home repo for the shared Claude Code setup. Project repos are cloned in `repos/`, each its own git repo, gitignored here.

`install.sh` links everything in `claude/` into `~/.claude`, so its skills, agents and settings are already loaded in every repo. Never copy them into a project. Edit them here.

| Need | Path |
|---|---|
| Global instructions | `claude/CLAUDE.md` |
| Settings, hooks | `claude/settings.json`, `claude/hooks/` |
| Skills | `claude/skills/<name>/SKILL.md` |
| Sub-agents | `claude/agents/<name>.md` |
| Public plugins | `plugins/<name>/` |
| CLI tools | `bin/` |
| Projects | `repos/<name>/` |
| Machine setup | `SETUP.md` |

- In `repos/<name>`, stay in that repo. Its own `CLAUDE.md` and `README.md` describe it. Touch other repos only when asked.
- Search from the narrowest folder. A search from the nexus root skips `repos/`. List projects with `ls repos/`.
- Skill and agent descriptions are already in context. Open a body only to edit it.
- Before editing anything under `claude/` or `plugins/`, read `.claude/rules/authoring.md`.
- Nexus and each project commit separately. Run `git` in the repo you changed.
