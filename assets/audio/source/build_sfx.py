"""Papírové zvukové efekty a okolní smyčky pro Lemmings 2026.

Vše je syntetizované z šumu a tónů (NumPy + SciPy) s pevnými seedy, žádné
nahrávky ani cizí vzorky. Použití z kořene repozitáře:

    python assets/audio/source/build_sfx.py          # vygeneruje sadu a zapíše manifest
    python assets/audio/source/build_sfx.py --check  # jen ověří, že generátor dává stejné soubory

Efekty jsou mono 44,1 kHz, smyčky mono 22,05 kHz (16 bit PCM WAV). Hlasitost,
rozptyl výšky a omezení opakování pro hru jsou v sfx.json.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import platform
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np
from scipy import signal

HERE = Path(__file__).resolve().parent
PACKAGE = HERE.parent
REPO = PACKAGE.parents[1]
SR = 44100
LOOP_SR = 22050


# --- základní stavebnice -----------------------------------------------------

def samples(dur: float, sr: int = SR) -> np.ndarray:
    return np.arange(int(dur * sr)) / sr


def decay(t: np.ndarray, tau: float, attack: float = 0.002) -> np.ndarray:
    """Rychlý náběh a exponenciální dozvuk."""
    return np.minimum(t / max(attack, 1e-6), 1.0) * np.exp(-t / tau)


def filt(x: np.ndarray, kind: str, freq, order: int = 2, sr: int = SR) -> np.ndarray:
    sos = signal.butter(order, freq, btype=kind, fs=sr, output="sos")
    return signal.sosfilt(sos, x)


def tone(t: np.ndarray, freq, phase: float = 0.0) -> np.ndarray:
    """Sinus s proměnnou frekvencí (pole nebo číslo)."""
    f = np.broadcast_to(np.asarray(freq, dtype=np.float64), t.shape)
    return np.sin(2 * np.pi * np.cumsum(f) / SR + phase)


def place(out: np.ndarray, sound: np.ndarray, at: float, gain: float = 1.0, sr: int = SR) -> None:
    """Přimíchá zvuk od času `at`; konec se krátce dotlumí, aby neluplo uříznutí."""
    start = int(at * sr)
    end = min(len(out), start + len(sound))
    if end > start:
        part = sound[:end - start].copy()
        k = min(len(part), int(0.006 * sr))
        part[len(part) - k:] *= np.linspace(1, 0, k)
        out[start:end] += part * gain


def crumple(rng, dur: float, density: float, lo: float = 1500, hi: float = 9000,
            fade_tau: float = 0.12) -> np.ndarray:
    """Mačkaný papír: hustá řada drobných lupnutí s náhodnou silou."""
    n = int(dur * SR)
    clicks = np.zeros(n)
    t = samples(dur)
    rate = density * np.exp(-t / fade_tau)
    hits = rng.random(n) < rate / SR
    clicks[hits] = rng.uniform(-1, 1, hits.sum()) * rng.random(hits.sum()) ** 0.5
    body = filt(clicks, "band", [lo, min(hi, SR / 2 - 100)], order=2)
    return body + filt(rng.standard_normal(n), "band", [lo, min(hi, SR / 2 - 100)]) * 0.04 * decay(t, fade_tau)


def thud(dur: float, f0: float, f1: float, tau: float) -> np.ndarray:
    t = samples(dur)
    return tone(t, f1 + (f0 - f1) * np.exp(-t / 0.03)) * decay(t, tau, 0.001)


def wood(t: np.ndarray, f: float, tau: float = 0.02) -> np.ndarray:
    """Dřevěné ťuknutí: dva tlumené módy."""
    return (tone(t, f) + 0.5 * tone(t, f * 2.31)) * decay(t, tau, 0.0005)


def bell(t: np.ndarray, f: float, tau: float = 0.35) -> np.ndarray:
    """Měkký zvonek/hrací strojek: základ, oktáva a jemný inharmonický třpyt."""
    return (tone(t, f) + 0.35 * tone(t, f * 2.0) * np.exp(-t / (tau * 0.4))
            + 0.12 * tone(t, f * 3.01) * np.exp(-t / (tau * 0.25))) * decay(t, tau, 0.003)


def note(name: str) -> float:
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    semitone = names[name[0]] + (1 if "#" in name else 0)
    octave = int(name[-1])
    return 440.0 * 2 ** ((semitone - 9) / 12 + octave - 4)


def fade(x: np.ndarray, fin: float = 0.002, fout: float = 0.02, sr: int = SR) -> np.ndarray:
    x = x.copy()
    a, b = int(fin * sr), int(fout * sr)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def finish(x: np.ndarray, peak_db: float = -1.0, sr: int = SR, loop: bool = False) -> np.ndarray:
    """Odstraní stejnosměrnou složku a srovná špičku; efekty dostanou krátké
    náběhy a doznění, smyčky ne (ztlumený šev by se každé kolo ozval)."""
    x = x - np.mean(x)
    if not loop:
        x = fade(x, sr=sr)
    peak = np.max(np.abs(x))
    return x / peak * 10 ** (peak_db / 20) if peak > 0 else x


def loopable(x: np.ndarray, overlap: int) -> np.ndarray:
    """Plynulá smyčka: konec se prolne do začátku (rovnovýkonově)."""
    body = x[:-overlap].copy()
    tail = x[-overlap:]
    k = np.linspace(0, np.pi / 2, overlap)
    body[:overlap] = body[:overlap] * np.sin(k) + tail * np.cos(k)
    return body


# --- efekty ------------------------------------------------------------------

def sfx_assign(rng):
    t = samples(0.4)
    snap = filt(rng.standard_normal(len(t)), "band", [2500, 9000]) * decay(t, 0.006, 0.0005)
    ping = bell(t, note("E6"), 0.18) * 0.5 + bell(t, note("B6"), 0.14) * 0.3
    out = snap * 0.9
    place(out, ping, 0.012)
    return out


def sfx_select(rng):
    t = samples(0.12)
    tap = filt(rng.standard_normal(len(t)), "band", [1500, 5000]) * decay(t, 0.012, 0.0005)
    return tap + 0.5 * thud(0.12, 420, 260, 0.025)


def sfx_click(rng):
    t = samples(0.1)
    return wood(t, 1150, 0.018) + 0.3 * filt(rng.standard_normal(len(t)), "high", 3000) * decay(t, 0.003)


def sfx_deny(rng):
    t = samples(0.28)
    out = np.zeros(len(t))
    for i, f in enumerate([note("A4"), note("F4")]):
        tt = samples(0.13)
        place(out, (tone(tt, f) + 0.25 * tone(tt, f * 2)) * decay(tt, 0.05, 0.004), i * 0.11)
    return filt(out, "low", 2500)


def sfx_tick(rng):
    t = samples(0.06)
    return wood(t, 2200, 0.008)


def sfx_sweep(rng, up: bool):
    dur = 0.16
    t = samples(dur)
    n = rng.standard_normal(len(t))
    k = t / dur if up else 1 - t / dur
    out = np.zeros(len(t))
    # Posuvný pásmový filtr po krátkých úsecích (list papíru se přetočí).
    for i in range(0, len(t), 256):
        f = 900 + 3800 * k[i]
        seg = filt(n[max(0, i - 512):i + 256], "band", [f * 0.6, f * 1.4])[-min(256, len(t) - i):]
        out[i:i + len(seg)] = seg
    return out * np.sin(np.pi * t / dur) ** 0.7


def sfx_hatch(rng):
    dur = 0.95
    t = samples(dur)
    # Vrzání pantů: pila s pomalu kolísající výškou, pásmově omezená.
    f = 330 + 60 * np.sin(2 * np.pi * 2.3 * t) + 40 * np.sin(2 * np.pi * 5.1 * t)
    saw = signal.sawtooth(2 * np.pi * np.cumsum(f) / SR)
    creak = filt(saw * (0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 7 * t))), "band", [600, 2600])
    creak *= np.clip(t / 0.05, 0, 1) * np.clip((0.55 - t) / 0.1, 0, 1)
    out = creak * 0.5
    for at, f0 in [(0.56, 520), (0.64, 470)]:
        tt = samples(0.2)
        place(out, wood(tt, f0, 0.04) + 0.6 * thud(0.2, 180, 110, 0.05), at)
    return out


def sfx_spawn(rng):
    dur = 0.28
    t = samples(dur)
    flap = 0.5 + 0.5 * np.sin(2 * np.pi * 16 * t)
    flutter = filt(rng.standard_normal(len(t)), "band", [900, 3500]) * flap * decay(t, 0.09, 0.01)
    pop = thud(dur, 700, 350, 0.02) * 0.4
    return flutter + pop


def sfx_dig(rng, variant: int):
    dur = 0.24
    t = samples(dur)
    soil = filt(rng.standard_normal(len(t)), "low", 1300 + 300 * variant) * decay(t, 0.05, 0.002)
    grains = crumple(rng, dur, 2500, 600, 3500, 0.06) * 0.6
    return soil + grains + 0.7 * thud(dur, 140, 80, 0.04)


def sfx_bash(rng, variant: int):
    dur = 0.3
    t = samples(dur)
    hit = filt(rng.standard_normal(len(t)), "band", [1200, 6000]) * decay(t, 0.008, 0.0003)
    body = thud(dur, 260 + 30 * variant, 150, 0.05)
    crumbs = crumple(rng, dur, 1800, 700, 4000, 0.09) * 0.5
    return hit * 0.8 + body + crumbs


def sfx_mine(rng):
    dur = 0.34
    t = samples(dur)
    hit = filt(rng.standard_normal(len(t)), "band", [900, 4500]) * decay(t, 0.01, 0.0003)
    return hit * 0.7 + thud(dur, 200, 110, 0.06) + crumple(rng, dur, 2200, 500, 3000, 0.12) * 0.6


def sfx_brick(rng):
    dur = 0.24
    out = np.zeros(int(dur * SR))
    # Harmonikový díl se rozloží: tři rychlá lupnutí papíru a měkké ťuknutí.
    for i in range(3):
        place(out, crumple(rng, 0.05, 9000, 1800, 8000, 0.015), 0.025 * i, 0.5 + 0.2 * i)
    place(out, wood(samples(0.1), 760, 0.02) * 0.7, 0.08)
    return out


def sfx_brick_warning(rng):
    out = np.zeros(int(0.42 * SR))
    for i, n in enumerate(["G5", "E5"]):
        place(out, bell(samples(0.3), note(n), 0.16), 0.11 * i, 0.8)
    return out


def sfx_steel(rng):
    dur = 0.7
    t = samples(dur)
    out = np.zeros(len(t))
    for ratio, tau, amp in [(1.0, 0.35, 1.0), (2.76, 0.22, 0.6), (5.4, 0.12, 0.4), (8.93, 0.07, 0.25)]:
        out += tone(t, 820 * ratio) * decay(t, tau, 0.0005) * amp
    hit = filt(rng.standard_normal(len(t)), "high", 4000) * decay(t, 0.004, 0.0002)
    return out * 0.6 + hit * 0.4


def sfx_splat(rng):
    dur = 0.45
    return crumple(rng, dur, 7000, 1200, 9000, 0.09) + 0.9 * thud(dur, 120, 55, 0.08)


def sfx_exit(rng):
    out = np.zeros(int(0.8 * SR))
    for i, n in enumerate(["C6", "E6", "G6", "C7"]):
        place(out, bell(samples(0.5), note(n), 0.25), 0.055 * i, 0.55)
    t = samples(0.8)
    sparkle = filt(rng.standard_normal(len(t)), "high", 7000) * decay(t, 0.12, 0.01) * 0.06
    return out + sparkle


def sfx_explode(rng):
    dur = 1.0
    t = samples(dur)
    n = rng.standard_normal(len(t))
    boom = filt(n, "low", 520) * decay(t, 0.22, 0.002) * 2.2
    crack = filt(n, "band", [1000, 7000]) * decay(t, 0.015, 0.0003)
    out = boom + crack + 0.8 * thud(dur, 110, 40, 0.18)
    place(out, crumple(rng, 0.6, 3500, 1500, 8000, 0.2) * 0.5, 0.05)
    return out


def sfx_fell_out(rng):
    dur = 0.65
    t = samples(dur)
    f = 1150 * np.exp(-t * 2.2) + 260 + 18 * np.sin(2 * np.pi * 9 * t)
    return tone(t, f) * np.sin(np.pi * np.minimum(t / dur, 1)) ** 0.5 * 0.6


def bubble(f0: float, f1: float, dur: float = 0.05) -> np.ndarray:
    t = samples(dur)
    return tone(t, f0 + (f1 - f0) * (t / dur) ** 0.6) * decay(t, dur * 0.45, 0.002)


def sfx_drown(rng):
    dur = 0.65
    t = samples(dur)
    n = rng.standard_normal(len(t))
    splash = filt(n, "band", [400, 4500]) * decay(t, 0.09, 0.002)
    out = splash + 0.8 * thud(dur, 160, 90, 0.06)
    for _ in range(7):
        place(out, bubble(rng.uniform(700, 1100), rng.uniform(1300, 2100), 0.04) * 0.35,
              rng.uniform(0.04, 0.4))
    return out


def sfx_drowned(rng):
    out = np.zeros(int(0.75 * SR))
    at = 0.0
    for i in range(5):
        place(out, bubble(rng.uniform(260, 340), rng.uniform(560, 760), 0.06), at, 0.9 - 0.12 * i)
        at += rng.uniform(0.09, 0.15)
    return out


def sfx_burn(rng):
    dur = 0.75
    t = samples(dur)
    n = rng.standard_normal(len(t))
    out = np.zeros(len(t))
    # Vzplanutí: šum s filtrem otevírajícím se nahoru, pak praskání.
    for i in range(0, len(t), 512):
        f = 250 + 2600 * min(t[i] / 0.25, 1.0)
        seg = filt(n[max(0, i - 1024):i + 512], "low", f)[-min(512, len(t) - i):]
        out[i:i + len(seg)] = seg
    out *= np.clip(t / 0.08, 0, 1) * np.exp(-np.maximum(t - 0.15, 0) / 0.25)
    return out * 1.4 + crumple(rng, dur, 900, 1500, 7000, 0.4) * 0.6


def sfx_burned(rng):
    dur = 0.85
    t = samples(dur)
    sizzle = filt(rng.standard_normal(len(t)), "band", [2500, 9000]) * decay(t, 0.3, 0.02) * 0.5
    poof = filt(rng.standard_normal(len(t)), "low", 400) * decay(t, 0.08, 0.005)
    return sizzle + poof + crumple(rng, dur, 700, 1200, 6000, 0.3) * 0.5


def sfx_trap(rng):
    dur = 0.45
    out = np.zeros(int(dur * SR))
    for at in [0.0, 0.035]:
        place(out, wood(samples(0.08), 1500, 0.012), at)
        place(out, filt(rng.standard_normal(int(0.02 * SR)), "band", [2000, 7000]) * 0.5, at)
    place(out, thud(0.3, 170, 85, 0.07) * 0.9, 0.09)
    place(out, crumple(rng, 0.2, 2500, 800, 4000, 0.06) * 0.4, 0.06)
    return out


def sfx_nuke(rng):
    dur = 1.1
    t = samples(dur)
    hiss = filt(rng.standard_normal(len(t)), "band", [2200, 7500]) * (0.4 + 0.3 * np.sin(2 * np.pi * 11 * t))
    hiss *= np.clip(t / 0.05, 0, 1) * np.clip((dur - t) / 0.3, 0, 1)
    return hiss + crumple(rng, dur, 1200, 1500, 8000, 0.6) * 0.5


def sfx_jingle(rng, notes, step: float, tail: float, tau: float):
    out = np.zeros(int((step * len(notes) + tail) * SR))
    for i, n in enumerate(notes):
        place(out, bell(samples(tail + 0.2), note(n), tau), step * i, 0.6)
    return out


def sfx_win(rng):
    out = sfx_jingle(rng, ["C5", "E5", "G5", "C6"], 0.11, 1.1, 0.5)
    for n in ["C5", "E5", "G5"]:
        place(out, bell(samples(1.0), note(n), 0.55) * 0.25, 0.48)
    return out


def sfx_lose(rng):
    out = sfx_jingle(rng, ["G4", "E4", "C4"], 0.2, 0.9, 0.45)
    place(out, bell(samples(1.0), note("C3"), 0.6) * 0.4, 0.42)
    return out


# --- okolní smyčky -----------------------------------------------------------

def loop_wind(rng):
    dur, overlap = 12.0, 1.0
    n = int((dur + overlap) * LOOP_SR)
    t = np.arange(n) / LOOP_SR
    brown = np.cumsum(rng.standard_normal(n))
    brown = filt(brown - signal.savgol_filter(brown, 4001, 1), "low", 420, sr=LOOP_SR)
    gust = 0.55 + 0.25 * np.sin(2 * np.pi * t / 12.0) + 0.2 * np.sin(2 * np.pi * t / 4.0 + 1.3)
    rustle = filt(rng.standard_normal(n), "band", [1800, 5200], sr=LOOP_SR)
    rustle *= np.clip(gust - 0.6, 0, None) * 1.6
    x = brown / np.max(np.abs(brown)) * gust + rustle * 0.12
    return finish(loopable(x, int(overlap * LOOP_SR)), -6.0, LOOP_SR, loop=True)


def loop_lava(rng):
    dur, overlap = 6.0, 0.6
    n = int((dur + overlap) * LOOP_SR)
    t = np.arange(n) / LOOP_SR
    rumble = filt(rng.standard_normal(n), "low", 140, sr=LOOP_SR) * (0.8 + 0.2 * np.sin(2 * np.pi * t / 3.0))
    x = rumble / np.max(np.abs(rumble))
    for _ in range(22):
        dur_b = rng.uniform(0.06, 0.14)
        tb = np.arange(int(dur_b * LOOP_SR)) / LOOP_SR
        f = rng.uniform(70, 150) * (1 + tb / dur_b)
        pop = np.sin(2 * np.pi * np.cumsum(f) / LOOP_SR) * np.exp(-tb / (dur_b * 0.4))
        place(x, pop * rng.uniform(0.4, 0.8), rng.uniform(0, dur), sr=LOOP_SR)
    clicks = np.zeros(n)
    hits = rng.random(n) < 30 / LOOP_SR
    clicks[hits] = rng.uniform(-1, 1, hits.sum())
    x += filt(clicks, "band", [1500, 6000], sr=LOOP_SR) * 0.6
    return finish(loopable(x, int(overlap * LOOP_SR)), -6.0, LOOP_SR, loop=True)


def loop_water(rng):
    dur, overlap = 6.0, 0.6
    n = int((dur + overlap) * LOOP_SR)
    t = np.arange(n) / LOOP_SR
    lap = filt(rng.standard_normal(n), "band", [250, 1100], sr=LOOP_SR)
    lap *= 0.45 + 0.35 * np.sin(2 * np.pi * t / 1.5) ** 2 + 0.2 * np.sin(2 * np.pi * t / 3.0 + 0.7)
    x = lap / np.max(np.abs(lap))
    for _ in range(9):
        dur_b = 0.035
        tb = np.arange(int(dur_b * LOOP_SR)) / LOOP_SR
        f = rng.uniform(900, 1500) * (1 + 0.8 * tb / dur_b)
        drip = np.sin(2 * np.pi * np.cumsum(f) / LOOP_SR) * np.exp(-tb / 0.012)
        place(x, drip * rng.uniform(0.2, 0.45), rng.uniform(0, dur), sr=LOOP_SR)
    return finish(loopable(x, int(overlap * LOOP_SR)), -6.0, LOOP_SR, loop=True)


# --- sestavení ---------------------------------------------------------------

EFFECTS = {
    "assign": sfx_assign, "select": sfx_select, "click": sfx_click, "deny": sfx_deny,
    "tick": sfx_tick, "pause": lambda r: sfx_sweep(r, False), "resume": lambda r: sfx_sweep(r, True),
    "hatch": sfx_hatch, "spawn": sfx_spawn,
    "dig_0": lambda r: sfx_dig(r, 0), "dig_1": lambda r: sfx_dig(r, 1),
    "bash_0": lambda r: sfx_bash(r, 0), "bash_1": lambda r: sfx_bash(r, 1),
    "mine": sfx_mine, "brick": sfx_brick, "brick_warning": sfx_brick_warning, "steel": sfx_steel,
    "splat": sfx_splat, "exit": sfx_exit, "explode": sfx_explode, "fell_out": sfx_fell_out,
    "drown": sfx_drown, "drowned": sfx_drowned, "burn": sfx_burn, "burned": sfx_burned,
    "trap": sfx_trap, "nuke": sfx_nuke, "win": sfx_win, "lose": sfx_lose,
}
LOOPS = {"wind": loop_wind, "lava": loop_lava, "water": loop_water}

# Mix pro hru: [soubory, hlasitost dB, rozptyl výšky, min. odstup s, hlasy, sběrnice, v prostoru]
MIX = {
    "assign": [["assign"], -1, 0.03, 0.04, 3, "SFX", True],
    "select": [["select"], -5, 0.04, 0.03, 2, "UI", False],
    "click": [["click"], -5, 0.05, 0.03, 2, "UI", False],
    "deny": [["deny"], -7, 0.02, 0.15, 1, "UI", False],
    "tick": [["tick"], -9, 0.06, 0.03, 2, "UI", False],
    "pause": [["pause"], -7, 0.0, 0.05, 1, "UI", False],
    "resume": [["resume"], -7, 0.0, 0.05, 1, "UI", False],
    "hatch": [["hatch"], -1, 0.0, 0.5, 2, "SFX", True],
    "spawn": [["spawn"], -11, 0.08, 0.08, 3, "SFX", True],
    "dig": [["dig_0", "dig_1"], -7, 0.08, 0.07, 4, "SFX", True],
    "bash": [["bash_0", "bash_1"], -6, 0.08, 0.07, 4, "SFX", True],
    "mine": [["mine"], -6, 0.08, 0.07, 4, "SFX", True],
    "brick": [["brick"], -5, 0.06, 0.06, 4, "SFX", True],
    "brick_warning": [["brick_warning"], -3, 0.0, 0.2, 2, "SFX", True],
    "steel": [["steel"], -5, 0.05, 0.1, 3, "SFX", True],
    "splat": [["splat"], -1, 0.06, 0.06, 4, "SFX", True],
    "exit": [["exit"], -3, 0.02, 0.06, 4, "SFX", True],
    "explode": [["explode"], -1, 0.06, 0.05, 6, "SFX", True],
    "fell_out": [["fell_out"], -7, 0.05, 0.1, 3, "SFX", True],
    "drown": [["drown"], -1, 0.06, 0.06, 4, "SFX", True],
    "drowned": [["drowned"], -5, 0.08, 0.06, 4, "SFX", True],
    "burn": [["burn"], -1, 0.06, 0.06, 4, "SFX", True],
    "burned": [["burned"], -5, 0.06, 0.06, 4, "SFX", True],
    "trap": [["trap"], 1, 0.04, 0.06, 3, "SFX", True],
    "nuke": [["nuke"], -1, 0.0, 0.5, 1, "UI", False],
    "win": [["win"], -1, 0.0, 1.0, 1, "UI", False],
    "lose": [["lose"], -1, 0.0, 1.0, 1, "UI", False],
}
LOOP_MIX = {"wind": -17, "lava": -8, "water": -10}


def write_wav(path: Path, data: np.ndarray, sr: int) -> None:
    pcm = np.clip(np.round(data * 32767), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())


def generate(out: Path, seed: int = 2030) -> None:
    (out / "sfx").mkdir(parents=True, exist_ok=True)
    (out / "loops").mkdir(parents=True, exist_ok=True)
    for i, (name, fn) in enumerate(EFFECTS.items()):
        write_wav(out / "sfx" / f"{name}.wav", finish(fn(np.random.default_rng(seed + i))), SR)
    for i, (name, fn) in enumerate(LOOPS.items()):
        write_wav(out / "loops" / f"{name}.wav", fn(np.random.default_rng(seed + 100 + i)), LOOP_SR)
    mix = {"sounds": {}, "loops": {}}
    for name, (files, db, pitch, gap, voices, bus, positional) in MIX.items():
        mix["sounds"][name] = {"files": [f"sfx/{f}.wav" for f in files], "volume_db": db,
                               "pitch_spread": pitch, "min_interval": gap, "voices": voices,
                               "bus": bus, "positional": positional}
    for name, db in LOOP_MIX.items():
        mix["loops"][name] = {"file": f"loops/{name}.wav", "volume_db": db, "bus": "Ambient"}
    (out / "sfx.json").write_text(json.dumps(mix, indent=1, ensure_ascii=False) + "\n")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def tracked_files() -> list[Path]:
    return [p for p in sorted(PACKAGE.rglob("*"))
            if p.is_file() and p.suffix != ".import" and "__pycache__" not in p.parts]


def write_manifest() -> None:
    import scipy
    provenance = {
        "package": "lemmings-paper-sfx",
        "version": "1.0.0",
        "game_version": "0.5.0",
        "authoring": "Syntetizováno vlastním skriptem assets/audio/source/build_sfx.py "
                     "(NumPy + SciPy, pevné seedy): šum, filtry, tóny a obálky.",
        "inputs": "Žádné nahrávky, vzorky, hudba ani zvuky z původní hry nebo od třetích stran.",
        "tools": {"python": platform.python_version(), "numpy": np.__version__, "scipy": scipy.__version__},
        "generator_sha256": {p.name: digest(p) for p in sorted(HERE.glob("*.py"))},
        "format": "WAV PCM 16 bit mono; efekty 44,1 kHz, smyčky 22,05 kHz",
        "contents": {
            "sfx": "papírové a dřevěné ťuknutí, přidělení dovednosti, kopání, ražení, cihla, ocel, "
                   "splácnutí, východ, výbuch, pád z mapy, šplouchnutí a bubliny, vzplanutí a syčení, "
                   "past, odpočet, krátké znělky výhry a prohry, zvuky rozhraní",
            "loops": "vítr v krajině, bublající láva, šplouchající voda",
        },
        "limitations": ["Hudba zatím není součástí sady (autor ji doplní později)."],
    }
    (PACKAGE / "provenance.json").write_text(json.dumps(provenance, indent=2, ensure_ascii=False) + "\n")
    files = [{"path": str(p.relative_to(REPO)), "sha256": digest(p)} for p in tracked_files()]
    lock = {"package": provenance["package"], "version": provenance["version"],
            "license": "LicenseRef-Paperlings-AllRightsReserved", "files": files}
    (REPO / "assets" / "audio.lock.json").write_text(json.dumps(lock, indent=2) + "\n")
    print(f"Manifest: {len(files)} souborů")


def check() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp)
        generate(out)
        bad = []
        for path in sorted(out.rglob("*")):
            if path.is_file():
                target = PACKAGE / path.relative_to(out)
                if not target.exists() or digest(target) != digest(path):
                    bad.append(str(path.relative_to(out)))
        if bad:
            print("Rozdílné soubory:", ", ".join(bad))
            return 1
    print("Generátor zvuků odpovídá uloženým souborům.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.check:
        return check()
    generate(PACKAGE)
    write_manifest()
    return 0


if __name__ == "__main__":
    sys.exit(main())
