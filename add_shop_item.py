#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""รอบ 60 — เพิ่มไอเทมเข้า "ของที่ NPC ขาย" (ช่อง Shop Items) โดยไม่ต้องเปิด Godot

    python3 add_shop_item.py                                  # ใส่ค่าเริ่มต้น: ปีกแห่งวาลคีรี → พ่อค้าโทนี่
    python3 add_shop_item.py --item wing_of_valkyrie --npc "พ่อค้าโทนี่"
    python3 add_shop_item.py --item red_potion --npc "นายหน้าเฮลกา" --before phracon

--before <id>  = แทรกไว้ก่อนไอเทมนี้ (ไม่ใส่ = ต่อท้ายรายการ)
มีอยู่แล้วจะไม่ใส่ซ้ำ · สำรองฉากเดิมไว้ที่ _to_delete/originals_maps_shop/
"""
import re, glob, os, sys, shutil

args = sys.argv[1:]


def opt(name, default=None):
    return args[args.index(name) + 1] if name in args else default


ITEM = opt("--item", "wing_of_valkyrie")
NPC = opt("--npc", "พ่อค้าโทนี่")
BEFORE = opt("--before", "phracon")
BAK = "_to_delete/originals_maps_shop"


def main():
    hit = False
    for f in sorted(glob.glob("scenes/maps/*.tscn")):
        s = open(f, encoding="utf-8").read()
        if 'npc_name = "%s"' % NPC not in s:
            continue
        i = s.index('npc_name = "%s"' % NPC)
        m = re.compile(r"shop_items = Array\[StringName\]\(\[(.*?)\]\)", re.S).search(s, i)
        if m is None:
            print("%s: เจอ %s แต่ NPC คนนี้ไม่มีช่อง Shop Items" % (os.path.basename(f), NPC))
            continue
        hit = True
        body = m.group(1)
        if '&"%s"' % ITEM in body:
            print("%s: %s ขาย %s อยู่แล้ว — ไม่ทำอะไร" % (os.path.basename(f), NPC, ITEM))
            continue
        entry = '&"%s"' % ITEM
        if BEFORE and '&"%s"' % BEFORE in body:
            new_body = body.replace('&"%s"' % BEFORE, entry + ', &"%s"' % BEFORE, 1)
        else:
            new_body = body.rstrip() + ", " + entry
        os.makedirs(BAK, exist_ok=True)
        bak = os.path.join(BAK, os.path.basename(f))
        if not os.path.exists(bak):
            shutil.copy2(f, bak)
        s = s[:m.start(1)] + new_body + s[m.end(1):]
        open(f, "w", encoding="utf-8").write(s)
        print("%s: เพิ่ม %s ให้ %s แล้ว (ตอนนี้ขาย %d ชิ้น)"
              % (os.path.basename(f), ITEM, NPC, new_body.count('&"')))
    if not hit:
        print("ไม่เจอ NPC ชื่อ '%s' ในฉากไหนเลย" % NPC)


if __name__ == "__main__":
    main()
