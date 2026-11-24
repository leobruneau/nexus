#!/usr/bin/env bash
# PreInvocation hook for Antigravity CLI. Tells the agent when its context passes
# 100k, 125k, and 150k tokens. Each threshold fires once per conversation. If
# context shrinks, thresholds above the new size fire again when it grows back.
set -euo pipefail

noop() { echo "{}"; exit 0; }

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

jq="$(find_jq)" || noop

input="$(cat)"
session=""
transcript=""
while IFS=$'\t' read -r s t; do
  session="$s"
  transcript="$t"
done < <("$jq" -r '[.conversationId // "", .transcriptPath // ""] | @tsv' <<<"$input" 2>/dev/null || true)

[[ "$session" =~ ^[A-Za-z0-9._-]+$ && -f "$transcript" ]] || noop

# Context size on the last model response is input + cache_read + output tokens.
# Skip 0-token/synthetic entries so high-water state does not reset spuriously.
tokens="$(tail -n 500 "$transcript" | "$jq" -Rn '
  [inputs | fromjson?
    | select(.type == "PLANNER_RESPONSE")
    | ((.input_tokens // 0) + (.cache_read_tokens // 0) + (.output_tokens // 0))
    | select(. > 0)]
  | last // empty' 2>/dev/null || true)"
[[ "$tokens" =~ ^[0-9]+$ ]] || noop

level=0
for t in 100000 125000 150000; do
  if ((tokens >= t)); then level=$t; fi
done

state_dir="${PLUGIN_DATA:-${XDG_STATE_HOME:-$HOME/.local/state}/nexus}/context-alert"
mkdir -p "$state_dir" 2>/dev/null || noop
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

((level > 10#$last)) || noop

case $level in
  100000) msg="100k context window reached." ;;
  125000) msg="125k context window reached. Please start thinking about handing off the task." ;;
  150000) msg="150k context window reached. Please hand off the task ASAP." ;;
  *) noop ;;
esac

"$jq" -n --arg m "$msg" '{injectSteps: [{systemMessage: {systemMessage: $m}}]}'
