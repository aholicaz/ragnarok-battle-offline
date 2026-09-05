## PlayerState — ข้อมูลตัวละครทั้งหมด (Autoload ชื่อ "PlayerState")
## รวม สเตตัส / กระเป๋า / ของสวมใส่ / สกิล / ซีนี / บัฟ ไว้ที่เดียว
## UI และฉากทุกฉากอ่านจากที่นี่
## หมายเหตุ: ไฟล์นี้ห้ามใส่ class_name เพราะจะชนกับชื่อ Autoload
extends Node

const INVENTORY_SIZE := 40
const REGEN_INTERVAL := 3.0   ## ฟื้น HP/SP ทุกกี่วินาที

var stats: PlayerStats
var inventory: Inventory
var equipment: Equipment
var skills: SkillBook
var quests: QuestLog

var zeny: int = 1000
var current_map_id: StringName = &"prontera_field"

## ★ ช่องยาด่วน ★ ช่อง 0 = ปุ่ม Q (ยาเลือด) · ช่อง 1 = ปุ่ม R (ยามานา)
## เลือกยาได้เองจากหน้ากระเป๋า
const ITEM_HOTKEY_COUNT := 2
var item_hotkeys: Array = [&"red_potion", &"blue_potion"]

## บัฟที่ติดอยู่: skill_id -> { "time_left": float, "values": Dictionary, "level": int }
var active_buffs: Dictionary = {}
## คูลดาวน์สกิล: skill_id -> วินาทีที่เหลือ
var cooldowns: Dictionary = {}

var _regen_timer := 0.0
var _is_dead := false

# =========================================================
# ★★ ธงเนื้อเรื่อง (Story Flags) — รอบ 30 ★★
#
# ใช้จำว่า "เกิดอะไรขึ้นแล้วบ้าง" ในเนื้อเรื่อง เช่น
#   สาบานต่อธอร์แล้วหรือยัง · เจอคนแปลกหน้าแล้วหรือยัง · ดูพิธีฉลองแล้วหรือยัง
#
# เอาไปใช้ได้ 3 ที่:
#   1) เงื่อนไขเควส (ObjectiveData ชนิด FLAG · ช่อง Required Flag ของเควส)
#   2) เลือกบทพูดของ NPC (NPC มีบทพูดหลายชุด ดูที่ npc.gd)
#   3) เปลี่ยนพฤติกรรมเกม เช่น แมพกลางคืน / ข้อความหน้าจอตาย
#
# ตั้งค่า: PlayerState.set_flag(&"saw_ceremony")
# อ่านค่า: PlayerState.has_flag(&"saw_ceremony")
# =========================================================
var story_flags: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	new_game()
	Events.monster_killed.connect(_on_monster_killed)
	# ★ เดินความคืบหน้าเควสชนิดใหม่ ★
	Events.map_changed.connect(_on_map_changed)
	Events.inventory_changed.connect(_on_inventory_changed)


func _on_monster_killed(monster_id: StringName, _level: int) -> void:
	if quests != null:
		quests.on_monster_killed(monster_id)


func _on_map_changed(map_id: StringName) -> void:
	if quests != null:
		quests.on_map_entered(map_id)


func _on_inventory_changed() -> void:
	# เงื่อนไข "หาไอเทม" นับสดจากกระเป๋า — แค่แจ้งให้สมุดเควสอัปเดต
	if quests != null:
		quests.refresh_live()


# =========================================================
# ★ ธงเนื้อเรื่อง ★
# =========================================================
## ตั้งธง (ค่าเริ่มต้น = true) · ตั้งซ้ำค่าเดิมจะไม่ยิงสัญญาณซ้ำ
func set_flag(flag: StringName, value: Variant = true) -> void:
	if flag == &"":
		return
	if story_flags.get(flag, null) == value:
		return
	story_flags[flag] = value
	if quests != null:
		quests.refresh_live()
	Events.quest_changed.emit()


func has_flag(flag: StringName) -> bool:
	var v = story_flags.get(flag, false)
	if v is bool:
		return v
	return v != null


## อ่านค่าธงแบบเก็บข้อมูลได้ (เช่น เก็บว่าผู้เล่นตอบอะไร)
func get_flag(flag: StringName, fallback: Variant = false) -> Variant:
	return story_flags.get(flag, fallback)


func clear_flag(flag: StringName) -> void:
	if story_flags.erase(flag):
		Events.quest_changed.emit()


## รับรางวัลเควส แล้วส่งเควส — คืน true ถ้าส่งสำเร็จ
func turn_in_quest(quest_id: StringName) -> bool:
	var q := GameData.get_quest(quest_id)
	if q == null or not quests.is_ready(quest_id):
		return false

	# ต้องมีที่ว่างในกระเป๋าก่อน
	if q.reward_item_id != &"" and q.reward_item_count > 0:
		var reward := ItemInstance.create(q.reward_item_id, q.reward_item_count)
		if inventory.add(reward) > 0:
			Events.say("กระเป๋าเต็ม — เก็บของให้ว่างก่อนแล้วค่อยมาส่งเควส")
			return false

	if not quests.turn_in(quest_id):
		return false

	if q.reward_zeny > 0:
		add_zeny(q.reward_zeny)
	if q.reward_exp > 0:
		var jx: int = q.reward_job_exp if q.reward_job_exp > 0 else int(round(q.reward_exp * 0.7))
		gain_exp(q.reward_exp, jx)
	Events.say("[เควสสำเร็จ] %s — ได้รับ %s" % [q.title, q.reward_text()])
	return true


# =========================================================
# เริ่มเกมใหม่
# =========================================================
func new_game() -> void:
	stats = PlayerStats.new()
	inventory = Inventory.new(INVENTORY_SIZE)
	equipment = Equipment.new()
	skills = SkillBook.new()
	quests = QuestLog.new()
	story_flags.clear()
	zeny = 1000
	active_buffs.clear()
	cooldowns.clear()
	item_hotkeys = [&"red_potion", &"blue_potion"]
	_is_dead = false
	current_map_id = &"prontera_field"

	stats.job_id = &"swordsman"
	stats.level = 1
	stats.job_level = 1
	stats.stat_points = 20

	refresh()
	stats.hp = stats.max_hp
	stats.sp = stats.max_sp

	# ของเริ่มต้น
	inventory.add_id(&"red_potion", 10)
	inventory.add_id(&"novice_sword", 1)
	inventory.add_id(&"cotton_shirt", 1)

	# สวมของเริ่มต้นให้เลย
	for i in range(inventory.size):
		var s := inventory.get_slot(i)
		if s != null and (s.item_id == &"novice_sword" or s.item_id == &"cotton_shirt"):
			equip_from_inventory(i)

	stats.hp = stats.max_hp
	stats.sp = stats.max_sp

	_emit_all()


# =========================================================
# คำนวณค่าพลังใหม่ทั้งหมด — เรียกทุกครั้งที่มีอะไรเปลี่ยน
# =========================================================
func refresh(keep_ratio: bool = true) -> void:
	var flat := equipment.collect_bonus()
	var percent := equipment.collect_percent_bonus()

	# --- สกิลพาสซีฟ ---
	for key in skills.passive_bonus().keys():
		if String(key).ends_with("_percent"):
			percent[key] = float(percent.get(key, 0.0)) + float(skills.passive_bonus()[key])
		else:
			flat[key] = float(flat.get(key, 0)) + float(skills.passive_bonus()[key])

	# --- บัฟ ---
	for skill_id in active_buffs.keys():
		var values: Dictionary = active_buffs[skill_id].get("values", {})
		for key in values.keys():
			var k := StringName(key)
			if String(k).ends_with("_percent"):
				percent[k] = float(percent.get(k, 0.0)) + float(values[key])
			else:
				flat[k] = float(flat.get(k, 0)) + float(values[key])

	stats.flat_bonus = flat
	stats.percent_bonus = percent
	stats.weapon_atk = equipment.weapon_atk()
	stats.recalculate(keep_ratio)

	# ★ รอบ 50 — ช่องกระเป๋าตาม STR ★ (set_size ปลอดภัยกับของที่มีอยู่แล้ว)
	if inventory != null:
		inventory.set_size(INVENTORY_SIZE + stats.bag_bonus_slots)

	Events.stats_changed.emit()
	Events.hp_changed.emit(stats.hp, stats.max_hp)
	Events.sp_changed.emit(stats.sp, stats.max_sp)


func _emit_all() -> void:
	Events.inventory_changed.emit()
	Events.equipment_changed.emit()
	Events.skills_changed.emit()
	Events.zeny_changed.emit(zeny)
	Events.exp_changed.emit(stats.exp_current, stats.exp_to_next())
	Events.job_exp_changed.emit(stats.job_exp_current, stats.job_exp_to_next())


# =========================================================
# ฟื้นฟู HP/SP + นับเวลาบัฟและคูลดาวน์
# =========================================================
func _process(delta: float) -> void:
	if stats == null:
		return

	# คูลดาวน์
	var finished_cd: Array = []
	for sid in cooldowns.keys():
		cooldowns[sid] -= delta
		if cooldowns[sid] <= 0.0:
			finished_cd.append(sid)
	for sid in finished_cd:
		cooldowns.erase(sid)

	# บัฟหมดอายุ
	var expired: Array = []
	for sid in active_buffs.keys():
		active_buffs[sid]["time_left"] -= delta
		if active_buffs[sid]["time_left"] <= 0.0:
			expired.append(sid)
	if not expired.is_empty():
		for sid in expired:
			active_buffs.erase(sid)
		refresh()
		Events.buff_changed.emit()

	# ฟื้นฟู
	if _is_dead:
		return
	_regen_timer += delta
	if _regen_timer >= REGEN_INTERVAL:
		_regen_timer = 0.0
		if stats.hp > 0 and stats.hp < stats.max_hp:
			heal_hp(int(stats.hp_regen * REGEN_INTERVAL), false)
		if stats.sp < stats.max_sp:
			restore_sp(int(stats.sp_regen * REGEN_INTERVAL))


# =========================================================
# HP / SP
# =========================================================
func heal_hp(amount: int, show_text: bool = true) -> void:
	if amount <= 0:
		return
	var before := stats.hp
	stats.hp = clampi(stats.hp + amount, 0, stats.max_hp)
	if stats.hp != before:
		Events.hp_changed.emit(stats.hp, stats.max_hp)
		if show_text:
			var p := get_tree().get_first_node_in_group("player")
			if p != null:
				Events.floating_text(p.global_position, "+%d" % (stats.hp - before), Color("#5cff7a"), 24, 0)


func take_damage(amount: int) -> void:
	if _is_dead:
		return
	stats.hp = clampi(stats.hp - amount, 0, stats.max_hp)
	Events.hp_changed.emit(stats.hp, stats.max_hp)
	if stats.hp <= 0:
		_is_dead = true
		Events.player_died.emit()


func restore_sp(amount: int) -> void:
	var before := stats.sp
	stats.sp = clampi(stats.sp + amount, 0, stats.max_sp)
	if stats.sp != before:
		Events.sp_changed.emit(stats.sp, stats.max_sp)


func spend_sp(amount: int) -> bool:
	if stats.sp < amount:
		return false
	stats.sp -= amount
	Events.sp_changed.emit(stats.sp, stats.max_sp)
	return true


func is_dead() -> bool:
	return _is_dead


func revive(hp_percent: float = 0.5) -> void:
	_is_dead = false
	stats.hp = maxi(1, int(stats.max_hp * hp_percent))
	stats.sp = maxi(1, int(stats.max_sp * hp_percent))
	active_buffs.clear()
	refresh(false)


# =========================================================
# EXP / ซีนี
# =========================================================
## ★ ค่าประสบการณ์ Base ★ (ขึ้นเลเวล = ได้แต้มสเตตัส)
func add_exp(amount: int) -> void:
	var gained := stats.add_exp(amount)
	Events.exp_changed.emit(stats.exp_current, stats.exp_to_next())
	if gained > 0:
		refresh(false)
		stats.hp = stats.max_hp
		stats.sp = stats.max_sp
		Events.hp_changed.emit(stats.hp, stats.max_hp)
		Events.sp_changed.emit(stats.sp, stats.max_sp)
		Events.level_up.emit(stats.level)


## ★ ค่าประสบการณ์อาชีพ (Job) ★ (ขึ้น job level = ได้แต้มสกิล)
func add_job_exp(amount: int) -> void:
	var gained := stats.add_job_exp(amount)
	Events.job_exp_changed.emit(stats.job_exp_current, stats.job_exp_to_next())
	if gained > 0:
		refresh(false)
		Events.job_level_up.emit(stats.job_level)


## ได้ทั้งสองหลอดพร้อมกัน (ใช้ตอนฆ่ามอน/ส่งเควส)
func gain_exp(base_exp: int, job_exp: int) -> void:
	if base_exp > 0:
		add_exp(base_exp)
	if job_exp > 0:
		add_job_exp(job_exp)


func add_zeny(amount: int) -> void:
	zeny = maxi(0, zeny + amount)
	Events.zeny_changed.emit(zeny)


# =========================================================
# สเตตัส
# =========================================================
func raise_stat(stat: StringName) -> bool:
	if stats.raise_stat(stat):
		refresh()
		return true
	return false


# =========================================================
# ของสวมใส่
# =========================================================
## ใส่ของจากช่องกระเป๋าที่ระบุ
func equip_from_inventory(inv_index: int) -> bool:
	var inst := inventory.get_slot(inv_index)
	if inst == null:
		return false
	var data := inst.data()
	if data == null or not data.is_equipment():
		Events.say("ไอเทมนี้สวมใส่ไม่ได้")
		return false

	# ★ เช็คระดับเลเวล ★
	if stats.level < data.required_level:
		Events.say("ต้องเลเวล %d ขึ้นไปถึงจะใส่ %s ได้ (ตอนนี้ Lv.%d)"
			% [data.required_level, data.display_name, stats.level])
		return false

	# เช็คว่าอาชีพใส่อาวุธชนิดนี้ได้ไหม
	if data.type == ItemData.Type.WEAPON:
		var job := stats.job()
		if not job.weapon_types.is_empty() and data.weapon_type not in job.weapon_types:
			Events.say("อาชีพ %s ใช้อาวุธชนิดนี้ไม่ได้" % job.display_name)
			return false

	# เครื่องประดับ: ถ้าช่อง 1 มีของแล้วให้ไปช่อง 2
	var prefer_second := false
	if data.slot == ItemData.Slot.ACCESSORY:
		prefer_second = equipment.get_item(Equipment.EquipSlot.ACCESSORY_1) != null \
			and equipment.get_item(Equipment.EquipSlot.ACCESSORY_2) == null

	var slot := Equipment.slot_for(data, prefer_second)
	if slot < 0:
		return false

	inventory.set_slot(inv_index, null)
	var old := equipment.equip(slot, inst)
	if old != null:
		inventory.set_slot(inv_index, old)
	refresh()
	return true


func unequip(slot: int) -> bool:
	var inst := equipment.get_item(slot)
	if inst == null:
		return false
	if inventory.is_full():
		Events.say("กระเป๋าเต็ม")
		return false
	equipment.unequip(slot)
	inventory.add(inst)
	refresh()
	return true


# =========================================================
# การ์ดมอนสเตอร์
# =========================================================
## รายการอุปกรณ์ที่ใส่การ์ดใบนี้ได้
## คืน Array ของ { "source": "eq:<slot>" หรือ "inv:<index>", "instance": ItemInstance }
func sockets_for_card(card_id: StringName) -> Array:
	var card := GameData.get_card(card_id)
	var out: Array = []
	if card == null:
		return out

	for slot in equipment.slots.keys():
		var inst: ItemInstance = equipment.get_item(slot)
		if inst != null and inst.can_socket(card):
			out.append({"source": "eq:%d" % slot, "instance": inst,
				"label": "%s (สวมอยู่)" % inst.display_name()})

	for i in range(inventory.size):
		var inst2 := inventory.get_slot(i)
		if inst2 != null and inst2.can_socket(card):
			out.append({"source": "inv:%d" % i, "instance": inst2,
				"label": inst2.display_name()})

	return out


## ใส่การ์ดจากกระเป๋าลงในอุปกรณ์
func socket_card(card_id: StringName, target: ItemInstance) -> bool:
	if target == null:
		return false
	var card := GameData.get_card(card_id)
	if card == null:
		Events.say("ไม่พบการ์ดใบนี้")
		return false
	if not inventory.has(card_id, 1):
		Events.say("ไม่มีการ์ดใบนี้ในกระเป๋า")
		return false
	if not target.can_socket(card):
		Events.say("ใส่ไม่ได้ — ต้องเป็น%sที่ยังมีช่องว่าง" % card.slot_name())
		return false

	inventory.remove_id(card_id, 1)
	target.socket_card(card_id)
	refresh()
	Events.inventory_changed.emit()
	Events.equipment_changed.emit()
	Events.say("ใส่ %s ลงใน %s แล้ว" % [card.display_name, target.display_name()])
	return true


## ถอดการ์ดออกจากอุปกรณ์ (คืนการ์ดกลับเข้ากระเป๋า)
## อยากให้ถอดแล้วการ์ดหายแบบ RO ต้นฉบับ ให้เปลี่ยน return_to_inventory เป็น false
func unsocket_card(target: ItemInstance, index: int, return_to_inventory: bool = true) -> bool:
	if target == null:
		return false
	var card_id := target.remove_card(index)
	if card_id == &"":
		return false
	if return_to_inventory:
		inventory.add_id(card_id, 1)
	refresh()
	Events.inventory_changed.emit()
	Events.equipment_changed.emit()
	Events.say("ถอด %s ออกแล้ว" % GameData.item_name(card_id))
	return true


## ★ ใส่ของเข้ากระเป๋า "ผ่านทางนี้เสมอ" ★
## จะได้ตรวจได้ว่าเป็นการ์ดใบใหม่ที่ยังไม่เคยมี แล้วเด้ง popup ยินดีด้วย
## คืนค่าจำนวนที่ใส่ไม่ได้ (0 = เข้าครบ) เหมือน Inventory.add()
func gain_item(inst: ItemInstance) -> int:
	if inst == null:
		return 0
	var d := inst.data()
	var first_card: bool = d != null and d.is_card() and not owns_card(inst.item_id)
	var leftover := inventory.add(inst)
	if first_card and leftover < inst.count:
		Events.card_obtained.emit(inst.item_id)
	return leftover


## ★ ให้ไอเทมจาก id ★ ใช้ตอนอ่าน lore / รางวัลเควส / ของจากเนื้อเรื่อง
## คืนจำนวนที่ใส่กระเป๋าไม่ลง (0 = เข้าครบ)
func gain_item_id(item_id: StringName, count: int = 1) -> int:
	if item_id == &"" or count <= 0:
		return 0
	var d := GameData.get_item(item_id)
	if d == null:
		push_warning("[PlayerState] ไม่รู้จักไอเทม: " + String(item_id))
		return count
	var inst := ItemInstance.new()
	inst.item_id = item_id
	inst.count = count
	var left := gain_item(inst)
	if left < count:
		Events.item_gained.emit(item_id, count - left)
		Events.say("ได้รับ %s x%d" % [d.display_name, count - left])
	return left


## เก็บการ์ดใบนี้ได้แล้วหรือยัง (นับทั้งในกระเป๋าและที่ใส่อยู่ในอุปกรณ์)
func owns_card(card_id: StringName) -> bool:
	if inventory.has(card_id, 1):
		return true
	for slot in equipment.slots.keys():
		var inst: ItemInstance = equipment.get_item(slot)
		if inst != null and card_id in inst.cards:
			return true
	for i in range(inventory.size):
		var inst2 := inventory.get_slot(i)
		if inst2 != null and card_id in inst2.cards:
			return true
	return false


func cards_collected() -> int:
	var n := 0
	for cid in GameData.cards.keys():
		if owns_card(cid):
			n += 1
	return n


# =========================================================
# ใช้ไอเทม
# =========================================================
func use_item(inv_index: int) -> bool:
	var inst := inventory.get_slot(inv_index)
	if inst == null:
		return false
	var data := inst.data()
	if data == null:
		return false

	if data.is_equipment():
		return equip_from_inventory(inv_index)

	if data.is_card():
		Events.toggle_window.emit(&"cards")
		return false

	if data.type != ItemData.Type.CONSUMABLE:
		Events.say("ไอเทมนี้ใช้ไม่ได้")
		return false

	# ★ รอบ 45 — ไอเทมพิเศษ: รีสกิล / รีสเตตัส ★
	if data.special_effect != &"":
		match data.special_effect:
			&"reset_skills":
				var before := stats.skill_points
				skills.reset(stats)
				inventory.take_from_slot(inv_index, 1)
				refresh()
				Events.say("รีเซ็ตสกิลแล้ว — ได้แต้มสกิลคืน %d แต้ม" % (stats.skill_points - before))
			&"reset_stats":
				var refund := stats.reset_stats()
				inventory.take_from_slot(inv_index, 1)
				refresh()
				Events.say("รีเซ็ตสเตตัสแล้ว — ได้แต้มสเตตัสคืน %d แต้ม" % refund)
			_:
				Events.say("ไอเทมนี้ยังไม่มีผล (%s)" % String(data.special_effect))
				return false
		Events.item_used.emit(data.id)
		return true

	var heal := data.heal_hp + int(stats.max_hp * data.heal_hp_percent / 100.0)
	var sp_heal := data.heal_sp + int(stats.max_sp * data.heal_sp_percent / 100.0)
	var has_buff := data.buff_duration > 0.0 and not data.buff_values.is_empty()

	if heal > 0 and stats.hp >= stats.max_hp and sp_heal <= 0 and not has_buff:
		Events.say("เลือดเต็มอยู่แล้ว")
		return false

	inventory.take_from_slot(inv_index, 1)
	if heal > 0:
		heal_hp(heal)
	if sp_heal > 0:
		restore_sp(sp_heal)
	if has_buff:
		apply_item_buff(data)
	Events.item_used.emit(data.id)
	return true


## ★ รอบ 45 — บัฟจากไอเทม ★ เก็บใน active_buffs เหมือนบัฟสกิล (คีย์ = "item_<id>") ใช้ซ้ำ = ต่ออายุใหม่
func apply_item_buff(data: ItemData) -> void:
	var key := StringName("item_" + String(data.id))
	active_buffs[key] = {
		"time_left": data.buff_duration,
		"values": data.buff_values.duplicate(),
		"level": 1,
		"name": data.display_name,
		"icon": data.icon,
	}
	refresh()
	Events.buff_changed.emit()
	Events.say("ได้รับบัฟ %s (%d วินาที)" % [data.display_name, int(data.buff_duration)])


# =========================================================
# ★ ช่องยาด่วน (ปุ่ม Q / R) ★
# =========================================================
func item_hotkey_at(index: int) -> StringName:
	if index < 0 or index >= ITEM_HOTKEY_COUNT:
		return &""
	return item_hotkeys[index]


## ตั้งยาลงช่องด่วน (ใส่ &"" = ล้างช่อง)
func set_item_hotkey(index: int, item_id: StringName) -> void:
	if index < 0 or index >= ITEM_HOTKEY_COUNT:
		return
	# ยาชิ้นเดียวกันอยู่ได้ช่องเดียว
	for i in range(ITEM_HOTKEY_COUNT):
		if item_id != &"" and item_hotkeys[i] == item_id:
			item_hotkeys[i] = &""
	item_hotkeys[index] = item_id
	Events.inventory_changed.emit()


## กดปุ่มยาด่วน
func use_item_hotkey(index: int) -> bool:
	var id := item_hotkey_at(index)
	if id == &"":
		Events.say("ยังไม่ได้เลือกยาในช่องนี้ (เปิดกระเป๋าแล้วกดตั้งช่องยา)")
		return false
	if inventory.count_of(id) <= 0:
		Events.say("%s หมดแล้ว" % GameData.item_name(id))
		return false
	return use_item_by_id(id)


func use_item_by_id(item_id: StringName) -> bool:
	for i in range(inventory.size):
		var s := inventory.get_slot(i)
		if s != null and s.item_id == item_id:
			return use_item(i)
	return false


# =========================================================
# สกิล
# =========================================================
func skill_cooldown_left(skill_id: StringName) -> float:
	return float(cooldowns.get(skill_id, 0.0))


func can_use_skill(skill_id: StringName) -> Dictionary:
	var out := {"ok": false, "reason": ""}
	var s := GameData.get_skill(skill_id)
	if s == null:
		out.reason = "ไม่พบสกิล"
		return out
	var lv := skills.level_of(skill_id)
	if lv <= 0:
		out.reason = "ยังไม่ได้เรียนสกิลนี้"
		return out
	if not s.is_active():
		out.reason = "สกิลพาสซีฟใช้เองไม่ได้"
		return out
	if skill_cooldown_left(skill_id) > 0.0:
		out.reason = "ยังคูลดาวน์อยู่"
		return out
	if stats.sp < s.sp_cost(lv):
		out.reason = "SP ไม่พอ"
		return out
	out.ok = true
	return out


## หักค่าใช้จ่ายและเริ่มคูลดาวน์ (player.gd เป็นคนทำดาเมจจริง)
func commit_skill_use(skill_id: StringName) -> bool:
	var check := can_use_skill(skill_id)
	if not check.ok:
		Events.say(check.reason)
		return false
	var s := GameData.get_skill(skill_id)
	var lv := skills.level_of(skill_id)
	spend_sp(s.sp_cost(lv))
	# ★ รอบ 50 — DEX ลดคูลดาวน์ (ดู PlayerStats.cooldown_reduction) ★
	cooldowns[skill_id] = s.cooldown * (1.0 - stats.cooldown_reduction / 100.0)
	Events.skill_used.emit(skill_id, lv)
	return true


func apply_buff(skill_id: StringName) -> void:
	var s := GameData.get_skill(skill_id)
	if s == null:
		return
	var lv := skills.level_of(skill_id)
	active_buffs[skill_id] = {
		"time_left": s.duration(lv),
		"values": s.buff_values(lv),
		"level": lv,
	}
	refresh()
	Events.buff_changed.emit()


func learn_skill(skill_id: StringName) -> bool:
	if skills.learn(skill_id, stats):
		refresh()
		return true
	Events.say(skills.learn_blocker(skill_id, stats))
	return false


# =========================================================
# ร้านค้า
# =========================================================
func buy(item_id: StringName, count: int = 1) -> bool:
	var d := GameData.get_item(item_id)
	if d == null:
		return false
	var total := d.buy_price * count
	if zeny < total:
		Events.say("ซีนีไม่พอ")
		return false
	if inventory.is_full() and not d.is_stackable():
		Events.say("กระเป๋าเต็ม")
		return false
	var leftover := inventory.add_id(item_id, count)
	var bought := count - leftover
	if bought <= 0:
		Events.say("กระเป๋าเต็ม")
		return false
	add_zeny(-d.buy_price * bought)
	Events.say("ซื้อ %s x%d" % [d.display_name, bought])
	return true


func sell_slot(inv_index: int, count: int = 1) -> bool:
	var inst := inventory.get_slot(inv_index)
	if inst == null:
		return false
	var d := inst.data()
	if d == null or d.type == ItemData.Type.QUEST:
		Events.say("ไอเทมนี้ขายไม่ได้")
		return false
	var taken := inventory.take_from_slot(inv_index, count)
	if taken == null:
		return false
	add_zeny(taken.sell_value())
	Events.say("ขาย %s ได้ %d ซีนี" % [taken.display_name(), taken.sell_value()])
	return true


# =========================================================
# เซฟ / โหลด
# =========================================================
# =========================================================
# ★★ คูลดาวน์เกิดใหม่ของบอส (รอบ 56) ★★
#
# เดิม: เวลานับถอยหลังอยู่ในฉากแมพ — ออกแมพแล้วเข้าใหม่ ฉากถูกสร้างใหม่
#       บอสจึงเกิดทันที ผู้เล่นวนออก-เข้าเพื่อฟาร์มบอสรัว ๆ ได้
# ตอนนี้: จำ "เวลาที่เกิดใหม่ได้" ต่อ id มอน ไว้ในเซฟ (นาฬิกาเครื่อง)
#         ออกแมพ ปิดเกม โหลดเซฟ ก็ยังต้องรอจนครบ
# =========================================================
var respawn_locks: Dictionary = {}     ## id มอน -> unix time ที่เกิดใหม่ได้


## ล็อกไม่ให้มอน id นี้เกิดใหม่อีก seconds วินาที
func lock_respawn(monster_id: StringName, seconds: float) -> void:
	if seconds <= 0.0:
		return
	respawn_locks[monster_id] = Time.get_unix_time_from_system() + seconds


## เหลืออีกกี่วินาทีถึงจะเกิดใหม่ได้ (0 = เกิดได้เลย)
func respawn_remaining(monster_id: StringName) -> float:
	if not respawn_locks.has(monster_id):
		return 0.0
	var left: float = float(respawn_locks[monster_id]) - Time.get_unix_time_from_system()
	if left <= 0.0:
		respawn_locks.erase(monster_id)
		return 0.0
	return left


## เกิดใหม่ได้หรือยัง
func can_respawn(monster_id: StringName) -> bool:
	return respawn_remaining(monster_id) <= 0.0


func _respawn_locks_to_dict() -> Dictionary:
	var out: Dictionary = {}
	for k in respawn_locks.keys():
		out[String(k)] = float(respawn_locks[k])
	return out


func to_dict() -> Dictionary:
	return {
		"version": 1,
		"respawn_locks": _respawn_locks_to_dict(),
		"stats": stats.to_dict(),
		"inventory": inventory.to_array(),
		"equipment": equipment.to_dict(),
		"skills": skills.to_dict(),
		"quests": quests.to_dict(),
		"zeny": zeny,
		"item_hotkeys": [String(item_hotkeys[0]), String(item_hotkeys[1])],
		"map": String(current_map_id),
		"flags": _flags_to_dict(),
	}


func _flags_to_dict() -> Dictionary:
	var out: Dictionary = {}
	for k in story_flags.keys():
		out[String(k)] = story_flags[k]
	return out


func from_dict(d: Dictionary) -> void:
	stats = PlayerStats.new()
	inventory = Inventory.new(INVENTORY_SIZE)
	equipment = Equipment.new()
	skills = SkillBook.new()
	quests = QuestLog.new()
	active_buffs.clear()
	cooldowns.clear()
	_is_dead = false

	stats.from_dict(d.get("stats", {}))
	inventory.from_array(d.get("inventory", []))
	equipment.from_dict(d.get("equipment", {}))
	skills.from_dict(d.get("skills", {}))
	quests.from_dict(d.get("quests", {}))
	zeny = int(d.get("zeny", 0))
	var ih: Array = d.get("item_hotkeys", [])
	item_hotkeys = [&"red_potion", &"blue_potion"]
	for i in range(mini(ih.size(), ITEM_HOTKEY_COUNT)):
		item_hotkeys[i] = StringName(ih[i])
	current_map_id = StringName(d.get("map", "prontera_field"))

	respawn_locks.clear()
	var rl = d.get("respawn_locks", {})
	if rl is Dictionary:
		for k in rl.keys():
			respawn_locks[StringName(k)] = float(rl[k])

	story_flags.clear()
	var fl = d.get("flags", {})
	if fl is Dictionary:
		for k in fl.keys():
			story_flags[StringName(k)] = fl[k]

	refresh(false)
	_emit_all()
