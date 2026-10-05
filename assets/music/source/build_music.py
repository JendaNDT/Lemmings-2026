#!/usr/bin/env python3
"""Připraví čtyři dodané WAVy pro Paperlings, originály nemění.

python assets/music/source/build_music.py --source-dir /cesta/k/wav
Výstup nejdřív vzniká v samostatné složce (--output-dir), ne v projektu.
K převodu je potřeba ffmpeg/ffprobe s libvorbis. Po kontrole se balíček
přenese do assets/music/ a ověří proti assets/music.lock.json.
"""

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import shutil
import subprocess


SOURCES = [
    ("Lemmings 1 (1).wav", "3e7e085a03f13ba2e10dd4496325dd8e33d5fabfac2863b421d087bfd8938370"),
    ("Lemmings 1.wav", "a005e0a07ec786221689e50c8fa2916d4d5a827a0c3af78b5f98445182d490e7"),
    ("Lemmings 2 (1).wav", "ec4a3276a775269edaab36b1feb873a98d7823a75fd1000122b5f7368b745ed9"),
    ("Lemmings 2.wav", "6104f728f416ad42ce44c52dbe0644be9aa6011d077584d549b6a8a9153dcdb8"),
]
LICENSE = "LicenseRef-UserProvided-Paperlings"
TERMS = """LicenseRef-UserProvided-Paperlings

Čtyři hudební nahrávky poskytl Jenda v této konverzaci dne 5. října 2026
s výslovným zadáním vložit je do Paperlings a střídat po jednotlivých misích.
Soubory jsou použity v rozsahu tohoto zadání. Vlastnictví ani jméno
skladatele nebyly uvedeny; tento záznam je nevymýšlí. Původní práva
k nahrávkám zůstávají jejich držitelům. Tento projekt neuděluje novou
licenci k samostatnému použití nebo šíření nahrávek mimo hru.

Původní názvy a SHA-256 souborů jsou v provenance.json. Názvy souborů
nejsou tvrzením o původu hudby z konkrétní hry. Převod mění jen formát,
hlasitost a krátké technické náběhy/dozvuky, nikoli autorství nahrávek.
"""


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def probe(path):
    return json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_entries",
        "format=duration:stream=codec_name,sample_rate,channels", "-of", "json", str(path),
    ]))


def measurements(path):
    result = subprocess.run([
        "ffmpeg", "-hide_banner", "-nostats", "-i", str(path),
        "-af", "loudnorm=I=-21:TP=-2:LRA=11:print_format=json", "-f", "null", "-",
    ], capture_output=True, text=True, check=True)
    # Novější FFmpeg může za JSON dopsat souhrn muxeru.
    return json.JSONDecoder().raw_decode(result.stderr[result.stderr.rfind("{"):])[0]


def convert(index, folder, output):
    name, expected = SOURCES[index]
    source = folder / name
    assert digest(source) == expected, f"Jiný původní soubor: {name}"
    original = probe(source)
    length = float(original["format"]["duration"])
    measured = measurements(source)
    normalize = ("loudnorm=I=-21:TP=-2:LRA=11:linear=true"
                 f":measured_I={measured['input_i']}:measured_TP={measured['input_tp']}"
                 f":measured_LRA={measured['input_lra']}:measured_thresh={measured['input_thresh']}"
                 f":offset={measured['target_offset']}")
    target = output / f"track_{index + 1:02d}.ogg"
    args = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-nostdin", "-n",
            "-i", str(source), "-map_metadata", "-1", "-vn", "-af",
            normalize + f",afade=t=in:d=0.025,afade=t=out:st={length - 0.025:.6f}:d=0.025",
            "-ar", "48000", "-ac", "2", "-c:a", "libvorbis", "-q:a", "5", str(target)]
    subprocess.run(args, check=True)
    encoded = probe(target)
    stream = encoded["streams"][0]
    assert stream["codec_name"] == "vorbis" and stream["channels"] == 2
    assert abs(float(encoded["format"]["duration"]) - length) < 0.1
    # Ověří skutečné dekódování celé skladby, nikoli jen hlavičku.
    subprocess.run(["ffmpeg", "-v", "error", "-xerror", "-i", str(target),
                    "-f", "null", "-"], check=True)
    final = measurements(target)
    assert abs(float(final["input_i"]) + 21) < 1.0, final
    assert float(final["input_tp"]) <= -0.5, final
    return {"slot": index, "source_name": name, "source_sha256": expected,
            "source_bytes": source.stat().st_size, "file": target.name,
            "sha256": digest(target), "bytes": target.stat().st_size,
            "duration_seconds": length, "source_audio": original,
            "original_measurement": measured, "encoded_measurement": final,
            "transform": "Two-pass -21 LUFS / -2 dBTP, stereo 48 kHz Vorbis q5, 25 ms fades",
            "campaign_missions": list(range(index + 1, 25, 4))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=False)
    with ThreadPoolExecutor(max_workers=2) as pool:
        tracks = list(pool.map(lambda i: convert(i, args.source_dir, args.output_dir), range(4)))
    (args.output_dir / "LICENSE.txt").write_text(TERMS, encoding="utf-8")
    provenance = {"package": "paperlings-music", "version": "1.0.0", "date": "2026-10-05",
                  "license": LICENSE, "source": "Four user-supplied WAV attachments",
                  "authorization": "User requested integrating these recordings into Paperlings",
                  "composer": "not supplied", "generation_provider": None,
                  "ffmpeg": subprocess.check_output(["ffmpeg", "-version"], text=True).splitlines()[0],
                  "policy": {"format": "Ogg Vorbis", "sample_rate": 48000, "channels": 2,
                             "target_lufs": -21, "true_peak_target_db": -2,
                             "max_total_bytes": 20000000, "original_wavs_modified": False},
                  "tracks": tracks}
    assert sum(t["bytes"] for t in tracks) < provenance["policy"]["max_total_bytes"]
    (args.output_dir / "provenance.json").write_text(
        json.dumps(provenance, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    code = args.output_dir / "source"
    code.mkdir()
    shutil.copyfile(__file__, code / "build_music.py")
    files = [{"path": str(p.relative_to(args.output_dir)), "sha256": digest(p)}
             for p in sorted(args.output_dir.rglob("*")) if p.is_file()]
    (args.output_dir.parent / (args.output_dir.name + ".manifest.json")).write_text(
        json.dumps({"package": "paperlings-music", "license": LICENSE, "files": files}, indent=2) + "\n")
    print(json.dumps({"tracks": [{"file": t["file"], "bytes": t["bytes"],
                                 "duration": t["duration_seconds"],
                                 "LUFS": t["encoded_measurement"]["input_i"]} for t in tracks]}, indent=2))


if __name__ == "__main__":
    main()
