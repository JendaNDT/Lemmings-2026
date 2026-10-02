#!/usr/bin/env python3
"""Ověřený standardní Godot 4.7 pro lokální kontroly a CI (bez exportních šablon)."""

import argparse
import hashlib
from pathlib import Path
import platform
import sys
import tempfile
import urllib.request
import zipfile

RELEASE = "https://github.com/godotengine/godot-builds/releases/download/4.7-stable/"
PACKAGES = {
    "Linux": (
        "Godot_v4.7-stable_linux.x86_64.zip",
        "b639ca9c1ddea39bb3df89bd5283a51ca6047467abe6b25e9436566f2b2082ede6330"
        "25073989ecf39c7d5d3c2493d80ea13e3af6dd5e261bbf89e462d6d2214",
        "Godot_v4.7-stable_linux.x86_64",
    ),
    "Darwin": (
        "Godot_v4.7-stable_macos.universal.zip",
        "0d5d635e6d78d4c2b1286586ca62af249609c2f70815b35437049f08476714d08b913fa"
        "af8c10f37313c932ee24c4f87a829899c84fa248f788fb612b8f79229",
        "Godot.app/Contents/MacOS/Godot",
    ),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, default=Path("build/tools/godot"))
    parser.add_argument("--archive", type=Path, help="použít již stažený oficiální ZIP")
    args = parser.parse_args()
    system = platform.system()
    if system not in PACKAGES or (system == "Linux" and platform.machine() not in ("x86_64", "AMD64")):
        raise RuntimeError("Instalátor podporuje Linux x86_64 a univerzální macOS.")
    filename, expected, binary = PACKAGES[system]
    destination = args.directory.resolve()
    with tempfile.TemporaryDirectory(prefix="godot-download-") as temp:
        archive = args.archive or Path(temp) / filename
        if args.archive is None:
            with urllib.request.urlopen(RELEASE + filename, timeout=60) as source:
                with archive.open("wb") as output:
                    while chunk := source.read(1024 * 1024):
                        output.write(chunk)
        digest = hashlib.sha512()
        with archive.open("rb") as source:
            while chunk := source.read(1024 * 1024):
                digest.update(chunk)
        if digest.hexdigest() != expected:
            raise RuntimeError("SHA-512 neodpovídá oficiálnímu archivu; nic nebylo rozbaleno.")
        with zipfile.ZipFile(archive) as package:
            package.extractall(destination)
        executable = destination / binary
        executable.chmod(executable.stat().st_mode | 0o111)
    print(executable)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, zipfile.BadZipFile) as error:
        print(f"CHYBA: {error}", file=sys.stderr)
        sys.exit(1)
