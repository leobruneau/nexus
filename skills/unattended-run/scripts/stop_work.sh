#!/bin/bash
# Stop the run's background work: kill each process group listed in tools/work.pids, run CANCEL_CMD from
# run.env if set, then log "run stopped". Safe to run more than once.
source "$(dirname "$0")/common.sh"
signaled=()
if [[ -f $TOOLS/work.pids ]]; then
  while read -r pid _; do
    [[ $pid =~ ^[0-9]+$ ]] || continue
    if kill -0 -- "-$pid" 2>/dev/null; then
      kill -TERM -- "-$pid" 2>/dev/null
      log "stop_work: stopped pid $pid"
      signaled+=("$pid")
    fi
  done < "$TOOLS/work.pids"
fi
if (( ${#signaled[@]} > 0 )); then
  for (( i = 0; i < 10; i++ )); do
    alive=0
    for p in "${signaled[@]}"; do
      if kill -0 -- "-$p" 2>/dev/null; then
        alive=1
        break
      fi
    done
    (( alive )) || break
    sleep 0.5
  done
  for p in "${signaled[@]}"; do
    if kill -0 -- "-$p" 2>/dev/null; then
      kill -KILL -- "-$p" 2>/dev/null
      log "stop_work: force-killed pid $p"
    fi
  done
fi
if [[ -n ${CANCEL_CMD:-} ]]; then
  (cd "$WORKSPACE" && bash -c "$CANCEL_CMD")
  rc=$?
  log "stop_work: ran '$CANCEL_CMD' (exit $rc)"
fi
log "run stopped"
