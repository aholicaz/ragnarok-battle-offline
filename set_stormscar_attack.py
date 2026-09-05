#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""★ อสูรสายฟ้าตะปบ 2 ที (รอบ 69) ★ — รันในโฟลเดอร์โปรเจกต์

    python3 set_stormscar_attack.py            # ดูว่าจะตั้งอะไร (ยังไม่เขียน)
    python3 set_stormscar_attack.py --apply    # เขียนจริง

ท่าโจมตี (attack v2.png · 32 เฟรม 15 fps = 2.13 วิ) มันตะปบ 2 ครั้งจริง ๆ
วัดจากภาพ: ดูว่าอุ้งเท้ายื่นไปข้างหน้าสุดที่เฟรมไหน

    เฟรม  8- 9   ยกอุ้งเท้าขึ้น (เตรียมที่ 1)
    เฟรม 10-12   ฟาดลง
    เฟรม 13      ★ โดนที่ 1 ★  (อุ้งเท้ายื่นสุด ปากอ้า)
    เฟรม 14-16   ดึงกลับ ยกขึ้นใหม่ (เตรียมที่ 2)
    เฟรม 17-19   ฟาดลงอีกครั้ง
    เฟรม 20      ★ โดนที่ 2 ★
    เฟรม 21-31   ลงท่า

ระบบใหม่รอบ 69: MonsterData ช่อง **Attack Hit Frames** ใส่ได้หลายเฟรม
= ดาเมจออกหลายครั้งในท่าเดียว · ใช้กับมอนตัวไหนก็ได้

สำรองไฟล์เดิมไว้ที่ _to_delete/originals_monsters_r69/
"""
import os, re, shutil, sys

BAK = "_to_delete/originals_monsters_r69"
FILE = "data/monsters/stormscar.tres"
FRAMES = "data/sprites/placeholder/stormscar_frames.tres"
apply = "--apply" in sys.argv

# =========================================================
# ★ ค่าที่จะตั้ง ★ แก้ตรงนี้แล้วรันใหม่ได้เลย
# =========================================================
VALUES = {
    # ★ เฟรมที่ดาเมจออก ★ ใส่กี่ตัวก็ได้ = ตีกี่ที
    "attack_hit_frames": "PackedInt32Array(13, 20)",
    # ★ ดาเมจต่อที ★ 1.0 = เต็มทั้งสองที (รวม 2 เท่า) · 0.65 = รวมแล้ว 1.3 เท่า
    #   อยากให้แต่ละทีเต็มดาเมจไปเลย เปลี่ยนเป็น "1.0"
    "attack_hit_damage_mult": "0.65",
    # ท่ายาว 2.13 วิ ถ้าไม่เปิดจะถูกตัดที่ Attack Duration (0.5 วิ) แล้วเด้งกลับท่ายืนกลางคัน
    "attack_follow_anim": "true",
    # attack_windup ไม่ได้ใช้แล้วเพราะมี hit frames — สคริปต์คิดให้เองจาก เฟรมแรก ÷ fps จริง
    # (จะได้ตรงกันเสมอแม้เปลี่ยน fps ของท่า)
}


def anim_info(path, name):
    """คืน (จำนวนเฟรม, fps) ของท่านั้นใน SpriteFrames"""
    if not os.path.exists(path):
        return None, None
    s = open(path, encoding="utf-8").read()
    m = re.search(
        r'\{\n"frames": \[(.*?)\],\n"loop": \w+,\n"name": &"%s",\n"speed": ([\d.]+)\n\}' % re.escape(name),
        s[s.index("animations = ["):], re.S)
    if m is None:
        return None, None
    return len(re.findall(r'SubResource\("[^"]+"\)', m.group(1))), float(m.group(2))


def main():
    if not os.path.exists(FILE):
        sys.exit("ต้องรันในโฟลเดอร์โปรเจกต์ (ไม่เจอ %s)" % FILE)

    n, fps = anim_info(FRAMES, "Attack")
    hits = [int(x) for x in re.findall(r"\d+", VALUES["attack_hit_frames"].split("(", 1)[1])]
    if n:
        print("★ ท่าโจมตี %d เฟรม %.0f fps = %.2f วิ ★" % (n, fps, n / fps))
        for i, f in enumerate(hits):
            print("    โดนที่ %d: เฟรม %2d = %.2f วินาทีหลังเริ่มท่า" % (i + 1, f, f / fps))
        bad = [f for f in hits if f >= n]
        if bad:
            print("    ★ เตือน: เฟรม %s เกินจำนวนเฟรมของท่า (%d) ★" % (bad, n))
        if len(hits) > 1:
            print("    ห่างกัน %.2f วิ" % ((hits[-1] - hits[0]) / fps))
    else:
        print("(อ่านท่า Attack จาก %s ไม่ได้ — ข้ามการตรวจเฟรม)" % FRAMES)

    # ★ ตั้ง attack_windup ให้ตรงกับเฟรมแรกเสมอ (เผื่อวันหลังถอด hit frames ออก) ★
    if n and fps:
        VALUES["attack_windup"] = "%.2f" % (hits[0] / fps)

    print("\n★ ค่าที่จะตั้ง ★")
    s = open(FILE, encoding="utf-8").read()
    at = s.index("[resource]")
    head, body = s[:at], s[at:]
    changed = []
    for key, val in VALUES.items():
        m = re.search(r"^%s = (.*)$" % re.escape(key), body, re.M)
        if m:
            if m.group(1).strip() != val:
                changed.append((key, m.group(1).strip(), val))
                body = body[:m.start()] + "%s = %s" % (key, val) + body[m.end():]
        else:
            changed.append((key, "(ไม่มี = ค่าเริ่มต้น)", val))
            body = body.rstrip("\n") + "\n%s = %s\n" % (key, val)
    for k, old, new in changed:
        print("    %-26s %-22s → %s" % (k, old, new))
    if not changed:
        print("    (ตั้งไว้ครบแล้ว)")
        return

    mult = float(VALUES["attack_hit_damage_mult"])
    print("\n    ดาเมจรวมต่อการโจมตี 1 ครั้ง = %d ที x %.2f = %.2f เท่าของเดิม"
          % (len(hits), mult, len(hits) * mult))
    if not apply:
        print("\n(ใส่ --apply เพื่อเขียนจริง)")
        return
    os.makedirs(BAK, exist_ok=True)
    b = os.path.join(BAK, os.path.basename(FILE))
    if not os.path.exists(b):
        shutil.copy2(FILE, b)
    open(FILE, "w", encoding="utf-8").write(head + body)
    print("\nเขียนแล้ว: %s  (สำรองที่ %s)" % (FILE, b))


if __name__ == "__main__":
    main()
