#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""รอบ 46 — ย่อไอคอนไอเทม/UI ที่ใหญ่เกินจำเป็น (ในเกมโชว์แค่ ~48 px แต่ไฟล์ 2,000+ px)

    python3 shrink_icons.py            # แค่ดูว่าจะย่อไฟล์ไหน (ไม่แตะไฟล์)
    python3 shrink_icons.py --apply    # ย่อจริง (ต้นฉบับสำรองไว้ที่ _to_delete/originals_icons/)

เกณฑ์เดียวกับแท็บ "งานภาพที่ยังไม่ทำ" ใน Codex: Sprites/ui_icons + Sprites/items ที่ใหญ่กว่า 600 KB → ย่อด้านยาวสุดเหลือ MAX_PX
ไม่แตะไฟล์ .import ของ Godot — เปิด Godot แล้วมันจะ re-import ให้เอง (ขนาดใน Inspector เปลี่ยน แต่ path เดิม ไม่ต้องชี้ใหม่)
"""
import os, sys, shutil
from PIL import Image

ROOT = os.path.abspath('.')
DIRS = ["Sprites/ui_icons", "Sprites/items"]
BAK = "_to_delete/originals_icons"
LIMIT = 600_000
MAX_PX = 256
apply = "--apply" in sys.argv

todo = []
for d in DIRS:
    for root, _dirs, files in os.walk(d):
        for f in files:
            if not f.lower().endswith(".png"):
                continue
            p = os.path.join(root, f)
            if os.path.getsize(p) > LIMIT:
                todo.append(p)
todo.sort()
if not todo:
    print("ไม่มีไฟล์เกิน %d KB" % (LIMIT // 1000))
    sys.exit(0)

total_before = total_after = 0
for p in todo:
    before = os.path.getsize(p)
    im = Image.open(p)
    w, h = im.size
    scale = MAX_PX / max(w, h)
    if scale >= 1:
        print("  ข้าม (เล็กอยู่แล้ว %dx%d แต่ไฟล์ใหญ่ — ลอง optimize):" % (w, h), p)
        nw, nh = w, h
    else:
        nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    if apply:
        bak = os.path.join(BAK, os.path.relpath(p, "Sprites"))
        os.makedirs(os.path.dirname(bak), exist_ok=True)
        if not os.path.exists(bak):
            shutil.copy(p, bak)
        out = im.convert("RGBA").resize((nw, nh), Image.LANCZOS) if (nw, nh) != (w, h) else im.convert("RGBA")
        out.save(p, optimize=True)
        after = os.path.getsize(p)
    else:
        after = before
    total_before += before
    total_after += after
    print("  %s  %dx%d → %dx%d  %.1f MB%s" % (
        "ย่อแล้ว" if apply else "จะย่อ", w, h, nw, nh, before / 1048576,
        (" → %.0f KB" % (after / 1024)) if apply else ""))
print("รวม %d ไฟล์ · %.1f MB%s" % (len(todo), total_before / 1048576,
      (" → %.1f MB" % (total_after / 1048576)) if apply else "  (ใส่ --apply เพื่อย่อจริง)"))
