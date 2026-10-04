#!/usr/bin/env python3
"""Vydání Paperlings: jedna verze pro všechny platformy, exporty, balíčky a součty.

Verze je jen v project.godot (`application/config/version`), např. 1.0.0
nebo předběžná 1.0.0-rc1. Z ní se odvodí čísla pro Android, Windows a macOS.

  python scripts/release.py info [--field version]   # verze, versionCode, soubory
  python scripts/release.py sync                     # verze do exportních předvoleb
  python scripts/release.py build [--platforms android,windows,macos]
                                  [--skip-check] [--android-apk SOUBOR]

`build` = sync, celá kontrola (scripts/check.py), exporty, balíčky do
build/release/<verze>/ (APK, zip pro Windows a macOS s licencí a návodem,
THIRD_PARTY_NOTICES.txt, SHA256SUMS.txt) a jejich ověření. Android se podepisuje
klíčem z prostředí (scripts/export_android.sh); v GitHub Actions se místo
exportu předá hotové APK z větve pro stažení (`--android-apk`).
Poznámky k vydání musí být v docs/vydani/<verze>.md.
"""

from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
NAME = "Paperlings"
VERSION_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)(?:-rc(\d+))?$")
ZIP_TIME = (2026, 1, 1, 0, 0, 0)
DOCS = {"LICENSE.txt": ROOT / "LICENSE.txt", "NAVOD.txt": ROOT / "docs" / "NAVOD.md"}


def version() -> str:
    text = (ROOT / "project.godot").read_text(encoding="utf-8")
    match = re.search(r'^config/version="([^"]+)"$', text, re.M)
    if match is None or VERSION_RE.match(match.group(1)) is None:
        raise SystemExit("project.godot: verze musí mít tvar X.Y.Z nebo X.Y.Z-rcN")
    return match.group(1)


def numbers(ver: str) -> dict:
    """Odvozená čísla: versionCode Androidu roste s každou verzí (rc < finální)."""
    major, minor, patch, rc = VERSION_RE.match(ver).groups()
    build = int(rc) if rc else 100
    base = f"{major}.{minor}.{patch}"
    return {"version": ver, "android_code": int(major) * 1_000_000 + int(minor) * 10_000
            + int(patch) * 100 + (int(rc) if rc else 99),
            "short": base, "build": f"{base}.{build}", "prerelease": rc is not None}


def files(ver: str) -> dict:
    return {"android": f"{NAME}-{ver}-Android.apk", "windows": f"{NAME}-{ver}-Windows.zip",
            "macos": f"{NAME}-{ver}-macOS.zip"}


def sync(ver: str) -> None:
    n = numbers(ver)
    path = ROOT / "export_presets.cfg"
    text = path.read_text(encoding="utf-8")
    values = {"version/code": str(n["android_code"]), "version/name": f'"{ver}"',
              "application/file_version": f'"{n["build"]}"',
              "application/product_version": f'"{n["build"]}"',
              "application/short_version": f'"{n["short"]}"', "application/version": f'"{n["build"]}"'}
    for key, value in values.items():
        text, count = re.subn(rf"^{re.escape(key)}=.*$", f"{key}={value}", text, flags=re.M)
        if count != 1:
            raise SystemExit(f"export_presets.cfg: klíč {key} nalezen {count}×, čekán 1×")
    path.write_text(text, encoding="utf-8")
    print(f"Předvolby: {ver}, Android versionCode {n['android_code']}, Windows/macOS {n['build']}")


def run(*cmd: str) -> None:
    print("$", " ".join(cmd), flush=True)
    subprocess.run(cmd, cwd=ROOT, check=True)


def godot() -> str:
    return os.environ.get("GODOT_BIN", "godot")


def zip_add(out: zipfile.ZipFile, name: str, data: bytes, mode: int = 0o644) -> None:
    info = zipfile.ZipInfo(name, ZIP_TIME)
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = (0o100000 | mode) << 16
    out.writestr(info, data)


def package(ver: str, platforms: list[str], android_apk: Path | None) -> Path:
    dest = ROOT / "build" / "release" / ver
    shutil.rmtree(dest, ignore_errors=True)
    dest.mkdir(parents=True)
    names = files(ver)
    notices = dest / "THIRD_PARTY_NOTICES.txt"
    run(godot(), "--headless", "--path", str(ROOT), "--script",
        "res://scripts/third_party_notices.gd", "--", str(notices))
    docs = {name: path.read_bytes() for name, path in DOCS.items()}
    docs["THIRD_PARTY_NOTICES.txt"] = notices.read_bytes()
    if "android" in platforms or android_apk is not None:
        source = android_apk or ROOT / "build" / "android" / f"{NAME}-Android.apk"
        shutil.copyfile(source, dest / names["android"])
    if "windows" in platforms:
        folder = f"{NAME}-{ver}-Windows/"
        with zipfile.ZipFile(dest / names["windows"], "w") as out:
            zip_add(out, folder + f"{NAME}.exe",
                    (ROOT / "build" / "windows" / f"{NAME}.exe").read_bytes(), 0o755)
            for name, data in docs.items():
                zip_add(out, folder + name, data)
    if "macos" in platforms:
        with zipfile.ZipFile(ROOT / "build" / "macos" / f"{NAME}-macOS.zip") as src, \
                zipfile.ZipFile(dest / names["macos"], "w") as out:
            for info in src.infolist():
                copy = zipfile.ZipInfo(info.filename, ZIP_TIME)
                copy.compress_type = zipfile.ZIP_DEFLATED
                copy.external_attr = info.external_attr
                out.writestr(copy, src.read(info))
            for name, data in docs.items():
                zip_add(out, name, data)
    sums = []
    for path in sorted(dest.iterdir()):
        if path.name != "SHA256SUMS.txt":
            sums.append(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}")
    (dest / "SHA256SUMS.txt").write_text("\n".join(sums) + "\n", encoding="utf-8")
    return dest


def verify(ver: str, dest: Path) -> list[str]:
    """Kontrola hotových balíčků; vrací seznam problémů."""
    problems = []
    names = files(ver)
    apk = dest / names["android"]
    if apk.exists() and shutil.which("apksigner"):
        expected = "".join(line.strip() for line in (ROOT / "scripts" / "android_signing.txt")
                           .read_text().splitlines() if not line.startswith("#"))
        certs = subprocess.run(["apksigner", "verify", "--print-certs", str(apk)],
                               capture_output=True, text=True).stdout
        if f"SHA-256 digest: {expected}" not in certs:
            problems.append("APK není podepsané očekávaným certifikátem")
    windows = dest / names["windows"]
    if windows.exists():
        with zipfile.ZipFile(windows) as z:
            exe = z.getinfo(f"{NAME}-{ver}-Windows/{NAME}.exe")
            if exe.file_size < 50_000_000:
                problems.append("Windows: Paperlings.exe je podezřele malý")
    macos = dest / names["macos"]
    if macos.exists():
        with zipfile.ZipFile(macos) as z:
            plist = z.read(f"{NAME}.app/Contents/Info.plist").decode()
            if f"<string>{numbers(ver)['short']}</string>" not in plist or NAME not in plist:
                problems.append("macOS: Info.plist nemá název nebo verzi")
            if "LICENSE.txt" not in z.namelist():
                problems.append("macOS: chybí licence")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", choices=["info", "sync", "build"])
    parser.add_argument("--field", choices=["version", "android_code", "prerelease"])
    parser.add_argument("--platforms", default="android,windows,macos")
    parser.add_argument("--skip-check", action="store_true")
    parser.add_argument("--android-apk", type=Path)
    args = parser.parse_args()
    ver = version()
    if args.command == "info":
        if args.field:
            print(numbers(ver)[args.field])
        else:
            print(numbers(ver), files(ver))
        return 0
    sync(ver)
    if args.command == "sync":
        return 0
    platforms = [p for p in args.platforms.split(",") if p]
    if not (ROOT / "docs" / "vydani" / f"{ver}.md").exists():
        raise SystemExit(f"Chybí poznámky k vydání docs/vydani/{ver}.md")
    if not args.skip_check:
        run(sys.executable, "scripts/check.py")
    if "android" in platforms and args.android_apk is None:
        run("bash", "scripts/export_android.sh")
    for platform_name in ("windows", "macos"):
        if platform_name in platforms:
            run("bash", "scripts/export_desktop.sh", platform_name)
    dest = package(ver, platforms, args.android_apk)
    problems = verify(ver, dest)
    for path in sorted(dest.iterdir()):
        print(f"{path.stat().st_size / 1048576:8.1f} MiB  {path.name}")
    for problem in problems:
        print("CHYBA:", problem)
    print("VYDÁNÍ", "CHYBA" if problems else "OK", ver, dest)
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
