#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""รอบ 46 — ประกอบ "เฟรมแยก" เป็นชีท NPC ที่ปลายเท้าตรงกันทุกช่อง + สร้าง SpriteFrames (.tres) ให้พร้อมใช้

ทำไม: ให้ AI วาด "ทั้งกริด 3x2 ในรูปเดียว" ตัวละครจะเลื่อนไปมาระหว่างช่องเสมอ (แก้ได้ด้วย fix_npc_sheets.py แต่ไม่สวยเท่า)
       วิธีที่ตรงกว่า = วาดทีละเฟรมบนผืนผ้าใบเดียวกัน (เช่น frame_01.png … frame_08.png ขนาดเท่ากันทุกไฟล์)
       แล้วให้สคริปต์นี้จัดปลายเท้า/กึ่งกลางเท้าให้ตรงกัน ประกอบเป็นชีท และเขียน .tres ให้ลากใส่ AnimatedSprite2D ได้เลย

ใช้ยังไง (รันจากโฟลเดอร์โปรเจกต์):
    python3 make_npc_sheet.py guard_erik Sprites/npc/frame_*.png
    python3 make_npc_sheet.py guard_erik Sprites/npc/erik_frames/          (ทั้งโฟลเดอร์ เรียงตามชื่อ)
  ตัวเลือก:
    --cols 4        จำนวนคอลัมน์ (ค่าเริ่มต้น: 6 เฟรม→3 · 8 เฟรม→4 · อื่น ๆ ≈ รากที่สอง)
    --fps 6         ความเร็วท่า (เฟรม/วินาที)
    --anim Idle     ชื่อท่าใน SpriteFrames (npc.gd เล่น "Idle" ถ้ามี ไม่งั้น "default")
    --cell 513x770  บังคับขนาดช่อง (ให้เท่าชีทเก่า → scale ใน Godot ใช้ค่าเดิมได้) · ค่าเริ่มต้น = พอดีตัวละคร + ขอบ
    --pad 12        ขอบว่างรอบตัวละคร (px) เมื่อไม่บังคับ --cell

ผลลัพธ์:
    Sprites/npc/<ชื่อ>.png            ชีท (ปลายเท้าทุกช่องอยู่บรรทัดเดียวกัน · กึ่งกลางเท้าตรงกลางช่อง)
    data/sprites/npc_<ชื่อ>.tres      SpriteFrames — ใน Godot: เลือก AnimatedSprite2D ของ NPC → ช่อง Sprite Frames → โหลดไฟล์นี้
                                     (ถ้าเคยตั้ง scale ไว้กับชีทเก่าที่ช่องสูงต่างกัน ปรับ scale ใหม่ให้สูงเท่าเดิม)
"""
import os, sys, glob, math
from PIL import Image

ALPHA_THR = 8
FEET_BAND = 40


def parse_args(argv):
    opts = {"cols": 0, "fps": 6.0, "anim": "Idle", "cell": None, "pad": 12}
    pos = []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--cols":
            opts["cols"] = int(argv[i + 1]); i += 2
        elif a == "--fps":
            opts["fps"] = float(argv[i + 1]); i += 2
        elif a == "--anim":
            opts["anim"] = argv[i + 1]; i += 2
        elif a == "--cell":
            w, h = argv[i + 1].lower().split("x"); opts["cell"] = (int(w), int(h)); i += 2
        elif a == "--pad":
            opts["pad"] = int(argv[i + 1]); i += 2
        else:
            pos.append(a); i += 1
    return opts, pos


def collect(paths):
    files = []
    for p in paths:
        if os.path.isdir(p):
            files += sorted(glob.glob(os.path.join(p, "*.png")))
        elif any(ch in p for ch in "*?["):
            files += sorted(glob.glob(p))
        else:
            files.append(p)
    return [f for f in files if f.lower().endswith(".png")]


def measure(im):
    a = im.getchannel("A").point(lambda v: 255 if v > ALPHA_THR else 0)
    bb = a.getbbox()
    if bb is None:
        return None, None
    band = a.crop((0, max(0, bb[3] - FEET_BAND), im.width, bb[3])).getbbox()
    feet_cx = (band[0] + band[2]) / 2.0 if band else (bb[0] + bb[2]) / 2.0
    return bb, feet_cx


def main():
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    opts, pos = parse_args(sys.argv[1:])
    if len(pos) < 2:
        print(__doc__); sys.exit(1)
    name, files = pos[0], collect(pos[1:])
    if len(files) < 2:
        print("ต้องมีเฟรมอย่างน้อย 2 ไฟล์ (เจอ %d)" % len(files)); sys.exit(1)
    frames = []
    for f in files:
        im = Image.open(f).convert("RGBA")
        bb, fcx = measure(im)
        if bb is None:
            print("  ข้าม (รูปว่าง):", f); continue
        frames.append((f, im, bb, fcx))
        print("  %-40s %dx%d  ตัวละคร %dx%d  ปลายเท้า y=%d  กลางเท้า x=%.0f" % (
            os.path.basename(f), im.width, im.height, bb[2] - bb[0], bb[3] - bb[1], bb[3], fcx))
    n = len(frames)
    cols = opts["cols"] or {6: 3, 8: 4, 4: 2, 2: 2}.get(n, math.ceil(math.sqrt(n)))
    rows = math.ceil(n / cols)
    max_w = max(bb[2] - bb[0] for _, _, bb, _ in frames)
    max_h = max(bb[3] - bb[1] for _, _, bb, _ in frames)
    # ตัวละครกว้างจริงเมื่อจัดกลางเท้า = ระยะจากกลางเท้าไปซ้ายสุด/ขวาสุด (เผื่อผ้าคลุม/หอกที่ยื่น)
    left = max(fcx - bb[0] for _, _, bb, fcx in frames)
    right = max(bb[2] - fcx for _, _, bb, fcx in frames)
    pad = opts["pad"]
    if opts["cell"]:
        cw, ch = opts["cell"]
        if 2 * max(left, right) > cw or max_h > ch - pad:
            print("  ★ เตือน: ช่อง %dx%d เล็กกว่าตัวละคร (ต้องกว้าง ≥ %d สูง ≥ %d) — ส่วนที่ล้นจะถูกตัด ★" % (
                cw, ch, int(2 * max(left, right)) + 2, max_h + pad))
    else:
        cw = int(math.ceil(2 * max(left, right))) + 2 * pad
        ch = max_h + 2 * pad
    sheet = Image.new("RGBA", (cw * cols, ch * rows), (0, 0, 0, 0))
    base_y = ch - pad            # บรรทัดปลายเท้า (เท่ากันทุกช่อง)
    for i, (f, im, bb, fcx) in enumerate(frames):
        c, r = i % cols, i // cols
        dx = int(round(cw / 2.0 - fcx))
        dy = base_y - bb[3]
        cell = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        cell.paste(im, (dx, dy))
        sheet.paste(cell, (c * cw, r * ch))
    out_png = os.path.join("Sprites/npc", name + ".png")
    os.makedirs("Sprites/npc", exist_ok=True)
    sheet.save(out_png)
    # ---- SpriteFrames .tres ----
    res_path = "res://" + out_png.replace("\\", "/")
    subs, refs = [], []
    for i in range(n):
        c, r = i % cols, i // cols
        sid = "AtlasTexture_%d" % (i + 1)
        subs.append('[sub_resource type="AtlasTexture" id="%s"]\natlas = ExtResource("1_sheet")\nregion = Rect2(%d, %d, %d, %d)\n' % (
            sid, c * cw, r * ch, cw, ch))
        refs.append('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % sid)
    tres = ('[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n'
            '[ext_resource type="Texture2D" path="%s" id="1_sheet"]\n\n' % (n + 2, res_path)
            + "\n".join(subs) +
            '\n[resource]\nanimations = [{\n"frames": [%s],\n"loop": true,\n"name": &"%s",\n"speed": %s\n}]\n' % (
                ", ".join(refs), opts["anim"], repr(float(opts["fps"]))))
    os.makedirs("data/sprites", exist_ok=True)
    out_tres = os.path.join("data/sprites", "npc_%s.tres" % name)
    open(out_tres, "w", encoding="utf-8").write(tres)
    print("\nเขียน %s  (%d เฟรม · กริด %dx%d · ช่องละ %dx%d · ปลายเท้า y=%d ทุกช่อง)" % (out_png, n, cols, rows, cw, ch, base_y))
    print("เขียน %s  (ท่า \"%s\" %.0f fps)" % (out_tres, opts["anim"], opts["fps"]))
    print("ใน Godot: เลือก AnimatedSprite2D ของ NPC → Sprite Frames → โหลด %s → ตั้ง Animation = %s" % (out_tres, opts["anim"]))
    print("  scale แนะนำให้ตัวสูงบนจอ ~%d px: %.3f" % (250, 250.0 / max_h))


if __name__ == "__main__":
    main()
