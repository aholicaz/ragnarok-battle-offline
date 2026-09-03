#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""รอบ 47 — ราคาของสวมใส่: ซื้อ ×5 · ขาย ÷2

ใช้กับไอเทมชนิด "อาวุธ" (type = 1) และ "ของสวมใส่" (type = 2) ทุกชิ้นใน data/items/
  buy_price  = ฐาน × 5
  sell_price = ฐาน ÷ 2  (ปัดลง · ต่ำสุด 1)

★ รันซ้ำได้ (idempotent) ★ ครั้งแรกจะจำ "ราคาฐานก่อนรอบ 47" ลง metadata ของไฟล์
    metadata/price_base_r47_buy   ราคาซื้อเดิม
    metadata/price_base_r47_sell  ราคาขายเดิม
รอบถัด ๆ ไปคำนวณจากฐานนั้นเสมอ → รันกี่ครั้งราคาก็เท่ากัน (ไม่ทวีคูณ)
อยากย้อนกลับ: เอาค่าใน metadata ใส่คืน buy_price/sell_price แล้วลบ 2 บรรทัดนั้นทิ้ง

    python3 rebalance_r47_prices.py           # ดูก่อนว่าจะเปลี่ยนอะไร (ไม่แตะไฟล์)
    python3 rebalance_r47_prices.py --apply   # แก้จริง
"""
import re, sys, pathlib

ROOT = pathlib.Path('.')
BUY_MULT = 5
SELL_DIV = 2
WEARABLE = {1, 2}          # 1 = อาวุธ · 2 = ของสวมใส่ (ItemData.Type)
DEF_BUY, DEF_SELL = 100, 40   # ค่า default ใน item_data.gd (ไฟล์ .tres ไม่เก็บค่าที่เท่า default)
apply = "--apply" in sys.argv


def prop(text, name):
    m = re.search(r'^%s = (.+)$' % re.escape(name), text, re.M)
    return m.group(1).strip() if m else None


def set_prop(text, name, value):
    """ตั้งค่า property ใน [resource] — ไม่มีบรรทัดนั้นก็แทรกให้ (ต่อจาก type = N)"""
    line = "%s = %s" % (name, value)
    if re.search(r'^%s = .+$' % re.escape(name), text, re.M):
        return re.sub(r'^%s = .+$' % re.escape(name), line, text, count=1, flags=re.M)
    m = re.search(r'^type = .+$', text, re.M)
    if m:
        return text[:m.end()] + "\n" + line + text[m.end():]
    return text.rstrip("\n") + "\n" + line + "\n"


rows, changed = [], 0
for path in sorted(ROOT.glob("data/items/*.tres")):
    text = path.read_text(encoding="utf-8")
    t = prop(text, "type")
    if t is None or not t.isdigit() or int(t) not in WEARABLE:
        continue
    iid = (prop(text, "id") or "").strip('&"')
    name = (prop(text, "display_name") or "").strip('"')

    cur_buy = int(prop(text, "buy_price") or DEF_BUY)
    cur_sell = int(prop(text, "sell_price") or DEF_SELL)
    base_buy = int(prop(text, "metadata/price_base_r47_buy") or cur_buy)
    base_sell = int(prop(text, "metadata/price_base_r47_sell") or cur_sell)

    new_buy = base_buy * BUY_MULT
    new_sell = max(1, base_sell // SELL_DIV)
    rows.append((iid or path.stem, name, base_buy, new_buy, base_sell, new_sell,
                 cur_buy != new_buy or cur_sell != new_sell))

    out = set_prop(text, "metadata/price_base_r47_buy", str(base_buy))
    out = set_prop(out, "metadata/price_base_r47_sell", str(base_sell))
    out = set_prop(out, "buy_price", str(new_buy))
    out = set_prop(out, "sell_price", str(new_sell))
    if out != text:
        changed += 1
        if apply:
            path.write_text(out, encoding="utf-8")


print("%-22s %-26s %10s %10s   %8s %8s" % ("id", "ชื่อ", "ซื้อเดิม", "ซื้อใหม่", "ขายเดิม", "ขายใหม่"))
for iid, name, b0, b1, s0, s1, diff in rows:
    print("%-22s %-26s %10d %10d   %8d %8d %s" % (iid, name[:26], b0, b1, s0, s1, "" if diff else "(เท่าเดิม)"))
print("\nของสวมใส่ %d ชิ้น · ต้องแก้ %d ไฟล์%s" % (
    len(rows), changed, "" if apply else "  (ใส่ --apply เพื่อแก้จริง)"))
