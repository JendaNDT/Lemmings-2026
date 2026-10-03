#!/usr/bin/env python3
"""Kontrola přenesených podkladů proti uloženému manifestu (bez Godotu)."""

import hashlib
import json
from pathlib import Path


def verify(root):
    receipt = json.loads((root / 'assets/clay.lock.json').read_text())
    assert receipt['license'] == 'LicenseRef-Lemmings2026-Project-Internal'
    assert len(receipt['files']) == 50
    for entry in receipt['files']:
        path = root / entry['path']
        assert path.resolve().is_relative_to((root / 'assets/clay').resolve())
        assert hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256'], entry['path']
    print(f"[OK] {len(receipt['files'])} podkladů souhlasí s manifestem")
    art = json.loads((root / 'assets/art_v2.lock.json').read_text())
    assert art['license'] == 'LicenseRef-Lemmings2026-Project-Internal AND OFL-1.1'
    assert art['files']
    for entry in art['files']:
        path = root / entry['path']
        assert path.resolve().is_relative_to((root / 'assets/art_v2').resolve())
        assert hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256'], entry['path']
    print(f"[OK] {len(art['files'])} nových výtvarných podkladů souhlasí s manifestem")
    origami = json.loads((root / 'assets/origami.lock.json').read_text())
    assert origami['license'] == 'LicenseRef-Lemmings2026-Project-Internal'
    folder = (root / 'assets/origami').resolve()
    listed = set()
    for entry in origami['files']:
        path = root / entry['path']
        assert path.resolve().is_relative_to(folder)
        assert hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256'], entry['path']
        listed.add(path.resolve())
    # Každý soubor sady (kromě .import Godotu) musí být v manifestu.
    for path in folder.rglob('*'):
        if path.is_file() and path.suffix != '.import' and '__pycache__' not in path.parts:
            assert path.resolve() in listed, f'mimo manifest: {path}'
    print(f"[OK] {len(origami['files'])} origami podkladů souhlasí s manifestem")


if __name__ == '__main__':
    verify(Path(__file__).resolve().parents[1])
