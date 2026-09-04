#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""รอบ 54 — ตั้งให้มอน "บิน/ลอยเหนือพื้น" (แก้ data/monsters/<id>.tres ให้ ไม่ต้องเปิด Inspector)

    python3 set_monster_flying.py hornet                         # บิน สูง 110 โยก ±8 1.4 รอบ/วิ (ค่าเริ่มต้น)
    python3 set_monster_flying.py hornet --height 130 --bob 10 --speed 1.2
    python3 set_monster_flying.py ember_bat chonchon             # หลายตัว
    python3 set_monster_flying.py hornet --off                   # เลิกบิน

ค่าเดียวกับช่องในกลุ่ม "บิน (ลอยเหนือพื้น)" ของ MonsterData — ตั้งใน Inspector ก็ได้ผลเหมือนกัน
★ ปิด Godot ก่อนรัน ★ · รันซ้ำได้
"""
import re, sys, os

args = sys.argv[1:]
if not args:
    print(__doc__); sys.exit(1)
height, bob, speed, off = 110.0, 8.0, 1.4, False
ids = []
i = 0
while i < len(args):
    a = args[i]
    if a == "--height": height = float(args[i + 1]); i += 2; continue
    if a == "--bob": bob = float(args[i + 1]); i += 2; continue
    if a == "--speed": speed = float(args[i + 1]); i += 2; continue
    if a == "--off": off = True; i += 1; continue
    ids.append(a.replace(".tres", "")); i += 1


def set_prop(text, key, value):
    line = "%s = %s" % (key, value)
    if re.search(r"^%s = .*$" % re.escape(key), text, re.M):
        return re.sub(r"^%s = .*$" % re.escape(key), line, text, count=1, flags=re.M)
    # แทรกหลัง align_feet/display_height/hp_bar_offset_y (กลุ่ม Visual) ถ้ามี ไม่งั้นต่อท้าย
    for anchor in ("align_feet", "display_height", "hp_bar_offset_y", "hitbox_size"):
        m = re.search(r"^%s = .*$" % anchor, text, re.M)
        if m:
            return text[:m.end()] + "\n" + line + text[m.end():]
    return text.rstrip("\n") + "\n" + line + "\n"


def num(v):
    s = ("%.3f" % v).rstrip("0").rstrip(".")
    return s if "." in s else s + ".0"


for mid in ids:
    path = "data/monsters/%s.tres" % mid
    if not os.path.exists(path):
        print("✗ ไม่พบ %s" % path); continue
    t = open(path, encoding="utf-8").read()
    new = t
    if off:
        new = re.sub(r"^flying = .*\n?", "", new, flags=re.M)      # ค่า default = false ไม่ต้องเขียน
    else:
        new = set_prop(new, "flying", "true")
        new = set_prop(new, "hover_height", num(height))
        new = set_prop(new, "hover_bob", num(bob))
        new = set_prop(new, "hover_bob_speed", num(speed))
    if new == t:
        print("   = %s ตรงอยู่แล้ว" % mid); continue
    open(path, "w", encoding="utf-8", newline="\n").write(new)
    print("   ✓ %s %s" % (mid, "เลิกบิน" if off else "บิน สูง %s โยก ±%s %s รอบ/วิ" % (num(height), num(bob), num(speed))))
