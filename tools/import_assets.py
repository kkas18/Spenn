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

# Mocking laughs (freesound.org, all CC0; see CREDITS.md): five families
# from small and high to big and low, each take (freesound id, start s,
# end s) of a longer recording. The game picks the family by the enemy's
# kind and mood and pitches the take by its size (see Target.laugh_voice).
LAUGHS = {
    # small and light: a cartoon giggle
    "giggle": [(513983, 0.12, 0.80), (19260, 0.0, 0.72), (576984, 0.02, 1.08),
               (243378, 6.40, 7.18), (243378, 10.88, 11.64)],
    # the sly ones: a mischievous snicker
    "imp": [(205751, 0.04, 0.86), (580747, 0.04, 1.66), (417826, 0.14, 1.16),
            (702394, 7.64, 9.10)],
    # the crowd: a nasal cackle
    "goblin": [(643664, 2.12, 3.08), (643664, 3.88, 4.58), (643664, 10.80, 11.74),
               (643664, 12.74, 14.02), (173933, 0.54, 1.72), (173933, 2.74, 4.02)],
    # the unimpressed: grown-up and condescending, down to a single "heh"
    "sneer": [(343981, 0.02, 0.28), (842291, 0.22, 1.68), (697899, 0.90, 3.12),
              (382906, 0.04, 2.40), (649082, 1.18, 3.06)],
    # the Spinneren and the big ones: a deep villain's laugh
    "evil": [(362330, 0.02, 2.92), (401332, 0.16, 3.58), (704363, 0.04, 2.06),
             (466059, 1.22, 4.84), (646307, 0.0, 1.98)],
}
LAUGH_MAX = {"giggle": 1.1, "imp": 1.35, "goblin": 1.4, "sneer": 1.6, "evil": 2.2}
LAUGH_HPF = {"giggle": 180.0, "imp": 150.0, "goblin": 150.0, "sneer": 110.0, "evil": 80.0}
LAUGH_ENV_RATE = 30       # the loudness curve the laughing mouth follows, per second

BAR = 4 * 60.0 / 124.0   # s: the three play tracks all run at 124 BPM

# music name: (source mp3, loop start s or None, loop length in bars or
# None, crossfade seconds, loudness)
# A loop start cuts the loop out of the body of a longer piece, on its
# downbeat (found from its onsets; its end repeats its start, see PLAN.md
# v7.56). Loudness: None keeps the old match (RMS -18 dBFS), a number is a
# K-weighted loudness (roughly LUFS) to match the play track's -15.4 by ear
# rather than by meter, a touch lower for the busier pieces.
MUSIC = {
    # 124 BPM, 48 bars: the published loop version is cut on the bar.
    "play": ("music_Mesmerizing_Galaxy_Loop.mp3", None, 48, 0.0, None),
    # Not a loop: baked crossfade from the end back into the start.
    "menu": ("music_Dreamy_Flashback.mp3", None, None, 3.0, None),
    # The lift of the middle waves: 32 bars of the driving groove.
    "lift": ("music_Brain_Dance.mp3", 29.543, 32, 0.0, -15.9),
    # The Spinneren's: 16 bars of the steadiest, hardest stretch.
    "boss": ("music_Cephalopod.mp3", 35.340, 16, 0.0, -16.4),
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


# The background fibres are a harp: plucked strings (Karplus-Strong) on the
# C minor pentatonic, two octaves, so any run of them sits in the play
# track's key. HARP_TAUT is the tension string across the top bar: one low,
# brighter steel string the game retunes (pitch) as the wave pulls it tight.
HARP = [60, 63, 65, 67, 70, 72, 75, 77, 79, 82, 84]
HARP_TAUT = 48


def _pluck(f0, sr, dur, bright, decay, seed):
    """Karplus-Strong: a burst of filtered noise in a delay line one period
    long, averaged on every pass, so it rings like a plucked string and
    darkens as it fades. `bright` (0..1) keeps more of the pick's edge;
    `decay` is the loss per pass (closer to 1 rings longer)."""
    n = int(dur * sr)
    # The two-tap average and the interpolation add a fraction of a sample
    # of delay: take it off the line (measured: within a few cents).
    period = sr / f0 - 0.2
    p = int(period)
    frac = period - p
    rng = np.random.default_rng(seed)
    burst = rng.uniform(-1.0, 1.0, p)
    # Soften the pick: a one-pole low-pass over the burst.
    a = 0.25 + 0.7 * bright
    for i in range(1, p):
        burst[i] = burst[i - 1] + a * (burst[i] - burst[i - 1])
    burst -= burst.mean()
    buf = np.zeros(n + p + 2)
    buf[:p] = burst
    for i in range(p, n + p):
        # Averaging the two taps (with the fractional part for tuning) is
        # the string's loss and its low-pass.
        x0 = buf[i - p]
        x1 = buf[i - p - 1] if i - p - 1 >= 0 else 0.0
        buf[i] = decay * ((1.0 - frac) * (0.5 * (x0 + x1)) + frac * x1)
    y = buf[p:p + n].copy()
    t = np.arange(n) / sr
    # A little body: the soundboard's low resonance and a soft attack.
    body = np.sin(2 * np.pi * f0 * 0.5 * t) * np.exp(-t / 0.12) * 0.08
    y = y + body
    # Take out any DC the loop keeps (a one-pole high-pass near 25 Hz).
    k = np.exp(-2 * np.pi * 25.0 / sr)
    out = np.zeros(n)
    px = py = 0.0
    for i in range(n):
        py = k * (py + y[i] - px)
        px = y[i]
        out[i] = py
    y = out
    atk = int(0.002 * sr)
    y[:atk] *= np.linspace(0.0, 1.0, atk)
    fo = int(0.12 * sr)
    y[-fo:] *= np.linspace(1.0, 0.0, fo) ** 2
    return y


def build_harp():
    sr = 44100
    for i, midi in enumerate(HARP):
        f0 = 440.0 * 2 ** ((midi - 69) / 12.0)
        m = _level(_pluck(f0, sr, 1.7, 0.35, 0.996, 100 + i), sr) * 0.8
        sf.write(os.path.join(OUT, "sfx", "harp_%d.ogg" % i), m.astype(np.float32), sr, format="OGG", subtype="VORBIS")
    f0 = 440.0 * 2 ** ((HARP_TAUT - 69) / 12.0)
    for v in range(2):
        m = _level(_pluck(f0, sr, 2.2, 0.75, 0.998, 200 + v), sr)
        sf.write(os.path.join(OUT, "sfx", "taut_%d.ogg" % v), m.astype(np.float32), sr, format="OGG", subtype="VORBIS")


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


def _hpf(m, sr, fc, order=3):
    """Zero-phase Butterworth-shaped high-pass (in the frequency domain)."""
    n = len(m)
    size = 1 << int(np.ceil(np.log2(n + sr // 4)))
    f = np.fft.rfftfreq(size, 1.0 / sr)
    h = 1.0 / np.sqrt(1.0 + (fc / np.maximum(f, 1e-3)) ** (2 * order))
    return np.fft.irfft(np.fft.rfft(m, size) * h, size)[:n]


def _stft(m, n=1024, hop=256):
    pad = np.concatenate([np.zeros(n), m, np.zeros(n)])
    frames = np.lib.stride_tricks.sliding_window_view(pad, n)[::hop] * np.hanning(n)
    return np.fft.rfft(frames, axis=1)


def _istft(spec, length, n=1024, hop=256):
    w = np.hanning(n)
    frames = np.fft.irfft(spec, n, axis=1) * w
    out = np.zeros(hop * (len(frames) - 1) + n)
    norm = np.zeros_like(out)
    for i, f in enumerate(frames):
        out[i * hop:i * hop + n] += f
        norm[i * hop:i * hop + n] += w * w
    return (out / np.maximum(norm, 1e-6))[n:n + length]


def _denoise(m, whole, strength=2.0, floor_db=-14.0):
    """Spectral gate: the recording's noise is measured in its quietest
    frames and taken off every bin, at most `floor_db`, with the gain
    smoothed over time and frequency so it never warbles."""
    p_all = np.abs(_stft(whole)) ** 2
    e = p_all.sum(axis=1)
    live = e > 1e-10
    noise = p_all[live & (e <= np.percentile(e[live], 15))].mean(axis=0)
    spec = _stft(m)
    p = np.abs(spec) ** 2
    g = np.clip(1.0 - strength * noise[None, :] / np.maximum(p, 1e-20), 10 ** (floor_db / 10.0), 1.0)
    g = np.lib.stride_tricks.sliding_window_view(np.pad(g, ((1, 1), (2, 2)), mode="edge"), (3, 5)).mean(axis=(2, 3))
    return _istft(spec * np.sqrt(g), len(m))


def _env_rms(m, sr, hop_s):
    hop = max(1, int(hop_s * sr))
    pad = np.concatenate([np.zeros(hop), m, np.zeros(2 * hop)])
    return np.array([np.sqrt(np.mean(pad[i:i + 2 * hop] ** 2)) for i in range(0, len(m), hop)])


def _trim_laugh(m, sr, max_len):
    """Silence off both ends; a take longer than `max_len` ends in the
    quietest gap between syllables before it, never mid-syllable."""
    step = int(0.005 * sr)
    e = _env_rms(m, sr, 0.005)
    on = np.nonzero(e > e.max() * 10 ** (-42 / 20.0))[0]
    m = m[max(0, on[0] * step - int(0.008 * sr)): min(len(m), (on[-1] + 1) * step + int(0.03 * sr))]
    cut = len(m)
    if len(m) > max_len * sr:
        e = _env_rms(m, sr, 0.01)
        lo, hi = int((max_len - 0.4) / 0.01), int(max_len / 0.01)
        cut = (lo + int(np.argmin(e[lo:hi]))) * int(0.01 * sr) + int(0.005 * sr)
    m = m[:cut].copy()
    fi = int(0.004 * sr)
    fo = min(len(m) // 4, int(0.07 * sr))
    m[:fi] *= np.linspace(0.0, 1.0, fi)
    m[len(m) - fo:] *= np.cos(np.linspace(0.0, np.pi / 2, fo)) ** 2
    return m


def build_laughs():
    """The mocking laughs: each take cut from its recording, high-passed,
    cleaned of its background hiss, trimmed and levelled like every other
    sound. Their loudness curves (one hex digit, 0..f, LAUGH_ENV_RATE
    times a second) go to scripts/laughs.gd, so a laughing enemy's mouth
    and bounce follow its voice."""
    curves = {}
    for fam, takes in LAUGHS.items():
        curves[fam] = []
        for i, (sid, s0, s1) in enumerate(takes):
            d, sr = sf.read(os.path.join(SRC, FS % sid), always_2d=True)
            whole = d.mean(axis=1)
            m = whole[max(0, int((s0 - 0.03) * sr)): min(len(whole), int((s1 + 0.08) * sr))]
            m = _hpf(m, sr, LAUGH_HPF[fam])
            m = _denoise(m, whole)
            m = _level(_trim_laugh(m, sr, LAUGH_MAX[fam]), sr)
            path = os.path.join(OUT, "sfx", "laugh_%s_%d.ogg" % (fam, i))
            sf.write(path, m, sr, format="OGG", subtype="VORBIS")
            e = _env_rms(m, sr, 1.0 / LAUGH_ENV_RATE)
            e = np.clip(e / max(np.percentile(e, 97), 1e-9), 0.0, 1.0)
            curves[fam].append("".join("0123456789abcdef"[int(round(v * 15))] for v in e))
            print("%-24s %5.2fs rms %5.1f pk %5.1f" % (os.path.basename(path), len(m) / sr,
                  db(active_rms(m, sr)), db(np.abs(m).max())))
    lines = [
        "class_name Laughs",
        "## Generated by tools/import_assets.py (build_laughs): do not edit.",
        "## The mocking laughs (assets/sfx/laugh_<family>_<take>.ogg), and for each",
        "## take its loudness RATE times a second as hex digits (0..f), which the",
        "## laughing enemy's mouth and bounce follow.",
        "",
        "const RATE := %.1f" % LAUGH_ENV_RATE,
        "const CURVES := {",
    ]
    for fam, cs in curves.items():
        lines.append('\t"%s": [' % fam)
        lines += ['\t\t"%s",' % c for c in cs]
        lines.append("\t],")
    lines.append("}")
    with open(os.path.join(os.path.dirname(OUT), "scripts", "laughs.gd"), "w") as f:
        f.write("\n".join(lines) + "\n")


def _k_loudness(d, sr):
    """Loudness with the K-weighting of ITU-R BS.1770 (a high shelf of
    +4 dB from ~1.7 kHz and a high-pass at 38 Hz, in the frequency domain),
    no gating: close to LUFS for music that never stops."""
    n = len(d)
    size = 1 << int(np.floor(np.log2(min(n, sr * 20))))
    f = np.fft.rfftfreq(size, 1.0 / sr)
    a = 10 ** (4 / 20.0)
    h = np.sqrt((1 + (f / 1681.0) ** 2 * a * a) / (1 + (f / 1681.0) ** 2)) * (f / 38.0) ** 2 / np.sqrt(1 + (f / 38.0) ** 4)
    total, count = 0.0, 0
    for i in range(0, n - size + 1, size):
        for ch in range(d.shape[1]):
            total += np.sum(np.abs(np.fft.rfft(d[i:i + size, ch]) * h) ** 2) / size ** 2 * 2
        count += 1
    return 10 * np.log10(total / count) - 0.691


def build_music(names=None):
    os.makedirs(os.path.join(OUT, "music"), exist_ok=True)
    for name, (src, start, bars, xfade, loud) in MUSIC.items():
        if names and name not in names:
            continue
        d, sr = sf.read(os.path.join(SRC, src), always_2d=True)
        if start is None:
            env = np.abs(d).max(axis=1)
            nz = np.nonzero(env > 1e-3)[0]
            d = d[nz[0]:]
        else:
            d = d[int(round(start * sr)):]
        loop_len = int(round(bars * BAR * sr)) if bars else None
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
        # Match the tracks' loudness, keep headroom.
        if loud is None:
            g = 10 ** ((-18.0 - db(np.sqrt(np.mean(d ** 2)))) / 20.0)
        else:
            g = 10 ** ((loud - _k_loudness(d, sr)) / 20.0)
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
    build_harp()
    build_surge()
    build_voices()
    build_laughs()
    build_music()
    build_particles()
