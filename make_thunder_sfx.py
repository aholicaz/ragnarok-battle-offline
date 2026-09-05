#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""เสียง "ฟ้าผ่า" ของสกิลสายฟ้าคำราม (รอบ 64) → Sprites/sfx/thunder_strike.ogg

    python3 make_thunder_sfx.py [--force]

เสียงจริงเอามาทับชื่อเดิมได้เลย · ต้องมี numpy + ffmpeg
"""
import os, sys, wave, tempfile, subprocess
import numpy as np

SR = 44100
OUT = "Sprites/sfx/thunder_strike.ogg"


def thunder():
    dur = 1.6
    n = int(SR * dur)
    t = np.linspace(0, dur, n, endpoint=False)
    rng = np.random.default_rng(64)

    # 1) แครก! — นอยส์แหลมสั้น ๆ ตอนฟ้าลง (ไฮพาส: นอยส์ลบนอยส์หน่วง)
    crack_env = np.exp(-42.0 * t)
    noise = rng.uniform(-1, 1, n)
    hp = noise - np.concatenate([[0], noise[:-1]])
    crack = 0.85 * crack_env * hp

    # 2) เปรี้ยง — คลื่นต่ำกระแทก
    boom = 0.6 * np.exp(-7.0 * t) * np.sin(2 * np.pi * 62 * t * (1 - 0.25 * t))
    boom += 0.35 * np.exp(-5.0 * t) * np.sin(2 * np.pi * 41 * t)

    # 3) ครืน ๆ — เสียงก้องยาว (นอยส์ผ่านฟิลเตอร์ต่ำแบบเฉลี่ยเคลื่อนที่ + สั่นเป็นลูก)
    rumble_n = rng.uniform(-1, 1, n)
    k = 220
    rumble = np.convolve(rumble_n, np.ones(k) / k, mode="same")
    wobble = 1.0 + 0.45 * np.sin(2 * np.pi * 7.5 * t) * np.exp(-1.6 * t)
    rumble = 0.9 * rumble * np.exp(-2.6 * t) * wobble

    return crack + boom + rumble


def main():
    force = "--force" in sys.argv
    os.makedirs("Sprites/sfx", exist_ok=True)
    if os.path.exists(OUT) and not force:
        print("มีอยู่แล้ว ข้าม:", OUT)
        return
    buf = thunder()
    peak = np.max(np.abs(buf)) or 1.0
    pcm = (np.clip(buf / peak * 0.92, -1, 1) * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        with wave.open(tmp.name, "wb") as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name,
                        "-c:a", "libvorbis", "-q:a", "4", OUT], check=True)
    os.unlink(tmp.name)
    print("สร้าง:", OUT, "%.0f KB" % (os.path.getsize(OUT) / 1024))


if __name__ == "__main__":
    main()
