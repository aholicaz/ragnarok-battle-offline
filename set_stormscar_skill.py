#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ตั้งสกิล "สายฟ้าคำราม" ให้อสูรสายฟ้า (รอบ 64) — รันในโฟลเดอร์โปรเจกต์

    python3 set_stormscar_skill.py            # ดูว่าจะตั้งอะไร
    python3 set_stormscar_skill.py --apply    # เขียนลง data/monsters/stormscar.tres

ตั้งอะไรบ้าง:
  · skill_anim = "Skill"  (ท่าคำรามที่วาดไว้ 32 เฟรม 12fps = 2.67 วิ)
  · จังหวะให้สายฟ้าเริ่มฟาดตอน "อ้าปากคำราม" (เฟรม ~11 = 0.9 วิ)
  · สายฟ้า 5 เส้น เรียงออกไปข้างหน้า ห่างกัน 150 px ฟาดห่างกัน 0.14 วิ
สำรองไฟล์เดิมไว้ที่ _to_delete/originals_monsters_r64/
"""
import os, re, shutil, sys

FILE = "data/monsters/stormscar.tres"
FRAMES = "data/sprites/placeholder/stormscar_frames.tres"
BAK = "_to_delete/originals_monsters_r64"
apply = "--apply" in sys.argv

## ★ ค่าที่จะตั้ง ★ แก้ตรงนี้แล้วรันใหม่ได้เลย
VALUES = {
    # ---- ท่า + จังหวะ ----
    "skill_name": '"สายฟ้าคำราม"',
    "skill_anim": '&"Skill"',
    "skill_range": "520.0",        # เห็นผู้เล่นไกลแค่ไหนถึงร่าย (แนวสายฟ้ายาว ~750)
    "skill_duration": "2.7",       # ท่าคำราม 32 เฟรม / 12fps
    "skill_windup": "0.9",         # (ไม่ได้ใช้ทำดาเมจแล้ว — สายฟ้าคิดเอง) ไว้กันโค้ดเก่า
    "skill_cooldown": "11.0",
    "skill_chance": "0.75",
    "skill_damage_mult": "1.6",
    "skill_knockback": "340.0",
    # ---- สายฟ้า 5 เส้น ----
    "skill_bolt_count": "5",
    "skill_bolt_start": "150.0",
    "skill_bolt_spacing": "150.0",
    "skill_bolt_interval": "0.14",
    "skill_bolt_telegraph": "0.32",
    "skill_bolt_delay": "0.9",     # เริ่มฟาดตอนอ้าปากคำราม (เฟรม 11)
    "skill_bolt_hit_width": "95.0",
    "skill_bolt_hit_height": "260.0",
    "skill_bolt_max_hits": "2",
    "skill_bolt_height": "560.0",
    "skill_bolt_sfx": '"thunder_strike"',
    "skill_bolt_z": "70",
}


def unloop_skill():
    """ท่าคำรามตั้ง loop ไว้ = พอเล่นจบจะวนกลับไปคำรามใหม่ → ปิด loop ให้เล่นรอบเดียว"""
    if not os.path.exists(FRAMES):
        print("(ไม่พบ %s — ข้าม)" % FRAMES)
        return
    s = open(FRAMES, encoding="utf-8").read()
    # หาบล็อกของท่า Skill แล้วปิด loop เฉพาะบล็อกนั้น
    key = '"name": &"Skill"'
    if key not in s:
        print("(ไม่มีท่า Skill ใน %s — ข้าม)" % FRAMES)
        return
    i = s.index(key)
    start = s.rfind('"frames": [', 0, i)
    head, block, tail = s[:start], s[start:i], s[i:]
    # Godot เขียนได้ทั้ง  "loop": true  และ  "loop": 1
    if re.search(r'"loop":\s*(false|0)', block):
        print("ท่า Skill ปิด loop อยู่แล้ว")
        return
    new_block = re.sub(r'"loop":\s*(true|1)', '"loop": false', block, count=1)
    if new_block == block:
        print("(หาบรรทัด loop ของท่า Skill ไม่เจอ — ข้าม)")
        return
    print("  ท่า Skill: loop true → false (เล่นรอบเดียว ไม่วนคำรามซ้ำ)")
    if not apply:
        return
    os.makedirs(BAK, exist_ok=True)
    bak = os.path.join(BAK, os.path.basename(FRAMES))
    if not os.path.exists(bak):
        shutil.copy2(FRAMES, bak)
    open(FRAMES, "w", encoding="utf-8").write(head + new_block + tail)
    print("  เขียนแล้ว: %s" % FRAMES)


def main():
    unloop_skill()
    if not os.path.exists(FILE):
        sys.exit("ไม่พบ %s" % FILE)
    s = open(FILE, encoding="utf-8").read()
    body_at = s.index("[resource]")
    head, body = s[:body_at], s[body_at:]

    changed = []
    for key, val in VALUES.items():
        m = re.search(r"^%s = (.*)$" % re.escape(key), body, re.M)
        if m:
            if m.group(1).strip() != val:
                changed.append((key, m.group(1).strip(), val))
                body = body[:m.start()] + "%s = %s" % (key, val) + body[m.end():]
        else:
            changed.append((key, "(ไม่มี)", val))
            body = body.rstrip("\n") + "\n%s = %s\n" % (key, val)

    if not changed:
        print("ตั้งไว้ครบแล้ว ไม่มีอะไรต้องแก้")
        return
    for k, old, new in changed:
        print("  %-26s %-14s → %s" % (k, old, new))
    if not apply:
        print("\n(ใส่ --apply เพื่อเขียนจริง)")
        return
    os.makedirs(BAK, exist_ok=True)
    bak = os.path.join(BAK, os.path.basename(FILE))
    if not os.path.exists(bak):
        shutil.copy2(FILE, bak)
    open(FILE, "w", encoding="utf-8").write(head + body)
    print("\nเขียนแล้ว: %s  (สำรองที่ %s)" % (FILE, bak))


if __name__ == "__main__":
    main()
