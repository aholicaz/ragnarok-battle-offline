#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ขยายขนาดบอส King Poring (แก้ในที่ ไม่ทับไฟล์ที่คุณแก้เอง · รันซ้ำได้)

★ วิธีปรับขนาดมอนเอง ★
เปิด data/monsters/<ชื่อมอน>.tres ใน Godot แล้วแก้ 4 ช่องนี้:
  Display Height   = อยากให้สูงกี่พิกเซลบนจอ  <- ปรับตัวนี้ตัวเดียวก็พอ
  Hitbox Size      = กล่องชน (กว้าง, สูง)      ควรประมาณ 0.5 เท่าของความสูง
  Hp Bar Offset Y  = หลอดเลือดสูงจากจุดกึ่งกลางเท่าไหร่ (ติดลบ = ขึ้นไปข้างบน)
  Attack Range     = ระยะที่ตีถึง
"""
import io, os, re, sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."

# ไฟล์ -> {ช่อง: ค่าใหม่}
TARGETS = {
    "data/monsters/king_poring.tres": {
        "display_height": "300.0",
        "hitbox_size": "Vector2(170, 160)",
        "hp_bar_offset_y": "-250.0",
        "attack_range": "150.0",
    },
}


def main():
    for rel, fields in TARGETS.items():
        p = os.path.join(ROOT, rel)
        if not os.path.exists(p):
            print("  ไม่เจอ %s" % rel)
            continue
        s = io.open(p, encoding="utf-8").read()
        orig = s
        body_at = s.find("[resource]")
        if body_at < 0:
            print("  ! %s ไม่มีหัวข้อ [resource]" % rel)
            continue
        head, body = s[:body_at], s[body_at:]

        for key, value in fields.items():
            line = "%s = %s" % (key, value)
            if re.search(r"^%s = .*$" % key, body, re.M):
                body = re.sub(r"^%s = .*$" % key, line, body, flags=re.M)
            else:
                body = body.rstrip("\n") + "\n" + line + "\n"
        s = head + body

        if s == orig:
            print("  %s ขนาดตรงอยู่แล้ว ข้าม" % os.path.basename(rel))
            continue
        io.open(p, "w", encoding="utf-8", newline="\n").write(s)
        print("  %s -> สูง %s px, กล่องชน %s"
              % (os.path.basename(rel), fields["display_height"], fields["hitbox_size"]))


if __name__ == "__main__":
    print("ขนาดบอส:")
    main()
    print("เสร็จ")
