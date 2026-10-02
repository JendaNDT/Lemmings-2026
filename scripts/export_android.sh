#!/usr/bin/env bash
# Podepsané testovací APK. Android SDK a Java musí být nastavené v editoru Godotu.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"
godot_bin=${GODOT_BIN:-godot}
case "$("$godot_bin" --version)" in
  4.7.stable.*) ;;
  *) printf 'Je potřeba standardní Godot 4.7 stable a jeho Android šablony.\n' >&2; exit 1 ;;
esac

mkdir -p build/android
"$godot_bin" --headless --editor --path "$repo_root" --import
"$godot_bin" --headless --path "$repo_root" --export-debug Android
