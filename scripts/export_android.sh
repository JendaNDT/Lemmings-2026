#!/usr/bin/env bash
# Samostatný Paperlings od rc2 (cool.jenda.paperlings), nová instalace schválená
# autorem 5. 10. 2026. Nový soukromý klíč se uchovává mimo Git; jeho veřejný
# otisk musí souhlasit před exportem i v hotovém release APK.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"
godot_bin=${GODOT_BIN:-godot}
case "$("$godot_bin" --version)" in
  4.7.stable.*|4.7.*.stable.*) ;;
  *) printf 'Je potřeba standardní Godot 4.7 stable a jeho Android šablony.\n' >&2; exit 1 ;;
esac

keystore=${PAPERLINGS_KEYSTORE_PATH:-"${XDG_DATA_HOME:-$HOME/.local/share}/godot/keystores/paperlings-release.p12"}
password_file=${PAPERLINGS_KEYSTORE_PASSWORD_FILE:-"$keystore.password"}
key_alias=${PAPERLINGS_KEYSTORE_ALIAS:-paperlings}
apksigner_bin=${APKSIGNER_BIN:-apksigner}
expected=$(sed '/^#/d' scripts/android_signing.txt | tr -d '[:space:]')

if [ ! -r "$keystore" ] || [ ! -r "$password_file" ]; then
  printf 'Chybí soukromý podpisový klíč nebo soubor s jeho heslem. Nový klíč automaticky nevytvářím.\n' >&2
  exit 1
fi
if ! command -v "$apksigner_bin" >/dev/null 2>&1; then
  printf 'Chybí apksigner z Android build-tools; nastav APKSIGNER_BIN.\n' >&2
  exit 1
fi
if ! certificate=$(keytool -list -v -keystore "$keystore" \
  -storepass:file "$password_file" -alias "$key_alias" 2>/dev/null); then
  printf 'Podpisový klíč nelze otevřít. Ověř lokální nastavení klíče a hesla.\n' >&2
  exit 1
fi
actual=$(printf '%s\n' "$certificate" | sed -n 's/.*SHA256: *//p' | tr -d ':' | tr '[:upper:]' '[:lower:]')
if [ "$actual" != "$expected" ]; then
  printf 'Podpisový klíč neodpovídá Paperlings. Export zastaven, aby další verze měla stejný podpis.\n' >&2
  exit 1
fi

# Oficiální proměnné exportéru Godotu: heslo se nikdy nezapisuje do předvoleb,
# nevypisuje; exportéru je předané v prostředí procesu.
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$keystore"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$key_alias"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=$(cat "$password_file")
mkdir -p build/android
touch build/.gdignore
"$godot_bin" --headless --editor --path "$repo_root" --import
"$godot_bin" --headless --path "$repo_root" --export-release Android
unset GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD

signed=$("$apksigner_bin" verify --print-certs build/android/Paperlings-Android.apk \
  | sed -n 's/^Signer #1 certificate SHA-256 digest: //p')
if [ "$signed" != "$expected" ]; then
  printf 'Hotové APK nemá očekávaný podpis. Nepublikovat.\n' >&2
  exit 1
fi
printf 'Release APK je ověřené a podepsané klíčem Paperlings.\n'
