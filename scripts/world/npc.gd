## NPC — คนในเมือง (ร้านค้า / ช่างตีบวก / หมอ / เซฟเกม)
##
## โครงสร้าง Scene:
##   NPC (Area2D)  <- ใส่สคริปต์นี้
##   ├── Sprite2D หรือ AnimatedSprite2D
##   ├── CollisionShape2D
##   └── Label   (ชื่อ NPC — ไม่ใส่ก็ได้)
extends Area2D

## ★ รอบ 57 ★ SAVE_POINT กลายเป็น "เสาวาป" แล้ว (วาปข้ามแมพ + บันทึกเกม)
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
## ★ รอบ 56 ★ มีเมนู "เจาะรูการ์ด" ไหม (ช่างตีเหล็ก REFINER มีให้อัตโนมัติอยู่แล้ว)
@export var has_socket: bool = false
## ★ รอบ 57 ★ มีเมนู "ตีบวก" ไหม (ช่างตีเหล็ก REFINER มีให้อัตโนมัติอยู่แล้ว)
@export var has_refine: bool = false

# =========================================================
# ★★ เสาวาป (รอบ 57) ★★ — ใช้กับ NPC ชนิด SAVE_POINT
# ปลายทางเพิ่มทีหลังแค่เติม id แมพในลิสต์ (ต้องมีใน Game.MAPS)
# ถ้าอยากให้ปลายทางไหน "ปลดล็อกก่อนถึงไปได้" ใส่ธงเนื้อเรื่องใน Warp Flags
# =========================================================
@export_group("เสาวาป")
## แมพปลายทางที่วาปไปได้ (เรียงตามลำดับที่อยากให้โชว์)
@export var warp_targets: Array[StringName] = [&"asgard_forest_2"]
## ปลายทางไหนต้องปลดล็อกก่อน — { map_id: ธงเนื้อเรื่อง } (ไม่ใส่ = ไปได้เลย)
@export var warp_flags: Dictionary = {}
## จุดเกิดที่จะไปโผล่ในแมพปลายทาง (ไม่มีชื่อนี้ในแมพ ระบบใช้ default ให้เอง)
@export var warp_spawn_point: StringName = &"default"
## เสาวาปนี้บันทึกเกมให้ด้วยไหม (เดิม SavePoint ทำหน้าที่นี้)
@export var warp_saves_game: bool = true
## ★ รอบ 45 — ประโยคทักตอนเปิดเมนู พูดคุย / ซื้อขาย / ไม่คุย ★
@export var greeting: String = "มีอะไรให้ช่วยไหม"

# =========================================================
# ★★ เสียงพากย์ (รอบ 59) ★★
# วางไฟล์  Sprites/voice/<Voice Id>/<ประโยค>.ogg  แล้วระบบเล่นให้เองตอนขึ้นบรรทัดนั้นในกล่องสนทนา
# ชื่อประโยค: greeting · dialog_1.. · <ธง>_1.. · <เควส>_offer_1.. · <เควส>_offer_ask · <เควส>_progress
#            · <เควส>_complete · <เควส>_choice · <เควส>_cutscene_1.. · heal_full · heal_poor · heal_done
# ดูรายการทั้งหมดพร้อมคำพูด:  python3 dump_npc_lines.py
# =========================================================
@export_group("เสียงพากย์")
## โฟลเดอร์เสียงของตัวละครนี้ (ว่าง = ไม่มีเสียงพากย์) เช่น hans · tony · maria
@export var voice_id: String = ""

## ★ เควสที่ NPC คนนี้เป็นคนให้ ★ (ใส่ id ของเควสจาก data/quests/)
## ใส่ได้กับ NPC ทุกแบบ ไม่ใช่แค่แบบ QUEST — คุยแล้วจะถามเรื่องเควสก่อน แล้วค่อยเปิดร้าน
@export var quest_ids: Array[StringName] = []

## ★★ รอบ 47 — เครื่องหมายเควสเหนือหัว ! ? ★★
## ใหญ่ขึ้น มีวงป้ายรองให้เห็นชัดบนฉากหลังทุกสี และลอยอยู่ "เหนือป้ายชื่อ" ไม่ทับตัวละคร
const MARK_SIZE := 74.0        # ขนาดวงป้าย (พิกเซล)
const MARK_FONT := 50          # ขนาดตัวอักษร ! ?
const MARK_GAP := 16.0         # ห่างจากขอบบนของป้ายชื่อขึ้นไป
const MARK_FALLBACK_TOP := -174.0   # NPC ที่ไม่มีป้ายชื่อ ใช้ระดับเดียวกับป้ายชื่อในแม่แบบ
const MARK_BOB := 7.0          # ลอยขึ้น-ลงกี่พิกเซล
const MARK_BOB_SPEED := 2.4

var _player_inside := false
var _prompt: Label
var _mark: Control
var _mark_glyph: Label
var _mark_disc: _MarkDisc
var _mark_base_y := 0.0


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

	_build_mark(label)

	Events.quest_changed.connect(_refresh_mark)
	_refresh_mark()


## ★ รอบ 47 — สร้างป้าย ! ? เหนือหัว (วงรอง + ตัวอักษรใหญ่) ★
func _build_mark(name_label: Label) -> void:
	# วางให้ "ขอบล่างของวง" อยู่เหนือขอบบนของป้ายชื่อ — NPC ตัวสูง/เตี้ยก็ไม่ทับชื่อ
	var name_top: float = name_label.offset_top if name_label != null else MARK_FALLBACK_TOP
	_mark_base_y = name_top - MARK_GAP - MARK_SIZE

	_mark = Control.new()
	_mark.name = "QuestMark"
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark.size = Vector2(MARK_SIZE, MARK_SIZE)
	_mark.position = Vector2(-MARK_SIZE * 0.5, _mark_base_y)
	_mark.hide()
	add_child(_mark)

	_mark_disc = _MarkDisc.new()
	_mark_disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark.add_child(_mark_disc)

	_mark_glyph = Label.new()
	_mark_glyph.text = "!"
	_mark_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark_glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mark_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mark_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mark_glyph.add_theme_font_size_override("font_size", MARK_FONT)
	_mark_glyph.add_theme_color_override("font_color", Color("#ffe14a"))
	_mark_glyph.add_theme_color_override("font_outline_color", Color.BLACK)
	_mark_glyph.add_theme_constant_override("outline_size", 8)
	_mark.add_child(_mark_glyph)


## ป้ายลอยขึ้นลงเบา ๆ ให้สะดุดตา (ทำงานเฉพาะตอนป้ายโชว์อยู่)
func _process(_delta: float) -> void:
	if _mark == null or not _mark.visible:
		return
	var t: float = float(Time.get_ticks_msec()) * 0.001 * MARK_BOB_SPEED
	_mark.position.y = _mark_base_y + sin(t) * MARK_BOB


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
			_show_mark("?", Color("#7dffa8"))   # เอาไปส่งได้แล้ว = เขียว
			return
	for qid in quest_ids:
		if log.can_accept(qid, lv):
			_show_mark("!", Color("#ffe14a"))   # มีเควสให้รับ = เหลือง
			return
	_mark.hide()


func _show_mark(glyph: String, tint: Color) -> void:
	_mark_glyph.text = glyph
	_mark_glyph.add_theme_color_override("font_color", tint)
	if _mark_disc != null:
		_mark_disc.tint = tint
		_mark_disc.queue_redraw()
	_mark.position.y = _mark_base_y
	_mark.show()


## รูปที่จะโชว์ในกล่องสนทนา (ไม่มีก็คืน null — กล่องจะไม่โชว์ช่องรูป)
func portrait_texture() -> Texture2D:
	if portrait != null:
		return portrait
	if portrait_file != "" and ResourceLoader.exists(portrait_file):
		return load(portrait_file) as Texture2D
	return null


## บทพูดของ NPC คนนี้ 1 บรรทัด (ใส่ชื่อ + รูป + ฝั่งให้อัตโนมัติ)
func line(text: String, info: String = "", choices: Array = [], voice_key: String = "") -> Dictionary:
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
	var v := voice_path(voice_key)
	if v != "":
		d["voice"] = v
	return d


## ★ รอบ 59 ★ "voice_id/key" ของประโยคนี้ ("" = NPC ไม่มีเสียงพากย์ หรือไม่ได้ระบุประโยค)
func voice_path(key: String) -> String:
	if voice_id == "" or key == "":
		return ""
	return voice_id + "/" + key


## เล่นเสียงพากย์ทันที (ใช้กับประโยคที่ไม่ได้ผ่านกล่องสนทนา เช่นหมอรักษา)
func say_voice(key: String) -> void:
	var v := voice_path(key)
	if v == "" or Game.voice == null:
		return
	Game.voice.play_path(v)


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

	# ★ รอบ 57 — เสาวาป ★ (เดิมเป็นศิลาเซฟ กดแล้วเซฟทันที ตอนนี้มีเมนูให้เลือกปลายทาง)
	if type == NPCType.SAVE_POINT:
		await open_warp_menu()
		return

	# ★★ รอบ 45 — เมนูก่อนคุย: พูดคุย / ซื้อขาย / ไม่คุย ★★
	var options: Array = [MENU_TALK]
	if has_shop_menu():
		options.append(MENU_SHOP)
	if has_refine_menu():
		options.append(MENU_REFINE)
	if has_socket_menu():
		options.append(MENU_SOCKET)
	options.append(MENU_LEAVE)
	var pick: int = await UI.talk([line(greeting, "", options, "greeting")])
	if not is_instance_valid(self) or pick < 0 or pick >= options.size():
		return
	var chosen: String = options[pick]
	if chosen == MENU_LEAVE:
		return
	if chosen == MENU_SHOP:
		open_shop()
		return
	if chosen == MENU_REFINE:
		Events.refine_npc_opened.emit()
		return
	if chosen == MENU_SOCKET:
		Events.socket_npc_opened.emit()
		return

	# ---- พูดคุย: เรื่องเควสมาก่อน แล้วค่อยบริการ/บทพูด ----
	var quest_handled: bool = await _handle_quests()
	if quest_handled or not is_instance_valid(self):
		return

	match type:
		NPCType.HEALER:
			if PlayerState.stats.hp >= PlayerState.stats.max_hp \
					and PlayerState.stats.sp >= PlayerState.stats.max_sp:
				Events.say("%s: เลือดกับพลังเต็มอยู่แล้วนะ" % npc_name)
				say_voice("heal_full")
			elif PlayerState.zeny < heal_price:
				Events.say("%s: ค่ารักษา %d ซีนี ซีนีไม่พอนะ" % [npc_name, heal_price])
				say_voice("heal_poor")
			else:
				PlayerState.add_zeny(-heal_price)
				PlayerState.heal_hp(PlayerState.stats.max_hp)
				PlayerState.restore_sp(PlayerState.stats.max_sp)
				Events.say("%s: หายดีแล้ว!" % npc_name)
				say_voice("heal_done")

		_:
			# ★ คุยผ่านกล่องสนทนา ★ เว้นบรรทัดว่าง = ขึ้นหน้าใหม่
			var pages: Array = []
			var vkey := current_dialog_key()       # dialog / ชื่อธง → ไฟล์เสียง <vkey>_1, _2 ...
			for part in current_dialog().split("\n\n", false):
				var t := String(part).strip_edges()
				if t != "":
					pages.append(line(t, "", [], "%s_%d" % [vkey, pages.size() + 1]))
			if pages.is_empty():
				pages.append(line(current_dialog(), "", [], vkey + "_1"))
			await UI.talk(pages)


const MENU_TALK := "พูดคุย"
const MENU_SHOP := "ซื้อขาย"
const MENU_REFINE := "ตีบวก"
const MENU_SOCKET := "เจาะรูการ์ด"
const MENU_LEAVE := "ไม่คุย"
const MENU_SAVE := "บันทึกเกม"


## มีเมนูซื้อขายไหม — ร้านค้า หรือ NPC ที่ติ๊ก Has Shop
func has_shop_menu() -> bool:
	return type == NPCType.SHOP or has_shop


## มีเมนูเจาะรูการ์ดไหม — ช่างตีเหล็ก (REFINER) มีให้เลย หรือ NPC ที่ติ๊ก Has Socket
func has_socket_menu() -> bool:
	return type == NPCType.REFINER or has_socket


## มีเมนูตีบวกไหม — ช่างตีเหล็ก (REFINER) มีให้เลย หรือ NPC ที่ติ๊ก Has Refine
func has_refine_menu() -> bool:
	return type == NPCType.REFINER or has_refine


# =========================================================
# ★★ เสาวาป (รอบ 57) ★★
# =========================================================
## ปลายทางที่ "เปิดให้ไปได้ตอนนี้" — คืน Array ของ { "id": StringName, "name": String }
func warp_options() -> Array:
	var out: Array = []
	for mid in warp_targets:
		var id := StringName(mid)
		if not Game.MAPS.has(id):
			push_warning("[เสาวาป] ไม่รู้จักแมพ %s" % id)
			continue
		if id == PlayerState.current_map_id:
			continue                      # อยู่แมพนี้อยู่แล้ว ไม่ต้องโชว์
		if warp_flags.has(id) and not PlayerState.has_flag(StringName(warp_flags[id])):
			continue                      # ยังไม่ปลดล็อก
		out.append({"id": id, "name": Game.map_display_name(id)})
	return out


## เปิดเมนูเสาวาป
func open_warp_menu() -> void:
	var targets := warp_options()
	var options: Array = []
	for t in targets:
		options.append("ไป %s" % String(t["name"]))
	if warp_saves_game:
		options.append(MENU_SAVE)
	options.append(MENU_LEAVE)

	var head: String = current_dialog()
	if targets.is_empty():
		head = "%s
(ยังไม่มีปลายทางให้ไป)" % head
	var pick: int = await UI.talk([line(head, "", options)])
	if not is_instance_valid(self) or pick < 0 or pick >= options.size():
		return
	var chosen: String = options[pick]
	if chosen == MENU_LEAVE:
		return
	if chosen == MENU_SAVE:
		SaveManager.save_game(0)
		return
	if pick < targets.size():
		var dest: StringName = targets[pick]["id"]
		Events.say("กำลังวาปไป %s..." % String(targets[pick]["name"]))
		await Game.change_map(dest, warp_spawn_point)


func open_shop() -> void:
	var ids: Array = []
	for id in shop_items:
		ids.append(id)
	Events.shop_opened.emit(ids)


## ★ บทพูดที่ควรใช้ตอนนี้ ★ ดูจากธงเนื้อเรื่องที่ตั้งไว้แล้ว
## ไล่จากท้ายลิสต์ขึ้นมา — ธงตัวหลังชนะตัวหน้า (เขียนเรียงตามลำดับเนื้อเรื่องได้เลย)
func current_dialog() -> String:
	var k := current_dialog_key()
	if k != "dialog":
		return String(dialog_by_flag[k]).strip_edges()
	return dialog


## ★ รอบ 59 ★ บทพูดชุดไหนกำลังใช้อยู่ — "dialog" (ปกติ) หรือชื่อธงใน dialog_by_flag
## ใช้เป็นชื่อไฟล์เสียงพากย์ด้วย: <key>_1.ogg, <key>_2.ogg ...
func current_dialog_key() -> String:
	if not dialog_by_flag.is_empty() and PlayerState != null:
		var keys: Array = dialog_by_flag.keys()
		for i in range(keys.size() - 1, -1, -1):
			var flag := StringName(keys[i])
			if PlayerState.has_flag(flag):
				var t := String(dialog_by_flag[keys[i]]).strip_edges()
				if t != "":
					return String(keys[i])
	return "dialog"


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
				"ความคืบหน้า: %s" % q.objective_text(log.count_of(qid)), [], String(qid) + "_progress")])
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
	var qk := String(q.id)
	var script: Array = []
	# บทชวน (เว้นบรรทัดว่าง = ขึ้นหน้าใหม่) → เสียง <เควส>_offer_1, _offer_2 ...
	for part in q.dialog_offer.split("\n\n", false):
		var t := String(part).strip_edges()
		if t != "":
			script.append(line(t, "", [], "%s_offer_%d" % [qk, script.size() + 1]))
	if script.is_empty():
		script.append(line(q.dialog_offer, "", [], qk + "_offer_1"))
	if q.description != "" and q.description != q.dialog_offer:
		script.append(line(q.description, "", [], "%s_offer_%d" % [qk, script.size() + 1]))
	script.append(line("เอาไงล่ะ รับงานนี้มั้ย",
		"[ %s ]  เงื่อนไข: %s\nรางวัล: %s" % [q.title, q.objective_text(0), q.reward_text()],
		["รับเควส", "ไว้ก่อน"], qk + "_offer_ask"))

	var pick: int = await UI.talk(script)
	if pick == 0 and is_instance_valid(self):
		PlayerState.quests.accept(q.id)
		Events.say("[รับเควส] %s — %s" % [q.title, q.objective_text(0)])
		# ★ รอบ 59 — วิดีโอคัทซีนตอนรับเควส ★
		if q.video_on_accept != "":
			await UI.play_video(q.video_on_accept)


func _ask_turn_in(q: QuestData) -> void:
	if q == null:
		return
	var pick: int = await UI.talk([
		line(q.dialog_complete,
			"[ %s ]  รางวัล: %s" % [q.title, q.reward_text()],
			["รับรางวัล", "ไว้ก่อน"], String(q.id) + "_complete"),
	])
	if pick == 0 and is_instance_valid(self):
		PlayerState.turn_in_quest(q.id)
		# ★ รอบ 59 — วิดีโอคัทซีนตอนส่งเควส (ก่อนตัวเลือก/แพนกล้อง) ★
		if q.video_on_complete != "":
			await UI.play_video(q.video_on_complete)
		if not is_instance_valid(self):
			return
		await _after_turn_in(q)


## ★ เหตุการณ์หลังส่งเควส (รอบ 38) ★ ตัวเลือกเนื้อเรื่อง + ฉากแพนกล้อง
func _after_turn_in(q: QuestData) -> void:
	# ---------- ตัวเลือกที่เกมจะจำไว้ (เช่น M2 สาบาน/เงียบ) ----------
	if q.choice_prompt != "" and not q.choice_options.is_empty():
		var choice: int = await UI.talk([line(q.choice_prompt, "", q.choice_options, String(q.id) + "_choice")])
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
	# เสียงพากย์ฉากนี้ใช้ voice_id ของ NPC ที่กล้องแพนไปหา (ไม่มีก็ใช้ของคนให้เควส)
	var cut_voice: String = voice_id
	if target != null and "voice_id" in target and String(target.voice_id) != "":
		cut_voice = String(target.voice_id)
	var pages: Array = []
	for part in q.cutscene_text.split("\n\n", false):
		var t := String(part).strip_edges()
		if t != "":
			var pg := {"name": q.cutscene_pan_npc, "side": 1, "text": t}
			if cut_voice != "":
				pg["voice"] = "%s/%s_cutscene_%d" % [cut_voice, String(q.id), pages.size() + 1]
			pages.append(pg)
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


# =========================================================
# ★ รอบ 47 — วงป้ายรองหลังเครื่องหมาย ! ? ★
# วาดเอง (ไม่ต้องมีไฟล์ภาพ) — วงเข้มทึบ + ขอบสีตามชนิดเครื่องหมาย + เงาจาง ๆ
# ทำให้ ! ? อ่านออกทั้งบนฉากหลังสว่างและมืด
# =========================================================
class _MarkDisc extends Control:
	var tint := Color("#ffe14a")

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r: float = minf(size.x, size.y) * 0.5
		# แสงเรืองจาง ๆ รอบนอก
		draw_circle(c, r, Color(tint.r, tint.g, tint.b, 0.16))
		# วงพื้นเข้ม
		draw_circle(c, r * 0.78, Color(0.05, 0.06, 0.1, 0.82))
		# ขอบสี
		draw_arc(c, r * 0.78, 0.0, TAU, 40, tint, 4.0, true)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()
