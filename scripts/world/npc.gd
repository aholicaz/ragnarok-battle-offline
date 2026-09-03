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

## ★★ บทพูดชุดพิเศษตามธงเนื้อเรื่อง (รอบ 30) ★★
##
## ใส่แบบ  {"saw_ceremony": "บทพูดชุดใหม่...", "beat_boss": "อีกชุด..."}
## ระบบจะไล่จาก "ล่างขึ้นบน" — ธงตัวท้ายสุดที่ตั้งไว้แล้วชนะ
## ไม่มีธงไหนตรงเลย = ใช้ช่อง Dialog ปกติ
##
## ตัวอย่างของตาแก่กุนนาร์:
##   {
##     "saw_ceremony": "ถ้าธอร์ปกป้องพวกเรา... แล้วเหตุใดทุกครั้งที่สายฟ้าฟาด\n\nป่าจึงเงียบลงเหมือนมีบางสิ่งตายไป?",
##     "beat_stormscar": "เจ้าเห็นแสงมันไหลลงดินใช่ไหม..."
##   }
@export var dialog_by_flag: Dictionary = {}

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
## ★ รอบ 45 — NPC ประเภทอื่น (เช่นนักบวช) ก็มีร้านได้ ★ ติ๊กแล้วเมนู "ซื้อขาย" จะโผล่ (ใช้ Shop Items ข้างบน)
@export var has_shop: bool = false
## ★ รอบ 45 — ประโยคทักตอนเปิดเมนู พูดคุย / ซื้อขาย / ไม่คุย ★
@export var greeting: String = "มีอะไรให้ช่วยไหม"

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
	# ★ เดินความคืบหน้าเควสชนิด "คุยกับ NPC" ★ (รอบ 30)
	# ทำก่อนอย่างอื่น เผื่อการคุยครั้งนี้ทำให้เควสครบพอดี แล้วส่งเควสได้เลยในครั้งเดียว
	if PlayerState.quests != null:
		PlayerState.quests.on_talked_to(npc_name)

	# ศิลาเซฟไม่ใช่คน — ไม่มีเมนู
	if type == NPCType.SAVE_POINT:
		SaveManager.save_game(0)
		return

	# ★★ รอบ 45 — เมนูก่อนคุย: พูดคุย / ซื้อขาย / ไม่คุย ★★
	var options: Array = [MENU_TALK]
	if has_shop_menu():
		options.append(MENU_SHOP)
	options.append(MENU_LEAVE)
	var pick: int = await UI.talk([line(greeting, "", options)])
	if not is_instance_valid(self) or pick < 0 or pick >= options.size():
		return
	var chosen: String = options[pick]
	if chosen == MENU_LEAVE:
		return
	if chosen == MENU_SHOP:
		open_shop()
		return

	# ---- พูดคุย: เรื่องเควสมาก่อน แล้วค่อยบริการ/บทพูด ----
	var quest_handled: bool = await _handle_quests()
	if quest_handled or not is_instance_valid(self):
		return

	match type:
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

		_:
			# ★ คุยผ่านกล่องสนทนา ★ เว้นบรรทัดว่าง = ขึ้นหน้าใหม่
			var pages: Array = []
			for part in current_dialog().split("\n\n", false):
				var t := String(part).strip_edges()
				if t != "":
					pages.append(line(t))
			if pages.is_empty():
				pages.append(line(current_dialog()))
			await UI.talk(pages)


const MENU_TALK := "พูดคุย"
const MENU_SHOP := "ซื้อขาย"
const MENU_LEAVE := "ไม่คุย"


## มีเมนูซื้อขายไหม — ร้านค้า หรือ NPC ที่ติ๊ก Has Shop
func has_shop_menu() -> bool:
	return type == NPCType.SHOP or has_shop


func open_shop() -> void:
	var ids: Array = []
	for id in shop_items:
		ids.append(id)
	Events.shop_opened.emit(ids)


## ★ บทพูดที่ควรใช้ตอนนี้ ★ ดูจากธงเนื้อเรื่องที่ตั้งไว้แล้ว
## ไล่จากท้ายลิสต์ขึ้นมา — ธงตัวหลังชนะตัวหน้า (เขียนเรียงตามลำดับเนื้อเรื่องได้เลย)
func current_dialog() -> String:
	if not dialog_by_flag.is_empty() and PlayerState != null:
		var keys: Array = dialog_by_flag.keys()
		for i in range(keys.size() - 1, -1, -1):
			var flag := StringName(keys[i])
			if PlayerState.has_flag(flag):
				var t := String(dialog_by_flag[keys[i]]).strip_edges()
				if t != "":
					return t
	return dialog


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
		await _after_turn_in(q)


## ★ เหตุการณ์หลังส่งเควส (รอบ 38) ★ ตัวเลือกเนื้อเรื่อง + ฉากแพนกล้อง
func _after_turn_in(q: QuestData) -> void:
	# ---------- ตัวเลือกที่เกมจะจำไว้ (เช่น M2 สาบาน/เงียบ) ----------
	if q.choice_prompt != "" and not q.choice_options.is_empty():
		var choice: int = await UI.talk([line(q.choice_prompt, "", q.choice_options)])
		if not is_instance_valid(self):
			return
		if choice >= 0 and choice < q.choice_flags.size() and q.choice_flags[choice] != &"":
			PlayerState.set_flag(q.choice_flags[choice])

	# ---------- ฉากแพนกล้องไปหา NPC (เช่น M6 กล้องไปหยุดที่กุนนาร์) ----------
	if q.cutscene_pan_npc == "":
		return
	var target: Node2D = null
	for n in get_tree().get_nodes_in_group("npc"):
		if n != self and "npc_name" in n and String(n.npc_name) == q.cutscene_pan_npc:
			target = n
			break
	var pages: Array = []
	for part in q.cutscene_text.split("\n\n", false):
		var t := String(part).strip_edges()
		if t != "":
			pages.append({"name": q.cutscene_pan_npc, "side": 1, "text": t})
	var player := get_tree().get_first_node_in_group("player")
	var cam: Camera2D = player.get_node_or_null("Camera2D") if player != null else null
	if target == null or cam == null:
		# หา NPC ไม่เจอ (คนละแมพ) — โชว์แค่ข้อความ
		if not pages.is_empty():
			await UI.talk(pages)
		return
	# แพนกล้องไปหา → คุย → แพนกลับ
	var off: Vector2 = target.global_position - (player as Node2D).global_position + Vector2(0, -40)
	var tw := create_tween()
	tw.tween_property(cam, "offset", off, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	if not is_instance_valid(self):
		return
	if not pages.is_empty():
		await UI.talk(pages)
	if not is_instance_valid(self) or cam == null:
		return
	var back := create_tween()
	back.tween_property(cam, "offset", Vector2.ZERO, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await back.finished
