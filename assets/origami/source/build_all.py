"""Sestaví celou origami sadu a zapíše původ a kontrolní součty.

Použití z kořene repozitáře:
    python assets/origami/source/build_all.py          # vygeneruje a zapíše manifest
    python assets/origami/source/build_all.py --check  # jen ověří, že generátor dává stejné soubory

Generátory jsou deterministické (pevné seedy). Soubory .import patří Godotu,
manifest je nesleduje; kontrolu manifestu dělá scripts/check_assets.py.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import platform
import shutil
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
PACKAGE = HERE.parent
REPO = PACKAGE.parents[1]
sys.path.insert(0, str(HERE))

import build_backgrounds  # noqa: E402
import build_character  # noqa: E402
import build_icon  # noqa: E402
import build_props  # noqa: E402
import build_themes  # noqa: E402
import build_ui  # noqa: E402

GENERATED = ["layers", "paper", "props", "actor", "ui", "icon", "source/previews"]


def generate(out: Path) -> None:
    build_backgrounds.build(out)
    build_themes.build(out)
    build_props.build(out)
    build_character.build(out)
    build_ui.build(out)
    build_icon.build(out)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def tracked_files() -> list[Path]:
    files = []
    for path in sorted(PACKAGE.rglob("*")):
        if path.is_dir() or path.suffix == ".import" or "__pycache__" in path.parts:
            continue
        files.append(path)
    return files


def write_manifest() -> None:
    import numpy
    import PIL
    import scipy
    sources = {p.name: digest(p) for p in sorted(HERE.glob("*.py"))}
    provenance = {
        "package": "lemmings-origami-art",
        "version": "1.0.0",
        "game_version": "0.5.0",
        "reference": "docs/images/mockup-origami-prvni-kroky.png (jediná přijatá předloha, jen vizuální vodítko)",
        "authoring": "Procedurálně generováno vlastními skripty v assets/origami/source "
                     "(Python + NumPy/Pillow/SciPy, pevné seedy); ikony jsou ručně psané SVG.",
        "inputs": "Žádné cizí obrázky, fonty ani modely. Z mockupu nebyly vyřezány pixely; "
                  "převzaty jsou pouze barvy (změřené mediánem) a výtvarné principy.",
        "tools": {"python": platform.python_version(), "numpy": numpy.__version__,
                  "pillow": PIL.__version__, "scipy": scipy.__version__},
        "generator_sha256": sources,
        "units": {
            "layers": "1200 px textury = výška obrazovky při zoomu 1×; vodorovně navazující dlaždice",
            "actor": "32 px atlasu = 1 logický pixel simulace; postava je vysoká 10 logických px",
            "props": "24 px textury = 1 logický pixel; kotvy v props/props.json",
        },
        "contents": {
            "layers": "obloha se sluncem, pět samostatných mraků a tři pózy letícího ptáčka "
                      "(sky.json), hory, střední pás s vesnicí, viaduktem a vodopádem, "
                      "blízký les s řekou, tři trsy rostlin popředí; ve složkách les, sopka "
                      "a bourka krajiny kapitol II–IV (skalní město a jedle, sopka s kouřem "
                      "a jezerem, sněžné štíty s bouřkovými mraky a chatami), ve složce "
                      "podzemi jeskyně a důl pro patrové mise (strop s krápníky, sloupy, "
                      "výdřeva s lucernami, žebříky, svítící krystaly, tři pózy netopýra)",
            "paper": "periodická vláknitá textura papíru a hladký šum pro trhané hrany",
            "props": "líheň (chatka, kůl, příčka žebříku, padací dvířka), východ (domek, vlajka)",
            "actor": "atlas dílů origami postavy, kostra, 13 animací a mapování stavů",
            "ui": "papírové panely HUDu (9 dílů), 8 ikon dovedností, ikony menu a zvuku (SVG)",
            "icon": "ikona aplikace Paperlings (postavička z dílů atlasu ve 3× rozlišení "
                    "na papírovém kopci): PNG 1024/256, Android 192 a adaptivní 432 "
                    "(pozadí, popředí a silueta), .ico a .icns",
            "source/previews": "kontaktní arch póz pro vizuální kontrolu (není ve hře)",
        },
        "limitations": [
            "Ruční ilustrace v předloze má bohatší detail; generátor ji nekopíruje 1:1.",
            "Vrstvy jsou navržené pro paralaxu se zoomem 1×–3,2×; mimo tento rozsah neověřeno.",
        ],
    }
    (PACKAGE / "provenance.json").write_text(json.dumps(provenance, indent=2, ensure_ascii=False) + "\n")
    files = [{"path": str(p.relative_to(REPO)), "sha256": digest(p)} for p in tracked_files()]
    lock = {"package": provenance["package"], "version": provenance["version"],
            "license": "LicenseRef-Paperlings-AllRightsReserved", "files": files}
    (REPO / "assets" / "origami.lock.json").write_text(json.dumps(lock, indent=2) + "\n")
    print(f"Manifest: {len(files)} souborů")


def check() -> int:
    """Vygeneruje sadu do dočasné složky a porovná ji s uloženými soubory."""
    with tempfile.TemporaryDirectory(prefix="origami-") as temp:
        out = Path(temp)
        generate(out)
        differences = []
        for path in sorted(out.rglob("*")):
            if path.is_dir():
                continue
            rel = path.relative_to(out)
            stored = PACKAGE / rel
            if not stored.exists() or digest(stored) != digest(path):
                differences.append(str(rel))
    for item in differences:
        print("ROZDÍL", item)
    print("Generátor odpovídá uloženým souborům." if not differences else "Generátor se liší.")
    return 1 if differences else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.check:
        return check()
    for folder in GENERATED:
        target = PACKAGE / folder
        if target.exists():
            for path in target.rglob("*"):
                if path.is_file() and path.suffix != ".import":
                    path.unlink()
    generate(PACKAGE)
    shutil.rmtree(HERE / "__pycache__", ignore_errors=True)
    write_manifest()
    return 0


if __name__ == "__main__":
    sys.exit(main())
