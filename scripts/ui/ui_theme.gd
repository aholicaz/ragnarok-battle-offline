## UITheme — สีและสไตล์กลางของหน้าต่างทั้งหมด
## อยากเปลี่ยนหน้าตา UI ทั้งเกม แก้ที่ไฟล์นี้ไฟล์เดียว
class_name UITheme
extends RefCounted

const BG := Color("#161b28")
const PANEL := Color("#1e2537")
const PANEL_LIGHT := Color("#2a3450")
const BORDER := Color("#4a5a7a")
const ACCENT := Color("#ffd54a")
const TEXT := Color("#e6ecf5")
const TEXT_DIM := Color("#93a1b8")
const HP := Color("#e64c4c")
const SP := Color("#4c8ce6")
const EXP := Color("#5ccf7a")
## สีหลอดค่าประสบการณ์อาชีพ (Job)
const JOB := Color("#c58cf0")
const GOOD := Color("#5cff7a")
const BAD := Color("#ff6b6b")


static func panel_style(bg: Color = PANEL, border: Color = BORDER, radius: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(8)
	return s


static func slot_style(highlight: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL_LIGHT if not highlight else Color("#3d4a70")
	s.border_color = ACCENT if highlight else BORDER
	s.set_border_width_all(2 if highlight else 1)
	s.set_corner_radius_all(4)
	return s


## ★ ใส่รูปในช่องไอเทม/การ์ดให้อยู่ "กึ่งกลางเป๊ะ" ★
##
## ไม่ใช้ `button.icon` เพราะ Godot จะวางรูปชิดมุมเวลาเปิด expand_icon
## วิธีนี้ใช้ TextureRect ซ้อนเต็มปุ่มแทน แล้วให้มันจัดกึ่งกลาง + คงสัดส่วนภาพเอง
## คืน [TextureRect (รูป), Label (จำนวน มุมขวาล่าง)]
static func make_slot_icon(button: Button, margin: float = 5.0) -> Array:
	var art := TextureRect.new()
	art.name = "SlotIcon"
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# ต้องใช้ and_offsets ไม่งั้นจะได้กรอบขนาด 0 (ดูหัวข้อ ConfirmDialog)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = margin
	art.offset_top = margin
	art.offset_right = -margin
	art.offset_bottom = -margin
	button.add_child(art)

	var count := Label.new()
	count.name = "SlotCount"
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	count.offset_right = -3
	count.offset_bottom = -1
	count.add_theme_font_size_override("font_size", 11)
	count.add_theme_color_override("font_color", Color.WHITE)
	count.add_theme_color_override("font_outline_color", Color.BLACK)
	count.add_theme_constant_override("outline_size", 4)
	button.add_child(count)

	return [art, count]


static func make_label(text: String, size: int = 14, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func make_button(text: String, min_width: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", ACCENT)
	b.add_theme_stylebox_override("normal", _btn_style(PANEL_LIGHT))
	b.add_theme_stylebox_override("hover", _btn_style(Color("#3a4870")))
	b.add_theme_stylebox_override("pressed", _btn_style(Color("#4a5a90")))
	b.add_theme_stylebox_override("disabled", _btn_style(Color("#232a3c")))
	if min_width > 0.0:
		b.custom_minimum_size.x = min_width
	return b


static func _btn_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


static func make_bar(fill_color: Color, height: float = 16.0) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = height
	bar.max_value = 100
	bar.value = 100

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#0d1119")
	bg.border_color = Color("#000000")
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


static func separator() -> HSeparator:
	var sep := HSeparator.new()
	var s := StyleBoxFlat.new()
	s.bg_color = BORDER
	s.content_margin_top = 1
	sep.add_theme_stylebox_override("separator", s)
	return sep
