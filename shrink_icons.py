#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ย่อไอคอนไอเทม/ปุ่มเมนูให้เป็น "ไซส์ที่ถูกต้อง" (รอบ 46 · ปรับเกณฑ์รอบ 60)

    python3 shrink_icons.py            # ดูรายการที่จะย่อเฉย ๆ (ไม่แตะไฟล์)
    python3 shrink_icons.py --apply    # ย่อจริง — ต้นฉบับสำรองไว้ที่ _to_delete/originals_icons/

★ เกณฑ์ (รอบ 60) ★  ด้านยาวสุดเกิน MAX_PX (256) → ย่อลงเหลือ 256
   หรือไฟล์ใหญ่เกิน LIMIT (600 KB) ทั้งที่ภาพเล็ก → บีบไฟล์ใหม่ (ขนาดภาพเท่าเดิม)

ทำไม 256: ในเกมไอคอนโชว์ใหญ่สุดแค่ 120x120 (หน้ารายละเอียดไอเทม) · การ์ด 210x300 · ปุ่มเมนู ~44
   256 = เผื่อจอความละเอียดสูงไว้เท่าตัวแล้ว ใหญ่กว่านี้เปลืองแรม/พื้นที่เปล่า ๆ
★ ไม่แตะโฟลเดอร์ portraits (รูปคุย NPC โชว์สูง 330 px ต้องคมกว่านี้) ★

ไม่ต้องแก้ .import — เปิด Godot แล้วมันนำเข้าใหม่ให้เอง (path เดิม ไม่ต้องชี้ใหม่)
"""
import os, sys, shutil
from PIL import Image

DIRS = ["Sprites/ui_icons", "Sprites/items"]
BAK = "_to_delete/originals_icons"
LIMIT = 600_000          # ไฟล์ใหญ่กว่านี้ = บีบใหม่แม้ภาพจะเล็กอยู่แล้ว
MAX_PX = 256             # ด้านยาวสุดหลังย่อ
apply = "--apply" in sys.argv

todo = []
for d in DIRS:
    for root, _dirs, files in os.walk(d):
        for f in sorted(files):
            if not f.lower().endswith(".png"):
                continue
            p = os.path.join(root, f)
            try:
                w, h = Image.open(p).size
            except Exception as e:
                print("  อ่านไม่ได้ ข้าม:", p, e)
                continue
            if max(w, h) > MAX_PX or os.path.getsize(p) > LIMIT:
                todo.append(p)

if not todo:
    print("ไอคอนทุกอันไซส์ถูกต้องแล้ว (ไม่เกิน %d px และไม่เกิน %d KB)" % (MAX_PX, LIMIT // 1000))
    sys.exit(0)

total_before = total_after = 0
for p in todo:
    before = os.path.getsize(p)
    im = Image.open(p)
    w, h = im.size
    scale = MAX_PX / max(w, h)
    if scale >= 1:
        nw, nh = w, h                      # ภาพเล็กอยู่แล้ว แค่บีบไฟล์ใหม่
    else:
        nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    if apply:
        bak = os.path.join(BAK, os.path.relpath(p, "Sprites"))
        os.makedirs(os.path.dirname(bak), exist_ok=True)
        if not os.path.exists(bak):
            shutil.copy2(p, bak)           # สำรองต้นฉบับครั้งแรกครั้งเดียว
        out = im.convert("RGBA")
        if (nw, nh) != (w, h):
            out = out.resize((nw, nh), Image.LANCZOS)
        out.save(p, optimize=True)
        after = os.path.getsize(p)
    else:
        after = before
    total_before += before
    total_after += after
    print("  %s  %-46s %4dx%-4d → %3dx%-3d  %6.0f KB%s" % (
        "ย่อแล้ว" if apply else "จะย่อ ", p, w, h, nw, nh, before / 1024,
        (" → %5.0f KB" % (after / 1024)) if apply else ""))

print("รวม %d ไฟล์ · %.1f MB%s" % (len(todo), total_before / 1048576,
      (" → %.1f MB  (ประหยัด %.1f MB)" % (total_after / 1048576, (total_before - total_after) / 1048576))
      if apply else "   ← ใส่ --apply เพื่อย่อจริง (สำรองต้นฉบับที่ %s)" % BAK))
