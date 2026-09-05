#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""★ ปรับลูนาติก (รอบ 67) ★ — รันในโฟลเดอร์โปรเจกต์

    python3 set_lunatic.py            # ดูตารางเทียบ + ค่าที่จะตั้ง (ยังไม่เขียน)
    python3 set_lunatic.py --apply    # เขียนจริง

แก้ 3 เรื่อง
  1) ★ ดุร้าย ★ เห็นผู้เล่นแล้วยิงเลย (เดิมเป็น PASSIVE = ตีก่อนถึงจะสู้)
  2) ★ ยิงไกล 520 px ★ (ระบบรอบ 66 ใช้ Detect Range เป็นระยะยิง)
  3) ★ ยิงห่างขึ้น ★ คูลดาวน์ 1.6 → 2.4 วิ ชดเชยดาเมจ 55-65 ที่แรงเกินเลเวล

  ส่วน "ป้องกันเยอะ" (จริง ๆ คือ MISS บ่อย ไม่ใช่ DEF) ผู้ใช้แก้เองแล้วด้วยการลดเลเวล 15 → 13
  ทำให้ได้ส่วนลดค่าหลบของมอนเลเวลต่ำ (−20%) → ค่าหลบจริง 143 → 113 · สคริปต์ไม่แตะ flee

สำรองไฟล์เดิมไว้ที่ _to_delete/originals_monsters_r67/
"""
import os, re, shutil, sys

BAK = "_to_delete/originals_monsters_r67"
FILE = "data/monsters/lunatic.tres"
apply = "--apply" in sys.argv

# เกณฑ์ลดค่าหลบของมอนเลเวลต่ำ (ต้องตรงกับ combat.gd)
LOW_LEVEL_FLEE_CAP = 15
LOW_LEVEL_FLEE_REDUCTION = 0.20

# =========================================================
# ★ ค่าที่จะตั้ง ★ แก้ตรงนี้แล้วรันใหม่ได้เลย
# =========================================================
VALUES = {
    # ---- 1) ค่าหลบ ----
    # ★ ผู้ใช้แก้เองแล้ว ★ ลดเลเวล 15 → 13 ซึ่งทำให้มันได้ส่วนลดค่าหลบของมอนเลเวลต่ำ (−20%)
    #    ค่าหลบจริง 143 → 113 = เท่าฮอร์เน็ต (111) พอดี · ไม่ต้องแตะ flee อีก
    # (อยากให้ตีเข้าง่ายกว่านี้อีก ค่อยใส่ "flee": "5" ตรงนี้ → ได้ 94)

    # ---- 2) ดุร้าย ----
    "ai_type": "1",                # 0 = ใจดี · 1 = ดุร้าย (เห็นแล้วสู้เลย) · 2 = ยืนอยู่กับที่

    # ---- 3) ยิงไกล 520 px ----
    # ระบบรอบ 66: Ranged Attack Range = 0 → ใช้ Detect Range เป็นระยะยิง
    "detect_range": "520.0",
    "ranged_attack_range": "0.0",  # 0 = ใช้ Detect Range (520)
    "ranged_attack": "true",
    "projectile_range": "900.0",   # ลูกบอลต้องวิ่งไกลกว่าระยะยิง
    "leash_range": "700.0",        # เดิม 520 สั้นกว่าระยะยิง มันจะถูกลากกลับบ้านกลางคัน

    # ---- 4) ไม่ลดดาเมจ แต่ยิงห่างขึ้น ----
    # ตี 55-65 แรงมากสำหรับเลเวล 13 (หมาป่า Lv13 = 42-58) แต่เก็บไว้ให้มันน่ากลัว
    # ชดเชยด้วยการยืดจังหวะยิง → มีเวลาหลบ/เข้าประชิด
    "attack_cooldown": "2.4",      # เดิม 1.6
}


def read_mon(path):
    s = open(path, encoding="utf-8").read()
    b = s[s.index("[resource]"):]

    def n(k, d=0.0):
        m = re.search(r"^%s = ([-\d.]+)$" % k, b, re.M)
        return float(m.group(1)) if m else d

    def t(k, d=""):
        m = re.search(r'^%s = "(.*)"$' % k, b, re.M)
        return m.group(1) if m else d

    lv = int(n("level", 1))
    flee = int(n("flee"))
    real = 100 + lv + flee
    if lv < LOW_LEVEL_FLEE_CAP:
        real = int(round(real * (1.0 - LOW_LEVEL_FLEE_REDUCTION)))
    return dict(name=t("display_name", os.path.basename(path)), lv=lv, hp=int(n("max_hp", 1)),
                df=int(n("def")), flee=flee, real=real)


def table(mark_flee=None):
    """ตารางค่าหลบจริงของมอนทุกตัว เรียงตามเลเวล"""
    rows = []
    for f in sorted(os.listdir("data/monsters")):
        if f.endswith(".tres"):
            r = read_mon(os.path.join("data/monsters", f))
            r["id"] = f[:-5]
            rows.append(r)
    rows.sort(key=lambda r: r["lv"])
    print("\n★ ค่าหลบจริงของมอนทุกตัว (ยิ่งสูง ผู้เล่นยิ่งตีพลาดบ่อย) ★")
    print("  %-16s %3s %6s %4s %5s  %s" % ("ชื่อ", "Lv", "HP", "DEF", "หลบ", ""))
    for r in rows:
        star = ""
        if r["id"] == "lunatic":
            star = "  ← ★ ลูนาติก ★"
            if mark_flee is not None:
                new = 100 + r["lv"] + mark_flee
                if r["lv"] < LOW_LEVEL_FLEE_CAP:
                    new = int(round(new * (1.0 - LOW_LEVEL_FLEE_REDUCTION)))
                star = "  ← ★ แก้เป็น %d ★" % new
        print("  %-16s %3d %6d %4d %5d%s" % (r["name"], r["lv"], r["hp"], r["df"], r["real"], star))


def main():
    if not os.path.exists(FILE):
        sys.exit("ต้องรันในโฟลเดอร์โปรเจกต์ (ไม่เจอ %s)" % FILE)
    before = read_mon(FILE)
    table(int(VALUES["flee"]) if "flee" in VALUES else None)

    print("\n★ ลูนาติก — ค่าที่จะตั้ง ★")
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
        print("    %-22s %-22s → %s" % (k, old, new))
    if not changed:
        print("    (ตั้งไว้ครบแล้ว)")
        return

    print("\n    ค่าหลบจริง %d (Lv%d — ปกติดีแล้ว เท่าฮอร์เน็ต 111)" % (before["real"], before["lv"]))
    print("    พฤติกรรม: ใจดี (ตีก่อนถึงสู้) → ★ ดุร้าย ยิงทันทีที่เห็น ★")
    print("    ระยะยิง: → ★ %s px ★ (ยืนยิงอยู่กับที่ ไม่เดินเข้ามาประชิด)" % VALUES["detect_range"])
    print("    จังหวะยิง: 1.6 → ★ %s วิ ★ (ดาเมจเท่าเดิม แต่มีเวลาหลบ/เข้าประชิด)" % VALUES["attack_cooldown"])

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
