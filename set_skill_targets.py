#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""รอบ 56 — ตั้ง "จำนวนเป้าหมายตามเลเวลสกิล" ให้ไฟล์สกิล (data/skills/<id>.tres)

    python3 set_skill_targets.py slash 1:3,5:4,8:5
        = เลเวล 1-4 โดน 3 ตัว · เลเวล 5-7 โดน 4 ตัว · เลเวล 8 ขึ้นไปโดน 5 ตัว

    python3 set_skill_targets.py slash --off        # กลับไปใช้ Max Targets ค่าเดียวทุกเลเวล

★ ปิด Godot ก่อนรัน ★ · รันซ้ำได้ · สำรองไว้ที่ _to_delete/originals_skills_r56/
"""
import os, re, sys, shutil

args = sys.argv[1:]
if not args:
    print(__doc__); sys.exit(1)
skill = args[0].replace(".tres", "")
off = "--off" in args
pairs = ""
for a in args[1:]:
    if not a.startswith("-"):
        pairs = a

path = "data/skills/%s.tres" % skill
if not os.path.exists(path):
    print("✗ ไม่พบ %s" % path); sys.exit(1)
text = open(path, encoding="utf-8").read()

if off:
    new = re.sub(r"^max_targets_by_level = .*\n?", "", text, flags=re.M)
    line = "(ลบออก)"
else:
    if not pairs:
        print("✗ ต้องบอกคู่ เลเวล:จำนวน เช่น 1:3,5:4,8:5"); sys.exit(1)
    items = []
    for part in pairs.split(","):
        lv, n = part.split(":")
        items.append("%d: %d" % (int(lv), int(n)))
    line = "max_targets_by_level = {\n%s\n}" % ",\n".join(items)
    if re.search(r"^max_targets_by_level = \{[^}]*\}", text, re.M | re.S):
        new = re.sub(r"^max_targets_by_level = \{[^}]*\}", line, text, count=1, flags=re.M | re.S)
    elif re.search(r"^max_targets = .*$", text, re.M):
        new = re.sub(r"^(max_targets = .*)$", r"\1\n" + line, text, count=1, flags=re.M)
    else:
        new = text.rstrip("\n") + "\n" + line + "\n"

if new == text:
    print("= %s ตรงอยู่แล้ว" % path); sys.exit(0)
os.makedirs("_to_delete/originals_skills_r56", exist_ok=True)
bak = "_to_delete/originals_skills_r56/%s.tres" % skill
if not os.path.exists(bak):
    shutil.copy2(path, bak)
open(path, "w", encoding="utf-8", newline="\n").write(new)
print("✓ %s → %s" % (path, line.replace("\n", " ")))
