#!/bin/bash
# Launch the next orchestrator in recovery mode when LOG.md has been silent for WATCHDOG_MIN minutes.
# After the machine sleeps, it logs the wake-up, which restarts the silence count, so a sleeping
# laptop doesn't look like a stalled orchestrator. Exits once the final summary has started, or
# launches the final summary if the run stopped and LOG.md goes silent without one.
#   nohup setsid <run_dir>/tools/watchdog.sh >/dev/null 2>&1 </dev/null &
source "$(dirname "$0")/common.sh"
echo "$$ watchdog" >> "$TOOLS/timer.pids"
log "watchdog: pid $$, relaunches after $WATCHDOG_MIN silent minutes"
prev=$(date +%s)
while sleep 60; do
  if [[ -d $RUN_DIR/.summary_started ]]; then
    log "watchdog: run over, exiting"
    exit 0
  fi
  now=$(date +%s)
  if (( now - prev > 300 )); then
    log "watchdog: clock jumped $(( (now - prev) / 60 )) min (machine asleep?), waiting $WATCHDOG_MIN min before judging silence"
  fi
  prev=$now
  log_mtime=$(mtime "$LOG" 2>/dev/null) || continue
  [[ $log_mtime =~ ^[0-9]+$ ]] || continue
  age=$(( (now - log_mtime) / 60 ))
  (( age < WATCHDOG_MIN )) && continue
  if grep -q " run stopped$" "$LOG" 2>/dev/null; then
    log "watchdog: run stopped and LOG.md silent for $age min without summary, launching final summary"
    "$TOOLS/launch_summary.sh" >/dev/null || log "watchdog: summary launch failed"
    exit 0
  fi
  last=$(grep -oE "^- [0-9-]+ [0-9:]+ launch orchestrator [0-9]+ " "$LOG" 2>/dev/null | awk '{print $6}' | sort -n | tail -1)
  log "watchdog: LOG.md silent for $age min, last orchestrator ${last:-none}, launching the next"
  "$TOOLS/launch_orchestrator.sh" $(( ${last:-0} + 1 )) recovery >/dev/null || log "watchdog: relaunch failed"
done
