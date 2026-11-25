# nexus

Nexus is a home repository for a shared Claude Code and Antigravity CLI setup.
It holds shared global rules, skills, harness-specific configs, sub-agents,
hooks, and CLI tools, and `install.sh` links them into `~/.claude` and
`~/.gemini/config`. Clone project repos inside it under `repos/`.

## Layout

```
AGENTS.md                        map for agents (CLAUDE.md symlinks here)
README.md, SETUP.md              SETUP.md has steps for setting up a machine
install.sh, capture.sh           install and reverse-sync scripts
.claude/rules/authoring.md       authoring rules for Claude Code
.agents/rules/authoring.md       authoring rules for Antigravity CLI
rules/global.md                  shared global rules (writing, engineering discipline, code style, workflows, ctx, authorship)
skills/<name>/SKILL.md           shared workflow and composable skills
claude/                          Claude Code setup linked into ~/.claude
  CLAUDE.md, settings.json
  agents/<name>.md
  hooks/, mods/
antigravity/                     Antigravity CLI plugin linked into ~/.gemini/config/plugins/nexus
  plugin.json, hooks.json
  rules/AGENTS.md
  skills/bg-session/
  agents/<name>.md
  hooks/
bin/                             CLI tools, currently ctx
repos/                           gitignored, one clone per project
```

## New machine

Install requires `git`, `curl`, `rsync`, and `sha256sum` or `shasum` on macOS.
The `/handoff` hook and `/time-machine` also require `python3`. Make sure
`~/.local/bin` is on `PATH` so `ctx` can run.

```sh
git clone https://github.com/leobruneau/nexus ~/nexus
cd ~/nexus
./install.sh --dry-run   # print what would change
./install.sh             # or pass --claude-only / --antigravity-only
```

You can also ask an agent to "set up this machine from
github.com/leobruneau/nexus". `SETUP.md` lists the steps it follows.

### Verify the install

- Claude Code. Restart Claude Code and run `/plugin` to confirm every plugin in
  `enabledPlugins` installed. If one did not auto-install, run
  `claude plugin install <name>@<marketplace>`.
- Antigravity CLI. Run `agy plugin list` and confirm `nexus` is listed.
- `ctx`. Run `command -v ctx` in a shell to check `PATH`. Then run `ctx` inside
  a Claude Code or Antigravity CLI session, or `ctx <session-id>` from a shell,
  to confirm token output.

### What `install.sh` does

`install.sh` downloads a pinned `jq` release with `curl` to
`~/.local/share/nexus/bin/jq`, links `~/.claude/bin/jq` to it, verifies its
SHA-256, and uses it. If the download fails, it falls back to `jq` on `PATH`.

- Symlinks `rules/global.md` as `nexus-global.md` and every shared folder in
  `skills/` into `~/.claude/skills/`, `~/.gemini/config/skills/`, and
  `~/.gemini/antigravity-cli/skills/` so Nexus skills take priority over
  `~/.agents/skills/` in Antigravity CLI. Warns if a same-named skill exists
  in `~/.agents/skills/` or `~/.gemini/skills/`.
- For Claude Code, symlinks `claude/CLAUDE.md`, `claude/skills/*`,
  `claude/mods/*`, `claude/hooks/*`, and `claude/agents` as `agents/nexus`, and
  merges `claude/settings.json` into `~/.claude/settings.json`. Repo keys win,
  local-only keys stay, and `{{HOME}}`, `{{CLAUDE_CONFIG_DIR}}`, and
  `{{NEXUS}}` expand. Arrays such as `permissions.deny` replace whole, and keys
  removed from the repo stay on machines that already had them.
- For Antigravity CLI, symlinks `antigravity/` to
  `~/.gemini/config/plugins/nexus`.
- Links each file in `bin/` into `~/.local/bin` or `$NEXUS_BIN_DIR`.
- Moves every replaced file to `<config-dir>/backups/nexus-<timestamp>/`.

Running `install.sh` twice changes nothing. Because of the symlinks, keep the
clone where it is.

Optional environment variables override the default paths:

| Variable | Default | Used for |
|---|---|---|
| `CLAUDE_CONFIG_DIR` | `~/.claude` | Claude Code config directory |
| `ANTIGRAVITY_CONFIG_DIR` | `~/.gemini/config` | Antigravity CLI config directory |
| `ANTIGRAVITY_APP_DATA_DIR` | `~/.gemini/antigravity-cli` | Antigravity CLI high-priority skills and transcripts |
| `NEXUS_BIN_DIR` | `~/.local/bin` | Symlink directory for `bin/` tools |
| `NEXUS_DATA_DIR` | `~/.local/share/nexus` | Pinned `jq` binary location |

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

Under Claude Code, `~/nexus/CLAUDE.md` loads from parent directories. Under
Antigravity CLI, workspace rule walking stops at each repo's `.git`, so the
`nexus` global plugin provides the workspace instructions and global rules
across every session under `repos/`.

You can keep an optional gitignored `repos/INDEX.md` (for example, listing
`my-project` stacks, doc paths, and test commands) so agents working from
`~/nexus` can locate and switch projects without scanning every repo.

## Daily usage

- `ctx`. Run `ctx` inside a Claude Code or Antigravity CLI session to print
  context-window usage, such as `29.2K / 1000K tokens (2.9%)`. Outside a
  session, pass `ctx <session-id>` and an optional `<max_tokens>`. It reads the
  latest token counts from the transcript and lags by one API call.
- Workflow skills. Four end-to-end workflows compose the shared skills below:
  - `/kickoff`. Turns a rough idea into a spec and ordered tickets using
    `grilling`, `domain-modeling`, `codebase-design`, `prototype`, `to-spec`,
    and `to-tickets`.
  - `/execute-plan`. Carries out a spec or ticket queue with `tdd`,
    `diagnosing-bugs`, `codebase-design`, and `architect`, logging technical
    decisions with `show-me-your-work`.
  - `/review`. Runs multi-axis `code-review` (Standards and Spec), adversarial
    `interrogate`, `blast-radius`, `no-comments`, and hygiene checks.
  - `/improve-setup`. Audits recent transcripts and decision logs with
    `reflect`, `correct`, `improve-codebase-architecture`,
    `create-verification-skill`, `maintain-verification-skill`, and
    `writing-for-agents` to update rules and skills.
- Composable skills in `skills/`. Available on their own or inside workflows:
  `grilling`, `domain-modeling`, `codebase-design`, `to-spec`, `to-tickets`,
  `prototype`, `tdd`, `diagnosing-bugs`, `architect`, `code-review`,
  `interrogate`, `blast-radius`, `no-comments`, `pr`, `show-me-your-work`,
  `create-verification-skill`, `maintain-verification-skill`,
  `improve-codebase-architecture`, `correct`, `reflect`, `writing-for-agents`,
  `handoff`, `time-machine`, and `unslop`.
- `/handoff`. Writes a compact handoff file under
  `~/.local/share/nexus/handoffs/<project-slug>/` and prints commands to start a
  fresh session with it. To auto-inject the newest pending handoff on `/clear`,
  `/new`, or session start instead, install the optional `SessionStart` hook
  once from `~/nexus`:

  ```sh
  bash skills/handoff/scripts/install_hook.sh
  ```

  Pass `--claude` or `--antigravity` to register the hook for one harness only.
  In Claude Code, crossing 150k tokens triggers automated handoff via `skills/handoff/scripts/spawn_claude.sh` (`claude --bg`), printing `claude attach <id>` so work continues in a fresh background session (capped at 5 chained handoffs by default via `HANDOFF_MAX_GEN`).
- `/time-machine`. Mines Claude Code transcripts, Antigravity CLI transcripts,
  and git history over a time window, then writes a chronological report to
  `~/time-machine-reports/`.
- Shared sub-agents. Both harnesses define `implementer` for executing one
  already-planned change, `reviewer` for read-only diff review, `test-runner`
  for running a test, build, or lint command and returning only failures, and
  `comment-sicko` for auditing and removing redundant or misleading comments.
- Engineering discipline. `rules/global.md` sets shared defaults across every
  repo for small changes, explicit error handling, testing real behavior, and
  unslopped writing.

## Unattended runs

The `unattended-run` skill sets `disable-model-invocation: true`, so only you
start it with `/unattended-run`. It needs bash, GNU or BSD `date` and `stat`,
perl on macOS (the skill ships a `setsid` stand-in), and either `claude --bg`
with a trusted workspace (`HARNESS=claude`) or `rex`, `agy`, and `jq`
(`HARNESS=agy`, using the `bg-session` skill). On a laptop, keep it on power
with the lid open (`caffeinate` stops idle sleep, closing the lid still sleeps).

Setup can ingest `/kickoff` specs from `docs/specs/` or `.scratch/` into
`inputs/` and import `/to-tickets` queues with blocking edges into `PLAN.md`.
Orchestrators can record technical decisions in `decisions.tsv` via
`show-me-your-work` while keeping `LOG.md` for watchdog and protocol lines.
Combined-branch verification and PR creation wire `/review` and `/pr`, and the
final summary audits `decisions.tsv` and suggests `/improve-setup` when lessons
accumulate.

## What is tracked

| Path | Goes to | Contents |
|---|---|---|
| `rules/global.md` | `~/.claude/nexus-global.md`, `~/.gemini/config/nexus-global.md` | Shared writing, engineering discipline, code style, workflows, `ctx` handoffs, and authorship rules |
| `skills/kickoff` | `~/.claude/skills/kickoff`, `~/.gemini/config/skills/kickoff`, `~/.gemini/antigravity-cli/skills/kickoff` | `/kickoff` shapes an idea into a spec and ticket queue |
| `skills/execute-plan` | `~/.claude/skills/execute-plan`, `~/.gemini/config/skills/execute-plan`, `~/.gemini/antigravity-cli/skills/execute-plan` | `/execute-plan` executes a spec or ticket queue with TDD and decision logging |
| `skills/review` | `~/.claude/skills/review`, `~/.gemini/config/skills/review`, `~/.gemini/antigravity-cli/skills/review` | `/review` runs Standards and Spec review, interrogation, blast-radius, and comment cleanup |
| `skills/improve-setup` | `~/.claude/skills/improve-setup`, `~/.gemini/config/skills/improve-setup`, `~/.gemini/antigravity-cli/skills/improve-setup` | `/improve-setup` refines rules, skills, and verification checks from session history |
| `skills/grilling` | `~/.claude/skills/grilling`, `~/.gemini/config/skills/grilling`, `~/.gemini/antigravity-cli/skills/grilling` | Questions a plan or requirement until ambiguities settle |
| `skills/domain-modeling` | `~/.claude/skills/domain-modeling`, `~/.gemini/config/skills/domain-modeling`, `~/.gemini/antigravity-cli/skills/domain-modeling` | Sharpens domain terms, glossaries, and ADRs |
| `skills/codebase-design` | `~/.claude/skills/codebase-design`, `~/.gemini/config/skills/codebase-design`, `~/.gemini/antigravity-cli/skills/codebase-design` | Designs module boundaries and deep interfaces |
| `skills/to-spec` | `~/.claude/skills/to-spec`, `~/.gemini/config/skills/to-spec`, `~/.gemini/antigravity-cli/skills/to-spec` | Turns settled design notes into a written spec |
| `skills/to-tickets` | `~/.claude/skills/to-tickets`, `~/.gemini/config/skills/to-tickets`, `~/.gemini/antigravity-cli/skills/to-tickets` | Splits a spec into ordered tickets with blocking edges |
| `skills/prototype` | `~/.claude/skills/prototype`, `~/.gemini/config/skills/prototype`, `~/.gemini/antigravity-cli/skills/prototype` | Builds a throwaway prototype to test state or UI assumptions |
| `skills/tdd` | `~/.claude/skills/tdd`, `~/.gemini/config/skills/tdd`, `~/.gemini/antigravity-cli/skills/tdd` | Test-driven red-green-refactor workflow |
| `skills/diagnosing-bugs` | `~/.claude/skills/diagnosing-bugs`, `~/.gemini/config/skills/diagnosing-bugs`, `~/.gemini/antigravity-cli/skills/diagnosing-bugs` | Root-cause diagnosis loop for failures and regressions |
| `skills/architect` | `~/.claude/skills/architect`, `~/.gemini/config/skills/architect`, `~/.gemini/antigravity-cli/skills/architect` | Reviews or plans cross-cutting architecture changes |
| `skills/code-review` | `~/.claude/skills/code-review`, `~/.gemini/config/skills/code-review`, `~/.gemini/antigravity-cli/skills/code-review` | Parallel Standards and Spec review against a fixed base |
| `skills/interrogate` | `~/.claude/skills/interrogate`, `~/.gemini/config/skills/interrogate`, `~/.gemini/antigravity-cli/skills/interrogate` | Adversarial questioning of changes for hidden flaws |
| `skills/blast-radius` | `~/.claude/skills/blast-radius`, `~/.gemini/config/skills/blast-radius`, `~/.gemini/antigravity-cli/skills/blast-radius` | Traces callers, dependencies, and side effects of a diff |
| `skills/no-comments` | `~/.claude/skills/no-comments`, `~/.gemini/config/skills/no-comments`, `~/.gemini/antigravity-cli/skills/no-comments` | Strips unnecessary comments and keeps only why-comments |
| `skills/pr` | `~/.claude/skills/pr`, `~/.gemini/config/skills/pr`, `~/.gemini/antigravity-cli/skills/pr` | Writes pull request titles and bodies from the diff |
| `skills/show-me-your-work` | `~/.claude/skills/show-me-your-work`, `~/.gemini/config/skills/show-me-your-work`, `~/.gemini/antigravity-cli/skills/show-me-your-work` | Logs technical decisions to `decisions.tsv` via `scripts/log.sh` |
| `skills/create-verification-skill` | `~/.claude/skills/create-verification-skill`, `~/.gemini/config/skills/create-verification-skill`, `~/.gemini/antigravity-cli/skills/create-verification-skill` | Creates a repo-specific `verify-*` skill |
| `skills/maintain-verification-skill` | `~/.claude/skills/maintain-verification-skill`, `~/.gemini/config/skills/maintain-verification-skill`, `~/.gemini/antigravity-cli/skills/maintain-verification-skill` | Updates a repo `verify-*` skill when checks drift |
| `skills/improve-codebase-architecture` | `~/.claude/skills/improve-codebase-architecture`, `~/.gemini/config/skills/improve-codebase-architecture`, `~/.gemini/antigravity-cli/skills/improve-codebase-architecture` | Finds and resolves structural friction in a repo |
| `skills/correct` | `~/.claude/skills/correct`, `~/.gemini/config/skills/correct`, `~/.gemini/antigravity-cli/skills/correct` | Captures user corrections into durable project rules |
| `skills/reflect` | `~/.claude/skills/reflect`, `~/.gemini/config/skills/reflect`, `~/.gemini/antigravity-cli/skills/reflect` | Extracts recurring lessons from recent sessions |
| `skills/writing-for-agents` | `~/.claude/skills/writing-for-agents`, `~/.gemini/config/skills/writing-for-agents`, `~/.gemini/antigravity-cli/skills/writing-for-agents` | Guides edits to skills, `AGENTS.md`, and `CLAUDE.md` |
| `skills/handoff` | `~/.claude/skills/handoff`, `~/.gemini/config/skills/handoff`, `~/.gemini/antigravity-cli/skills/handoff` | `/handoff` writes a handoff file and hooks or spawns a fresh background Claude session |
| `skills/time-machine` | `~/.claude/skills/time-machine`, `~/.gemini/config/skills/time-machine`, `~/.gemini/antigravity-cli/skills/time-machine` | `/time-machine` reports past work from Claude Code, Antigravity CLI, and git history |
| `skills/unslop` | `~/.claude/skills/unslop`, `~/.gemini/config/skills/unslop`, `~/.gemini/antigravity-cli/skills/unslop` | Writing rules that strip AI patterns from prose |
| `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | Imports `nexus-global.md` and `unslop`, plus Claude delegation rules |
| `claude/settings.json` | merged into `~/.claude/settings.json` | Model, effort, permission mode, denied tools, hooks, plugins |
| `claude/hooks/context-alert.sh` | `~/.claude/hooks/context-alert.sh` | Alerts once per session when context passes 100k, 125k, and 150k tokens |
| `skills/unattended-run` | `~/.claude/skills/unattended-run`, `~/.gemini/config/skills/unattended-run`, `~/.gemini/antigravity-cli/skills/unattended-run` | `/unattended-run` runs long tasks across chained background Claude or `agy` sessions |
| `claude/agents` | `~/.claude/agents/nexus` | Claude sub-agents (`implementer`, `reviewer`, `test-runner`, `comment-sicko`) |
| `claude/mods/context-bar` | `~/.claude/mods/context-bar` | Local Claude Code plugin showing context usage in the footer |
| `antigravity/` | `~/.gemini/config/plugins/nexus` | Antigravity plugin: rules, `bg-session` skill, sub-agents (`implementer`, `reviewer`, `test-runner`, `comment-sicko`), `PreInvocation` context alert hook |
| `bin/ctx` | `~/.local/bin/ctx` | Prints context-window usage for Claude Code or Antigravity CLI |

Not tracked: `~/.claude.json`, `~/.gemini/config/config.json`, session history,
caches, and `~/.claude/skills/synced`. Marketplace plugins are listed in
`claude/settings.json`, not copied.

## Adding things

Conventions live in `.claude/rules/authoring.md` and `.agents/rules/authoring.md`.

- Shared skill. Create `skills/<name>/SKILL.md`, then run `./install.sh`.
- Shared rule. Edit `rules/global.md`.
- Claude sub-agent. Create `claude/agents/<name>.md`; changes apply live with no reinstall.
- Antigravity sub-agent. Create `antigravity/agents/<name>.md`; changes apply live with no reinstall.
- Claude mod or hook. Add under `claude/mods/` or `claude/hooks/`, register hooks in `claude/settings.json`, and run `./install.sh`.
- Antigravity hook. Add under `antigravity/hooks/`, register in `antigravity/hooks.json`, and run `agy plugin validate antigravity --strict`.
- CLI tool. Create an executable script in `bin/`, then run `./install.sh`.

## Saving changes

Edits to symlinked files go straight into the clone. Run `./capture.sh` to copy
back `settings.json` or plain skills, hooks, mods, and agents added locally:

```sh
./capture.sh
git status --short && git diff
```

For `settings.json`, `capture.sh` only copies keys already present in
`claude/settings.json`, along with tracked subkeys inside `env` and
`enabledPlugins`. It prints any skipped local keys so machine-specific values do
not leak into the public repo. To start tracking a new top-level key or a new
entry under `env` or `enabledPlugins`, add it to `claude/settings.json` first
using `{{HOME}}`, `{{CLAUDE_CONFIG_DIR}}`, or `{{NEXUS}}` for local paths. Then
run `./install.sh` to apply it locally, or run `./capture.sh` to pull your
current local value into the repo.

Keep the main clone on `main`, because `~/.claude` and `~/.gemini/config` link
into it. Edit through a git worktree, then open a PR. On other machines,
`git pull && ./install.sh` applies changes.
