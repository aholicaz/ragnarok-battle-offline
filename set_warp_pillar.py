#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""รอบ 57 — เปลี่ยน "ศิลาเซฟ" (NPC ชนิด SAVE_POINT) ให้เป็น "เสาวาป"

    python3 set_warp_pillar.py                       # ทุกแมพ · ปลายทาง asgard_forest_2
    python3 set_warp_pillar.py --targets asgard_forest_2,dark_forest
    python3 set_warp_pillar.py --list                # ดูว่ามีเสาไหนบ้าง ไม่แก้จริง

ทำอะไร: หา node ที่ `type = 4` (SAVE_POINT) ในไฟล์ scenes/maps/*.tscn แล้วเติม
  warp_targets = Array[StringName]([...])   ← ปลายทางที่วาปไปได้
  npc_name / dialog                          ← เปลี่ยนข้อความให้เข้ากับเสาวาป (ถ้ายังเป็นค่าเดิม)

★ ปิด Godot ก่อนรัน ★ · รันซ้ำได้ · สำรองที่ _to_delete/originals_maps_r57/
"""
import os, re, sys, shutil

args = sys.argv[1:]
dry = "--list" in args
targets = ["asgard_forest_2"]
if "--targets" in args:
    targets = [t.strip() for t in args[args.index("--targets") + 1].split(",") if t.strip()]

MAPS_DIR = "scenes/maps"
BACKUP = "_to_delete/originals_maps_r57"
arr = "Array[StringName]([%s])" % ", ".join('&"%s"' % t for t in targets)

changed = 0
for f in sorted(os.listdir(MAPS_DIR)):
    if not f.endswith(".tscn"):
        continue
    path = os.path.join(MAPS_DIR, f)
    text = open(path, encoding="utf-8").read()
    out = text
    # หา block ของ node ที่มี type = 4
    for m in re.finditer(r'^\[node name="([^"]+)"[^\]]*\]\n((?:(?!\n\[node )[\s\S])*)', text, re.M):
        block = m.group(0)
        body = m.group(2)
        if not re.search(r'^type = 4\s*$', body, re.M):
            continue
        name = m.group(1)
        print("● %s / %s" % (f[:-5], name))
        new_block = block
        if re.search(r'^warp_targets = ', new_block, re.M):
            new_block = re.sub(r'^warp_targets = .*$', "warp_targets = " + arr, new_block, count=1, flags=re.M)
        else:
            new_block = new_block.rstrip("\n") + "\nwarp_targets = " + arr + "\n"
        # ข้อความ: เปลี่ยนเฉพาะที่ยังพูดถึง "บันทึก" อย่างเดียว
        new_block = re.sub(r'^dialog = "[^"]*บันทึกการเดินทาง"',
                           'dialog = "เสาวาปโบราณ · เลือกปลายทางแล้วก้าวเข้าไปได้เลย"',
                           new_block, count=1, flags=re.M)
        if re.search(r'^npc_name = "ศิลา', new_block, re.M):
            new_block = re.sub(r'^npc_name = "[^"]*"', 'npc_name = "เสาวาปแห่งธอร์"', new_block, count=1, flags=re.M)
        if new_block != block:
            out = out.replace(block, new_block, 1)
            changed += 1
            print("   ปลายทาง: %s" % ", ".join(targets))
    if out != text and not dry:
        os.makedirs(BACKUP, exist_ok=True)
        bak = os.path.join(BACKUP, f)
        if not os.path.exists(bak):
            shutil.copy2(path, bak)
        open(path, "w", encoding="utf-8", newline="\n").write(out)
print("%s %d เสา" % ("พบ" if dry else "แก้แล้ว", changed))
