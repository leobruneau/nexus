#!/bin/bash
# List this run's sessions ("<TAG> | ...") with their state, then print stop/close lines for each
# non-FS session or tab still open, for the user to paste.
#   <run_dir>/tools/sessions.sh
source "$(dirname "$0")/common.sh"

jq_bin="$(find_jq || true)"

if [[ ${HARNESS:-claude} == "agy" ]]; then
  if [[ ! -f "$TOOLS/rex.session" || ! -f "$TOOLS/rex.sessions.tsv" ]]; then
    echo "no $TAG | sessions listed"
    exit 0
  fi
  read -r sid < "$TOOLS/rex.session" || sid=""
  inspect_json="$(rex session inspect "$sid" --json 2>/dev/null || true)"
  if [[ -z $sid || -z $inspect_json ]]; then
    echo "no $TAG | sessions listed"
    exit 0
  fi

  live_wids=""
  if [[ -n $jq_bin ]]; then
    live_wids="$(printf '%s' "$inspect_json" | "$jq_bin" -r '.windows[]?.window_id // empty' 2>/dev/null || true)"
  else
    live_wids="$(printf '%s\n' "$inspect_json" | sed -n 's/^ *"window_id": *"\(.*\)",\{0,1\}$/\1/p')"
  fi

  listed=0
  close_cmds=()
  while IFS=$'\t' read -r name row_sid wid bid; do
    [[ -n $name && $row_sid == "$sid" ]] || continue
    printf '%s\n' "$live_wids" | grep -qxF -- "$wid" || continue
    listed=1
    state="open"
    proc_json="$(rex block call -s "$sid" -b "$bid" process 2>/dev/null || true)"
    if [[ -n $proc_json ]]; then
      if [[ -n $jq_bin ]]; then
        running="$(printf '%s' "$proc_json" | "$jq_bin" -r 'if .running == true then "running" elif .running == false then "exited" else "open" end' 2>/dev/null || echo "open")"
      else
        running="open"
        printf '%s' "$proc_json" | grep -q '"running": *true' && running="running"
        printf '%s' "$proc_json" | grep -q '"running": *false' && running="exited"
      fi
      state="$running"
    fi
    printf '%s\t%s\t%s\n' "$bid" "$name" "$state"
    [[ $name == "$TAG | FS" ]] || close_cmds+=("rex window close -s $sid $wid")
  done < "$TOOLS/rex.sessions.tsv"

  if (( ! listed )); then
    echo "no $TAG | sessions listed"
    exit 0
  fi
  for cmd in "${close_cmds[@]}"; do
    printf '%s\n' "$cmd"
  done
  printf '# or close the whole run session: rex kill %s\n' "$sid"
  exit 0
fi

raw="$(claude agents --json </dev/null 2>/dev/null || true)"
if [[ -z $raw ]]; then
  echo "no $TAG | sessions listed"
  exit 0
fi

if [[ -n $jq_bin ]]; then
  "$jq_bin" -r --arg tag "$TAG | " --arg fs "$TAG | FS" '
    def items: if type == "array" then . else (.agents // .sessions // []) end;
    [items[] | select((.name // "") | startswith($tag))] as $all
    | if ($all | length) == 0 then
        "no " + $tag + "sessions listed"
      else
        ($all[] | "\(.id)\t\(.name)\t\(.state // "")"),
        ($all[] | select(.name != $fs) | "! claude stop \(.id)")
      end
  ' <<<"$raw"
else
  printf '%s\n' "$raw" | awk -v tag="$TAG | " -v fs="$TAG | FS" '
    /"id":/    { id = $0;    sub(/^ *"id": *"/, "", id);       sub(/".*/, "", id) }
    /"name":/  { name = $0;  sub(/^ *"name": *"/, "", name);   sub(/",? *$/, "", name) }
    /"state":/ { state = $0; sub(/^ *"state": *"/, "", state); sub(/".*/, "", state) }
    /^ *}/     { if (index(name, tag) == 1) {
                   print id "\t" name "\t" state
                   if (name != fs) ids = ids " " id
                 }
                 id = name = state = "" }
    END        { if (ids == "") print "no " tag "sessions listed"
                 else { n = split(ids, a, " "); for (i = 1; i <= n; i++) print "! claude stop " a[i] } }'
fi
