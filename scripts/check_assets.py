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


if __name__ == '__main__':
    verify(Path(__file__).resolve().parents[1])
