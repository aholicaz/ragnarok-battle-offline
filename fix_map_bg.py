#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""★ ปรับฉากหลังแมพให้เห็นทั้งภาพ + พื้นในภาพตรงกับพื้นที่ยืนจริง (รอบ 68) ★

    python3 fix_map_bg.py            # ตรวจทุกแมพ + ดูค่าที่จะตั้ง (ยังไม่เขียน)
    python3 fix_map_bg.py --apply    # เขียนจริง

★ ปัญหาที่แก้ ★
ฉากหลังของแมพวาดด้วย Polygon2D ซึ่งมี 2 ค่า:
    polygon = รูปสี่เหลี่ยมในโลก (พิกเซลของแมพ)
    uv      = ส่วนของ "ภาพ" ที่จะเอามาแปะ (พิกเซลของไฟล์ภาพ)

ถ้า uv เล็กกว่าขนาดไฟล์จริง = **ภาพโดนตัด** เห็นแค่มุมซ้ายบน
เกิดตอนเปลี่ยนไฟล์ภาพเป็นรูปใหม่ที่ใหญ่กว่าเดิม แต่ uv ยังเป็นเลขเก่า

thunder_scar: ไฟล์จริง 1905x825 แต่ uv = 1500x650
    → หายไป ขวา 405 px (หอคอย+โซ่) · ล่าง 175 px (หน้าตัดใต้ดิน)

★★ กับดักตัวจริงที่ทำให้ฉากหลังหายไปทั้งแมพ ★★
Godot ต้องการให้ polygon กับ uv มี "จำนวนจุดเท่ากัน"
ถ้าไม่เท่ากัน มัน **ทิ้ง uv ทั้งชุด** แล้วแปะภาพแบบ 1 พิกเซลภาพ = 1 พิกเซลโลกแทน
→ ภาพเล็กนิดเดียวอยู่มุมซ้ายบน ที่เหลือดำสนิท
เกิดตอนลากแก้รูปทรงใน Godot แล้วมันเพิ่มจุดให้ polygon โดยที่ uv ยังมี 4 จุดเท่าเดิม
สคริปต์นี้เขียนทั้ง polygon และ uv ใหม่เป็นสี่เหลี่ยม 4 จุดตรงกันเสมอ

★ วิธีแก้ ★ ตั้ง uv = ขนาดไฟล์เต็ม แล้วขยับ/ย่อขยายกรอบให้
    1) ย่อขยายเท่ากันทั้งแนวตั้งแนวนอน (ภาพไม่ยืด)
    2) "เส้นพื้นในภาพ" ตรงกับพื้นที่ตัวละครยืนจริงพอดี
    3) map_bounds เท่ากับกรอบภาพ กล้องเลยไม่แพนไปเจอที่ว่างดำ ๆ

สำรองไฟล์เดิมไว้ที่ _to_delete/originals_maps_r68/
"""
import os, re, shutil, sys

try:
    from PIL import Image
except ImportError:
    sys.exit("ต้องมี Pillow ก่อน:  pip install pillow")

BAK = "_to_delete/originals_maps_r68"
apply = "--apply" in sys.argv

# =========================================================
# ★ แมพที่จะจัดใหม่ ★ เพิ่มแมพอื่นได้ถ้าเปลี่ยนภาพฉากหลัง
# =========================================================
MAPS = {
    "thunder_scar": {
        "node": "Sky",           # ชื่อโหนด Polygon2D ที่แปะภาพ
        # ★ แถวในไฟล์ภาพที่เป็น "ผิวพื้นที่ตัวละครยืน" ★
        # (thunder_scar: พื้นหินเริ่มที่ y=580 · ต่ำกว่านั้นเป็นหน้าตัดใต้ดิน)
        "ground_row": 580,
        # พื้นชนจริงในแมพ — เว้นว่างไว้ = อ่านจากกล่องชน Ground ในฉากเอง
        # (จะได้ตามที่ปรับพื้นไว้ล่าสุดเสมอ ไม่ต้องมาแก้เลขตรงนี้)
        "ground_world_y": None,
        # ★ ให้พื้นชนกว้างเท่าแมพ ★ (กันเดินตกตรงขอบเพราะกล่องชนถูกลากเลื่อน)
        "fix_ground_span": True,
        # ความกว้าง/ขอบซ้ายของแมพ (คงเดิม)
        "left": -100,
        "width": 3000,
    },
}


def rect_array(x, y, w, h):
    return "PackedVector2Array(%g, %g, %g, %g, %g, %g, %g, %g)" % (
        x, y, x + w, y, x + w, y + h, x, y + h)


def scan(path, textures):
    """คืน list ของ (ชื่อโหนด, ไฟล์ภาพ, ขนาด polygon, ขนาด uv, ขนาดไฟล์จริง)"""
    s = open(path, encoding="utf-8").read()
    out = []
    for m in re.finditer(r'\[node name="([^"]+)" type="Polygon2D"[^\]]*\]\n((?:(?!\[node)[^\n]*\n)*)', s):
        name, blk = m.group(1), m.group(2)
        tm = re.search(r'texture = ExtResource\("([^"]+)"\)', blk)
        if not tm:
            continue
        img = textures.get(tm.group(1))
        if img is None:
            continue

        def wh(key):
            g = re.search(r'%s = PackedVector2Array\(([^)]*)\)' % key, blk)
            if not g:
                return None
            v = [float(x) for x in g.group(1).split(",")]
            return (max(v[0::2]) - min(v[0::2]), max(v[1::2]) - min(v[1::2]))

        try:
            size = Image.open(img).size
        except Exception:
            size = None
        out.append((name, img, wh("polygon"), wh("uv"), size))
    return out


def textures_of(path):
    s = open(path, encoding="utf-8").read()
    return {m.group(2): m.group(1) for m in re.finditer(
        r'\[ext_resource type="Texture2D"[^\]]*path="res://([^"]+)"[^\]]*id="([^"]+)"\]', s)}


def ground_top(path):
    """ขอบบนของกล่องชน Terrain/Ground (พื้นที่ตัวละครยืน)"""
    s = open(path, encoding="utf-8").read()
    m = re.search(r'\[node name="Ground" type="StaticBody2D"[^\]]*\]\n((?:(?!\[node)[^\n]*\n)*)', s)
    if m is None:
        return None, None
    body_y = 0.0
    g = re.search(r'^position = Vector2\([^,]*,\s*([-\d.]+)\)$', m.group(1), re.M)
    if g:
        body_y = float(g.group(1))
    m2 = re.search(r'\[node name="Shape" type="CollisionShape2D" parent="Terrain/Ground"[^\]]*\]\n((?:(?!\[node)[^\n]*\n)*)', s)
    if m2 is None:
        return None, None
    shape_y = 0.0
    g2 = re.search(r'^position = Vector2\([^,]*,\s*([-\d.]+)\)$', m2.group(1), re.M)
    if g2:
        shape_y = float(g2.group(1))
    sid = re.search(r'shape = SubResource\("([^"]+)"\)', m2.group(1))
    h = 240.0
    if sid:
        g3 = re.search(r'\[sub_resource type="RectangleShape2D" id="%s"\]\nsize = Vector2\([^,]*,\s*([-\d.]+)\)' % re.escape(sid.group(1)), s)
        if g3:
            h = float(g3.group(1))
    return body_y + shape_y - h * 0.5, h


def report():
    print("★ ตรวจฉากหลังทุกแมพ — uv ต้องเท่ากับขนาดไฟล์ภาพ ★")
    bad = []
    for f in sorted(os.listdir("scenes/maps")):
        if not f.endswith(".tscn") or ".bak" in f:
            continue
        p = os.path.join("scenes/maps", f)
        for name, img, pol, uv, size in scan(p, textures_of(p)):
            tag = "ok"
            if size is None:
                tag = "(ไม่พบไฟล์ภาพ)"
            elif uv and (uv[0] < size[0] - 1 or uv[1] < size[1] - 1):
                tag = "★ ภาพโดนตัด! หายไป %d x %d px ★" % (
                    max(0, size[0] - uv[0]), max(0, size[1] - uv[1]))
                bad.append(f[:-5])
            elif uv and (uv[0] > size[0] + 1 or uv[1] > size[1] + 1):
                tag = "(uv ใหญ่กว่าภาพ = ปูซ้ำ ตั้งใจไว้)"
            print("  %-22s %-12s ภาพ %-12s uv %-14s %s" % (
                f[:-5], name, "%dx%d" % size if size else "?",
                "%gx%g" % uv if uv else "?", tag))
    return bad


def fix(map_id, cfg):
    path = "scenes/maps/%s.tscn" % map_id
    if not os.path.exists(path):
        print("  (ไม่พบ %s)" % path)
        return
    s = open(path, encoding="utf-8").read()
    tex = textures_of(path)

    # หาบล็อกของโหนดที่ต้องแก้
    pat = r'(\[node name="%s" type="Polygon2D"[^\]]*\]\n)((?:(?!\[node)[^\n]*\n)*)' % re.escape(cfg["node"])
    m = re.search(pat, s)
    if m is None:
        print("  (ไม่เจอโหนด %s ใน %s)" % (cfg["node"], map_id))
        return
    head, blk = m.group(1), m.group(2)
    tm = re.search(r'texture = ExtResource\("([^"]+)"\)', blk)
    img = tex.get(tm.group(1)) if tm else None
    if img is None or not os.path.exists(img):
        print("  (ไม่พบไฟล์ภาพของ %s)" % map_id)
        return
    iw, ih = Image.open(img).size

    gy, gh = ground_top(path)
    want_gy = cfg.get("ground_world_y")
    if want_gy is None:
        if gy is None:
            print("  (อ่านพื้นชนของ %s ไม่ได้ — ข้าม)" % map_id)
            return
        want_gy = gy
        print("\n  (อ่านพื้นชนจากฉาก: ขอบบนอยู่ที่ y = %.0f · หนา %.0f)" % (gy, gh))

    # ---------- คำนวณ ----------
    k = cfg["width"] / float(iw)              # ย่อขยายเท่ากันทั้งสองแกน
    h = int(round(ih * k))
    top = want_gy - cfg["ground_row"] * k
    top = int(round(top))

    print("\n★ %s ★  ภาพ %dx%d  (%s)" % (map_id, iw, ih, img))
    print("    ย่อขยาย x%.4f  → กรอบ %d x %d" % (k, cfg["width"], h))
    print("    เส้นพื้นในภาพ y=%d → ในแมพ y=%.0f (พื้นชนจริงอยู่ที่ %d)"
          % (cfg["ground_row"], top + cfg["ground_row"] * k, want_gy))
    print("    กรอบภาพในแมพ: x %d..%d · y %d..%d"
          % (cfg["left"], cfg["left"] + cfg["width"], top, top + h))

    new_blk = blk
    sm = re.search(r'^scale = Vector2\(([^)]*)\)$', new_blk, re.M)
    if sm:
        print("    ★ โหนดถูกย่อ/ขยายไว้ (scale %s) → ล้างเป็น 1 เพื่อให้ตัวเลขตรงกับที่เห็นจริง ★" % sm.group(1))
        new_blk = new_blk[:sm.start()] + new_blk[sm.end() + 1:]
    new_blk = re.sub(r'^position = Vector2\([^)]*\)$',
                     "position = Vector2(%d, %d)" % (cfg["left"], top), new_blk, count=1, flags=re.M)
    if "position = " not in new_blk:
        new_blk = "position = Vector2(%d, %d)\n" % (cfg["left"], top) + new_blk
    new_blk = re.sub(r'^polygon = PackedVector2Array\([^)]*\)$',
                     "polygon = " + rect_array(0, 0, cfg["width"], h), new_blk, count=1, flags=re.M)
    new_blk = re.sub(r'^uv = PackedVector2Array\([^)]*\)$',
                     "uv = " + rect_array(0, 0, iw, ih), new_blk, count=1, flags=re.M)

    out = s[:m.start()] + head + new_blk + s[m.end():]

    # ---------- map_bounds ให้เท่ากรอบภาพ ----------
    bm = re.search(r'^map_bounds = Rect2\(([^)]*)\)$', out, re.M)
    if bm:
        old = bm.group(1)
        new = "%d, %d, %d, %d" % (cfg["left"], top, cfg["width"], h)
        if old.replace(" ", "") != new.replace(" ", ""):
            print("    map_bounds: Rect2(%s) → Rect2(%s)" % (old, new))
            out = out[:bm.start()] + "map_bounds = Rect2(%s)" % new + out[bm.end():]

    # ---------- พื้นชนต้องกว้างคลุมทั้งแมพ ----------
    if cfg.get("fix_ground_span"):
        gm = re.search(r'(\[node name="Shape" type="CollisionShape2D" parent="Terrain/Ground"[^\]]*\]\n)((?:(?!\[node)[^\n]*\n)*)', out)
        if gm:
            gblk = gm.group(2)
            pm = re.search(r'^position = Vector2\(([-\d.]+),\s*([-\d.]+)\)$', gblk, re.M)
            if pm and abs(float(pm.group(1))) > 0.5:
                print("    ★ กล่องชนพื้นถูกเลื่อนไปทางข้าง %s px → ดันกลับเป็น 0 (กันเดินตกตรงขอบ) ★" % pm.group(1))
                gblk = gblk[:pm.start()] + "position = Vector2(0, %s)" % pm.group(2) + gblk[pm.end():]
                out = out[:gm.start()] + gm.group(1) + gblk + out[gm.end():]

    if out == s:
        print("    (ตั้งไว้ถูกแล้ว)")
        return
    if not apply:
        return
    os.makedirs(BAK, exist_ok=True)
    b = os.path.join(BAK, os.path.basename(path))
    if not os.path.exists(b):
        shutil.copy2(path, b)
    open(path, "w", encoding="utf-8").write(out)
    print("    เขียนแล้ว (สำรองที่ %s)" % b)


def main():
    if not os.path.isdir("scenes/maps"):
        sys.exit("ต้องรันในโฟลเดอร์โปรเจกต์ (ไม่เจอ scenes/maps)")
    bad = report()
    for map_id, cfg in MAPS.items():
        fix(map_id, cfg)
    extra = [b for b in bad if b not in MAPS]
    if extra:
        print("\n★ แมพที่ภาพโดนตัดแต่ยังไม่ได้ตั้งค่าไว้ในสคริปต์: %s" % ", ".join(extra))
        print("  เพิ่มเข้า MAPS ข้างบน (บอก ground_row = แถวในภาพที่เป็นผิวพื้น) แล้วรันใหม่")
    if not apply:
        print("\n(ใส่ --apply เพื่อเขียนจริง)")


if __name__ == "__main__":
    main()
