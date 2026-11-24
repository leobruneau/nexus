# Instructions for coding agents

Follow these steps when the user asks you to set up this machine from nexus.

1. Check for `git`, `curl`, `rsync`, and `sha256sum` or `shasum` on macOS. Also
   check for `python3`, which `/handoff` hooks and `/time-machine` need. Let
   `install.sh` fetch its pinned `jq` binary on its own; install system `jq`
   with `brew install jq` or `apt install jq` and rerun only if `install.sh`
   reports it could not get `jq`.
2. Clone `https://github.com/leobruneau/nexus` to `~/nexus`, or run `git pull`
   if the clone is already there. Use a permanent path, not a temporary folder,
   because `install.sh` symlinks into the clone.
3. Run `./install.sh --dry-run` from `~/nexus`. Pass `--claude-only` or
   `--antigravity-only` if the user wants only one harness. Show the user every
   file it would back up or replace and any `settings.json` diff. Ask before
   continuing if it would replace a file this repo does not track.
4. Run `./install.sh` with the same flags. If it prints that a Claude
   marketplace changed source, run the `claude plugin marketplace add` command
   it prints. If it warns about shadowing skills in `~/.agents/skills/` or
   `~/.gemini/skills/`, report them to the user.
5. Check that `~/.local/bin`, or `$NEXUS_BIN_DIR` if set, is on `PATH` and that
   `command -v ctx` resolves. If not, tell the user to add that directory to
   `PATH`.
6. When setting up Claude Code, tell the user to restart Claude Code and run
   `/plugin` to verify every entry in `enabledPlugins` from
   `claude/settings.json` installed. If any plugin is missing, give them
   `claude plugin install <name>@<marketplace>`.
7. When setting up Antigravity CLI, if `agy` is installed, run
   `agy plugin validate antigravity --strict` and `agy plugin list` to confirm
   the `nexus` plugin is valid and listed.
8. Report any backup folder path printed by `install.sh`.

## Saving local setup changes

When the user asks you to save their current setup, follow these steps.

1. Run `./capture.sh` from `~/nexus`.
2. Show `git status`, `git diff`, and any skipped local `settings.json` keys
   printed by `capture.sh`. If the user wants to track a skipped key, add it to
   `claude/settings.json` using `{{HOME}}`, `{{CLAUDE_CONFIG_DIR}}`, or
   `{{NEXUS}}` for local paths, then rerun `./capture.sh`.
3. Inspect the diff to confirm it contains no local usernames, private project
   names, or absolute local paths.
4. Commit and push, or open a PR from a git worktree to keep the main clone on
   `main`, only after the user approves.

Track only shared rules, skills, sub-agents, hooks, mods, CLI tools, and
sanitized `claude/settings.json` keys. Never copy `~/.claude.json`,
`~/.claude/history.jsonl`, `~/.claude/projects/`,
`~/.gemini/config/config.json`, `~/.gemini/antigravity-cli/`, or other account
and session data into this repo.
