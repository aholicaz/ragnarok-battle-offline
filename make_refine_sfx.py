#!/usr/bin/env python3
"""สร้างเสียงตัวอย่างหน้าตีบวก (รอบ 59) — ไว้ใช้ชั่วคราวจนกว่าจะมีเสียงจริง

    python3 make_refine_sfx.py            → Sprites/sfx/refine_roll.ogg / refine_success.ogg / refine_fail.ogg

ไฟล์ที่มีอยู่แล้วจะไม่ถูกเขียนทับ (ใส่ --force ถ้าอยากสร้างใหม่)
ต้องมี numpy + ffmpeg
"""
import os, sys, subprocess, tempfile, wave, struct
import numpy as np

SR = 44100
OUT = "Sprites/sfx"


def tone(freq, dur, vol=0.5, decay=6.0, wave_fn=np.sin):
    t = np.linspace(0, dur, int(SR * dur), endpoint=False)
    env = np.exp(-decay * t)
    return vol * env * wave_fn(2 * np.pi * freq * t)


def noise(dur, vol=0.3, decay=20.0):
    t = np.linspace(0, dur, int(SR * dur), endpoint=False)
    return vol * np.exp(-decay * t) * np.random.uniform(-1, 1, t.size)


def place(buf, snd, at):
    i = int(at * SR)
    n = min(snd.size, buf.size - i)
    if n > 0:
        buf[i:i + n] += snd[:n]


def roll():
    """ค้อนเคาะถี่ขึ้นเรื่อย ๆ 1.6 วิ (ตรงกับ ROLL_TIME)"""
    dur = 1.7
    buf = np.zeros(int(SR * dur))
    t = 0.0
    gap = 0.22
    while t < 1.55:
        place(buf, tone(180 + 400 * (t / 1.6), 0.12, 0.35, 30), t)
        place(buf, noise(0.05, 0.25, 60), t)
        t += gap
        gap = max(0.05, gap * 0.82)
    return buf


def success():
    dur = 1.4
    buf = np.zeros(int(SR * dur))
    for i, f in enumerate([523.25, 659.25, 783.99, 1046.5]):     # C E G C
        place(buf, tone(f, 0.9, 0.35, 4.0), i * 0.09)
        place(buf, tone(f * 2, 0.6, 0.12, 6.0), i * 0.09)
    place(buf, noise(0.3, 0.12, 12), 0.0)                        # ประกาย
    return buf


def fail():
    dur = 1.0
    buf = np.zeros(int(SR * dur))
    place(buf, noise(0.25, 0.6, 18), 0.0)                        # เปรี้ยง
    place(buf, tone(110, 0.8, 0.5, 5.0, lambda x: np.sign(np.sin(x))), 0.03)   # ทุ้ม
    place(buf, tone(82, 0.8, 0.4, 4.0), 0.06)
    return buf


def write_ogg(buf, path):
    peak = np.max(np.abs(buf)) or 1.0
    pcm = (np.clip(buf / peak * 0.9, -1, 1) * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        with wave.open(tmp.name, "wb") as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name,
                        "-c:a", "libvorbis", "-q:a", "4", path], check=True)
    os.unlink(tmp.name)


if __name__ == "__main__":
    force = "--force" in sys.argv
    os.makedirs(OUT, exist_ok=True)
    for name, fn in [("refine_roll", roll), ("refine_success", success), ("refine_fail", fail)]:
        path = os.path.join(OUT, name + ".ogg")
        if os.path.exists(path) and not force:
            print("มีอยู่แล้ว ข้าม:", path)
            continue
        write_ogg(fn(), path)
        print("สร้าง:", path)
