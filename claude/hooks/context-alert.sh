#!/usr/bin/env bash
# PostToolUse and UserPromptSubmit hook. Tells the agent when its context passes 100k, 125k and 150k
# tokens. Each threshold fires once per session. If the context shrinks (after /compact), the
# thresholds above the new size fire again when the context grows back.
set -euo pipefail

find_jq() {
  local cand
  for cand in \
    "${NEXUS_DATA_DIR:-$HOME/.local/share/nexus}/bin/jq" \
    "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/bin/jq"; do
    if [[ -x "$cand" ]]; then
      echo "$cand"
      return 0
    fi
  done
  command -v jq 2>/dev/null || return 1
}

jq="$(find_jq)" || exit 0
[[ -x "$jq" ]] || exit 0

input="$(cat)"
session=""
transcript=""
event=""
while IFS=$'\t' read -r s t e; do
  session="$s"
  transcript="$t"
  event="$e"
done < <("$jq" -r '[.session_id // "", .transcript_path // "", .hook_event_name // ""] | @tsv' <<<"$input" 2>/dev/null || true)

[[ "$session" =~ ^[A-Za-z0-9._-]+$ && -f "$transcript" && -n "$event" ]] || exit 0

# Context size is what the model read on the last main-thread turn plus what it wrote.
# fromjson? skips a line that Claude Code is still writing, and select(. > 0) ignores 0-token turns.
tokens="$(tail -n 500 "$transcript" | "$jq" -Rn '
  [inputs | fromjson?
    | select(.type == "assistant" and (.isSidechain | not) and .message.usage != null)
    | .message.usage
    | ((.input_tokens // 0) + (.cache_creation_input_tokens // 0)
      + (.cache_read_input_tokens // 0) + (.output_tokens // 0))
    | select(. > 0)]
  | last // empty' 2>/dev/null || true)"
[[ "$tokens" =~ ^[0-9]+$ ]] || exit 0

level=0
for t in 100000 125000 150000; do if ((tokens >= t)); then level=$t; fi; done

state_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/state/context-alert"
mkdir -p "$state_dir" 2>/dev/null || exit 0
state="$state_dir/$session"

if [[ ! -f "$state" ]]; then
  find "$state_dir" -type f -mtime +14 -delete 2>/dev/null || true
fi

last="$(cat "$state" 2>/dev/null || true)"
[[ "$last" =~ ^[0-9]+$ ]] || last=0

tmp="$(mktemp "$state_dir/.tmp.XXXXXX" 2>/dev/null || true)"
if [[ -n "$tmp" ]]; then
  printf '%s\n' "$level" > "$tmp" 2>/dev/null && mv -f "$tmp" "$state" 2>/dev/null || rm -f "$tmp" 2>/dev/null || true
fi

((level > 10#$last)) || exit 0

handoff_dir="${CLAUDE_CONFIG_DIR:-~/.claude}/skills/handoff"
case $level in
  100000) msg="100k context window reached." ;;
  125000) msg="125k context window reached. Finish the current unit cleanly and prepare to hand off." ;;
  150000) msg="150k context window reached. Hand off ASAP: follow ${handoff_dir}/SKILL.md and spawn a continuation session with ${handoff_dir}/scripts/spawn_claude.sh (skip auto-spawn if you are a subagent, blocked on user input, finished, or an /unattended-run orchestrator following MISSION.md)." ;;
  *) exit 0 ;;
esac

"$jq" -n --arg e "$event" --arg m "$msg" \
  '{hookSpecificOutput: {hookEventName: $e, additionalContext: $m}, systemMessage: $m}'
