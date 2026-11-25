#!/bin/bash
# Start the run's detached processes: the watchdog, and the STOP_AT and SUMMARY_AT timers when run.env
# sets them. Each runs under nohup and setsid, outside any Claude session, and logs its PID in LOG.md.
# On macOS it also starts caffeinate for as long as the watchdog lives, so the machine doesn't idle-sleep.
# Closing the lid still sleeps it.
#   <run_dir>/tools/start_timers.sh
# Skips watchdog, timers, and caffeinate if timer.pids lists one that is still alive.
source "$(dirname "$0")/common.sh"
start() { nohup setsid "$@" >/dev/null 2>&1 </dev/null & }

alive_for() {
  local want_role=$1 want_suffix=${2:-} pid role rest
  [[ -f $TOOLS/timer.pids ]] || return 1
  while read -r pid role rest; do
    [[ $pid =~ ^[0-9]+$ && $role == "$want_role" ]] || continue
    [[ -z $want_suffix || $rest == *"$want_suffix" ]] || continue
    if kill -0 "$pid" 2>/dev/null; then
      echo "$pid"
      return 0
    fi
  done < "$TOOLS/timer.pids"
  return 1
}

wait_for_alive() {
  local role=$1 suffix=${2:-} pid i
  for (( i = 0; i < 25; i++ )); do
    if pid=$(alive_for "$role" "$suffix"); then
      echo "$pid"
      return 0
    fi
    sleep 0.2
  done
  return 1
}

if wd=$(alive_for watchdog); then
  echo "watchdog already running: $wd"
else
  start "$TOOLS/watchdog.sh"
  wd=$(wait_for_alive watchdog || true)
fi

run_at_logs_before=$(grep -c " run_at:" "$LOG" 2>/dev/null || true)
need_stop_wait=0
need_summary_wait=0

if [[ -n ${STOP_AT:-} ]]; then
  if p=$(alive_for run_at "$TOOLS/stop_work.sh"); then
    echo "stop_work timer already running: $p"
  else
    start "$TOOLS/run_at.sh" "$STOP_AT" "$TOOLS/stop_work.sh"
    need_stop_wait=1
  fi
fi

if [[ -n ${SUMMARY_AT:-} ]]; then
  if p=$(alive_for run_at "$TOOLS/launch_summary.sh"); then
    echo "launch_summary timer already running: $p"
  else
    start "$TOOLS/run_at.sh" "$SUMMARY_AT" "$TOOLS/launch_summary.sh"
    need_summary_wait=1
  fi
fi

if (( need_stop_wait || need_summary_wait )); then
  for (( i = 0; i < 10; i++ )); do
    ok=1
    if (( need_stop_wait )) && ! alive_for run_at "$TOOLS/stop_work.sh" >/dev/null; then ok=0; fi
    if (( need_summary_wait )) && ! alive_for run_at "$TOOLS/launch_summary.sh" >/dev/null; then ok=0; fi
    (( ok )) && break
    run_at_logs_now=$(grep -c " run_at:" "$LOG" 2>/dev/null || true)
    (( run_at_logs_now > run_at_logs_before )) && break
    sleep 0.2
  done
fi

if command -v caffeinate >/dev/null && [[ -n ${wd:-} ]]; then
  if c=$(alive_for caffeinate); then
    echo "caffeinate already running: $c"
  else
    start sh -c 'echo "$$ caffeinate" >> "$1"; exec caffeinate -ims -w "$2"' _ "$TOOLS/timer.pids" "$wd"
    wait_for_alive caffeinate >/dev/null || true
    log "start_timers: caffeinate keeps the machine awake while watchdog pid $wd runs"
  fi
fi

echo "processes in timer.pids:"
if [[ -f $TOOLS/timer.pids ]]; then
  while read -r pid what _; do
    if kill -0 "$pid" 2>/dev/null; then echo "  $pid $what alive"; else echo "  $pid $what not running"; fi
  done < "$TOOLS/timer.pids"
else
  echo "  (none)"
fi
