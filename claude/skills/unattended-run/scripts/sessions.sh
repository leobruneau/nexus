#!/bin/bash
# List this run's Claude sessions ("<TAG> | ...") with their state, then print a `claude stop` line for
# each non-FS session still listed, for the user to paste. In auto mode the permission classifier refused
# `claude stop` from inside a run every time, so stopping sessions is the user's step.
#   <run_dir>/tools/sessions.sh
source "$(dirname "$0")/common.sh"

jq_bin=""
for cand in "${NEXUS_DATA_DIR:-$HOME/.local/share/nexus}/bin/jq" "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/bin/jq"; do
  if [[ -x "$cand" ]]; then
    jq_bin="$cand"
    break
  fi
done
[[ -n $jq_bin ]] || jq_bin="$(command -v jq 2>/dev/null || true)"

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
