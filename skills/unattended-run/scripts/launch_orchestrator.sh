#!/bin/bash
# Launch orchestrator N and print its session id. Logs "launch orchestrator N <id>" and, unless this is
# a recovery launch, "handoff orchestrator <caller> -> <N>" in the same step (caller = N-1).
#   <run_dir>/tools/launch_orchestrator.sh <N> [recovery]
# If N has been launched before, it takes the next free number, so two sessions never share a name.
# Above MAX_ORCH it stops the run and starts the final summary instead.
source "$(dirname "$0")/common.sh"
N=$1; MODE=${2:-}
[[ $N =~ ^[0-9]+$ ]] && (( 10#$N >= 1 )) || { echo "usage: $0 <N> [recovery]" >&2; exit 2; }
N=$((10#$N))
caller=$((N - 1))
lock="$RUN_DIR/.launch.lock"
acquired=0
for (( attempt = 1; attempt <= 60; attempt++ )); do
  if mkdir "$lock" 2>/dev/null; then
    acquired=1
    break
  fi
  if [[ -f $lock/pid ]]; then
    read -r holder < "$lock/pid" 2>/dev/null || holder=""
    if [[ $holder =~ ^[0-9]+$ ]] && ! kill -0 "$holder" 2>/dev/null; then
      rm -rf "$lock"
      continue
    fi
  fi
  sleep 1
done
if (( ! acquired )); then
  log "launch_orchestrator: timed out waiting for launch lock"
  exit 1
fi
trap 'rm -rf "$lock"' EXIT
echo "$$" > "$lock/pid"
last=$(grep -oE "^- [0-9-]+ [0-9:]+ launch orchestrator [0-9]+ " "$LOG" 2>/dev/null | awk '{print $6}' | sort -n | tail -1)
if [[ -n $last ]] && (( N <= last )); then
  if [[ $MODE == recovery ]]; then
    log "launch_orchestrator: orchestrator $last already launched, skipping stale recovery for $N"
    exit 0
  fi
  log "launch_orchestrator: orchestrator $N was launched before, using $((last + 1))"
  N=$((last + 1))
fi
if (( N > MAX_ORCH )); then
  log "orchestrator limit $MAX_ORCH reached, stopping the run"
  "$TOOLS/stop_work.sh"
  rm -rf "$lock"
  trap - EXIT
  exec "$TOOLS/launch_summary.sh"
fi
# The predecessor is the caller for a handoff, or the last one launched for a recovery.
[[ $MODE == recovery ]] && pred=$((N - 1)) || pred=$caller
if (( caller < 1 )) && [[ $MODE != recovery ]]; then
  prompt="You are orchestrator $N of $RUN_NAME."
else
  prev=$(grep -oE "^- [0-9-]+ [0-9:]+ launch orchestrator $pred [^[:space:]]+" "$LOG" 2>/dev/null | tail -1 | awk '{print $7}')
  prompt="You are orchestrator $N of $RUN_NAME. Your predecessor is orchestrator $pred, session ${prev:-none}."
fi
prompt+=" Read $RUN_DIR/MISSION.md first and follow it, then COORDINATOR.md, PLAN.md, results/WORKFLOW.md, and only the last 60 lines of LOG.md in the same directory."
if [[ $MODE == recovery ]]; then
  prompt+=" The watchdog started you because LOG.md was silent for $WATCHDOG_MIN minutes. Follow the recovery steps in MISSION.md."
fi
id=$(bg_launch "$TAG | O$N" "$prompt") || exit 1
if [[ -z $id ]]; then
  log "launch orchestrator $N: no session id from bg_launch (HARNESS=${HARNESS:-claude})"
  exit 1
fi
log "launch orchestrator $N $id${MODE:+ ($MODE)}"
# The handoff line goes in now, not when the caller gets round to it. In one run the machine slept
# between the launch and the caller's own handoff line, and the watchdog read the gap as a crash.
[[ $MODE == recovery ]] || (( caller < 1 )) || log "handoff orchestrator $caller -> $N"
echo "$id"
