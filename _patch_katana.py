#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ต่อสไปรท์ดาบซามู (Katana) เข้ากับตัวละคร + แก้บั๊กของดรอปออร์ค (รันซ้ำได้)

สิ่งที่ทำ:
  1) แก้ orc_warrior.tres  ดรอป blade -> novice_sword (ไอเทมชื่อ blade ไม่มีอยู่จริง)
  2) เพิ่มท่า Attack_Katana / Attack_Katana_bash ลง player_frames.tres
     โดย "อ่านจากไฟล์ภาพเอง" ว่าช่องไหนมีรูป (ช่องละ 512x512) แล้วเรียงซ้าย->ขวา บน->ล่าง
     วิธีเดียวกับที่ท่า Attack_falchion / Attack_Blade ทำไว้
  3) แก้ katana.tres ให้ชี้ไปที่ท่า Attack_Katana
"""
import io, os, re, sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
CELL = 512
FRAMES = "data/sprites/player_frames.tres"

# ชื่อท่า -> (ไฟล์ภาพ, uid ของภาพ, ความเร็ว)
ANIMS = [
    ("Attack_Katana", "res://Sprites/spritesheet Attack Katana.png",
     "uid://bvvkldu234yrl", 16.0),
    ("Attack_Katana_bash", "res://Sprites/spritesheet Attack Katana bash.png",
     "uid://67un784vcplx", 13.0),
]


def read(p):
    return io.open(os.path.join(ROOT, p), encoding="utf-8").read()


def write(p, t):
    io.open(os.path.join(ROOT, p), "w", encoding="utf-8", newline="\n").write(t)


# =========================================================
# 1) ของดรอปออร์คนักรบ
# =========================================================
def fix_orc_drop():
    p = "data/monsters/orc_warrior.tres"
    if not os.path.exists(os.path.join(ROOT, p)):
        print("  ไม่เจอ orc_warrior.tres")
        return
    s = read(p)
    if 'item_id = &"blade"' not in s:
        print("  ของดรอปออร์คถูกอยู่แล้ว ข้าม")
        return
    s = s.replace('item_id = &"blade"', 'item_id = &"novice_sword"')
    write(p, s)
    print("  ออร์คนักรบ: ดรอป blade -> novice_sword")


# =========================================================
# 2) หาช่องที่มีรูปในสไปรท์ชีท
# =========================================================
def filled_cells(image_path):
    """คืนรายการ (x, y) ของช่อง 512x512 ที่มีรูปอยู่จริง เรียงซ้าย->ขวา บน->ล่าง"""
    from PIL import Image
    full = os.path.join(ROOT, image_path.replace("res://", ""))
    if not os.path.exists(full):
        print("  ! ไม่เจอไฟล์ภาพ %s — ข้ามท่านี้" % image_path)
        return []
    im = Image.open(full).convert("RGBA")
    alpha = im.getchannel("A")
    w, h = im.size
    out = []
    for gy in range(h // CELL):
        for gx in range(w // CELL):
            crop = alpha.crop((gx * CELL, gy * CELL, gx * CELL + CELL, gy * CELL + CELL))
            # นับพิกเซลที่ทึบพอ (ตัดเศษขอบจาง ๆ ทิ้ง)
            solid = sum(crop.histogram()[25:])
            if solid > 500:
                out.append((gx * CELL, gy * CELL))
    return out


# =========================================================
# 3) ยัดท่าใหม่ลง player_frames.tres
# =========================================================
def add_anims():
    p = FRAMES
    if not os.path.exists(os.path.join(ROOT, p)):
        print("  ไม่เจอ %s" % p)
        return
    s = read(p)

    todo = [a for a in ANIMS if ('&"%s"' % a[0]) not in s]
    if not todo:
        print("  มีท่า Katana อยู่แล้วครบ ข้าม")
        return

    # ---- เลขต่อท้าย id ที่ยังไม่ถูกใช้ ----
    used_ext = set(re.findall(r'\[ext_resource[^\]]*id="([^"]+)"', s))
    used_sub = set(re.findall(r'\[sub_resource[^\]]*id="([^"]+)"', s))

    new_ext_lines = []
    new_sub_blocks = []
    new_anim_blocks = []

    for name, img, uid, speed in todo:
        cells = filled_cells(img)
        if not cells:
            print("  ! %s: ไม่เจอเฟรมในภาพ ข้าม" % name)
            continue

        ext_id = "kat_%s" % name.split("_")[-1].lower()
        n = 0
        while ext_id in used_ext:
            n += 1
            ext_id = "kat_%s%d" % (name.split("_")[-1].lower(), n)
        used_ext.add(ext_id)
        new_ext_lines.append(
            '[ext_resource type="Texture2D" uid="%s" path="%s" id="%s"]'
            % (uid, img, ext_id))

        frame_ids = []
        for i, (x, y) in enumerate(cells):
            sid = "AtlasTexture_%s_%02d" % (ext_id, i)
            used_sub.add(sid)
            frame_ids.append(sid)
            new_sub_blocks.append(
                '[sub_resource type="AtlasTexture" id="%s"]\n'
                'atlas = ExtResource("%s")\n'
                'region = Rect2(%d, %d, %d, %d)\n' % (sid, ext_id, x, y, CELL, CELL))

        frames_txt = ", ".join(
            '{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % f for f in frame_ids)
        new_anim_blocks.append(
            '{\n"frames": [%s],\n"loop": 1,\n"name": &"%s",\n"speed": %.1f\n}'
            % (frames_txt, name, speed))
        print("  %s: %d เฟรม (speed %.0f)" % (name, len(cells), speed))

    if not new_anim_blocks:
        return

    # ---- แทรก ext_resource ต่อท้ายบล็อก ext_resource เดิม ----
    last_ext = None
    for m in re.finditer(r'^\[ext_resource[^\]]*\]$', s, re.M):
        last_ext = m
    s = s[:last_ext.end()] + "\n" + "\n".join(new_ext_lines) + s[last_ext.end():]

    # ---- แทรก sub_resource ★ ก่อนหัวข้อ [resource] ★ ----
    # (sub_resource ต้องอยู่ก่อน [resource] เสมอ ไม่งั้น Godot อ่านไฟล์ไม่ผ่าน)
    m = re.search(r'^\[resource\]$', s, re.M)
    i = m.start() if m is not None else s.index("animations = [")
    s = s[:i] + "\n".join(new_sub_blocks) + "\n" + s[i:]

    # ---- แทรก animation ต่อท้ายอาร์เรย์ ----
    j = s.rindex("}]")
    s = s[:j + 1] + ", " + ", ".join(new_anim_blocks) + "]" + s[j + 2:]

    write(p, s)
    print("  บันทึก player_frames.tres แล้ว")


# =========================================================
# 4) ให้ดาบซามูใช้ท่าของตัวเอง
# =========================================================
def fix_katana_item():
    p = "data/items/katana.tres"
    if not os.path.exists(os.path.join(ROOT, p)):
        print("  ไม่เจอ katana.tres")
        return
    s = read(p)
    before = s

    if 'attack_animation = &"Attack_Katana"' in s:
        print("  katana.tres ชี้ท่าถูกอยู่แล้ว ข้าม")
    elif re.search(r'^attack_animation = .*$', s, re.M):
        s = re.sub(r'^attack_animation = .*$', 'attack_animation = &"Attack_Katana"',
                   s, flags=re.M)
        print("  ดาบซามู: attack_animation -> Attack_Katana")
    else:
        s = s.rstrip("\n") + '\nattack_animation = &"Attack_Katana"\n'
        print("  ดาบซามู: เพิ่ม attack_animation = Attack_Katana")

    # id ของไอเทมทุกชิ้นเป็นตัวพิมพ์เล็ก — ของชิ้นนี้เป็น &"Katana" อยู่
    # ถ้าปล่อยไว้ เวลาอ้างถึงด้วย &"katana" (ดรอป/ร้านค้า/เควส) จะหาไม่เจอ
    if re.search(r'^id = &"Katana"$', s, re.M):
        s = re.sub(r'^id = &"Katana"$', 'id = &"katana"', s, flags=re.M)
        print("  ดาบซามู: id &\"Katana\" -> &\"katana\" (ให้เข้าชุดกับไอเทมอื่น)")

    if s != before:
        write(p, s)


if __name__ == "__main__":
    print("แก้ของดรอปออร์ค:")
    fix_orc_drop()
    print("เพิ่มท่าดาบซามู:")
    add_anims()
    print("ผูกไอเทมดาบซามู:")
    fix_katana_item()
    print("เสร็จ")
