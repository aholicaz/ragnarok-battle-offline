# -*- coding: utf-8 -*-
## ★ รอบ 42 — บาฟโฟเมทเป็นบอสจริง ๆ แต่ลืมติ๊ก is_boss ★ (ไม่มีป้าย MVP · ไม่ตั้งธง killed_baphomet)
## รันซ้ำได้ · ปิด Godot ก่อนรัน
import os, shutil
os.chdir(os.path.dirname(os.path.abspath(__file__)))
p = "data/monsters/baphomet.tres"
s = open(p, encoding="utf-8").read()
if "is_boss = true" in s:
    print("ครบแล้ว", p)
else:
    bak = p.replace(".tres", "_ก่อนตั้งบอส.tres.bak")
    if not os.path.exists(bak): shutil.copy(p, bak)
    if not s.endswith("\n"): s += "\n"
    s += 'is_boss = true\nboss_title = "ราชาปีศาจบาฟโฟเมท"\n'
    open(p, "w", encoding="utf-8").write(s)
    print("แก้", p, "— ตั้ง is_boss + boss_title แล้ว")
print("★ เปิด Godot ใหม่แล้วกด F5 ★")
