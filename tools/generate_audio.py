#!/usr/bin/env python3
"""Synthesises ALL sound effects and the music loop (original, no samples) - v2 'game-feel' pass.
Bell/pluck/bloop voices, pentatonic combo chimes, echo for space.
Run from the project root:  python3 tools/generate_audio.py
Output: 22.05 kHz mono 16-bit WAV in assets/sounds and assets/music.
"""
import math
import os
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SR = 22050
RNG = np.random.default_rng(11)


def save(path, x, peak=0.85):
    p = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    m = float(np.abs(x).max()) or 1.0
    x = x / m * peak
    with wave.open(p, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())


def T(sec):
    return np.arange(int(SR * sec)) / SR


def env(t, attack=0.004, decay=8.0):
    return np.minimum(t / attack, 1.0) * np.exp(-decay * t)


def sine(f, sec, vol=1.0, decay=8.0, attack=0.004):
    t = T(sec)
    return np.sin(2 * np.pi * f * t) * env(t, attack, decay) * vol


def bell(f, sec=0.9, vol=1.0, decay=4.5):
    """Inharmonic additive bell (glass / music-box)."""
    t = T(sec)
    out = np.zeros_like(t)
    for ratio, amp, dec in [(1.0, 1.0, 1.0), (2.0, 0.5, 1.3), (2.76, 0.35, 1.8), (5.4, 0.18, 2.6), (8.9, 0.08, 3.4)]:
        out += amp * np.sin(2 * np.pi * f * ratio * t) * np.exp(-decay * dec * t)
    return out * np.minimum(t / 0.003, 1.0) * vol


def pluck(f, sec=0.5, vol=1.0, decay=7.0):
    t = T(sec)
    w = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * 2 * f * t) + 0.12 * np.sin(2 * np.pi * 3 * f * t)
    return w * env(t, 0.003, decay) * vol


def bloop(f0, f1, sec, vol=1.0, decay=14.0):
    t = T(sec)
    f = f0 * (f1 / f0) ** (t / sec)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * env(t, 0.002, decay) * vol


def noise(sec, decay=20.0, vol=1.0):
    t = T(sec)
    return RNG.uniform(-1, 1, len(t)) * env(t, 0.001, decay) * vol


def lowpass(x, k):
    k = max(1, int(k))
    return np.convolve(x, np.ones(k) / k, mode="same")


def echo(x, delay=0.17, fb=0.35, taps=4, mix=0.5):
    out = np.zeros(len(x) + int(SR * delay * taps) + 1)
    out[: len(x)] += x
    for i in range(1, taps + 1):
        d = int(SR * delay * i)
        out[d : d + len(x)] += x * (fb ** i) * mix
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def at(x, sec, total):
    out = np.zeros(int(SR * total))
    i = int(SR * sec)
    out[i : i + len(x)] += x[: len(out) - i]
    return out


PENTA = [523.25, 587.33, 659.25, 783.99, 880.00, 1046.5, 1174.7, 1318.5]  # C major pentatonic from C5


def make_sfx():
    # Minnaert-style bubble voice: a damped sine whose pitch rises a little, like a real water bubble
    def bubble(f0, rise=0.35, sec=0.11, vol=1.0, decay=38.0):
        t = T(sec)
        f = f0 * (1 + rise * (1 - np.exp(-t * 60)))
        return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(t, 0.0015, decay) * vol
    t = T(0.18)
    whoosh = lowpass(RNG.uniform(-1, 1, len(t)), 12) * np.sin(np.pi * np.clip(t / 0.18, 0, 1)) ** 1.6
    save("assets/sounds/shoot.wav", mix(whoosh * 1.2, bubble(380, 0.9, 0.16, 0.5, 14)))
    for i, f0 in enumerate([880, 1020, 1180, 760]):
        pop = mix(bubble(f0, 0.45, 0.1, 1.0, 42), at(bubble(f0 * 1.5, 0.4, 0.08, 0.35, 48), 0.008, 0.1), lowpass(noise(0.02, 160, 0.35), 4))
        save("assets/sounds/pop%s.wav" % ("" if i == 0 else "_%d" % i), echo(pop, 0.045, 0.22, 2, 0.3))
    save("assets/sounds/pop_big.wav", echo(mix(bubble(700, 0.5, 0.14, 1.0, 30), at(bubble(1050, 0.4, 0.12, 0.7, 34), 0.03, 0.2), at(bell(PENTA[2], 0.5, 0.35, 7), 0.04, 0.6), at(bell(PENTA[4], 0.5, 0.3, 7), 0.1, 0.6)), 0.08, 0.28, 3, 0.4))
    for i in range(5):
        save("assets/sounds/chime_%d.wav" % i, echo(mix(bell(PENTA[i], 0.7, 0.8, 6.0), at(bell(PENTA[i + 2], 0.6, 0.45, 7.0), 0.07, 0.7)), 0.11, 0.26, 3, 0.45))
    save("assets/sounds/bounce.wav", bloop(560, 330, 0.07, 0.8, 30))
    save("assets/sounds/land.wav", mix(bubble(170, 0.25, 0.1, 1.0, 30), lowpass(noise(0.025, 110, 0.25), 8)))
    save("assets/sounds/drop.wav", echo(mix(bloop(900, 260, 0.35, 0.8, 7), at(bloop(700, 240, 0.3, 0.5, 8), 0.07, 0.4)), 0.07, 0.3, 2, 0.4))
    save("assets/sounds/click.wav", mix(sine(880, 0.05, 0.8, 70), lowpass(noise(0.012, 200, 0.4), 3), bell(1760, 0.1, 0.18, 18)))
    save("assets/sounds/coin.wav", echo(mix(bell(1318.5, 0.5, 0.8, 6), at(bell(1975.5, 0.7, 0.8, 5), 0.07, 0.8)), 0.1, 0.3, 3, 0.45))
    save("assets/sounds/power.wav", echo(mix(bloop(280, 1400, 0.32, 0.7, 5), at(bell(1760, 0.6, 0.5, 5), 0.18, 0.8), at(bell(2349, 0.6, 0.4, 5), 0.26, 0.8)), 0.09, 0.3, 3, 0.4))
    boom = mix(lowpass(noise(0.5, 6, 1.0), 14), bloop(130, 38, 0.45, 1.1, 6), lowpass(noise(0.12, 25, 0.6), 3))
    save("assets/sounds/explosion.wav", echo(boom, 0.09, 0.3, 2, 0.35))
    save("assets/sounds/lightning.wav", mix(noise(0.3, 14, 0.5), bloop(3200, 260, 0.26, 0.7, 11), at(bloop(2600, 400, 0.2, 0.5, 14), 0.06, 0.4)))
    t = T(0.6)
    swell = lowpass(RNG.uniform(-1, 1, len(t)), 9) * np.sin(np.pi * np.clip(t / 0.6, 0, 1)) ** 1.3
    save("assets/sounds/fire.wav", mix(swell * 1.6, bloop(180, 520, 0.55, 0.45, 3)))
    save("assets/sounds/freeze.wav", echo(mix(bell(2093, 0.9, 0.7, 3.5), at(bell(2637, 0.9, 0.55, 3.5), 0.06, 1.0), at(bell(3136, 0.9, 0.45, 3.5), 0.12, 1.0)), 0.13, 0.35, 3, 0.5))
    fan = [523.25, 659.25, 783.99, 1046.5]
    win = mix(*[at(bell(f, 0.8, 0.9, 4.5), 0.13 * i, 1.8) for i, f in enumerate(fan)],
              at(mix(bell(1046.5, 1.2, 0.8, 3), bell(1318.5, 1.2, 0.6, 3), bell(1568, 1.2, 0.5, 3)), 0.55, 1.8))
    save("assets/sounds/win.wav", echo(win, 0.16, 0.38, 4, 0.5))
    lose = mix(*[at(bell(f, 0.9, 0.8, 4), 0.22 * i, 1.6) for i, f in enumerate([392.0, 349.23, 311.13, 261.63])])
    save("assets/sounds/lose.wav", echo(lose, 0.18, 0.3, 3, 0.4))
    save("assets/sounds/star.wav", echo(mix(bell(1046.5, 0.7, 0.9, 5), at(bell(1568, 0.8, 0.8, 5), 0.09, 0.9)), 0.1, 0.3, 3, 0.45))


def make_music():
    """C - Am - F - G, 118 bpm, 16 bars (~32 s). Bell melody, plucky bass, soft pad, light shaker, wraps cleanly."""
    bpm = 100
    beat = 60.0 / bpm
    bars = 16
    total = beat * 4 * bars
    n = int(SR * total)
    out = np.zeros(n + int(SR * 3))
    chords = [(261.63, 329.63, 392.0), (220.0, 261.63, 329.63), (174.61, 220.0, 261.63), (196.0, 246.94, 293.66)]
    bass = [130.81, 110.0, 87.31, 98.0]
    motif = [0, 2, 4, 2, 3, 2, 1, 2, 4, 5, 4, 2, 3, 2, 1, 0]
    for bar in range(bars):
        ci = (bar // 1) % 4
        t0 = bar * beat * 4
        for f in chords[ci]:
            pad = sine(f, beat * 4.2, 0.09, 0.5, 0.3)
            i = int(t0 * SR)
            out[i : i + len(pad)] += pad
        for b in (0, 1.5, 2, 3.5):
            bp = pluck(bass[ci], beat * 1.2, 0.34, 6.5)
            i = int((t0 + b * beat) * SR)
            out[i : i + len(bp)] += bp
        for k in range(8):
            idx = motif[(bar * 8 + k) % len(motif)]
            if k % 2 == 1 or (k in (2, 6) and bar % 2 == 0):
                continue  # sparse, relaxed melody
            f = PENTA[idx % 8] * (1 if (bar // 4) % 2 == 0 else 1.0)
            note = bell(f, beat * 2.2, 0.15, 3.4)
            i = int((t0 + k * beat / 2) * SR)
            out[i : i + len(note)] += note
    out = echo(out[: n + int(SR * 2)], 0.19, 0.33, 3, 0.4)
    loop = out[:n].copy()
    tail = out[n : n + int(SR * 2)]
    loop[: len(tail)] += tail[: len(loop)]  # fold the echo tail back to the start -> seamless loop
    loop = lowpass(loop, 3)  # take the edge off the bells
    save("assets/music/mystic_loop.wav", loop, peak=0.7)


if __name__ == "__main__":
    make_sfx()
    make_music()
    print("audio generated")
