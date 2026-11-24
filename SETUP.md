# Instructions for coding agents

If the user asks you to set up their machine from this repository, follow these steps.

1. Check for `git`, `curl`, `rsync`, and `sha256sum` (or `shasum` on macOS).
   `install.sh` downloads a pinned `jq`, so do not install `jq` yourself. If
   `install.sh` reports that it could not get `jq`, install `jq` (`brew install jq`
   or `apt install jq`) and rerun it.
2. Clone `github.com/leobruneau/nexus` to `~/nexus`, or `git pull` if it is
   already there. Do not use a temporary folder, because `install.sh` creates
   symlinks into the clone.
3. Run `./install.sh --dry-run` (pass `--claude-only` or `--antigravity-only`
   if the user only wants one harness) and show the user which files it would
   back up and replace, plus any `settings.json` diff. Ask before continuing if
   it would replace a file the repo does not track.
4. Run `./install.sh`. If it prints that a Claude marketplace changed source,
   run the `claude plugin marketplace add` command it gives.
5. Check that `~/.local/bin` is on `PATH`, because `install.sh` links `ctx`
   there. Tell the user to add it if not.
6. For Claude Code: tell the user to restart Claude Code and run `/plugin` to
   verify `enabledPlugins` from `claude/settings.json` are installed (install
   any missing one with `claude plugin install <name>@<marketplace>`).
7. For Antigravity CLI: run `agy plugin validate antigravity --strict` if `agy`
   is installed, and tell the user the `nexus` plugin is linked under
   `~/.gemini/config/plugins/nexus` (check with `agy plugin list`).
8. Report any backup folder path printed by `install.sh`.

If the user asks you to save their current setup, run `./capture.sh`, show
`git status` and `git diff`, and commit and push after they approve.

Never copy `~/.claude.json`, `~/.claude/history.jsonl`, `~/.claude/projects/`,
`~/.gemini/config/config.json`, `~/.gemini/antigravity-cli/`, or other account
and session data into this repo.
