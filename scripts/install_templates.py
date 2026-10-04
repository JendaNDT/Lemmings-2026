#!/usr/bin/env python3
"""Ověřené oficiální exportní šablony Godot 4.7 (Windows, macOS, Linux, Android).

Stáhne `Godot_v4.7-stable_export_templates.tpz` (nebo použije `--archive`),
ověří SHA-512 z oficiálního vydání a rozbalí jen potřebné šablony do složky,
kde je Godot hledá (Linux `~/.local/share/godot/export_templates/4.7.stable`,
macOS `~/Library/Application Support/Godot/export_templates/4.7.stable`).
Existující soubor se přepíše jen tehdy, když se liší od oficiálního.
"""

import argparse
import hashlib
import os
from pathlib import Path
import platform
import tempfile
import urllib.request
import zipfile

URL = ("https://github.com/godotengine/godot-builds/releases/download/4.7-stable/"
       "Godot_v4.7-stable_export_templates.tpz")
SHA512 = ("1035dfde4edcc2472bb0c0b9610ce3ee9302642c2b9957e9066372f9f6bb759ab250c8887551a66f0"
          "bc5f51bbd9a58bb45e33a0f29844e97615a9b1138c1120e")
NEEDED = ["version.txt", "windows_release_x86_64.exe", "windows_debug_x86_64.exe", "macos.zip",
          "linux_release.x86_64", "linux_debug.x86_64", "android_release.apk", "android_debug.apk"]


def default_target() -> Path:
    if platform.system() == "Darwin":
        base = Path.home() / "Library/Application Support/Godot"
    elif platform.system() == "Windows":
        base = Path(os.environ["APPDATA"]) / "Godot"
    else:
        base = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "godot"
    return base / "export_templates" / "4.7.stable"


def sha512(path: Path) -> str:
    digest = hashlib.sha512()
    with path.open("rb") as source:
        while chunk := source.read(1 << 20):
            digest.update(chunk)
    return digest.hexdigest()


def install(archive: Path, target: Path) -> list[str]:
    if sha512(archive) != SHA512:
        raise RuntimeError("SHA-512 šablon neodpovídá oficiálnímu vydání; nic nebylo rozbaleno.")
    target.mkdir(parents=True, exist_ok=True)
    written = []
    with zipfile.ZipFile(archive) as package:
        for name in NEEDED:
            data = package.read("templates/" + name)
            path = target / name
            if path.exists() and path.read_bytes() == data:
                continue
            path.write_bytes(data)
            if not name.endswith((".txt", ".zip", ".apk")):
                path.chmod(0o755)
            written.append(name)
    if (target / "version.txt").read_text().strip() != "4.7.stable":
        raise RuntimeError("Šablony nejsou pro Godot 4.7 stable.")
    return written


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, help="již stažený oficiální .tpz")
    parser.add_argument("--target", type=Path, default=default_target())
    args = parser.parse_args()
    if args.archive is not None:
        written = install(args.archive, args.target)
    else:
        with tempfile.TemporaryDirectory(prefix="godot-templates-") as temp:
            archive = Path(temp) / "templates.tpz"
            with urllib.request.urlopen(URL, timeout=120) as source, archive.open("wb") as output:
                while chunk := source.read(1 << 20):
                    output.write(chunk)
            written = install(archive, args.target)
    print(f"Šablony v {args.target}: nově zapsáno {len(written)} ({', '.join(written) or 'nic'})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
