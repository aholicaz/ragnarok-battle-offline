# -*- coding: utf-8 -*-
## ★ รอบ 37 — ใส่เอฟเฟกต์ระเบิดไฟให้สกิล Magnum Break ★
## รันซ้ำได้ · ปิด Godot ก่อนรัน (หรือปิดแท็บ magnum_break.tres โดยไม่บันทึก)
## ต้องมีไฟล์ Sprites/effects/magnum_break.png + data/sprites/fx_magnum.tres (จาก make_magnum_fx.py) ก่อน
import os, re, shutil
os.chdir(os.path.dirname(os.path.abspath(__file__)))

PATH = "data/skills/magnum_break.tres"
EXT = '[ext_resource type="SpriteFrames" path="res://data/sprites/fx_magnum.tres" id="2_fx"]'
FIELDS = {
    "effect_frames": 'ExtResource("2_fx")',
    "effect_anim": '&"burst"',
    # กลางตัว · +28 = เส้นพื้นของชีท (y=296/384) ตรงเท้าพอดีเมื่อสูง 340
    "effect_offset": "Vector2(0, 28)",
    "effect_height": "340.0",       # ชีท 768x384 → กว้าง 680 · วงไฟ ±270 · เปลวสูง 220 ตรงกับ Range X/Y
    "effect_scale": "1.0",
    "effect_speed": "0.0",
    "effect_follow": "false",       # ระเบิดอยู่กับที่ที่แทงดาบ
    "effect_life": "0.0",
    "effect_delay": "0.2",          # เฟรมแทงดาบของสไปรท์ (6fps: เฟรม 1 เริ่ม 0.167 วิ)
    "effect_z": "60",
    "effect_damage": "false",       # ดาเมจใช้กรอบรอบตัว Range X/Y ของสกิลตามเดิม (โดนสูงสุด Max Targets)
}

def main():
    s = open(PATH, encoding="utf-8").read(); orig = s
    if EXT not in s:
        m = list(re.finditer(r'^\[ext_resource [^\n]*\]\n', s, flags=re.M))[-1]
        s = s[:m.end()] + EXT + "\n" + s[m.end():]
    for k in FIELDS:
        s = re.sub(r"^%s = [^\n]*\n" % re.escape(k), "", s, flags=re.M)
    if not s.endswith("\n"): s += "\n"
    s += "\n".join("%s = %s" % (k, v) for k, v in FIELDS.items()) + "\n"
    # load_steps ต้องนับ ext_resource + sub_resource + 1
    n = len(re.findall(r"^\[(ext_resource|sub_resource) ", s, flags=re.M)) + 1
    s = re.sub(r'load_steps=\d+', 'load_steps=%d' % n, s, count=1)
    if "load_steps=" not in s:
        s = s.replace('[gd_resource type="Resource"', '[gd_resource type="Resource" load_steps=%d' % n, 1)
    if s != orig:
        bak = PATH.replace(".tres", "_ก่อนใส่เอฟเฟกต์.tres.bak")
        if not os.path.exists(bak): shutil.copy(PATH, bak)
        open(PATH, "w", encoding="utf-8").write(s)
        print("แก้", PATH)
    else:
        print("ครบแล้ว", PATH)
    for need in ["Sprites/effects/magnum_break.png", "data/sprites/fx_magnum.tres"]:
        print(("มี   " if os.path.exists(need) else "★ ไม่มี ★ ") + need)
    print("★ เปิด Godot ใหม่แล้วกด F5 ★")

if __name__ == "__main__":
    main()
