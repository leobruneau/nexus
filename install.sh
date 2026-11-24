#!/usr/bin/env bash
# Install shared nexus rules/skills, Claude Code config (claude/), Antigravity
# CLI plugin (antigravity/), and CLI tools (bin/).
#
# Usage: ./install.sh [--dry-run] [--claude-only | --antigravity-only]
set -euo pipefail

JQ_VERSION=1.8.2
JQ_SHA256_linux_amd64=b1c22172dd303f3be49e935aa56aa48a8b7a46e0bc838b4997d3bb451495870f
JQ_SHA256_linux_arm64=8b85c817833814ddca00a144c33705546355afccf0cf39b188f3cdb48b852309
JQ_SHA256_macos_amd64=e94b266e3c26690550006abe63152b782280f4e14374accdf04cbde844f00bc0
JQ_SHA256_macos_arm64=2d75340ba57a4b4b4c8708a21c2dc8e958a48aaa8bba13b27f77f6e4c0eca07e

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
claude_src="$repo/claude"
agy_src="$repo/antigravity"
claude_dest="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
agy_dest="${ANTIGRAVITY_CONFIG_DIR:-$HOME/.gemini/config}"
bindir="${NEXUS_BIN_DIR:-$HOME/.local/bin}"
datadir="${NEXUS_DATA_DIR:-$HOME/.local/share/nexus}"
ts="$(date +%Y%m%d-%H%M%S)"
claude_backup="$claude_dest/backups/nexus-$ts"
agy_backup="$agy_dest/backups/nexus-$ts"

dry=0
install_claude=1
install_agy=1
only_flag=""

usage() {
  echo "Usage: ./install.sh [--dry-run] [--claude-only | --antigravity-only]" >&2
  exit 1
}

while (( $# > 0 )); do
  case "$1" in
    --dry-run) dry=1 ;;
    --claude-only)
      [[ "$only_flag" == "antigravity" ]] && usage
      only_flag="claude"
      install_claude=1
      install_agy=0
      ;;
    --antigravity-only)
      [[ "$only_flag" == "claude" ]] && usage
      only_flag="antigravity"
      install_claude=0
      install_agy=1
      ;;
    *) usage ;;
  esac
  shift
done

run() { if ((dry)); then echo "would: $*"; else "$@"; fi; }

jq_platform() {
  local os arch
  case "$(uname -s)" in Darwin) os=macos ;; Linux) os=linux ;; *) return 1 ;; esac
  case "$(uname -m)" in x86_64|amd64) arch=amd64 ;; arm64|aarch64) arch=arm64 ;; *) return 1 ;; esac
  echo "$os-$arch"
}

sha256_of() {
  if command -v sha256sum >/dev/null; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

download_jq() {
  command -v curl >/dev/null || { jq_error="curl is missing"; return 1; }
  curl --proto '=https' --connect-timeout 15 --max-time 120 --retry 2 -fsSL -o "$3" \
    "https://github.com/jqlang/jq/releases/download/jq-$JQ_VERSION/jq-$1" || { jq_error="download failed"; return 1; }
  [[ "$(sha256_of "$3")" == "$2" ]] || { jq_error="checksum mismatch"; return 1; }
  chmod +x "$3"
}

use_pinned_jq() {
  local platform checksum expected cand
  command -v sha256sum >/dev/null || command -v shasum >/dev/null || { jq_error="no sha256sum or shasum"; return 1; }
  platform="$(jq_platform)" || { jq_error="unsupported platform $(uname -s) $(uname -m)"; return 1; }
  checksum="JQ_SHA256_${platform//-/_}"
  expected="${!checksum}"

  JQ="$datadir/bin/jq"
  if [[ -x "$JQ" && "$(sha256_of "$JQ")" == "$expected" ]]; then
    echo "ok      data/bin/jq"
    return 0
  fi

  # Reuse an already-downloaded pinned jq from ~/.claude/bin/jq if present.
  cand="$claude_dest/bin/jq"
  if [[ -x "$cand" && ! -L "$cand" && "$(sha256_of "$cand")" == "$expected" ]]; then
    if ((dry)); then
      echo "would: copy $cand to $JQ"
      JQ="$cand"
    else
      mkdir -p "$datadir/bin"
      cp "$cand" "$JQ.new" && chmod +x "$JQ.new" && mv -f "$JQ.new" "$JQ"
      echo "copy    data/bin/jq"
    fi
    return 0
  fi

  if ((dry)); then
    if JQ="$(command -v jq 2>/dev/null)"; then
      echo "would: fetch data/bin/jq (jq $JQ_VERSION); using system jq for dry-run"
      return 0
    fi
    echo "would: fetch data/bin/jq (jq $JQ_VERSION)"
  fi

  _jq_tmp="$(mktemp -d)"
  trap '[[ -n "${_jq_tmp:-}" ]] && rm -rf "$_jq_tmp"' EXIT
  download_jq "$platform" "$expected" "$_jq_tmp/jq" || { rm -rf "$_jq_tmp"; _jq_tmp=""; return 1; }
  if ((dry)); then
    JQ="$_jq_tmp/jq"
  else
    { mkdir -p "$datadir/bin" && mv "$_jq_tmp/jq" "$JQ.new" && mv -f "$JQ.new" "$JQ"; } ||
      { rm -rf "$_jq_tmp"; _jq_tmp=""; jq_error="cannot write $JQ"; return 1; }
    rm -rf "$_jq_tmp"
    _jq_tmp=""
    echo "fetch   data/bin/jq"
  fi
}

resolve_jq() {
  jq_error=""
  use_pinned_jq && return 0
  if JQ="$(command -v jq 2>/dev/null)"; then
    echo "ok      jq (system, pinned jq unavailable: $jq_error)"
    return 0
  fi
  echo "Could not get jq ($jq_error). Install jq (brew install jq, or apt install jq) and rerun." >&2
  exit 1
}

resolve_jq

# link <target> <dest_path> <backup_root> [rel]
link_item() {
  local target="$1" path="$2" b_root="$3" rel="${4:-}"
  if [[ -z "$rel" ]]; then
    rel="$(basename "$path")"
  fi
  if [[ -L "$path" && "$(readlink "$path")" == "$target" ]]; then
    echo "ok      $rel"
    return
  fi
  if [[ -e "$path" || -L "$path" ]]; then
    run mkdir -p "$(dirname "$b_root/$rel")"
    run mv "$path" "$b_root/$rel"
    if ((dry)); then echo "would: backup $rel"; else echo "backup  $rel"; fi
  fi
  run ln -s "$target" "$path"
  if ((dry)); then echo "would: link $rel"; else echo "link    $rel"; fi
}

if ((install_claude)); then
  run mkdir -p "$claude_dest/skills" "$claude_dest/mods" "$claude_dest/hooks"

  link_item "$claude_src/CLAUDE.md" "$claude_dest/CLAUDE.md" "$claude_backup" "CLAUDE.md"
  link_item "$repo/rules/global.md" "$claude_dest/nexus-global.md" "$claude_backup" "nexus-global.md"

  for d in "$repo"/skills/*/ "$claude_src"/skills/*/; do
    [[ -d "$d" ]] || continue
    d="${d%/}"
    name="$(basename "$d")"
    link_item "$d" "$claude_dest/skills/$name" "$claude_backup" "skills/$name"
  done

  for d in "$claude_src"/mods/*/; do
    [[ -d "$d" ]] || continue
    d="${d%/}"
    name="$(basename "$d")"
    link_item "$d" "$claude_dest/mods/$name" "$claude_backup" "mods/$name"
  done

  for f in "$claude_src"/hooks/*; do
    [[ -e "$f" || -L "$f" ]] || continue
    name="$(basename "$f")"
    link_item "$f" "$claude_dest/hooks/$name" "$claude_backup" "hooks/$name"
  done

  if [[ -d "$claude_src/agents" ]]; then
    run mkdir -p "$claude_dest/agents"
    link_item "$claude_src/agents" "$claude_dest/agents/nexus" "$claude_backup" "agents/nexus"
  fi

  # Keep ~/.claude/bin/jq pointing to the shared pinned jq when available.
  if [[ -x "$datadir/bin/jq" ]]; then
    run mkdir -p "$claude_dest/bin"
    link_item "$datadir/bin/jq" "$claude_dest/bin/jq" "$claude_backup" "bin/jq"
  fi

  rendered="$("$JQ" --arg h "$HOME" --arg r "$repo" --arg c "$claude_dest" \
    'walk(if type == "string" then split("{{CLAUDE_CONFIG_DIR}}") | join($c) | split("{{NEXUS}}") | join($r) | split("{{HOME}}") | join($h) else . end)' \
    "$claude_src/settings.json")"
  settings="$claude_dest/settings.json"
  if [[ -f "$settings" ]]; then
    merged="$("$JQ" -s '.[0] * .[1]' "$settings" <(printf '%s\n' "$rendered"))"
    if [[ "$merged" == "$("$JQ" . "$settings")" ]]; then
      echo "ok      settings.json"
    else
      run mkdir -p "$claude_backup"
      run cp "$settings" "$claude_backup/settings.json"
      if ((dry)); then
        diff <("$JQ" . "$settings") <(printf '%s\n' "$merged") || true
        echo "would: merge settings.json"
      else
        tmp_settings="$(mktemp "$claude_dest/.settings.tmp.XXXXXX")"
        printf '%s\n' "$merged" > "$tmp_settings"
        mv -f "$tmp_settings" "$settings"
        echo "merge   settings.json"
      fi
    fi
  else
    if ((dry)); then
      echo "would: write $settings"
    else
      tmp_settings="$(mktemp "$claude_dest/.settings.tmp.XXXXXX")"
      printf '%s\n' "$rendered" | "$JQ" . > "$tmp_settings"
      mv -f "$tmp_settings" "$settings"
      echo "write   settings.json"
    fi
  fi

  known="$claude_dest/plugins/known_marketplaces.json"
  if [[ -f "$known" ]]; then
    "$JQ" -r --slurpfile k "$known" '(.extraKnownMarketplaces // {}) | to_entries[]
      | select($k[0][.key] != null and $k[0][.key].source != .value.source)
      | "Marketplace \(.key) changed source. Run: claude plugin marketplace add \(.value.source.repo // .value.source.path // .value.source.url // .value.source)"' \
      <<<"$rendered" 2>/dev/null || true
  fi
fi

if ((install_agy)); then
  run mkdir -p "$agy_dest/plugins" "$agy_dest/skills"

  link_item "$agy_src" "$agy_dest/plugins/nexus" "$agy_backup" "plugins/nexus"
  link_item "$repo/rules/global.md" "$agy_dest/nexus-global.md" "$agy_backup" "nexus-global.md"

  for d in "$repo"/skills/*/ "$agy_src"/skills/*/; do
    [[ -d "$d" ]] || continue
    d="${d%/}"
    name="$(basename "$d")"
    link_item "$d" "$agy_dest/skills/$name" "$agy_backup" "skills/$name"
  done
fi

if [[ -d "$repo/bin" ]]; then
  run mkdir -p "$bindir"
  bin_backup="$agy_backup"
  if ((install_claude)); then
    bin_backup="$claude_backup"
  fi
  for f in "$repo"/bin/*; do
    [[ -e "$f" || -L "$f" ]] || continue
    name="$(basename "$f")"
    link_item "$f" "$bindir/$name" "$bin_backup" "bin/$name"
  done
fi

if (( ! dry )); then
  for b in "$claude_backup" "$agy_backup"; do
    if [[ -d "$b" ]]; then
      echo "Replaced files are in $b"
    fi
  done
  if ((install_claude)); then
    echo "Restart Claude Code. Plugins listed in enabledPlugins install from their marketplaces on start."
    echo "If one is missing, run: claude plugin install <name>@<marketplace>"
  fi
  if ((install_agy)); then
    echo "Antigravity plugin linked at $agy_dest/plugins/nexus."
  fi
fi
