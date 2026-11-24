#!/usr/bin/env bash
# SessionStart hook for Claude Code and Antigravity CLI.
# If a handoff is pending for this project, rename it to .md.done (and mark any
# older stale .md files .done so they do not leak) and point the fresh session
# at the newest handoff file.
set -uo pipefail

exec python3 -c '
import json
import os
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse

raw = "" if sys.stdin.isatty() else sys.stdin.read().strip()
payload = {}
if raw:
    try:
        parsed = json.loads(raw)
        if isinstance(parsed, dict):
            payload = parsed
    except json.JSONDecodeError:
        payload = {}

is_agy = "conversationId" in payload or "workspacePaths" in payload
cwd = payload.get("cwd")
if not cwd:
    ws = payload.get("workspacePaths") or []
    if isinstance(ws, list) and ws:
        cwd = ws[0]
if not cwd:
    cwd = os.getcwd()

if isinstance(cwd, str) and cwd.startswith("file://"):
    cwd = unquote(urlparse(cwd).path)
if isinstance(cwd, str) and len(cwd) > 1:
    cwd = cwd.rstrip("/")

slug = cwd.replace("/", "-")
shared_root = Path(os.environ.get("NEXUS_HANDOFF_DIR") or (Path.home() / ".local" / "share" / "nexus" / "handoffs"))
claude_root = Path(os.environ.get("CLAUDE_CONFIG_DIR") or (Path.home() / ".claude")) / "handoffs"

candidates = []
for root in (shared_root, claude_root):
    d = root / slug
    if d.is_dir():
        md_files = [p for p in d.glob("*.md") if p.is_file()]
        if md_files:
            candidates = md_files
            break

if not candidates:
    if is_agy:
        print("{}")
    sys.exit(0)

candidates.sort(key=lambda p: p.stat().st_mtime, reverse=True)
newest = candidates[0]
newest_done = newest.with_name(newest.name + ".done")

try:
    os.replace(newest, newest_done)
except OSError:
    if is_agy:
        print("{}")
    sys.exit(0)

for stale in candidates[1:]:
    try:
        os.replace(stale, stale.with_name(stale.name + ".done"))
    except OSError:
        pass

msg = (
    "A handoff was left for you by the previous session.\n"
    "Before doing anything else, read it IN FULL:\n\n"
    f"    {newest_done}\n\n"
    "Treat it as the current task state and continue from its \"Next action\"."
)

if is_agy:
    print(json.dumps({
        "injectSteps": [{
            "systemMessage": {
                "systemMessage": msg,
            }
        }]
    }))
else:
    print(msg)
'
