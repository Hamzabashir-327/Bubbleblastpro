#!/usr/bin/env python3
"""Builds ONE self-contained HTML file: a playable web preview of the game.
Same levels, sprites and rules (JS port of board_logic.gd). Not the Android build.

    python3 tools/build_web_preview.py [output.html]
"""
import base64
import glob
import io
import json
import os
import sys
import wave

import numpy as np

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def b64(path, mime):
    return "data:%s;base64,%s" % (mime, base64.b64encode(open(path, "rb").read()).decode())


def jpeg(path, q=72):
    buf = io.BytesIO()
    Image.open(path).convert("RGB").save(buf, "JPEG", quality=q, optimize=True)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()


def wav_uri(path, target_sr):
    """Embed a WAV, resampled to target_sr (keeps the page small; SFX are fine at 16 kHz, music at 11 kHz)."""
    w = wave.open(path)
    sr = w.getframerate()
    x = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float64)
    if sr != target_sr:
        k = max(1, int(round(sr / target_sr)))
        x = np.convolve(x, np.ones(k) / k, mode="same")  # crude anti-alias
        n = int(len(x) * target_sr / sr)
        x = np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x)
    buf = io.BytesIO()
    with wave.open(buf, "wb") as o:
        o.setnchannels(1)
        o.setsampwidth(2)
        o.setframerate(target_sr)
        o.writeframes(np.clip(x, -32768, 32767).astype("<i2").tobytes())
    return "data:audio/wav;base64," + base64.b64encode(buf.getvalue()).decode()


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "build/bubble_blast_preview.html")
    assets = {}
    for i in range(6):
        assets["bubble_%d" % i] = b64(os.path.join(ROOT, "assets/bubbles/bubble_%d.png" % i), "image/png")
    for n in ["ice", "stone", "lock", "critter", "rainbow", "bomb", "lightning", "fireball"]:
        assets[n] = b64(os.path.join(ROOT, "assets/bubbles/%s.png" % n), "image/png")
    for n in ["rainbow", "bomb", "lightning", "fireball", "color_switch", "time_freeze"]:
        assets["power_" + n] = b64(os.path.join(ROOT, "assets/icons/power_%s.png" % n), "image/png")
    for n in ["star_on", "star_off", "swap", "powered_by", "node_open", "node_done", "node_locked", "node_boss", "node_halo", "marker",
              "title_select_level", "title_level_complete", "title_game_over", "title_paused", "menu", "back", "lock_small"]:
        assets[n] = b64(os.path.join(ROOT, "assets/ui/%s.png" % n), "image/png")
    for i in (1, 2, 3):
        assets["bg%d" % i] = jpeg(os.path.join(ROOT, "assets/backgrounds/world_%d.png" % i))
    audio = {}
    for n in ["shoot", "pop", "pop_1", "pop_2", "pop_3", "pop_big", "bounce", "land", "drop", "click", "power", "explosion", "win", "lose", "star", "freeze"] + ["chime_%d" % i for i in range(5)]:
        audio[n] = wav_uri(os.path.join(ROOT, "assets/sounds/%s.wav" % n), 16000)
    audio["music"] = wav_uri(os.path.join(ROOT, "assets/music/mystic_loop.wav"), 11025)
    levels = [json.load(open(p)) for p in sorted(glob.glob(os.path.join(ROOT, "data/levels/level_*.json")))]
    tpl = open(os.path.join(ROOT, "tools/web_preview_template.html")).read()
    html = (tpl.replace("__FONT__", b64(os.path.join(ROOT, "assets/fonts/Poppins-Bold.ttf"), "font/ttf")).replace("__FONTM__", b64(os.path.join(ROOT, "assets/fonts/Poppins-Medium.ttf"), "font/ttf"))
            .replace("__BG1__", assets["bg1"]).replace("__LOGO__", b64(os.path.join(ROOT, "assets/ui/logo.png"), "image/png"))
            .replace("__BADGE__", assets["powered_by"]).replace("__BACK__", assets["back"]).replace("__LOCKS__", assets["lock_small"]).replace("__T_SELECT__", assets["title_select_level"]).replace("__ASSETS__", json.dumps(assets)).replace("__AUDIO__", json.dumps(audio)).replace("__LEVELS__", json.dumps(levels, separators=(",", ":"))))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    open(out, "w").write(html)
    print("wrote %s (%.0f KB, %d levels)" % (out, len(html) / 1024, len(levels)))


if __name__ == "__main__":
    main()
