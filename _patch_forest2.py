#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ต่อประตูจากแมพของคุณ (world_node_2d) ไปยัง Asgard Forest 2 (รันซ้ำได้)"""
import io, os, re, sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
MAP = "Sprites/world_node_2d.tscn"


def main():
    p = os.path.join(ROOT, MAP)
    if not os.path.exists(p):
        print("  ไม่เจอแมพ %s" % MAP)
        return
    s = io.open(p, encoding="utf-8").read()
    orig = s

    # ---------- 1) ประตูที่เขียนป้ายว่า Asgard forest 2 อยู่แล้ว ----------
    m = re.search(r'(\[node name="ToTown2"[^\]]*\]\n)((?:(?!\[node)[^\n]*\n)*)', s)
    if m is None:
        print("  ! ไม่เจอประตู ToTown2 — ข้ามขั้นนี้")
    else:
        body = m.group(2)
        new_body = body
        if re.search(r"^target_map = ", new_body, re.M):
            new_body = re.sub(r"^target_map = .*$", 'target_map = &"asgard_forest_2"',
                              new_body, flags=re.M)
        else:
            new_body = 'target_map = &"asgard_forest_2"\n' + new_body
        if re.search(r"^target_spawn_point = ", new_body, re.M):
            new_body = re.sub(r"^target_spawn_point = .*$",
                              'target_spawn_point = &"from_forest_1"', new_body, flags=re.M)
        else:
            new_body = new_body + 'target_spawn_point = &"from_forest_1"\n'
        if 'destination_name' not in new_body:
            new_body = new_body.rstrip("\n") + '\ndestination_name = "Asgard Forest 2"\n\n'
        if new_body != body:
            s = s[:m.start(2)] + new_body + s[m.end(2):]
            print("  ประตู ToTown2 -> asgard_forest_2 (จุดเกิด from_forest_1)")
        else:
            print("  ประตู ToTown2 ตั้งไว้ครบแล้ว ข้าม")

    # ---------- 2) จุดเกิดตอนเดินกลับมาจาก Forest 2 ----------
    if 'name="from_forest_2"' in s:
        print("  จุดเกิด from_forest_2 มีอยู่แล้ว ข้าม")
    else:
        m2 = re.search(r'\[node name="from_town" type="Marker2D" parent="SpawnPoints"[^\]]*\]\n'
                       r'((?:(?!\[node)[^\n]*\n)*)', s)
        if m2 is None:
            print("  ! ไม่เจอ SpawnPoints/from_town — ข้ามขั้นนี้")
        else:
            block = ('[node name="from_forest_2" type="Marker2D" parent="SpawnPoints"]\n'
                     'position = Vector2(4620, 380)\n\n')
            s = s[:m2.end()] + block + s[m2.end():]
            print("  เพิ่มจุดเกิด from_forest_2 ที่ (4620, 380)")

    if s == orig:
        print("  ไม่มีอะไรต้องแก้")
        return
    io.open(p, "w", encoding="utf-8", newline="\n").write(s)
    print("  บันทึกแมพแล้ว")


if __name__ == "__main__":
    main()
    print("เสร็จ")
