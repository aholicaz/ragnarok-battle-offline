#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""★ ตั้งค่ามอนโจมตีระยะไกล (รอบ 66) ★ — รันในโฟลเดอร์โปรเจกต์

    python3 set_ranged_monsters.py            # ดูว่าจะตั้งอะไรบ้าง (ยังไม่เขียน)
    python3 set_ranged_monsters.py --apply    # เขียนจริง

ทำ 2 อย่าง
  1) ★ มอนยิงกระสุนทุกตัว ★ ยิงได้ตั้งแต่เห็นตัว ไม่ต้องเดินเข้ามาประชิด
     (ระบบใช้ Detect Range แทน Attack Range ให้เองอยู่แล้ว — สคริปต์แค่ตรวจและรายงาน
      ตัวไหนอยากให้ยิงไกล/ใกล้กว่าที่มองเห็น ใส่ Ranged Attack Range ใน Inspector)
  2) ★ บาฟโฟเมทจูเนียร์ ★ ให้ลูกวิญญาณออกตรงจังหวะที่มันผลักมือออกพอดี
     · ท่า Attack 17 เฟรม — เฟรม 11 คือจังหวะที่ลูกไฟหลุดจากมือ (วัดจากภาพจริง)
     · ตั้ง fps ของท่าใหม่ + ปิด loop (ท่าโจมตีต้องเล่นรอบเดียว)
     · จุดปล่อย/ขนาด/ความเร็วลูกไฟ วัดจากตำแหน่งมือในภาพ

สำรองไฟล์เดิมไว้ที่ _to_delete/originals_monsters_r66/
"""
import os, re, shutil, sys

BAK = "_to_delete/originals_monsters_r66"
apply = "--apply" in sys.argv

# =========================================================
# ★ ค่าที่จะตั้งให้บาฟโฟเมทจูเนียร์ ★ แก้ตรงนี้แล้วรันใหม่ได้เลย
# =========================================================
BAPJR = "data/monsters/baphomet_jr.tres"

## ท่า Attack เล่นกี่เฟรมต่อวินาที
##   5 fps  = ท่ายาว 3.4 วิ · ลูกไฟออกตอน 2.2 วิ (ช้า)
##   8 fps  = ท่ายาว 2.1 วิ · ลูกไฟออกตอน 1.4 วิ
##  14 fps  = ท่ายาว 1.2 วิ · ลูกไฟออกตอน 0.8 วิ  ← ★ ค่าที่คุณตั้งไว้เอง ★
ATTACK_FPS = 14.0

BAPJR_VALUES = {
    # ---- จังหวะ ----
    "attack_hit_frame": "11",       # ★ เฟรมที่ลูกไฟหลุดจากมือ ★
    "attack_follow_anim": "true",   # เล่นท่าจนจบ ไม่ตัดกลางคัน
    "attack_windup": "0.25",        # (ไม่ได้ใช้แล้วเพราะมี hit frame — ไว้กันโค้ดเก่า)
    "attack_cooldown": "1.0",
    # ---- ยิงจากไกล ----
    "ranged_attack": "true",
    "ranged_attack_range": "0.0",   # 0 = ใช้ Detect Range (460)
    # ---- ลูกวิญญาณ ----
    # จุดปล่อย = ตำแหน่งมือที่ยื่นออกไปในเฟรม 11 (วัดจากภาพ: หน้า 119 px · สูง 110 px จากเท้า)
    "projectile_offset": "Vector2(120, -110)",
    "projectile_height": "70.0",
    "projectile_speed": "820.0",
    "projectile_range": "820.0",
    "projectile_hit_size": "Vector2(56, 56)",
    "projectile_faces_left": "true",  # หัวลูกไฟอยู่ทางซ้ายของภาพ หางชี้ขวา
    "projectile_spin": "0.0",
}


def backup(path):
    os.makedirs(BAK, exist_ok=True)
    b = os.path.join(BAK, os.path.basename(path))
    if not os.path.exists(b):
        shutil.copy2(path, b)
    return b


def set_props(path, values):
    """ตั้งค่าในบล็อก [resource] ของไฟล์ .tres"""
    s = open(path, encoding="utf-8").read()
    at = s.index("[resource]")
    head, body = s[:at], s[at:]
    changed = []
    for key, val in values.items():
        m = re.search(r"^%s = (.*)$" % re.escape(key), body, re.M)
        if m:
            if m.group(1).strip() != val:
                changed.append((key, m.group(1).strip(), val))
                body = body[:m.start()] + "%s = %s" % (key, val) + body[m.end():]
        else:
            changed.append((key, "(ไม่มี)", val))
            body = body.rstrip("\n") + "\n%s = %s\n" % (key, val)
    for k, old, new in changed:
        print("    %-24s %-18s → %s" % (k, old, new))
    if not changed:
        print("    (ตั้งไว้ครบแล้ว)")
        return
    if not apply:
        return
    backup(path)
    open(path, "w", encoding="utf-8").write(head + body)


def fix_attack_anim(path, fps, unloop=True):
    """ตั้ง speed + ปิด loop ของท่า Attack ใน SpriteFrames ที่ฝังอยู่ในไฟล์"""
    s = open(path, encoding="utf-8").read()
    key = '"name": &"Attack"'
    if key not in s:
        print("    (ไม่มีท่า Attack — ข้าม)")
        return
    i = s.index(key)
    start = s.rfind('"frames": [', 0, i)
    end = s.index("}", i)
    head, block, tail = s[:start], s[start:end], s[end:]
    new = block
    m = re.search(r'"speed": ([\d.]+)', new)
    if m and float(m.group(1)) != fps:
        print("    ท่า Attack: fps %s → %.1f" % (m.group(1), fps))
        new = new[:m.start()] + '"speed": %.1f' % fps + new[m.end():]
    if unloop:
        m2 = re.search(r'"loop": (true|1)', new)
        if m2:
            print("    ท่า Attack: loop เปิด → ปิด (เล่นรอบเดียว)")
            new = new[:m2.start()] + '"loop": false' + new[m2.end():]
    if new == block:
        print("    (ท่า Attack ตั้งไว้ถูกแล้ว)")
        return
    if not apply:
        return
    backup(path)
    open(path, "w", encoding="utf-8").write(head + new + tail)


def scan_ranged():
    """ไล่ดูมอนทุกตัวว่าใครยิงกระสุนบ้าง แล้วบอกระยะยิงใหม่"""
    print("\n★ มอนที่ยิงกระสุน (ได้ระยะยิงใหม่ = ระยะมองเห็น) ★")
    rows = []
    for name in sorted(os.listdir("data/monsters")):
        if not name.endswith(".tres"):
            continue
        p = os.path.join("data/monsters", name)
        s = open(p, encoding="utf-8").read()
        body = s[s.index("[resource]"):] if "[resource]" in s else s
        if not re.search(r"^projectile_texture = ", body, re.M):
            continue

        def num(k, d):
            m = re.search(r"^%s = ([-\d.]+)$" % k, body, re.M)
            return float(m.group(1)) if m else d

        def txt(k, d=""):
            m = re.search(r'^%s = "(.*)"$' % k, body, re.M)
            return m.group(1) if m else d

        rng = num("ranged_attack_range", 0.0)
        detect = num("detect_range", 250.0)
        atk = num("attack_range", 70.0)
        rows.append((txt("display_name", name), atk, detect, rng if rng > 0 else max(detect, atk)))
    if not rows:
        print("  (ไม่มี)")
    w = max(len(r[0]) for r in rows) if rows else 10
    for nm, atk, detect, reach in rows:
        print("  %-*s  เดิมต้องเข้าใกล้ %4.0f px  →  ยิงได้ตั้งแต่ %4.0f px (ระยะมองเห็น %.0f)"
              % (w, nm, atk, reach, detect))


def main():
    if not os.path.isdir("data/monsters"):
        sys.exit("ต้องรันในโฟลเดอร์โปรเจกต์ (ไม่เจอ data/monsters)")
    scan_ranged()
    print("\n★ บาฟโฟเมทจูเนียร์ — ลูกวิญญาณออกตรงจังหวะผลักมือ ★")
    if not os.path.exists(BAPJR):
        print("  (ไม่พบ %s)" % BAPJR)
    else:
        fix_attack_anim(BAPJR, ATTACK_FPS)
        set_props(BAPJR, BAPJR_VALUES)
        n = 17
        print("    → ท่ายาว %.2f วิ · ลูกไฟออกตอน %.2f วิ"
              % (n / ATTACK_FPS, int(BAPJR_VALUES["attack_hit_frame"]) / ATTACK_FPS))
    if not apply:
        print("\n(ใส่ --apply เพื่อเขียนจริง)")
    else:
        print("\nเขียนแล้ว · สำรองที่ %s" % BAK)


if __name__ == "__main__":
    main()
