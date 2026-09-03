#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""รอบ 46 — จัดเฟรมในชีท NPC ให้ตรงกันทุกช่อง (แก้ idle เด้งไปเด้งมา)

สาเหตุ: ชีท 6 เฟรม (3x2 · 1540x1540 · ช่องละ 513x770) ที่วาดมา "ตัวละครไม่ได้อยู่ตำแหน่งเดียวกันในทุกช่อง"
  แถวล่างอยู่ต่ำกว่าแถวบน ~10 px · คอลัมน์ขวาสุดเยื้องขวา ~7-17 px  (ปลายเท้าเท่ากันภายในแถวจริง แต่ข้ามแถว/คอลัมน์ไม่เท่า)
  Godot ตัดช่องเป็นกริดเป๊ะ ๆ → เฟรม 4-6 เลื่อนลง/ขวา → เห็นเป็นตัวกระตุก

วิธีแก้: วัดกรอบพิกเซลจริงของแต่ละช่อง แล้ว "เลื่อนภาพในช่อง" ให้ปลายเท้าตรงกันทุกช่อง
  แนวตั้ง = ขอบล่างสุดของภาพ · แนวนอน = กึ่งกลางของ "แถบเท้า" (40 px ล่างสุด) — ไม่ใช่กึ่งกลางทั้งตัว
  (ผ้าคลุม/แขนที่กางออกทำให้กรอบทั้งตัวเบี้ยวได้ แต่เท้าที่ยืนอยู่กับที่ต้องไม่ขยับ)

ใช้ยังไง:  python3 fix_npc_sheets.py            (ทุกชีท 3x2 ใน Sprites/npc)
          python3 fix_npc_sheets.py ชื่อไฟล์.png  (เฉพาะไฟล์)
  - ต้นฉบับสำรองไว้ที่ _to_delete/originals_npc/  · รันซ้ำได้ ผลเหมือนเดิม (คำนวณจากต้นฉบับเสมอ)
  - ★ ถ้าคุณวางไฟล์ใหม่ทับชื่อเดิม สคริปต์รู้เอง (เทียบ hash กับผลลัพธ์ที่มันเขียนไว้ครั้งก่อน) แล้วสำรองต้นฉบับใหม่ให้ ★
  - ชีทที่ไม่ใช่ 3x2 (รูปเดี่ยว / เฟรมแยก frame_01.png ฯลฯ) จะข้าม — เฟรมแยกใช้ make_npc_sheet.py แทน
"""
import os, sys, glob, shutil, hashlib
from PIL import Image

os.chdir(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = "Sprites/npc"
BAK_DIR = "_to_delete/originals_npc"
COLS, ROWS = 3, 2
ALPHA_THR = 8      # พิกเซลจาง ๆ กว่านี้ไม่นับเป็นขอบ
FEET_BAND = 40     # ความสูงแถบเท้า (px ในภาพต้นฉบับ) ที่ใช้หากึ่งกลางแนวนอน


def md5(path):
    h = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def cell_bbox(im, c, r, cw, ch):
    """คืน (ภาพช่อง, กรอบทั้งตัว (l,t,r,b), กึ่งกลางแนวนอนของแถบเท้า)"""
    cell = im.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))
    a = cell.getchannel("A").point(lambda v: 255 if v > ALPHA_THR else 0)
    bb = a.getbbox()
    if bb is None:
        return cell, None, None
    band = a.crop((0, max(0, bb[3] - FEET_BAND), cw, bb[3])).getbbox()
    feet_cx = (band[0] + band[2]) / 2.0 if band else (bb[0] + bb[2]) / 2.0
    return cell, bb, feet_cx


def is_sheet(path):
    im = Image.open(path)
    W, H = im.size
    if W < 600 or H < 600 or abs(W - H) > W * 0.3:
        return False          # รูปเดี่ยว/รูปคุย/เฟรมแยก ไม่ใช่ชีท 3x2
    return True


def fix_sheet(path):
    if not is_sheet(path):
        return None
    bak = os.path.join(BAK_DIR, os.path.basename(path))
    stamp = bak + ".fixed.md5"          # md5 ของไฟล์ที่สคริปต์เขียนออกไปครั้งก่อน
    cur = md5(path)
    if os.path.exists(bak):
        last = open(stamp).read().strip() if os.path.exists(stamp) else ""
        if cur != last and cur != md5(bak):
            # ไฟล์ปัจจุบันไม่ใช่ผลลัพธ์ของเรา และไม่ใช่ต้นฉบับเดิม = ผู้ใช้วางรูปใหม่ → สำรองใหม่
            shutil.copy(path, bak)
            print("  (พบรูปใหม่ → สำรองต้นฉบับใหม่)", os.path.basename(path))
    else:
        os.makedirs(BAK_DIR, exist_ok=True)
        shutil.copy(path, bak)
    im = Image.open(bak).convert("RGBA")      # ★ คำนวณจากต้นฉบับเสมอ ★
    W, H = im.size
    cw, ch = W // COLS, H // ROWS   # 1540/3 = 513 (เศษ 1 px ทิ้ง — Godot ก็ตัดแบบนี้)
    cells, boxes, centers = [], [], []
    for r in range(ROWS):
        for c in range(COLS):
            cell, bb, fcx = cell_bbox(im, c, r, cw, ch)
            if bb is None:
                return None          # มีช่องว่าง = ไม่ใช่ชีท 6 เฟรม
            cells.append((c, r, cell))
            boxes.append(bb)
            centers.append(fcx)
    bottoms = [b[3] for b in boxes]
    # เป้าหมาย: ขอบล่าง = ค่าสูงสุด (เลื่อนลงอย่างเดียว ไม่มีทางตัดหัว) · กึ่งกลาง = ค่ากลาง
    target_bottom = max(bottoms)
    cs = sorted(centers)
    target_cx = cs[len(cs) // 2]
    shifts = []
    for (c, r, cell), bb, fcx in zip(cells, boxes, centers):
        dy = target_bottom - bb[3]
        dx = int(round(target_cx - fcx))
        # กันภาพหลุดขอบช่อง
        dx = max(-bb[0], min(dx, cw - 1 - bb[2]))
        shifts.append((dx, dy))
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    for (c, r, cell), (dx, dy) in zip(cells, shifts):
        moved = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        moved.paste(cell, (dx, dy))
        out.paste(moved, (c * cw, r * ch))
    out.save(path)
    open(stamp, "w").write(md5(path))
    changed = any(dx or dy for dx, dy in shifts)
    return (im.size, shifts, changed)


def main():
    if len(sys.argv) > 1:
        files = [p if os.path.exists(p) else os.path.join(SRC_DIR, p) for p in sys.argv[1:]]
    else:
        files = sorted(glob.glob(os.path.join(SRC_DIR, "*.png")))
    for p in files:
        res = fix_sheet(p)
        if res is None:
            print("  ข้าม (ไม่ใช่ชีท 3x2):", os.path.basename(p))
            continue
        size, shifts, changed = res
        tag = "แก้แล้ว" if changed else "ตรงอยู่แล้ว"
        print("  %s %s %s  เลื่อน(dx,dy)=%s" % (tag, os.path.basename(p), size, shifts))


if __name__ == "__main__":
    main()
