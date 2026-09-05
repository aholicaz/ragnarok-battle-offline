## ItemInstance — ของ 1 กองในกระเป๋า
## เก็บว่าเป็นไอเทมอะไร จำนวนเท่าไหร่ และตีบวกไปกี่ระดับ
class_name ItemInstance
extends Resource

@export var item_id: StringName = &""
@export var count: int = 1
@export var refine: int = 0
## การ์ดที่ใส่อยู่ในชิ้นนี้ (เก็บเป็น id ของการ์ด)
@export var cards: Array[StringName] = []
## ★ ช่องการ์ดของ "ชิ้นนี้" ★ ของร้านค้า = 0 เสมอ · ของที่ดรอปจากมอนถึงจะมีช่อง
@export var slots: int = 0
## ★★ รอบ 57 — โบนัสของดรอป ★★
## ของที่ดรอปจากมอน/บอส "ค่าพลังดีกว่าของร้าน" กี่ % (สุ่มตอนดรอป · ของร้าน = 0)
## คูณกับ ATK/DEF/MATK/MDEF/HIT/FLEE/CRIT/MaxHP/MaxSP และค่าสเตตัสของชิ้นนั้น
@export var bonus_percent: float = 0.0

## ★ ช่วงโบนัสของที่ดรอป (%) ★ อยากให้ของดรอปแรงขึ้น/ลง แก้ 2 ค่านี้ที่เดียว
const DROP_BONUS_MIN := 5.0
const DROP_BONUS_MAX := 30.0


static func create(p_item_id: StringName, p_count: int = 1, p_refine: int = 0,
		p_slots: int = 0) -> ItemInstance:
	var inst := ItemInstance.new()
	inst.item_id = p_item_id
	inst.count = p_count
	inst.refine = p_refine
	inst.slots = p_slots
	return inst


## สร้างของแบบ "ดรอปจากมอน" — ได้ช่องการ์ดติดมาตามที่ตั้งไว้ใน ItemData
## ★ รอบ 57 ★ ถ้าเป็นของสวมใส่ จะสุ่มโบนัสค่าพลัง 5-30% ให้ด้วย (ดีกว่าของที่ซื้อจากร้านเสมอ)
static func create_drop(p_item_id: StringName, p_count: int = 1, p_refine: int = 0) -> ItemInstance:
	var d := GameData.get_item(p_item_id)
	var n: int = d.card_slots if d != null else 0
	var inst := create(p_item_id, p_count, p_refine, n)
	if d != null and d.is_equipment():
		inst.bonus_percent = roundf(randf_range(DROP_BONUS_MIN, DROP_BONUS_MAX) * 10.0) / 10.0
	return inst


func data() -> ItemData:
	return GameData.get_item(item_id)


func display_name() -> String:
	var d := data()
	if d == null:
		return String(item_id)
	var text: String = d.display_name
	if refine > 0:
		text = "+%d %s" % [refine, text]
	if slots > 0:
		text += " [%d]" % slots
	if bonus_percent > 0.0:
		text += " (+%s%%)" % _pct_text(bonus_percent)
	return text


## ข้อความ % แบบสั้น (12.5 → "12.5" · 20.0 → "20")
static func _pct_text(v: float) -> String:
	return "%.1f" % v if absf(v - roundf(v)) > 0.05 else "%d" % int(roundf(v))


## ★ รอบ 57 ★ ตัวคูณค่าพลังของชิ้นนี้ (1.0 = ของร้านปกติ · 1.3 = ของดรอปที่ได้ +30%)
func bonus_multiplier() -> float:
	return 1.0 + maxf(0.0, bonus_percent) / 100.0


## ค่าพลัง 1 ช่องของชิ้นนี้ หลังคูณโบนัสของดรอปแล้ว (ปัดขึ้นถ้ามีเศษ)
func boosted(value: float) -> int:
	if value == 0.0 or bonus_percent <= 0.0:
		return int(value)
	return int(ceilf(absf(value) * bonus_multiplier())) * (1 if value > 0.0 else -1)


# =========================================================
# ช่องใส่การ์ด
# =========================================================
## ช่องการ์ดของชิ้นนี้ (ไม่ใช่ของชนิดไอเทม)
func card_slots() -> int:
	return slots


func free_card_slots() -> int:
	return maxi(0, card_slots() - cards.size())


func can_socket(card: CardData) -> bool:
	var d := data()
	if d == null or card == null:
		return false
	if free_card_slots() <= 0:
		return false
	return card.fits_slot == d.slot


func socket_card(card_id: StringName) -> bool:
	var card := GameData.get_card(card_id)
	if not can_socket(card):
		return false
	cards.append(card_id)
	return true


func remove_card(index: int) -> StringName:
	if index < 0 or index >= cards.size():
		return &""
	var id: StringName = cards[index]
	cards.remove_at(index)
	return id


func card_list() -> Array[CardData]:
	var out: Array[CardData] = []
	for cid in cards:
		var c := GameData.get_card(cid)
		if c != null:
			out.append(c)
	return out


## ATK รวมของชิ้นนี้ (รวมโบนัสตีบวกแล้ว)
func total_atk() -> int:
	var d := data()
	if d == null:
		return 0
	return boosted(d.atk) + refine * d.refine_atk_per_level


func total_def() -> int:
	var d := data()
	if d == null:
		return 0
	return boosted(d.def) + refine * d.refine_def_per_level


## ราคาขาย รวมมูลค่าจากการตีบวก
func sell_value() -> int:
	var d := data()
	if d == null:
		return 0
	var value := int(d.sell_price * (1.0 + refine * 0.25)) * count
	for c in card_list():
		value += c.sell_price
	return value


func duplicate_instance() -> ItemInstance:
	var inst := ItemInstance.create(item_id, count, refine, slots)
	inst.cards = cards.duplicate()
	inst.bonus_percent = bonus_percent
	return inst


func same_kind_as(other: ItemInstance) -> bool:
	return other != null and other.item_id == item_id \
		and other.refine == refine and other.cards == cards \
		and is_equal_approx(other.bonus_percent, bonus_percent)


func to_dict() -> Dictionary:
	var card_ids: Array = []
	for c in cards:
		card_ids.append(String(c))
	return {"item_id": String(item_id), "count": count, "refine": refine,
		"cards": card_ids, "slots": slots, "bonus_percent": bonus_percent}


static func from_dict(d: Dictionary) -> ItemInstance:
	var inst := ItemInstance.create(
		StringName(d.get("item_id", "")),
		int(d.get("count", 1)),
		int(d.get("refine", 0))
	)
	inst.slots = int(d.get("slots", 0))
	inst.bonus_percent = float(d.get("bonus_percent", 0.0))
	for c in d.get("cards", []):
		inst.cards.append(StringName(c))
	# เซฟเก่าที่ยังไม่มีช่อง slots — เดาจากจำนวนการ์ดที่ใส่ไว้ จะได้ไม่หลุด
	inst.slots = maxi(inst.slots, inst.cards.size())
	return inst
