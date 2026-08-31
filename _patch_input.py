#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""เพิ่มปุ่ม WASD + ปุ่มเมนู ลงใน project.godot (รันซ้ำได้ ไม่ซ้ำซ้อน)"""
import io, os, sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."

EVENT = ('Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,'
         '"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,'
         '"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":%d,'
         '"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)')

# ชื่อ action -> physical keycode ที่ใช้ได้
ACTIONS = [
    ("move_left",  [65, 4194319]),          # A / ลูกศรซ้าย
    ("move_right", [68, 4194321]),          # D / ลูกศรขวา
    ("move_up",    [87, 4194320]),          # W / ลูกศรขึ้น
    ("move_down",  [83, 4194322]),          # S / ลูกศรลง
    ("jump",       [87, 32, 4194320]),      # W / Space / ลูกศรขึ้น
    ("toggle_menu", [4194306]),             # Tab
    ("toggle_quests", [85]),                # U = สมุดเควส
]


def block(name, keys):
    events = "\n, ".join(EVENT % k for k in keys)
    return '%s={\n"deadzone": 0.2,\n"events": [%s\n]\n}\n' % (name, events)


def main():
    p = os.path.join(ROOT, "project.godot")
    s = io.open(p, encoding="utf-8").read()

    added = []
    for name, keys in ACTIONS:
        if ("\n%s={" % name) in s:
            continue
        added.append(name)
        if "[input]" in s:
            i = s.index("[input]") + len("[input]")
            # แทรกท้ายหมวด input
            j = s.find("\n[", i)
            if j == -1:
                j = len(s)
            s = s[:j] + "\n" + block(name, keys) + s[j:]
        else:
            s = s.rstrip("\n") + "\n\n[input]\n\n" + block(name, keys)

    if not added:
        print("  ปุ่มครบอยู่แล้ว ไม่ต้องแก้")
        return
    io.open(p, "w", encoding="utf-8", newline="\n").write(s)
    print("  เพิ่มปุ่ม: " + ", ".join(added))


if __name__ == "__main__":
    main()
