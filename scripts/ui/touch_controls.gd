## TouchControls — ปุ่มบนจอสำหรับเล่นบนมือถือ / จอสัมผัส
##
## ★ ทำไมต้องเขียนเอง ไม่ใช้ปุ่มธรรมดา ★
## Godot แปลง "นิ้วแรก" เป็นเมาส์ให้เท่านั้น ถ้าใช้ Button ปกติจะกดได้ทีละปุ่ม
## (เดินไปตีไปไม่ได้) ไฟล์นี้เลยอ่าน InputEventScreenTouch เองแยกตามนิ้ว (multi-touch)
##
## ★ ปุ่มส่งเป็น "action" ★ เกมทั้งเกมเลยไม่ต้องแก้อะไรเลย
## กดปุ่มบนจอ = เหมือนกดคีย์บอร์ด (ทั้งแบบ polling และแบบรับ event)
##
## ★ เปิด/ปิด ★  UI.touch.set_mode(TouchControls.Mode.AUTO / ON / OFF)
## AUTO = โผล่เองเมื่อเครื่องมีจอสัมผัส หรือเมื่อมีการแตะจอครั้งแรก
## ค่าที่เลือกถูกจำไว้ใน user://ui_layout.cfg
class_name TouchControls
extends Control

enum Mode { AUTO, ON, OFF }

const LAYOUT_PATH := "user://ui_layout.cfg"

## ---------- ขนาดปุ่ม (แก้ตรงนี้ถ้าอยากให้ใหญ่/เล็กลง) — รอบ 45 ใหญ่ขึ้น + ยกสูงจากขอบล่าง ----------
const PAD_BIG := 128.0        # ปุ่มเดินซ้าย-ขวา
const PAD_ATTACK := 150.0     # ★ ปุ่มโจมตี (ใหญ่สุด อยู่กลางวงสกิล) ★
const PAD_MID := 100.0        # คุย/เก็บของ · ★ รอบ 47 — ยา/มานา/พุ่งหลบ ใช้ขนาดนี้ด้วย ★
const PAD_SMALL := 86.0       # สกิล 1-4 (ล้อมรอบปุ่มโจมตี)
const PAD_TINY := 70.0        # (สำรองไว้ — รอบ 47 เลิกใช้กับแถวยาแล้ว)
const EDGE := 26.0            # ห่างจากขอบซ้าย-ขวา
const EDGE_BOTTOM := 64.0     # ★ ห่างจากขอบล่าง (เดิม 22 — นิ้วโป้งจะได้ไม่ชนขอบเครื่อง) ★
const GAP := 12.0             # ห่างระหว่างปุ่ม
## ★ วงสกิลรอบปุ่มโจมตี: เริ่มที่ 8 นาฬิกา ไปจบที่ 1 นาฬิกา (ตามเข็ม) ★  (มุมนาฬิกา: 12 = บน · 3 = ขวา)
const SKILL_CLOCK_START := 8.0
const SKILL_CLOCK_END := 13.0

## ★★ รอบ 47 — ความจางอยู่ที่ "แผ่นปุ่ม" ไม่ใช่ทั้งปุ่ม ★★
## เดิมตั้ง node.modulate.a = 0.55 ซึ่งจางลงไปถึงไอคอนข้างในด้วย → ไอคอนสกิลดูซีดเป็นสีเทา
## ตอนนี้ใส่ alpha ลงในสีของ StyleBox เอง (พื้น+ขอบ) ไอคอน/ตัวหนังสือจึงเป็นสีปกติเต็มที่
const PLATE_ALPHA := 0.55     # ความจางของแผ่นปุ่มตอนไม่ได้กด
const PLATE_ALPHA_HOLD := 0.9 # ตอนกด
## ไอคอนสกิลตอนคูลดาวน์: เทาเท่าไหร่ (0 = ดำ · 1 = สีปกติ) แล้วไล่กลับมา 1.0 เมื่อคูลดาวน์ครบ
const CD_GRAY := 0.34

var mode: Mode = Mode.AUTO

## รายการปุ่มทั้งหมด: {id, action, label, size, node, rect, callable}
var _zones: Array = []
## นิ้วไหนกดปุ่มไหนอยู่ (index ของนิ้ว -> id ปุ่ม)
var _fingers: Dictionary = {}
var _shown := false


func _ready() -> void:
	name = "TouchControls"
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 190
	# ปุ่มพวกนี้ไม่กินเมาส์ — เราอ่านการแตะเองใน _input()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	_define_zones()
	_build()
	_load_mode()
	get_viewport().size_changed.connect(_layout)
	_refresh_visible()


# =========================================================
# รายการปุ่ม
# =========================================================
func _define_zones() -> void:
	# ฝั่งซ้าย = เดิน · ฝั่งขวา = สู้
	_zones = [
		{"id": "left",    "action": "move_left",  "arrow": "left",  "size": PAD_BIG},
		{"id": "right",   "action": "move_right", "arrow": "right", "size": PAD_BIG},
		{"id": "down",    "action": "move_down",  "arrow": "down",  "size": PAD_MID},

		{"id": "attack",  "action": "attack",   "label": "โจมตี",  "size": PAD_ATTACK},
		{"id": "interact","action": "interact", "label": "คุย/เก็บ", "size": PAD_MID},

		{"id": "skill_1", "action": "skill_1", "label": "1", "size": PAD_SMALL, "skill": 0},
		{"id": "skill_2", "action": "skill_2", "label": "2", "size": PAD_SMALL, "skill": 1},
		{"id": "skill_3", "action": "skill_3", "label": "3", "size": PAD_SMALL, "skill": 2},
		{"id": "skill_4", "action": "skill_4", "label": "4", "size": PAD_SMALL, "skill": 3},

		# ★ รอบ 47 — แถวนี้ใหญ่เท่าปุ่มคุย (100) · ยา/มานาโชว์ไอคอนยาที่จะถูกใช้ + จำนวนที่เหลือ ★
		{"id": "potion",  "action": "quick_potion",    "label": "ยา", "size": PAD_MID, "item": 0},
		{"id": "sp",      "action": "quick_sp_potion", "label": "มานา", "size": PAD_MID, "item": 1},
		# ★ รอบ 47 — คืนปุ่มพุ่งหลบ (แทนปุ่มเมนูเดิม · เมนูระบบยังกดได้จากแถบไอคอนมุมขวาบน) ★
		{"id": "dash",    "action": "jump", "label": "พุ่งหลบ", "size": PAD_MID},
	]


func _build() -> void:
	for z in _zones:
		var panel := PanelContainer.new()
		panel.name = "Btn_%s" % z.id
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", _pad_style(false))
		add_child(panel)
		z["node"] = panel

		if z.has("arrow"):
			var arrow := _Arrow.new()
			arrow.dir = String(z.arrow)
			arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(arrow)
			if z.has("caption"):
				var cap := UITheme.make_label(String(z.caption), 13, Color(1, 1, 1, 0.85))
				cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
				cap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
				cap.offset_top = -20
				cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				panel.add_child(cap)
		else:
			# ★ รอบ 45 — ปุ่มสกิลมีไอคอนสกิลข้างใน (ถ้าช่องลัดนั้นตั้งสกิลไว้) ★
			# ★ รอบ 47 — ปุ่มยา/มานาก็มีไอคอนไอเทมแบบเดียวกัน ★
			if z.has("skill") or z.has("item"):
				var art := TextureRect.new()
				art.name = "SkillIcon"
				art.mouse_filter = Control.MOUSE_FILTER_IGNORE
				art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				var m := float(z.size) * 0.2   # ให้สี่เหลี่ยมไอคอนอยู่ในวงกลมพอดี
				art.offset_left = m
				art.offset_top = m
				art.offset_right = -m
				art.offset_bottom = -m
				panel.add_child(art)
				z["icon"] = art
				# ★ รอบ 47 — ม่านคูลดาวน์ (วาดทับไอคอน) เหลือเท่าไหร่ก็บังเท่านั้น แล้วเปิดออกจนหมด ★
				if z.has("skill"):
					var veil := _CooldownVeil.new()
					veil.name = "Cooldown"
					veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
					panel.add_child(veil)
					z["veil"] = veil
			var lbl := UITheme.make_label(String(z.get("label", "")),
				20 if float(z.size) >= PAD_MID else 15, Color.WHITE)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.add_theme_color_override("font_outline_color", Color.BLACK)
			lbl.add_theme_constant_override("outline_size", 5)
			panel.add_child(lbl)
			z["label_node"] = lbl
			if z.has("skill") or z.has("item"):
				# เลขช่อง / จำนวนยา เล็ก ๆ มุมขวาล่าง เมื่อมีไอคอนแล้ว
				lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
				lbl.offset_left = -30
				lbl.offset_top = -26
				lbl.offset_right = -8
				lbl.offset_bottom = -6
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				lbl.add_theme_font_size_override("font_size", 15)
	if Events.has_signal("skills_changed"):
		Events.skills_changed.connect(refresh_skill_icons)
	if Events.has_signal("inventory_changed"):
		Events.inventory_changed.connect(refresh_item_icons)
	refresh_skill_icons()
	refresh_item_icons()


## ★ รอบ 45 — อัพเดตไอคอนสกิลบนปุ่มตามช่องลัด 1-4 ★
func refresh_skill_icons() -> void:
	if PlayerState == null or PlayerState.skills == null:
		return
	for z in _zones:
		if not z.has("skill") or not z.has("icon"):
			continue
		var sid: StringName = PlayerState.skills.hotkey_at(int(z.skill))
		var sk := GameData.get_skill(sid) if sid != &"" else null
		var art: TextureRect = z.icon
		art.texture = sk.icon if sk != null else null
		var lbl: Label = z.get("label_node", null)
		if lbl != null:
			# มีไอคอนแล้ว = เหลือแค่เลขช่องเล็ก ๆ · ไม่มีไอคอน = ชื่อสกิลย่อ/เลขใหญ่กลางปุ่ม
			if art.texture != null:
				lbl.text = str(int(z.skill) + 1)
			elif sk != null:
				lbl.text = sk.display_name.substr(0, 6)
			else:
				lbl.text = str(int(z.skill) + 1)


## ★ รอบ 47 — ไอคอนยา/มานาบนปุ่ม + จำนวนที่เหลือในกระเป๋า ★
## ยาที่โชว์ = ยาที่กดปุ่มนี้แล้วจะถูกใช้จริง (ช่องด่วน PlayerState.item_hotkeys — เปลี่ยนได้ในกระเป๋า)
func refresh_item_icons() -> void:
	if PlayerState == null:
		return
	for z in _zones:
		if not z.has("item") or not z.has("icon"):
			continue
		var iid: StringName = PlayerState.item_hotkey_at(int(z.item))
		var data := GameData.get_item(iid) if iid != &"" else null
		var art: TextureRect = z.icon
		art.texture = data.icon if data != null else null
		var n := 0
		if PlayerState.inventory != null and iid != &"":
			n = PlayerState.inventory.count_of(iid)
		# ยาหมด = ไอคอนหมองลง ให้รู้ตั้งแต่ยังไม่กด
		art.modulate = Color.WHITE if n > 0 else Color(CD_GRAY, CD_GRAY, CD_GRAY)
		var lbl: Label = z.get("label_node", null)
		if lbl == null:
			continue
		if art.texture != null:
			lbl.text = str(n)                        # มีไอคอนแล้ว = โชว์แค่จำนวน
			lbl.add_theme_color_override("font_color",
				Color.WHITE if n > 0 else Color("#ff9c9c"))
		else:
			lbl.text = String(z.get("label", ""))    # ยังไม่มีไอคอน = ข้อความเดิม


## ★ รอบ 47 — ไอคอนสกิลเทาตอนเพิ่งใช้ แล้วค่อย ๆ กลับมาสีสดจนคูลดาวน์ครบ ★
func _tick_cooldowns() -> void:
	if PlayerState == null or PlayerState.skills == null:
		return
	for z in _zones:
		if not z.has("skill") or not z.has("icon"):
			continue
		var art: TextureRect = z.icon
		var veil = z.get("veil", null)
		var sid: StringName = PlayerState.skills.hotkey_at(int(z.skill))
		var t := 1.0                    # 0 = เพิ่งใช้ · 1 = พร้อมใช้
		if sid != &"":
			var left: float = PlayerState.skill_cooldown_left(sid)
			if left > 0.0:
				var sk := GameData.get_skill(sid)
				var total: float = maxf(0.0, float(sk.cooldown)) if sk != null else 0.0
				t = clampf(1.0 - left / total, 0.0, 1.0) if total > 0.0 else 0.0
		var g: float = lerpf(CD_GRAY, 1.0, t)
		art.modulate = Color(g, g, g)
		if veil != null:
			veil.set_progress(1.0 - t)


static func _pad_style(pressed: bool) -> StyleBoxFlat:
	# ★ รอบ 47 — ใส่ alpha ที่ "สีของแผ่นปุ่ม" เอง ไม่ใช่ modulate ของทั้งปุ่ม ★
	# เดิมตั้ง node.modulate.a = 0.55 ซึ่งจางลงไปถึงไอคอนข้างในด้วย ไอคอนสกิลจึงดูซีดเป็นสีเทา
	var st := StyleBoxFlat.new()
	var a: float = PLATE_ALPHA_HOLD if pressed else PLATE_ALPHA
	var bg := Color("#4a5c86") if pressed else Color("#1b2333")
	var line: Color = UITheme.ACCENT if pressed else Color("#8ea0c4")
	bg.a = a
	line.a = minf(1.0, a + 0.3)
	st.bg_color = bg
	st.border_color = line
	st.set_border_width_all(3)
	st.set_corner_radius_all(999)   # กลม
	return st


# =========================================================
# วางตำแหน่งปุ่ม
# =========================================================
func _layout() -> void:
	var vp := get_viewport_rect().size
	var bottom := vp.y - EDGE_BOTTOM

	# ---------- ฝั่งซ้าย: เดิน ----------
	_set_rect("left",  Vector2(EDGE, bottom - PAD_BIG))
	_set_rect("right", Vector2(EDGE + PAD_BIG + GAP, bottom - PAD_BIG))
	_set_rect("down",  Vector2(EDGE + (PAD_BIG * 2.0 + GAP - PAD_MID) * 0.5,
		bottom - PAD_BIG - GAP - PAD_MID))

	# ---------- ฝั่งขวา: ปุ่มโจมตีใหญ่ตรงกลาง + สกิลล้อมรอบ 8 → 1 นาฬิกา ----------
	# วงสกิลกินพื้นที่ล่างซ้ายของปุ่มโจมตีด้วย (8 นาฬิกา) → ยกปุ่มโจมตีขึ้นให้วงไม่ตกขอบจอ
	# รัศมีวง = ครึ่งปุ่มโจมตี + ช่องว่าง + ครึ่งปุ่มสกิล (+16 กันกรอบสี่เหลี่ยมของปุ่มข้างกันเกยกัน)
	var ring_r: float = PAD_ATTACK * 0.5 + GAP + PAD_SMALL * 0.5 + 16.0
	var lowest_extra: float = maxf(0.0, ring_r * -cos(deg_to_rad(SKILL_CLOCK_START * 30.0)) + PAD_SMALL * 0.5 - PAD_ATTACK * 0.5)
	var center := Vector2(vp.x - EDGE - PAD_SMALL - GAP * 0.5 - PAD_ATTACK * 0.5,
		bottom - lowest_extra - PAD_ATTACK * 0.5)
	_set_rect("attack", center - Vector2.ONE * PAD_ATTACK * 0.5)
	var ids := ["skill_1", "skill_2", "skill_3", "skill_4"]
	var n := ids.size()
	for i in range(n):
		var t: float = float(i) / float(maxi(1, n - 1))
		var clock: float = SKILL_CLOCK_START + (SKILL_CLOCK_END - SKILL_CLOCK_START) * t
		var ang: float = deg_to_rad(clock * 30.0)          # 12 นาฬิกา = 0° · ตามเข็ม
		var dir := Vector2(sin(ang), -cos(ang))
		_set_rect(ids[i], center + dir * ring_r - Vector2.ONE * PAD_SMALL * 0.5)

	# ---------- คุย/เก็บของ: ซ้ายของวงสกิล ----------
	var ring_left: float = minf(center.x - PAD_ATTACK * 0.5,
		center.x + ring_r * sin(deg_to_rad(SKILL_CLOCK_START * 30.0)) - PAD_SMALL * 0.5)
	var ix: float = ring_left - GAP - PAD_MID
	_set_rect("interact", Vector2(ix, bottom - PAD_MID))

	# ---------- ยา / มานา / พุ่งหลบ: แถวเหนือปุ่มคุย (รอบ 47 — ใหญ่เท่าปุ่มคุย) ----------
	# ไล่จากขวาไปซ้าย: พุ่งหลบอยู่ขวาสุด (ชิดวงสกิล) → มานา → ยา
	var row3: float = bottom - PAD_MID - GAP - PAD_MID
	var tx: float = ix
	for id in ["dash", "sp", "potion"]:
		_set_rect(id, Vector2(tx, row3))
		tx -= GAP + PAD_MID


func _set_rect(id: String, pos: Vector2) -> void:
	for z in _zones:
		if z.id != id:
			continue
		var s: float = float(z.size)
		z["rect"] = Rect2(pos, Vector2(s, s))
		var node: Control = z.node
		node.position = pos
		node.size = Vector2(s, s)
		return


# =========================================================
# เปิด / ปิด
# =========================================================
func set_mode(new_mode: Mode) -> void:
	mode = new_mode
	_save_mode()
	_refresh_visible()


func mode_text() -> String:
	match mode:
		Mode.ON: return "เปิดตลอด"
		Mode.OFF: return "ปิด"
	return "อัตโนมัติ"


## เครื่องนี้ควรมีปุ่มจอสัมผัสไหม
func should_show() -> bool:
	match mode:
		Mode.ON: return true
		Mode.OFF: return false
	if DisplayServer.is_touchscreen_available():
		return true
	return _shown   # เคยมีการแตะจอมาแล้ว


func _refresh_visible() -> void:
	var want: bool = should_show()
	# ระหว่างเปิดหน้าต่าง/คุยกับ NPC/ตายอยู่ ให้ซ่อนไว้ก่อน จะได้ไม่บังปุ่มในกล่อง
	if want and (UI.is_any_window_open() or UI.is_asking()):
		want = false
	# แถบคำใบ้ปุ่มคีย์บอร์ดล่างจอไม่มีประโยชน์บนมือถือ แถมทับปุ่ม — ซ่อนไว้
	if UI.hud != null and UI.hud.bottom_panel != null:
		var dlg_open: bool = UI.dialogue != null and UI.dialogue.is_open()
		UI.hud.bottom_panel.visible = not want and not dlg_open

	if want == visible:
		return
	visible = want
	if not want:
		_release_all()
	else:
		_layout()


func _process(_delta: float) -> void:
	_refresh_visible()
	if visible:
		_tick_cooldowns()


# =========================================================
# อ่านการแตะจอ (แยกตามนิ้ว = กดพร้อมกันหลายปุ่มได้)
# =========================================================
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		# แตะจอครั้งแรก = เครื่องนี้มีจอสัมผัสจริง โผล่ปุ่มให้เลย (โหมดอัตโนมัติ)
		if not _shown and mode == Mode.AUTO:
			_shown = true
			_refresh_visible()
		if not visible:
			return
		if t.pressed:
			_press_at(t.index, t.position)
		else:
			_release_finger(t.index)
	elif event is InputEventScreenDrag and visible:
		var d := event as InputEventScreenDrag
		# ลากนิ้วจากปุ่มหนึ่งไปอีกปุ่ม (เช่นสไลด์ซ้าย->ขวา) ให้เปลี่ยนปุ่มตาม
		var now := _zone_at(d.position)
		var was: String = String(_fingers.get(d.index, ""))
		var now_id: String = String(now.id) if not now.is_empty() else ""
		if now_id != was:
			_release_finger(d.index)
			if now_id != "":
				_press_at(d.index, d.position)


func _press_at(index: int, pos: Vector2) -> void:
	var z := _zone_at(pos)
	if z.is_empty():
		return
	_fingers[index] = z.id
	_set_pressed(z, true)
	var action := String(z.get("action", ""))
	if action != "" and InputMap.has_action(action):
		# ส่งทั้ง 2 แบบ: action_press (โค้ดที่เช็คแบบ polling)
		# + InputEventAction (โค้ดที่เช็คใน _input/_unhandled_input เช่น NPC กด F)
		Input.action_press(action)
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = true
		Input.parse_input_event(ev)


func _release_finger(index: int) -> void:
	if not _fingers.has(index):
		return
	var id: String = String(_fingers[index])
	_fingers.erase(index)
	for z in _zones:
		if z.id != id:
			continue
		_set_pressed(z, false)
		var action := String(z.get("action", ""))
		if action != "" and InputMap.has_action(action):
			Input.action_release(action)
			var ev := InputEventAction.new()
			ev.action = action
			ev.pressed = false
			Input.parse_input_event(ev)
		if z.has("tap"):
			(z.tap as Callable).call()
		return


func _release_all() -> void:
	for index in _fingers.keys().duplicate():
		_release_finger(index)


func _set_pressed(z: Dictionary, on: bool) -> void:
	var node: Control = z.node
	node.add_theme_stylebox_override("panel", _pad_style(on))


## ปุ่มไหนอยู่ตรงจุดนี้ (เผื่อระยะนิ้วอ้วนไว้นิดหน่อย)
func _zone_at(pos: Vector2) -> Dictionary:
	for z in _zones:
		if not z.has("rect"):
			continue
		if (z.rect as Rect2).grow(6.0).has_point(pos):
			return z
	return {}


## จุดนี้ทับปุ่มจอสัมผัสไหม (UI.is_point_over_ui เรียกใช้ กันคลิกทะลุไปตีมอน)
func is_over(point: Vector2) -> bool:
	if not visible:
		return false
	return not _zone_at(point).is_empty()


# =========================================================
# จำค่าที่เลือกไว้
# =========================================================
func _save_mode() -> void:
	var cfg := ConfigFile.new()
	cfg.load(LAYOUT_PATH)
	cfg.set_value("touch", "mode", int(mode))
	cfg.save(LAYOUT_PATH)


func _load_mode() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(LAYOUT_PATH) != OK:
		return
	var v = cfg.get_value("touch", "mode", int(Mode.AUTO))
	if typeof(v) == TYPE_INT and v >= 0 and v <= 2:
		mode = v as Mode


# =========================================================
# ลูกศรบนปุ่มเดิน (วาดเอง — ฟอนต์ไทยไม่มี glyph ลูกศร)
# =========================================================
class _Arrow extends Control:
	var dir := "left"

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r: float = minf(size.x, size.y) * 0.26
		var pts := PackedVector2Array()
		match dir:
			"left":
				pts = PackedVector2Array([c + Vector2(r, -r), c + Vector2(r, r), c + Vector2(-r, 0)])
			"right":
				pts = PackedVector2Array([c + Vector2(-r, -r), c + Vector2(-r, r), c + Vector2(r, 0)])
			"down":
				pts = PackedVector2Array([c + Vector2(-r, -r * 0.6), c + Vector2(r, -r * 0.6),
					c + Vector2(0, r * 0.8)])
			_:
				pts = PackedVector2Array([c + Vector2(-r, r * 0.6), c + Vector2(r, r * 0.6),
					c + Vector2(0, -r * 0.8)])
		draw_colored_polygon(pts, Color(1, 1, 1, 0.92))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()


# =========================================================
# ★ รอบ 47 — ม่านคูลดาวน์บนปุ่มสกิล ★
# วาดเป็น "พัด" สีเข้มทับไอคอน กินพื้นที่เท่าสัดส่วนคูลดาวน์ที่เหลือ
# เริ่มจากบน (12 นาฬิกา) กวาดตามเข็ม แล้วหุบหายไปตอนพร้อมใช้
# =========================================================
class _CooldownVeil extends Control:
	var progress := 0.0      # 1 = เพิ่งใช้ (บังทั้งวง) · 0 = พร้อมใช้ (ไม่บังเลย)

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_progress(v: float) -> void:
		var nv: float = clampf(v, 0.0, 1.0)
		if absf(nv - progress) < 0.004:
			return
		progress = nv
		visible = progress > 0.0
		queue_redraw()

	func _draw() -> void:
		if progress <= 0.0:
			return
		var c := size * 0.5
		var r: float = minf(size.x, size.y) * 0.5 - 3.0
		var steps: int = maxi(3, int(ceilf(progress * 48.0)))
		var pts := PackedVector2Array([c])
		for i in range(steps + 1):
			var ang: float = deg_to_rad(-90.0 + 360.0 * progress * (float(i) / float(steps)))
			pts.append(c + Vector2(cos(ang), sin(ang)) * r)
		draw_colored_polygon(pts, Color(0.03, 0.05, 0.09, 0.62))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()
