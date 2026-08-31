## EquipmentWindow — หน้าสวมใส่ชุดและอาวุธ (กด E)
## หน้าตาแบบ Ragnarok: แท็บด้านบน · ช่องอุปกรณ์ซ้าย-ขวา · ตัวละครอยู่ตรงกลาง
## คลิกช่องที่มีของ = ดูรายละเอียด · คลิกซ้ำ = ถอดออก
class_name EquipmentWindow
extends GameWindow

## ขนาดช่องอุปกรณ์หนึ่งช่อง (กล่องชื่อไอเทม + ไอคอนขวา)
const SLOT_SIZE := Vector2(152, 44)
## ความกว้างสูงสุดของไอคอนในช่องสวมใส่ (พิกเซล)
const ICON_MAX := 32
## ขนาดกรอบตัวละครตรงกลาง
const PREVIEW_SIZE := Vector2(146, 240)

## ชื่อช่องแบบสั้น (ป้ายเล็ก ๆ ใต้กล่อง เหมือนหน้าต่างของ RO)
const SLOT_CAPTION := {
	Equipment.EquipSlot.HEAD: "ศีรษะ · head",
	Equipment.EquipSlot.WEAPON: "อาวุธ · R-hand",
	Equipment.EquipSlot.ARMOR: "ชุดเกราะ · body",
	Equipment.EquipSlot.ACCESSORY_1: "ประดับ · acc 1",
	Equipment.EquipSlot.GARMENT: "ผ้าคลุม · robe",
	Equipment.EquipSlot.OFFHAND: "มือรอง · L-hand",
	Equipment.EquipSlot.SHOES: "รองเท้า · shoes",
	Equipment.EquipSlot.ACCESSORY_2: "ประดับ · acc 2",
}

## ช่องคอลัมน์ซ้าย (บน -> ล่าง)
const LEFT_SLOTS := [
	Equipment.EquipSlot.HEAD,
	Equipment.EquipSlot.WEAPON,
	Equipment.EquipSlot.ARMOR,
	Equipment.EquipSlot.ACCESSORY_1,
]
## ช่องคอลัมน์ขวา (บน -> ล่าง)
const RIGHT_SLOTS := [
	Equipment.EquipSlot.GARMENT,
	Equipment.EquipSlot.OFFHAND,
	Equipment.EquipSlot.SHOES,
	Equipment.EquipSlot.ACCESSORY_2,
]

var _slot_buttons: Dictionary = {}   # EquipSlot -> Button
var _slot_icons: Dictionary = {}     # EquipSlot -> TextureRect
var _slot_names: Dictionary = {}     # EquipSlot -> Label (ชื่อไอเทม)
var _slot_captions: Dictionary = {}  # EquipSlot -> Label (ป้ายชื่อช่องใต้กล่อง)

var _tab_equip: Button
var _tab_shadow: Button
var _page_equip: Control
var _page_shadow: Control
var _tab_index := 0

var _preview: TextureRect
var _preview_hint: Label
var _preview_caption: Label

var _summary: Label
var _info_slot: int = -1


func _ready() -> void:
	window_title = "ไอเท็มที่สวมใส่"
	super._ready()
	custom_minimum_size = Vector2(452, 0)
	Events.equipment_changed.connect(refresh)
	Events.stats_changed.connect(refresh)


# =========================================================
# สร้างหน้าตา
# =========================================================
func _build_content() -> void:
	# ---------- แถบแท็บ ----------
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 3)
	content.add_child(tabs)

	_tab_equip = _make_tab("อุปกรณ์  (equipment)")
	_tab_equip.pressed.connect(func(): _set_tab(0))
	tabs.add_child(_tab_equip)

	_tab_shadow = _make_tab("เงา  (Shadow)")
	_tab_shadow.pressed.connect(func(): _set_tab(1))
	tabs.add_child(_tab_shadow)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tabs.add_child(spacer)

	# ---------- หน้าอุปกรณ์ ----------
	_page_equip = VBoxContainer.new()
	_page_equip.add_theme_constant_override("separation", 6)
	content.add_child(_page_equip)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_page_equip.add_child(row)

	# คอลัมน์ซ้าย
	row.add_child(_make_column(LEFT_SLOTS))
	# ตัวละครตรงกลาง
	row.add_child(_make_preview())
	# คอลัมน์ขวา
	row.add_child(_make_column(RIGHT_SLOTS))

	var hint := UITheme.make_label(
		"คลิกช่อง = ดูรายละเอียด  ·  คลิกซ้ำที่ช่องเดิม = ถอดออก", 11, UITheme.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_equip.add_child(hint)

	# ---------- หน้าเงา (ยังไม่เปิดใช้งาน) ----------
	_page_shadow = VBoxContainer.new()
	_page_shadow.add_theme_constant_override("separation", 8)
	_page_shadow.custom_minimum_size.y = PREVIEW_SIZE.y
	content.add_child(_page_shadow)

	var sh_box := CenterContainer.new()
	sh_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_shadow.add_child(sh_box)

	var sh_text := UITheme.make_label(
		"ช่องอุปกรณ์เงา (Shadow Gear)\nยังไม่เปิดใช้งานในเวอร์ชันนี้", 13, UITheme.TEXT_DIM)
	sh_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sh_box.add_child(sh_text)

	# ---------- สรุปค่าพลัง ----------
	content.add_child(UITheme.separator())
	_summary = UITheme.make_label("", 13, UITheme.TEXT)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_summary)

	_set_tab(0)


func _make_tab(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 26)
	b.add_theme_font_size_override("font_size", 12)
	return b


## คอลัมน์ช่องอุปกรณ์ (โครงเดียวกันทั้งสองฝั่ง: ชื่อไอเทมซ้าย · ไอคอนขวา)
func _make_column(slot_list: Array, _unused := false) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	for slot in slot_list:
		col.add_child(_make_slot(slot))
	return col


## หนึ่งช่อง = กล่องชื่อไอเทม + ไอคอนขวา  แล้วมีป้ายชื่อช่องเล็ก ๆ อยู่ใต้กล่อง
func _make_slot(slot: int) -> VBoxContainer:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 0)

	var btn := Button.new()
	btn.text = ""
	btn.custom_minimum_size = SLOT_SIZE
	btn.focus_mode = Control.FOCUS_NONE
	btn.clip_contents = true
	btn.add_theme_stylebox_override("normal", UITheme.slot_style())
	btn.add_theme_stylebox_override("hover", UITheme.slot_style(true))
	btn.add_theme_stylebox_override("pressed", UITheme.slot_style(true))
	btn.pressed.connect(func(): _on_slot_pressed(slot))
	_slot_buttons[slot] = btn
	cell.add_child(btn)

	# กล่องจัดวางภายในปุ่ม (ปุ่มไม่จัดวางลูกให้เอง ต้องกางเต็มปุ่มเอง)
	var box := HBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 5
	box.offset_top = 3
	box.offset_right = -4
	box.offset_bottom = -3
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(box)

	# ★ ชื่อไอเทม — ชิดซ้าย ตัดได้ 2 บรรทัด ★
	var name_label := UITheme.make_label("", 11, UITheme.TEXT)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.max_lines_visible = 2
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_names[slot] = name_label
	box.add_child(name_label)

	# ★ รูปอุปกรณ์ — อยู่ขอบขวาของกล่อง มีกรอบสี่เหลี่ยมเล็ก ๆ ครอบ (เหมือน RO) ★
	var art_frame := PanelContainer.new()
	art_frame.custom_minimum_size = Vector2(ICON_MAX + 4, ICON_MAX + 4)
	art_frame.add_theme_stylebox_override("panel",
		UITheme.panel_style(Color("#0d1119"), UITheme.BORDER, 3))
	art_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(art_frame)

	var art := TextureRect.new()
	art.name = "SlotIcon"
	art.custom_minimum_size = Vector2(ICON_MAX, ICON_MAX)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slot_icons[slot] = art
	art_frame.add_child(art)

	# ★ ป้ายชื่อช่อง (เล็ก จาง) อยู่ใต้กล่อง เหมือน head / L-hand ของ RO ★
	var caption := UITheme.make_label(SLOT_CAPTION.get(slot, Equipment.SLOT_NAMES[slot]),
		9, UITheme.TEXT_DIM)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_captions[slot] = caption
	cell.add_child(caption)

	return cell


func _make_preview() -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = PREVIEW_SIZE
	frame.add_theme_stylebox_override("panel",
		UITheme.panel_style(Color("#10141f"), UITheme.BORDER, 4))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(box)

	_preview = TextureRect.new()
	_preview.name = "CharacterPreview"
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_preview)

	_preview_hint = UITheme.make_label("(ยังไม่มีตัวละครในฉาก)", 11, UITheme.TEXT_DIM)
	_preview_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_preview_hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_preview_hint)

	_preview_caption = UITheme.make_label("", 11, UITheme.ACCENT)
	_preview_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_preview_caption)

	return frame


# =========================================================
# แท็บ
# =========================================================
func _set_tab(index: int) -> void:
	_tab_index = index
	if _page_equip != null:
		_page_equip.visible = index == 0
	if _page_shadow != null:
		_page_shadow.visible = index == 1
	_style_tab(_tab_equip, index == 0)
	_style_tab(_tab_shadow, index == 1)
	# หน้าต่างจะได้หดตามหน้าที่เปิดอยู่
	# ★ ต้องรอ 1 เฟรมก่อน ★ ไม่งั้นได้ขนาดเดิมของหน้าที่เพิ่งซ่อนไป
	# (Control ไม่หดเองอยู่แล้ว ถ้าตั้งค่าผิดรอบ หน้าต่างจะค้างใหญ่ตลอด)
	fit_to_content()


func _style_tab(b: Button, active: bool) -> void:
	if b == null:
		return
	var box := UITheme.panel_style(
		UITheme.PANEL_LIGHT if active else Color("#141a28"),
		UITheme.ACCENT if active else UITheme.BORDER, 4)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	b.add_theme_stylebox_override("normal", box)
	b.add_theme_stylebox_override("hover", box)
	b.add_theme_stylebox_override("pressed", box)
	b.add_theme_color_override("font_color", UITheme.ACCENT if active else UITheme.TEXT_DIM)
	b.add_theme_color_override("font_hover_color", UITheme.TEXT)


# =========================================================
# กดช่อง
# =========================================================
func _on_slot_pressed(slot: int) -> void:
	var inst := PlayerState.equipment.get_item(slot)
	if inst == null:
		Events.say("ช่องนี้ว่างอยู่ — เปิดกระเป๋า (I) แล้วกดสวมใส่")
		UI.hide_item_popup()
		return
	# กดครั้งแรก = ดูรายละเอียด / กดซ้ำที่ช่องเดิม = ถอดออก
	if _info_slot != slot or not UI.item_popup.is_open():
		_info_slot = slot
		UI.show_item(inst, self, "กดช่องนี้อีกครั้งเพื่อถอดออก")
		return
	_info_slot = -1
	UI.hide_item_popup()
	PlayerState.unequip(slot)


# =========================================================
# อัพเดตข้อมูล
# =========================================================
func refresh() -> void:
	if _summary == null:
		return

	for slot in _slot_buttons.keys():
		var btn: Button = _slot_buttons[slot]
		var art: TextureRect = _slot_icons.get(slot, null)
		var name_label: Label = _slot_names.get(slot, null)
		var inst: ItemInstance = PlayerState.equipment.get_item(slot)
		btn.icon = null

		if inst == null:
			if art != null:
				art.texture = null
			if name_label != null:
				# ช่องว่าง = ปล่อยกล่องโล่ง (ชื่อช่องอยู่ป้ายเล็กใต้กล่องแล้ว)
				name_label.text = ""
				name_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
			btn.tooltip_text = Equipment.SLOT_NAMES[slot] + " — ว่าง"
		else:
			var d := inst.data()
			if art != null:
				art.texture = d.icon if d != null and d.icon != null else null
			if name_label != null:
				name_label.text = inst.display_name()
				name_label.add_theme_color_override("font_color",
					UITheme.ACCENT if inst.refine > 0 else UITheme.TEXT)
			btn.tooltip_text = "%s\nATK %d  DEF %d" % [inst.display_name(), inst.total_atk(), inst.total_def()]

	_update_preview()

	var s := PlayerState.stats
	_summary.text = "ATK %d   DEF %d   MATK %d   MDEF %d\nHIT %d   FLEE %d   CRIT %.1f%%   ASPD %.2f/s\nMaxHP %d   MaxSP %d" % [
		s.atk, s.def, s.matk, s.mdef, s.hit, s.flee, s.crit, s.aspd, s.max_hp, s.max_sp
	]


## รูปตัวละครตรงกลาง — ดึงเฟรมท่ายืนของผู้เล่นในฉากมาโชว์
func _update_preview() -> void:
	if _preview == null:
		return
	var tex := _player_frame()
	_preview.texture = tex
	_preview.visible = tex != null
	if _preview_hint != null:
		_preview_hint.visible = tex == null

	if _preview_caption != null:
		var s := PlayerState.stats
		var job := GameData.get_job(s.job_id)
		var job_name: String = job.display_name if job != null else ""
		_preview_caption.text = ("Lv.%d  %s" % [s.level, job_name]).strip_edges()


func _player_frame() -> Texture2D:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return null
	var spr = p.get("sprite")
	if not (spr is AnimatedSprite2D):
		return null
	var frames: SpriteFrames = spr.sprite_frames
	if frames == null:
		return null

	# หันหน้าไปทางเดียวกันทุกครั้ง ไม่ต้องสนว่าตอนนั้นตัวละครหันไปทางไหน
	var faces_left = p.get("sprite_faces_left")
	if faces_left != null:
		_preview.flip_h = bool(faces_left)

	# ท่ายืนของอาวุธที่ถืออยู่ก่อน แล้วค่อยถอยไปท่ายืนธรรมดา
	var wanted: Array[String] = []
	if p.has_method("weapon_suffix"):
		var suffix: String = p.weapon_suffix()
		if suffix != "":
			wanted.append("Idle_" + suffix)
	wanted.append("Idle")
	wanted.append(String(spr.animation))

	for want in wanted:
		var real := want
		if p.has_method("_real_anim"):
			real = p._real_anim(want)
		elif not frames.has_animation(want):
			real = ""
		if real != "" and frames.has_animation(real) and frames.get_frame_count(real) > 0:
			return frames.get_frame_texture(real, 0)
	return null
