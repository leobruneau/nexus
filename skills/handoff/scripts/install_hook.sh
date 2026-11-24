#!/usr/bin/env bash
# Register resume_hook.sh as a SessionStart hook for Claude Code and/or Antigravity CLI.
# Usage: install_hook.sh [--claude | --antigravity | --all]
# Idempotent: re-running does not duplicate the entry. Backs up existing configs first.
set -euo pipefail

target="all"
case "${1:-}" in
  ""|--all) target="all" ;;
  --claude) target="claude" ;;
  --antigravity) target="antigravity" ;;
  *) echo "Usage: $0 [--claude | --antigravity | --all]" >&2; exit 2 ;;
esac

hook_raw="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/resume_hook.sh"
chmod +x "$hook_raw"

python3 - "$hook_raw" "$target" <<'PY'
import json
import os
import shlex
import shutil
import sys
import tempfile

hook_real = os.path.realpath(sys.argv[1])
target = sys.argv[2]
cmd = f"bash {shlex.quote(hook_real)}"

claude_dir = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.join(os.path.expanduser("~"), ".claude")
agy_dir = os.environ.get("ANTIGRAVITY_CONFIG_DIR") or os.path.join(os.path.expanduser("~"), ".gemini", "config")


def atomic_write_json(path, data):
    parent = os.path.dirname(path)
    os.makedirs(parent, exist_ok=True)
    if os.path.exists(path):
        shutil.copy2(path, path + ".bak")
    fd, tmp = tempfile.mkstemp(prefix=".tmp.", dir=parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
        os.replace(tmp, path)
    except Exception:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def is_handoff_cmd(command_str):
    if not isinstance(command_str, str):
        return False
    return command_str == cmd or "/handoff/scripts/resume_hook.sh" in command_str


def install_claude():
    settings = os.path.join(claude_dir, "settings.json")
    cfg = {}
    if os.path.exists(settings):
        with open(settings, encoding="utf-8") as f:
            cfg = json.load(f)
    entries = cfg.setdefault("hooks", {}).setdefault("SessionStart", [])
    for e in entries:
        for h in e.get("hooks", []):
            if is_handoff_cmd(h.get("command")):
                if h.get("command") == cmd:
                    print(f"already installed in {settings}")
                    return
                h["command"] = cmd
                atomic_write_json(settings, cfg)
                print(f"updated SessionStart hook in {settings}")
                return
    entries.append({
        "matcher": "startup|clear",
        "hooks": [{"type": "command", "command": cmd}],
    })
    atomic_write_json(settings, cfg)
    print(f"installed SessionStart hook in {settings}")


def install_antigravity():
    hooks_path = os.path.join(agy_dir, "hooks.json")
    cfg = {}
    if os.path.exists(hooks_path):
        with open(hooks_path, encoding="utf-8") as f:
            cfg = json.load(f)
    desired = {
        "SessionStart": [
            {"type": "command", "command": cmd, "timeout": 10}
        ]
    }
    if cfg.get("handoff-resume") == desired:
        print(f"already installed in {hooks_path}")
        return
    cfg["handoff-resume"] = desired
    atomic_write_json(hooks_path, cfg)
    print(f"installed SessionStart hook in {hooks_path}")


if target == "claude":
    install_claude()
elif target == "antigravity":
    install_antigravity()
else:
    ran = False
    if os.path.isdir(claude_dir):
        install_claude()
        ran = True
    if os.path.isdir(agy_dir):
        install_antigravity()
        ran = True
    if not ran:
        install_claude()
        install_antigravity()
PY
