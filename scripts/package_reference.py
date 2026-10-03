#!/usr/bin/env python3
"""Samostatný projekt Godotu s výtvarným výřezem, bez cache a bez herní simulace."""
import hashlib
import json
from pathlib import Path
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'build/reference-v3/standalone'
ARCHIVE = ROOT / 'build/reference-v3/Lemmings-Modelinovy-vyrez-v3.zip'


def main():
    receipt = json.loads((ROOT / 'assets/reference_v3.lock.json').read_text())
    files = [entry['path'] for entry in receipt['files']]
    files += ['assets/reference_v3.lock.json', 'assets/art_v2/ui/Nunito.ttf',
              'assets/art_v2/ui/OFL.txt', 'assets/clay/LICENSE.txt',
              'assets/clay/models/clay_pickaxe.glb', 'assets/clay/models/clay_brick.glb']
    files += [str(p.relative_to(ROOT)) for p in sorted((ROOT / 'studies').glob('*')) if p.is_file()]
    for entry in receipt['files']:
        assert hashlib.sha256((ROOT / entry['path']).read_bytes()).hexdigest() == entry['sha256']
    DEST.mkdir(parents=True, exist_ok=True)
    for name in files:
        source = ROOT / name
        assert source.resolve().is_relative_to(ROOT)
        target = DEST / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    project = '''config_version=5

[application]
config/name="Modelínový svět — výtvarný výřez"
run/main_scene="res://studies/clay_reference.tscn"
config/features=PackedStringArray("4.7", "Forward Plus")

[display]
window/size/viewport_width=1600
window/size/viewport_height=900
window/size/window_width_override=1280
window/size/window_height_override=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[rendering]
renderer/rendering_method="forward_plus"
textures/vram_compression/import_etc2_astc=true
anti_aliasing/quality/msaa_3d=2
'''
    (DEST / 'project.godot').write_text(project)
    (DEST / 'README.txt').write_text('''MODELÍNOVÝ SVĚT — výtvarný výřez v3

1. Rozbal celý ZIP.
2. V Godotu 4.7 nebo 4.7.1 zvol Import a vyber project.godot z tohoto balíčku.
3. Počkej na import modelů, pak stiskni F5.

Mezerník: pauza animace. Tab: přepnutí detailu. R: opakování od začátku.
Blender není ke spuštění potřeba; jeho editovatelné zdroje jsou přiložené.

Toto je samostatná výtvarná studie. Nejde o novou verzi celé hry ani o APK.
Terén je autorská statická geometrie, odtržení hrudky je krátká řízená
deformace. Napojení na dynamickou masku kopání ve hře bude další práce.

Projekt byl importován a skutečně vykreslen Godotem 4.7 na Linuxu.
Nativní spuštění a výkon na macOS ani Androidu tím nejsou ověřené.
Původní mockup zůstává cílem; předání studie neznamená schválení vzhledu.

Modely a zdroje: assets/reference_v3/LICENSE.txt a provenance.json.
Písmo Nunito: SIL OFL 1.1, assets/art_v2/ui/OFL.txt.
''')
    files += ['project.godot', 'README.txt']
    with zipfile.ZipFile(ARCHIVE, 'w', zipfile.ZIP_DEFLATED) as archive:
        for name in sorted(set(files)):
            archive.write(DEST / name, 'Lemmings-Modelinovy-vyrez-v3/' + name)
    with zipfile.ZipFile(ARCHIVE) as archive:
        assert archive.testzip() is None
        for entry in receipt['files']:
            data = archive.read('Lemmings-Modelinovy-vyrez-v3/' + entry['path'])
            assert hashlib.sha256(data).hexdigest() == entry['sha256']
    print(ARCHIVE)
    print('SHA-256:', hashlib.sha256(ARCHIVE.read_bytes()).hexdigest())


if __name__ == '__main__':
    main()
