#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""รอบ 58 — ดูว่าเสียงเอฟเฟกต์ไฟล์ไหนถูกใช้ตรงไหน และยังขาดอะไร

    python3 check_sfx.py

วางไฟล์ที่ Sprites/sfx/<ชื่อ>.ogg (หรือ .wav/.mp3) — ชื่อผิดตัวเดียวเกมจะเงียบเฉย ๆ ไม่มี error
"""
import os, re, glob

DIRS = ["Sprites/sfx", "sfx", "audio/sfx", "Sprites/audio"]
EXTS = (".ogg", ".wav", ".mp3")

have = {}
for d in DIRS:
    if os.path.isdir(d):
        for f in sorted(os.listdir(d)):
            if f.lower().endswith(EXTS):
                have.setdefault(os.path.splitext(f)[0], os.path.join(d, f))

# ท่าโจมตีของตัวละคร (จาก player_frames) → ชื่อเสียง attack_<อาวุธ>
anims = re.findall(r'"name": &"(Attack[^"]*)"', open("data/sprites/player_frames.tres", encoding="utf-8").read())
weapons = sorted({a.lower().split("_")[1] for a in anims if "_" in a})
# สกิลที่ต้องกดใช้ (type != PASSIVE=4)
skills = []
for p in sorted(glob.glob("data/skills/*.tres")):
    t = open(p, encoding="utf-8").read()
    m = re.search(r"^type = (\d+)", t, re.M)
    typ = int(m.group(1)) if m else 0
    if typ == 4:
        continue
    sid = os.path.basename(p)[:-5]
    snd = re.search(r'^sound = "([^"]*)"', t, re.M)
    skills.append((sid, typ, snd.group(1) if snd else ""))

def mark(k):
    return "✓ %s" % have[k] if k in have else "○ (ยังไม่มี)"

print("=" * 66)
print("ไฟล์เสียงที่มี %d ไฟล์" % len(have))
print("=" * 66)
print("\n[ฟันธรรมดา]  ลำดับหา: attack_<อาวุธ> → attack_blade → attack")
for w in weapons:
    print("   attack_%-14s %s" % (w, mark("attack_%s" % w)))
print("   %-21s %s" % ("attack", mark("attack")))

print("\n[สกิลที่ต้องกดใช้]  ลำดับหา: (ช่อง Sound) → attack_<อาวุธ>_<สกิล> → skill_<สกิล> → เสียงฟันของอาวุธ")
for sid, typ, snd in skills:
    kind = {2: "บัฟ", 3: "ฮีล"}.get(typ, "โจมตี")
    line = "   %-16s %-6s skill_%-18s %s" % (sid, kind, sid, mark("skill_%s" % sid))
    if snd:
        line += "   · ตั้ง Sound=%s %s" % (snd, mark(snd))
    print(line)
    if typ not in (2, 3):
        for w in weapons:
            k = "attack_%s_%s" % (w, sid)
            if k in have:
                print("      ↳ เฉพาะอาวุธ %-24s ✓ %s" % (k, have[k]))
print("\n[สำรอง]  skill_heal %s · skill_buff %s" % (mark("skill_heal"), mark("skill_buff")))

used = set(["attack"]) | {"attack_%s" % w for w in weapons} | {"skill_%s" % s[0] for s in skills} \
    | {"attack_%s_%s" % (w, s[0]) for w in weapons for s in skills} | {s[2] for s in skills if s[2]} \
    | {"skill_heal", "skill_buff", "hit", "level_up", "warp"}
extra = [k for k in have if k not in used]
if extra:
    print("\n✗ ไฟล์ที่ไม่มีอะไรเรียกใช้ (ชื่อผิด?): " + ", ".join(extra))
print()
