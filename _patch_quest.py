#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ใส่ระดับเลเวลให้ของสวมใส่ + ผูกเควสเข้ากับ NPC ในเมือง (รันซ้ำได้)"""
import io, os, re, sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."

# ไอเทม -> เลเวลที่ต้องใช้
LEVELS = {
    # อาวุธ
    "novice_sword": 1, "blade": 4, "falchion": 12,
    "claymore": 25, "flame_sword": 40,
    # ชุดเกราะ / ของสวมใส่
    "cotton_shirt": 1, "adventurer_suit": 8, "plate_armor": 30,
    "guard": 1, "buckler": 12,
    "cap": 1, "hood": 4, "helm": 20,
    "sandals": 1, "boots": 15,
    "clip": 1, "ring": 18, "glove": 10,
}


def read(p):
    return io.open(os.path.join(ROOT, p), encoding="utf-8").read()


def write(p, t):
    io.open(os.path.join(ROOT, p), "w", encoding="utf-8", newline="\n").write(t)


def set_levels():
    print("ระดับเลเวลของสวมใส่:")
    d = os.path.join(ROOT, "data/items")
    if not os.path.isdir(d):
        print("  ไม่เจอโฟลเดอร์ data/items")
        return
    for name in sorted(os.listdir(d)):
        if not name.endswith(".tres"):
            continue
        item_id = name[:-5]
        lv = LEVELS.get(item_id)
        if lv is None:
            continue
        p = "data/items/%s" % name
        s = read(p)
        if re.search(r"^required_level = ", s, re.M):
            s = re.sub(r"^required_level = .*$", "required_level = %d" % lv, s, flags=re.M)
        else:
            # แทรกไว้ก่อนบรรทัด type = (ตามลำดับใน ItemData)
            m = re.search(r"^type = ", s, re.M)
            if m:
                s = s[:m.start()] + "required_level = %d\n" % lv + s[m.start():]
            else:
                s = s.rstrip("\n") + "\nrequired_level = %d\n" % lv
        write(p, s)
        print("  %-18s Lv.%d" % (item_id, lv))


def bind_quests():
    """ผูกเควสเข้ากับ NPC ในแมพเมือง"""
    print("ผูกเควสกับ NPC:")
    p = "scenes/maps/prontera_town.tscn"
    if not os.path.exists(os.path.join(ROOT, p)):
        print("  ไม่เจอแมพเมือง")
        return
    s = read(p)

    # NPC ที่ชื่อ node ตรงกับนี้ -> เควสที่ให้
    binding = [("Blacksmith", "hans_poring"), ("Merchant", "tony_fabre")]

    for node_name, quest_id in binding:
        m = re.search(r'(\[node name="%s"[^\]]*\]\n)((?:(?!\[node)[^\n]*\n)*)' % node_name, s)
        if m is None:
            print("  ! ไม่เจอ node %s" % node_name)
            continue
        body = m.group(2)
        if "quest_ids" in body:
            print("  %s มีเควสอยู่แล้ว ข้าม" % node_name)
            continue
        line = 'quest_ids = Array[StringName]([&"%s"])\n' % quest_id
        s = s[:m.end(1)] + line + s[m.end(1):]
        print("  %s -> %s" % (node_name, quest_id))

    write(p, s)


if __name__ == "__main__":
    set_levels()
    bind_quests()
    print("เสร็จ")
