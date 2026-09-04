#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""รอบ 52 — ตรวจไฟล์เพลงว่าชื่อตรงกับแมพไหม + บอกว่าแมพไหนยังไม่มีเพลง

    python3 check_music.py

วางไฟล์เพลงที่ Sprites/music/<map_id>.mp3 แล้วรันสคริปต์นี้เช็คได้เลยว่าชื่อถูกไหม
(ชื่อผิดแม้แต่ตัวเดียว เกมจะหาไม่เจอแล้วเงียบไปเฉย ๆ ไม่มี error บอก)
"""
import os, re, glob

MUSIC_DIRS = ["Sprites/music", "music", "Sprites/Music", "audio/music"]
EXTS = (".mp3", ".ogg", ".wav")
SPECIAL = {"title": "หน้าหลัก (title screen)", "boss": "เพลงบอส (เรียกเองในโค้ด)"}


def map_ids():
    """map_id ของทุกแมพ + ชื่อไทย (ค่า default ไม่ถูกเขียนลง .tscn ต้องเติมเอง)"""
    out = {}
    for path in sorted(glob.glob("scenes/maps/*.tscn")):
        text = open(path, encoding="utf-8", errors="ignore").read()
        m = re.search(r'^map_id = &"([^"]+)"', text, re.M)
        mid = m.group(1) if m else os.path.basename(path)[:-5]
        n = re.search(r'^display_name = "([^"]*)"', text, re.M)
        out[mid] = n.group(1) if n else ""
    return out


def tracks():
    found = {}
    for d in MUSIC_DIRS:
        if not os.path.isdir(d):
            continue
        for f in sorted(os.listdir(d)):
            if f.lower().endswith(EXTS):
                key = os.path.splitext(f)[0]
                found.setdefault(key, os.path.join(d, f).replace("\\", "/"))
    return found


maps = map_ids()
have = tracks()

print("=" * 62)
print("เพลงที่มีอยู่ %d ไฟล์ · แมพทั้งหมด %d แมพ" % (len(have), len(maps)))
print("=" * 62)

ok, bad = [], []
for key, path in sorted(have.items()):
    if key in maps or key in SPECIAL:
        ok.append((key, path))
    else:
        bad.append((key, path))

print("\n✓ ใช้งานได้ (%d)" % len(ok))
for key, path in ok:
    label = SPECIAL.get(key) or maps.get(key, "")
    size = os.path.getsize(path) / 1048576.0
    print("   %-22s %-28s %.1f MB" % (key, label, size))

if bad:
    print("\n✗ ★ ชื่อไม่ตรงกับแมพไหนเลย — เกมจะไม่เล่นไฟล์นี้ ★ (%d)" % len(bad))
    for key, path in bad:
        # เดาว่าน่าจะหมายถึงแมพไหน (ชื่อใกล้เคียง)
        guess = [m for m in maps if m.startswith(key[:5]) or key.startswith(m[:5])]
        hint = ("  ← ตั้งใจหมายถึง %s ไหม?" % " / ".join(guess)) if guess else ""
        print("   %-22s %s%s" % (key, path, hint))

missing = [m for m in sorted(maps) if m not in have]
print("\n○ แมพที่ยังไม่มีเพลง (%d) — วางไฟล์ชื่อนี้ได้เลย" % len(missing))
for m in missing:
    print("   Sprites/music/%s.mp3%s%s" % (m, " " * max(1, 24 - len(m)), maps[m]))

if "title" not in have:
    print("\n○ อยากมีเพลงหน้าหลักด้วย วางไฟล์  Sprites/music/title.mp3")
print()
