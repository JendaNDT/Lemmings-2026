#!/usr/bin/env python3
"""Stejný gdparse/gdlint i v prostředí, kde domovská složka není zapisovatelná."""

from importlib.metadata import version
import sys
import tempfile

from gdtoolkit.parser import parser

if version("gdtoolkit") != "4.5.0":
    sys.exit("Nainstaluj verzi ze scripts/requirements-dev.txt.")
mode = sys.argv.pop(1)
if mode == "parse":
    from gdtoolkit.parser.__main__ import main
elif mode == "lint":
    from gdtoolkit.linter.__main__ import main
else:
    sys.exit("Použití: gdcheck.py [parse|lint] soubory...")

with tempfile.TemporaryDirectory(prefix="gdtoolkit-") as cache:
    # gdtoolkit 4.5.0 ignoruje XDG_CACHE_HOME. Měníme jen cestu cache, žádná pravidla.
    parser._cache_dirpath = cache
    main()
