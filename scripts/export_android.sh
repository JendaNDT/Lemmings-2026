#!/usr/bin/env bash
# Podepsané testovací APK. Android SDK a Java musí být nastavené v editoru Godotu.
#
# Podpis musí být vždy stejný (otisk ve scripts/android_signing.txt), jinak
# nová verze nepůjde nainstalovat přes starou. Když klíč v tomto prostředí
# chybí nebo nesedí, export skončí chybou místo tichého podpisu jiným klíčem.
# Záměrnou výměnu klíče povolí jen LEMMINGS_ALLOW_NEW_KEY=1.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"
godot_bin=${GODOT_BIN:-godot}
case "$("$godot_bin" --version)" in
  4.7.stable.*) ;;
  *) printf 'Je potřeba standardní Godot 4.7 stable a jeho Android šablony.\n' >&2; exit 1 ;;
esac

keystore=${LEMMINGS_KEYSTORE_PATH:-"$HOME/.local/share/godot/keystores/debug.keystore"}
expected=$(grep -v '^#' scripts/android_signing.txt | tr -d '[:space:]')
allow_new=${LEMMINGS_ALLOW_NEW_KEY:-0}

if [ ! -f "$keystore" ] && [ "$allow_new" != "1" ]; then
  printf 'Chybí podpisový klíč %s.\nAPK by dostalo nový podpis a nešlo by nainstalovat jako aktualizace.\n' \
    "$keystore" >&2
  exit 1
fi
if [ -f "$keystore" ]; then
  actual=$(keytool -list -v -keystore "$keystore" -storepass android -alias androiddebugkey \
    2>/dev/null | sed -n 's/.*SHA256: *//p' | tr -d ':' | tr '[:upper:]' '[:lower:]')
  if [ "$actual" != "$expected" ] && [ "$allow_new" != "1" ]; then
    printf 'Podpisový klíč nesedí (%s, čekán %s).\nAPK by nešlo nainstalovat jako aktualizace.\n' \
      "$actual" "$expected" >&2
    exit 1
  fi
fi

mkdir -p build/android
"$godot_bin" --headless --editor --path "$repo_root" --import
"$godot_bin" --headless --path "$repo_root" --export-debug Android

# Kontrola hotového APK: podepsané očekávaným certifikátem.
if command -v apksigner >/dev/null 2>&1; then
  signed=$(apksigner verify --print-certs build/android/Paperlings-Android.apk 2>/dev/null \
    | sed -n 's/^Signer #1 certificate SHA-256 digest: //p')
  if [ "$signed" != "$expected" ] && [ "$allow_new" != "1" ]; then
    printf 'APK je podepsané jiným certifikátem (%s).\n' "$signed" >&2
    exit 1
  fi
  printf 'Podpis APK sedí: %s\n' "$signed"
fi
