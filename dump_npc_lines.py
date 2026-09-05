#!/usr/bin/env python3
"""ดึง "คำพูด NPC ทุกประโยค" ออกมาเป็นรายการ พร้อมชื่อไฟล์เสียงพากย์ที่ระบบจะเรียก (รอบ 59)

    python3 dump_npc_lines.py                 → พิมพ์สรุปบนจอ + เขียน  _to_delete/npc_lines.md  และ  _to_delete/npc_lines.csv
    python3 dump_npc_lines.py --out โฟลเดอร์  → เขียนไปที่อื่น

หลักการตั้งชื่อไฟล์เสียง (VoicePlayer):  Sprites/voice/<voice_id>/<key>.ogg
  greeting                  ประโยคทักตอนเปิดเมนู
  dialog_1, dialog_2 ...    บทคุยเล่น (แต่ละ "หน้า" = คั่นด้วยบรรทัดว่าง)
  <ธง>_1, <ธง>_2 ...        บทพูดตามธงเนื้อเรื่อง (dialog_by_flag)
  <เควส>_offer_1 ...        ตอนชวนรับเควส (หน้า 1 = dialog_offer · หน้า 2 = description ถ้ามี)
  <เควส>_offer_ask          "เอาไงล่ะ รับงานนี้มั้ย"
  <เควส>_progress           ตอนยังทำไม่ครบ
  <เควส>_complete           ตอนส่งเควส
  <เควส>_choice             คำถามตัวเลือกหลังส่งเควส
  <เควส>_cutscene_1 ...     ฉากแพนกล้อง (คนพูดคือ NPC ใน cutscene_pan_npc)
  heal_full · heal_poor · heal_done   หมอ (เลือดเต็ม / เงินไม่พอ / รักษาแล้ว)
voice_id = ค่าในช่อง Voice Id ของ NPC (ใส่ให้ทั้งหมดด้วย  python3 set_npc_voice.py)
"""
import re, glob, os, sys, csv, json
try:
    from set_npc_voice import voice_id_for      # ตาราง npc_name → voice_id (ตัวเดียวกับที่ใส่ในฉาก)
except Exception:
    def voice_id_for(npc_name, node_name, map_name=""):
        return node_name.lower()

OUT_DIR = "_to_delete"
if "--out" in sys.argv:
    OUT_DIR = sys.argv[sys.argv.index("--out") + 1]

TYPE_NAMES = {0: "คุย", 1: "ร้านค้า", 2: "ช่างตีเหล็ก", 3: "หมอ", 4: "เสาวาป", 5: "เควส"}
ASK_LINE = "เอาไงล่ะ รับงานนี้มั้ย"


def unquote(s):
    return s.replace('\\"', '"').replace("\\n", "\n")


def parse_str(block, key):
    m = re.search(r'\n%s = "((?:[^"\\]|\\.)*)"' % key, block)
    return unquote(m.group(1)) if m else None


def parse_multiline(block, key):
    # ค่าแบบหลายบรรทัด: key = "....\n...."
    m = re.search(r'\n%s = "((?:[^"\\]|\\.)*)"' % key, block, re.S)
    return unquote(m.group(1)) if m else None


def parse_dict(block, key):
    m = re.search(r'\n%s = \{(.*?)\n\}' % key, block, re.S)
    if not m:
        m = re.search(r'\n%s = \{(.*?)\}' % key, block, re.S)
    if not m:
        return {}
    body = m.group(1)
    out = {}
    for km in re.finditer(r'"([^"]+)":\s*"((?:[^"\\]|\\.)*)"', body, re.S):
        out[km.group(1)] = unquote(km.group(2))
    return out


def parse_array(block, key):
    m = re.search(r'\n%s = Array\[StringName\]\(\[([^\]]*)\]\)' % key, block)
    if not m:
        return []
    return re.findall(r'&"([^"]+)"', m.group(1))


def pages(text):
    return [p.strip() for p in re.split(r"\n\s*\n", text or "") if p.strip()]


def load_quests():
    qs = {}
    for f in sorted(glob.glob("data/quests/*.tres")):
        s = open(f, encoding="utf-8").read()
        qid = re.search(r'\nid = &"([^"]+)"', s)
        if not qid:
            continue
        q = {"id": qid.group(1), "file": f}
        for k in ["title", "description", "giver_name", "dialog_offer", "dialog_progress",
                  "dialog_complete", "choice_prompt", "cutscene_pan_npc", "cutscene_text"]:
            q[k] = parse_multiline(s, k) or ""
        opts = re.search(r'\nchoice_options = Array\[String\]\(\[([^\]]*)\]\)', s)
        q["choice_options"] = re.findall(r'"([^"]*)"', opts.group(1)) if opts else []
        qs[q["id"]] = q
    return qs


def main():
    quests = load_quests()
    rows = []        # (map, node, npc_name, voice_id, key, speaker, text, context)
    npc_by_name = {}

    for f in sorted(glob.glob("scenes/maps/*.tscn")):
        s = open(f, encoding="utf-8").read()
        mapname = os.path.basename(f)[:-5]
        for block in re.split(r"\n(?=\[node )", s):
            if 'instance=ExtResource("npc")' not in block and "scripts/world/npc.gd" not in block:
                continue
            node = re.search(r'\[node name="([^"]+)"', block).group(1)
            npc_name = parse_str(block, "npc_name") or "พ่อค้า"
            vm = re.search(r'\nvoice_id = "([^"]*)"', block)
            voice_id = vm.group(1) if vm else voice_id_for(npc_name, node, mapname)
            if voice_id == "":
                continue            # NPC ที่ไม่มีเสียงพากย์ (เช่นเสาวาป)
            tm = re.search(r"\ntype = (\d+)", block)
            typ = int(tm.group(1)) if tm else 1
            greeting = parse_str(block, "greeting") or "มีอะไรให้ช่วยไหม"
            dialog = parse_multiline(block, "dialog") or "สวัสดี นักผจญภัย"
            by_flag = parse_dict(block, "dialog_by_flag")
            qids = parse_array(block, "quest_ids")
            npc_by_name[npc_name] = voice_id

            def add(key, text, ctx):
                rows.append({"map": mapname, "node": node, "npc": npc_name, "voice_id": voice_id,
                             "key": key, "text": text, "context": ctx})

            if typ != 4:
                add("greeting", greeting, "ทักตอนเดินเข้าไปกด F (ก่อนเมนู พูดคุย/ซื้อขาย)")
            if typ == 3:
                add("heal_full", "เลือดกับพลังเต็มอยู่แล้วนะ", "หมอ: HP/SP เต็มอยู่แล้ว")
                add("heal_poor", "ค่ารักษา %d ซีนี ซีนีไม่พอนะ", "หมอ: เงินไม่พอ (ตัวเลขใส่เอง)")
                add("heal_done", "หายดีแล้ว!", "หมอ: รักษาเสร็จ")
            if typ not in (3, 4):
                for i, p in enumerate(pages(dialog), 1):
                    add("dialog_%d" % i, p, "คุยเล่น หน้า %d" % i)
                for flag, txt in by_flag.items():
                    for i, p in enumerate(pages(txt), 1):
                        add("%s_%d" % (flag, i), p, "บทพูดหลังมีธง %s หน้า %d" % (flag, i))
            for qid in qids:
                q = quests.get(qid)
                if not q:
                    continue
                qp = pages(q["dialog_offer"]) or [q["dialog_offer"]]
                n = 0
                for p in qp:
                    n += 1
                    add("%s_offer_%d" % (qid, n), p, "เควส [%s] ชวนรับ" % q["title"])
                if q["description"] and q["description"] != q["dialog_offer"]:
                    n += 1
                    add("%s_offer_%d" % (qid, n), q["description"], "เควส [%s] อธิบายงาน" % q["title"])
                add("%s_offer_ask" % qid, ASK_LINE, "เควส [%s] ถามรับไหม" % q["title"])
                add("%s_progress" % qid, q["dialog_progress"], "เควส [%s] ยังไม่ครบ" % q["title"])
                add("%s_complete" % qid, q["dialog_complete"], "เควส [%s] ส่งเควส" % q["title"])
                if q["choice_prompt"]:
                    add("%s_choice" % qid, q["choice_prompt"], "เควส [%s] ตัวเลือก: %s" % (q["title"], " / ".join(q["choice_options"])))
                if q["cutscene_text"]:
                    for i, p in enumerate(pages(q["cutscene_text"]), 1):
                        rows.append({"map": mapname, "node": "(cutscene)", "npc": q["cutscene_pan_npc"],
                                     "voice_id": "@" + q["cutscene_pan_npc"],
                                     "key": "%s_cutscene_%d" % (qid, i), "text": p,
                                     "context": "เควส [%s] ฉากแพนกล้องไปหา %s หน้า %d" % (q["title"], q["cutscene_pan_npc"], i)})

    # cutscene speaker → voice_id ของ NPC คนนั้น (ถ้ามีในฉาก)
    for r in rows:
        if r["voice_id"].startswith("@"):
            r["voice_id"] = npc_by_name.get(r["voice_id"][1:], r["voice_id"][1:].lower())

    order = []
    for r in rows:
        if r["voice_id"] not in order:
            order.append(r["voice_id"])
    rows.sort(key=lambda r: order.index(r["voice_id"]))

    os.makedirs(OUT_DIR, exist_ok=True)
    with open(os.path.join(OUT_DIR, "npc_lines.csv"), "w", encoding="utf-8-sig", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["แมพ", "โหนด", "NPC", "voice_id", "ไฟล์เสียง (Sprites/voice/<voice_id>/<key>.ogg)", "บริบท", "คำพูด"])
        for r in rows:
            w.writerow([r["map"], r["node"], r["npc"], r["voice_id"], r["key"] + ".ogg", r["context"], r["text"]])

    with open(os.path.join(OUT_DIR, "npc_lines.md"), "w", encoding="utf-8") as fh:
        fh.write("# คำพูด NPC ทั้งหมด (สร้างโดย dump_npc_lines.py)\n\n")
        fh.write("ไฟล์เสียงวางที่ `Sprites/voice/<voice_id>/<key>.ogg` (หรือ .wav/.mp3) — ไม่มีไฟล์ = เงียบ ไม่ error\n\n")
        cur = None
        for r in rows:
            head = (r["map"], r["npc"], r["voice_id"])
            if head != cur:
                cur = head
                fh.write("\n## %s — %s   (voice_id: `%s`)\n\n" % (r["map"], r["npc"], r["voice_id"]))
                fh.write("| ไฟล์ | บริบท | คำพูด |\n|---|---|---|\n")
            fh.write("| `%s.ogg` | %s | %s |\n" % (r["key"], r["context"], r["text"].replace("\n", " ").replace("|", "／")))

    print("NPC %d ประโยค → %s/npc_lines.md, npc_lines.csv" % (len(rows), OUT_DIR))
    by_npc = {}
    for r in rows:
        by_npc.setdefault((r["npc"], r["voice_id"]), 0)
        by_npc[(r["npc"], r["voice_id"])] += 1
    for (n, v), c in by_npc.items():
        print("  %-28s voice_id=%-16s %d ประโยค" % (n, v, c))


if __name__ == "__main__":
    main()
