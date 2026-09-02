# -*- coding: utf-8 -*-
## ★★ รอบ 38 — เควสเนื้อเรื่องหลัก M1-M13 + บอสอสูรสายฟ้า + แมพรอยสายฟ้า + เควสบท 2 (C2-1..C2-8) ★★
## รันซ้ำได้ (idempotent) · ปิด Godot ก่อนรัน · ใช้ฟังก์ชันจาก gen_round31.py
##
## สิ่งที่สร้าง/แก้:
##   1. ไอเทมเควส 4 ชิ้น: adventurer_badge · burnt_bark_piece · hunter_journal · glow_shard (+ไอคอนชั่วคราว)
##   2. บอสใหม่ stormscar (อสูรสายฟ้า Lv.20) + การ์ด + ของขยะ 2 ชิ้น + สไปรท์ชั่วคราว
##   3. แมพใหม่ thunder_scar (รอยสายฟ้า — ลานบอสบทที่ 1) + ประตูจากป่าเงาลึก (ล็อกธง thunder_scar_open)
##   4. เควส M1-M13 (บท 1) + C2-1..C2-8 (บท 2) — data/quests/*.tres
##   5. king_poring ดรอป glow_shard 100% (ของเควส M11)
##   6. ผูก quest_ids ให้ NPC ในเมือง + LoreObject ใหม่ 3 จุดในป่า + บทพูดตามธงของกุนนาร์/วาลเดอร์
##   7. ลงทะเบียน thunder_scar ใน Game.MAPS (แก้ scripts/core/game.gd)
import os, re, importlib.util

os.chdir(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_file_location("g31", "gen_round31.py")
g = importlib.util.module_from_spec(spec)
spec.loader.exec_module(g)          # main() มีการ์ด __main__ — ไม่รันเอง
write, patch, LOG = g.w, g.patch, g.LOG

# =========================================================
# 1) ไอเทมเควส (type = 4 QUEST — ขายไม่ได้ ทิ้งไม่ได้)
# =========================================================
def quest_item(item_id, name, desc, code, color):
    g.ICON_JOBS.append((item_id, code, color))
    return '''[gd_resource type="Resource" script_class="ItemData" load_steps=3 format=3]

%s
%s

[resource]
script = ExtResource("1_item")
id = &"%s"
display_name = "%s"
description = "%s"
icon = ExtResource("2_icon")
type = 4
buy_price = 0
sell_price = 0
''' % (g.ITEM_SCRIPT, g.icon_line(item_id), item_id, name, desc)

QUEST_ITEMS = [
    ("adventurer_badge", "ตราประจำตัวนักผจญภัย", "ตราทองเหลืองสลักรูปสายฟ้า ออกโดยกองยามพรอนเทรา", "AB", (200, 170, 90)),
    ("burnt_bark_piece", "เศษเปลือกไม้ไหม้", "เปลือกไม้จากป่าสนธยา รอยไหม้เป็นเส้นตรงผิดธรรมชาติ ไม่เหมือนโดนไฟป่า", "BB", (90, 60, 40)),
    ("hunter_journal", "สมุดของนักล่า", "สมุดบันทึกเปื้อนโคลนของนักล่าที่หายไป หน้าสุดท้ายเขียนว่า «พวกมันไม่ได้ล่า พวกมันหนี»", "HJ", (120, 100, 70)),
    ("glow_shard", "เศษแก้วเรืองแสง", "เศษแก้วใสที่เรืองแสงสีทองจาง ๆ ตลอดเวลา อุ่นเหมือนมีชีวิต", "GS", (255, 215, 100)),
]

# =========================================================
# 2) บอสอสูรสายฟ้า (stormscar)
# =========================================================
g.JUNK.append(("storm_scale", "เกล็ดอสูรสายฟ้า", "เกล็ดสีน้ำเงินเข้มจากตัวอสูรสายฟ้า ยังมีไฟฟ้าสถิตแปลบ ๆ", 3000, "SC", "stormscar", 100, 1))
g.JUNK.append(("charged_horn", "เขาสะสมประจุ", "เขาโค้งของอสูรสายฟ้า จับแล้วขนลุกทั้งแขน", 5000, "CH", "stormscar", 40, 1))

STORMSCAR = dict(
    id="stormscar", name="อสูรสายฟ้า", code="TH", color=(80, 90, 200),
    hb=(90, 110), h=300.0, lv=20, hp=4500, atk=(85, 125), df=20, mdef=25,
    hit=55, flee=25, crit=5, el=4, race=6, size=2, ai=1, spd=170.0, jump=0,
    exp=6000, zeny=(1500, 2500), kb=260,
    boss="อสูรสายฟ้า — สิ่งที่ซุ่มอยู่ในรอยสายฟ้า",
    skill=dict(name="สายฟ้าคำราม", rng=420, rx=260, ry=200, mult=1.6, windup=0.8, dur=0.6),
    card=dict(slot=3, r=4, txt="ซากของมันสลายเป็นแสงทอง... แล้วไหลลงดินไปทางเหนือ",
              atk=5, bonus_agi=2, pct={"aspd_percent": 5.0}),
    extra=[],
)

# =========================================================
# 3) เควส — ตัวช่วยเขียนไฟล์
# =========================================================
K_KILL, K_COLLECT, K_TALK, K_VISIT, K_READ, K_FLAG = range(6)

def obj(kind, target, count=1, text="", consume=True):
    return dict(kind=kind, target=target, count=count, text=text, consume=consume)

def quest_tres(q):
    subs, refs = [], []
    for i, o in enumerate(q["objs"]):
        lines = ['[sub_resource type="Resource" id="Obj_%d"]' % i,
                 'script = ExtResource("2_obj")',
                 'kind = %d' % o["kind"], 'target = &"%s"' % o["target"], 'count = %d' % o["count"]]
        if o["text"]:
            lines.append('text = "%s"' % o["text"])
        if o["kind"] == K_COLLECT and not o["consume"]:
            lines.append('consume = false')
        subs.append("\n".join(lines))
        refs.append('SubResource("Obj_%d")' % i)
    body = ['script = ExtResource("1_quest")',
            'id = &"%s"' % q["id"], 'title = "%s"' % q["title"],
            'description = "%s"' % q["desc"], 'giver_name = "%s"' % q["giver"],
            'dialog_offer = "%s"' % q["offer"],
            'dialog_progress = "%s"' % q["progress"],
            'dialog_complete = "%s"' % q["complete"],
            'objectives = Array[ExtResource("2_obj")]([%s])' % ", ".join(refs),
            'kill_monster_id = &""',
            'required_level = %d' % q.get("lv", 1)]
    if q.get("req"):
        body.append('required_quests = Array[StringName]([%s])' % ", ".join('&"%s"' % r for r in q["req"]))
    if q.get("req_flag"):
        body.append('required_flag = &"%s"' % q["req_flag"])
    if q.get("flag"):
        body.append('set_flag_on_complete = &"%s"' % q["flag"])
    if q.get("choice"):
        c = q["choice"]
        body += ['choice_prompt = "%s"' % c["prompt"],
                 'choice_options = Array[String]([%s])' % ", ".join('"%s"' % o for o in c["options"]),
                 'choice_flags = Array[StringName]([%s])' % ", ".join('&"%s"' % f for f in c["flags"])]
    if q.get("pan"):
        body += ['cutscene_pan_npc = "%s"' % q["pan"][0],
                 'cutscene_text = "%s"' % q["pan"][1]]
    r = q.get("reward", {})
    if r.get("item"):
        body += ['reward_item_id = &"%s"' % r["item"][0], 'reward_item_count = %d' % r["item"][1]]
    body += ['reward_zeny = %d' % r.get("zeny", 0), 'reward_exp = %d' % r.get("exp", 0)]
    return '''[gd_resource type="Resource" script_class="QuestData" load_steps=%d format=3]

[ext_resource type="Script" path="res://scripts/resources/quest_data.gd" id="1_quest"]
[ext_resource type="Script" path="res://scripts/resources/objective_data.gd" id="2_obj"]

%s

[resource]
%s
''' % (3 + len(subs), "\n\n".join(subs), "\n".join(body))


## ★★ เควสหลักบท 1 — Shadows of Fate ★★ (M3 = hans_poring · M4 = tony_fabre ที่มีอยู่แล้ว)
QUESTS = [
    dict(id="m1_adventurer_badge", title="M1 ตราประจำตัวนักผจญภัย", giver="ทหารยามเอริค", lv=1,
         desc="ทำความรู้จักผู้คนสำคัญของพรอนเทรา แล้วรับตราประจำตัวนักผจญภัยจากเอริค",
         offer="นักผจญภัยหน้าใหม่สินะ ก่อนออกนอกเมือง ไปทำความรู้จักผู้คนก่อน — หัวหน้ากิลด์ พ่อค้า แล้วก็ท่านนักบวช เสร็จแล้วข้าจะออกตราประจำตัวให้",
         progress="ยังทักทายไม่ครบเลยนะ กิลด์อยู่ทางขวาสุดของเมือง ร้านโทนี่อยู่กลางเมือง",
         complete="เรียบร้อย! นี่ตราประจำตัวของเจ้า ยินดีต้อนรับสู่พรอนเทรา นครแห่งสายฟ้า จงขอบคุณธอร์ที่นำเจ้ามาถึงที่นี่",
         objs=[obj(K_TALK, "หัวหน้ากิลด์บียอร์น"), obj(K_TALK, "พ่อค้าโทนี่"), obj(K_TALK, "นักบวชหญิงมาเรีย")],
         reward=dict(item=("adventurer_badge", 1), zeny=200, exp=120)),

    dict(id="m2_oath", title="M2 คำสาบานใต้ค้อน", giver="นักบวชสูงสุดวาลเดอร์", lv=2, req=["m1_adventurer_badge"],
         desc="ทำพิธีต่อหน้าศิลาสลักแห่งธอร์ แล้วกลับมากล่าวคำสาบานกับวาลเดอร์",
         offer="นักผจญภัยทุกคนต้องผ่านพิธีใต้ค้อน จงไปแตะศิลาสลักแห่งธอร์กลางเมือง แล้วกลับมาหาข้า",
         progress="ศิลาสลักอยู่กลางเมือง ใต้ตราค้อนใหญ่นั่นแหละ",
         complete="บัดนี้เจ้ายืนอยู่ใต้แสงของธอร์แล้ว เหลือเพียงขั้นสุดท้าย...",
         objs=[obj(K_TALK, "ศิลาสลักแห่งธอร์", text="ทำพิธีที่ศิลาสลักแห่งธอร์")],
         choice=dict(prompt="จงกล่าวตามข้า — «ข้าขอสาบานต่อธอร์ จะรับใช้แสงแห่งสายฟ้าตราบชีวิตจะหาไม่»",
                     options=["ข้าขอสาบาน", "...(ยืนเงียบ)"],
                     flags=["swore_oath", "stayed_silent"]),
         reward=dict(exp=250)),

    dict(id="m5_old_mine_iron", title="M5 เหล็กจากเหมืองเก่า", giver="ช่างตีเหล็กฮันส์", lv=5, req=["tony_fabre"],
         desc="หาแร่เหล็กจากมอนสเตอร์แถวป่าสนธยามาให้ฮันส์ (ชอนชอนชอบกลืนแร่เข้าไป)",
         offer="ของจากทางเหนือขาดมาสามเดือน เหล็กข้าใกล้หมดแล้ว... พวกชอนชอนในป่าสนธยาชอบกลืนแร่เหล็ก ช่วยหามาให้ข้าห้าก้อนที",
         progress="แร่เหล็กห้าก้อน ลองล่าพวกชอนชอนในป่าสนธยาดู",
         complete="พอถูไถไปได้อีกพัก... เจ้ารู้ไหม สมัยก่อนคนแคระใต้ภูเขาเหนือตีเหล็กให้ทั้งเก้าโลก ข้าเคยเป็นลูกศิษย์พวกเขา แต่สามเดือนมานี้... เงียบไปทั้งภูเขา",
         objs=[obj(K_COLLECT, "iron_ore", 5)],
         flag="heard_mountain_story",
         reward=dict(item=("phracon", 3), zeny=500, exp=900)),

    dict(id="m6_ceremony", title="M6 พิธีฉลองชัยชนะ", giver="นักบวชสูงสุดวาลเดอร์", lv=6, req=["m5_old_mine_iron"],
         desc="ช่วยวาลเดอร์เตรียมพิธีขอบคุณธอร์ครั้งใหญ่ แจ้งมาเรียกับเอริคให้พร้อม",
         offer="ค่ำนี้จะมีพิธีขอบคุณธอร์ครั้งใหญ่ ไปแจ้งมาเรียให้เตรียมบทสวด และแจ้งเอริคให้จัดแถวยาม",
         progress="แจ้งมาเรียกับเอริคให้ครบก่อนนะ พิธีรอไม่ได้",
         complete="สมบูรณ์แบบ... ฟังสิ ทั้งเมืองกำลังสวดพร้อมกัน จงขอบคุณธอร์!",
         objs=[obj(K_TALK, "นักบวชหญิงมาเรีย", text="แจ้งมาเรียเรื่องพิธี"), obj(K_TALK, "ทหารยามเอริค", text="แจ้งเอริคเรื่องพิธี")],
         pan=("ตาแก่กุนนาร์", "ทั้งเมืองก้มหัว ยกมือขึ้นสวดพร้อมกัน\n\n...ยกเว้นชายชราคนหนึ่ง\n\nตาแก่กุนนาร์ยืนนิ่ง มองท้องฟ้าเงียบ ๆ\nมือทั้งสองข้างไม่ได้ยกขึ้นเลย"),
         flag="saw_ceremony",
         reward=dict(zeny=300, exp=800)),

    dict(id="m7_silent_forest", title="M7 ป่าที่เงียบเกินไป", giver="ทหารยามเอริค", lv=7, req=["m6_ceremony"],
         desc="ป่าสนธยาเงียบผิดปกติ ไปตรวจดูว่าเกิดอะไรขึ้น",
         offer="พวกลาดตระเวนบอกว่าป่าสนธยาช่วงนี้เงียบผิดปกติ... เสียงนกเสียงแมลงหายไปเป็นหย่อม ๆ ไปตรวจดูที ถ้าเจออะไรแปลก ๆ ให้ดูให้ละเอียด",
         progress="ในป่าสนธยา ลองเดินลึกเข้าไปหน่อย มีบางอย่างให้ตรวจแน่ ๆ",
         complete="ตายโดยไม่มีบาดแผล...? ...อย่าเพิ่งเล่าเรื่องนี้ให้ชาวเมืองฟัง เดี๋ยวคนแตกตื่น ข้าจะรายงานท่านวาลเดอร์เอง",
         objs=[obj(K_VISIT, "asgard_forest_2", text="ไปที่ป่าสนธยา"), obj(K_READ, "dead_monster", text="ตรวจดูซากมอนสเตอร์ในป่าสนธยา")],
         reward=dict(zeny=400, exp=1200)),

    dict(id="m8_burnt_bark", title="M8 รอยไหม้บนเปลือกไม้", giver="นักบวชสูงสุดวาลเดอร์", lv=8, req=["m7_silent_forest"],
         desc="เก็บตัวอย่างเปลือกไม้ที่มีรอยไหม้ประหลาดจากป่าสนธยามาให้วาลเดอร์",
         offer="เอริครายงานเรื่องในป่ามาแล้ว ข้าต้องการเห็นกับตา... ไปเก็บตัวอย่างเปลือกไม้ที่มีรอยไหม้มาให้ข้า",
         progress="ต้นไม้ที่มีรอยไหม้อยู่ลึกเข้าไปในป่าสนธยา",
         complete="อืม... รอยไหม้แบบนี้ข้าเคยเห็นในตำราเก่า ตัวอย่างนี้ข้าเก็บไว้ศึกษาเอง เจ้าไม่ต้องยุ่งกับเรื่องนี้อีก เข้าใจไหม",
         objs=[obj(K_READ, "burnt_bark", text="ตรวจต้นไม้ที่มีรอยไหม้"), obj(K_COLLECT, "burnt_bark_piece", 1, text="เก็บเศษเปลือกไม้ไหม้ไปให้วาลเดอร์")],
         flag="valder_kept_bark",
         reward=dict(exp=1500)),

    dict(id="m9_missing_hunter", title="M9 คนที่ไม่กลับมา", giver="อิงกริด", lv=10, req=["m8_burnt_bark"],
         desc="พ่อของอิงกริดหายไปในป่าเงาลึก เคลียร์ฝูงหมาป่าเพื่อเปิดทางตามหา",
         offer="พ่อข้าเข้าป่าเงาลึกไปหลายวันแล้วยังไม่กลับ... แกไม่เคยหลงทางนะ ช่วยข้าที ฝูงหมาป่าแถวนั้นดุจนข้าเข้าไปเองไม่ได้",
         progress="หมาป่าในป่าเงาลึกยังเยอะอยู่ ระวังตัวด้วยนะ",
         complete="ยังไม่เจอตัวพ่อ... แต่ขอบคุณที่เปิดทางให้ ถ้าเจอข้าวของของพ่อ เอามาให้ข้าดูด้วยนะ",
         objs=[obj(K_VISIT, "dark_forest", text="ไปที่ป่าเงาลึก"), obj(K_KILL, "wolf", 10)],
         reward=dict(zeny=600, exp=2000)),

    dict(id="m10_hunter_journal", title="M10 สมุดของนักล่า", giver="อิงกริด", lv=11, req=["m9_missing_hunter"],
         desc="ตามหาแคมป์ของนักล่าในป่าเงาลึก แล้วนำสิ่งที่พบกลับมาให้อิงกริด",
         offer="พ่อชอบตั้งแคมป์ลึกเข้าไปทางตะวันออกของป่าเงาลึก... ลองไปดูตรงนั้นที ขอร้องล่ะ",
         progress="แคมป์อยู่ลึกเข้าไปทางตะวันออกของป่าเงาลึก",
         complete="ลายมือพ่อจริง ๆ ด้วย... «พวกมันไม่ได้ล่า พวกมันหนี» ...หนีจากอะไรกัน? สมุดเล่มนี้เจ้าเก็บไว้เถอะ ข้าอ่านแล้วใจไม่ดีเลย",
         objs=[obj(K_READ, "hunter_camp", text="ตรวจดูแคมป์ร้างของนักล่า"), obj(K_COLLECT, "hunter_journal", 1, text="นำสมุดของนักล่าไปให้อิงกริด", consume=False)],
         flag="read_hunter_journal",
         reward=dict(exp=2500)),

    dict(id="m11_king_poring", title="M11 ราชาวุ้นแห่งป่าสนธยา", giver="หัวหน้ากิลด์บียอร์น", lv=12, req=["m10_hunter_journal"],
         desc="ล่าคิงโพริงในป่าสนธยา แล้วเก็บของประหลาดที่มันกลืนไว้",
         offer="โพริงยักษ์อาละวาดในป่าสนธยา มอนแถวนั้นแตกตื่นหนีกันหมด กิลด์ตั้งค่าหัวไว้สูง... จัดการมัน แล้วดูว่าในตัวมันมีอะไร",
         progress="คิงโพริงอยู่ลึกสุดของป่าสนธยา ระวังลูกน้องมันด้วย",
         complete="เศษแก้วเรืองแสง...? ในตัวโพริงเนี่ยนะ... ข้าอยู่มาสี่สิบปีไม่เคยเห็นของแบบนี้ เก็บไว้ให้ดี แล้วอย่าเอาให้ใครเห็นพร่ำเพรื่อ",
         objs=[obj(K_KILL, "king_poring", 1), obj(K_COLLECT, "glow_shard", 1, text="เก็บของประหลาดจากคิงโพริง", consume=False)],
         reward=dict(zeny=2000, exp=4000)),

    dict(id="m12_shadow", title="M12 สิ่งที่หลบอยู่ในเงา", giver="นักบวชสูงสุดวาลเดอร์", lv=14, req=["m11_king_poring"],
         desc="วาลเดอร์ขอเศษแก้วเรืองแสงไปตรวจ และให้กวาดล้างสิ่งที่ซุ่มอยู่ในป่าเงาลึก",
         offer="ข้าได้ยินเรื่อง «ของประหลาด» ที่เจ้าเก็บได้... เอามาให้ข้าตรวจเถอะ เพื่อความปลอดภัยของเจ้าเอง และระหว่างนั้น ช่วยกวาดล้างพวกที่ซุ่มในเงาของป่าเงาลึกด้วย",
         progress="พวกฮอร์เน็ตซุ่มอยู่ตามเงาไม้ในป่าเงาลึก... และอย่าลืมเรื่องเศษแก้ว",
         complete="เศษแก้วนี้ข้าจะเก็บรักษาไว้เอง ...อย่ามองข้าแบบนั้น ทุกอย่างเพื่อความปลอดภัยของเมือง จงขอบคุณธอร์ที่เจ้ายังหายใจอยู่",
         objs=[obj(K_COLLECT, "glow_shard", 1, text="มอบเศษแก้วเรืองแสงให้วาลเดอร์"), obj(K_KILL, "hornet", 15, text="กวาดล้างสิ่งที่ซุ่มในป่าเงาลึก")],
         flag="thunder_scar_open",
         reward=dict(zeny=1000, exp=5000)),

    dict(id="m13_thunder_scar", title="M13 รอยสายฟ้า", giver="ทหารยามเอริค", lv=18, req=["m12_shadow"],
         desc="สายฟ้าฟาดซ้ำจุดเดิมกลางป่าเงาลึกทั้งที่ฟ้าเปิด — มีบางอย่างอยู่ที่นั่น",
         offer="เจ้าเห็นฟ้าแถวป่าลึกไหม สายฟ้าฟาดจุดเดิมซ้ำ ๆ ทั้งที่ไม่มีเมฆสักก้อน พวกเราเรียกที่นั่นว่า «รอยสายฟ้า» ...มีบางอย่างอยู่ตรงนั้น และมันไม่ใช่พรของธอร์แน่ ๆ จัดการมัน",
         progress="ทางเข้ารอยสายฟ้าอยู่กลางป่าเงาลึก ตรงที่แสงฟ้าแลบไม่หยุด",
         complete="เจ้าล้มมันได้จริง ๆ รึ... ว่าแต่ ซากมันสลายเป็นแสงทองแล้วไหลลงดินไปทางเหนืองั้นรึ? ...ทางเหนือน่ะ มีแต่ภูเขาของพวกคนแคระนี่นา",
         objs=[obj(K_VISIT, "thunder_scar", text="ไปที่รอยสายฟ้า"), obj(K_KILL, "stormscar", 1)],
         flag="chapter2_open",
         reward=dict(item=("white_potion", 5), zeny=5000, exp=12000)),

    # ---------- ★ บท 2 — สวาร์ทัลฟ์เฮม ★ ----------
    dict(id="c2_1_unwelcome_gate", title="C2-1 ประตูที่ไม่ต้อนรับ", giver="นายหน้าเฮลกา", lv=18, req_flag="chapter2_open",
         desc="ชาวนิดาเวลลิร์ไม่ต้อนรับคนแปลกหน้า ไปแนะนำตัวกับช่างเอกดวาลินและบรอกก์",
         offer="มนุษย์...? นานแล้วนะที่ไม่มีมนุษย์เดินผ่านประตูนั้นเข้ามา ถ้าอยากให้ใครในเมืองนี้คุยด้วย ไปให้ช่างเอกดวาลินกับบรอกก์เห็นหน้าก่อนเถอะ",
         progress="ดวาลินอยู่หน้าเตาตีเหล็ก ส่วนบรอกก์... แกไม่ค่อยอยากคุยกับใครหรอก",
         complete="อย่างน้อยเจ้าก็กล้าดี... เมืองนี้ไม่ต้อนรับใคร แต่ก็ไม่ไล่ใครเหมือนกัน อยู่ไปเถอะ แค่อย่าถามอะไรมากนัก",
         objs=[obj(K_TALK, "ช่างเอกดวาลิน"), obj(K_TALK, "บรอกก์")],
         flag="nidavellir_intro",
         reward=dict(zeny=800, exp=3000)),

    dict(id="c2_2_toll", title="C2-2 ค่าผ่านทาง", giver="นายหน้าเฮลกา", lv=19, req=["c2_1_unwelcome_gate"],
         desc="เฮลกาขอ «ค่าผ่านทาง» เป็นวัสดุจากทางเหล็ก ก่อนจะยอมขายของให้ราคาปกติ",
         offer="ในเมืองนี้ไม่มีอะไรฟรี อยากให้ข้าขายของราคาคนใน ก็เอาของจากทางเหล็กมาแลกสิ — เปลือกด้วงเหล็กกับก้อนดินอัดของพวกพิตแมน",
         progress="เปลือกเหล็กห้าชิ้น ดินอัดห้าก้อน จากพวกมอนบนทางเหล็กนั่นแหละ",
         complete="ฮึ... ใช้ได้นี่ ตกลงตามนั้น เจ้าซื้อของข้าราคาคนในได้แล้ว",
         objs=[obj(K_COLLECT, "steel_shell", 5), obj(K_COLLECT, "dirt_clump", 5)],
         reward=dict(item=("miner_helmet", 1), exp=3500)),

    dict(id="c2_3_forbidden_name", title="C2-3 ชื่อที่ห้ามเอ่ย", giver="ช่างตีเหล็กฮันส์", lv=20, req=["c2_2_toll"],
         desc="ฮันส์อยากรู้ข่าวอาจารย์เก่า «ซินดริ» แต่ไม่มีคนแคระคนไหนยอมพูดถึง",
         offer="ข้าตามเจ้ามาที่นี่เพราะอยากรู้ข่าวอาจารย์ซินดริ... แต่ข้าถามทีไร ทุกคนเปลี่ยนเรื่องทันที เจ้าเป็นคนนอก ลองถามแทนข้าที",
         progress="ลองถามเฮลกา ดวาลิน บรอกก์ กับหมอเฮดินดู... สังเกตสีหน้าพวกเขาด้วยล่ะ",
         complete="เห็นไหม... ไม่มีใครยอมเอ่ยชื่ออาจารย์เลยสักคน ทั้งที่เคยเป็นช่างเอกของเมืองนี้แท้ ๆ ...ความเงียบก็เป็นคำตอบชนิดหนึ่งนะเจ้าว่าไหม",
         objs=[obj(K_TALK, "นายหน้าเฮลกา", text="ถามเฮลกาเรื่องซินดริ"), obj(K_TALK, "ช่างเอกดวาลิน", text="ถามดวาลินเรื่องซินดริ"),
               obj(K_TALK, "บรอกก์", text="ถามบรอกก์เรื่องซินดริ"), obj(K_TALK, "หมอคนแคระเฮดิน", text="ถามหมอเฮดินเรื่องซินดริ")],
         flag="asked_about_sindri",
         reward=dict(exp=4000)),

    dict(id="c2_4_nameless_grave", title="C2-4 หลุมศพที่ไม่มีชื่อ", giver="ช่างตีเหล็กฮันส์", lv=21, req=["c2_3_forbidden_name"],
         desc="มีหลุมศพเก่าท้ายเมืองที่ชื่อบนป้ายถูกสกัดออก ไปดูให้เห็นกับตา",
         offer="บรอกก์เผลอพูดถึง «หลุมท้ายเมือง» แล้วก็หุบปากทันที... ไปดูหลุมศพนั้นให้ข้าที ข้าไม่กล้าไปเอง",
         progress="หลุมศพอยู่ท้ายเมืองนิดาเวลลิร์",
         complete="ชื่อบนป้ายถูกสกัดออก... เหมือนศิลาสลักที่บ้านเราเลย ใครกัน... ใครกันที่ไล่ลบชื่อคนตายไปทั่วทุกโลกแบบนี้",
         objs=[obj(K_READ, "sindri_grave", text="ตรวจดูหลุมศพท้ายเมือง")],
         reward=dict(exp=4500)),

    dict(id="c2_5_hall_of_silence", title="C2-5 ห้องโถงเงียบ", giver="ช่างเอกดวาลิน", lv=28, req=["c2_4_nameless_grave"],
         desc="เคลียร์ห้องโถงเงียบ — โรงหลอมเก่าที่ตอนนี้เหลือแต่ภูตกับผู้เฝ้ารูน",
         offer="ห้องโถงเงียบเคยเป็นโรงหลอมใหญ่ที่สุดใต้ภูเขา ตอนนี้เหลือแต่ภูตไร้เสียงกับ «ผู้เฝ้ารูน» ...เคลียร์ทางให้ข้าที ข้าอยากกลับไปเอาเครื่องมือของตระกูล",
         progress="ภูตไร้เสียงไม่มีเสียงฝีเท้า ฟังไม่ได้ ต้องใช้ตาดู... ส่วนผู้เฝ้ารูนอยู่ในสุด",
         complete="เจ้าล้มผู้เฝ้ารูนได้จริง ๆ รึ... งั้นที่เหลือในความมืดข้างล่างก็มีแค่ «มัน» แล้วสินะ",
         objs=[obj(K_VISIT, "hall_of_silence", text="ไปที่ห้องโถงเงียบ"), obj(K_KILL, "silent_wraith", 10), obj(K_KILL, "rune_watcher", 1)],
         reward=dict(zeny=3000, exp=8000)),

    dict(id="c2_6_to_cold_forge", title="C2-6 สู่เตาหลอมร้าง", giver="ช่างเอกดวาลิน", lv=31, req=["c2_5_hall_of_silence"],
         desc="บุกเข้าเตาหลอมร้าง ที่ที่คนแคระเลิกพูดถึงไปนานแล้ว",
         offer="เตาหลอมร้างคือที่ที่พวกเราเลิกเอ่ยถึง... ถ้าเจ้าจะลงไปจริง ๆ ระวังพวกโกเลม — มันยังทำงานตามคำสั่งสุดท้ายที่ได้รับ แม้คนสั่งจะไม่อยู่แล้วก็ตาม",
         progress="พวกโกเลมเตาหลอมช้าแต่หนักมาก อย่าให้มันต้อนมุม",
         complete="เจ้ากลับมาได้ทั้งตัว... ดีแล้ว ข้างในสุดมีอะไร เจ้าคงเห็นแล้วสินะ — ผู้พิทักษ์ตัวนั้นยังเฝ้าอยู่ใช่ไหม",
         objs=[obj(K_VISIT, "cold_forge", text="ไปที่เตาหลอมร้าง"), obj(K_KILL, "forge_golem", 5)],
         reward=dict(item=("dwarven_mail", 1), exp=9000)),

    dict(id="c2_7_forge_guardian", title="C2-7 ผู้พิทักษ์เตาหลอม", giver="ช่างเอกดวาลิน", lv=34, req=["c2_6_to_cold_forge"],
         desc="ล้มผู้พิทักษ์เตาหลอม เพื่อเปิดทางไปยังกำแพงด้านในสุด",
         offer="ผู้พิทักษ์เตาหลอมถูกสร้างมาเฝ้า «บางสิ่ง» บนกำแพงในสุด... ล้มมันซะ แล้วดูให้เห็นกับตาว่ามันเฝ้าอะไรไว้",
         progress="ผู้พิทักษ์อยู่ในสุดของเตาหลอมร้าง ระวังค้อนของมัน",
         complete="...เจ้าล้มมันได้จริง ๆ สี่สิบปีที่ไม่มีใครทำได้ ตอนนี้ไม่มีอะไรบังกำแพงด้านในแล้ว... ไปดูเถอะ",
         objs=[obj(K_KILL, "forge_guardian", 1)],
         reward=dict(zeny=8000, exp=15000)),

    dict(id="c2_8_hammer_truth", title="C2-8 ความจริงของค้อน", giver="บรอกก์", lv=34, req=["c2_7_forge_guardian"],
         desc="ดูแบบร่างบนกำแพงในสุดของเตาหลอมร้าง แล้วกลับมาคุยกับบรอกก์",
         offer="ถ้าเจ้าผ่านผู้พิทักษ์มาได้จริง... ไปดูกำแพงด้านในสุดของเตาหลอมร้าง แล้วกลับมาบอกข้า ว่าเจ้าเห็นอะไร",
         progress="แบบร่างอยู่บนกำแพงในสุดของเตาหลอมร้าง หลังจุดที่ผู้พิทักษ์เคยยืน",
         complete="...เจ้าเห็นแล้วสินะ วงจรรูนบนหัวค้อน — มันไม่ใช่รูนป้องกัน มันคือรูน «ดูด» ...ใช่ เราสร้างค้อนให้ธอร์จริง แต่ฟังให้ดีนะมนุษย์ — เราไม่เคยสร้างมันเพื่อปกป้องพวกเจ้า",
         objs=[obj(K_READ, "hammer_blueprint", text="ดูแบบร่างบนกำแพงเตาหลอมร้าง")],
         flag="chapter2_done",
         reward=dict(item=("forge_saber", 1), zeny=10000, exp=20000)),
]

# =========================================================
# 4) แก้ NPC ในแมพ — quest_ids + บทพูดตามธง (patch ด้วย regex ยึดชื่อ NPC)
# =========================================================
def set_npc_field(path, npc_name, field, value_line):
    """ใส่/แทนที่ฟิลด์ของโหนด NPC (ยึดจากบรรทัด npc_name) — รันซ้ำได้"""
    s = open(path, encoding="utf-8").read()
    anchor = 'npc_name = "%s"' % npc_name
    i = s.find(anchor)
    if i < 0:
        print("  ! ไม่เจอ NPC %s ใน %s" % (npc_name, path))
        return
    j = s.find("\n[", i)                      # จุดจบของโหนดนี้
    if j < 0:
        j = len(s)
    block = s[i:j]
    # ★ ค่าหลายบรรทัด (เช่น dialog_by_flag = { ... }) ต้องจับทั้งก้อนถึงวงเล็บปิด ★
    if value_line.startswith(field + " = {"):
        m = re.search(r"^%s = \{.*?^\}" % field, block, flags=re.M | re.S)
    else:
        m = re.search(r"^%s = .*$" % field, block, flags=re.M)
    if m:
        if m.group(0) == value_line:
            return
        new_block = block[:m.start()] + value_line + block[m.end():]
    else:
        new_block = block.replace(anchor, anchor + "\n" + value_line, 1)
    g.backup(path, "รอบ38")
    open(path, "w", encoding="utf-8").write(s[:i] + new_block + s[j:])
    LOG.append("แก้ %s — %s ของ %s" % (path, field, npc_name))

def qid_line(ids):
    return "quest_ids = Array[StringName]([%s])" % ", ".join('&"%s"' % q for q in ids)

# =========================================================
# 5) แทรกโหนดท้ายไฟล์แมพ (Marker / Portal / LoreObject)
# =========================================================
def append_nodes(path, marker, text, need_lore_ext=False):
    s = open(path, encoding="utf-8").read()
    if marker in s:
        return
    if need_lore_ext and "lore_object.tscn" not in s:
        lastext = list(re.finditer(r'^\[ext_resource [^\n]*\]$', s, flags=re.M))[-1]
        s = s[:lastext.end()] + '\n[ext_resource type="PackedScene" path="res://scenes/world/lore_object.tscn" id="lore38"]' + s[lastext.end():]
        n = len(re.findall(r"^\[(ext_resource|sub_resource) ", s, flags=re.M)) + 1
        s = re.sub(r"load_steps=\d+", "load_steps=%d" % n, s, count=1)
    if not s.endswith("\n"):
        s += "\n"
    s += "\n" + text.strip() + "\n"
    g.backup(path, "รอบ38")
    open(path, "w", encoding="utf-8").write(s)
    LOG.append("เพิ่มโหนดใน %s (%s)" % (path, marker))

# =========================================================
# 6) king_poring ดรอป glow_shard 100%
# =========================================================
def patch_king_poring_drop():
    path = "data/monsters/king_poring.tres"
    s = open(path, encoding="utf-8").read()
    if "glow_shard" in s:
        return
    sub = '[sub_resource type="Resource" id="Drop_kp_glow"]\nscript = ExtResource("2_drop")\nitem_id = &"glow_shard"\nchance = 100.0\n\n'
    s = s.replace("[resource]", sub + "[resource]", 1)
    s = re.sub(r"(drops = Array\[ExtResource\(\"2_drop\"\)\]\(\[[^\]]*)\]\)", r'\1, SubResource("Drop_kp_glow")])', s, count=1)
    n = len(re.findall(r"^\[(ext_resource|sub_resource) ", s, flags=re.M)) + 1
    s = re.sub(r"load_steps=\d+", "load_steps=%d" % n, s, count=1)
    g.backup(path, "รอบ38")
    open(path, "w", encoding="utf-8").write(s)
    LOG.append("แก้ %s — เพิ่มดรอป glow_shard 100%%" % path)

# =========================================================
def main():
    # ---- ไอเทมเควส ----
    for (iid, name, desc, code, color) in QUEST_ITEMS:
        write("data/items/%s.tres" % iid, quest_item(iid, name, desc, code, color))
    # ---- ของขยะบอสสายฟ้า ----
    for j in g.JUNK[-2:]:
        write("data/items/%s.tres" % j[0], g.junk_tres(j[0], j[1], j[2], j[3], j[4]))
    # ---- บอส stormscar ----
    write("data/monsters/stormscar.tres", g.monster_tres(STORMSCAR))
    write("data/sprites/placeholder/stormscar_frames.tres", g.frames_tres(STORMSCAR))
    g.monster_png(STORMSCAR)
    write("data/cards/card_stormscar.tres", g.card_tres(STORMSCAR))
    patch_king_poring_drop()

    # ---- แมพรอยสายฟ้า (บทที่ 1) ----
    ts = dict(id="thunder_scar", name="รอยสายฟ้า", w=2800, h=1100, ground_y=880,
              colors=("0.09, 0.09, 0.15", "0.14, 0.14, 0.22", "0.2, 0.19, 0.23"),
              spawns=[("default", 200), ("from_dark_forest", 200)],
              portals=[("ToDarkForest", 70, "dark_forest", "from_thunder_scar", "← ป่าเงาลึก", "ป่าเงาลึก")],
              mons=[], boss=["stormscar"], boss_x=2300,
              plats=[(1100, 700, 320), (1750, 620, 300)],
              lore=[dict(node="ScarCenter", x=2300, id="thunder_scar_center", title="รอยแผลบนผืนดิน",
                         text="ดินตรงนี้ไหม้เป็นแนวยาว เหมือนโดนสายฟ้าฟาดซ้ำ ๆ นับร้อยครั้ง\n\nตรงกลางรอยไหม้มีร่องเล็ก ๆ ...เหมือนมีบางอย่างไหลลงดินไปทางเหนือ",
                         label="รอยไหม้ประหลาด", flag="killed_stormscar",
                         locked="เสียงฟ้าคำรามดังจนเข้าใกล้ไม่ได้")])
    txt = g.map_tscn(ts)
    txt = txt.replace("chapter = 2", "chapter = 1").replace('region = "สวาร์ทัลฟ์เฮม"', 'region = "มิดการ์ด"')
    write("scenes/maps/thunder_scar.tscn", txt)

    # Game.MAPS (แก้ที่ /root/rbo แล้วส่งทั้งไฟล์ · บนเครื่องผู้ใช้ patch ตรง ๆ)
    patch("scripts/core/game.gd", [
        ('	&"cold_forge": "res://scenes/maps/cold_forge.tscn",\n}',
         '	&"cold_forge": "res://scenes/maps/cold_forge.tscn",\n'
         '	## ★ ลานบอสบทที่ 1 (รอบ 38) ★\n'
         '	&"thunder_scar": "res://scenes/maps/thunder_scar.tscn",\n}'),
    ], "รอบ38")

    # ประตูป่าเงาลึก -> รอยสายฟ้า + จุดเกิดขากลับ
    append_nodes("scenes/maps/dark_forest.tscn", 'name="from_thunder_scar"',
                 '[node name="from_thunder_scar" type="Marker2D" parent="SpawnPoints"]\nposition = Vector2(2350, 560)')
    append_nodes("scenes/maps/dark_forest.tscn", 'name="ToThunderScar"',
                 '[node name="ToThunderScar" parent="Portals" instance=ExtResource("portal")]\n'
                 'position = Vector2(2350, 640)\ntarget_map = &"thunder_scar"\ntarget_spawn_point = &"from_dark_forest"\n'
                 'label_text = "⚡ รอยสายฟ้า"\ndestination_name = "รอยสายฟ้า"\n'
                 'required_flag = &"thunder_scar_open"\nlocked_text = "ลึกเข้าไปมีเสียงฟ้าคำรามไม่หยุด... ยังไม่มีเหตุให้เข้าไปตอนนี้"')

    # LoreObject 3 จุด (ป่าสนธยา 2 · ป่าเงาลึก 1)
    append_nodes("scenes/maps/asgard_forest_2.tscn", 'lore_id = &"dead_monster"',
                 '[node name="Lore38" type="Node2D" parent="."]\n\n'
                 '[node name="DeadMonster" parent="Lore38" instance=ExtResource("lore38")]\n'
                 'position = Vector2(1500, 570)\nlore_id = &"dead_monster"\ntitle = "ซากมอนสเตอร์"\n'
                 'text = "ซากชอนชอนนอนแน่นิ่งอยู่หลายตัว\\n\\nไม่มีบาดแผลเลยสักแห่ง...\\n\\nราวกับชีวิตถูกดูดออกไปเฉย ๆ"\n'
                 'label_text = "ซากมอนสเตอร์"\nprompt_text = "กด F เพื่อตรวจดู"\n\n'
                 '[node name="BurntBark" parent="Lore38" instance=ExtResource("lore38")]\n'
                 'position = Vector2(2450, 570)\nlore_id = &"burnt_bark"\ntitle = "ต้นไม้ไหม้เกรียม"\n'
                 'text = "เปลือกไม้มีรอยไหม้เป็นเส้นตรงหลายเส้น\\n\\nไม่ใช่รอยไฟป่า... เส้นพวกนี้เป็นระเบียบเกินไป\\n\\n(ได้รับ เศษเปลือกไม้ไหม้)"\n'
                 'give_item = &"burnt_bark_piece"\nlabel_text = "ต้นไม้ไหม้"\nprompt_text = "กด F เพื่อตรวจดู"',
                 need_lore_ext=True)
    append_nodes("scenes/maps/dark_forest.tscn", 'lore_id = &"hunter_camp"',
                 '[node name="Lore38" type="Node2D" parent="."]\n\n'
                 '[node name="HunterCamp" parent="Lore38" instance=ExtResource("lore38")]\n'
                 'position = Vector2(3100, 620)\nlore_id = &"hunter_camp"\ntitle = "แคมป์ร้าง"\n'
                 'text = "กองไฟดับไปนานแล้ว ข้าวของกระจัดกระจาย\\n\\nใต้ผ้าห่มมีสมุดบันทึกเล่มหนึ่ง หน้าสุดท้ายลายมือสั่น ๆ:\\n\\n«พวกมันไม่ได้ล่า พวกมันหนี»\\n\\n(ได้รับ สมุดของนักล่า)"\n'
                 'give_item = &"hunter_journal"\nlabel_text = "แคมป์ร้าง"\nprompt_text = "กด F เพื่อตรวจดู"',
                 need_lore_ext=True)

    # ---- เควสทั้งหมด ----
    for q in QUESTS:
        write("data/quests/%s.tres" % q["id"], quest_tres(q))
    # M3/M4 เดิม: ต่อสายเนื้อเรื่อง (เติม required_quests)
    patch("data/quests/hans_poring.tres",
          [("required_level = 1", "required_level = 1\nrequired_quests = Array[StringName]([&\"m2_oath\"])")],
          "รอบ38", markers=("required_quests",))
    patch("data/quests/tony_fabre.tres",
          [("required_level = 1", "required_level = 1\nrequired_quests = Array[StringName]([&\"hans_poring\"])")],
          "รอบ38", markers=("required_quests",))

    # ---- ผูก quest_ids ให้ NPC ----
    town = "scenes/maps/prontera_town.tscn"
    set_npc_field(town, "ทหารยามเอริค", "quest_ids", qid_line(["m1_adventurer_badge", "m7_silent_forest", "m13_thunder_scar"]))
    set_npc_field(town, "นักบวชสูงสุดวาลเดอร์", "quest_ids", qid_line(["m2_oath", "m6_ceremony", "m8_burnt_bark", "m12_shadow"]))
    set_npc_field(town, "ช่างตีเหล็กฮันส์", "quest_ids", qid_line(["hans_poring", "m5_old_mine_iron"]))
    set_npc_field(town, "อิงกริด", "quest_ids", qid_line(["m9_missing_hunter", "m10_hunter_journal"]))
    set_npc_field(town, "หัวหน้ากิลด์บียอร์น", "quest_ids", qid_line(["m11_king_poring"]))
    nida = "scenes/maps/nidavellir_town.tscn"
    set_npc_field(nida, "นายหน้าเฮลกา", "quest_ids", qid_line(["c2_1_unwelcome_gate", "c2_2_toll"]))
    set_npc_field(nida, "ช่างตีเหล็กฮันส์", "quest_ids", qid_line(["c2_3_forbidden_name", "c2_4_nameless_grave"]))
    set_npc_field(nida, "ช่างเอกดวาลิน", "quest_ids", qid_line(["c2_5_hall_of_silence", "c2_6_to_cold_forge", "c2_7_forge_guardian"]))
    set_npc_field(nida, "บรอกก์", "quest_ids", qid_line(["c2_8_hammer_truth"]))

    # ---- บทพูดตามธง (กุนนาร์เปลี่ยนตามเนื้อเรื่อง 4 ช่วง · วาลเดอร์หลังยึดเศษแก้ว) ----
    set_npc_field(town, "ตาแก่กุนนาร์", "dialog_by_flag",
        'dialog_by_flag = {\n'
        '"saw_ceremony": "เมื่อคืนเจ้าก็อยู่ในพิธีสินะ...\\n\\nถ้าธอร์ปกป้องพวกเราจริง แล้วเหตุใดทุกครั้งที่สายฟ้าฟาด\\n\\nป่าจึงเงียบลง เหมือนมีบางสิ่งตายไป",\n'
        '"read_hunter_journal": "«พวกมันไม่ได้ล่า พวกมันหนี» งั้นรึ...\\n\\nสัตว์น่ะ มันรู้ก่อนคนเสมอแหละ ว่าอะไรกำลังมา",\n'
        '"killed_stormscar": "เจ้าเห็นกับตาแล้วใช่ไหม... แสงที่ไหลลงดินน่ะ\\n\\nสายฟ้าไม่เคยให้อะไรใครฟรี ๆ หรอกหนุ่มน้อย\\n\\nมันมาเก็บของมันต่างหาก",\n'
        '"chapter2_done": "กลับมาจากใต้ภูเขาแล้วสินะ\\n\\nตอนนี้เจ้าก็รู้แล้วว่าค้อนเล่มนั้นตีขึ้นมาเพื่ออะไร\\n\\n...ระวังตัวให้มาก อย่าให้ใครรู้ว่าเจ้ารู้"\n'
        '}')
    set_npc_field(town, "นักบวชสูงสุดวาลเดอร์", "dialog_by_flag",
        'dialog_by_flag = {\n'
        '"thunder_scar_open": "เศษแก้วอยู่ในที่ที่ปลอดภัยแล้ว เจ้าไม่ต้องถามถึงมันอีก\\n\\nจงขอบคุณธอร์ แล้วทำหน้าที่ของเจ้าต่อไป"\n'
        '}')

    g.make_icons()
    print()
    if LOG:
        print("ทำไปทั้งหมด %d รายการ:" % len(LOG))
        for l in LOG:
            print("  ·", l)
    else:
        print("ทุกอย่างมีครบแล้ว")
    print("★ เปิด Godot ใหม่ (ปิดแท็บแมพโดยไม่บันทึกก่อน) แล้วกด F5 ★")

if __name__ == "__main__":
    main()
