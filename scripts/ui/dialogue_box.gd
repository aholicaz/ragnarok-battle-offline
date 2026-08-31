## DialogueBox — กล่องสนทนาแบบเกม RPG (รูปตัวละครยืนข้างกล่องข้อความ)
##
## ★ ใช้ยังไง ★
##   var pick: int = await UI.talk([
##       {"name": "ช่างตีเหล็กฮันส์", "portrait": tex, "side": 0, "text": "ว่าไงเจ้าหนู"},
##       {"name": "คุณ",             "side": 1,       "text": "มีงานให้ทำมั้ย"},
##       {"info": "เงื่อนไข: ล่าโพริง 10 ตัว", "choices": ["รับเควส", "ไว้ก่อน"]},
##   ])
##   pick = ลำดับตัวเลือกที่กด (0 = อันแรก) · -1 = ไม่มีตัวเลือกในบทนี้ · ยกเลิก = อันสุดท้าย
##
## ★ คีย์ของบทสนทนา 1 บรรทัด ★
##   name     ชื่อผู้พูด (ขึ้นบนกล่อง)
##   text     ข้อความ (ขึ้นทีละตัวอักษร กด F/Enter/คลิก = ขึ้นครบทันที แล้วกดอีกทีไปบรรทัดถัดไป)
##   portrait รูปตัวละคร — ใส่ Texture2D หรือ path "res://..." ก็ได้ (ไม่ใส่ = ใช้รูปเดิมของฝั่งนั้น)
##   side     0 = รูปอยู่ซ้าย · 1 = รูปอยู่ขวา  (ฝั่งที่ไม่ได้พูดจะหรี่ลง)
##   info     ข้อความเสริมตัวเล็ก (เงื่อนไข/รางวัล) ขึ้นใต้ข้อความหลัก
##   choices  รายชื่อปุ่มตัวเลือก — มีเมื่อไหร่จะรอให้ผู้เล่นเลือกก่อนถึงไปต่อ
##
## รูปตัวละคร: ตัดครึ่งท่อนบน (หัวถึงเอว) พื้นหลังโปร่งใส สูงประมาณ 400-500 px
class_name DialogueBox
extends Control

signal finished(choice: int)

## ความสูงกล่องข้อความ (เฉพาะส่วนข้อความ — มีข้อความเสริม/ปุ่มตัวเลือกจะสูงขึ้นเอง)
const BOX_HEIGHT := 156.0
## ความสูงที่เพิ่มให้แถวข้อความเสริม / แถวปุ่มตัวเลือก
const INFO_H := 58.0
const CHOICE_H := 52.0
const BOX_MARGIN := 28.0
## ความสูงรูปตัวละครบนจอ
const PORTRAIT_HEIGHT := 330.0
## รูปกินพื้นที่ด้านข้างเท่าไหร่ (กล่องข้อความจะหลบให้)
const PORTRAIT_SLOT := 300.0
## ตัวอักษรโผล่กี่ตัวต่อวินาที
const TEXT_SPEED := 55.0

# ★★ สีและขนาดตัวอักษรของกล่อง ★★ (กล่องพื้นขาว ตัวหนังสือเข้ม อ่านง่ายกว่าพื้นเข้ม)
const BOX_BG := Color("#f6f3ebfa")        # พื้นกล่อง — ขาวนวล
const BOX_EDGE := Color("#2b3346")        # เส้นขอบบาง ๆ
const NAME_BG := Color("#232c42fa")       # ป้ายชื่อ — เข้ม ตัดกับกล่องขาว
const TEXT_DARK := Color("#1c2231")       # ตัวหนังสือหลัก
const INFO_DARK := Color("#8a5a12")       # ข้อความเสริม (เงื่อนไข/รางวัล)
const HINT_DARK := Color("#8b8f9b")       # คำใบ้มุมล่าง
const LINE_SOFT := Color("#d6d0c2")       # เส้นคั่นในกล่อง
## ขนาดตัวอักษร
const FONT_TEXT := 22
const FONT_NAME := 19
const FONT_INFO := 15
const FONT_HINT := 13
## ระยะขอบในกล่อง
const PAD_X := 22.0
const PAD_TOP := 16.0
const PAD_BOTTOM := 12.0

var _dim: ColorRect
var _panel: PanelContainer
var _name_panel: PanelContainer
var _name_label: Label
var _text: RichTextLabel
var _info: Label
var _hint: Label
var _choice_row: HBoxContainer
var _info_line: ColorRect
var _portraits: Array[TextureRect] = []      # 0 = ซ้าย · 1 = ขวา

var _script: Array = []
var _index := 0
var _open := false
var _revealing := false
var _reveal := 0.0
var _full_text := ""
var _last_choice := -1
var _waiting_choice := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	z_index = 210
	# ★ ต้อง _and_offsets_ ★ ไม่งั้นกรอบยังกว้าง 0 ของข้างในจะไปกองมุมซ้ายบน
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0, 0, 0, 0.42)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	# ---------- รูปตัวละคร 2 ฝั่ง ----------
	for i in range(2):
		var art := TextureRect.new()
		art.name = "PortraitLeft" if i == 0 else "PortraitRight"
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.visible = false
		add_child(art)
		_portraits.append(art)

	# ---------- กล่องข้อความ (พื้นขาว ขอบบาง) ----------
	_panel = PanelContainer.new()
	_panel.name = "Box"
	_panel.add_theme_stylebox_override("panel", _box_style())
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	# เว้นขอบในกล่องให้ข้อความไม่ชิดเส้น
	var pad := MarginContainer.new()
	pad.name = "Pad"
	pad.add_theme_constant_override("margin_left", int(PAD_X))
	pad.add_theme_constant_override("margin_right", int(PAD_X))
	pad.add_theme_constant_override("margin_top", int(PAD_TOP))
	pad.add_theme_constant_override("margin_bottom", int(PAD_BOTTOM))
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(pad)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(box)

	_text = RichTextLabel.new()
	_text.name = "Text"
	_text.bbcode_enabled = true
	_text.fit_content = false
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", FONT_TEXT)
	_text.add_theme_font_size_override("bold_font_size", FONT_TEXT)
	_text.add_theme_constant_override("line_separation", 6)
	_text.add_theme_color_override("default_color", TEXT_DARK)
	box.add_child(_text)

	# เส้นคั่นบาง ๆ เหนือข้อความเสริม
	_info_line = ColorRect.new()
	_info_line.name = "InfoLine"
	_info_line.color = LINE_SOFT
	_info_line.custom_minimum_size.y = 1.0
	_info_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_line.visible = false
	box.add_child(_info_line)

	_info = UITheme.make_label("", FONT_INFO, INFO_DARK)
	_info.name = "Info"
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.visible = false
	box.add_child(_info)

	_choice_row = HBoxContainer.new()
	_choice_row.name = "Choices"
	_choice_row.alignment = BoxContainer.ALIGNMENT_END
	_choice_row.add_theme_constant_override("separation", 10)
	_choice_row.visible = false
	box.add_child(_choice_row)

	_hint = UITheme.make_label("[F] คุยต่อ", FONT_HINT, HINT_DARK)
	_hint.name = "Hint"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_hint)

	# ---------- ป้ายชื่อผู้พูด (วางเหนือกล่อง ไม่ทับข้อความ) ----------
	_name_panel = PanelContainer.new()
	_name_panel.name = "NamePlate"
	_name_panel.add_theme_stylebox_override("panel", _name_style())
	_name_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_panel)

	_name_label = UITheme.make_label("", FONT_NAME, UITheme.ACCENT)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_panel.add_child(_name_label)

	# ★ ให้รูปตัวละครวาดทีหลังกล่อง ★ ตัวละครจะได้ยืน "หน้า" กล่อง ไม่โดนกล่องทับ
	for art in _portraits:
		move_child(art, get_child_count() - 1)

	gui_input.connect(_on_click)
	_panel.gui_input.connect(_on_click)
	get_viewport().size_changed.connect(_layout)


## กล่องพื้นขาว มุมมน ขอบบาง (ไม่ใช้ขอบทองแล้ว)
static func _box_style() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = BOX_BG
	st.border_color = BOX_EDGE
	st.set_border_width_all(2)
	st.set_corner_radius_all(14)
	st.set_content_margin_all(0)
	st.shadow_color = Color(0, 0, 0, 0.45)
	st.shadow_size = 8
	st.shadow_offset = Vector2(0, 3)
	return st


## ป้ายชื่อ — พื้นเข้ม ตัวหนังสือทอง ตัดกับกล่องขาว
static func _name_style() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = NAME_BG
	st.border_color = UITheme.ACCENT
	st.set_border_width_all(2)
	st.set_corner_radius_all(9)
	st.content_margin_left = 16
	st.content_margin_right = 16
	st.content_margin_top = 5
	st.content_margin_bottom = 5
	return st


func is_open() -> bool:
	return _open


# =========================================================
# เริ่มบทสนทนา
# =========================================================
func play(script: Array) -> int:
	if script.is_empty():
		return -1
	_script = script
	_index = 0
	_last_choice = -1
	_open = true
	visible = true
	move_to_front()
	for art in _portraits:
		art.texture = null
		art.visible = false
	_hud_hint(false)
	_layout()
	_show_line()
	return await finished


func close() -> void:
	_open = false
	visible = false
	_revealing = false
	_waiting_choice = false
	_hud_hint(true)


## แถบคำใบ้ปุ่มล่างจอบังกล่องสนทนา — ซ่อนไว้ระหว่างคุย
func _hud_hint(on: bool) -> void:
	if UI.hud != null and UI.hud.bottom_panel != null:
		UI.hud.bottom_panel.visible = on


# =========================================================
# จัดตำแหน่ง — กล่องอยู่ล่างจอ รูปตัวละครยืนข้าง ๆ
# =========================================================
func _layout() -> void:
	var vp := get_viewport_rect().size
	var left_on: bool = _portraits[0].visible
	var right_on: bool = _portraits[1].visible

	# ★ กล่องทึบแล้ว ห้ามทับรูป ★ ไม่งั้นตัวละครโดนกล่องบังครึ่งตัว
	var box_left: float = BOX_MARGIN + (PORTRAIT_SLOT if left_on else 0.0)
	var box_right: float = vp.x - BOX_MARGIN - (PORTRAIT_SLOT if right_on else 0.0)

	# ★ กล่องสูงขึ้นตามของที่มีจริง ★ แล้วยึด "ขอบล่าง" ไว้เท่าเดิม
	# (ถ้าตั้งความสูงตายตัว พอมีปุ่มตัวเลือกกล่องจะงอกลงไปนอกจอ)
	var box_h: float = BOX_HEIGHT
	if _info.visible:
		box_h += INFO_H
	if _choice_row.visible:
		box_h += CHOICE_H
	box_h = minf(box_h, vp.y * 0.62)
	var box_top: float = vp.y - BOX_MARGIN - box_h

	var box_w: float = maxf(240.0, box_right - box_left)
	# ★ ต้องบอกความกว้างให้ป้ายที่ตัดบรรทัดเองก่อน ★
	# ไม่งั้นตอนคำนวณขนาดขั้นต่ำมันเห็นความกว้าง 0 แล้วตัดทีละตัวอักษร
	# ความสูงขั้นต่ำจะพุ่งไปเป็นพันพิกเซล ดันกล่องยาวทะลุจอ
	_info.custom_minimum_size.x = box_w - 44.0
	_text.custom_minimum_size.x = box_w - 44.0

	_panel.position = Vector2(box_left, box_top)
	_panel.size = Vector2(box_w, box_h)

	# ป้ายชื่ออยู่มุมบนซ้ายของกล่อง (ถ้าคนพูดอยู่ฝั่งขวา ย้ายไปมุมขวา)
	_name_panel.reset_size()
	var name_x: float = box_left + 16.0
	if _portraits[1].modulate.a > 0.9 and right_on:
		name_x = _panel.position.x + _panel.size.x - _name_panel.size.x - 16.0
	# ★ วางไว้ "เหนือกล่อง" ทั้งป้าย ★ ไม่ให้ทับบรรทัดแรกของข้อความ
	_name_panel.position = Vector2(name_x, box_top - _name_panel.size.y - 4.0)

	# รูปตัวละคร: ยืนติดขอบล่างจอ ล้ำขึ้นไปเหนือกล่องข้อความ
	for i in range(2):
		var art := _portraits[i]
		if art.texture == null:
			continue
		var tex_size := art.texture.get_size()
		var w: float = PORTRAIT_HEIGHT * (tex_size.x / maxf(1.0, tex_size.y))
		art.size = Vector2(w, PORTRAIT_HEIGHT)
		var x: float = BOX_MARGIN - 10.0 if i == 0 else vp.x - BOX_MARGIN - w + 10.0
		art.position = Vector2(x, vp.y - PORTRAIT_HEIGHT - 4.0)


# =========================================================
# แสดงบรรทัดปัจจุบัน
# =========================================================
func _show_line() -> void:
	if _index >= _script.size():
		close()
		finished.emit(_last_choice)
		return

	var line: Dictionary = _script[_index]
	var side: int = clampi(int(line.get("side", 0)), 0, 1)

	# ---------- รูปตัวละคร ----------
	if line.has("portrait"):
		var tex := _to_texture(line.portrait)
		_portraits[side].texture = tex
		_portraits[side].visible = tex != null
	# ฝั่งที่กำลังพูดสว่าง ฝั่งที่ฟังอยู่หรี่ลง
	for i in range(2):
		_portraits[i].modulate = Color.WHITE if i == side else Color(0.45, 0.48, 0.58)

	# ---------- ชื่อผู้พูด ----------
	var speaker := String(line.get("name", ""))
	_name_panel.visible = speaker != ""
	_name_label.text = speaker

	# ---------- ข้อความ (ขึ้นทีละตัว) ----------
	_full_text = String(line.get("text", ""))
	_text.text = _full_text
	_text.visible_characters = 0
	_reveal = 0.0
	_revealing = _full_text != ""

	# ---------- ข้อความเสริม ----------
	var info := String(line.get("info", ""))
	_info.text = info
	_info.visible = info != ""
	_info_line.visible = info != ""

	# ---------- ตัวเลือก ----------
	_clear_choices()
	var choices: Array = line.get("choices", [])
	_waiting_choice = not choices.is_empty()
	_choice_row.visible = _waiting_choice
	if _waiting_choice:
		for i in range(choices.size()):
			var index := i
			var btn := UITheme.make_button(String(choices[i]), 150)
			btn.focus_mode = Control.FOCUS_NONE
			btn.custom_minimum_size.y = 38.0
			btn.add_theme_font_size_override("font_size", 16)
			btn.pressed.connect(func(): _pick(index))
			_choice_row.add_child(btn)
	_hint.text = "เลือกด้วยเมาส์  ·  Esc = ยกเลิก" if _waiting_choice else "[F] คุยต่อ"

	_layout()
	_settle()


## ขนาดขั้นต่ำของป้ายจะนิ่งหลังผ่านไป 1 เฟรม — จัดกล่องอีกรอบให้พอดีจริง ๆ
func _settle() -> void:
	await get_tree().process_frame
	if _open:
		_layout()


func _to_texture(value: Variant) -> Texture2D:
	if value is Texture2D:
		return value
	if value is String and String(value) != "":
		var path := String(value)
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null


func _clear_choices() -> void:
	for c in _choice_row.get_children():
		_choice_row.remove_child(c)
		c.queue_free()


func _pick(index: int) -> void:
	if not _waiting_choice:
		return
	_last_choice = index
	_waiting_choice = false
	_next()


# =========================================================
# เดินเรื่อง
# =========================================================
func _process(delta: float) -> void:
	if not _open or not _revealing:
		return
	_reveal += delta * TEXT_SPEED
	_text.visible_characters = int(_reveal)
	if _text.visible_characters >= _full_text.length():
		_revealing = false
		_text.visible_characters = -1


## กด/คลิก 1 ครั้ง: ข้อความยังขึ้นไม่ครบ = ขึ้นให้ครบ · ครบแล้ว = ไปบรรทัดถัดไป
func _advance() -> void:
	if _revealing:
		_revealing = false
		_text.visible_characters = -1
		return
	if _waiting_choice:
		return
	_next()


func _next() -> void:
	_index += 1
	_show_line()


func _on_click(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_advance()
		accept_event()


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("close_windows"):
		# ยกเลิก = เลือกตัวเลือกสุดท้าย (ปกติคือ "ไว้ก่อน") ถ้าไม่มีตัวเลือกก็ปิดไปเลย
		if _waiting_choice:
			_pick(maxi(0, _choice_row.get_child_count() - 1))
		else:
			_index = _script.size()
			_show_line()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_advance()
		get_viewport().set_input_as_handled()
