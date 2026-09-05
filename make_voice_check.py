#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""สร้างหน้าเว็บ "ตรวจเสียงพากย์" ไว้ฟังทีละประโยคว่าตัดตรงกับบทไหม (รอบ 61)

    python3 make_voice_check.py --voice hans
    python3 make_voice_check.py --voice hans --out _to_delete/ตรวจเสียง_hans.html

เปิดไฟล์ที่ได้ด้วยเบราว์เซอร์ (ดับเบิลคลิก) → กดฟังทีละอัน เทียบกับข้อความข้าง ๆ
เสียงฝังอยู่ในไฟล์ HTML แล้ว ส่งต่อ/เปิดที่ไหนก็ได้ ไม่ต้องมีไฟล์ .ogg ตามไปด้วย
"""
import os, sys, csv, base64, html, glob

args = sys.argv[1:]
def opt(n, d=None): return args[args.index(n) + 1] if n in args else d
VOICE = opt("--voice", "")
VDIR = os.path.join(opt("--dir", "Sprites/voice"), VOICE)
CSV = opt("--csv", "_to_delete/npc_lines.csv")
OUT = opt("--out", "_to_delete/ตรวจเสียง_%s.html" % VOICE)

if not VOICE:
    sys.exit(__doc__)

rows = []
for r in csv.DictReader(open(CSV, encoding="utf-8-sig")):
    if r["voice_id"] != VOICE:
        continue
    key = [v for k, v in r.items() if k.startswith("ไฟล์เสียง")][0].replace(".ogg", "")
    rows.append({"key": key, "npc": r["NPC"], "ctx": r["บริบท"], "text": r["คำพูด"]})

have = {os.path.basename(p)[:-4] for p in glob.glob(os.path.join(VDIR, "*.ogg"))}
npc = rows[0]["npc"] if rows else VOICE

items = []
for i, r in enumerate(rows, 1):
    p = os.path.join(VDIR, r["key"] + ".ogg")
    if os.path.exists(p):
        b64 = base64.b64encode(open(p, "rb").read()).decode()
        player = '<audio controls preload="none" src="data:audio/ogg;base64,%s"></audio>' % b64
        cls, tag = "ok", "%.0f KB" % (os.path.getsize(p) / 1024)
    else:
        player = '<span class="none">— ยังไม่มีไฟล์เสียง —</span>'
        cls, tag = "missing", "ขาด"
    items.append("""
  <tr class="%s">
    <td class="num">%d</td>
    <td class="file"><code>%s.ogg</code><div class="tag">%s</div></td>
    <td class="ctx">%s</td>
    <td class="text">%s</td>
    <td class="play">%s</td>
  </tr>""" % (cls, i, html.escape(r["key"]), tag, html.escape(r["ctx"]),
              html.escape(r["text"]).replace("\n", "<br>"), player))

doc = """<!doctype html><html lang="th"><head><meta charset="utf-8">
<title>ตรวจเสียงพากย์ %s</title>
<style>
 body{font-family:"Segoe UI",Tahoma,sans-serif;background:#151a24;color:#e6ebf5;margin:0;padding:24px}
 h1{font-size:20px;margin:0 0 4px} .sub{color:#93a1bd;font-size:13px;margin-bottom:18px}
 table{border-collapse:collapse;width:100%%;max-width:1180px}
 td,th{border-bottom:1px solid #263049;padding:10px 8px;vertical-align:top}
 th{color:#93a1bd;font-size:12px;text-align:left;font-weight:600}
 .num{color:#6c7a95;width:26px} .file code{color:#ffd54a;font-size:12px}
 .tag{color:#6c7a95;font-size:11px;margin-top:2px}
 .ctx{color:#93a1bd;font-size:12px;width:210px}
 .text{font-size:14px;line-height:1.5;max-width:430px}
 .play{width:290px} audio{width:280px;height:34px}
 tr.missing .text{opacity:.5} .none{color:#ff8a8a;font-size:12px}
 .hint{background:#1c2436;border-left:3px solid #ffd54a;padding:10px 14px;margin:16px 0;font-size:13px;line-height:1.6;max-width:1150px}
</style></head><body>
<h1>ตรวจเสียงพากย์ — %s <span style="color:#6c7a95;font-weight:400">(โฟลเดอร์ %s)</span></h1>
<div class="sub">กดฟังทีละอัน แล้วดูว่าตรงกับข้อความข้าง ๆ ไหม · ถ้าสลับกันให้บอกได้เลยว่าอันไหนควรเป็นอันไหน</div>
<div class="hint">ไฟล์เสียงอยู่ที่ <code>Sprites/voice/%s/&lt;ชื่อประโยค&gt;.ogg</code> — อยากเปลี่ยนอันไหนก็เอาไฟล์ใหม่ทับชื่อเดิมได้เลย ไม่ต้องแก้โค้ด</div>
<table><tr><th></th><th>ไฟล์</th><th>เล่นตอน</th><th>คำพูด</th><th>ฟัง</th></tr>%s</table>
</body></html>""" % (npc, npc, VDIR, VOICE, "".join(items))

os.makedirs(os.path.dirname(OUT) or ".", exist_ok=True)
open(OUT, "w", encoding="utf-8").write(doc)
print("เขียน %s  (%.1f MB · %d ประโยค · มีเสียงแล้ว %d)"
      % (OUT, os.path.getsize(OUT) / 1048576, len(rows), len(have)))
