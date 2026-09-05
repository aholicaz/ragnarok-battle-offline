#!/usr/bin/env python3
"""ใส่ voice_id ให้ NPC ทุกตัวในฉาก scenes/maps/*.tscn (รอบ 59) — รันในโฟลเดอร์โปรเจกต์

    python3 set_npc_voice.py           → ใส่ตามตาราง VOICE_IDS (ชื่อ NPC → โฟลเดอร์เสียง)
    python3 set_npc_voice.py --show    → แค่ดูว่าใครได้ id อะไร ไม่แก้ไฟล์

ตัวเดิมที่มี voice_id อยู่แล้วจะไม่ถูกเขียนทับ · NPC ที่ไม่อยู่ในตารางจะได้ id จากชื่อโหนด (ตัวพิมพ์เล็ก)
สำรองไฟล์เดิมไว้ที่ _to_delete/originals_maps_voice/
"""
import re, glob, os, sys, shutil

## ★ ชื่อ NPC (ช่อง npc_name) → โฟลเดอร์เสียง Sprites/voice/<id>/ ★
## ตัวละครเดียวกันที่อยู่หลายแมพ (เช่นฮันส์) ใช้ id เดียวกัน → อัดเสียงชุดเดียว
VOICE_IDS = {
    "พ่อค้าโทนี่": "tony",
    "ช่างตีเหล็กฮันส์": "hans",
    "นักบวชหญิงมาเรีย": "maria",
    "ทหารยามเอริค": "erik",
    "นักบวชสูงสุดวาลเดอร์": "valder",
    "ตาแก่กุนนาร์": "gunnar",
    "อิงกริด": "ingrid",
    "หัวหน้ากิลด์บียอร์น": "bjorn",
    "นายหน้าเฮลกา": "helga",
    "ช่างเอกดวาลิน": "dvalin",
    "บรอกก์": "brokk",
    "หมอคนแคระเฮดิน": "hedin",
    "เสาวาปแห่งธอร์": "",          # เสาวาปไม่พูด
}


## ★ ตัวละครเดิมแต่ "บทคุยเล่นคนละชุด" ในอีกแมพ → ต้องแยกโฟลเดอร์ ไม่งั้นไฟล์ dialog_1.ogg ชนกัน ★
## key = "<ชื่อแมพ>/<ชื่อโหนด>"  (ฮันส์ในนิดาเวลลีร์ = บท 2 คุยคนละเรื่องกับในพรอนเทรา)
VOICE_IDS_BY_NODE = {
    "nidavellir_town/Hans": "hans_c2",
}


def voice_id_for(npc_name, node_name, map_name=""):
    if map_name and "%s/%s" % (map_name, node_name) in VOICE_IDS_BY_NODE:
        return VOICE_IDS_BY_NODE["%s/%s" % (map_name, node_name)]
    if npc_name in VOICE_IDS:
        return VOICE_IDS[npc_name]
    return node_name.lower()


def main():
    show = "--show" in sys.argv
    backup_dir = "_to_delete/originals_maps_voice"
    for f in sorted(glob.glob("scenes/maps/*.tscn")):
        s = open(f, encoding="utf-8").read()
        if 'path="res://scenes/npc/npc.tscn"' not in s and "scripts/world/npc.gd" not in s:
            continue
        parts = re.split(r"(\n(?=\[node ))", s)
        changed = False
        out = []
        for part in parts:
            if part.startswith("[node ") and ('instance=ExtResource("npc")' in part or "npc.gd" in part):
                node = re.search(r'\[node name="([^"]+)"', part).group(1)
                nm = re.search(r'\nnpc_name = "((?:[^"\\]|\\.)*)"', part)
                npc_name = nm.group(1) if nm else "พ่อค้า"
                vid = voice_id_for(npc_name, node, os.path.basename(f)[:-5])
                has = re.search(r'\nvoice_id = "([^"]*)"', part)
                print("%-22s %-24s %-22s → %s%s" % (os.path.basename(f), node, npc_name, vid or "(ไม่มีเสียง)",
                      "   (มีอยู่แล้ว: %s)" % has.group(1) if has else ""))
                if not has and vid and not show:
                    # แทรกต่อท้ายบรรทัด npc_name (หรือหลังหัวโหนดถ้าไม่มี)
                    if nm:
                        part = part.replace(nm.group(0), nm.group(0) + '\nvoice_id = "%s"' % vid, 1)
                    else:
                        head_end = part.index("\n")
                        part = part[:head_end] + '\nvoice_id = "%s"' % vid + part[head_end:]
                    changed = True
            out.append(part)
        if changed:
            os.makedirs(backup_dir, exist_ok=True)
            bak = os.path.join(backup_dir, os.path.basename(f))
            if not os.path.exists(bak):
                shutil.copy2(f, bak)
            open(f, "w", encoding="utf-8").write("".join(out))
            print("  แก้แล้ว:", f)


if __name__ == "__main__":
    main()
