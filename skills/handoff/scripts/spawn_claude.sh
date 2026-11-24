#!/usr/bin/env bash
# Claim a handoff file (.md -> .md.done) and spawn a fresh background Claude Code
# continuation session (`claude --bg`) pointing at it.
#
# Usage:
#   spawn_claude.sh <handoff-file> [--cwd <dir>] [--tag <tag>] [--gen <N>]
#                   [--max <N>] [--model <model>] [--permission-mode <mode>]
#                   [--dry-run] [--help]
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: spawn_claude.sh <handoff-file> [options]

Options:
  --cwd <dir>               Working directory for the new session (default: pwd)
  --tag <tag>               Chain tag for session naming (lowercase, digits, hyphens)
  --gen <N>                 Generation number (positive integer, default: 1 or inherited)
  --max <N>                 Maximum chain generations (default: HANDOFF_MAX_GEN or 5)
  --model <model>           Model override (default: HANDOFF_MODEL or Claude default)
  --permission-mode <mode>  Permission mode (default: HANDOFF_PERMISSION_MODE or auto)
  --dry-run                 Print the planned claim and command without running claude
  --help                    Show this help
EOF
}

handoff_arg=""
cwd_arg=""
tag=""
gen=""
max="${HANDOFF_MAX_GEN:-5}"
model="${HANDOFF_MODEL:-}"
permission_mode="${HANDOFF_PERMISSION_MODE:-auto}"
dry_run=0
tag_set=0
gen_set=0
max_set=0

while (( $# > 0 )); do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --cwd)
      [[ $# -ge 2 ]] || { echo "spawn_claude: --cwd requires an argument" >&2; exit 2; }
      cwd_arg="$2"
      shift 2
      ;;
    --tag)
      [[ $# -ge 2 ]] || { echo "spawn_claude: --tag requires an argument" >&2; exit 2; }
      tag="$2"
      tag_set=1
      shift 2
      ;;
    --gen)
      [[ $# -ge 2 ]] || { echo "spawn_claude: --gen requires an argument" >&2; exit 2; }
      gen="$2"
      gen_set=1
      shift 2
      ;;
    --max)
      [[ $# -ge 2 ]] || { echo "spawn_claude: --max requires an argument" >&2; exit 2; }
      max="$2"
      max_set=1
      shift 2
      ;;
    --model)
      [[ $# -ge 2 ]] || { echo "spawn_claude: --model requires an argument" >&2; exit 2; }
      model="$2"
      shift 2
      ;;
    --permission-mode)
      [[ $# -ge 2 ]] || { echo "spawn_claude: --permission-mode requires an argument" >&2; exit 2; }
      permission_mode="$2"
      shift 2
      ;;
    -*)
      echo "spawn_claude: unknown option '$1'" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [[ -n "$handoff_arg" ]]; then
        echo "spawn_claude: unexpected positional argument '$1'" >&2
        usage >&2
        exit 2
      fi
      handoff_arg="$1"
      shift
      ;;
  esac
done

if [[ -z "$handoff_arg" ]]; then
  echo "spawn_claude: missing <handoff-file>" >&2
  usage >&2
  exit 2
fi

case "$handoff_arg" in
  *.md.done)
    echo "spawn_claude: handoff '$handoff_arg' was already claimed (.md.done)" >&2
    exit 2
    ;;
  *.md)
    ;;
  *)
    echo "spawn_claude: handoff file must end in .md (got '$handoff_arg')" >&2
    usage >&2
    exit 2
    ;;
esac

if [[ ! -f "$handoff_arg" ]]; then
  echo "spawn_claude: handoff file not found: $handoff_arg" >&2
  exit 2
fi

handoff="$(cd "$(dirname "$handoff_arg")" && pwd)/$(basename "$handoff_arg")"

if [[ -z "$cwd_arg" ]]; then
  cwd="$(pwd)"
else
  if [[ ! -d "$cwd_arg" ]]; then
    echo "spawn_claude: --cwd directory does not exist: $cwd_arg" >&2
    exit 2
  fi
  cwd="$(cd "$cwd_arg" && pwd)"
fi

if (( gen_set )) && ! [[ "$gen" =~ ^[1-9][0-9]*$ ]]; then
  echo "spawn_claude: --gen must be a positive integer (got '$gen')" >&2
  exit 2
fi

if ! [[ "$max" =~ ^[1-9][0-9]*$ ]]; then
  echo "spawn_claude: --max must be a positive integer (got '$max')" >&2
  exit 2
fi

if ! [[ "$permission_mode" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "spawn_claude: invalid --permission-mode '$permission_mode'" >&2
  exit 2
fi

if [[ -n "$model" ]] && ! [[ "$model" =~ ^[A-Za-z0-9._:/-]+$ ]]; then
  echo "spawn_claude: invalid --model '$model'" >&2
  exit 2
fi

if (( tag_set )) && ! [[ "$tag" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "spawn_claude: --tag must match ^[a-z0-9][a-z0-9-]*$ (got '$tag')" >&2
  exit 2
fi

claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
state_dir="$claude_dir/state/handoff-spawn"
chain_dir="$state_dir/chain"
spawned_dir="$state_dir/spawned"

caller_sid="${CLAUDE_CODE_SESSION_ID:-}"
if [[ -n "$caller_sid" ]] && ! [[ "$caller_sid" =~ ^[A-Za-z0-9._-]+$ ]]; then
  caller_sid=""
fi

read_chain_file() {
  local f="$1" k v
  prev_tag=""
  prev_gen=""
  prev_max=""
  while IFS='=' read -r k v; do
    case "$k" in
      TAG) prev_tag="$v" ;;
      GEN) prev_gen="$v" ;;
      MAX) prev_max="$v" ;;
    esac
  done < "$f"
}

if [[ -n "$caller_sid" ]]; then
  caller_short="$(printf '%s' "${caller_sid:0:8}" | tr '[:upper:]' '[:lower:]')"
  chain_file=""
  if [[ -f "$chain_dir/$caller_sid" ]]; then
    chain_file="$chain_dir/$caller_sid"
  elif [[ -f "$chain_dir/$caller_short" ]]; then
    chain_file="$chain_dir/$caller_short"
  fi
  if [[ -n "$chain_file" ]]; then
    read_chain_file "$chain_file"
    if (( ! tag_set )) && [[ "$prev_tag" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
      tag="$prev_tag"
    fi
    if (( ! gen_set )) && [[ "$prev_gen" =~ ^[1-9][0-9]*$ ]]; then
      gen=$((prev_gen + 1))
    fi
    if (( ! max_set )) && [[ "$prev_max" =~ ^[1-9][0-9]*$ ]]; then
      max="$prev_max"
    fi
  fi
fi

if [[ -z "$gen" ]]; then
  gen=1
fi

if [[ -z "$tag" ]]; then
  base="$(basename "$handoff" .md)"
  stripped="$(printf '%s' "$base" | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4,6}-//')"
  tag="$(printf '%s' "$stripped" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  tag="$(printf '%s' "${tag:0:40}" | sed -E 's/-+$//')"
  if [[ -z "$tag" ]]; then
    tag="handoff"
  fi
fi

# Guard 1: one auto-spawn per session.
if [[ -n "$caller_sid" ]] && (( ! dry_run )) && [[ -f "$spawned_dir/$caller_sid" ]]; then
  echo "spawn_claude: session '$caller_sid' already spawned a continuation:" >&2
  cat "$spawned_dir/$caller_sid" >&2
  exit 4
fi

# Guard 2: chain cap backstop.
if (( gen > max )); then
  {
    echo "spawn_claude: chain limit $max reached (next generation would be H$gen)."
    echo "Handoff left untouched at: $handoff"
    echo "Resume manually with:"
    echo "  claude \"\$(cat '$handoff')\""
    echo "Or run /clear in a session with the SessionStart hook installed."
  } >&2
  exit 3
fi

# Guard 3: claude CLI availability.
if (( ! dry_run )) && ! command -v claude >/dev/null 2>&1; then
  {
    echo "spawn_claude: 'claude' command not found on PATH."
    echo "Handoff left untouched at: $handoff"
    echo "Resume manually in a terminal with:"
    echo "  claude \"\$(cat '$handoff')\""
  } >&2
  exit 1
fi

session_name="${tag} | H${gen}"
done_path="${handoff}.done"
caller_label="${caller_sid:-manual}"
next_gen=$((gen + 1))

skill_dir="${CLAUDE_CONFIG_DIR:-~/.claude}/skills/handoff"
script_path="${skill_dir}/scripts/spawn_claude.sh"

prompt="You are continuation session H${gen} of \"${tag}\" (handoff ${gen} of ${max}, predecessor ${caller_label}).
Before doing anything else, read this handoff file IN FULL:

    ${done_path}

Treat it as the current task state and continue autonomously from its \"Next action\".
If you reach 150k context with remaining autonomous work, follow ${skill_dir}/SKILL.md and spawn the next continuation with:
    ${script_path} <new-handoff-path> --tag ${tag} --gen ${next_gen} --max ${max}
Stop and report cleanly to the user when the task is complete, when a step requires a user decision or missing credential, or if the handoff chain limit is reached."

if (( dry_run )); then
  echo "dry_run: true"
  echo "session_name: $session_name"
  echo "cwd: $cwd"
  echo "handoff_claim: $done_path"
  echo "generation: $gen/$max"
  echo "permission_mode: $permission_mode"
  echo "model: ${model:-(default)}"
  if [[ -n "$model" ]]; then
    echo "command: claude --bg -n \"$session_name\" --permission-mode \"$permission_mode\" --model \"$model\" <prompt>"
  else
    echo "command: claude --bg -n \"$session_name\" --permission-mode \"$permission_mode\" <prompt>"
  fi
  exit 0
fi

lock="${handoff}.lock"
acquired=0
for attempt in 1 2 3 4 5 6 7 8 9 10; do
  if mkdir "$lock" 2>/dev/null; then
    acquired=1
    break
  fi
  if [[ -f "$lock/pid" ]]; then
    read -r holder < "$lock/pid" 2>/dev/null || holder=""
    if [[ "$holder" =~ ^[0-9]+$ ]] && ! kill -0 "$holder" 2>/dev/null; then
      rm -f "$lock/pid" 2>/dev/null || true
      rmdir "$lock" 2>/dev/null || true
      continue
    fi
  fi
  sleep 1
done

if (( ! acquired )); then
  echo "spawn_claude: timed out waiting for lock $lock" >&2
  exit 1
fi

cleanup_lock() {
  rm -f "$lock/pid" 2>/dev/null || true
  rmdir "$lock" 2>/dev/null || true
}
trap cleanup_lock EXIT
printf '%s\n' "$$" > "$lock/pid"

if [[ -e "$done_path" ]]; then
  echo "spawn_claude: target claim path already exists: $done_path" >&2
  exit 2
fi

mv "$handoff" "$done_path"

cmd=(claude --bg -n "$session_name" --permission-mode "$permission_mode")
if [[ -n "$model" ]]; then
  cmd+=(--model "$model")
fi
cmd+=("$prompt")

set +e
out="$(cd "$cwd" && "${cmd[@]}" 2>&1)"
rc=$?
set -e

id="$(printf '%s\n' "$out" | grep -oE '[0-9a-f]{8}' | head -1 || true)"

if (( rc != 0 )) || [[ -z "$id" ]]; then
  if [[ -f "$done_path" && ! -e "$handoff" ]]; then
    mv "$done_path" "$handoff"
  fi
  {
    echo "spawn_claude: launch failed (exit $rc): $(printf '%s\n' "$out" | tail -1)"
    echo "Handoff restored to: $handoff"
    echo "Resume manually with:"
    echo "  claude \"\$(cat '$handoff')\""
  } >&2
  exit 1
fi

mkdir -p "$chain_dir" "$spawned_dir"
find "$chain_dir" -type f -mtime +14 -delete 2>/dev/null || true
find "$spawned_dir" -type f -mtime +14 -delete 2>/dev/null || true

write_state_atomic() {
  local dest="$1" content="$2" tmp
  tmp="$(mktemp "${dest}.tmp.XXXXXX")"
  printf '%s' "$content" > "$tmp"
  mv -f "$tmp" "$dest"
}

write_state_atomic "$chain_dir/$id" "TAG=${tag}
GEN=${gen}
MAX=${max}
PARENT=${caller_label}
HANDOFF=${done_path}
"

if [[ -n "$caller_sid" ]]; then
  write_state_atomic "$spawned_dir/$caller_sid" "CHILD_ID=${id}
SESSION_NAME=${session_name}
HANDOFF=${done_path}
"
fi

cat <<EOF
session_id: $id
session_name: $session_name
handoff: $done_path
generation: $gen/$max
attach: claude attach $id
list: claude agents
stop: claude stop $id
EOF
