#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""รอบ 60 — ย้าย "ภาพการ์ด" ที่ยังชื่อ ChatGPT Image ... ไปไว้ใน Sprites/items แล้วตั้งชื่อให้ตรงการ์ด

    python3 fix_card_art.py            # ดูว่าจะย้ายอะไร
    python3 fix_card_art.py --apply    # ย้ายจริง + แก้ path ใน .tres ให้เอง

ทำไม: ภาพการ์ดโพริงวางหลุดอยู่ที่ Sprites/ (นอกโฟลเดอร์ items) → shrink_icons.py มองไม่เห็น
      เลยเป็นไฟล์ 1122x1402 (2.3 MB) ค้างอยู่ไฟล์เดียว
ไฟล์เดิมย้ายไป _to_delete/originals_icons/moved/ (ไม่ได้ลบ — กู้คืนได้)
"""
import os, re, glob, shutil, sys

MOVES = [
    ("Sprites/ChatGPT Image 27 ส.ค. 2569 11_49_17.png", "Sprites/items/card_poring.png"),
    ("Sprites/items/ChatGPT Image 29 ส.ค. 2569 16_05_07.png", "Sprites/items/card_fabre.png"),
]
TRASH = "_to_delete/originals_icons/moved"
apply = "--apply" in sys.argv


def refs(old_res):
    """ไฟล์ .tres/.tscn ที่อ้างถึงภาพนี้"""
    out = []
    for pat in ("data/**/*.tres", "scenes/**/*.tscn", "data/**/*.tscn"):
        for f in glob.glob(pat, recursive=True):
            if old_res in open(f, encoding="utf-8").read():
                out.append(f)
    return out


def main():
    for old, new in MOVES:
        if not os.path.exists(old):
            print("ข้าม (ไม่มีไฟล์):", old)
            continue
        old_res = "res://" + old.replace("\\", "/")
        new_res = "res://" + new.replace("\\", "/")
        users = refs(old_res)
        print("%s\n   → %s   (ถูกใช้ใน %d ไฟล์: %s)" % (old, new, len(users), ", ".join(os.path.basename(u) for u in users)))
        if not apply:
            continue
        if os.path.exists(new):
            print("   ! มี %s อยู่แล้ว — ไม่เขียนทับ" % new)
        else:
            os.makedirs(os.path.dirname(new), exist_ok=True)
            shutil.copy2(old, new)
        for f in users:
            s = open(f, encoding="utf-8").read()
            # ตัด uid ของภาพเดิมออกด้วย ไม่งั้น Godot จะตามหา uid เก่าแล้วเตือน
            s = re.sub(r'uid="uid://[^"]+"\s+(path="%s")' % re.escape(old_res), r"\1", s)
            s = s.replace(old_res, new_res)
            open(f, "w", encoding="utf-8").write(s)
            print("   แก้ path ใน", f)
        os.makedirs(TRASH, exist_ok=True)
        for suffix in ("", ".import"):
            src = old + suffix
            if os.path.exists(src):
                dst = os.path.join(TRASH, os.path.basename(src))
                if os.path.exists(dst):
                    os.remove(src)
                else:
                    shutil.move(src, dst)
        print("   ย้ายไฟล์เดิมไป", TRASH)
    if not apply:
        print("\n(ใส่ --apply เพื่อทำจริง)")


if __name__ == "__main__":
    main()
