# nexus

Nexus is a home repository for a shared Claude Code setup. It holds global instructions, settings, hooks,
skills, sub-agents and CLI tools, and `install.sh` links them into `~/.claude`. Every project repo is cloned
inside it, under `repos/`.

## Layout

```
CLAUDE.md                        map for agents, loads in every session started under nexus
README.md, SETUP.md              SETUP.md has the steps for an agent setting up a machine
install.sh, capture.sh
.claude/rules/authoring.md       conventions for editing skills and agents
claude/                          mirrors ~/.claude
  CLAUDE.md, settings.json
  skills/<name>/SKILL.md
  agents/<name>.md
  hooks/, mods/
bin/                             CLI tools, currently ctx
repos/                           gitignored, one clone per project
```

## New machine

```sh
git clone https://github.com/leobruneau/nexus ~/nexus
cd ~/nexus
./install.sh --dry-run   # print what would change
./install.sh
```

Then restart Claude Code. You can also start Claude Code anywhere and say
"set up this machine from github.com/leobruneau/nexus"; `SETUP.md` tells the agent what to do.

`install.sh` needs `python3`. It does the following:

- symlinks `claude/CLAUDE.md`, each folder in `claude/skills/` and `claude/mods/`, each file in
  `claude/hooks/`, and the `claude/agents` folder into `~/.claude`
- links each file in `bin/` into `~/.local/bin`, or into `NEXUS_BIN_DIR` if set
- merges `claude/settings.json` into `~/.claude/settings.json`. Repo keys win, keys that exist only on
  the machine stay, `{{HOME}}` becomes `$HOME` and `{{NEXUS}}` becomes the clone's path. The merge replaces arrays whole (for example `permissions.deny`), and a key removed from the repo stays on a machine that already has it
- moves every file it replaces to `~/.claude/backups/nexus-<timestamp>/`

Running it twice changes nothing. Because of the symlinks, the clone must stay where it is.

## Working on a project

```sh
git clone <url> ~/nexus/repos/<name>
cd ~/nexus/repos/<name>
claude
```

To move an existing clone, `mv` it into `repos/`. If worktrees moved with it, run `git worktree repair <path>` in it with the new path of each worktree.
Claude Code stores session history per absolute path, so sessions from the old location do not show up
under the new one.

Repos sit inside nexus because the root `CLAUDE.md` loads in every session started there. Skills, agents
and settings reach those sessions through `~/.claude`.

## What is tracked

| Path | Goes to | Contents |
|---|---|---|
| `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | Global instructions. Imports the unslop rules. |
| `claude/settings.json` | merged into `~/.claude/settings.json` | Model, effort, permission mode, denied tools, hooks, enabled plugins, plugin marketplaces |
| `claude/hooks/context-alert.sh` | `~/.claude/hooks/context-alert.sh` | Runs after every tool call and prompt. When the context passes 100k, 125k and 150k tokens, it tells the agent once per threshold, with a stronger handoff request each time. |
| `claude/skills/handoff` | `~/.claude/skills/handoff` | `/handoff` writes a handoff document and starts a fresh session with it |
| `claude/skills/time-machine` | `~/.claude/skills/time-machine` | `/time-machine` reports past work from Claude Code and git history |
| `claude/skills/unattended-run` | `~/.claude/skills/unattended-run` | `/unattended-run` runs a long task (experiment search, issue backlog, refactor, sweep, literature review) unattended. Background orchestrator sessions hand off to each other through files in a run directory, a watchdog relaunches a stalled orchestrator, and a final summary session writes `FINAL_SUMMARY.md`. |
| `claude/skills/unslop` | `~/.claude/skills/unslop` | Writing rules that strip AI patterns from prose |
| `claude/agents` | `~/.claude/agents/nexus` | Sub-agent definitions, such as `reviewer` and `test-runner` |
| `claude/mods/context-bar` | `~/.claude/mods/context-bar` | Local plugin that shows a context-usage bar above the prompt, loaded through `CLAUDE_CODE_PLUGIN_DIRS` |
| `bin/ctx` | `~/.local/bin/ctx` | Prints the session's context-window usage. A symlink to the script in the `unattended-run` skill. |

Not tracked: `~/.claude.json` (account and per-project state), history, sessions, caches, and
`~/.claude/skills/synced` (claude.ai syncs it). Plugins from marketplaces are not copied either.
`settings.json` lists them under `enabledPlugins` and `extraKnownMarketplaces`, and Claude Code installs them.

## Adding things

Conventions are in `.claude/rules/authoring.md`.

- Skill. Create `claude/skills/<name>/SKILL.md`, then run `./install.sh`.
- Sub-agent. Create `claude/agents/<name>.md`. It is live with no reinstall.
- Hook. Add the script to `claude/hooks/`, register it in `claude/settings.json`, then run `./install.sh`.

## Saving changes

Edits to `claude/CLAUDE.md`, linked skills, agents and mods go straight into the clone, since those are
symlinks. Claude Code writes `settings.json` itself (for example when you enable a plugin), so copy it back:

```sh
./capture.sh   # copies settings.json, plus any skill, mod, hook, agent or CLAUDE.md that is a plain file in ~/.claude
git diff
git add -A && git commit -m "Update settings" && git push
```

Keep the main clone on `main`, because `~/.claude` links into it and a branch checkout changes the live
config of every session. Edit through a git worktree, then open a PR.
On other machines, `git pull && ./install.sh` applies the changes.

## Unattended runs

The `unattended-run` skill sets `disable-model-invocation: true`, so only you start it, with `/unattended-run`. It needs bash, GNU or BSD `date` and `stat`, perl on macOS (the skill ships a `setsid` stand-in), a Claude Code version with `claude --bg` and `claude agents --json`, and a trusted workspace. On a laptop, keep it on power with the lid open. `caffeinate` stops idle sleep, but closing the lid still sleeps the machine.
