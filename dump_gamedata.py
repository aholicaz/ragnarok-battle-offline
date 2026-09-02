# -*- coding: utf-8 -*-
## ★ อ่านข้อมูลเกมทั้งหมดจาก .tres/.tscn แล้วเขียนเป็นเอกสารอ้างอิง (รอบ 42) ★
## ใช้: python3 dump_gamedata.py   → เขียน ข้อมูลเกมทั้งหมด.md
## รันซ้ำได้ ไม่แก้ไฟล์เกม (อ่านอย่างเดียว)
import os, re, glob, json, collections

os.chdir(os.path.dirname(os.path.abspath(__file__)))

# =========================================================
# ตัวอ่าน .tres / .tscn
# =========================================================
def read(path):
    return open(path, encoding="utf-8").read()

def parse_val(v):
    v = v.strip()
    if v.startswith('"') and v.endswith('"'):
        return v[1:-1]
    if v.startswith('&"'):
        return v[2:-1]
    if v in ("true", "false"):
        return v == "true"
    m = re.match(r"^Vector2\(([-\d.]+),\s*([-\d.]+)\)$", v)
    if m:
        return (float(m.group(1)), float(m.group(2)))
    m = re.match(r"^Rect2\(([-\d.]+),\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+)\)$", v)
    if m:
        return tuple(float(m.group(i)) for i in range(1, 5))
    try:
        return int(v)
    except ValueError:
        pass
    try:
        return float(v)
    except ValueError:
        pass
    return v

def props_from_lines(lines):
    """อ่านคู่ key = value · ★ ค่าแบบหลายบรรทัด ({...} / [...]) ต้องรวมจนวงเล็บครบ ★
    (required_skills / percent_effects / drops เขียนคร่อมหลายบรรทัดเสมอ)"""
    out = {}
    i = 0
    while i < len(lines):
        m = re.match(r"^([a-z_0-9]+) = (.*)$", lines[i])
        if not m:
            i += 1
            continue
        key, val = m.group(1), m.group(2)
        depth = val.count("{") + val.count("[") + val.count("(") \
                - val.count("}") - val.count("]") - val.count(")")
        while depth > 0 and i + 1 < len(lines):
            i += 1
            val += "\n" + lines[i]
            depth += lines[i].count("{") + lines[i].count("[") + lines[i].count("(") \
                     - lines[i].count("}") - lines[i].count("]") - lines[i].count(")")
        out[key] = parse_val(val)
        i += 1
    return out


def resource_props(text):
    """คืน dict ของบล็อก [resource] (บล็อกสุดท้ายของไฟล์ .tres)"""
    i = text.rfind("\n[resource]")
    if i < 0:
        return {}
    return props_from_lines(text[i + len("\n[resource]"):].split("\n"))

def sub_resources(text, type_name=None):
    """คืน dict: sub id -> props"""
    out = {}
    blocks = re.split(r"\n(?=\[)", text)
    for b in blocks:
        m = re.match(r'\[sub_resource type="([^"]+)" id="([^"]+)"\]', b)
        if not m:
            continue
        if type_name and m.group(1) != type_name:
            continue
        out[m.group(2)] = props_from_lines(b.split("\n")[1:])
    return out

# ---- enum ----
ITEM_TYPE = ["ของกิน", "อาวุธ", "ของสวมใส่", "วัตถุดิบ", "ของเควส", "การ์ด"]
ITEM_SLOT = ["—", "อาวุธ", "มือรอง/โล่", "ศีรษะ", "ชุดเกราะ", "ผ้าคลุม", "รองเท้า", "เครื่องประดับ"]
ELEMENT = ["ไร้ธาตุ", "ไฟ", "น้ำ", "ดิน", "ลม", "พิษ", "ศักดิ์สิทธิ์", "มืด", "วิญญาณ", "อันเดด"]
RACE = ["ไร้รูปร่าง", "อันเดด", "สัตว์ป่า", "พืช", "แมลง", "ปลา", "ปีศาจ", "กึ่งมนุษย์", "เทวดา", "มังกร"]
SIZE = ["เล็ก", "กลาง", "ใหญ่"]
AI = ["PASSIVE (ตีก่อนถึงสู้)", "AGGRESSIVE (เห็นแล้วไล่)", "STATIONARY (ยืนอยู่กับที่)"]
SKILL_TYPE = ["โจมตีตรงหน้า", "โจมตีรอบตัว", "บัฟ", "ฟื้นเลือด", "พาสซีฟ", "พุ่งฟัน"]

def job_exp_of(m):
    """Job EXP ที่ได้จริง — ตั้ง 0 ไว้ = ระบบคิดให้ 70% ของ EXP"""
    v = m.get("job_exp_reward", 0)
    if v and int(v) > 0:
        return int(v), False
    return max(1, int(round(m.get("exp_reward", 0) * 0.7))), True


def enum_name(table, v, default="—"):
    try:
        return table[int(v)]
    except Exception:
        return default


# =========================================================
# ★ ค่า default ของแต่ละ Resource ★ อ่านจาก @export ในสคริปต์จริง
# ไฟล์ .tres จะไม่เก็บช่องที่ยังเป็นค่า default ไว้ — ถ้าไม่เติมให้ ตารางจะโชว์ 0 ผิด ๆ
# =========================================================
def script_defaults(path):
    out = {}
    if not os.path.exists(path):
        return out
    src = read(path)
    # เก็บ enum ทั้งหมดในสคริปต์: ชื่อ enum -> {ชื่อสมาชิก: ดัชนี}
    enums = {}
    for em in re.finditer(r"enum\s+([A-Za-z0-9_]+)\s*\{([^}]*)\}", src, re.S):
        names = [x.strip().split("=")[0].strip() for x in em.group(2).split(",")]
        names = [re.sub(r"##.*", "", n).strip() for n in names]
        enums[em.group(1)] = {n: i for i, n in enumerate([x for x in names if x])}
    for line in src.split("\n"):
        m = re.match(r"^@export(?:_[a-z_]+(?:\([^)]*\))?)? var ([a-z_0-9]+)(?::\s*[A-Za-z0-9_.\[\]]+)?\s*=\s*(.+?)(?::)?$", line.strip())
        if not m:
            continue
        v = m.group(2).strip()
        if v.endswith(":"):
            v = v[:-1].strip()
        val = parse_val(v)
        # ★ ค่า default ที่เป็น enum (เช่น Element.WATER / AIType.PASSIVE) ★ แปลงเป็นเลขดัชนี
        if isinstance(val, str):
            mm = re.match(r"^(?:[A-Za-z0-9_]+\.)?([A-Za-z0-9_]+)\.([A-Z0-9_]+)$", val)
            if mm and mm.group(1) in enums:
                val = enums[mm.group(1)].get(mm.group(2), 0)
            elif val.startswith("["):
                val = ""
        out[m.group(1)] = val
    return out

DEF_ITEM = script_defaults("scripts/resources/item_data.gd")
DEF_MON = script_defaults("scripts/resources/monster_data.gd")
DEF_SKILL = script_defaults("scripts/resources/skill_data.gd")
DEF_QUEST = script_defaults("scripts/resources/quest_data.gd")
DEF_PORTAL = script_defaults("scripts/world/portal.gd")
DEF_NPC = script_defaults("scripts/world/npc.gd")
DEF_SPAWNER = script_defaults("scripts/world/map_spawner.gd")

def with_defaults(d, defaults):
    out = dict(defaults)
    out.update(d)
    return out

# =========================================================
# 1) ไอเทม + การ์ด
# =========================================================
items = {}
for p in sorted(glob.glob("data/items/*.tres")) + sorted(glob.glob("data/cards/*.tres")):
    if ".bak" in p:
        continue
    t = read(p)
    d = resource_props(t)
    iid = d.get("id") or os.path.basename(p).replace(".tres", "")
    d.setdefault("id", iid)
    d["_file"] = p
    d["_is_card"] = "card_data.gd" in t
    items[iid] = with_defaults(d, DEF_ITEM)

# =========================================================
# 2) มอนสเตอร์ (+ ตารางดรอป)
# =========================================================
monsters = {}
for p in sorted(glob.glob("data/monsters/*.tres")):
    if ".bak" in p:
        continue
    t = read(p)
    d = resource_props(t)
    # ★ poring.tres ไม่มีบรรทัด id (ค่า default ของ MonsterData คือ &"poring") → ใช้ชื่อไฟล์
    mid = d.get("id") or os.path.basename(p).replace(".tres", "")
    d.setdefault("id", mid)
    subs = sub_resources(t)
    drops = []
    arr = d.get("drops", "")
    for sid in re.findall(r'SubResource\("([^"]+)"\)', str(arr)):
        s = subs.get(sid, {})
        if "item_id" in s:
            drops.append({
                "item": s.get("item_id"),
                "chance": float(s.get("chance", 10.0)),
                "min": int(s.get("min_count", 1)),
                "max": int(s.get("max_count", s.get("min_count", 1))),
            })
    d["_drops"] = drops
    d["_file"] = p
    monsters[mid] = with_defaults(d, DEF_MON)

# =========================================================
# 3) สกิลผู้เล่น
# =========================================================
skills = {}
for p in sorted(glob.glob("data/skills/*.tres")):
    if ".bak" in p:
        continue
    d = resource_props(read(p))
    sid = d.get("id") or os.path.basename(p).replace(".tres", "")
    d["_file"] = p
    skills[sid] = with_defaults(d, DEF_SKILL)

# =========================================================
# 4) เควส
# =========================================================
KIND = ["ล่ามอน", "หาไอเทม", "คุยกับ NPC", "ไปให้ถึงแมพ", "ตรวจของในแมพ", "ธงเนื้อเรื่อง"]
quests = {}
for p in sorted(glob.glob("data/quests/*.tres")):
    if ".bak" in p:
        continue
    t = read(p)
    d = resource_props(t)
    qid = d.get("id") or os.path.basename(p).replace(".tres", "")
    subs = sub_resources(t, "Resource")
    objs = []
    for sid in re.findall(r'SubResource\("([^"]+)"\)', str(d.get("objectives", ""))):
        s = subs.get(sid, {})
        objs.append({"kind": int(s.get("kind", 0)), "target": s.get("target", ""),
                     "count": int(s.get("count", 1)), "text": s.get("text", "")})
    if not objs and d.get("kill_monster_id"):
        objs = [{"kind": 0, "target": d["kill_monster_id"], "count": int(d.get("kill_count", 1)), "text": ""}]
    d["_objs"] = objs
    d["_file"] = p
    quests[qid] = with_defaults(d, DEF_QUEST)

# =========================================================
# 5) แมพ (.tscn)
# =========================================================
def parse_map(path):
    t = read(path)
    subs = sub_resources(t)
    nodes = []
    for b in re.split(r"\n(?=\[node )", t):
        m = re.match(r'\[node name="([^"]+)"(?: type="([^"]+)")?(?: parent="([^"]+)")?[^\]]*\]', b)
        if not m:
            continue
        body = []
        for line in b.split("\n")[1:]:
            if line.startswith("["):
                break
            body.append(line)
        props = props_from_lines(body)
        inst = re.search(r'instance=ExtResource\("([^"]+)"\)', b)
        nodes.append({"name": m.group(1), "type": m.group(2) or "",
                      "parent": m.group(3) or "", "props": props,
                      "inst": inst.group(1) if inst else ""})
    root = nodes[0] if nodes else {"props": {}}
    info = {
        "file": path,
        "map_id": root["props"].get("map_id", os.path.basename(path).replace(".tscn", "")),
        "display_name": root["props"].get("display_name", ""),
        "chapter": root["props"].get("chapter", 1),
        "region": root["props"].get("region", "มิดการ์ด"),
        "bounds": root["props"].get("map_bounds"),
        "auto_fit": root["props"].get("auto_fit_bounds"),
        "camera_offset": root["props"].get("camera_offset"),
        "spawns": [], "portals": [], "spawners": [], "npcs": [], "lore": [],
        "ground": [], "platforms": [], "bg": [],
    }
    ext_paths = dict(re.findall(r'\[ext_resource type="[^"]+"[^\]]*path="res://([^"]+)" id="([^"]+)"\]', t))
    id2path = {v: k for k, v in ext_paths.items()}
    for n in nodes:
        p, props, nm = n["parent"], n["props"], n["name"]
        if p == "SpawnPoints":
            info["spawns"].append((nm, props.get("position", (0, 0))))
        elif p == "Portals":
            info["portals"].append({
                "name": nm, "pos": props.get("position", (0, 0)),
                "to": props.get("target_map", DEF_PORTAL.get("target_map", "")),
                "spawn": props.get("target_spawn_point", DEF_PORTAL.get("target_spawn_point", "default")),
                "label": props.get("label_text", ""), "flag": props.get("required_flag", ""),
            })
        elif p == "Spawners":
            mons = re.findall(r'ExtResource\("([^"]+)"\)', str(props.get("monster_types", "")))
            mids = []
            for e in mons:
                fp = id2path.get(e, "")
                if "/monsters/" in fp:
                    mids.append(os.path.basename(fp).replace(".tres", ""))
            if mids:
                info["spawners"].append({
                    "node": nm, "mons": mids,
                    "count": props.get("count_per_type", DEF_SPAWNER.get("count_per_type", 5)),
                    "max_alive": props.get("max_alive"),
                    "pos": props.get("position"),
                })
        elif p == "NPCs":
            shop = re.findall(r'&"([^"]+)"', str(props.get("shop_items", "")))
            qs = re.findall(r'&"([^"]+)"', str(props.get("quest_ids", "")))
            info["npcs"].append({
                "node": nm, "name": props.get("npc_name", nm),
                "type": props.get("type", 0), "pos": props.get("position", (0, 0)),
                "shop": shop, "quests": qs,
                "by_flag": "dialog_by_flag" in props or "dialog_by_flag" in str(props),
            })
        elif p.startswith("Lore"):
            info["lore"].append({
                "node": nm, "id": props.get("lore_id", ""), "title": props.get("title", ""),
                "pos": props.get("position", (0, 0)), "flag": props.get("required_flag", ""),
                "give": props.get("give_item", ""),
            })
        elif p == "Terrain" or p.startswith("Terrain/") or p == "TileMap" or p.startswith("TileMap/"):
            if n["type"] in ("StaticBody2D",):
                info["ground"].append((nm, props.get("position", (0, 0))))
            if n["type"] == "CollisionShape2D":
                sid = re.search(r'SubResource\("([^"]+)"\)', str(props.get("shape", "")))
                size = subs.get(sid.group(1), {}).get("size") if sid else None
                info["platforms"].append((p + "/" + nm, props.get("position", (0, 0)), size))
        elif p == "Background":
            tex = re.search(r'ExtResource\("([^"]+)"\)', str(props.get("texture", "")))
            info["bg"].append((nm, id2path.get(tex.group(1), "") if tex else "",
                               props.get("polygon") is not None))
    return info

maps = {}
for p in sorted(glob.glob("scenes/maps/*.tscn")):
    if ".bak" in p:
        continue
    try:
        info = parse_map(p)
        maps[info["map_id"]] = info
    except Exception as e:
        print("อ่านแมพไม่ได้", p, e)

MAP_ORDER = ["prontera_town", "prontera_field", "asgard_forest_2", "dark_forest", "thunder_scar",
             "iron_road", "nidavellir_town", "ember_mine", "hall_of_silence", "cold_forge"]

# =========================================================
# ที่มาของไอเทม: ดรอปจากมอน / ร้านขาย / รางวัลเควส
# =========================================================
sources = collections.defaultdict(list)
for mid, m in monsters.items():
    for d in m["_drops"]:
        cnt = "" if d["max"] <= 1 else " x%d-%d" % (d["min"], d["max"])
        sources[d["item"]].append("ดรอป: %s %.1f%%%s" % (m.get("display_name", mid), d["chance"], cnt))
shops = {}
for mid, mp in maps.items():
    for n in mp["npcs"]:
        if n["shop"]:
            shops[n["name"]] = n["shop"]
            for it in n["shop"]:
                sources[it].append("ร้าน: %s" % n["name"])
for qid, q in quests.items():
    if q.get("reward_item_id"):
        sources[q["reward_item_id"]].append("รางวัลเควส: %s" % q.get("title", qid))
for mid, mp in maps.items():
    for l in mp["lore"]:
        if l["give"]:
            sources[l["give"]].append("เก็บจาก: %s (%s)" % (l["title"] or l["id"], mp["display_name"]))

# มอนตัวไหนอยู่แมพไหน
mon_maps = collections.defaultdict(list)
for mid, mp in maps.items():
    for sp in mp["spawners"]:
        for m in sp["mons"]:
            nm = mp["display_name"] or mid
            if nm not in mon_maps[m]:
                mon_maps[m].append(nm)

# =========================================================
# เขียนเอกสาร
# =========================================================
L = []
def w(s=""):
    L.append(s)

w("# ข้อมูลเกมทั้งหมด — Shadows of Fate (Ragnarok Battle Offline remake)")
w()
w("อัพเดตอัตโนมัติจากไฟล์จริงในโปรเจกต์ด้วย `dump_gamedata.py` (รันใหม่ได้ทุกเมื่อ ข้อมูลจะตรงกับเกมเสมอ)")
w()
w("| หมวด | จำนวน |")
w("|---|---|")
w("| ไอเทมทั้งหมด | **%d** ชิ้น (ไม่รวมการ์ด %d · การ์ด %d) |" % (
    len(items), len([i for i in items.values() if not i["_is_card"]]),
    len([i for i in items.values() if i["_is_card"]])))
w("| มอนสเตอร์ | **%d** ตัว (บอส %d) |" % (len(monsters), len([m for m in monsters.values() if m.get("is_boss")])))
w("| สกิลผู้เล่น | **%d** |" % len(skills))
w("| เควส | **%d** |" % len(quests))
w("| แมพ | **%d** |" % len(maps))
w()
w("**หน่วยพิกัด**: 1 หน่วย = 1 พิกเซล · จอเกม 1280x720 · ตัวละครสูง 240 px (`auto_fit_height`)")
w()
w("---")
w()

# ---------------- ไอเทม ----------------
def stat_str(d):
    parts = []
    for k, label in [("atk", "ATK"), ("matk", "MATK"), ("def", "DEF"), ("mdef", "MDEF"),
                     ("hit", "HIT"), ("flee", "FLEE"), ("crit", "CRIT"),
                     ("max_hp", "MaxHP"), ("max_sp", "MaxSP")]:
        v = d.get(k, 0)
        if v:
            parts.append("%s %+d" % (label, v))
    for k, label in [("bonus_str", "STR"), ("bonus_agi", "AGI"), ("bonus_vit", "VIT"),
                     ("bonus_int", "INT"), ("bonus_dex", "DEX"), ("bonus_luk", "LUK")]:
        v = d.get(k, 0)
        if v:
            parts.append("%s %+d" % (label, v))
    if d.get("aspd_percent"):
        parts.append("ASPD %+.0f%%" % d["aspd_percent"])
    if d.get("heal_hp") or d.get("heal_hp_percent"):
        parts.append("ฟื้น HP %d%s" % (d.get("heal_hp", 0),
                     " +%.0f%%" % d["heal_hp_percent"] if d.get("heal_hp_percent") else ""))
    if d.get("heal_sp") or d.get("heal_sp_percent"):
        parts.append("ฟื้น SP %d%s" % (d.get("heal_sp", 0),
                     " +%.0f%%" % d["heal_sp_percent"] if d.get("heal_sp_percent") else ""))
    pe = d.get("percent_effects")
    if pe:
        for kv in re.findall(r'"([a-z_]+)":\s*([\d.]+)', str(pe)):
            parts.append("%s +%s%%" % (kv[0].replace("_percent", "").upper(), kv[1]))
    return " · ".join(parts) if parts else "—"

def src_str(iid):
    s = sources.get(iid, [])
    return " / ".join(s) if s else "—"

w("## 1. ไอเทม")
w()

GROUPS = [
    ("1.1 อาวุธ (ดาบ)", lambda d: d.get("type") == 1),
    ("1.2 ของสวมใส่ (เกราะ/โล่/หมวก/ผ้าคลุม/รองเท้า/เครื่องประดับ)", lambda d: d.get("type") == 2),
    ("1.3 ของกิน / ยา", lambda d: d.get("type") == 0),
    ("1.4 วัตถุดิบ + ของขยะจากมอน", lambda d: d.get("type") == 3),
    ("1.5 ของเควส (ขาย/ทิ้งไม่ได้)", lambda d: d.get("type") == 4),
]
for title, fn in GROUPS:
    rows = [(iid, d) for iid, d in items.items() if not d["_is_card"] and fn(d)]
    rows.sort(key=lambda x: (x[1].get("required_level", 1), x[1].get("buy_price", 0), x[0]))
    w("### %s — %d ชิ้น" % (title, len(rows)))
    w()
    if not rows:
        w("(ยังไม่มี)")
        w()
        continue
    if fn({"type": 1}) or fn({"type": 2}):
        w("| id | ชื่อ | ช่อง | Lv | ค่าพลัง | ตีบวก | ช่องการ์ด | ซื้อ | ขาย | ได้จาก |")
        w("|---|---|---|---|---|---|---|---|---|---|")
        for iid, d in rows:
            w("| `%s` | %s | %s | %d | %s | %s | %d | %s | %s | %s |" % (
                iid, d.get("display_name", ""), enum_name(ITEM_SLOT, d.get("slot", 0)),
                d.get("required_level", 1), stat_str(d),
                "✓" if d.get("refinable") else "—", d.get("card_slots", 0),
                "{:,}".format(d.get("buy_price", 0)) if d.get("buy_price") else "—",
                "{:,}".format(d.get("sell_price", 0)), src_str(iid)))
    else:
        w("| id | ชื่อ | ผล / คำอธิบาย | ซื้อ | ขาย | ได้จาก |")
        w("|---|---|---|---|---|---|")
        for iid, d in rows:
            eff = stat_str(d)
            if eff == "—":
                eff = (d.get("description", "") or "—")[:60]
            w("| `%s` | %s | %s | %s | %s | %s |" % (
                iid, d.get("display_name", ""), eff,
                "{:,}".format(d.get("buy_price", 0)) if d.get("buy_price") else "—",
                "{:,}".format(d.get("sell_price", 0)) if d.get("sell_price") else "—",
                src_str(iid)))
    w()

cards = [(iid, d) for iid, d in items.items() if d["_is_card"]]
cards.sort(key=lambda x: x[0])
w("### 1.6 การ์ดมอนสเตอร์ — %d ใบ" % len(cards))
w()
w("ดรอปจากมอนตัวนั้นโดยเฉพาะ · โอกาส 5% (บอส/มินิบอสบางตัว 2%) · ใส่ในช่องการ์ดของอุปกรณ์")
w()
w("| id | ชื่อ | มาจากมอน | ใส่ช่อง | ผลที่ได้ | ขาย |")
w("|---|---|---|---|---|---|")
for iid, d in cards:
    w("| `%s` | %s | `%s` | %s | %s | %s |" % (
        iid, d.get("display_name", ""), d.get("monster_id", "—"),
        enum_name(ITEM_SLOT, d.get("fits_slot", 0)), stat_str(d),
        "{:,}".format(d.get("sell_price", 0))))
w()

w("### 1.7 รายการของในร้านค้า")
w()
for name, lst in shops.items():
    w("**%s** (%d รายการ): %s" % (name, len(lst), ", ".join("`%s`" % x for x in lst)))
    w()

w("---")
w()

# ---------------- มอนสเตอร์ ----------------
w("## 2. มอนสเตอร์")
w()
w("### 2.1 ตารางรวม")
w()
w("`*` ที่ Job EXP = ไม่ได้ตั้งค่าไว้ ระบบคิดให้อัตโนมัติ 70% ของ EXP")
w()
w("| id | ชื่อ | Lv | HP | ATK | DEF/MDEF | HIT/FLEE | ธาตุ | เผ่า | ขนาด | AI | ความเร็ว | EXP/Job | ซีนี | สูง(px) | แมพ |")
w("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
for mid, m in sorted(monsters.items(), key=lambda x: (x[1].get("level", 1), x[0])):
    w("| `%s` | %s%s | %d | %s | %d-%d | %d/%d | %d/%d | %s | %s | %s | %s | %.0f | %s/%s | %d-%d | %.0f | %s |" % (
        mid, m.get("display_name", ""), " ★บอส" if m.get("is_boss") else "",
        m.get("level", 1), "{:,}".format(m.get("max_hp", 0)),
        m.get("atk_min", 0), m.get("atk_max", 0), m.get("def", 0), m.get("mdef", 0),
        m.get("hit", 0), m.get("flee", 0),
        enum_name(ELEMENT, m.get("element", 2)), enum_name(RACE, m.get("race", 0)),
        enum_name(SIZE, m.get("size", 0)), enum_name(AI, m.get("ai_type", 0)).split(" ")[0],
        m.get("move_speed", 90), "{:,}".format(m.get("exp_reward", 0)),
        "{:,}{}".format(job_exp_of(m)[0], "*" if job_exp_of(m)[1] else ""),
        m.get("zeny_min", 0), m.get("zeny_max", 0), m.get("display_height", 0) or 0,
        ", ".join(mon_maps.get(mid, [])) or "—"))
w()

w("### 2.2 รายละเอียดรายตัว (สเตตัส · จังหวะโจมตี · สกิล · ตารางดรอป)")
w()
for mid, m in sorted(monsters.items(), key=lambda x: (x[1].get("level", 1), x[0])):
    w("#### `%s` — %s%s" % (mid, m.get("display_name", ""), "  ★ บอส MVP ★" if m.get("is_boss") else ""))
    w()
    w("- **สเตตัส**: Lv %d · HP %s · ATK %d-%d · DEF %d · MDEF %d · HIT %d · FLEE %d · CRIT %d" % (
        m.get("level", 1), "{:,}".format(m.get("max_hp", 0)), m.get("atk_min", 0), m.get("atk_max", 0),
        m.get("def", 0), m.get("mdef", 0), m.get("hit", 0), m.get("flee", 0), m.get("crit", 0)))
    w("- **ชนิด**: ธาตุ%s (Lv %d) · เผ่า%s · ขนาด%s · AI %s" % (
        enum_name(ELEMENT, m.get("element", 2)), m.get("element_level", 1),
        enum_name(RACE, m.get("race", 0)), enum_name(SIZE, m.get("size", 0)),
        enum_name(AI, m.get("ai_type", 0))))
    w("- **การเคลื่อนไหว**: ความเร็ว %.0f · เห็นผู้เล่นที่ %.0f · ตีได้ที่ %.0f · ลากกลับบ้านที่ %.0f · เดินเล่นในรัศมี %.0f%s" % (
        m.get("move_speed", 90), m.get("detect_range", 250), m.get("attack_range", 70),
        m.get("leash_range", 750), m.get("wander_range", 260),
        " · กระโดดได้" if m.get("jump_force") else ""))
    w("- **จังหวะโจมตี**: ยกท่า %.2f วิ · ท่าโจมตี %.2f วิ · คูลดาวน์ %.2f วิ · knockback %.0f" % (
        m.get("attack_windup", 0.4), m.get("attack_duration", 0.5),
        m.get("attack_cooldown", 1.8), m.get("knockback_force", 160)))
    w("- **พักเดิน (idle)**: โอกาสพัก %.0f%% · พัก %.1f-%.1f วิ · เดิน %.1f-%.1f วิ" % (
        float(m.get("wander_pause_chance", 0.65)) * 100,
        m.get("wander_pause_min", 3.0), m.get("wander_pause_max", 5.0),
        m.get("wander_walk_min", 1.6), m.get("wander_walk_max", 3.2)))
    je, auto = job_exp_of(m)
    w("- **รางวัล**: EXP %s · Job %s%s · ซีนี %d-%d · เกิดใหม่ทุก %.0f วิ" % (
        "{:,}".format(m.get("exp_reward", 0)), "{:,}".format(je),
        " (คิดอัตโนมัติ 70%)" if auto else "",
        m.get("zeny_min", 0), m.get("zeny_max", 0), m.get("respawn_time", 15)))
    if m.get("skill_name"):
        w("- **★ สกิล «%s» ★**: ระยะร่าย %.0f · พื้นที่โดน %.0fx%.0f · ดาเมจ x%.1f · ยกท่า %.1f วิ · ท่า %.1f วิ · คูลดาวน์ %.1f วิ · โอกาสใช้ %.0f%% · knockback %.0f" % (
            m["skill_name"], m.get("skill_range", 320), m.get("skill_radius_x", 300),
            m.get("skill_radius_y", 180), m.get("skill_damage_mult", 2.2),
            m.get("skill_windup", 0.7), m.get("skill_duration", 0.8),
            m.get("skill_cooldown", 9.0), float(m.get("skill_chance", 0.6)) * 100,
            m.get("skill_knockback", 320)))
    if m.get("projectile_texture"):
        w("- **โจมตีระยะไกล**: ยิงกระสุนตรง ความเร็ว %.0f · ระยะ %.0f · จุดปล่อย %s · กล่องชน %s" % (
            m.get("projectile_speed", 520), m.get("projectile_range", 720),
            m.get("projectile_offset", "—"), m.get("projectile_hit_size", "—")))
    if m.get("skill_projectile_texture"):
        w("- **สกิลขว้างโค้ง**: ความสูงโค้ง %.0f · เวลาบิน %.2f วิ · ระเบิดรัศมี %.0fx%.0f" % (
            m.get("skill_projectile_arc", 240), m.get("skill_projectile_time", 0.9),
            m.get("skill_radius_x", 300), m.get("skill_radius_y", 180)))
    if m.get("intro_video"):
        w("- **วิดีโอเปิดตัว**: `%s` (เล่นครั้งแรกที่เข้าใกล้ %.0f px · ครั้งเดียวต่อเซฟ)" % (
            m["intro_video"], m.get("intro_range", 700)))
    if m["_drops"]:
        w("- **ตารางดรอป**:")
        w()
        w("  | ไอเทม | ชื่อ | โอกาส | จำนวน |")
        w("  |---|---|---|---|")
        for d in sorted(m["_drops"], key=lambda x: -x["chance"]):
            it = items.get(d["item"], {})
            w("  | `%s` | %s | %.1f%% | %s |" % (
                d["item"], it.get("display_name", "?"), d["chance"],
                "%d" % d["min"] if d["max"] <= d["min"] else "%d-%d" % (d["min"], d["max"])))
    w()

w("---")
w()

# ---------------- สกิลผู้เล่น ----------------
w("## 3. สกิลผู้เล่น (อาชีพนักดาบ)")
w()
w("| id | ชื่อ | ชนิด | Lv ที่เรียนได้ | ต้องมีสกิล | SP | คูลดาวน์ | ดาเมจ | ระยะ X/Y | เป้าหมายสูงสุด |")
w("|---|---|---|---|---|---|---|---|---|---|")
for sid, s in sorted(skills.items(), key=lambda x: x[1].get("required_level", 1)):
    req = re.findall(r'"([a-z_]+)":\s*(\d+)', str(s.get("required_skills", "")))
    reqs = ", ".join("%s Lv%s" % (a, b) for a, b in req) or "—"
    attack_like = int(s.get("type", 0)) in (0, 1, 5)
    dmg = "x%.1f (+%.2f/Lv)" % (s.get("damage_mult_base", 1.0), s.get("damage_mult_per_level", 0)) \
        if attack_like else "—"
    w("| `%s` | %s | %s | %d | %s | %d (+%.0f/Lv) | %.1f วิ | %s | %s | %s |" % (
        sid, s.get("display_name", ""), enum_name(SKILL_TYPE, s.get("type", 0)),
        s.get("required_level", 1), reqs, s.get("sp_cost_base", 0),
        s.get("sp_cost_per_level", 0), s.get("cooldown", 0), dmg,
        ("%.0f / %.0f" % (s.get("range_x", 0) or 0, s.get("range_y", 0) or 0)) if attack_like else "—",
        (s.get("max_targets", 0) or "ไม่จำกัด") if attack_like else "—"))
w()
w("**ผลของสกิลบัฟ / ฟื้นเลือด / พาสซีฟ** (ค่าที่เพิ่มต่อเลเวลสกิลอยู่ในวงเล็บ)")
w()
for sid, s in sorted(skills.items(), key=lambda x: x[1].get("required_level", 1)):
    line = "- **%s** (Lv สูงสุด %d) — %s" % (
        s.get("display_name", sid), s.get("max_level", 10), s.get("description", ""))
    eff = []
    for key in ("buff_effects", "passive_effects"):
        for k, v in re.findall(r'"([a-z_]+)":\s*([\d.]+)', str(s.get(key, ""))):
            eff.append("%s %s%s" % (k.replace("_percent", "").upper(), v,
                                    "%" if "percent" in k else ""))
    if eff:
        line += "  ▸ ให้ %s" % (" · ".join(eff))
        if int(s.get("type", 0)) == 2:   # เฉพาะบัฟที่มีเวลาหมดอายุ (พาสซีฟติดตัวถาวร)
            line += " (+%.0f/Lv · อยู่ได้ %.0f วิ +%.0f/Lv)" % (
                s.get("buff_value_per_level", 0), s.get("duration_base", 0),
                s.get("duration_per_level", 0))
    if int(s.get("type", 0)) == 3:
        line += "  ▸ ฟื้น %.0f + %.0f/Lv + INT x%.1f" % (
            s.get("heal_base", 30), s.get("heal_per_level", 25), s.get("heal_int_scale", 2))
    w(line)
w()
w("---")
w()

# ---------------- แมพ ----------------
w("## 4. แมพ")
w()
w("### 4.1 ตารางรวม + ขนาด")
w()
w("| id | ชื่อ | บท | ภูมิภาค | ขนาดแมพ (x, y, กว้าง, สูง) | ระดับพื้น (y) | มอนที่เกิด | ประตูออก |")
w("|---|---|---|---|---|---|---|---|")
order = [m for m in MAP_ORDER if m in maps] + [m for m in maps if m not in MAP_ORDER]
for mid in order:
    mp = maps[mid]
    b = mp["bounds"]
    bs = "Rect2(%.0f, %.0f, %.0f, %.0f)" % b if b else "auto"
    gy = "—"
    if mp["spawns"]:
        gy = "%.0f" % max(p[1] for _, p in mp["spawns"])
    mons = sorted(set(sum([sp["mons"] for sp in mp["spawners"]], [])))
    w("| `%s` | %s | %s | %s | %s | ~%s | %s | %s |" % (
        mid, mp["display_name"], mp["chapter"], mp["region"], bs, gy,
        ", ".join(mons) or "—",
        ", ".join(p["to"] for p in mp["portals"]) or "—"))
w()

w("### 4.2 รายละเอียดรายแมพ")
w()
NPC_TYPE = ["คุย", "ร้านค้า", "ตีบวก", "หมอ", "จุดเซฟ", "เควส"]
for mid in order:
    mp = maps[mid]
    b = mp["bounds"]
    w("#### `%s` — %s (บทที่ %s · %s)" % (mid, mp["display_name"], mp["chapter"], mp["region"]))
    w()
    w("- **ไฟล์**: `%s`" % mp["file"])
    if b:
        w("- **ขอบเขตแมพ**: `Rect2(%.0f, %.0f, %.0f, %.0f)` → กว้าง **%.0f px** สูง **%.0f px** (x %.0f→%.0f · y %.0f→%.0f)" % (
            b[0], b[1], b[2], b[3], b[2], b[3], b[0], b[0] + b[2], b[1], b[1] + b[3]))
    else:
        w("- **ขอบเขตแมพ**: คำนวณอัตโนมัติจากภาพพื้นหลัง (`auto_fit_bounds`)")
    if mp["bg"]:
        for nm, path, poly in mp["bg"]:
            if path:
                w("- **ฉากหลัง (%s)**: `%s`" % (nm, path))
    if mp["spawns"]:
        w("- **จุดเกิดผู้เล่น**: " + " · ".join("`%s` (%.0f, %.0f)" % (n, p[0], p[1]) for n, p in mp["spawns"]))
    if mp["platforms"]:
        pl = [x for x in mp["platforms"] if x[2]]
        if pl:
            w("- **พื้น/แท่นยืน**: " + " · ".join(
                "%s ที่ (%.0f, %.0f) ขนาด %.0fx%.0f" % (n.split("/")[-1], p[0], p[1], s[0], s[1])
                for n, p, s in pl[:8]))
    if mp["portals"]:
        w("- **ประตู**:")
        for p in mp["portals"]:
            w("  - `%s` ที่ (%.0f, %.0f) → **%s** (จุดเกิด `%s`) %s%s" % (
                p["name"], p["pos"][0], p["pos"][1], p["to"], p["spawn"],
                "«%s»" % p["label"] if p["label"] else "",
                " · ★ล็อกด้วยธง `%s`★" % p["flag"] if p["flag"] else ""))
    if mp["spawners"]:
        w("- **การเกิดมอน**:")
        for sp in mp["spawners"]:
            names = ", ".join("%s (`%s`)" % (monsters.get(x, {}).get("display_name", x), x) for x in sp["mons"])
            if sp.get("max_alive"):
                w("  - `%s` (บอส): %s · มีได้ทีละ %s ตัว ที่ x≈%.0f" % (
                    sp["node"], names, sp["max_alive"], (sp["pos"] or (0, 0))[0]))
            else:
                w("  - `%s`: %s · ชนิดละ %s ตัว (รวม %d ตัว)" % (
                    sp["node"], names, sp["count"], len(sp["mons"]) * int(sp["count"] or 5)))
    if mp["npcs"]:
        w("- **NPC** (%d คน):" % len(mp["npcs"]))
        for n in mp["npcs"]:
            extra = []
            if n["shop"]:
                extra.append("ร้านขาย %d รายการ" % len(n["shop"]))
            if n["quests"]:
                extra.append("ให้เควส: " + ", ".join("`%s`" % q for q in n["quests"]))
            w("  - **%s** (%s) ที่ x=%.0f%s" % (
                n["name"], enum_name(NPC_TYPE, n["type"], "คุย"), n["pos"][0],
                " — " + " · ".join(extra) if extra else ""))
    if mp["lore"]:
        w("- **จุดกด F อ่านเรื่องราว**:")
        for l in mp["lore"]:
            w("  - `%s` «%s» ที่ x=%.0f%s%s" % (
                l["id"], l["title"], l["pos"][0],
                " · ให้ไอเทม `%s`" % l["give"] if l["give"] else "",
                " · ล็อกธง `%s`" % l["flag"] if l["flag"] else ""))
    w()

w("---")
w()

# ---------------- เควส ----------------
w("## 5. เควส (สรุปสายเนื้อเรื่อง)")
w()
w("| id | ชื่อ | ผู้ให้ | Lv | ต้องผ่านเควส | เงื่อนไข | รางวัล | ตั้งธง |")
w("|---|---|---|---|---|---|---|---|")
def qorder(x):
    i = x[0]
    return (0 if i.startswith("m") else (1 if i.startswith("c2") else 2), i)
for qid, q in sorted(quests.items(), key=qorder):
    objs = " + ".join("%s `%s`%s" % (enum_name(KIND, o["kind"]), o["target"],
                                     " x%d" % o["count"] if o["count"] > 1 else "")
                      for o in q["_objs"]) or "คุยอย่างเดียว"
    rw = []
    if q.get("reward_item_id"):
        rw.append("`%s` x%d" % (q["reward_item_id"], q.get("reward_item_count", 1)))
    if q.get("reward_zeny"):
        rw.append("%s z" % "{:,}".format(q["reward_zeny"]))
    if q.get("reward_exp"):
        rw.append("EXP %s" % "{:,}".format(q["reward_exp"]))
    req = re.findall(r'&"([^"]+)"', str(q.get("required_quests", "")))
    w("| `%s` | %s | %s | %d | %s | %s | %s | %s |" % (
        qid, q.get("title", ""), q.get("giver_name", "—"), q.get("required_level", 1),
        ", ".join(req) or "—", objs, " · ".join(rw) or "—",
        "`%s`" % q["set_flag_on_complete"] if q.get("set_flag_on_complete") else "—"))
w()


w("---")
w()
w("## 6. เทมเพลตสำหรับสร้างของใหม่ (ใช้เป็นพรอมพ์ต่อได้)")
w()
w("""### สร้างมอนใหม่ — ข้อมูลที่ต้องมี
```
id: <ตัวพิมพ์เล็ก_ขีดล่าง>        ชื่อไทย: <...>
Lv / HP / ATK min-max / DEF / MDEF / HIT / FLEE / CRIT
ธาตุ (ไร้ธาตุ ไฟ น้ำ ดิน ลม พิษ ศักดิ์สิทธิ์ มืด วิญญาณ อันเดด) · เผ่า · ขนาด
AI: PASSIVE / AGGRESSIVE / STATIONARY · move_speed · detect_range · attack_range
รางวัล: exp / job_exp (~70% ของ exp) / zeny min-max
สูงบนจอ (display_height) · hitbox_size
สกิล (ถ้ามี): ชื่อ · range · radius x/y · damage_mult · windup · duration · cooldown · chance
ของขยะเฉพาะตัว 1-2 ชิ้น (ต้องมี!) + การ์ด card_<id> (ต้องมี!)
แมพที่ให้เกิด
```
เกณฑ์บาลานซ์ที่ใช้อยู่: HP ≈ Lv x 40-60 (บอส x200+) · ATK ≈ Lv x 4-6 · EXP ≈ Lv x 15-30 (บอส x300)

### สร้างไอเทมใหม่
```
id · ชื่อไทย · คำอธิบาย 1 บรรทัด
type: ของกิน / อาวุธ / ของสวมใส่ / วัตถุดิบ / ของเควส
slot (ถ้าสวมใส่): อาวุธ มือรอง ศีรษะ ชุดเกราะ ผ้าคลุม รองเท้า เครื่องประดับ
required_level · ค่าพลัง (ATK/DEF/HIT/FLEE/CRIT/MaxHP/MaxSP/STR-LUK/ASPD%)
buy_price (≈ sell x2.5) · sell_price · card_slots · refinable
ได้จาก: มอนตัวไหนดรอปกี่ % / ร้านใครขาย / รางวัลเควสอะไร
```
เส้นอาวุธปัจจุบัน (ATK): ดาบไม้ 14 → มือใหม่ 25 → สั้น 30 → เรเปียร์ 34 → ฟัลชิออน 39 → บาสตาร์ด 46 → ใบมีดเหล็ก 50 → คาตานะ 53 → เตาหลอม 72 → เคลย์มอร์ 92 → รูน 94 → เพลิง 105

### สร้างแมพใหม่
```
map_id · ชื่อไทย · chapter · region
ขนาด: กว้าง x สูง (แมพปัจจุบัน 1600-5750 x 950-1300)
ระดับพื้น y (แมพบท 2 = 880 · ทุ่งวิหาร = 504 · ป่าเงาลึก = 960)
ฉากหลัง: ไฟล์ภาพ 1 ชั้น (Sky) กว้างเท่าแมพ ผูกด้วย uv
จุดเกิด: default + from_<แมพก่อนหน้า> (ทุกประตูที่ชี้มาต้องมีจุดเกิดตรงกัน!)
ประตู: ไป map_id ไหน จุดเกิดชื่ออะไร ป้ายว่าอะไร ล็อกธงไหม
มอนที่เกิด: 2-3 ชนิด ชนิดละ 4-5 ตัว
NPC / จุดกด F อ่านเรื่องราว (ถ้ามี)
```
**กฎที่ระบบบังคับ** (เทสต์จะจับได้ถ้าผิด): มอนทุกตัวต้องมีการ์ด + ของขยะเฉพาะตัว · ประตูทุกบานต้องชี้ไปแมพ+จุดเกิดที่มีจริง · ของที่ร้านขาย/มอนดรอปต้องมีไฟล์จริง · id ไอเทมตัวพิมพ์เล็กเสมอ
""")

w("---")
w()
w("## 7. ตรวจสุขภาพข้อมูล (สร้างอัตโนมัติ — ใช้เลือกงานรอบต่อไป)")
w()

# ไอเทมที่ยังไม่มีที่มา
orphan_items = [(i, d) for i, d in items.items()
                if not d["_is_card"] and not sources.get(i) and d.get("type") != 4]
w("### 7.1 ไอเทมที่ยังไม่มีทางได้มา (%d ชิ้น)" % len(orphan_items))
w()
w("ไม่มีมอนตัวไหนดรอป · ไม่มีร้านไหนขาย · ไม่ใช่รางวัลเควส → ผู้เล่นหาไม่ได้เลย")
w()
if orphan_items:
    w("| id | ชื่อ | ประเภท | Lv | ค่าพลัง |")
    w("|---|---|---|---|---|")
    for i, d in sorted(orphan_items, key=lambda x: x[1].get("required_level", 1)):
        w("| `%s` | %s | %s | %d | %s |" % (i, d.get("display_name", ""),
          enum_name(ITEM_TYPE, d.get("type", 3)), d.get("required_level", 1), stat_str(d)))
else:
    w("(ครบทุกชิ้นแล้ว)")
w()

# มอนที่ยังไม่ได้วางในแมพ
orphan_mons = [m for m in monsters if not mon_maps.get(m)]
w("### 7.2 มอนสเตอร์ที่ยังไม่ได้วางในแมพไหนเลย (%d ตัว)" % len(orphan_mons))
w()
if orphan_mons:
    for m in orphan_mons:
        d = monsters[m]
        w("- `%s` **%s** Lv %d HP %s — ยังไม่มีแมพให้เกิด" % (
            m, d.get("display_name", ""), d.get("level", 1), "{:,}".format(d.get("max_hp", 0))))
else:
    w("(วางครบแล้ว)")
w()

# มอนที่ไม่มีการ์ด / ของขยะ
no_card = [m for m in monsters if ("card_%s" % m) not in items]
junk_owner = collections.defaultdict(list)
for m, d in monsters.items():
    for dr in d["_drops"]:
        it = items.get(dr["item"], {})
        if it.get("type") == 3:
            junk_owner[m].append(dr["item"])
no_junk = [m for m in monsters if not junk_owner.get(m)]
w("### 7.3 กฎบังคับของโปรเจกต์")
w()
w("- มอนที่ยังไม่มีการ์ด: %s" % (", ".join("`%s`" % x for x in no_card) if no_card else "**ครบทุกตัว ✓**"))
w("- มอนที่ยังไม่มีของขยะเฉพาะตัว: %s" % (", ".join("`%s`" % x for x in no_junk) if no_junk else "**ครบทุกตัว ✓**"))

# ประตูชี้ไปจุดเกิดที่มีจริงไหม
bad = []
for mid, mp in maps.items():
    for p in mp["portals"]:
        tgt = maps.get(p["to"])
        if tgt is None:
            bad.append("%s → `%s` (ไม่มีแมพนี้)" % (mid, p["to"]))
        elif p["spawn"] not in [n for n, _ in tgt["spawns"]]:
            bad.append("%s → %s@`%s` (ไม่มีจุดเกิดชื่อนี้)" % (mid, p["to"], p["spawn"]))
w("- ประตูที่ชี้ผิด: %s" % (" · ".join(bad) if bad else "**ไม่มี ✓**"))

# ไอเทมที่ถูกอ้างแต่ไม่มีไฟล์
missing = set()
for m, d in monsters.items():
    for dr in d["_drops"]:
        if dr["item"] not in items:
            missing.add(dr["item"])
for nm, lst in shops.items():
    for it in lst:
        if it not in items:
            missing.add(it)
w("- ไอเทมที่ถูกอ้างถึงแต่ไม่มีไฟล์: %s" % (", ".join("`%s`" % x for x in sorted(missing)) if missing else "**ไม่มี ✓**"))
w()

out = "ข้อมูลเกมทั้งหมด.md"
open(out, "w", encoding="utf-8").write("\n".join(L))
print("เขียน %s (%d บรรทัด · %.0f KB)" % (out, len(L), os.path.getsize(out) / 1024))
print("ไอเทม %d · มอน %d · สกิล %d · เควส %d · แมพ %d" % (len(items), len(monsters), len(skills), len(quests), len(maps)))
