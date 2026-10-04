#!/usr/bin/env python3
"""Kontrola přenesených podkladů proti uloženému manifestu (bez Godotu)."""

import hashlib
import json
from pathlib import Path


def verify(root):
    fonts = json.loads((root / 'assets/fonts.lock.json').read_text())
    assert fonts['license'] == 'OFL-1.1'
    folder = (root / 'assets/fonts').resolve()
    listed = set()
    for entry in fonts['files']:
        path = root / entry['path']
        assert path.resolve().is_relative_to(folder)
        assert hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256'], entry['path']
        listed.add(path.resolve())
    # Písmo OFL se smí šířit jen s licencí.
    assert (folder / 'OFL.txt').resolve() in listed
    for path in folder.rglob('*'):
        if path.is_file() and path.suffix != '.import':
            assert path.resolve() in listed, f'mimo manifest: {path}'
    print(f"[OK] {len(fonts['files'])} soubory písma souhlasí s manifestem")
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
    audio = json.loads((root / 'assets/audio.lock.json').read_text())
    assert audio['license'] == 'LicenseRef-Lemmings2026-Project-Internal'
    folder = (root / 'assets/audio').resolve()
    listed = set()
    for entry in audio['files']:
        path = root / entry['path']
        assert path.resolve().is_relative_to(folder)
        assert hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256'], entry['path']
        listed.add(path.resolve())
    for path in folder.rglob('*'):
        if path.is_file() and path.suffix != '.import' and '__pycache__' not in path.parts:
            assert path.resolve() in listed, f'mimo manifest: {path}'
    print(f"[OK] {len(audio['files'])} zvukových podkladů souhlasí s manifestem")


if __name__ == '__main__':
    verify(Path(__file__).resolve().parents[1])
