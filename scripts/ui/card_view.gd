## CardView — กรอบการ์ดแบบ Ragnarok
##
## ถ้า CardData ใส่ภาพ illustration ไว้ จะโชว์ภาพนั้นเต็มกรอบ
## ถ้ายังไม่มีภาพ ระบบจะวาดกรอบการ์ดให้แล้วเอา "รูปมอนสเตอร์ตัวนั้น" มาใส่ตรงกลางให้อัตโนมัติ
class_name CardView
extends PanelContainer

var _name_label: Label
var _art: TextureRect
var _art_frame: PanelContainer
var _slot_label: Label
var _effect_label: Label
var _rarity_label: Label

var _card: CardData
var _owned := true


func _ready() -> void:
	custom_minimum_size = Vector2(210, 300)
	_build()


func _build() -> void:
	if _name_label != null:
		return

	add_theme_stylebox_override("panel", _frame_style(Color("#9aa7bd")))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	# ---------- ชื่อการ์ด ----------
	_name_label = UITheme.make_label("", 14, UITheme.ACCENT)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_name_label)

	# ---------- ช่องรูปมอนสเตอร์ ----------
	_art_frame = PanelContainer.new()
	_art_frame.custom_minimum_size = Vector2(0, 150)
	_art_frame.add_theme_stylebox_override("panel", _art_style(Color("#9aa7bd")))
	box.add_child(_art_frame)

	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_art_frame.add_child(_art)

	# ---------- ป้ายบอกช่องที่ใส่ได้ ----------
	_slot_label = UITheme.make_label("", 11, UITheme.TEXT_DIM)
	_slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_slot_label)

	box.add_child(UITheme.separator())

	# ---------- คุณสมบัติ ----------
	_effect_label = UITheme.make_label("", 12, UITheme.GOOD)
	_effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_effect_label)

	_rarity_label = UITheme.make_label("", 10, UITheme.TEXT_DIM)
	_rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_rarity_label)


func show_card(card: CardData, owned: bool = true) -> void:
	_build()
	_card = card
	_owned = owned

	if card == null:
		_name_label.text = "— เลือกการ์ด —"
		_art.texture = null
		_slot_label.text = ""
		_effect_label.text = ""
		_rarity_label.text = ""
		add_theme_stylebox_override("panel", _frame_style(Color("#4a5a7a")))
		_art_frame.add_theme_stylebox_override("panel", _art_style(Color("#4a5a7a")))
		return

	var color := card.rarity_color()
	add_theme_stylebox_override("panel", _frame_style(color if owned else Color("#3a4256")))
	_art_frame.add_theme_stylebox_override("panel", _art_style(color if owned else Color("#3a4256")))

	_name_label.text = card.display_name if owned else "? ? ?"
	_name_label.add_theme_color_override("font_color", color if owned else UITheme.TEXT_DIM)

	_art.texture = card_texture(card)
	_art.modulate = Color.WHITE if owned else Color(0.12, 0.13, 0.18)

	if owned:
		var m := card.monster()
		var lv: String = "Lv.%d" % m.level if m != null else ""
		_slot_label.text = "ใส่ใน%s   •   %s" % [card.slot_name(), lv]
		_effect_label.text = card.describe()
		_effect_label.add_theme_color_override("font_color", UITheme.GOOD)
		_rarity_label.text = card.rarity_name()
	else:
		_slot_label.text = "ยังไม่เก็บได้"
		_effect_label.text = "ล่ามอนสเตอร์ตัวนี้เพื่อลุ้นการ์ด"
		_effect_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		_rarity_label.text = ""


## รูปที่จะโชว์บนการ์ด — ใช้ภาพการ์ดก่อน ถ้าไม่มีก็ดึงรูปมอนสเตอร์มาใช้
static func card_texture(card: CardData) -> Texture2D:
	if card == null:
		return null
	if card.illustration != null:
		return card.illustration
	if card.icon != null:
		return card.icon

	var m := card.monster()
	if m != null and m.sprite_frames != null:
		for anim in ["Idle", "Run", "Attack", "Jump", "Hit"]:
			if m.sprite_frames.has_animation(anim) and m.sprite_frames.get_frame_count(anim) > 0:
				return m.sprite_frames.get_frame_texture(anim, 0)
	return null


static func _frame_style(border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#131826")
	s.border_color = border
	s.set_border_width_all(3)
	s.set_corner_radius_all(10)
	s.set_content_margin_all(10)
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 4
	return s


static func _art_style(border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#0b0f18")
	s.border_color = Color(border, 0.55)
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(4)
	return s
