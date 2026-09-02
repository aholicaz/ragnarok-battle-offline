# -*- coding: utf-8 -*-
## ★ รอบ 33 — ตั้งจังหวะ "เดิน / ยืนพัก" ให้มอนแต่ละตัว ★
##
## ของเดิมมอนเดินเกือบตลอดเวลา (พักแค่ 0.5-1.3 วิ และมีโอกาสแค่ 28%)
## ตอนนี้ตั้งได้ต่อตัว ให้เข้ากับนิสัยของมอน:
##   ตัวช้า/ตัวใหญ่  = พักบ่อย พักนาน   · ตัวบิน/ตัวดุ = แทบไม่พัก
##
## รันซ้ำได้ ไม่พัง (เขียนทับค่าเดิมของช่องเหล่านี้เท่านั้น)
## ★ ปิด Godot ก่อนรัน ★
import os, re, shutil

os.chdir(os.path.dirname(os.path.abspath(__file__)))

# id: (โอกาสพัก, พักต่ำสุด, พักสูงสุด, เดินต่ำสุด, เดินสูงสุด, โอกาสหันมอง, เหตุผล)
TUNE = {
    # ---------- บทที่ 1 ----------
    "poring":        (0.70, 3.0, 5.0, 1.4, 2.6, 0.6, "ก้อนวุ้นเด้ง ๆ ช้า ๆ พักบ่อย"),
    "fabre":         (0.70, 3.0, 5.0, 1.4, 2.6, 0.7, "หนอนคืบช้า"),
    "lunatic":       (0.75, 2.0, 3.5, 1.0, 2.0, 0.9, "กระต่าย หยุดบ่อยแต่สั้น ชอบเหลียวมอง"),
    "drops":         (0.70, 3.0, 5.0, 1.4, 2.6, 0.6, "วุ้นเหมือนโพริง"),
    "chonchon":      (0.30, 1.0, 2.0, 2.0, 3.5, 0.5, "แมลงบิน อยู่ไม่นิ่ง"),
    "hornet":        (0.20, 0.8, 1.6, 2.5, 4.0, 0.4, "ต่อดุ บินวนแทบไม่หยุด"),
    "wolf":          (0.55, 2.5, 4.0, 2.0, 3.5, 0.9, "หมาป่าเดินตรวจแล้วหยุดดมกลิ่น"),
    "king_poring":   (0.70, 3.5, 5.5, 1.5, 2.8, 0.5, "มินิบอสตัวใหญ่ ช้า"),
    "munak":         (0.80, 4.0, 6.0, 1.2, 2.4, 0.5, "ผีสาว ยืนนิ่งนาน ๆ ให้ดูหลอน"),
    "orc_warrior":   (0.50, 2.5, 4.0, 2.0, 3.5, 0.7, "ทหารออร์คเดินตรวจการณ์"),
    "baphomet_jr":   (0.40, 1.5, 3.0, 1.8, 3.0, 0.8, "ปีศาจน้อย อยู่ไม่สุข"),
    "baphomet":      (0.60, 3.0, 5.0, 2.0, 3.5, 0.5, "บอสใหญ่ ยืนสง่า"),
    # ---------- บทที่ 2 ----------
    "pitman":        (0.70, 3.0, 5.0, 1.5, 2.8, 0.6, "ขุดดินอยู่กับที่"),
    "steel_beetle":  (0.70, 3.5, 5.5, 1.5, 2.5, 0.5, "ด้วงเกราะหนัก เดินช้า"),
    "ember_bat":     (0.25, 0.8, 1.5, 2.5, 4.0, 0.4, "ค้างคาวบิน ไม่หยุด"),
    "magma_slug":    (0.75, 4.0, 6.0, 1.5, 3.0, 0.4, "ทากช้ามาก"),
    "forge_golem":   (0.75, 4.0, 6.0, 2.0, 3.5, 0.4, "โกเลมยักษ์ ขยับทีนึงนาน"),
    "silent_wraith": (0.60, 3.0, 5.0, 1.8, 3.2, 0.8, "ภูตไร้เสียง ลอยแล้วหยุด"),
    "rune_watcher":  (0.80, 4.0, 6.0, 1.5, 2.5, 0.6, "ผู้เฝ้า — ยืนเฝ้าเป็นหลัก"),
    "forge_guardian": (0.60, 3.0, 5.0, 2.0, 3.5, 0.5, "บอส ยืนเฝ้าเตาหลอม"),
}

FIELDS = ["wander_pause_chance", "wander_pause_min", "wander_pause_max",
          "wander_walk_min", "wander_walk_max", "wander_look_chance"]

changed = []
for mid, vals in sorted(TUNE.items()):
    path = "data/monsters/%s.tres" % mid
    if not os.path.exists(path):
        print("  ! ไม่เจอ", path)
        continue
    s = open(path, encoding="utf-8").read()
    orig = s
    lines = ["%s = %.2f" % (f, v) for f, v in zip(FIELDS, vals[:6])]
    block = "\n".join(lines)

    # ลบค่าเก่าของช่องเหล่านี้ออกก่อน (กันซ้ำตอนรันรอบสอง)
    for f in FIELDS:
        s = re.sub(r"^%s = [-\d.]+\n" % re.escape(f), "", s, flags=re.M)

    # แทรกต่อท้ายบรรทัด hop_while_wandering ถ้ามี · ไม่มีก็ต่อท้าย jump_interval · ไม่มีอีกก็ต่อท้ายไฟล์
    for anchor in ["hop_while_wandering", "jump_interval", "wander_range", "move_speed"]:
        m = re.search(r"^%s = [^\n]*\n" % re.escape(anchor), s, flags=re.M)
        if m:
            s = s[:m.end()] + block + "\n" + s[m.end():]
            break
    else:
        if not s.endswith("\n"):
            s += "\n"
        s += block + "\n"

    if s != orig:
        bak = path.replace(".tres", "_ก่อนจังหวะพัก.tres.bak")
        if not os.path.exists(bak):
            shutil.copy(path, bak)
        open(path, "w", encoding="utf-8").write(s)
        changed.append("%-16s พัก %.0f%% %.1f-%.1f วิ · เดิน %.1f-%.1f วิ  (%s)"
                       % (mid, vals[0] * 100, vals[1], vals[2], vals[3], vals[4], vals[6]))

print()
if changed:
    print("ตั้งจังหวะให้มอน %d ตัว:" % len(changed))
    for c in changed:
        print("  ·", c)
    print("\n★ เปิด Godot ใหม่แล้วกด F5 ได้เลย ★")
else:
    print("ทุกตัวตั้งค่าไว้แล้ว ไม่ได้แก้อะไรเพิ่ม")
