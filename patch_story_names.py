## ★ รอบ 30 — ใส่เนื้อเรื่อง Shadows of Fate ลงชื่อแมพ/ประตู/NPC ★
##
## รันครั้งเดียวพอ · รันซ้ำได้ ไม่พัง (เช็คก่อนทุกจุดว่าแก้ไปแล้วหรือยัง)
## สำรองไฟล์เดิมให้อัตโนมัติเป็น <ชื่อ>_ก่อนใส่เนื้อเรื่อง.<นามสกุล>.bak
##
## ★ ปิด Godot ก่อนรัน ★ ไม่งั้น Godot อาจเซฟทับตอนปิดโปรแกรม
import os, shutil, sys

CHANGED = []

def backup(path):
    base, ext = os.path.splitext(path)
    bak = base + "_ก่อนใส่เนื้อเรื่อง" + ext + ".bak"
    if not os.path.exists(bak):
        shutil.copy(path, bak)

def patch(path, pairs, label=""):
    """pairs = [(ข้อความเดิม, ข้อความใหม่), ...] — ข้ามคู่ที่แก้ไปแล้ว"""
    if not os.path.exists(path):
        print("  ! ไม่เจอไฟล์:", path)
        return
    s = open(path, encoding="utf-8").read()
    hits = 0
    for old, new in pairs:
        if new in s:
            continue           # แก้ไปแล้ว
        if old not in s:
            print("  ! ไม่เจอข้อความใน %s: %s" % (os.path.basename(path), old[:48]))
            continue
        s = s.replace(old, new, 1)
        hits += 1
    if hits:
        backup(path)
        open(path, "w", encoding="utf-8").write(s)
        CHANGED.append("%s (%d จุด) %s" % (path, hits, label))

def append_block(path, marker, block, label=""):
    """ต่อท้ายไฟล์ ถ้ายังไม่มี marker อยู่"""
    if not os.path.exists(path):
        print("  ! ไม่เจอไฟล์:", path)
        return
    s = open(path, encoding="utf-8").read()
    if marker in s:
        return
    backup(path)
    if not s.endswith("\n"):
        s += "\n"
    open(path, "w", encoding="utf-8").write(s + block)
    CHANGED.append("%s (เพิ่ม %s) %s" % (path, marker, label))


# =========================================================
# 1) ชื่อแมพ
# =========================================================
print("[1] ชื่อแมพ")

patch("scenes/maps/prontera_town.tscn", [
    ('display_name = "เมืองพรอนเทรา"', 'display_name = "พรอนเทรา นครแห่งสายฟ้า"'),
    ('label_text = "→ ทุ่งหญ้า"', 'label_text = "→ ทุ่งวิหาร"'),
], "เมืองหลัก")

patch("scenes/maps/dark_forest.tscn", [
    ('display_name = "ป่ามืด"', 'display_name = "ป่าเงาลึก"'),
    ('label_text = "→ ทุ่งหญ้า"', 'label_text = "→ ทุ่งวิหาร"'),
], "ป่าลึก")

# ★ Asgard = ดินแดนเทพของบทที่ 9 ★ ห้ามใช้กับป่าข้างเมืองมนุษย์ในบทที่ 1
patch("scenes/maps/asgard_forest_2.tscn", [
    ('display_name = "Asgard Forest 2"', 'display_name = "ป่าสนธยา"'),
    ('label_text = "← Asgard Forest 1"', 'label_text = "← ทุ่งวิหาร"'),
    ('destination_name = "Asgard Forest 1"', 'destination_name = "ทุ่งวิหาร"'),
    ('destination_name = "เมือง Asgard"', 'destination_name = "พรอนเทรา"'),
], "แก้ชื่อ Asgard ที่ชนกับบท 9")

# ฉากสำรองที่ไม่ได้ใช้จริง (Game.MAPS ชี้ไปที่ world_node_2d.tscn) แต่แก้ให้ตรงกันไว้
patch("scenes/maps/prontera_field.tscn", [
    ('display_name = "ทุ่งหญ้าพรอนเทรา"', 'display_name = "ทุ่งวิหาร"'),
    ('label_text = "→ ป่ามืด"', 'label_text = "→ ป่าเงาลึก"'),
], "ฉากสำรอง")

# ★ แมพทุ่งจริงที่เกมใช้ ★ ไม่มีบรรทัด map_id/display_name เลย (ใช้ค่า default ของ MapBase)
patch("Sprites/world_node_2d.tscn", [
    ('script = ExtResource("map_base")\nmap_bounds = Rect2(-170, -320, 4500, 940)',
     'script = ExtResource("map_base")\nmap_id = &"prontera_field"\n'
     'display_name = "ทุ่งวิหาร"\nmap_bounds = Rect2(-170, -320, 4500, 940)'),
    ('label_text = "→ Asgard forest 2"', 'label_text = "→ ป่าสนธยา"'),
    ('destination_name = "Asgard Forest 2"', 'destination_name = "ป่าสนธยา"'),
    ('label_text = "→ เมือง (ร้านค้า/ตีบวก)"', 'label_text = "→ พรอนเทรา"'),
], "ทุ่งวิหาร (แมพจริง)")


# =========================================================
# 2) ชื่อ + บทพูดของ NPC เดิม
# =========================================================
print("[2] NPC เดิม")

patch("scenes/maps/prontera_town.tscn", [
    # --- พ่อค้าโทนี่ (คงชื่อ) — ปลูกเมล็ดของบทที่ 2 ---
    ('dialog = "มีของดีมาขายนะ"',
     'dialog = "มีของดีมาขายนะ\\n\\n'
     '...ถึงจะไม่ค่อยมีของใหม่ก็เถอะ ของจากทางเหนือไม่ได้ส่งมาสามเดือนแล้ว\\n'
     'ไม่มีใครบอกว่าทำไม"'),

    # --- นักบวชหญิงมาเรีย ---
    ('npc_name = "ซิสเตอร์มาเรีย"', 'npc_name = "นักบวชหญิงมาเรีย"'),
    ('dialog = "ขอพรให้เจ้าปลอดภัย"',
     'dialog = "บาดแผลของเจ้าจะหายดี จงขอบคุณธอร์เถิด"'),

    # --- ศิลาสลักแห่งธอร์ ---
    ('npc_name = "ศิลาบันทึก"', 'npc_name = "ศิลาสลักแห่งธอร์"'),
    ('dialog = "บันทึกการเดินทาง"',
     'dialog = "ศิลาสลักตราค้อน · สัมผัสเพื่อบันทึกการเดินทาง"'),

    # --- ทหารยามเอริค ---
    ('npc_name = "ไกด์นำทาง"', 'npc_name = "ทหารยามเอริค"'),
    ('dialog = "กด C ดูสเตตัส, I เปิดกระเป๋า, K เรียนสกิล นะ"',
     'dialog = "เด็กใหม่สินะ ข้าเอริค ยามประตูเมืองนี้\\n\\n'
     'กด C ดูสเตตัส · I เปิดกระเป๋า · K เรียนสกิล · M ดูแผนที่\\n'
     'J หรือคลิกซ้าย = ฟันดาบ · W หรือ Space = พุ่งหลบ อย่าอาย ข้าเองก็หลบทุกครั้ง\\n\\n'
     '...แล้วก็อย่าเข้าป่าลึกตอนค่ำนะ ผู้กองสั่งห้ามไว้\\n'
     'ไม่ได้บอกเหตุผลด้วย"'),

    # --- ช่างตีเหล็กฮันส์ (คงชื่อ) — สะพานไปบทที่ 2 ---
    ('dialog = "อยากให้อาวุธแกร่งขึ้นไหม"',
     'dialog = "อยากให้อาวุธแกร่งขึ้นไหม\\n\\n'
     'ตีเหล็กแบบนี้ข้าเรียนมาจากใต้ภูเขา ที่นั่นเขาตีกันมาเป็นพันปีแล้ว\\n'
     '...แต่ข้าถูกไล่ออกมา เพราะข้าถามคำถามที่ไม่ควรถาม"'),
], "เปลี่ยนชื่อ + บทพูด")


# =========================================================
# 3) NPC ใหม่ 4 ตัว
# =========================================================
print("[3] NPC ใหม่")

NEW_NPCS = '''
[node name="HighPriest" parent="NPCs" instance=ExtResource("npc")]
position = Vector2(1380, 590)
npc_name = "นักบวชสูงสุดวาลเดอร์"
type = 0
dialog = "เจ้ามาถูกที่แล้ว ลูกเอ๋ย\\n\\nทุกคนที่ยืนอยู่ในเมืองนี้ยืนอยู่ได้เพราะค้อนของพระองค์\\nจงถือดาบไว้ให้มั่น แล้วสายฟ้าจะนำทางเจ้าเอง"

[node name="OldMan" parent="NPCs" instance=ExtResource("npc")]
position = Vector2(-330, 590)
npc_name = "ตาแก่กุนนาร์"
type = 0
dialog = "เด็กใหม่สินะ...\\n\\nระวังตัวด้วยแล้วกัน"

[node name="Ingrid" parent="NPCs" instance=ExtResource("npc")]
position = Vector2(830, 590)
npc_name = "อิงกริด"
type = 0
dialog = "พ่อของข้าเข้าป่าไปเมื่อสิบวันก่อน\\n\\nแกเป็นนักล่า แกไม่เคยหลงทาง\\nแต่คราวนี้แกยังไม่กลับมา"

[node name="GuildMaster" parent="NPCs" instance=ExtResource("npc")]
position = Vector2(2020, 590)
npc_name = "หัวหน้ากิลด์บียอร์น"
type = 0
dialog = "กิลด์นักผจญภัยพรอนเทรา ยินดีต้อนรับ\\n\\nงานล่ามีเรื่อย ๆ ถ้าอยากได้เงินก็มาถามข้าได้\\n\\nช่วงนี้มอนสเตอร์แถวทุ่งเยอะผิดปกติ\\nแปลกนะ พวกมันไม่ได้วิ่งมาทางเมือง พวกมันวิ่งผ่านไป"
'''

append_block("scenes/maps/prontera_town.tscn", 'name="HighPriest"', NEW_NPCS,
             "วาลเดอร์ · กุนนาร์ · อิงกริด · บียอร์น")


# =========================================================
# 4) ชื่อเควสเดิมให้เข้าเนื้อเรื่อง
# =========================================================
print("[4] เควสเดิม")

patch("data/quests/hans_poring.tres", [
    ('title = "กำจัดโพริงให้ฮันส์"', 'title = "งานแรก — โพริงล้นทุ่ง"'),
    ('description = "โพริงเยอะเกินไปจนช่างตีเหล็กออกไปหาแร่ไม่ได้ ช่วยจัดการให้หน่อย"',
     'description = "โพริงล้นออกมาจากป่าจนฮันส์ออกไปหาแร่ไม่ได้ ช่วยเคลียร์ทุ่งวิหารให้หน่อย"'),
], "M3")

patch("data/quests/tony_fabre.tres", [
    ('title = "กำจัดแฟเบรให้โทนี่"', 'title = "กระสอบที่ถูกกัด"'),
    ('description = "แฟเบรแอบกัดกระสอบสินค้าของพ่อค้าโทนี่จนเสียหาย ช่วยจัดการให้หน่อย"',
     'description = "แฟเบรแอบกัดกระสอบสินค้าของโทนี่จนเสียหาย ช่วยจัดการให้หน่อย"'),
], "M4")


# =========================================================
print()
if CHANGED:
    print("แก้เรียบร้อย:")
    for c in CHANGED:
        print("  ·", c)
    print("\n★ เปิด Godot ใหม่แล้วกด F5 ได้เลย ★")
else:
    print("ทุกอย่างเป็นชื่อใหม่อยู่แล้ว — ไม่ได้แก้อะไรเพิ่ม")
