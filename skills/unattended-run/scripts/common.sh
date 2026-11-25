#!/bin/bash
# Sourced by the other scripts. Loads run.env from the same folder and defines helpers.
TOOLS=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=/dev/null
source "$TOOLS/run.env"
LOG="$RUN_DIR/LOG.md"
# macOS has no setsid(1). tools/setsid is a perl stand-in. It goes last on PATH, so a real setsid wins.
export PATH="$PATH:$TOOLS"

# log <text>: append a timestamped line to LOG.md.
log() { echo "- $(date '+%Y-%m-%d %H:%M') $*" >> "$LOG"; }

# to_epoch "YYYY-MM-DD HH:MM": seconds since the epoch, with GNU or BSD date.
to_epoch() {
  [[ -n ${1:-} ]] || return 1
  date -d "$1" +%s 2>/dev/null || date -j -f '%Y-%m-%d %H:%M:%S' "$1:00" +%s 2>/dev/null
}

# mtime <file>: modification time in seconds, with GNU or BSD stat.
mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1"; }

find_jq() {
  local cand
  for cand in "${NEXUS_DATA_DIR:-$HOME/.local/share/nexus}/bin/jq" "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/bin/jq"; do
    [[ -x "$cand" ]] && { echo "$cand"; return 0; }
  done
  command -v jq 2>/dev/null
}

# bg_launch <session name> <prompt>: start a background session in the workspace, print its id.
bg_launch() {
  local harness="${HARNESS:-claude}" out rc
  case "$harness" in
    claude)
      out=$(cd "$WORKSPACE" && claude --bg -n "$1" --model "$ORCH_MODEL" --permission-mode "$PERMISSION_MODE" "$2" 2>&1)
      rc=$?
      if (( rc != 0 )); then
        log "launch of '$1' failed (exit $rc): $(echo "$out" | tail -1)"
        return 1
      fi
      echo "$out" | grep -oE '[0-9a-f]{8}' | head -1
      ;;
    agy)
      local jq_bin tab sid wid bid tmp_sid
      local -a agy_args=()
      command -v rex >/dev/null 2>&1 || { log "launch of '$1' failed: rex not on PATH"; return 1; }
      command -v agy >/dev/null 2>&1 || { log "launch of '$1' failed: agy not on PATH"; return 1; }
      jq_bin=$(find_jq) || { log "launch of '$1' failed: jq not found"; return 1; }

      tab="${1#* | }"
      [[ "$tab" == "$1" ]] && tab="$1"
      [[ -n ${ORCH_MODEL:-} ]] && agy_args+=(--model "$ORCH_MODEL")
      if [[ ${PERMISSION_MODE:-} == "dangerously-skip-permissions" ]]; then
        agy_args+=(--dangerously-skip-permissions)
      elif [[ -n ${PERMISSION_MODE:-} ]]; then
        agy_args+=(--mode "$PERMISSION_MODE")
      fi

      sid=""
      [[ -f "$TOOLS/rex.session" ]] && read -r sid < "$TOOLS/rex.session" || true
      if [[ -n $sid ]] && rex session inspect "$sid" --json >/dev/null 2>&1; then
        out=$(rex window new -s "$sid" "$tab" -c "$WORKSPACE" --keep-open --focus=false --json -- agy -i "$2" "${agy_args[@]}" 2>&1)
        rc=$?
        if (( rc != 0 )); then
          log "launch of '$1' failed (exit $rc): $(echo "$out" | tail -1)"
          return 1
        fi
        wid=$(printf '%s' "$out" | "$jq_bin" -er '.window_id') || return 1
        bid=$(printf '%s' "$out" | "$jq_bin" -er '.block_ids[0]') || return 1
      else
        out=$(rex new "$TAG" -c "$WORKSPACE" --window "$tab" --keep-open --json -- agy -i "$2" "${agy_args[@]}" 2>&1)
        rc=$?
        if (( rc != 0 )); then
          log "launch of '$1' failed (exit $rc): $(echo "$out" | tail -1)"
          return 1
        fi
        sid=$(printf '%s' "$out" | "$jq_bin" -er '.session_id') || return 1
        wid=$(printf '%s' "$out" | "$jq_bin" -er '.initial_windows[0].window_id') || return 1
        bid=$(printf '%s' "$out" | "$jq_bin" -er '.initial_windows[0].block_ids[0]') || return 1
        tmp_sid=$(mktemp "$TOOLS/.rex.session.XXXXXX")
        printf '%s\n' "$sid" > "$tmp_sid"
        mv -f "$tmp_sid" "$TOOLS/rex.session"
      fi

      printf '%s\t%s\t%s\t%s\n' "$1" "$sid" "$wid" "$bid" >> "$TOOLS/rex.sessions.tsv"
      echo "$bid"
      ;;
    *)
      log "launch of '$1' failed: unknown HARNESS '$harness'"
      return 1
      ;;
  esac
}
