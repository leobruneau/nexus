#!/usr/bin/env bash
# Apply the Claude Code setup in claude/ to ~/.claude.
#
# - Symlinks CLAUDE.md, every folder in claude/skills and claude/mods, and every file in claude/hooks
#   into ~/.claude, so edits made on this machine land in the repo.
# - Links claude/agents as one folder to ~/.claude/agents/nexus, so new agent files need no reinstall.
# - Links every file in bin/ into $NEXUS_BIN_DIR (default ~/.local/bin).
# - Merges claude/settings.json into ~/.claude/settings.json. Keys from the repo win; keys that only
#   exist locally stay. {{HOME}} in the template becomes $HOME and {{NEXUS}} becomes this clone's path.
# - Moves anything it would replace to ~/.claude/backups/nexus-<timestamp>/ (bin files go under bin/).
#
# Run it from a clone that stays on disk, since the symlinks point into it.
# Usage: ./install.sh [--dry-run]
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="$repo/claude"
dest="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
backup="$dest/backups/nexus-$(date +%Y%m%d-%H%M%S)"
bindir="${NEXUS_BIN_DIR:-$HOME/.local/bin}"
dry=0
[[ "${1:-}" == "--dry-run" ]] && dry=1

run() { if ((dry)); then echo "would: $*"; else "$@"; fi; }

command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 1; }
run mkdir -p "$dest/skills" "$dest/mods"

link() { # link <target in repo> <path> [path relative to the backup folder]
  local target="$1" path="$2" rel="${3:-${2#"$dest"/}}"
  if [[ -L "$path" && "$(readlink "$path")" == "$target" ]]; then
    echo "ok      $rel"
    return
  fi
  if [[ -e "$path" || -L "$path" ]]; then
    run mkdir -p "$(dirname "$backup/$rel")"
    run mv "$path" "$backup/$rel"
    echo "backup  $rel"
  fi
  run ln -s "$target" "$path"
  echo "link    $rel"
}

link "$src/CLAUDE.md" "$dest/CLAUDE.md"
for d in "$src"/skills/*/; do [[ -d "$d" ]] || continue; d="${d%/}"; link "$d" "$dest/skills/$(basename "$d")"; done
for d in "$src"/mods/*/;   do [[ -d "$d" ]] || continue; d="${d%/}"; link "$d" "$dest/mods/$(basename "$d")"; done
run mkdir -p "$dest/hooks"
for f in "$src"/hooks/*;   do [[ -e "$f" || -L "$f" ]] || continue; link "$f" "$dest/hooks/$(basename "$f")"; done

if [[ -d "$src/agents" ]]; then
  run mkdir -p "$dest/agents"
  link "$src/agents" "$dest/agents/nexus"
fi

if [[ -d "$repo/bin" ]]; then
  run mkdir -p "$bindir"
  for f in "$repo"/bin/*; do
    [[ -e "$f" || -L "$f" ]] || continue
    link "$f" "$bindir/$(basename "$f")" "bin/$(basename "$f")"
  done
fi

python3 - "$src/settings.json" "$dest" "$backup" "$repo" "$dry" <<'PY'
import difflib, json, os, shutil, sys

template, dest, backup, repo, dry = sys.argv[1:6]
dry = dry == "1"


def merge(a, b):
    """Deep merge like jq's `*`: objects merge recursively, b wins, arrays are replaced."""
    out = dict(a)
    for k, v in b.items():
        both_dicts = isinstance(out.get(k), dict) and isinstance(v, dict)
        out[k] = merge(out[k], v) if both_dicts else v
    return out


def dump(obj):
    return json.dumps(obj, indent=2, ensure_ascii=False) + "\n"


with open(template) as f:
    text = f.read()
text = text.replace("{{HOME}}", os.environ["HOME"]).replace("{{NEXUS}}", repo)
rendered = json.loads(text)

settings = os.path.join(dest, "settings.json")
if os.path.isfile(settings):
    with open(settings) as f:
        current = json.load(f)
    merged = merge(current, rendered)
    if merged == current:
        print("ok      settings.json")
    elif dry:
        print(f"would: cp {settings} {backup}/settings.json")
        diff = difflib.unified_diff(
            dump(current).splitlines(True), dump(merged).splitlines(True), "current", "merged"
        )
        sys.stdout.writelines(diff)
        print("merge   settings.json")
    else:
        os.makedirs(backup, exist_ok=True)
        shutil.copy2(settings, os.path.join(backup, "settings.json"))
        with open(settings, "w") as f:
            f.write(dump(merged))
        print("merge   settings.json")
else:
    if dry:
        print(f"would: write {settings}")
    else:
        with open(settings, "w") as f:
            f.write(dump(rendered))
    print("write   settings.json")

# Claude Code ignores a marketplace whose registered source differs from the one in settings,
# and its plugins fail to load until the marketplace is added again from the new source.
known_path = os.path.join(dest, "plugins", "known_marketplaces.json")
if os.path.isfile(known_path):
    with open(known_path) as f:
        known = json.load(f)
    for name, entry in (rendered.get("extraKnownMarketplaces") or {}).items():
        if name in known and known[name].get("source") != entry.get("source"):
            s = entry.get("source") or {}
            where = s.get("repo") or s.get("path") or s.get("url")
            print(f"Marketplace {name} changed source. Run: claude plugin marketplace add {where}")
PY

if [[ -d "$backup" ]]; then echo "Replaced files are in $backup"; fi
echo "Restart Claude Code. Plugins listed in enabledPlugins install from their marketplaces on start."
echo "If one is missing, run: claude plugin install <name>@<marketplace>"
