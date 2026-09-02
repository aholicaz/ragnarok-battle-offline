# -*- coding: utf-8 -*-
## ★ รอบ 36 — ลูนาติกยิงบอล · คิงโพริงขว้างบอลเหมือกระเบิด ★
## รันซ้ำได้ · ปิด Godot ก่อนรัน
import os, re, shutil
os.chdir(os.path.dirname(os.path.abspath(__file__)))

def patch(path, ext_line, fields, set_fields):
    s = open(path, encoding="utf-8").read(); orig = s
    # 1) ext_resource ของรูป
    ext_id = re.search(r'id="([^"]+)"', ext_line).group(1)
    if ext_line not in s:
        m = list(re.finditer(r'^\[ext_resource [^\n]*\]\n', s, flags=re.M))[-1]
        s = s[:m.end()] + ext_line + "\n" + s[m.end():]
    # 2) ช่องต่าง ๆ (ลบของเก่าแล้วต่อท้าย [resource])
    for k in list(fields.keys()) + list(set_fields.keys()):
        s = re.sub(r"^%s = [^\n]*\n" % re.escape(k), "", s, flags=re.M)
    block = "\n".join("%s = %s" % (k, v) for k, v in {**set_fields, **fields}.items())
    if not s.endswith("\n"): s += "\n"
    s += block + "\n"
    if s != orig:
        bak = path.replace(".tres", "_ก่อนใส่กระสุน.tres.bak")
        if not os.path.exists(bak): shutil.copy(path, bak)
        open(path, "w", encoding="utf-8").write(s)
        print("แก้", path)
    else:
        print("ครบแล้ว", path)

# ---------- ลูนาติก: ยิงบอลตาแดง ----------
patch("data/monsters/lunatic.tres",
      '[ext_resource type="Texture2D" path="res://Sprites/effects/lunatic_ball.png" id="fx_ball"]',
      {
          "projectile_texture": 'ExtResource("fx_ball")',
          "projectile_speed": "540.0",
          "projectile_height": "130.0",
          "projectile_offset": "Vector2(40, -100)",
          "projectile_hit_size": "Vector2(70, 70)",
          "projectile_faces_left": "true",
          "projectile_spin": "0.0",
          "projectile_range": "760.0",
      },
      {   # ปรับให้ยิงจากไกล: หยุดแล้วยิงตั้งแต่ระยะ 300 · เห็นผู้เล่นไกลขึ้น · ยิงถี่พอประมาณ
          "attack_range": "300.0",
          "detect_range": "420.0",
          "attack_windup": "0.35",
          "attack_duration": "0.45",
          "attack_cooldown": "1.6",
      })

# ---------- คิงโพริง: ขว้างบอลเหมือกโค้งตกพื้นระเบิด ----------
patch("data/monsters/king_poring.tres",
      '[ext_resource type="Texture2D" path="res://Sprites/effects/king_poring_ball.png" id="fx_slime"]',
      {
          "skill_projectile_texture": 'ExtResource("fx_slime")',
          "skill_projectile_height": "110.0",
          "skill_projectile_offset": "Vector2(90, -230)",
          "skill_projectile_arc": "260.0",
          "skill_projectile_time": "0.95",
          "skill_projectile_spin": "0.8",
          "skill_explosion_height": "280.0",
      },
      {   # ระเบิดที่จุดตก: รัศมีแคบลงหน่อยเพราะเล็งตำแหน่งผู้เล่นตรง ๆ แล้ว (มีเวลาหลบ ~1 วิ)
          "skill_range": "520.0",
          "skill_radius_x": "210.0",
          "skill_radius_y": "160.0",
          "skill_windup": "0.55",
          "skill_duration": "1.0",
      })
print("★ เปิด Godot ใหม่แล้วกด F5 ★")
