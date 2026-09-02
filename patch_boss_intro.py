# -*- coding: utf-8 -*-
## ★ รอบ 41 — ผูกวิดีโอเปิดตัวให้บอสคิงโพริง + บาฟโฟเมท ★ รันซ้ำได้ · ปิด Godot ก่อนรัน
import os, re, shutil
os.chdir(os.path.dirname(os.path.abspath(__file__)))

def patch(path, video):
    s = open(path, encoding="utf-8").read()
    if "intro_video" in s:
        print("ครบแล้ว", path); return
    for k in ["intro_video", "intro_range"]:
        s = re.sub(r"^%s = [^\n]*\n" % k, "", s, flags=re.M)
    if not s.endswith("\n"): s += "\n"
    s += 'intro_video = "%s"\nintro_range = 700.0\n' % video
    bak = path.replace(".tres", "_ก่อนใส่วิดีโอเปิดตัว.tres.bak")
    if not os.path.exists(bak): shutil.copy(path, bak)
    open(path, "w", encoding="utf-8").write(s)
    print("แก้", path)

patch("data/monsters/king_poring.tres", "res://Sprites/video/boss_intro_king_poring.ogv")
patch("data/monsters/baphomet.tres", "res://Sprites/video/boss_intro_baphomet.ogv")
for f in ["Sprites/video/boss_intro_king_poring.ogv", "Sprites/video/boss_intro_baphomet.ogv"]:
    print(("มี   " if os.path.exists(f) else "★ ไม่มี ★ "), f)
print("★ เปิด Godot ใหม่แล้วกด F5 ★")
