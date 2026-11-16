#!/usr/bin/env bash
# Copy local Claude Code changes from ~/.claude back into claude/, then list what changed.
#
# - Rewrites claude/settings.json from ~/.claude/settings.json, with this clone's path replaced by
#   {{NEXUS}} and $HOME replaced by {{HOME}}.
# - Moves plain *.md files from ~/.claude/agents into claude/agents when agents/nexus links there, and copies them otherwise.
# - Copies CLAUDE.md, skills, mods and hooks/*.sh that are plain files in ~/.claude (not symlinks into this repo).
#   Run ./install.sh afterwards to replace them with symlinks.
# - Skips ~/.claude/skills/synced, which claude.ai manages.
#
# Review with `git diff`, then commit and push.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="$repo/claude"
dest="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
jq="$(command -v jq || echo "$dest/bin/jq")"
[[ -x "$jq" ]] || { echo "jq not found. Run ./install.sh first." >&2; exit 1; }

# Replace the repo path first, since the repo usually lives under $HOME. split/join matches literally.
"$jq" --arg r "$repo" --arg h "$HOME" \
  'walk(if type == "string" then split($r) | join("{{NEXUS}}") | split($h) | join("{{HOME}}") else . end)' \
  "$dest/settings.json" > "$src/settings.json"
echo "copied  settings.json"

if [[ -f "$dest/CLAUDE.md" && ! -L "$dest/CLAUDE.md" ]]; then
  cp "$dest/CLAUDE.md" "$src/CLAUDE.md"
  echo "copied  CLAUDE.md"
fi

for kind in skills mods; do
  for d in "$dest/$kind"/*/; do
    [[ -d "$d" ]] || continue
    d="${d%/}"; name="$(basename "$d")"
    [[ -L "$d" || "$kind/$name" == "skills/synced" ]] && continue
    rsync -a --exclude '.DS_Store' --exclude 'types/claude-code*' "$d/" "$src/$kind/$name/"
    echo "copied  $kind/$name"
  done
done

mkdir -p "$src/hooks"
for f in "$dest"/hooks/*.sh; do
  [[ -f "$f" && ! -L "$f" ]] || continue
  cp "$f" "$src/hooks/"
  echo "copied  hooks/$(basename "$f")"
done

if [[ -d "$dest/agents" ]]; then
  for f in "$dest"/agents/*.md; do
    [[ -f "$f" && ! -L "$f" ]] || continue
    mkdir -p "$src/agents"
    if [[ -L "$dest/agents/nexus" && "$(readlink "$dest/agents/nexus")" == "$src/agents" ]]; then
      mv "$f" "$src/agents/"
      echo "moved   agents/$(basename "$f")"
    else
      cp "$f" "$src/agents/"
      echo "copied  agents/$(basename "$f")"
    fi
  done
fi

git -C "$repo" status --short
