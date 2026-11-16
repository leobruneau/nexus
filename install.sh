#!/usr/bin/env bash
# Apply the Claude Code setup in claude/ to ~/.claude.
#
# - Symlinks CLAUDE.md, every folder in claude/skills and claude/mods, and every file in claude/hooks
#   into ~/.claude, so edits made on this machine land in the repo.
# - Links claude/agents as one folder to ~/.claude/agents/nexus, so new agent files need no reinstall.
# - Links every file in bin/ into $NEXUS_BIN_DIR (default ~/.local/bin).
# - Merges claude/settings.json into ~/.claude/settings.json. Keys from the repo win; keys that only
#   exist locally stay. {{HOME}} in the template becomes $HOME and {{NEXUS}} becomes this clone's path.
# - Uses jq from PATH. Without one, downloads a pinned jq to ~/.claude/bin/jq and checks its SHA-256.
# - Moves anything it would replace to ~/.claude/backups/nexus-<timestamp>/ (bin files go under bin/).
#
# Run it from a clone that stays on disk, since the symlinks point into it.
# Usage: ./install.sh [--dry-run]
set -euo pipefail

# jq comes from PATH if present. Otherwise this pinned release is downloaded to ~/.claude/bin/jq.
# Checksums come from https://github.com/jqlang/jq/releases/download/jq-1.8.2/sha256sum.txt
JQ_VERSION=1.8.2
JQ_SHA256_linux_amd64=b1c22172dd303f3be49e935aa56aa48a8b7a46e0bc838b4997d3bb451495870f
JQ_SHA256_linux_arm64=8b85c817833814ddca00a144c33705546355afccf0cf39b188f3cdb48b852309
JQ_SHA256_macos_amd64=e94b266e3c26690550006abe63152b782280f4e14374accdf04cbde844f00bc0
JQ_SHA256_macos_arm64=2d75340ba57a4b4b4c8708a21c2dc8e958a48aaa8bba13b27f77f6e4c0eca07e

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="$repo/claude"
dest="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
backup="$dest/backups/nexus-$(date +%Y%m%d-%H%M%S)"
bindir="${NEXUS_BIN_DIR:-$HOME/.local/bin}"
dry=0
[[ "${1:-}" == "--dry-run" ]] && dry=1

run() { if ((dry)); then echo "would: $*"; else "$@"; fi; }

die_without_jq() { echo "jq is missing and could not be downloaded ($1). Install jq (brew install jq, or apt install jq) and rerun." >&2; exit 1; }

jq_platform() {
  local os arch
  case "$(uname -s)" in Darwin) os=macos ;; Linux) os=linux ;; *) return 1 ;; esac
  case "$(uname -m)" in x86_64|amd64) arch=amd64 ;; arm64|aarch64) arch=arm64 ;; *) return 1 ;; esac
  echo "$os-$arch"
}

sha256_of() {
  if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

download_jq() { # download_jq <platform> <expected sha256> <file>
  command -v curl >/dev/null || die_without_jq "curl is missing"
  curl -fsSL -o "$3" "https://github.com/jqlang/jq/releases/download/jq-$JQ_VERSION/jq-$1" || die_without_jq "download failed"
  [[ "$(sha256_of "$3")" == "$2" ]] || die_without_jq "checksum mismatch"
  chmod +x "$3"
}

fetch_jq() { # fetch_jq <platform> <expected sha256>
  jq_tmp="$(mktemp -d)"
  trap 'rm -rf "$jq_tmp"' EXIT
  download_jq "$1" "$2" "$jq_tmp/jq"
  if ((dry)); then
    echo "would: install jq $JQ_VERSION to $dest/bin/jq"
    JQ="$jq_tmp/jq"
  else
    mkdir -p "$dest/bin"
    mv "$jq_tmp/jq" "$dest/bin/jq"
    JQ="$dest/bin/jq"
  fi
  echo "fetch   bin/jq"
}

# Sets JQ. Runs before any symlink is made, so a failure leaves nothing half installed.
resolve_jq() {
  local platform checksum
  if JQ="$(command -v jq)"; then echo "ok      jq (system)"; return; fi
  platform="$(jq_platform)" || die_without_jq "unsupported platform $(uname -s) $(uname -m)"
  checksum="JQ_SHA256_${platform//-/_}"
  JQ="$dest/bin/jq"
  if [[ -x "$JQ" && "$(sha256_of "$JQ")" == "${!checksum}" ]]; then echo "ok      bin/jq"; return; fi
  fetch_jq "$platform" "${!checksum}"
}

resolve_jq
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

rendered="$(sed -e "s|{{HOME}}|$HOME|g" -e "s|{{NEXUS}}|$repo|g" "$src/settings.json")"
settings="$dest/settings.json"
if [[ -f "$settings" ]]; then
  merged="$("$JQ" -s '.[0] * .[1]' "$settings" <(echo "$rendered"))"
  if [[ "$merged" == "$("$JQ" . "$settings")" ]]; then
    echo "ok      settings.json"
  else
    run mkdir -p "$backup"
    run cp "$settings" "$backup/settings.json"
    if ((dry)); then diff <("$JQ" . "$settings") <(echo "$merged") || true
    else echo "$merged" > "$settings"; fi
    echo "merge   settings.json"
  fi
else
  if ((dry)); then echo "would: write $settings"; else echo "$rendered" | "$JQ" . > "$settings"; fi
  echo "write   settings.json"
fi

# Claude Code ignores a marketplace whose registered source differs from the one in settings,
# and its plugins fail to load until the marketplace is added again from the new source.
known="$dest/plugins/known_marketplaces.json"
if [[ -f "$known" ]]; then
  "$JQ" -r --slurpfile k "$known" '(.extraKnownMarketplaces // {}) | to_entries[]
    | select($k[0][.key] != null and $k[0][.key].source != .value.source)
    | "Marketplace \(.key) changed source. Run: claude plugin marketplace add \(.value.source.repo // .value.source.path // .value.source.url)"' \
    <<<"$rendered"
fi

if [[ -d "$backup" ]]; then echo "Replaced files are in $backup"; fi
echo "Restart Claude Code. Plugins listed in enabledPlugins install from their marketplaces on start."
echo "If one is missing, run: claude plugin install <name>@<marketplace>"
