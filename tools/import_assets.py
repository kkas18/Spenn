#!/usr/bin/env python3
"""Prepares third-party audio and particle assets for Spenn.

Source packs (see CREDITS.md) are unpacked into SRC. The script trims,
fades, loudness-matches and re-encodes the sounds to mono OGG Vorbis, makes
the two music tracks loop seamlessly, and downsizes the particle textures to
white-on-alpha PNGs. Output goes straight into the project's assets/ folder.

    pip install soundfile numpy pillow
    python3 tools/import_assets.py /path/to/unpacked/packs
"""

import os
import sys

import numpy as np
import soundfile as sf
from PIL import Image

SRC = sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-0/assets"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")

UI = "kenney_interface-sounds/Audio/"
IMP = "kenney_impact-sounds/Audio/"
JIN = "kenney_music-jingles/Audio/"
RPG = "kenney_rpg-audio/Audio/"
FS = "fs/fs_%d.mp3"      # freesound.org HQ previews, all CC0 (see CREDITS.md)


def impact(name, n=5):
    return [IMP + "%s_%03d.ogg" % (name, i) for i in range(n)]


def ui(name, ids):
    return [UI + "%s_%03d.ogg" % (name, i) for i in ids]


# game sound name: (source files, max length in seconds or None)
SFX = {
    "release": (ui("pluck", [1, 2]), None),
    "hit": (impact("impactPlate_light"), 0.35),
    "thud": (impact("impactSoft_medium"), None),
    "snap": (impact("impactWood_light"), 0.2),
    "knock": (impact("impactGeneric_light"), None),
    "twang": (ui("pluck", [1, 2]), None),
    "clank": (impact("impactMetal_light"), 0.3),
    "cut": (ui("scratch", [1, 2]), None),
    "burst": (impact("impactGlass_light"), None),
    "breach": (impact("impactPunch_heavy"), None),
    "boss": ([JIN + "Steel jingles/jingles_STEEL05.ogg"], None),
    "streak": (ui("select", [3, 4, 5]), None),
    "reel": (ui("scroll", [1, 2, 3]), 0.35),
    "fade": (ui("glass", [2, 5, 6]), None),
    "intro": ([JIN + "Pizzicato jingles/jingles_PIZZI16.ogg"], None),
    "beat": (impact("impactSoft_heavy"), 0.3),
    "token": (ui("select", [1, 2]), None),
    "click": (ui("click", [2, 3, 4, 5]), None),
    "pause": (ui("minimize", [4]), None),
    "resume": (ui("maximize", [4]), None),
    "reveal": ([JIN + "Pizzicato jingles/jingles_PIZZI04.ogg"], None),
    "death": (impact("impactPlate_heavy"), None),
    "count": (ui("tick", [1, 2]), None),
    "record": ([JIN + "Pizzicato jingles/jingles_PIZZI02.ogg"], None),
    "restart": (ui("maximize", [8]), None),
    "deny": (ui("error", [8]), None),
    "panel": (ui("toggle", [1, 2, 3]), None),
    "countdown": (ui("tick", [4]), None),
    "tick": (ui("tick", [2]), None),
    "reload": (ui("drop", [1]), None),
    "clear": ([JIN + "Pizzicato jingles/jingles_PIZZI10.ogg"], None),
    "lose": ([JIN + "Pizzicato jingles/jingles_PIZZI14.ogg"], None),
    # enemy evasion: hook sliding along the rail, string creaking up
    "slide": ([RPG + "drawKnife%d.ogg" % i for i in (1, 2, 3)], 0.3),
    "creak": ([RPG + "creak%d.ogg" % i for i in (1, 2, 3)], 0.4),
    # soft (jelly) bodies: squish on a hit, splat when they burst
    "squish": ([FS % 442772, (FS % 593984, 0.15, 0.5), (FS % 593984, 1.88, 2.25),
                (FS % 593984, 3.73, 4.1), (FS % 794272, 0.8, 1.05)], 0.4),
    "splat": ([FS % 445117, FS % 445118, (FS % 447929, 0.08, 0.95)], 0.6),
    # a teasing "na-na" when an enemy mocks a miss (pizzicato, two notes)
    "tease": ([JIN + "Pizzicato jingles/jingles_PIZZI%02d.ogg" % i for i in (8, 9, 5)], None),
    # rigid bodies: wood for the rod, heavier metal for the boss
    "wood": (impact("impactWood_medium"), 0.3),
    "metal": (impact("impactMetal_heavy"), 0.35),
}

TARGET_RMS_DB = -20.0     # loudness of the active part of every sound
PEAK_DB = -1.0

# music name: (source mp3, loop length in samples or None, crossfade seconds)
MUSIC = {
    # 124 BPM, 48 bars: the published loop version is cut on the bar.
    "play": ("music_Mesmerizing_Galaxy_Loop.mp3", int(round(48 * 4 * 60.0 / 124.0 * 44100)), 0.0),
    # Not a loop: baked crossfade from the end back into the start.
    "menu": ("music_Dreamy_Flashback.mp3", None, 3.0),
}

# texture name: (source file, size)
PARTICLES = {
    "smoke_a": ("smoke_04.png", 128),
    "smoke_b": ("smoke_07.png", 128),
    "streak": ("trace_06.png", 64),
    "soft": ("circle_05.png", 64),
    "ring": ("circle_04.png", 128),
}


def db(x):
    return 20.0 * np.log10(max(x, 1e-9))


def trim(m, sr, max_len):
    env = np.abs(m)
    thr = env.max() * 10 ** (-50 / 20.0)
    nz = np.nonzero(env > thr)[0]
    m = m[max(0, nz[0] - int(0.002 * sr)): nz[-1] + 1]
    if max_len:
        m = m[: int(max_len * sr)]
    # 2 ms fade in, 25 ms (or 20 %) fade out: no clicks.
    fi = min(len(m) // 4, int(0.002 * sr))
    fo = min(len(m) // 5, int(0.025 * sr))
    m = m.copy()
    m[:fi] *= np.linspace(0.0, 1.0, fi)
    m[len(m) - fo:] *= np.linspace(1.0, 0.0, fo) ** 2
    return m


def active_rms(m, sr):
    win = max(1, int(0.02 * sr))
    frames = [np.sqrt(np.mean(m[i:i + win] ** 2)) for i in range(0, max(1, len(m) - win), win)]
    frames = sorted(frames, reverse=True)
    top = frames[: max(1, len(frames) // 3)]
    return float(np.mean(top))


def build_sfx():
    os.makedirs(os.path.join(OUT, "sfx"), exist_ok=True)
    for name, (files, max_len) in SFX.items():
        for i, rel in enumerate(files):
            span = None
            if isinstance(rel, tuple):
                rel, a, b = rel
                span = (a, b)
            d, sr = sf.read(os.path.join(SRC, rel), always_2d=True)
            if span:
                d = d[int(span[0] * sr): int(span[1] * sr)]
            m = trim(d.mean(axis=1), sr, max_len)
            g = 10 ** ((TARGET_RMS_DB - db(active_rms(m, sr))) / 20.0)
            g = min(g, 10 ** (PEAK_DB / 20.0) / max(np.abs(m).max(), 1e-9))
            m = (m * g).astype(np.float32)
            path = os.path.join(OUT, "sfx", "%s_%d.ogg" % (name, i))
            sf.write(path, m, sr, format="OGG", subtype="VORBIS")
            print("%-24s %5.2fs rms %5.1f pk %5.1f" % (os.path.basename(path), len(m) / sr,
                  db(active_rms(m, sr)), db(np.abs(m).max())))


def build_whoosh():
    """Kenney has no air movement, so the whoosh is made here: noise through
    a swept band-pass with a soft swell. Three variants."""
    sr = 44100
    rng = np.random.default_rng(3)
    for v in range(3):
        n = int((0.28 + 0.04 * v) * sr)
        x = rng.uniform(-1.0, 1.0, n)
        t = np.arange(n) / n
        cut = 500.0 + 1400.0 * np.sin(np.pi * t) * (1.0 + 0.2 * v)
        lo = np.zeros(n)
        hi = np.zeros(n)
        a_lo = 1.0 - np.exp(-2 * np.pi * cut / sr)
        a_hi = 1.0 - np.exp(-2 * np.pi * (cut * 0.35) / sr)
        y1 = y2 = 0.0
        for i in range(n):
            y1 += (x[i] - y1) * a_lo[i]
            y2 += (y1 - y2) * a_hi[i]
            lo[i] = y1
            hi[i] = y1 - y2
        env = np.sin(np.pi * t ** 0.7) ** 2
        m = hi * env
        m = m / np.abs(m).max() * 10 ** (-6 / 20.0)
        g = 10 ** ((TARGET_RMS_DB - db(active_rms(m, sr))) / 20.0)
        m = (m * min(g, 10 ** (PEAK_DB / 20.0) / np.abs(m).max())).astype(np.float32)
        sf.write(os.path.join(OUT, "sfx", "whoosh_%d.ogg" % v), m, sr, format="OGG", subtype="VORBIS")


# The play track sits in C minor, so the combo notes climb C D Eb G, the
# notes of its chord plus the ninth: any of them sounds right over any bar.
NOTES = [60, 62, 63, 67, 72, 74, 75, 79, 84]


def _tine(f0, sr, dur):
    """A kalimba-like tine: a sine with a quickly fading bell partial and a
    soft mallet tick, so rising runs read as a melody, not as beeps."""
    n = int(dur * sr)
    t = np.arange(n) / sr
    y = np.sin(2 * np.pi * f0 * t) * np.exp(-t / 0.42)
    y += 0.22 * np.sin(2 * np.pi * f0 * 2.0 * t) * np.exp(-t / 0.16)
    y += 0.10 * np.sin(2 * np.pi * f0 * 4.07 * t) * np.exp(-t / 0.05)
    rng = np.random.default_rng(int(f0))
    tick = rng.uniform(-1.0, 1.0, int(0.004 * sr))
    y[:len(tick)] += tick * np.linspace(0.3, 0.0, len(tick))
    atk = int(0.003 * sr)
    y[:atk] *= np.linspace(0.0, 1.0, atk)
    fo = int(0.08 * sr)
    y[-fo:] *= np.linspace(1.0, 0.0, fo) ** 2
    return y


def _level(m, sr):
    g = 10 ** ((TARGET_RMS_DB - db(active_rms(m, sr))) / 20.0)
    return (m * min(g, 10 ** (PEAK_DB / 20.0) / np.abs(m).max())).astype(np.float32)


def build_notes():
    sr = 44100
    for i, midi in enumerate(NOTES):
        f0 = 440.0 * 2 ** ((midi - 69) / 12.0)
        m = _level(_tine(f0, sr, 0.9), sr)
        sf.write(os.path.join(OUT, "sfx", "note_%d.ogg" % i), m, sr, format="OGG", subtype="VORBIS")


def build_surge():
    """Overload: a C minor chord swelling out of a rising band of air, then
    ringing off; and its release, the same chord falling away."""
    sr = 44100
    for v, rising in enumerate([True, False]):
        dur = 1.4 if rising else 0.9
        n = int(dur * sr)
        t = np.arange(n) / sr
        k = t / dur
        env = (np.sin(np.pi * np.minimum(k / 0.45, 1.0) / 2) ** 2 * np.exp(-np.maximum(t - 0.6, 0) / 0.35)
               if rising else np.exp(-t / 0.3))
        y = np.zeros(n)
        for j, midi in enumerate([48, 55, 60, 63, 67, 72]):
            f = 440.0 * 2 ** ((midi - 69) / 12.0) * (1.0 + (0.0 if rising else -0.06 * k))
            for det in (-0.003, 0.003):
                y += np.sin(2 * np.pi * np.cumsum(np.full(n, f * (1 + det))) / sr) / (1 + j * 0.4)
        y *= env
        rng = np.random.default_rng(11 + v)
        x = rng.uniform(-1.0, 1.0, n)
        cut = 300.0 + 3500.0 * (k if rising else 1.0 - k) ** 1.5
        a = 1.0 - np.exp(-2 * np.pi * cut / sr)
        lo = np.zeros(n)
        z = 0.0
        for i in range(n):
            z += (x[i] - z) * a[i]
            lo[i] = z
        air = lo * (np.sin(np.pi * np.minimum(k / 0.5, 1.0)) if rising else np.exp(-t / 0.2))
        y = y / np.abs(y).max() + 0.6 * air / np.abs(air).max()
        fo = int(0.06 * sr)
        y[-fo:] *= np.linspace(1.0, 0.0, fo) ** 2
        sf.write(os.path.join(OUT, "sfx", ("rise_0.ogg", "fall_0.ogg")[v]), _level(y, sr), sr, format="OGG", subtype="VORBIS")


def build_voices():
    """Tiny creature voices: a sung syllable through two formant bands with
    a quick pitch gesture, at C5, pitched by the game onto the notes of the
    key. Three shapes: a rising chirp (startle), a two-step taunt, a falling
    sigh (death)."""
    sr = 44100
    f0 = 523.25
    shapes = {
        "voice_up": (0.16, lambda k: 0.88 + 0.3 * k),
        "voice_taunt": (0.26, lambda k: np.where(k < 0.45, 1.0, 1.2)),
        "voice_down": (0.34, lambda k: 1.12 - 0.42 * k ** 0.8),
    }
    for name, (dur, glide) in shapes.items():
        n = int(dur * sr)
        t = np.arange(n) / sr
        k = t / dur
        f = f0 * glide(k) * (1.0 + 0.012 * np.sin(2 * np.pi * 7.0 * t))
        ph = 2 * np.pi * np.cumsum(f) / sr
        # A buzzy source (a few harmonics) so the formants have something to shape.
        src = sum(np.sin(ph * h) / h for h in range(1, 7))
        out = np.zeros(n)
        for fc, gain in ((900.0, 1.0), (2300.0, 0.45)):
            # Two-pole resonator per formant.
            r = np.exp(-np.pi * 180.0 / sr)
            c = 2 * r * np.cos(2 * np.pi * fc / sr)
            y1 = y2 = 0.0
            band = np.zeros(n)
            for i in range(n):
                y = src[i] + c * y1 - r * r * y2
                y2, y1 = y1, y
                band[i] = y
            out += band / np.abs(band).max() * gain
        env = np.minimum(k / 0.08, 1.0) * (1.0 - np.maximum(k - 0.55, 0.0) / 0.45) ** 1.5
        m = _level(out * env, sr)
        sf.write(os.path.join(OUT, "sfx", name + "_0.ogg"), m, sr, format="OGG", subtype="VORBIS")


def build_music():
    os.makedirs(os.path.join(OUT, "music"), exist_ok=True)
    for name, (src, loop_len, xfade) in MUSIC.items():
        d, sr = sf.read(os.path.join(SRC, src), always_2d=True)
        env = np.abs(d).max(axis=1)
        nz = np.nonzero(env > 1e-3)[0]
        d = d[nz[0]:]
        if loop_len:
            # Fold the few samples that ring past the loop point back into
            # the start (10 ms equal-power) so the seam never clicks.
            n = min(len(d) - loop_len, int(0.01 * sr))
            t = np.linspace(0.0, 1.0, n)[:, None]
            head = d[:n] * np.sin(t * np.pi / 2) + d[loop_len:loop_len + n] * np.cos(t * np.pi / 2)
            d = np.concatenate([head, d[n:loop_len]])
        else:
            end = np.nonzero(np.abs(d).max(axis=1) > 10 ** (-40 / 20.0))[0][-1]
            d = d[:end]
            n = int(xfade * sr)
            t = np.linspace(0.0, 1.0, n)[:, None]
            head = d[:n] * np.sin(t * np.pi / 2) + d[-n:] * np.cos(t * np.pi / 2)
            d = np.concatenate([head, d[n:-n]])
        # Match both tracks to the same loudness, keep headroom.
        g = 10 ** ((-18.0 - db(np.sqrt(np.mean(d ** 2)))) / 20.0)
        g = min(g, 10 ** (-1.0 / 20.0) / np.abs(d).max())
        d = (d * g).astype(np.float32)
        path = os.path.join(OUT, "music", name + ".ogg")
        # libsndfile's Vorbis writer crashes on very large single writes.
        with sf.SoundFile(path, "w", sr, d.shape[1], format="OGG", subtype="VORBIS",
                          compression_level=0.55) as f:
            for i in range(0, len(d), 1 << 14):
                f.write(d[i:i + (1 << 14)])
        print(path, "%.2fs" % (len(d) / sr), "%.1f MB" % (os.path.getsize(path) / 1e6))


def build_particles():
    os.makedirs(os.path.join(OUT, "particles"), exist_ok=True)
    base = os.path.join(SRC, "kenney_particle-pack", "PNG (Transparent)")
    for name, (src, size) in PARTICLES.items():
        im = Image.open(os.path.join(base, src)).convert("RGBA")
        a = np.asarray(im).astype(np.float32) / 255.0
        lum = a[..., :3].max(axis=2) * a[..., 3]
        box = Image.fromarray((lum * 255).astype(np.uint8)).getbbox()
        # Keep it square around the centre so rotation stays centred.
        w = max(box[2] - box[0], box[3] - box[1])
        c = ((box[0] + box[2]) // 2, (box[1] + box[3]) // 2)
        half = w // 2 + 4
        crop = (c[0] - half, c[1] - half, c[0] + half, c[1] + half)
        alpha = Image.fromarray((lum * 255).astype(np.uint8)).crop(crop).resize((size, size), Image.LANCZOS)
        out = Image.new("RGBA", (size, size), (255, 255, 255, 0))
        out.putalpha(alpha)
        out.save(os.path.join(OUT, "particles", name + ".png"), optimize=True)
        print(name, crop, size)


if __name__ == "__main__":
    build_sfx()
    build_whoosh()
    build_notes()
    build_surge()
    build_voices()
    build_music()
    build_particles()
