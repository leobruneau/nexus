#!/usr/bin/env bash
# Copy local Claude Code and Antigravity CLI changes from ~/.claude and
# ~/.gemini/config back into the repo, then list what changed.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
claude_src="$repo/claude"
agy_src="$repo/antigravity"
claude_dest="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
agy_dest="${ANTIGRAVITY_CONFIG_DIR:-$HOME/.gemini/config}"
datadir="${NEXUS_DATA_DIR:-$HOME/.local/share/nexus}"

find_jq() {
  local cand
  for cand in "$datadir/bin/jq" "$claude_dest/bin/jq"; do
    if [[ -x "$cand" ]]; then
      echo "$cand"
      return 0
    fi
  done
  command -v jq 2>/dev/null || return 1
}

jq="$(find_jq)" || { echo "jq not found. Run ./install.sh first." >&2; exit 1; }

if [[ -d "$claude_dest" ]]; then
  if [[ -f "$claude_dest/settings.json" ]]; then
    tmp_settings="$(mktemp "$claude_src/.settings.tmp.XXXXXX")"
    if [[ -f "$claude_src/settings.json" ]]; then
      if "$jq" --arg r "$repo" --arg c "$claude_dest" --arg h "$HOME" \
        --slurpfile tracked "$claude_src/settings.json" \
        '$tracked[0] as $t |
        walk(if type == "string" then split($r) | join("{{NEXUS}}") | split($c) | join("{{CLAUDE_CONFIG_DIR}}") | split($h) | join("{{HOME}}") else . end) |
        if type == "object" and ($t | type == "object") then
          with_entries(
            select(.key as $k | $t | has($k)) |
            if (.key == "env" or .key == "enabledPlugins") and (.value | type == "object") and ($t[.key] | type == "object") then
              .key as $k | .value |= with_entries(select(.key as $sk | $t[$k] | has($sk)))
            else . end
          )
        else . end' \
        "$claude_dest/settings.json" > "$tmp_settings" && [[ -s "$tmp_settings" ]]; then
        mv -f "$tmp_settings" "$claude_src/settings.json"
        echo "copied  claude/settings.json"
        skipped_keys="$("$jq" -r --slurpfile tracked "$claude_src/settings.json" \
          '$tracked[0] as $t |
          if type == "object" and ($t | type == "object") then
            [
              (keys_unsorted[] | select(. as $k | $t | has($k) | not)),
              (("env", "enabledPlugins") as $k |
                select((.[$k] | type == "object") and ($t[$k] | type == "object")) |
                .[$k] | keys_unsorted[] | select(. as $sk | $t[$k] | has($sk) | not) | "\($k).\(.)")
            ] | sort | join(", ")
          else "" end' \
          "$claude_dest/settings.json")"
        if [[ -n "$skipped_keys" ]]; then
          echo "skip    claude/settings.json local keys: $skipped_keys"
        fi
      else
        rm -f "$tmp_settings"
        echo "warn    skipped claude/settings.json (invalid or empty)" >&2
      fi
    else
      if "$jq" --arg r "$repo" --arg c "$claude_dest" --arg h "$HOME" \
        'walk(if type == "string" then split($r) | join("{{NEXUS}}") | split($c) | join("{{CLAUDE_CONFIG_DIR}}") | split($h) | join("{{HOME}}") else . end)' \
        "$claude_dest/settings.json" > "$tmp_settings" && [[ -s "$tmp_settings" ]]; then
        mv -f "$tmp_settings" "$claude_src/settings.json"
        echo "copied  claude/settings.json"
      else
        rm -f "$tmp_settings"
        echo "warn    skipped claude/settings.json (invalid or empty)" >&2
      fi
    fi
  fi

  if [[ -f "$claude_dest/CLAUDE.md" && ! -L "$claude_dest/CLAUDE.md" ]]; then
    cp "$claude_dest/CLAUDE.md" "$claude_src/CLAUDE.md"
    echo "copied  claude/CLAUDE.md"
  fi

  for d in "$claude_dest/skills"/*/; do
    [[ -d "$d" ]] || continue
    d="${d%/}"
    name="$(basename "$d")"
    [[ -L "$d" || "$name" == "synced" ]] && continue
    if [[ -d "$repo/skills/$name" ]]; then
      rsync -a --exclude '.DS_Store' "$d/" "$repo/skills/$name/"
      echo "copied  skills/$name"
    else
      mkdir -p "$claude_src/skills"
      rsync -a --exclude '.DS_Store' "$d/" "$claude_src/skills/$name/"
      echo "copied  claude/skills/$name"
    fi
  done

  for d in "$claude_dest/mods"/*/; do
    [[ -d "$d" ]] || continue
    d="${d%/}"
    name="$(basename "$d")"
    [[ -L "$d" ]] && continue
    mkdir -p "$claude_src/mods"
    rsync -a --exclude '.DS_Store' --exclude '.claude-plugin/types/' "$d/" "$claude_src/mods/$name/"
    echo "copied  claude/mods/$name"
  done

  mkdir -p "$claude_src/hooks"
  for f in "$claude_dest"/hooks/*; do
    [[ -f "$f" && ! -L "$f" ]] || continue
    cp "$f" "$claude_src/hooks/"
    echo "copied  claude/hooks/$(basename "$f")"
  done

  if [[ -d "$claude_dest/agents" ]]; then
    for f in "$claude_dest"/agents/*.md; do
      [[ -f "$f" && ! -L "$f" ]] || continue
      name="$(basename "$f")"
      mkdir -p "$claude_src/agents"
      if [[ -e "$claude_src/agents/$name" ]]; then
        echo "warn    claude/agents/$name already exists, skipping" >&2
        continue
      fi
      if [[ -L "$claude_dest/agents/nexus" && "$(readlink "$claude_dest/agents/nexus")" == "$claude_src/agents" ]]; then
        mv "$f" "$claude_src/agents/"
        echo "moved   claude/agents/$name"
      else
        cp "$f" "$claude_src/agents/"
        echo "copied  claude/agents/$name"
      fi
    done
  fi
fi

if [[ -d "$agy_dest" ]]; then
  for d in "$agy_dest/skills"/*/; do
    [[ -d "$d" ]] || continue
    d="${d%/}"
    name="$(basename "$d")"
    [[ -L "$d" ]] && continue
    mkdir -p "$repo/skills"
    rsync -a --exclude '.DS_Store' "$d/" "$repo/skills/$name/"
    echo "copied  skills/$name"
  done

  if [[ -d "$agy_dest/agents" ]]; then
    for f in "$agy_dest"/agents/*.md; do
      [[ -f "$f" && ! -L "$f" ]] || continue
      name="$(basename "$f")"
      mkdir -p "$agy_src/agents"
      if [[ -e "$agy_src/agents/$name" ]]; then
        echo "warn    antigravity/agents/$name already exists, skipping" >&2
        continue
      fi
      cp "$f" "$agy_src/agents/"
      echo "copied  antigravity/agents/$name"
    done
  fi
fi

if git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$repo" status --short
fi
