# -*- coding: utf-8 -*-
"""ส่วนต่อของ dump_gamedata.py (รอบ 49) — ตารางผลของสเตตัส

อ่าน "ตัวเลขจริง" จากไฟล์โค้ด แล้วสร้างตารางว่าอัพสเตตัสแต่ละตัวได้อะไรบ้าง
  scripts/core/player_stats.gd   ค่าคงที่ต่อแต้ม (STR_ATK, VIT_HP_FLAT, ...)
  scripts/core/combat.gd         สูตรความแม่น/ดาเมจ
  data/jobs/*.tres               ตัวคูณของอาชีพ (atk_mod, hp_vit_percent, ...)

★ แก้ตัวเลขในไฟล์พวกนั้นแล้วรัน dump_gamedata.py ใหม่ ตารางจะอัปเดตตามเอง ★
★ ถ้าแก้ "สูตร" (ไม่ใช่แค่ตัวเลข) ต้องมาแก้คำอธิบายใน EFFECTS ข้างล่างด้วย ★
"""
import os, re, glob


def _num(expr, default=0.0):
    """แปลงค่าคงที่จาก GDScript เป็นตัวเลข (รองรับ 1.0 / 3.0 แบบเศษส่วน)"""
    if expr is None:
        return default
    s = str(expr).split("#")[0].strip()
    if not re.fullmatch(r"[0-9eEъ.+\-*/() ]+", s.replace("ъ", "")):
        return default
    try:
        return float(eval(s, {"__builtins__": {}}, {}))
    except Exception:
        return default


def _consts(path):
    """ดึง const NAME := ค่า ทั้งไฟล์"""
    out = {}
    if not os.path.exists(path):
        return out
    for line in open(path, encoding="utf-8"):
        m = re.match(r"\s*const\s+([A-Z_0-9]+)\s*:?=\s*(.+)", line)
        if m:
            out[m.group(1)] = _num(m.group(2))
    return out


PS = _consts("scripts/core/player_stats.gd")
CB = _consts("scripts/core/combat.gd")
# ช่องกระเป๋าเริ่มต้น (ก่อนบวกจาก STR)
BAG_BASE = int(_consts("scripts/core/player_state.gd").get("INVENTORY_SIZE", 40))


def _job_rows():
    """ตัวคูณของทุกอาชีพ (เติมค่า default จาก job_data.gd ให้ครบ)"""
    defaults = {}
    gd = "scripts/resources/job_data.gd"
    if os.path.exists(gd):
        for line in open(gd, encoding="utf-8"):
            m = re.match(r"\s*@export\s+var\s+(\w+)\s*:\s*\w+\s*=\s*(.+)", line)
            if m:
                defaults[m.group(1)] = _num(m.group(2))
    rows = []
    for p in sorted(glob.glob("data/jobs/*.tres")):
        text = open(p, encoding="utf-8").read()
        j = dict(defaults)
        for k in list(defaults.keys()) + ["display_name"]:
            m = re.search(r"^%s = (.+)$" % re.escape(k), text, re.M)
            if m:
                v = m.group(1).strip()
                j[k] = v.strip('"') if k == "display_name" else _num(v, defaults.get(k, 0.0))
        j["file"] = os.path.basename(p)
        j["display_name"] = j.get("display_name", os.path.basename(p))
        rows.append(j)
    return rows


JOBS = _job_rows()
# อาชีพหลักที่ใช้คิดตัวอย่างตัวเลข (นักดาบ)
MAIN = next((j for j in JOBS if "swordsman" in j["file"]), JOBS[0] if JOBS else {})


def g(k, d=0.0):
    return float(MAIN.get(k, d))


def _fmt(v, unit=""):
    s = ("%.3f" % v).rstrip("0").rstrip(".")
    return (s if s else "0") + unit


# ---------- HP/SP ต่อ 1 แต้ม ที่เลเวลต่าง ๆ (โชว์ให้เห็นว่าโตตามเลเวล) ----------
def hp_per_vit(level):
    base = g("hp_base", 40) + g("hp_per_level", 14) * (level - 1)
    return base * g("hp_vit_percent", 1.0) / 100.0 + PS.get("VIT_HP_FLAT", 0)


def sp_per_int(level):
    base = g("sp_base", 15) + g("sp_per_level", 3) * (level - 1)
    return base * g("sp_int_percent", 1.0) / 100.0 + PS.get("INT_SP_FLAT", 0)


# =========================================================
# ตารางหลัก — สเตตัส 6 ตัว
# แต่ละผล: ชื่อผล · ได้เท่าไรต่อ 1 แต้ม · ค่าคงที่ที่คุมอยู่ · ไฟล์ · หมายเหตุ
# =========================================================
EFFECTS = [
    {
        "id": "str", "name": "STR", "thai": "พลัง", "color": "#e07a5f",
        "summary": "พลังโจมตี + ช่องกระเป๋า — ตัวหลักของสายดาบ",
        "rows": [
            {"what": "ATK", "per": _fmt(PS.get("STR_ATK", 1) * g("atk_mod", 1)),
             "const": "STR_ATK × atk_mod", "file": "player_stats.gd + jobs/*.tres",
             "note": "STR_ATK = %s · นักดาบ atk_mod = %s" % (_fmt(PS.get("STR_ATK", 1)), _fmt(g("atk_mod", 1)))},
            {"what": "ATK โบนัสก้อน", "per": "ทุก 10 แต้ม",
             "const": "(STR/10)² (ฝังในสูตร)", "file": "player_stats.gd บรรทัด status_atk",
             "note": "STR 10 → +1 · 20 → +4 · 30 → +9 · 40 → +16 (คูณ atk_mod อีกที) — ยิ่งอัพเป็นสิบยิ่งคุ้ม"},
            {"what": "ช่องกระเป๋า", "per": "1 ทุก %d แต้ม" % int(PS.get("STR_PER_BAG_SLOT", 5) or 5),
             "const": "STR_PER_BAG_SLOT", "file": "player_stats.gd",
             "note": "ฐาน %d ช่อง · STR %d = %d ช่อง · STR 99 = %d ช่อง — ★ ลด STR แล้วช่องหดลง แต่ของไม่หาย (ระบบย้ายลงช่องว่างก่อน · ถ้าไม่พอจะค้างช่องไว้จนใช้ของออก) ★"
                     % (BAG_BASE, int(PS.get("STR_PER_BAG_SLOT", 5) or 5) * 10,
                        BAG_BASE + 10, BAG_BASE + int(99 / max(1, PS.get("STR_PER_BAG_SLOT", 5))))},
        ],
    },
    {
        "id": "agi", "name": "AGI", "thai": "ความคล่องแคล่ว", "color": "#5cc98f",
        "summary": "หลบเก่ง + ตีถี่ขึ้น",
        "rows": [
            {"what": "FLEE (โอกาสหลบ)", "per": _fmt(PS.get("AGI_FLEE", 1) * g("flee_mod", 1)),
             "const": "AGI_FLEE × flee_mod", "file": "player_stats.gd + jobs/*.tres",
             "note": "FLEE 1 แต้ม = มอนตีพลาดเพิ่ม 1%% ตรง ๆ (สูตร: %s + HIT มอน − FLEE เรา)" % _fmt(CB.get("MONSTER_BASE_HIT_RATE", 72))},
            {"what": "ASPD (ความเร็วโจมตี)", "per": _fmt(g("aspd_base", 1.1) * g("aspd_agi_percent", 1.2) / 100.0, " ครั้ง/วิ"),
             "const": "aspd_agi_percent", "file": "data/jobs/*.tres",
             "note": "= +%s%% ของ ASPD พื้นฐาน (%s ครั้ง/วิ) ต่อแต้ม" % (_fmt(g("aspd_agi_percent", 1.2)), _fmt(g("aspd_base", 1.1)))},
        ],
    },
    {
        "id": "vit", "name": "VIT", "thai": "ความอึด", "color": "#e0a94f",
        "summary": "เลือดหนา + ทนดาเมจ — ★ ยิ่งเลเวลสูง VIT ยิ่งให้ HP เยอะขึ้น ★",
        "rows": [
            {"what": "HP สูงสุด (Lv.1)", "per": _fmt(hp_per_vit(1)),
             "const": "VIT_HP_FLAT + hp_vit_percent", "file": "player_stats.gd + jobs/*.tres",
             "note": "= %s (ตรง ๆ) + %s%% ของ HP พื้นฐาน" % (_fmt(PS.get("VIT_HP_FLAT", 0)), _fmt(g("hp_vit_percent", 1.0)))},
            {"what": "HP สูงสุด (Lv.50)", "per": _fmt(hp_per_vit(50)),
             "const": "— (ค่าเดียวกัน)", "file": "—",
             "note": "ส่วน % คิดจาก HP พื้นฐานซึ่งโตตามเลเวล → VIT แต้มเดียวกันให้ HP มากขึ้นเรื่อย ๆ"},
            {"what": "HP สูงสุด (Lv.99)", "per": _fmt(hp_per_vit(99)),
             "const": "—", "file": "—", "note": ""},
            {"what": "DEF", "per": _fmt(PS.get("VIT_DEF", 0.5) * g("def_mod", 1)),
             "const": "VIT_DEF × def_mod", "file": "player_stats.gd + jobs/*.tres",
             "note": "ปัดเศษลงก่อนคูณ → ได้จริงทุก 2 แต้ม · DEF 100 = ลดดาเมจครึ่งหนึ่ง (100/(100+DEF)) ผลตอบแทนลดหลั่น"},
            {"what": "ฟื้น HP", "per": _fmt(PS.get("VIT_HP_REGEN", 0), "/วิ"),
             "const": "VIT_HP_REGEN", "file": "player_stats.gd", "note": ""},
        ],
    },
    {
        "id": "int", "name": "INT", "thai": "ปัญญา", "color": "#6aa8e0",
        "summary": "มานาและเวทย์ — สายดาบใช้แค่ให้สกิลพอร่าย",
        "rows": [
            {"what": "SP สูงสุด (Lv.1)", "per": _fmt(sp_per_int(1)),
             "const": "INT_SP_FLAT + sp_int_percent", "file": "player_stats.gd + jobs/*.tres",
             "note": "= %s (ตรง ๆ) + %s%% ของ SP พื้นฐาน" % (_fmt(PS.get("INT_SP_FLAT", 0)), _fmt(g("sp_int_percent", 1.0)))},
            {"what": "SP สูงสุด (Lv.50)", "per": _fmt(sp_per_int(50)), "const": "—", "file": "—", "note": ""},
            {"what": "ฟื้น SP", "per": _fmt(PS.get("INT_SP_REGEN", 0), "/วิ"),
             "const": "INT_SP_REGEN", "file": "player_stats.gd",
             "note": "ตัวนี้แรงสุดของ INT สำหรับสายดาบ — ร่ายสกิลถี่ขึ้นชัดเจน"},
            {"what": "MATK", "per": _fmt(1.0 * g("matk_mod", 0.6)),
             "const": "matk_mod", "file": "data/jobs/*.tres",
             "note": "+ โบนัสก้อนทุก 7 แต้ม (INT/7)² · นักดาบ matk_mod = %s จึงแทบไม่มีผล" % _fmt(g("matk_mod", 0.6))},
            {"what": "MDEF", "per": _fmt(PS.get("INT_MDEF", 0.5)),
             "const": "INT_MDEF", "file": "player_stats.gd",
             "note": "ปัดเศษลง → ได้จริงทุก 2 แต้ม · ไม่มีตัวคูณอาชีพ"},
        ],
    },
    {
        "id": "dex", "name": "DEX", "thai": "ความแม่นยำ", "color": "#c9a0e0",
        "summary": "ตีไม่พลาด + ร่ายสกิลถี่ขึ้น — ★ แต้มแรก ๆ คุ้มที่สุดถ้ารู้สึกว่าตีพลาดบ่อย ★",
        "rows": [
            {"what": "HIT (ความแม่น)", "per": _fmt(PS.get("HIT_PER_DEX", 1.5) * g("hit_mod", 1)),
             "const": "HIT_PER_DEX × hit_mod", "file": "player_stats.gd + jobs/*.tres",
             "note": "HIT 1 แต้ม = โอกาสตีเข้าเพิ่ม 1%% ตรง ๆ (สูตร: %s + HIT เรา − FLEE มอน · เพดาน %s%%)"
                     % (_fmt(CB.get("BASE_HIT_RATE", 85)), _fmt(CB.get("MAX_HIT_RATE", 98)))},
            {"what": "ATK", "per": _fmt(PS.get("DEX_ATK", 0.2) * g("atk_mod", 1)),
             "const": "DEX_ATK × atk_mod", "file": "player_stats.gd + jobs/*.tres", "note": ""},
            {"what": "ASPD", "per": _fmt(g("aspd_base", 1.1) * PS.get("DEX_ASPD", 0.004), " ครั้ง/วิ"),
             "const": "DEX_ASPD", "file": "player_stats.gd",
             "note": "= +%s%% ของ ASPD พื้นฐาน ต่อแต้ม (น้อยกว่า AGI ประมาณ 3 เท่า)" % _fmt(PS.get("DEX_ASPD", 0.004) * 100)},
            {"what": "ลดคูลดาวน์สกิล", "per": "1%% ทุก %d แต้ม" % int(PS.get("DEX_PER_COOLDOWN", 5) or 5),
             "const": "DEX_PER_COOLDOWN", "file": "player_stats.gd",
             "note": "DEX 50 = ลด 10%% · DEX 99 = ลด %d%% · เพดาน %s%% (MAX_COOLDOWN_REDUCTION) · ของสวมใส่เพิ่มได้ด้วยคีย์ cooldown_reduction_percent"
                     % (int(99 / max(1, PS.get("DEX_PER_COOLDOWN", 5))), _fmt(PS.get("MAX_COOLDOWN_REDUCTION", 50)))},
        ],
    },
    {
        "id": "luk", "name": "LUK", "thai": "โชค", "color": "#e0c94f",
        "summary": "คริติคอล — ★ คริทะลุ DEF ทั้งหมด ยิ่งตีมอนเกราะหนายิ่งคุ้ม ★",
        "rows": [
            {"what": "CRIT (โอกาสคริ)", "per": _fmt(PS.get("LUK_CRIT", 0.3), "%"),
             "const": "LUK_CRIT", "file": "player_stats.gd",
             "note": "คริ = ข้าม DEF ของเป้าหมายทั้งหมด แล้วคูณดาเมจ ×1.5 (crit_damage)"},
            {"what": "ATK", "per": _fmt(PS.get("LUK_ATK", 0.333) * g("atk_mod", 1)),
             "const": "LUK_ATK × atk_mod", "file": "player_stats.gd + jobs/*.tres", "note": ""},
        ],
    },
]

# =========================================================
# ค่าที่ได้จาก "เลเวล" (ไม่ใช่สเตตัส) — ไว้เทียบว่าอัพสเตตัสคุ้มแค่ไหน
# =========================================================
LEVEL_GAIN = [
    {"what": "แต้มสเตตัส", "per": "3 + (เลเวล ÷ 5)", "note": "Lv.10 ได้ 5 แต้ม · Lv.50 ได้ 13 แต้ม (`add_exp`)"},
    {"what": "ATK", "per": "+0.25 × atk_mod", "note": "สูตร status_atk มี level/4 อยู่"},
    {"what": "HIT", "per": "+1", "note": "100 + level + DEX×%s" % _fmt(PS.get("HIT_PER_DEX", 1.5))},
    {"what": "FLEE", "per": "+1", "note": "100 + level + AGI×%s" % _fmt(PS.get("AGI_FLEE", 1))},
    {"what": "HP สูงสุด", "per": "+%s × (1 + VIT×%s%%)" % (_fmt(g("hp_per_level", 14)), _fmt(g("hp_vit_percent", 1.0))),
     "note": "hp_per_level ในไฟล์อาชีพ"},
    {"what": "SP สูงสุด", "per": "+%s × (1 + INT×%s%%)" % (_fmt(g("sp_per_level", 3)), _fmt(g("sp_int_percent", 1.0))),
     "note": "sp_per_level ในไฟล์อาชีพ"},
]

JOB_LEVEL_GAIN = [
    {"what": "แต้มสกิล", "per": "+1", "note": "ทุกระดับ (`add_job_exp`)"},
    {"what": "ATK", "per": "+1", "note": "บวกตรง ๆ ไม่คูณ atk_mod"},
    {"what": "HIT", "per": "+1", "note": ""},
    {"what": "DEF", "per": "+1 ทุก 2 ระดับ", "note": "Job Lv.50 = DEF +24"},
]

COST = {
    "formula": "((แต้มปัจจุบัน − 1) ÷ 10) + 2",
    "note": "ปัดเศษลง — 1→10 จ่ายแต้มละ 2 · 11→20 จ่าย 3 · 21→30 จ่าย 4 … สูงสุด %d" % int(PS.get("MAX_STAT", 99)),
    "table": [{"range": "1 → 10", "cost": 2}, {"range": "11 → 20", "cost": 3},
              {"range": "21 → 30", "cost": 4}, {"range": "31 → 40", "cost": 5},
              {"range": "41 → 50", "cost": 6}, {"range": "51 → 60", "cost": 7}],
}

FORMULAS = [
    {"name": "โอกาสตีเข้า (ผู้เล่น → มอน)",
     "text": "%s + HIT ของเรา − FLEE ของมอน" % _fmt(CB.get("BASE_HIT_RATE", 85)),
     "note": "จำกัด %s%% ถึง %s%% · มอนเลเวลต่ำกว่า %d โดนลดค่าหลบ %s%%"
             % (_fmt(CB.get("MIN_HIT_RATE", 5)), _fmt(CB.get("MAX_HIT_RATE", 98)),
                int(CB.get("LOW_LEVEL_FLEE_CAP", 15)), _fmt(CB.get("LOW_LEVEL_FLEE_REDUCTION", 0.2) * 100))},
    {"name": "โอกาสมอนตีเราเข้า",
     "text": "%s + HIT ของมอน − FLEE ของเรา" % _fmt(CB.get("MONSTER_BASE_HIT_RATE", 72)),
     "note": "ฐานคนละตัวกับฝั่งเรา — ปรับความแม่นของเราได้โดยมอนไม่แม่นตาม"},
    {"name": "ลดดาเมจจาก DEF", "text": "ดาเมจ × 100 ÷ (100 + DEF)",
     "note": "DEF 50 = ลด 33% · DEF 100 = ลด 50% · DEF 200 = ลด 67% (ผลตอบแทนลดหลั่น)"},
    {"name": "คริติคอล", "text": "ข้าม DEF ทั้งหมด แล้ว × crit_damage (1.5)",
     "note": "ยิ่งเป้าหมาย DEF สูง คริยิ่งได้เปรียบ"},
    {"name": "ดาเมจแกว่ง", "text": "× สุ่ม %s ถึง %s" % (_fmt(1 - CB.get("DAMAGE_VARIANCE", 0.12)), _fmt(1 + CB.get("DAMAGE_VARIANCE", 0.12))),
     "note": "DAMAGE_VARIANCE ใน combat.gd"},
    {"name": "เวลาระหว่างตี 1 ครั้ง", "text": "1 ÷ ASPD วินาที",
     "note": "ASPD %s ครั้ง/วิ = ตีทุก %s วิ" % (_fmt(g("aspd_base", 1.1)), _fmt(1.0 / max(0.1, g("aspd_base", 1.1))))},
]

data_json["stats"] = {
    "effects": EFFECTS,
    "levelGain": LEVEL_GAIN,
    "jobLevelGain": JOB_LEVEL_GAIN,
    "cost": COST,
    "formulas": FORMULAS,
    "consts": {k: PS[k] for k in sorted(PS)},
    "combatConsts": {k: CB[k] for k in sorted(CB)},
    "jobs": JOBS,
    "mainJob": MAIN.get("display_name", ""),
    "maxLevel": int(PS.get("MAX_LEVEL", 99)),
    "maxJobLevel": int(PS.get("MAX_JOB_LEVEL", 50)),
    "moveSpeed": PS.get("BASE_MOVE_SPEED", 430),
}
print("สเตตัส: อ่านค่าคงที่ %d ตัว · อาชีพ %d · ตัวอย่างคิดจาก %s"
      % (len(PS) + len(CB), len(JOBS), MAIN.get("display_name", "-")))
