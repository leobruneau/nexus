# Instructions for coding agents

If the user asks you to set up their machine from this repository, follow these steps.

1. Check for `git` and `curl`. `install.sh` uses `jq` if the machine has one and downloads it
   otherwise, so don't install `jq` yourself. If `install.sh` reports that it couldn't get `jq`,
   install `jq` (`brew install jq` or `apt install jq`) and rerun it.
2. Clone `github.com/leobruneau/nexus` to `~/nexus`, or `git pull` if it is already there.
   Don't use a temporary folder, because `install.sh` creates symlinks into the clone.
3. Run `./install.sh --dry-run` and show the user which files it would back up and replace, and the
   settings diff. Ask before going on if it would replace a file that the repo doesn't already track.
4. Run `./install.sh`. If it prints that a marketplace changed source, run the
   `claude plugin marketplace add` command it gives. Until then that marketplace's plugins fail to load.
5. Check that `~/.local/bin` is on `PATH`, because `install.sh` links `ctx` there. Tell the user to add it if not.
6. Tell the user to restart Claude Code and run `/plugin` to check that the plugins in
   `claude/settings.json` under `enabledPlugins` are installed. Install any missing one with
   `claude plugin install <name>@<marketplace>`.
7. Report the backup folder path that `install.sh` printed.

If the user asks you to save their current setup, run `./capture.sh`, show `git diff`, and commit
and push after they approve.

Never copy `~/.claude.json`, `~/.claude/history.jsonl`, `~/.claude/projects/` or other session data into
this repo. They hold account details and conversation history.
