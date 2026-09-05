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
##   voice    ★ รอบ 59 ★ เสียงพากย์ของบรรทัดนี้ — "hans/greeting" หรือ path เต็ม (ขึ้นบรรทัด = เล่น · ปิดกล่อง = หยุด)
##
## รูปตัวละคร: ตัดครึ่งท่อนบน (หัวถึงเอว) พื้นหลังโปร่งใส สูงประมาณ 400-500 px
##
## ★ รอบ 62 — หน้าตาใหม่แบบ RPG ยุคใหม่ ★
##   ไม่มีกล่องขาวแล้ว → "แถบมืดโปร่งแสง" พาดล่างจอ ขอบบนมีเส้นแสงฟ้าบาง ๆ · ตัวหนังสือขาวมีเงา
##   ป้ายชื่อเป็นแถบสีฟ้าโปร่งจางไปทางขวา · รูปตัวละครใหญ่ยืนล้ำแถบ ปลายล่างจางหายเนียน ๆ
##   มุมขวาล่างมีลูกศร ▼ กระดึ๊บบอกว่ากดต่อได้
class_name DialogueBox
extends Control

signal finished(choice: int)

## ความสูงแถบข้อความ (เฉพาะส่วนข้อความ — มีข้อความเสริม/ปุ่มตัวเลือกจะสูงขึ้นเอง)
const BOX_HEIGHT := 150.0
## ความสูงที่เพิ่มให้แถวข้อความเสริม / แถวปุ่มตัวเลือก
const INFO_H := 58.0
const CHOICE_H := 52.0
## ระยะจากขอบจอซ้าย-ขวาของ "ข้อความ" · ระยะจากขอบล่างของแถบ
const BOX_MARGIN := 28.0
const BOX_BOTTOM := 14.0
## ความสูงรูปตัวละคร = สัดส่วนของจอ (ขั้นต่ำ PORTRAIT_MIN) — ใหญ่กว่าเดิมให้เห็นหน้าชัด
const PORTRAIT_RATIO := 0.60
const PORTRAIT_MIN := 330.0
## รูปกินพื้นที่ด้านข้างเท่าไหร่ (ข้อความจะเริ่มถัดจากตรงนี้ · รูปทับแถบได้ ไม่ต้องหลบ)
const PORTRAIT_SLOT := 300.0
## ปลายล่างของรูปเริ่มจางที่กี่ % ของความสูงรูป (0.72 = จาง 28% ล่างสุด)
const PORTRAIT_FADE := 0.58
## ตัวอักษรโผล่กี่ตัวต่อวินาที
const TEXT_SPEED := 55.0

# ★★ สีของแถบ ★★
const BAND_COLOR := Color(0.02, 0.03, 0.06, 0.62)   # แถบมืดโปร่งแสง
const LINE_GLOW := Color("#9fc8ff")                # เส้นแสงขอบบนแถบ
const NAME_BG := Color("#4a6fa8")                  # แถบป้ายชื่อ (ฟ้าโปร่ง จางไปทางขวา)
const TEXT_LIGHT := Color("#f4f6fb")               # ตัวหนังสือหลัก (ขาว)
const INFO_LIGHT := Color("#ffd98a")               # ข้อความเสริม (เงื่อนไข/รางวัล) ทองอ่อน
const HINT_LIGHT := Color("#aab6cc")               # คำใบ้
const DIM_ALPHA := 0.30                            # ฉากมืดลงเท่าไหร่ตอนคุย (0 = ไม่มืด)
## ขนาดตัวอักษร
const FONT_TEXT := 26
const FONT_NAME := 19
const FONT_INFO := 19
const FONT_HINT := 15
## ระยะขอบในแถบ
const PAD_X := 22.0
const PAD_TOP := 14.0
const PAD_BOTTOM := 12.0
## ป้ายชื่อสูงเท่าไหร่ · ข้อความเริ่มถัดจากป้ายเท่าไหร่
const NAME_H := 32.0
const NAME_GAP := 8.0

## เชดเดอร์ให้ปลายล่างรูปตัวละครจางหาย (ใช้กับ TextureRect ของรูป)
const PORTRAIT_SHADER := """
shader_type canvas_item;
uniform float fade_start : hint_range(0.0, 1.0) = 0.72;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	c.a *= 1.0 - smoothstep(fade_start, 0.97, UV.y);
	COLOR = c;
}
"""

var _dim: ColorRect
var _band_bg: TextureRect          # แถบมืดพาดล่างจอ (ไล่จางซ้าย-ขวา)
var _band_line: TextureRect        # เส้นแสงขอบบนแถบ
var _panel: PanelContainer         # พื้นที่ข้อความ (โปร่ง — ใช้จัดตำแหน่งเนื้อหา)
var _pad: MarginContainer
var _name_panel: Control           # ป้ายชื่อ (แถบฟ้าจาง + ตัวหนังสือ)
var _name_bg: TextureRect
var _name_label: Label
var _arrow: Label                  # ▼ มุมขวาล่าง กระดึ๊บบอกว่ากดต่อได้
var _arrow_tween: Tween
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
	_dim.color = Color(0, 0, 0, DIM_ALPHA)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	# ---------- แถบมืดพาดล่างจอ + เส้นแสงขอบบน ----------
	_band_bg = TextureRect.new()
	_band_bg.name = "Band"
	_band_bg.texture = _h_gradient([
		[0.0, Color(BAND_COLOR, 0.0)], [0.05, BAND_COLOR], [0.88, BAND_COLOR], [1.0, Color(BAND_COLOR, 0.0)]])
	_band_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_band_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_band_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_band_bg)

	_band_line = TextureRect.new()
	_band_line.name = "BandLine"
	_band_line.texture = _h_gradient([
		[0.0, Color(LINE_GLOW, 0.0)], [0.12, Color(LINE_GLOW, 0.9)], [0.7, Color(LINE_GLOW, 0.9)], [1.0, Color(LINE_GLOW, 0.0)]])
	_band_line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_band_line.stretch_mode = TextureRect.STRETCH_SCALE
	_band_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_band_line)

	# ---------- รูปตัวละคร 2 ฝั่ง (ปลายล่างจางหาย) ----------
	for i in range(2):
		var art := TextureRect.new()
		art.name = "PortraitLeft" if i == 0 else "PortraitRight"
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.visible = false
		var sh := Shader.new()
		sh.code = PORTRAIT_SHADER
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("fade_start", PORTRAIT_FADE)
		art.material = mat
		add_child(art)
		_portraits.append(art)

	# ---------- พื้นที่ข้อความ (โปร่ง — แถบมืดอยู่ข้างหลังแล้ว) ----------
	_panel = PanelContainer.new()
	_panel.name = "Box"
	_panel.add_theme_stylebox_override("panel", _box_style())
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	# เว้นขอบให้ข้อความไม่ชิดเส้น (ขอบบนเผื่อที่ให้ป้ายชื่อ — ปรับใน _layout)
	_pad = MarginContainer.new()
	_pad.name = "Pad"
	_pad.add_theme_constant_override("margin_left", int(PAD_X))
	_pad.add_theme_constant_override("margin_right", int(PAD_X))
	_pad.add_theme_constant_override("margin_top", int(PAD_TOP))
	_pad.add_theme_constant_override("margin_bottom", int(PAD_BOTTOM))
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_pad)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.add_child(box)

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
	_text.add_theme_color_override("default_color", TEXT_LIGHT)
	# เงาตัวหนังสือ ให้อ่านออกแม้ฉากหลังสว่าง
	_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_text.add_theme_constant_override("shadow_offset_x", 1)
	_text.add_theme_constant_override("shadow_offset_y", 2)
	_text.add_theme_constant_override("shadow_outline_size", 2)
	box.add_child(_text)

	# เส้นคั่นบาง ๆ เหนือข้อความเสริม
	_info_line = ColorRect.new()
	_info_line.name = "InfoLine"
	_info_line.color = Color(LINE_GLOW, 0.35)
	_info_line.custom_minimum_size.y = 1.0
	_info_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_line.visible = false
	box.add_child(_info_line)

	_info = UITheme.make_label("", FONT_INFO, INFO_LIGHT)
	_info.name = "Info"
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_info.add_theme_constant_override("shadow_offset_y", 1)
	_info.visible = false
	box.add_child(_info)

	_choice_row = HBoxContainer.new()
	_choice_row.name = "Choices"
	_choice_row.alignment = BoxContainer.ALIGNMENT_END
	_choice_row.add_theme_constant_override("separation", 10)
	_choice_row.visible = false
	box.add_child(_choice_row)

	_hint = UITheme.make_label("", FONT_HINT, HINT_LIGHT)
	_hint.name = "Hint"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_hint)

	# ---------- ป้ายชื่อผู้พูด (แถบฟ้าโปร่งจางไปทางขวา วางบนแถบ เหนือข้อความ) ----------
	_name_panel = Control.new()
	_name_panel.name = "NamePlate"
	_name_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_panel)

	_name_bg = TextureRect.new()
	_name_bg.name = "NameBg"
	_name_bg.texture = _h_gradient([
		[0.0, Color(NAME_BG, 0.95)], [0.5, Color(NAME_BG, 0.6)], [1.0, Color(NAME_BG, 0.0)]])
	_name_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_name_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_name_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_panel.add_child(_name_bg)

	_name_label = UITheme.make_label("", FONT_NAME, TEXT_LIGHT)
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_name_label.add_theme_constant_override("shadow_offset_y", 1)
	_name_panel.add_child(_name_label)

	# ---------- ▼ มุมขวาล่าง ----------
	_arrow = Label.new()
	_arrow.name = "Arrow"
	_arrow.text = "▼"
	_arrow.add_theme_font_size_override("font_size", 15)
	_arrow.add_theme_color_override("font_color", LINE_GLOW)
	_arrow.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_arrow.add_theme_constant_override("shadow_offset_y", 1)
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arrow)

	# ★ ให้รูปตัวละครวาดทีหลังแถบ ★ ตัวละครจะได้ยืน "หน้า" แถบ ไม่โดนบัง
	for art in _portraits:
		move_child(art, get_child_count() - 1)

	gui_input.connect(_on_click)
	_panel.gui_input.connect(_on_click)
	get_viewport().size_changed.connect(_layout)


## พื้นที่ข้อความโปร่งใส (แถบมืดอยู่ที่ _band_bg แล้ว)
static func _box_style() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0, 0, 0, 0)
	st.set_border_width_all(0)
	st.set_corner_radius_all(0)
	st.set_content_margin_all(0)
	return st


## เท็กซ์เจอร์ไล่สีแนวนอน — stops = [[ตำแหน่ง 0-1, สี], ...]
static func _h_gradient(stops: Array) -> GradientTexture2D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for st in stops:
		offs.append(float(st[0]))
		cols.append(st[1])
	g.offsets = offs
	g.colors = cols
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 256
	tex.height = 4
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(1, 0)
	return tex


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


## เล่นเสียงพากย์ของบรรทัดนี้ (ไม่มีไฟล์/ไม่มี Game.voice = เงียบ)
func _play_voice(rel: String) -> void:
	var g := get_node_or_null("/root/Game")
	if g == null or not ("voice" in g) or g.voice == null:
		return
	if rel == "":
		g.voice.stop()           # บรรทัดที่ไม่มีเสียง = ตัดเสียงบรรทัดก่อนทิ้ง (ไม่ให้พูดค้าง)
	else:
		g.voice.play_path(rel)


func close() -> void:
	_open = false
	_play_voice("")              # ปิดกล่อง = หยุดพากย์
	visible = false
	_revealing = false
	_waiting_choice = false
	_set_arrow(false)
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

	# รูปตัวละคร: ยืนติดขอบล่างจอ ล้ำขึ้นไปเหนือแถบ (ปลายล่างจางด้วยเชดเดอร์)
	var ph: float = maxf(PORTRAIT_MIN, vp.y * PORTRAIT_RATIO)
	var art_w: Array[float] = [0.0, 0.0]
	for i in range(2):
		var art := _portraits[i]
		if art.texture == null:
			continue
		var tex_size := art.texture.get_size()
		var w: float = ph * (tex_size.x / maxf(1.0, tex_size.y))
		art.size = Vector2(w, ph)
		var x: float = BOX_MARGIN - 20.0 if i == 0 else vp.x - BOX_MARGIN - w + 20.0
		art.position = Vector2(x, vp.y - ph + 2.0)
		art_w[i] = w

	# ข้อความเริ่มถัดจากรูป (รูปกว้างกว่าช่องมาตรฐานก็ขยับตาม — ทับขอบรูปได้นิดหน่อยเพราะขอบโปร่ง)
	var box_left: float = BOX_MARGIN
	if left_on:
		box_left = maxf(BOX_MARGIN + PORTRAIT_SLOT, _portraits[0].position.x + art_w[0] - 8.0)
	var box_right: float = vp.x - BOX_MARGIN
	if right_on:
		box_right = minf(vp.x - BOX_MARGIN - PORTRAIT_SLOT, _portraits[1].position.x + 8.0)

	# ★ แถบสูงขึ้นตามของที่มีจริง ★ แล้วยึด "ขอบล่าง" ไว้เท่าเดิม
	var box_h: float = BOX_HEIGHT
	if _info.visible:
		box_h += INFO_H
	if _choice_row.visible:
		box_h += CHOICE_H
	box_h = minf(box_h, vp.y * 0.62)
	var box_top: float = vp.y - BOX_BOTTOM - box_h

	# แถบมืดพาดเต็มจอ ยาวลงถึงขอบล่าง · เส้นแสงที่ขอบบน
	_band_bg.position = Vector2(0, box_top)
	_band_bg.size = Vector2(vp.x, vp.y - box_top)
	_band_line.position = Vector2(0, box_top)
	_band_line.size = Vector2(vp.x, 2)

	var box_w: float = maxf(240.0, box_right - box_left)
	# ★ ต้องบอกความกว้างให้ป้ายที่ตัดบรรทัดเองก่อน ★ (ไม่งั้นความสูงขั้นต่ำพุ่ง)
	_info.custom_minimum_size.x = box_w - 44.0
	_text.custom_minimum_size.x = box_w - 44.0

	# ป้ายชื่ออยู่ในแถบ เหนือข้อความ → เว้นขอบบนให้ข้อความหลบป้าย
	var has_name: bool = _name_panel.visible
	_pad.add_theme_constant_override("margin_top", int(PAD_TOP + (NAME_H + NAME_GAP if has_name else 0.0)))

	_panel.position = Vector2(box_left, box_top)
	_panel.size = Vector2(box_w, box_h)

	# ป้ายชื่อ: มุมบนซ้ายของพื้นที่ข้อความ (คนพูดอยู่ขวา → ชิดขวา)
	_name_label.reset_size()
	var name_w: float = maxf(140.0, _name_label.size.x * 2.6)
	_name_panel.size = Vector2(name_w, NAME_H)
	_name_bg.position = Vector2.ZERO
	_name_bg.size = _name_panel.size
	_name_label.position = Vector2(14.0, 0.0)
	_name_label.size = Vector2(_name_label.size.x, NAME_H)
	var name_x: float = box_left + PAD_X - 14.0
	if _portraits[1].modulate.a > 0.9 and right_on and not left_on:
		name_x = box_right - name_w
	_name_panel.position = Vector2(name_x, box_top + PAD_TOP - 2.0)

	# ▼ มุมขวาล่างของแถบ
	_arrow.reset_size()
	_arrow.position = Vector2(box_right - _arrow.size.x - 4.0, vp.y - BOX_BOTTOM - _arrow.size.y - 6.0)



## ▼ กระดึ๊บขึ้นลงตอนรอผู้เล่นกดต่อ
func _set_arrow(on: bool) -> void:
	if _arrow_tween != null and _arrow_tween.is_valid():
		_arrow_tween.kill()
	_arrow.visible = on
	if not on:
		return
	_arrow.modulate.a = 1.0
	var base_y: float = _arrow.position.y
	_arrow_tween = create_tween().set_loops()
	_arrow_tween.tween_property(_arrow, "position:y", base_y + 4.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_arrow_tween.tween_property(_arrow, "position:y", base_y, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


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

	# ---------- ★ เสียงพากย์ (รอบ 59) ★ ----------
	_play_voice(String(line.get("voice", "")))

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
	_hint.text = "Esc = ยกเลิก" if _waiting_choice else ""
	_hint.visible = _waiting_choice

	_layout()
	_set_arrow(not _waiting_choice)
	_settle()


## ขนาดขั้นต่ำของป้ายจะนิ่งหลังผ่านไป 1 เฟรม — จัดกล่องอีกรอบให้พอดีจริง ๆ
func _settle() -> void:
	await get_tree().process_frame
	if _open:
		_layout()
		_set_arrow(not _waiting_choice)


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
