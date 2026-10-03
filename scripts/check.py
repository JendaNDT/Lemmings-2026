#!/usr/bin/env python3
"""Přenosné kontroly v dočasné kopii; import neznečistí pracovní strom."""

import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

from check_assets import verify as verify_assets

ROOT = Path(__file__).resolve().parents[1]
ERROR = re.compile(r"^(?:(?:SCRIPT|SHADER) )?ERROR:", re.MULTILINE)
ANSI = re.compile(r"\x1b\[[0-9;]*m")


def executable(value):
    found = shutil.which(value)
    if not found:
        raise RuntimeError(f"Chybí nástroj: {value}")
    # Zachovat název symlinku: některé wrappery podle něj volí parser/linter.
    return str(Path(found).absolute())


def run(label, command, project, logs, *, success=None, timeout=120):
    env = {**os.environ, "GODOT_SILENCE_ROOT_WARNING": "1", "NO_COLOR": "1"}
    try:
        result = subprocess.run(
            command, cwd=project, env=env, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, timeout=timeout, check=False,
        )
        output = result.stdout.decode("utf-8", errors="replace")
    except subprocess.TimeoutExpired as exc:
        output = (exc.stdout or b"").decode("utf-8", errors="replace")
        (logs / f"{label}.log").write_text(output, encoding="utf-8")
        raise RuntimeError(f"{label}: překročen limit {timeout} s") from exc
    (logs / f"{label}.log").write_text(output, encoding="utf-8")
    clean = ANSI.sub("", output)
    if result.returncode or ERROR.search(clean) or (success and not re.search(success, clean)):
        print(clean[-8000:])
        raise RuntimeError(f"{label}: kontrola selhala (kód {result.returncode})")
    print(f"[OK] {label}", flush=True)
    return clean


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--benchmark", action="store_true", help="změřit také zátěž 200 lumíků")
    args = parser.parse_args()
    verify_assets(ROOT)
    godot = executable(args.godot)
    logs = ROOT / "build" / "checks"
    logs.mkdir(parents=True, exist_ok=True)
    # Povolená je řada 4.7 stable včetně opravných vydání (4.7.1 …); jiná
    # hlavní/vedlejší verze, beta či rc kontrolu záměrně neprojde.
    version = run("godot-version", [godot, "--version"], ROOT, logs,
                  success=r"^4\.7(?:\.[1-9]\d*)?\.stable\.")
    print(version.strip())
    with tempfile.TemporaryDirectory(prefix="lemmings-check-") as directory:
        project = Path(directory) / "project"
        shutil.copytree(ROOT, project, ignore=shutil.ignore_patterns(
            ".git", ".godot", "build", "docs", ".venv", "__pycache__",
        ))
        files = sorted(str(path.relative_to(project)) for path in project.rglob("*.gd"))
        suites = sorted(project.glob("tests/test_*.gd"))
        if not files or not suites:
            raise RuntimeError("Nebyly nalezeny GDScripty nebo testovací sady.")
        gdcheck = [sys.executable, str(project / "scripts" / "gdcheck.py")]
        run("gdparse", [*gdcheck, "parse", *files], project, logs)
        run("gdlint", [*gdcheck, "lint", *files], project, logs)
        base = [godot, "--headless", "--path", str(project)]
        run("import", [*base, "--editor", "--import"], project, logs)
        if args.benchmark:
            suites.append(project / "tests" / "benchmark_sim.gd")
            suites.append(project / "tests" / "benchmark_3d.gd")
        total = 0
        for suite in suites:
            output = run(suite.stem, [
                *base, "--fixed-fps", "60", "--script", f"res://tests/{suite.name}",
            ], project, logs, success=r"(?m)^VÝSLEDEK: OK(?:\s|$)")
            count = len(re.findall(r"(?m)^\[OK\] ", output))
            if not count or re.search(r"(?m)^\[CHYBA\]", output):
                raise RuntimeError(f"{suite.stem}: prázdná nebo neúspěšná sada")
            total += count
        run("startup", [*base, "--fixed-fps", "60", "--quit-after", "180"], project, logs)
    print(f"Hotovo: {len(files)} GDScriptů, {len(suites)} sad, {total} kontrol. Logy: {logs}")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError) as error:
        print(f"CHYBA: {error}", file=sys.stderr)
        sys.exit(1)
