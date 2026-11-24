# nexus

Nexus is a home repository for a shared Claude Code and Antigravity CLI setup.
It holds shared global rules, skills, harness-specific configs, sub-agents,
hooks, and CLI tools, and `install.sh` links them into `~/.claude` and
`~/.gemini/config`. Every project repo is cloned inside it under `repos/`.

## Layout

```
AGENTS.md                        map for agents (CLAUDE.md symlinks here)
README.md, SETUP.md              SETUP.md has steps for setting up a machine
install.sh, capture.sh           install and reverse-sync scripts
.claude/rules/authoring.md       authoring rules for Claude Code
.agents/rules/authoring.md       authoring rules for Antigravity CLI
rules/global.md                  shared global rules (writing, code style, ctx, authorship)
skills/<name>/SKILL.md           shared skills (handoff, time-machine, unslop)
claude/                          Claude Code setup linked into ~/.claude
  CLAUDE.md, settings.json
  skills/unattended-run/
  agents/<name>.md
  hooks/, mods/
antigravity/                     Antigravity CLI plugin linked into ~/.gemini/config/plugins/nexus
  plugin.json, hooks.json
  rules/AGENTS.md
  agents/<name>.md
  hooks/
bin/                             CLI tools, currently ctx
repos/                           gitignored, one clone per project
```

## New machine

```sh
git clone https://github.com/leobruneau/nexus ~/nexus
cd ~/nexus
./install.sh --dry-run   # print what would change
./install.sh             # or pass --claude-only / --antigravity-only
```

Then restart Claude Code or start `agy`. You can also ask an agent anywhere to
"set up this machine from github.com/leobruneau/nexus"; `SETUP.md` tells it
what to do.

`install.sh` downloads a pinned `jq` release with `curl` to
`~/.local/share/nexus/bin/jq` (and links `~/.claude/bin/jq` to it), checks its
SHA-256, and uses it. If the download fails, it falls back to `jq` on `PATH`.

`install.sh` does the following:

- symlinks `rules/global.md` as `nexus-global.md` and every shared folder in
  `skills/` into both `~/.claude` and `~/.gemini/config`
- for Claude Code, symlinks `claude/CLAUDE.md`, `claude/skills/*`,
  `claude/mods/*`, `claude/hooks/*`, and `claude/agents` (as `agents/nexus`),
  and merges `claude/settings.json` into `~/.claude/settings.json`. Repo keys
  win, local-only keys stay, and `{{HOME}}`, `{{CLAUDE_CONFIG_DIR}}`, and
  `{{NEXUS}}` expand. Arrays (such as `permissions.deny`) replace whole, and
  keys removed from the repo stay on machines that already had them
- for Antigravity CLI, symlinks `antigravity/` to
  `~/.gemini/config/plugins/nexus`
- links each file in `bin/` into `~/.local/bin` (or `$NEXUS_BIN_DIR`)
- moves every replaced file to `<config-dir>/backups/nexus-<timestamp>/`

Running it twice changes nothing. Because of the symlinks, the clone must stay
where it is.

## Working on a project

```sh
git clone <url> ~/nexus/repos/<name>
cd ~/nexus/repos/<name>
claude   # or: agy
```

To move an existing clone, `mv` it into `repos/`. If worktrees moved with it,
run `git worktree repair <path>` in it with the new path of each worktree.
Claude Code stores session history per absolute path, so sessions from an old
location do not show up under the new one.

Under Claude Code, `~/nexus/CLAUDE.md` loads from parent directories; under
Antigravity CLI, workspace rule walking stops at each repo's `.git`, so the
`nexus` global plugin provides the workspace instructions and global rules
across every session under `repos/`.

## What is tracked

| Path | Goes to | Contents |
|---|---|---|
| `rules/global.md` | `~/.claude/nexus-global.md`, `~/.gemini/config/nexus-global.md` | Shared writing, code style, `ctx`, and authorship rules |
| `skills/handoff` | `~/.claude/skills/handoff`, `~/.gemini/config/skills/handoff` | `/handoff` writes a handoff file and starts or hooks a fresh session |
| `skills/time-machine` | `~/.claude/skills/time-machine`, `~/.gemini/config/skills/time-machine` | `/time-machine` reports past work from Claude Code, Antigravity CLI, and git history |
| `skills/unslop` | `~/.claude/skills/unslop`, `~/.gemini/config/skills/unslop` | Writing rules that strip AI patterns from prose |
| `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | Imports `nexus-global.md` and `unslop`, plus Claude delegation rules |
| `claude/settings.json` | merged into `~/.claude/settings.json` | Model, effort, permission mode, denied tools, hooks, plugins |
| `claude/hooks/context-alert.sh` | `~/.claude/hooks/context-alert.sh` | Alerts once per session when context passes 100k, 125k, and 150k tokens |
| `claude/skills/unattended-run` | `~/.claude/skills/unattended-run` | `/unattended-run` runs long tasks across chained background Claude sessions |
| `claude/agents` | `~/.claude/agents/nexus` | Claude sub-agents (`implementer`, `reviewer`, `test-runner`) |
| `claude/mods/context-bar` | `~/.claude/mods/context-bar` | Local Claude Code plugin showing context usage in the footer |
| `antigravity/` | `~/.gemini/config/plugins/nexus` | Antigravity plugin: rules, sub-agents (`implementer`, `reviewer`, `test-runner`), `PreInvocation` context alert hook |
| `bin/ctx` | `~/.local/bin/ctx` | Prints context-window usage for Claude Code or Antigravity CLI |

Not tracked: `~/.claude.json`, `~/.gemini/config/config.json`, session history,
caches, and `~/.claude/skills/synced`. Marketplace plugins are listed in
`claude/settings.json`, not copied.

## Adding things

Conventions are in `.claude/rules/authoring.md` and `.agents/rules/authoring.md`.

- Shared skill. Create `skills/<name>/SKILL.md`, then run `./install.sh`.
- Shared rule. Edit `rules/global.md`.
- Claude sub-agent. Create `claude/agents/<name>.md` (live with no reinstall).
- Antigravity sub-agent. Create `antigravity/agents/<name>.md` (live with no reinstall).
- Claude mod or hook. Add under `claude/mods/` or `claude/hooks/` (and register hooks in `claude/settings.json`), then run `./install.sh`.
- Antigravity hook. Add under `antigravity/hooks/`, register in `antigravity/hooks.json`, and run `agy plugin validate antigravity --strict`.

## Saving changes

Edits to symlinked files go straight into the clone. Run `./capture.sh` to copy
back `settings.json` or plain skills, hooks, mods, and agents added locally. For
`settings.json`, `capture.sh` only copies keys already in
`claude/settings.json`, along with tracked entries inside `env` and
`enabledPlugins`, and prints any skipped local keys so they do not leak into
the public repo:

```sh
./capture.sh
git status --short && git diff
```

Keep the main clone on `main`, because `~/.claude` and `~/.gemini/config` link
into it. Edit through a git worktree, then open a PR. On other machines,
`git pull && ./install.sh` applies changes.

## Unattended runs

The `unattended-run` skill sets `disable-model-invocation: true`, so only you
start it with `/unattended-run`. It needs bash, GNU or BSD `date` and `stat`,
perl on macOS (the skill ships a `setsid` stand-in), a Claude Code build with
`claude --bg` and `claude agents --json`, and a trusted workspace. On a laptop,
keep it on power with the lid open (`caffeinate` stops idle sleep, closing the
lid still sleeps).
