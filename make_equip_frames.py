#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""รอบ 53 — ภาพอาวุธ/ของสวมใส่ "วาดบนผืนเดียวกับตัวละคร" (แบบเดียวกับเอฟเฟกต์สกิล)

วาดดาบลงผืนผ้าใบขนาดเท่าภาพท่านั้น (Idle = 1112x834 เท่า Sprites/frame_01.png) พื้นโปร่ง
แล้วสั่ง:

    python3 make_equip_frames.py sword_idle Sprites/equip/sword_idle.png
        → data/sprites/equip_sword_idle.tres  (SpriteFrames · ท่า Idle 1 เฟรม)

    python3 make_equip_frames.py sword_idle Sprites/equip/sword_idle.png --items @Attack_Blade
        → สร้าง .tres แล้ว "ผูก" ให้ดาบทุกเล่มที่ใช้ท่าโจมตี Attack_Blade (equip_sprite_frames)
    python3 make_equip_frames.py sword_idle Sprites/equip/sword_idle.png --items novice_sword short_sword
        → ผูกเฉพาะไอเทมที่ระบุ

    ตัวเลือก:  --anim Idle   ชื่อท่า (ค่าเริ่มต้น Idle)      --fps 5
               วาดหลายเฟรมก็ได้: ใส่ไฟล์หลายไฟล์เรียงตามเฟรม (จำนวนไม่ต้องเท่าตัวละคร เฟรมเกินใช้ตัวสุดท้าย)
               รันซ้ำด้วยชื่อเดิม + --anim อื่น = เพิ่มท่าเข้าไฟล์ .tres เดิม (เช่น ทำท่า Run ทีหลัง)

★ กติกา ★  ท่าไหนไม่มีในไฟล์ = ซ่อนอัตโนมัติ (ท่าโจมตีวาดดาบติดตัวละครไว้แล้ว เลยไม่ต้องทำ)
           หันซ้าย ระบบกลับด้านให้เอง · ขนาด/ตำแหน่งตามตัวละครเป๊ะ เพราะผืนเท่ากัน
           รูปที่แก้แล้ว: แค่ทับไฟล์ png ชื่อเดิม ไม่ต้องรันสคริปต์ใหม่
"""
import os, re, sys, shutil

args = sys.argv[1:]
if len(args) < 2 or args[0].startswith("-"):
    print(__doc__); sys.exit(1)

name = args[0]
anim = "Idle"
fps = 5.0
images, items = [], []
mode = "img"
i = 1
while i < len(args):
    a = args[i]
    if a == "--anim":
        anim = args[i + 1]; i += 2; continue
    if a == "--fps":
        fps = float(args[i + 1]); i += 2; continue
    if a == "--items":
        mode = "items"; i += 1; continue
    (items if mode == "items" else images).append(a)
    i += 1

if not images:
    print("★ ต้องระบุไฟล์ภาพอย่างน้อย 1 ไฟล์"); sys.exit(1)
for p in images:
    if not os.path.exists(p):
        print("★ ไม่พบไฟล์ %s" % p); sys.exit(1)

# ---------- ตรวจขนาดผืนเทียบกับตัวละคร (เตือนเฉย ๆ) ----------
try:
    from PIL import Image
    ref = {"idle": "Sprites/frame_01.png", "run": "Sprites/run_01.png"}.get(anim.lower())
    if ref and os.path.exists(ref):
        rs = Image.open(ref).size
        for p in images:
            s = Image.open(p).size
            if s != rs:
                print("⚠ %s ขนาด %dx%d แต่ภาพท่า %s ของตัวละครคือ %dx%d — ภาพจะซ้อนไม่ตรง" % (p, s[0], s[1], anim, rs[0], rs[1]))
except ImportError:
    pass

os.makedirs("data/sprites", exist_ok=True)
tres = "data/sprites/equip_%s.tres" % name

# ---------- อ่านของเดิม (ถ้ามี) เพื่อเก็บท่าอื่นไว้ ----------
anims = {}           # ชื่อท่า -> {"paths": [...], "fps": f}
if os.path.exists(tres):
    old = open(tres, encoding="utf-8").read()
    ext = {m.group(2): m.group(1) for m in re.finditer(r'\[ext_resource type="Texture2D"[^\]]*path="res://([^"]+)" id="([^"]+)"\]', old)}
    for fr, nm, sp in re.findall(r'"frames": \[(.*?)\],\n"loop": \w+,\n"name": &"([^"]+)",\n"speed": ([\d.]+)', old, re.S):
        ids = re.findall(r'ExtResource\("([^"]+)"\)', fr)
        anims[nm] = {"paths": [ext[i] for i in ids if i in ext], "fps": float(sp)}
    shutil.copy2(tres, tres + ".bak")
anims[anim] = {"paths": [p.replace("\\", "/") for p in images], "fps": fps}

# ---------- เขียน SpriteFrames ----------
paths = []
for a in anims.values():
    for p in a["paths"]:
        if p not in paths:
            paths.append(p)
ids = {p: "tex_%d" % (k + 1) for k, p in enumerate(paths)}
out = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (len(paths) + 1), ""]
for p in paths:
    out.append('[ext_resource type="Texture2D" path="res://%s" id="%s"]' % (p, ids[p]))
out += ["", "[resource]", "animations = ["]
blocks = []
for nm in sorted(anims):
    a = anims[nm]
    frames = ",\n".join('{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % ids[p] for p in a["paths"])
    blocks.append('{\n"frames": [%s],\n"loop": true,\n"name": &"%s",\n"speed": %s\n}' % (frames, nm, ("%.1f" % a["fps"])))
out.append(", ".join(blocks) + "]")
open(tres, "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
print("✓ %s  (ท่า: %s)" % (tres, " · ".join("%s %d เฟรม" % (n, len(a["paths"])) for n, a in sorted(anims.items()))))

# ---------- ผูกกับไอเทม ----------
if not items:
    print("   (ยังไม่ได้ผูกกับไอเทม — ใส่ --items <id ...> หรือ --items @Attack_Blade)")
    sys.exit(0)

targets = []
for it in items:
    if it.startswith("@"):
        want = it[1:]
        for f in sorted(os.listdir("data/items")):
            if f.endswith(".tres") and re.search(r'^attack_animation = &"%s"' % re.escape(want),
                                                 open("data/items/" + f, encoding="utf-8").read(), re.M):
                targets.append("data/items/" + f)
    else:
        p = "data/items/%s.tres" % it.replace(".tres", "")
        if os.path.exists(p):
            targets.append(p)
        else:
            print("   ✗ ไม่พบไอเทม %s" % it)

BACKUP = "_to_delete/originals_items_equipframes"
for path in targets:
    text = open(path, encoding="utf-8").read()
    m = re.search(r'\[ext_resource type="SpriteFrames"[^\]]*path="res://%s" id="([^"]+)"\]' % re.escape(tres), text)
    if m:
        rid = m.group(1)
    else:
        rid = "equipframes"
        steps = len(re.findall(r"^\[(?:ext|sub)_resource ", text, re.M)) + 2
        if re.search(r"load_steps=\d+", text):
            text = re.sub(r"load_steps=\d+", "load_steps=%d" % steps, text, count=1)
        else:
            text = text.replace("[gd_resource ", "[gd_resource load_steps=%d " % steps, 1)
        line = '[ext_resource type="SpriteFrames" path="res://%s" id="%s"]\n' % (tres, rid)
        exts = list(re.finditer(r"^\[ext_resource [^\n]*\]\n", text, re.M))
        pos = exts[-1].end() if exts else text.index("\n") + 1
        text = text[:pos] + line + text[pos:]
    prop = 'equip_sprite_frames = ExtResource("%s")' % rid
    if re.search(r"^equip_sprite_frames = .*$", text, re.M):
        new = re.sub(r"^equip_sprite_frames = .*$", prop, text, count=1, flags=re.M)
    else:
        new = text + ("" if text.endswith("\n") else "\n") + prop + "\n"
    orig = open(path, encoding="utf-8").read()
    if new == orig:
        print("   = %-28s ผูกอยู่แล้ว" % path); continue
    os.makedirs(BACKUP, exist_ok=True)
    bak = os.path.join(BACKUP, os.path.basename(path))
    if not os.path.exists(bak):
        shutil.copy2(path, bak)
    open(path, "w", encoding="utf-8", newline="\n").write(new)
    print("   ✓ %-28s ผูกภาพแล้ว" % path)
