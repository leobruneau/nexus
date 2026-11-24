#!/usr/bin/env python3
"""Extract a compact digest of Claude Code and Antigravity CLI work from stored history.

Claude Code stores one JSONL transcript per session under
~/.claude/projects/<encoded-cwd>/<session>.jsonl.
Antigravity CLI stores one JSONL transcript per conversation under
~/.gemini/antigravity-cli/brain/<conversation-id>/.system_generated/logs/transcript.jsonl.

Usage:
  extract.py --list                       # list projects + date ranges, then exit
  extract.py --since 2026-06-01            # all projects since a date
  extract.py --days 7                      # all projects, last N days
  extract.py --source antigravity --days 7 # only Antigravity CLI sessions
  extract.py --since 2026-06-01 --project my-project
  extract.py --since 2026-06-01 --until 2026-06-15 --project foo --project bar

Time bounds are inclusive dates (YYYY-MM-DD), compared in UTC. --project
matches if the substring appears in the project's cwd (repeatable).
"""
import argparse
from collections import Counter
import datetime as dt
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse

MAX_TEXT = 400
MUTATING = {
    "Edit",
    "Write",
    "NotebookEdit",
    "MultiEdit",
    "edit_file",
    "write_file",
    "replace_file_content",
    "multi_replace_file_content",
    "write_to_file",
}
SHELL_TOOLS = {"Bash", "run_command"}
PATH_KEYS = ("file_path", "path", "notebook_path", "Path", "TargetFile")
CMD_KEYS = ("command", "CommandLine")


def claude_projects_dir():
    base = Path(os.environ.get("CLAUDE_CONFIG_DIR") or (Path.home() / ".claude"))
    return base / "projects"


def antigravity_brain_dir():
    base = Path(os.environ.get("ANTIGRAVITY_APP_DATA_DIR") or (Path.home() / ".gemini" / "antigravity-cli"))
    return base / "brain"


def parse_ts(s):
    if not s:
        return None
    try:
        parsed = dt.datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed


def parse_date_arg(s, flag):
    try:
        return dt.date.fromisoformat(s)
    except ValueError:
        print(f"extract.py: invalid {flag} date '{s}' (expected YYYY-MM-DD)", file=sys.stderr)
        sys.exit(2)


def is_git_repo(cwd):
    if not cwd or cwd == "(unknown)":
        return False
    try:
        p = Path(cwd)
        if not p.exists():
            return False
        for cand in (p, *p.parents):
            if (cand / ".git").exists():
                return True
    except OSError:
        return False
    return False


def nearest_project_root(path_str):
    try:
        p = Path(path_str)
        if not p.is_absolute():
            return None
        s = str(p)
        if "/.gemini/" in s or s.startswith("/tmp/") or s.startswith("/var/folders/"):
            return None
        start = p if p.is_dir() else p.parent
        for cand in (start, *start.parents):
            if cand == Path("/"):
                break
            if (cand / ".git").exists():
                return str(cand)
        if start.exists():
            return str(start)
    except OSError:
        return None
    return None


def text_from_content(content):
    """User/assistant content is a string or a list of blocks. Pull plain text."""
    if isinstance(content, str):
        return content.strip()
    if not isinstance(content, list):
        return ""
    out = []
    for b in content:
        if isinstance(b, dict) and b.get("type") == "text":
            out.append(str(b.get("text", "")).strip())
    return "\n".join(t for t in out if t).strip()


def unwrap_arg_val(val):
    if isinstance(val, str) and len(val) >= 2 and val[0] == '"' and val[-1] == '"':
        try:
            decoded = json.loads(val)
            if isinstance(decoded, str):
                return decoded
        except json.JSONDecodeError:
            pass
    return val


def tool_summary_from_dict(name, inp):
    if not isinstance(inp, dict):
        return name, ""
    for key in PATH_KEYS:
        if key in inp:
            return name, str(unwrap_arg_val(inp[key]))
    for key in CMD_KEYS:
        if key in inp:
            return name, str(unwrap_arg_val(inp[key])).replace("\n", " ")[:160]
    for key in ("pattern", "query"):
        if key in inp:
            return name, f"/{unwrap_arg_val(inp[key])}/"
    if "description" in inp:
        return name, str(unwrap_arg_val(inp["description"]))
    return name, ""


def tool_summary(block):
    """(name, detail) for a Claude tool_use block."""
    return tool_summary_from_dict(block.get("name", "tool"), block.get("input", {}) or {})


def clip(s, n=MAX_TEXT):
    s = " ".join(s.split())
    return s if len(s) <= n else s[:n] + " ..."


def is_noise(txt):
    """Skip injected/meta user content that isn't a real human prompt."""
    if not txt:
        return True
    head = txt.lstrip()[:64].lower()
    return head.startswith((
        "<system-reminder",
        "<command-name",
        "caveat:",
        "<local-command",
        "<bash-input",
        "<bash-stdout",
        "<bash-stderr",
        "<task-notification",
        "<teammate-message",
        "[request interrupted",
        "this session is being continued from a previous conversation",
    ))


def scan_claude_session(path, seen):
    """Read one Claude Code transcript. Return dict of metadata + ordered events, or None."""
    cwd = None
    branches = set()
    title = None
    first_ts = last_ts = None
    events = []
    pending_tools = []

    try:
        fh = open(path, encoding="utf-8")
    except OSError:
        return None
    with fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
            except json.JSONDecodeError:
                continue
            if d.get("cwd") and not cwd:
                cwd = d["cwd"]
            if d.get("gitBranch"):
                branches.add(d["gitBranch"])
            t = d.get("type")
            if t == "ai-title" and not title:
                title = d.get("aiTitle") or d.get("title") or d.get("leafTitle")
            elif t == "custom-title" and not title:
                title = d.get("customTitle") or d.get("title")
            elif t == "summary" and not title:
                title = d.get("summary")

            u = d.get("uuid")
            if u:
                if u in seen:
                    continue
                seen.add(u)

            ts = parse_ts(d.get("timestamp"))
            if ts:
                first_ts = ts if first_ts is None or ts < first_ts else first_ts
                last_ts = ts if last_ts is None or ts > last_ts else last_ts
            if d.get("isSidechain") or d.get("isMeta"):
                continue
            msg = d.get("message")
            if not isinstance(msg, dict):
                continue
            role = msg.get("role")
            content = msg.get("content")
            if role == "user":
                txt = text_from_content(content)
                if not is_noise(txt):
                    events.append((ts, "prompt", clip(txt)))
            elif role == "assistant":
                said = text_from_content(content)
                if said:
                    events.append((ts, "said", clip(said)))
                if isinstance(content, list):
                    for b in content:
                        if isinstance(b, dict) and b.get("type") == "tool_use":
                            nm, detail = tool_summary(b)
                            pending_tools.append((ts, nm, detail))

    if not first_ts and not events:
        return None
    return {
        "source": "claude",
        "path": str(path),
        "cwd": cwd or "(unknown)",
        "branches": sorted(branches),
        "title": title,
        "first_ts": first_ts,
        "last_ts": last_ts,
        "events": events,
        "tools": pending_tools,
    }


def strip_agy_user_prompt(content):
    if not isinstance(content, str):
        return ""
    m = re.search(r"<USER_REQUEST>\s*(.*?)\s*</USER_REQUEST>", content, re.DOTALL)
    if m:
        return m.group(1).strip()
    cleaned = re.sub(r"<ADDITIONAL_METADATA>.*?</ADDITIONAL_METADATA>", "", content, flags=re.DOTALL)
    return cleaned.strip()


def uri_to_path(uri):
    if not isinstance(uri, str):
        return None
    if uri.startswith("file://"):
        parsed = urlparse(uri)
        return unquote(parsed.path)
    return uri if uri.startswith("/") else None


def agy_subagent_ids_and_workspaces(brain_dir):
    subagent_ids = set()
    workspaces_by_conv = {}
    if not brain_dir.is_dir():
        return subagent_ids, workspaces_by_conv
    for conv_dir in brain_dir.iterdir():
        if not conv_dir.is_dir():
            continue
        sub_dir = conv_dir / ".system_generated" / "subagents"
        if not sub_dir.is_dir():
            continue
        ws_list = []
        for meta_file in sub_dir.glob("*.json"):
            if meta_file.stem:
                subagent_ids.add(meta_file.stem)
            try:
                data = json.loads(meta_file.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                continue
            for uri in data.get("workspaceUris") or []:
                p = uri_to_path(uri)
                if p:
                    ws_list.append(p)
        if ws_list:
            workspaces_by_conv[conv_dir.name] = ws_list[0]
    return subagent_ids, workspaces_by_conv


def detect_git_branch(cwd):
    if not is_git_repo(cwd):
        return None
    try:
        res = subprocess.run(
            ["git", "-C", cwd, "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True,
            text=True,
            timeout=2,
        )
        if res.returncode == 0:
            b = res.stdout.strip()
            if b and b != "HEAD":
                return b
    except (OSError, subprocess.SubprocessError):
        pass
    return None


def scan_antigravity_session(transcript_path, workspace_hint=None):
    first_ts = last_ts = None
    events = []
    pending_tools = []
    project_votes = Counter()
    title = None

    try:
        fh = open(transcript_path, encoding="utf-8")
    except OSError:
        return None
    with fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
            except json.JSONDecodeError:
                continue
            ts = parse_ts(d.get("created_at") or d.get("timestamp"))
            if ts:
                first_ts = ts if first_ts is None or ts < first_ts else first_ts
                last_ts = ts if last_ts is None or ts > last_ts else last_ts
            t = d.get("type")
            source = d.get("source")
            if t == "USER_INPUT" and source == "USER_EXPLICIT":
                txt = strip_agy_user_prompt(d.get("content", ""))
                if not is_noise(txt):
                    if not title:
                        title = clip(txt, 72)
                    events.append((ts, "prompt", clip(txt)))
            elif t == "PLANNER_RESPONSE":
                said = str(d.get("content") or "").strip()
                if said:
                    events.append((ts, "said", clip(said)))
                for tc in d.get("tool_calls") or []:
                    if not isinstance(tc, dict):
                        continue
                    nm, detail = tool_summary_from_dict(tc.get("name", "tool"), tc.get("args", {}) or {})
                    pending_tools.append((ts, nm, detail))
                    if detail and detail.startswith("/"):
                        root = nearest_project_root(detail)
                        if root:
                            project_votes[root] += 1

    if not first_ts and not events:
        return None

    cwd = workspace_hint
    if not cwd and project_votes:
        cwd = project_votes.most_common(1)[0][0]
    branches = []
    b = detect_git_branch(cwd)
    if b:
        branches.append(b)

    return {
        "source": "antigravity",
        "path": str(transcript_path),
        "cwd": cwd or "(unknown)",
        "branches": branches,
        "title": title,
        "first_ts": first_ts,
        "last_ts": last_ts,
        "events": events,
        "tools": pending_tools,
    }


def overlaps(sess, since, until):
    f, l = sess["first_ts"], sess["last_ts"]
    if not f:
        return False
    if since and l and l < since:
        return False
    if until and f > until:
        return False
    return True


def in_window(ts, since, until):
    if ts is None:
        return True
    if since and ts < since:
        return False
    if until and ts > until:
        return False
    return True


def safe_mtime(path):
    try:
        return path.stat().st_mtime
    except OSError:
        return 0.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--since", help="inclusive start date YYYY-MM-DD")
    ap.add_argument("--until", help="inclusive end date YYYY-MM-DD")
    ap.add_argument("--days", type=int, help="window = last N days (overrides --since)")
    ap.add_argument("--project", action="append", default=[],
                    help="substring filter on project cwd (repeatable)")
    ap.add_argument("--source", choices=["all", "claude", "antigravity"], default="all",
                    help="history source to scan (default: all)")
    ap.add_argument("--list", action="store_true", help="list projects and exit")
    ap.add_argument("--brief", action="store_true",
                    help="compact output: drop assistant prose summaries, collapse "
                         "actions to a touched-file list + command count. Use for "
                         "wide scans (many projects / long windows).")
    args = ap.parse_args()

    now = dt.datetime.now(dt.timezone.utc)
    if args.until:
        until_date = parse_date_arg(args.until, "--until")
        until = dt.datetime.combine(until_date, dt.time.max, tzinfo=dt.timezone.utc)
    else:
        until = None

    if args.days is not None:
        if args.days < 0:
            print("extract.py: --days must be >= 0", file=sys.stderr)
            return 2
        anchor_date = until.date() if until else now.date()
        if args.days == 0 or until is not None:
            since = dt.datetime.combine(anchor_date - dt.timedelta(days=args.days), dt.time.min, tzinfo=dt.timezone.utc)
        else:
            since = now - dt.timedelta(days=args.days)
    elif args.since:
        since_date = parse_date_arg(args.since, "--since")
        since = dt.datetime.combine(since_date, dt.time.min, tzinfo=dt.timezone.utc)
    else:
        since = None

    want_claude = args.source in ("all", "claude")
    want_agy = args.source in ("all", "antigravity")

    c_dir = claude_projects_dir()
    a_dir = antigravity_brain_dir()
    has_claude = want_claude and c_dir.is_dir()
    has_agy = want_agy and a_dir.is_dir()

    if not has_claude and not has_agy:
        searched = []
        if want_claude:
            searched.append(str(c_dir))
        if want_agy:
            searched.append(str(a_dir))
        print(f"No history found at {', '.join(searched)}", file=sys.stderr)
        return 1

    by_cwd = {}

    if has_claude:
        files = [p for d in c_dir.iterdir() if d.is_dir() for p in d.glob("*.jsonl")]
        files.sort(key=safe_mtime)
        seen = set()
        for jsonl in files:
            sess = scan_claude_session(jsonl, seen)
            if sess:
                by_cwd.setdefault(sess["cwd"], []).append(sess)

    if has_agy:
        subagent_ids, ws_hints = agy_subagent_ids_and_workspaces(a_dir)
        for conv_dir in sorted(a_dir.iterdir()):
            if not conv_dir.is_dir() or conv_dir.name in subagent_ids:
                continue
            t_path = conv_dir / ".system_generated" / "logs" / "transcript.jsonl"
            if not t_path.is_file():
                continue
            sess = scan_antigravity_session(t_path, ws_hints.get(conv_dir.name))
            if sess:
                by_cwd.setdefault(sess["cwd"], []).append(sess)

    def project_matches(cwd):
        return not args.project or any(p.lower() in cwd.lower() for p in args.project)

    if args.list:
        print("# Projects in agent history\n")
        for cwd in sorted(by_cwd):
            if not project_matches(cwd):
                continue
            sessions = by_cwd[cwd]
            firsts = [s["first_ts"] for s in sessions if s["first_ts"]]
            lasts = [s["last_ts"] for s in sessions if s["last_ts"]]
            lo = min(firsts).date() if firsts else "?"
            hi = max(lasts).date() if lasts else "?"
            sources = ", ".join(sorted({s["source"] for s in sessions}))
            is_git = is_git_repo(cwd)
            print(f"- {cwd}")
            print(f"    sessions: {len(sessions)} ({sources}) | active: {lo} to {hi} | "
                  f"git repo: {'yes' if is_git else 'no'}")
        return 0

    win = []
    if since:
        win.append(f"since {since.date()}")
    if until:
        win.append(f"until {until.date()}")
    print(f"# Work digest ({', '.join(win) if win else 'all time'})\n")

    any_out = False
    for cwd in sorted(by_cwd):
        if not project_matches(cwd):
            continue
        sessions = [s for s in by_cwd[cwd] if overlaps(s, since, until)]
        if not sessions:
            continue
        any_out = True
        is_git = is_git_repo(cwd)
        print(f"\n## Project: {cwd}")
        print(f"git repo: {'yes - run git log for commit-level detail' if is_git else 'no'}\n")

        sessions.sort(key=lambda s: s["first_ts"] or now)
        for s in sessions:
            ev = [(ts, k, tx) for (ts, k, tx) in s["events"] if in_window(ts, since, until)]
            if args.brief:
                ev = [e for e in ev if e[1] == "prompt"]
            tools = [(nm, detail) for (ts, nm, detail) in s["tools"]
                     if in_window(ts, since, until)]
            if not ev and not tools:
                continue
            span = ""
            if s["first_ts"]:
                span = s["first_ts"].strftime("%Y-%m-%d %H:%M")
                if s["last_ts"]:
                    span += " to " + s["last_ts"].strftime("%Y-%m-%d %H:%M")
            head = s["title"] or "(untitled session)"
            print(f"### {head} [{s['source']}]")
            print(f"_{span} | branches: {', '.join(s['branches']) or 'n/a'}_")
            print(f"_path: {s['path']}_\n")
            assistant_label = "ANTIGRAVITY" if s["source"] == "antigravity" else "CLAUDE"
            for ts, kind, tx in ev:
                label = {"prompt": "USER", "said": assistant_label}.get(kind, kind)
                print(f"- **{label}:** {tx}")
            if tools and args.brief:
                files_touched = sorted({d for nm, d in tools if nm in MUTATING and d})
                ncmd = sum(1 for nm, _ in tools if nm in SHELL_TOOLS)
                if files_touched:
                    print(f"- **files changed ({len(files_touched)}):** "
                          + ", ".join(files_touched))
                print(f"- **{len(tools)} actions, {ncmd} shell commands**")
            elif tools:
                print(f"- **actions ({len(tools)}):**")
                for nm, detail in tools:
                    print(f"    - {nm}: {detail}" if detail else f"    - {nm}")
            print()

    if not any_out:
        print("_No sessions matched the filters._")
    return 0


if __name__ == "__main__":
    sys.exit(main())
