#!/usr/bin/env bash
# PostToolUse and UserPromptSubmit hook. Tells the agent when its context passes 100k, 125k and 150k
# tokens. Each threshold fires once per session. If the context shrinks (after /compact), the
# thresholds above the new size fire again when the context grows back.
# The logic runs in python3, which reads the hook input from this script's stdin.
code="$(cat <<'PY'
import json, os, sys, time

THRESHOLDS = {
    100000: "100k context window reached.",
    125000: "125k context window reached. Please start thinking about handing off the task.",
    150000: "150k context window reached. Please hand off the task ASAP.",
}


def tail(path, n):
    """Return the last n lines of a file without reading all of it."""
    with open(path, "rb") as f:
        end = f.seek(0, os.SEEK_END)
        data = b""
        while end > 0 and data.count(b"\n") <= n:
            step = min(65536, end)
            end -= step
            f.seek(end)
            data = f.read(step) + data
    return data.splitlines()[-n:]


def context_tokens(transcript):
    """Tokens the model read on the last main-thread turn plus what it wrote, or None."""
    for line in reversed(tail(transcript, 500)):
        try:
            record = json.loads(line)
        except ValueError:
            continue  # a line Claude Code is still writing
        usage = (record.get("message") or {}).get("usage")
        if record.get("type") == "assistant" and not record.get("isSidechain") and usage:
            keys = ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens", "output_tokens")
            return sum(usage.get(k) or 0 for k in keys)
    return None


def state_dir():
    base = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.join(os.environ["HOME"], ".claude")
    path = os.path.join(base, "state", "context-alert")
    os.makedirs(path, exist_ok=True)
    return path


def forget_old_sessions(folder, days=14):
    cutoff = time.time() - days * 86400
    for name in os.listdir(folder):
        path = os.path.join(folder, name)
        try:
            if os.path.isfile(path) and os.path.getmtime(path) < cutoff:
                os.remove(path)
        except OSError:
            pass


def swap_level(state, level):
    """Store the session's new level and return the one stored before it."""
    try:
        with open(state) as f:
            last = int(f.read().strip())
    except (OSError, ValueError):
        last = 0
    with open(state, "w") as f:
        f.write(f"{level}\n")
    return last


def alert(event, msg):
    output = {"hookSpecificOutput": {"hookEventName": event, "additionalContext": msg}, "systemMessage": msg}
    print(json.dumps(output))


try:
    hook = json.load(sys.stdin)
except ValueError:
    sys.exit(0)
session = hook.get("session_id")
transcript = hook.get("transcript_path") or ""
if not session or not os.path.isfile(transcript):
    sys.exit(0)

tokens = context_tokens(transcript)
if tokens is None:
    sys.exit(0)
level = max([t for t in THRESHOLDS if tokens >= t], default=0)

folder = state_dir()
forget_old_sessions(folder)
if level > swap_level(os.path.join(folder, session), level):
    alert(hook.get("hook_event_name") or "", THRESHOLDS[level])
PY
)"
exec python3 -I -c "$code"
