#!/usr/bin/env python3
"""รอบ 44 — ปรับอัตราดรอป (ไล่ระดับตามเลเวลมอน) + ราคาขายการ์ด/ของสวมใส่

กติกา (ตามที่สั่ง):
  การ์ดมอนธรรมดา  0.9% (Lv1) → 0.5% (Lv50)
  การ์ดบอส        2.5% (Lv1) → 2.0% (Lv50)
  ของสวมใส่ (อาวุธ/เกราะ)  3% → 1%
  หินตีบวก (phracon / emveretarcon)  5% → 1%
  ราคาขายการ์ด 500 · การ์ดบอส 1000
  ราคาขายของสวมใส่ ×4 (+300%) — ★ เพดาน 80% ของราคาซื้อ (ทุกชิ้น) กันซื้อมาขายกลับได้กำไร ★
ไล่ตามเลเวล: t = (level-1)/(50-1) แล้ว lerp(สูง, ต่ำ, t) — ปัดทศนิยม 2 ตำแหน่ง · ไม่มีการ 'เพิ่ม' (ของที่เดิมต่ำกว่าสูตร คงเดิม)
รันซ้ำได้ (idempotent) — คำนวณจากเลเวล/ชนิดล้วน ๆ ไม่ได้อิงค่าเดิม
"""
import re, sys, pathlib, json

ROOT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '.')
LV_MAX = 50.0
CARD = (0.9, 0.5)
BOSS_CARD = (2.5, 2.0)
EQUIP = (3.0, 1.0)
STONE = (5.0, 1.0)
STONES = {'phracon', 'emveretarcon'}
CARD_SELL, BOSS_CARD_SELL = 500, 1000
EQUIP_SELL_MULT = 4.0
SHOP_CAP = 0.8   # ราคาขายคืนไม่เกิน 80% ของราคาซื้อ (ทุกชิ้นที่มี buy_price)


def lerp(hi_lo, lv):
    t = max(0.0, min(1.0, (lv - 1) / (LV_MAX - 1)))
    return round(hi_lo[0] + (hi_lo[1] - hi_lo[0]) * t, 2)


def fmt(v):
    s = ('%.2f' % v).rstrip('0').rstrip('.')
    return s if '.' in s else s + '.0'


def prop(text, name, default=None):
    m = re.search(r'^%s = (.+)$' % re.escape(name), text, re.M)
    return m.group(1).strip() if m else default


# ---------- ไอเทม: ชนิด + ร้านค้า ----------
items = {}
for p in list((ROOT / 'data/items').glob('*.tres')) + list((ROOT / 'data/cards').glob('*.tres')):
    s = p.read_text(encoding='utf8')
    iid = prop(s, 'id', '&"%s"' % p.stem).strip('&"')
    items[iid] = {'path': p, 'type': int(prop(s, 'type', '3')), 'buy': int(prop(s, 'buy_price', '100')),
                  'sell': int(prop(s, 'sell_price', '40'))}

shop_items = set()
for p in (ROOT / 'scenes/maps').glob('*.tscn'):
    s = p.read_text(encoding='utf8')
    for m in re.finditer(r'shop_items = Array\[StringName\]\(\[([^\]]*)\]\)', s):
        shop_items |= set(x.strip().strip('&"') for x in m.group(1).split(',') if x.strip())
    for m in re.finditer(r'shop_items = \[([^\]]*)\]', s):
        shop_items |= set(x.strip().strip('&"') for x in m.group(1).split(',') if x.strip())

# ---------- มอน: บอส/เลเวล ----------
mon_info = {}
changes = []
for p in sorted((ROOT / 'data/monsters').glob('*.tres')):
    s = p.read_text(encoding='utf8')
    mid = prop(s, 'id', '&"%s"' % p.stem).strip('&"')
    lv = int(prop(s, 'level', '1'))
    boss = prop(s, 'is_boss', 'false') == 'true'
    mon_info[mid] = (lv, boss)
    out = s
    for m in list(re.finditer(r'(\[sub_resource type="Resource" id="[^"]+"\]\n)((?:[^\[\n][^\n]*\n)+)', s)):
        body = m.group(2)
        iid = prop(body, 'item_id', '')
        if not iid:
            continue
        iid = iid.strip('&"')
        info = items.get(iid)
        if info is None:
            continue
        new = None
        if info['type'] == 5:                       # การ์ด
            new = lerp(BOSS_CARD if boss else CARD, lv)
        elif info['type'] in (1, 2):                 # อาวุธ/ของสวมใส่
            new = lerp(EQUIP, lv)
        elif iid in STONES:
            new = lerp(STONE, lv)
        if new is None:
            continue
        old = float(prop(body, 'chance', '10.0'))
        new = min(old, new)   # ★ "ปรับลง" เท่านั้น — ของที่เดิมหายากกว่าสูตรอยู่แล้ว คงไว้ ★
        if abs(old - new) < 0.001:
            continue
        nb = re.sub(r'^chance = .+$', 'chance = %s' % fmt(new), body, flags=re.M)
        if 'chance = ' not in body:
            nb = body + 'chance = %s\n' % fmt(new)
        out = out.replace(m.group(1) + body, m.group(1) + nb, 1)
        changes.append(('drop', mid, lv, iid, old, new))
    if out != s:
        p.write_text(out, encoding='utf8')

# ---------- ราคาขาย ----------
for iid, info in items.items():
    p = info['path']
    s = p.read_text(encoding='utf8')
    new = None
    if info['type'] == 5:
        mon = prop(s, 'monster_id', '').strip('&"')
        boss = mon_info.get(mon, (1, False))[1]
        new = BOSS_CARD_SELL if boss else CARD_SELL
    elif info['type'] in (1, 2):
        # ★ ราคาฐาน = ราคาขายเดิมก่อนรอบ 44 ★ อ่านจากค่าที่บันทึกไว้ (กันคูณซ้ำเวลารันหลายรอบ)
        base = int(prop(s, 'metadata/sell_price_base_r44', str(info['sell'])))
        new = int(base * EQUIP_SELL_MULT)
        if info['buy'] > 0:   # ★ ทุกชิ้นที่มีราคาซื้อ (เผื่อวันหน้าเอาไปวางขายในร้าน) ★
            new = min(new, int(info['buy'] * SHOP_CAP))
        if 'metadata/sell_price_base_r44' not in s:
            # เก็บค่าเดิมไว้ในไฟล์เป็น metadata (Godot ไม่รู้จักช่องนี้ = ข้ามไป ไม่มีผลกับเกม)
            s = s.replace('sell_price = %d' % info['sell'],
                          'sell_price = %d\nmetadata/sell_price_base_r44 = %d' % (info['sell'], base), 1)
    if new is None or new == info['sell']:
        continue
    if re.search(r'^sell_price = ', s, re.M):
        s = re.sub(r'^sell_price = .+$', 'sell_price = %d' % new, s, flags=re.M)
    else:
        s = s.replace('[resource]\n', '[resource]\nsell_price = %d\n' % new, 1)
    p.write_text(s, encoding='utf8')
    changes.append(('sell', iid, info['type'], info['sell'], new))

for c in changes:
    if c[0] == 'drop':
        print('  ดรอป %-14s Lv%-2d %-20s %5.2f%% → %5.2f%%' % (c[1], c[2], c[3], c[4], c[5]))
    else:
        print('  ขาย  %-22s %7d → %7d' % (c[1], c[3], c[4]))
print('เปลี่ยน', len(changes), 'รายการ')
