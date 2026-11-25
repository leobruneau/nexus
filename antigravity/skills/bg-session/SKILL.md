---
name: bg-session
description: Spawn, inspect, steer, and stop background Antigravity CLI (agy -i) sessions in Rex.
---

# Background `agy` sessions with Rex

Spawn independent `agy` sessions in Rex with `-i` (`--prompt-interactive`) so each worker gets a fresh context, survives after you exit, and stays open for the user to inspect or continue in Rex.

Run `rex` commands outside the terminal sandbox (`BypassSandbox: true`), because the `rex` binary and server socket live outside the workspace.

## Start a session

Create a detached Rex session for the first worker:

```sh
created=$(rex new "$TAG" -c "$WORKSPACE" --window "O1" --keep-open --json -- \
  agy -i "$PROMPT" --model "$MODEL" --mode auto)
sid=$(printf '%s' "$created" | jq -er '.session_id')
wid=$(printf '%s' "$created" | jq -er '.initial_windows[0].window_id')
bid=$(printf '%s' "$created" | jq -er '.initial_windows[0].block_ids[0]')
```

Add more background agents as tabs in that same session (`--focus=false` keeps the user's focus untouched):

```sh
tab=$(rex window new -s "$sid" "O2" -c "$WORKSPACE" --keep-open --focus=false --json -- \
  agy -i "$PROMPT" --model "$MODEL" --mode auto)
wid=$(printf '%s' "$tab" | jq -er '.window_id')
bid=$(printf '%s' "$tab" | jq -er '.block_ids[0]')
```

Put all Rex flags before `--`, then `agy` and its arguments as separate words. Record `$sid`, `$wid`, and `$bid` in a file so later agents and cleanup steps can target full IDs.

## Monitor and steer

- **List sessions and tabs.** `rex ls --json` and `rex session inspect "$sid" --json`.
- **Check if `agy` is alive.** `rex block call -s "$sid" -b "$bid" process` (check running state and `last_exit`).
- **Peek at live TUI output.** `rex capture -s "$sid" -b "$bid" --trim`. Because `agy` uses the alternate screen, capture shows only the current viewport, not scrollback. Pass real results and logs through files on disk.
- **Send follow-up input.** `rex send -s "$sid" -b "$bid" "your message" && rex send-key -s "$sid" -b "$bid" enter`.

## Stop and clean up

- **Close one agent tab.** `rex window close -s "$sid" "$wid"`.
- **Close the whole run session.** `rex kill "$sid"`.

## Gotchas

- Always pass `--mode auto` (or `--dangerously-skip-permissions` if approved), or the background `agy` will stall waiting on a permission prompt.
- Always pass `--keep-open` so startup errors stay visible in the pane if `agy` exits immediately.
- Never send input to or kill your own session (`$REX_SESSION` or `$REX_BLOCK`).
