# -*- coding: utf-8 -*-
"""ส่วนต่อของ dump_gamedata.py (รอบ 46) — NPC ทุกคน + รายการ "งานภาพที่ยังไม่ทำ" (assets TODO)
ถูก exec จาก dump_gamedata.py ก่อนเขียน gamedata.json · ใช้ตัวแปร items/monsters/skills/maps/quests/read/sub_resources ที่มีอยู่แล้ว
"""
import os, re, glob

# ---------- รายชื่อไฟล์ภาพจริงบนเครื่องผู้ใช้ (ถ้ามี _sprites_list.txt) ----------
SPRITE_FILES = set()
SPRITE_SIZES = {}      # path -> bytes
if os.path.exists("_sprites_list.txt"):          # ฝั่ง Claude: รายชื่อไฟล์ที่ดึงมาจากเครื่องผู้ใช้
    for line in open("_sprites_list.txt", encoding="utf-8"):
        parts = line.rstrip("\n").split("\t")
        p = parts[0].strip()
        if p:
            SPRITE_FILES.add(p)
            if len(parts) == 2 and parts[1].isdigit():
                SPRITE_SIZES[p] = int(parts[1])
elif os.path.isdir("Sprites"):                   # ฝั่งเครื่องผู้ใช้: เดินโฟลเดอร์จริง
    for root_, _dirs, files_ in os.walk("Sprites"):
        for f_ in files_:
            fp = os.path.join(root_, f_).replace("\\", "/")
            SPRITE_FILES.add(fp)
            try:
                SPRITE_SIZES[fp] = os.path.getsize(fp)
            except OSError:
                pass
def file_exists(res_path):
    p = res_path.replace("res://", "")
    if SPRITE_FILES:
        return p in SPRITE_FILES or os.path.exists(p)
    return os.path.exists(p)
def is_placeholder(path):
    p = str(path).lower()
    return "placeholder" in p or "/generated/" in p

# ---------- ตัวช่วยอ่าน ext_resource ----------
def ext_map(text):
    return dict(re.findall(r'\[ext_resource type="[^"]+"[^\]]*path="([^"]+)" id="([^"]+)"\]', text))
def ext_path(text, ref):
    m = re.search(r'ExtResource\("([^"]+)"\)', str(ref))
    if not m:
        return ""
    for path, eid in ext_map(text).items():
        if eid == m.group(1):
            return path
    return ""
def anim_names(text):
    return sorted(set(re.findall(r'"name":\s*&"([^"]+)"', text)))
def anim_frame_counts(text):
    """{ชื่อท่า: จำนวนเฟรม} จากข้อความ SpriteFrames"""
    out = {}
    for blk in re.split(r'\}, \{\n"frames"', text):
        nm = re.search(r'"name":\s*&"([^"]+)"', blk)
        if nm:
            out[nm.group(1)] = blk.count('"texture"')
    return out
def frames_info(text, ref):
    """ref = ค่าช่อง sprite_frames → (paths ของภาพที่ใช้, ชื่อท่า, เป็น placeholder ไหม)"""
    s = str(ref)
    if "ExtResource" in s:
        fp = ext_path(text, s)
        if fp and os.path.exists(fp.replace("res://", "")):
            ft = read(fp.replace("res://", ""))
            paths = list(ext_map(ft).keys())
            return paths, anim_names(ft), is_placeholder(fp) or any(is_placeholder(x) for x in paths)
        return [fp], [], is_placeholder(fp)
    # SubResource ในไฟล์เดียวกัน
    paths = [p for p in ext_map(text).keys() if re.search(r"\.(png|jpg|jpeg|webp)$", p, re.I)]
    return paths, anim_names(text), any(is_placeholder(x) for x in paths)

# =========================================================
# NPC ทุกคน (จากทุกแมพ)
# =========================================================
NPC_TYPE_NAMES = ["คุย", "ร้านค้า", "ช่างตีบวก", "หมอ", "จุดเซฟ", "เควส"]
npc_rows = []
for p in sorted(glob.glob("scenes/maps/*.tscn")):
    if ".bak" in p:
        continue
    t = read(p)
    exts = ext_map(t)
    subs = sub_resources(t)
    blocks = re.split(r"\n(?=\[node )", t)
    root_props = {}
    node_props = {}
    order = []
    for b in blocks:
        m = re.match(r'\[node name="([^"]+)"(?: type="([^"]+)")?(?: parent="([^"]+)")?[^\]]*\]', b)
        if not m:
            continue
        body = []
        for line in b.split("\n")[1:]:
            if line.startswith("["):
                break
            body.append(line)
        key = (m.group(3) or "", m.group(1))
        node_props[key] = (m.group(2) or "", props_from_lines(body), b)
        order.append(key)
        if not root_props:
            root_props = props_from_lines(body)
    map_id = root_props.get("map_id", os.path.basename(p).replace(".tscn", ""))
    map_name = root_props.get("display_name", map_id)
    for (parent, name) in order:
        if parent != "NPCs":
            continue
        ntype, props, raw = node_props[(parent, name)]
        # sprite ลูก
        sprite_paths, anims, placeholder = [], [], False
        frame_counts = {}
        has_sprite = False
        for (p2, n2) in order:
            if p2 != "NPCs/" + name:
                continue
            t2, pr2, raw2 = node_props[(p2, n2)]
            if t2 == "AnimatedSprite2D" and pr2.get("sprite_frames"):
                sid = re.search(r'SubResource\("([^"]+)"\)', str(pr2.get("sprite_frames")))
                if sid:
                    # หาชื่อท่า + ภาพจาก sub_resource ของ SpriteFrames นี้
                    sf_txt = re.search(r'\[sub_resource type="SpriteFrames" id="%s"\]\n(.*?)(?=\n\[|\Z)' % re.escape(sid.group(1)), t, re.S)
                    if sf_txt:
                        anims = anim_names(sf_txt.group(1))
                        frame_counts = anim_frame_counts(sf_txt.group(1))
                        atlas_ids = set(re.findall(r'SubResource\("([^"]+)"\)', sf_txt.group(1)))
                        for aid in atlas_ids:
                            at = subs.get(aid, {})
                            fp = ext_path(t, at.get("atlas", ""))
                            if fp:
                                sprite_paths.append(fp)
                        if not sprite_paths:
                            # เฟรมอ้าง ExtResource ตรง ๆ
                            for eid in re.findall(r'ExtResource\("([^"]+)"\)', sf_txt.group(1)):
                                for path, e in exts.items():
                                    if e == eid:
                                        sprite_paths.append(path)
                    has_sprite = bool(sprite_paths)
                else:
                    fp = ext_path(t, pr2.get("sprite_frames"))
                    if fp:
                        sprite_paths.append(fp); has_sprite = True
            elif t2 == "Sprite2D" and pr2.get("texture"):
                fp = ext_path(t, pr2.get("texture"))
                if fp:
                    sprite_paths.append(fp); has_sprite = True
        sprite_paths = sorted(set(sprite_paths))
        placeholder = any(is_placeholder(x) for x in sprite_paths)
        portrait = ext_path(t, props.get("portrait", "")) or props.get("portrait_file", "") or ""
        dialog = str(props.get("dialog", "")).strip()
        first_line = dialog.split("\n")[0][:80]
        by_flag = re.findall(r'^"([^"]+)":', str(props.get("dialog_by_flag", "")), re.M)
        shop = re.findall(r'&"([^"]+)"', str(props.get("shop_items", "")))
        qs = re.findall(r'&"([^"]+)"', str(props.get("quest_ids", "")))
        tidx = int(props.get("type", 0) or 0)
        npc_rows.append({
            "node": name, "name": props.get("npc_name", name), "map": map_id, "mapName": map_name,
            "x": (props.get("position") or (0, 0))[0], "y": (props.get("position") or (0, 0))[1],
            "type": NPC_TYPE_NAMES[tidx] if tidx < len(NPC_TYPE_NAMES) else str(tidx), "typeIdx": tidx,
            "hasShop": tidx == 1 or bool(props.get("has_shop")), "shop": shop, "quests": qs,
            "greeting": props.get("greeting", ""), "dialog": first_line, "dialogPages": dialog.count("\n\n") + 1 if dialog else 0,
            "byFlag": by_flag, "healPrice": props.get("heal_price", 100) if tidx == 3 else None,
            "portrait": portrait, "portraitOk": bool(portrait) and file_exists(portrait),
            "sprites": sprite_paths, "anims": anims, "frames": frame_counts,
            "hasSprite": has_sprite, "spritePlaceholder": placeholder,
        })

# =========================================================
# งานภาพที่ยังไม่ทำ (assets TODO)
# =========================================================
MON_ANIMS = ["Idle", "Run", "Attack", "Hit", "Die"]
todo_monsters = []
for mid, m in monsters.items():
    t = read(m["_file"])
    paths, anims, ph = frames_info(t, m.get("sprite_frames", ""))
    missing = [a for a in MON_ANIMS if a not in anims] if anims else MON_ANIMS[:]
    if m.get("skill_anim") and m["skill_anim"] not in anims:
        missing.append(str(m["skill_anim"]) + " (สกิล)")
    need_fx = bool(m.get("skill_name")) and not m.get("skill_effect_frames")
    need_video = bool(m.get("is_boss")) and not m.get("intro_video")
    if ph or not anims or missing or need_fx or need_video:
        todo_monsters.append({"id": mid, "name": m.get("display_name", mid), "lv": m.get("level", 1),
                              "boss": bool(m.get("is_boss")), "placeholder": ph or not anims,
                              "missingAnims": missing, "needSkillFx": need_fx, "needVideo": need_video,
                              "files": [x.replace("res://", "") for x in paths][:3]})

todo_items = []
for iid, d in items.items():
    t = read(d["_file"])
    ip = ext_path(t, d.get("icon", ""))
    if not ip or is_placeholder(ip) or not file_exists(ip):
        todo_items.append({"id": iid, "name": d.get("display_name", iid), "type": enum_name(ITEM_TYPE, d.get("type", 3)),
                           "reason": "ไม่มีไอคอน" if not ip else ("ไฟล์หาย" if not file_exists(ip) else "ยังเป็น placeholder"),
                           "file": ip.replace("res://", "")})
    # ★ ของสวมใส่ที่ยังไม่มีภาพตอนใส่ (paper doll) — ตอนนี้ยังไม่มีชิ้นไหนเลย จึงไม่นับเป็น TODO บังคับ

todo_maps = []
for mid, mp in maps.items():
    bgs = [b[1] for b in mp["bg"] if b[1]]
    if not bgs:
        # แมพที่วางฉากหลังเป็น Sprite2D ใต้ Terrain (เช่นทุ่งวิหาร) — นับเป็นฉากหลังจริง
        mt = read(mp["file"])
        for blk in re.split(r"\n(?=\[node )", mt):
            if 'type="Sprite2D"' in blk and 'parent="Terrain"' in blk:
                m2 = re.search(r'texture = (ExtResource\("[^"]+"\))', blk)
                if m2:
                    fp = ext_path(mt, m2.group(1))
                    if fp:
                        bgs.append(fp)
    if not bgs or all(is_placeholder(b) for b in bgs):
        todo_maps.append({"id": mid, "name": mp["display_name"], "chapter": mp["chapter"],
                          "reason": "ไม่มีฉากหลัง" if not bgs else "ฉากหลังชั่วคราว (generated)",
                          "files": bgs, "size": list(mp["bounds"][2:4]) if mp["bounds"] else None})

todo_npcs = []
for n in npc_rows:
    reasons = []
    if not n["hasSprite"]:
        reasons.append("ไม่มีสไปรท์")
    elif n["spritePlaceholder"]:
        reasons.append("สไปรท์ชั่วคราว")
    elif n["frames"] and max(n["frames"].values()) <= 1:
        reasons.append("ภาพนิ่ง (ยังไม่มีท่า Idle หลายเฟรม)")
    if n["typeIdx"] != 4 and not n["portraitOk"]:
        reasons.append("ไม่มีรูปคุย" if not n["portrait"] else "ไฟล์รูปคุยหาย")
    if reasons:
        todo_npcs.append({"name": n["name"], "map": n["mapName"], "reasons": reasons, "sprites": n["sprites"]})

todo_skills = []
for sid, s in skills.items():
    t = read(s["_file"])
    reasons = []
    ip = ext_path(t, s.get("icon", ""))
    if not ip or not file_exists(ip):
        reasons.append("ไม่มีไอคอน")
    stype = int(s.get("type", 0) or 0)
    if stype in (0, 1, 5) and not s.get("effect_frames"):   # โจมตีตรงหน้า / รอบตัว / พุ่งฟัน (ดู SKILL_TYPE)
        reasons.append("ไม่มีเอฟเฟกต์")
    if reasons:
        todo_skills.append({"id": sid, "name": s.get("display_name", sid), "type": enum_name(SKILL_TYPE, stype), "reasons": reasons})

# ท่าผู้เล่นที่ควรมี: Attack_<อาวุธ>_<สกิล> สำหรับสกิลที่ใช้ท่าตี
player_anims = []
pf = "data/sprites/player_frames.tres"
if os.path.exists(pf):
    player_anims = anim_names(read(pf))
weapon_anims = sorted(a for a in player_anims if a.startswith("Attack_") and a.count("_") == 1)
active_skill_ids = [sid for sid, s in skills.items() if int(s.get("type", 0) or 0) in (0, 1, 5) and not s.get("animation")]
todo_player = []
for wa in weapon_anims:
    for sid in active_skill_ids:
        want = "%s_%s" % (wa, sid)
        if want not in player_anims:
            todo_player.append({"anim": want, "weapon": wa, "skill": skills[sid].get("display_name", sid)})
for base in ["Idle", "Run", "Attack", "Hit", "Die", "Dash"]:
    if base not in player_anims:
        todo_player.append({"anim": base, "weapon": "-", "skill": "ท่าพื้นฐาน"})

UI_ICONS = ["status", "inventory", "equipment", "skills", "quests", "cards", "system", "map"]
todo_ui = [{"file": "Sprites/ui_icons/%s.png" % k, "what": "ไอคอนปุ่ม " + k}
           for k in UI_ICONS if not file_exists("Sprites/ui_icons/%s.png" % k)]

todo_videos = [{"id": mid, "name": m.get("display_name", mid)} for mid, m in monsters.items()
               if m.get("is_boss") and not m.get("intro_video")]

# ไฟล์ภาพใหญ่เกินจำเป็น (ไอคอน UI/ไอเทมโชว์แค่ ~48 px แต่ไฟล์ > 1 MB)
todo_big = []
for pth, size in SPRITE_SIZES.items():
    if (pth.startswith("Sprites/ui_icons/") or pth.startswith("Sprites/items/")) and size > 600_000:
        todo_big.append({"file": pth, "mb": round(size / 1048576, 1), "hint": "ย่อเหลือ 256 px (โชว์แค่ ~48 px)"})
    elif pth.startswith("Sprites/portraits/") and size > 2_000_000:
        todo_big.append({"file": pth, "mb": round(size / 1048576, 1), "hint": "ย่อสูง ≤ 600 px"})
todo_big.sort(key=lambda x: -x["mb"])

assets_json = {
    "monsters": sorted(todo_monsters, key=lambda x: x["lv"]),
    "items": todo_items, "maps": todo_maps, "npcs": todo_npcs, "skills": todo_skills,
    "player": todo_player, "ui": todo_ui, "videos": todo_videos, "big": todo_big,
    "counts": {
        "monsters": len(todo_monsters), "items": len(todo_items), "maps": len(todo_maps), "npcs": len(todo_npcs),
        "skills": len(todo_skills), "player": len(todo_player), "ui": len(todo_ui), "videos": len(todo_videos), "big": len(todo_big),
    },
    "totals": {"monsters": len(monsters), "items": len(items), "maps": len(maps), "npcs": len(npc_rows),
               "skills": len(skills)},
}
data_json["npcs"] = npc_rows
data_json["assets"] = assets_json
print("NPC %d คน · งานภาพค้าง: มอน %d · ไอเทม %d · แมพ %d · NPC %d · สกิล %d · ท่าผู้เล่น %d · UI %d · วิดีโอ %d" % (
    len(npc_rows), len(todo_monsters), len(todo_items), len(todo_maps), len(todo_npcs), len(todo_skills),
    len(todo_player), len(todo_ui), len(todo_videos)))
