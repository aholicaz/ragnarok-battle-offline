## NPC — คนในเมือง (ร้านค้า / ช่างตีบวก / หมอ / เซฟเกม)
##
## โครงสร้าง Scene:
##   NPC (Area2D)  <- ใส่สคริปต์นี้
##   ├── Sprite2D หรือ AnimatedSprite2D
##   ├── CollisionShape2D
##   └── Label   (ชื่อ NPC — ไม่ใส่ก็ได้)
extends Area2D

enum NPCType { DIALOG, SHOP, REFINER, HEALER, SAVE_POINT, QUEST }

@export var npc_name: String = "พ่อค้า"
@export var type: NPCType = NPCType.SHOP
## ★ ข้อความคุยเล่น ★ เว้นบรรทัดว่าง 1 บรรทัด = ขึ้นหน้าใหม่ในกล่องสนทนา
@export_multiline var dialog: String = "สวัสดี นักผจญภัย"

@export_group("รูปตัวละครในกล่องสนทนา")
## ★ รูปครึ่งตัว (หัวถึงเอว) พื้นหลังโปร่งใส สูงประมาณ 400-500 px ★
## ลากไฟล์ภาพมาใส่ช่องนี้ได้เลย
@export var portrait: Texture2D
## หรือใส่เป็น path ก็ได้ เช่น "res://Sprites/portraits/hans.png"
## (ใช้ตอนไม่อยากลากไฟล์ใน Inspector — ช่องบนมาก่อนถ้าใส่ทั้งคู่)
@export var portrait_file: String = ""
## รูปอยู่ฝั่งไหนของจอ — 0 = ซ้าย · 1 = ขวา
@export_enum("ซ้าย", "ขวา") var portrait_side: int = 0

## ★ ของที่ร้านนี้ขาย (ใส่ id ของไอเทม) ★
@export var shop_items: Array[StringName] = [
	&"red_potion", &"orange_potion", &"blue_potion",
	&"novice_sword", &"cotton_shirt", &"phracon",
]

## ค่าบริการรักษา (สำหรับ HEALER)
@export var heal_price: int = 100

## ★ เควสที่ NPC คนนี้เป็นคนให้ ★ (ใส่ id ของเควสจาก data/quests/)
## ใส่ได้กับ NPC ทุกแบบ ไม่ใช่แค่แบบ QUEST — คุยแล้วจะถามเรื่องเควสก่อน แล้วค่อยเปิดร้าน
@export var quest_ids: Array[StringName] = []

var _player_inside := false
var _prompt: Label
var _mark: Label


func _ready() -> void:
	add_to_group("npc")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var label := get_node_or_null("Label") as Label
	if label != null:
		label.text = npc_name
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 5)

	_prompt = Label.new()
	_prompt.text = "[F] คุย"
	_prompt.position = Vector2(-24, -80)
	_prompt.add_theme_color_override("font_color", Color("#ffe14a"))
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 5)
	_prompt.hide()
	add_child(_prompt)

	_mark = Label.new()
	_mark.text = "!"
	_mark.position = Vector2(-6, -116)
	_mark.add_theme_font_size_override("font_size", 30)
	_mark.add_theme_color_override("font_color", Color("#ffe14a"))
	_mark.add_theme_color_override("font_outline_color", Color.BLACK)
	_mark.add_theme_constant_override("outline_size", 6)
	_mark.hide()
	add_child(_mark)

	Events.quest_changed.connect(_refresh_mark)
	_refresh_mark()


## เครื่องหมายเหนือหัว: ! = มีเควสให้รับ · ? = เอาไปส่งได้แล้ว
func _refresh_mark() -> void:
	if _mark == null:
		return
	if quest_ids.is_empty() or PlayerState.quests == null:
		_mark.hide()
		return
	var log := PlayerState.quests
	var lv: int = PlayerState.stats.level if PlayerState.stats != null else 1

	for qid in quest_ids:
		if log.is_ready(qid):
			_mark.text = "?"
			_mark.add_theme_color_override("font_color", Color("#7dffa8"))
			_mark.show()
			return
	for qid in quest_ids:
		if log.can_accept(qid, lv):
			_mark.text = "!"
			_mark.add_theme_color_override("font_color", Color("#ffe14a"))
			_mark.show()
			return
	_mark.hide()


## รูปที่จะโชว์ในกล่องสนทนา (ไม่มีก็คืน null — กล่องจะไม่โชว์ช่องรูป)
func portrait_texture() -> Texture2D:
	if portrait != null:
		return portrait
	if portrait_file != "" and ResourceLoader.exists(portrait_file):
		return load(portrait_file) as Texture2D
	return null


## บทพูดของ NPC คนนี้ 1 บรรทัด (ใส่ชื่อ + รูป + ฝั่งให้อัตโนมัติ)
func line(text: String, info: String = "", choices: Array = []) -> Dictionary:
	var d := {
		"name": npc_name,
		"portrait": portrait_texture(),
		"side": portrait_side,
		"text": text,
	}
	if info != "":
		d["info"] = info
	if not choices.is_empty():
		d["choices"] = choices
	return d


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		_prompt.show()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		_prompt.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside:
		return
	if event.is_action_pressed("interact"):
		interact()
		get_viewport().set_input_as_handled()


func interact() -> void:
	# ★ เรื่องเควสมาก่อน ★ คุยเรื่องเควสให้จบก่อน แล้วค่อยเปิดร้าน/ตีบวกตามปกติ
	var quest_handled: bool = await _handle_quests()
	if quest_handled and type == NPCType.DIALOG:
		return
	if not is_instance_valid(self):
		return

	match type:
		NPCType.SHOP:
			var ids: Array = []
			for id in shop_items:
				ids.append(id)
			Events.shop_opened.emit(ids)

		NPCType.REFINER:
			Events.refine_npc_opened.emit()

		NPCType.HEALER:
			if PlayerState.stats.hp >= PlayerState.stats.max_hp \
					and PlayerState.stats.sp >= PlayerState.stats.max_sp:
				Events.say("%s: เลือดกับพลังเต็มอยู่แล้วนะ" % npc_name)
			elif PlayerState.zeny < heal_price:
				Events.say("%s: ค่ารักษา %d ซีนี ซีนีไม่พอนะ" % [npc_name, heal_price])
			else:
				PlayerState.add_zeny(-heal_price)
				PlayerState.heal_hp(PlayerState.stats.max_hp)
				PlayerState.restore_sp(PlayerState.stats.max_sp)
				Events.say("%s: หายดีแล้ว!" % npc_name)

		NPCType.SAVE_POINT:
			SaveManager.save_game(0)

		_:
			# ★ คุยผ่านกล่องสนทนา ★ เว้นบรรทัดว่าง = ขึ้นหน้าใหม่
			var pages: Array = []
			for part in dialog.split("\n\n", false):
				var t := String(part).strip_edges()
				if t != "":
					pages.append(line(t))
			if pages.is_empty():
				pages.append(line(dialog))
			await UI.talk(pages)


# =========================================================
# เควส
# =========================================================
## จัดการเควสของ NPC คนนี้ — คืน true ถ้ามีเรื่องเควสให้คุย
## หมายเหตุ: คุยจบแล้วยังเปิดร้าน/ตีบวกต่อได้ตามปกติ (NPC ที่มีเควสจะไม่ถูกบล็อก)
func _handle_quests() -> bool:
	if quest_ids.is_empty():
		return false
	var log := PlayerState.quests
	var lv: int = PlayerState.stats.level

	# 1) มีเควสที่ทำครบแล้ว -> ส่งเควส
	for qid in quest_ids:
		if log.is_ready(qid):
			await _ask_turn_in(GameData.get_quest(qid))
			return true

	# 2) มีเควสที่รับไว้แล้วแต่ยังไม่ครบ -> บอกความคืบหน้า
	for qid in quest_ids:
		if log.is_active(qid):
			var q := GameData.get_quest(qid)
			if q == null:
				continue
			await UI.talk([line(q.dialog_progress,
				"ความคืบหน้า: %s" % q.objective_text(log.count_of(qid)))])
			return true

	# 3) มีเควสใหม่ให้รับ -> ถามว่ารับไหม
	for qid in quest_ids:
		if log.can_accept(qid, lv):
			await _ask_accept(GameData.get_quest(qid))
			return true

	return false


## ★ ชวนรับเควส — คุยกันเป็นบทสนทนา ★
func _ask_accept(q: QuestData) -> void:
	if q == null:
		return
	var script: Array = [line(q.dialog_offer)]
	if q.description != "" and q.description != q.dialog_offer:
		script.append(line(q.description))
	script.append(line("เอาไงล่ะ รับงานนี้มั้ย",
		"[ %s ]  เงื่อนไข: %s\nรางวัล: %s" % [q.title, q.objective_text(0), q.reward_text()],
		["รับเควส", "ไว้ก่อน"]))

	var pick: int = await UI.talk(script)
	if pick == 0 and is_instance_valid(self):
		PlayerState.quests.accept(q.id)
		Events.say("[รับเควส] %s — %s" % [q.title, q.objective_text(0)])


func _ask_turn_in(q: QuestData) -> void:
	if q == null:
		return
	var pick: int = await UI.talk([
		line(q.dialog_complete,
			"[ %s ]  รางวัล: %s" % [q.title, q.reward_text()],
			["รับรางวัล", "ไว้ก่อน"]),
	])
	if pick == 0 and is_instance_valid(self):
		PlayerState.turn_in_quest(q.id)
