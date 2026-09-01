## เพิ่มเอฟเฟกต์ให้สกิล Bash (รอบ 29)
## รันครั้งเดียวพอ — รันซ้ำได้ ไม่พัง (เช็คก่อนว่าใส่ไปแล้วหรือยัง)
import os, shutil, sys

P = "data/skills/bash.tres"
if not os.path.exists(P):
    sys.exit("ไม่เจอไฟล์ %s (ต้องรันในโฟลเดอร์โปรเจกต์)" % P)

s = open(P, encoding="utf-8").read()
if "effect_frames" in s:
    print("bash.tres มีเอฟเฟกต์อยู่แล้ว — ไม่แก้ซ้ำ")
    sys.exit(0)

shutil.copy(P, "data/skills/bash_ก่อนใส่เอฟเฟกต์.tres.bak")

# 1) เพิ่ม ext_resource ของ SpriteFrames + บวก load_steps
s = s.replace('load_steps=2', 'load_steps=3', 1)
s = s.replace(
    '[ext_resource type="Script" path="res://scripts/resources/skill_data.gd" id="1_skill"]',
    '[ext_resource type="Script" path="res://scripts/resources/skill_data.gd" id="1_skill"]\n'
    '[ext_resource type="SpriteFrames" path="res://data/sprites/fx_bash.tres" id="2_fx"]',
    1)

# 2) ต่อท้ายบล็อก [resource]
s = s.rstrip() + """
effect_frames = ExtResource("2_fx")
effect_anim = &"slash"
effect_offset = Vector2(95, -5)
effect_height = 300.0
effect_scale = 1.0
effect_speed = 460.0
effect_follow = false
effect_life = 0.5
effect_delay = 0.12
effect_z = 60
effect_damage = true
effect_hit_size = Vector2(200, 260)
effect_max_targets = 1
effect_hit_once = true
effect_pierce = true
"""

open(P, "w", encoding="utf-8").write(s)
print("ใส่เอฟเฟกต์ให้ bash.tres แล้ว (สำรองเดิมไว้ที่ bash_ก่อนใส่เอฟเฟกต์.tres.bak)")
