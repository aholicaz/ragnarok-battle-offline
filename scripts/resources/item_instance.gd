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


static func create(p_item_id: StringName, p_count: int = 1, p_refine: int = 0,
		p_slots: int = 0) -> ItemInstance:
	var inst := ItemInstance.new()
	inst.item_id = p_item_id
	inst.count = p_count
	inst.refine = p_refine
	inst.slots = p_slots
	return inst


## สร้างของแบบ "ดรอปจากมอน" — ได้ช่องการ์ดติดมาตามที่ตั้งไว้ใน ItemData
static func create_drop(p_item_id: StringName, p_count: int = 1, p_refine: int = 0) -> ItemInstance:
	var d := GameData.get_item(p_item_id)
	var n: int = d.card_slots if d != null else 0
	return create(p_item_id, p_count, p_refine, n)


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
	return text


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
	return d.atk + refine * d.refine_atk_per_level


func total_def() -> int:
	var d := data()
	if d == null:
		return 0
	return d.def + refine * d.refine_def_per_level


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
	var inst := ItemInstance.create(item_id, count, refine)
	inst.cards = cards.duplicate()
	return inst


func same_kind_as(other: ItemInstance) -> bool:
	return other != null and other.item_id == item_id \
		and other.refine == refine and other.cards == cards


func to_dict() -> Dictionary:
	var card_ids: Array = []
	for c in cards:
		card_ids.append(String(c))
	return {"item_id": String(item_id), "count": count, "refine": refine,
		"cards": card_ids, "slots": slots}


static func from_dict(d: Dictionary) -> ItemInstance:
	var inst := ItemInstance.create(
		StringName(d.get("item_id", "")),
		int(d.get("count", 1)),
		int(d.get("refine", 0))
	)
	inst.slots = int(d.get("slots", 0))
	for c in d.get("cards", []):
		inst.cards.append(StringName(c))
	# เซฟเก่าที่ยังไม่มีช่อง slots — เดาจากจำนวนการ์ดที่ใส่ไว้ จะได้ไม่หลุด
	inst.slots = maxi(inst.slots, inst.cards.size())
	return inst
