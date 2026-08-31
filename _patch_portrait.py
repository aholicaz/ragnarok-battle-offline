#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ใส่ "รูปตัวละครในกล่องสนทนา" ให้ NPC ในเมือง (แก้ในที่ · รันซ้ำได้ · สำรองไฟล์ให้ก่อน)

★ วิธีใส่รูปให้ NPC คนอื่นเอง ★
1. วาดรูปครึ่งท่อนบน (หัวถึงเอว) พื้นหลังโปร่งใส สูงประมาณ 400-500 px
2. เซฟไว้ที่ Sprites/portraits/<ชื่อ>.png
3. ใน Godot เลือก NPC คนนั้น -> ช่อง "Portrait" ลากรูปมาใส่
   (หรือช่อง "Portrait File" พิมพ์ path เช่น res://Sprites/portraits/tony.png)
4. ช่อง "Portrait Side" = ซ้าย/ขวา ว่าจะให้ยืนฝั่งไหนของจอ
"""
import io, os, re, sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
SCENE = "scenes/maps/prontera_town.tscn"
BACKUP = "scenes/maps/prontera_town_ก่อนใส่รูปคุย.tscn.bak"

# ชื่อโหนด NPC -> path ของรูป
PORTRAITS = {
    "Blacksmith": "res://Sprites/portraits/hans.png",
}


def main():
    path = os.path.join(ROOT, SCENE)
    if not os.path.exists(path):
        print("  ไม่เจอ %s" % SCENE)
        return
    s = io.open(path, encoding="utf-8").read()
    orig = s

    backup = os.path.join(ROOT, BACKUP)
    if not os.path.exists(backup):
        io.open(backup, "w", encoding="utf-8", newline="\n").write(s)
        print("  สำรองไว้ที่ %s" % os.path.basename(BACKUP))

    for node, art in PORTRAITS.items():
        # หาบล็อกของโหนดนั้น (ตั้งแต่บรรทัด [node name="X" ... จนถึง [ ถัดไป)
        m = re.search(r'^\[node name="%s"[^\]]*\]\n' % re.escape(node), s, re.M)
        if m is None:
            print("  ! ไม่เจอโหนด %s" % node)
            continue
        start = m.end()
        nxt = s.find("\n[", start)
        if nxt < 0:
            nxt = len(s)
        block = s[start:nxt]

        if "portrait_file" in block:
            block2 = re.sub(r'^portrait_file = .*$',
                            'portrait_file = "%s"' % art, block, flags=re.M)
        else:
            block2 = block.rstrip("\n") + '\nportrait_file = "%s"\n' % art
        s = s[:start] + block2 + s[nxt:]
        print("  %s -> %s" % (node, art))

    if s == orig:
        print("  ใส่ไว้อยู่แล้ว ข้าม")
        return
    io.open(path, "w", encoding="utf-8", newline="\n").write(s)


if __name__ == "__main__":
    print("รูปตัวละครในกล่องสนทนา:")
    main()
    print("เสร็จ")
