#!/usr/bin/env bash
# Export společného projektu. Vyžaduje standardní Godot 4.7 a jeho šablony
# (python scripts/install_templates.py). Vydání skládá scripts/release.py.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"
godot_bin=${GODOT_BIN:-godot}

case "${1:-macos}" in
  macos) preset=macOS; output_dir=build/macos ;;
  windows) preset='Windows Desktop'; output_dir=build/windows ;;
  linux-qa) preset='Linux QA'; output_dir=build/linux-qa ;;
  *) printf 'Použití: %s [macos|windows|linux-qa]\n' "$0" >&2; exit 2 ;;
esac

case "$("$godot_bin" --version)" in
  4.7.stable.*) ;;
  *) printf 'Je potřeba standardní Godot 4.7 stable. Nastav GODOT_BIN.\n' >&2; exit 1 ;;
esac

mkdir -p "$output_dir"
# Čistý klon nemá importované podklady; bez importu by v balíčku chyběly.
"$godot_bin" --headless --editor --path "$repo_root" --import
"$godot_bin" --headless --path "$repo_root" --export-release "$preset"
