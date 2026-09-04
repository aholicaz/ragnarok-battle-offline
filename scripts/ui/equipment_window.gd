## EquipmentWindow — ★ หน้าตัวละคร: ของสวมใส่ + สเตตัส ในหน้าเดียว (รอบ 45) ★  (กด E หรือ C)
##
## ซ้าย  = ช่องอุปกรณ์แบบ RO (ชื่อไอเทมซ้าย · ไอคอนขวา · ป้ายชื่อช่องใต้กล่อง) + ตัวละครตรงกลาง
## ขวา   = สเตตัส 6 ค่า (ปุ่ม +) + ค่าที่คำนวณได้ทั้งหมด — เห็นทันทีว่าใส่ของแล้วอะไรเปลี่ยน (ตัวเลขที่ขึ้นจากของสวมใส่เป็นสีเขียว)
## โทนสีครีมเหมือนหน้ากระเป๋า (InventoryWindow.C_XXX)
##
## ★ ลาก-วางได้ ★ (DragSlot)
##   ลากของจากกระเป๋ามาปล่อยที่ช่องอุปกรณ์ / ที่รูปตัวละคร = สวมใส่
##   ลากของจากช่องอุปกรณ์ไปปล่อยในกระเป๋า = ถอด · คลิกช่อง = ดูรายละเอียด · คลิกซ้ำ = ถอด
class_name EquipmentWindow
extends GameWindow

## ขนาดช่องอุปกรณ์หนึ่งช่อง (กล่องชื่อไอเทม + ไอคอนขวา)
const SLOT_SIZE := Vector2(152, 44)
## ความกว้างสูงสุดของไอคอนในช่องสวมใส่ (พิกเซล)
const ICON_MAX := 32
## ขนาดกรอบตัวละครตรงกลาง
const PREVIEW_SIZE := Vector2(140, 236)

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
const LEFT_SLOTS := [
	Equipment.EquipSlot.HEAD,
	Equipment.EquipSlot.WEAPON,
	Equipment.EquipSlot.ARMOR,
	Equipment.EquipSlot.ACCESSORY_1,
]
const RIGHT_SLOTS := [
	Equipment.EquipSlot.GARMENT,
	Equipment.EquipSlot.OFFHAND,
	Equipment.EquipSlot.SHOES,
	Equipment.EquipSlot.ACCESSORY_2,
]

const STAT_LABELS := {
	&"str": "STR พลัง",
	&"agi": "AGI คล่อง",
	&"vit": "VIT อึด",
	&"int": "INT ปัญญา",
	&"dex": "DEX แม่น",
	&"luk": "LUK โชค",
}
## คำอธิบายสั้น ๆ ว่าแต่ละสเตตัสให้อะไร (tooltip ที่ชื่อ/ปุ่ม +) — ตัวเลขจริงอยู่ที่ PlayerStats (ตารางผลของสเตตัส)
const STAT_TIPS := {
	&"str": "ATK +1 ต่อแต้ม (+โบนัสทุก 10 แต้ม) · ช่องกระเป๋า +1 ทุก 5 แต้ม",
	&"agi": "FLEE +1 · ความเร็วโจมตี +1.2%",
	&"vit": "DEF +0.5 · HP +6 และ +1.2% · ฟื้น HP",
	&"int": "MATK +1 · MDEF +0.5 · SP +4 และ +1% · ฟื้น SP +0.12/วิ",
	&"dex": "HIT +1.5 · ATK +0.2 · ความเร็วโจมตี +0.4% · ลดคูลดาวน์ 1% ทุก 5 แต้ม",
	&"luk": "CRIT +0.3% · ATK +0.33",
}

# ---- โทนสีครีม (ใช้ชุดเดียวกับกระเป๋า) ----
## ★ รอบ 48 — ใช้โทนเดียวกับกระเป๋า (= HUD) ทั้งชุด ★
const C_BG := InventoryWindow.C_BG
const C_BORDER := InventoryWindow.C_BORDER
const C_BAR := InventoryWindow.C_BAR
const C_SLOT := InventoryWindow.C_SLOT
const C_SLOT_EDGE := InventoryWindow.C_SLOT_EDGE
const C_SLOT_SEL := InventoryWindow.C_SLOT_SEL
const C_SEL_EDGE := InventoryWindow.C_SEL_EDGE
const C_TEXT := InventoryWindow.C_TEXT
const C_TEXT_DIM := InventoryWindow.C_TEXT_DIM
const C_BTN := InventoryWindow.C_BTN
const C_BTN_HOVER := InventoryWindow.C_BTN_HOVER
const C_BTN_DISABLED := InventoryWindow.C_BTN_DISABLED
const C_FRAME := InventoryWindow.C_FRAME
const C_INNER := InventoryWindow.C_INNER
const C_GOOD := UITheme.GOOD              # ค่าที่ได้จากของสวมใส่ (เขียวสว่างบนพื้นเข้ม)
const C_ACCENT := UITheme.ACCENT

var _slot_buttons: Dictionary = {}   # EquipSlot -> DragSlot
var _slot_icons: Dictionary = {}     # EquipSlot -> TextureRect
var _slot_names: Dictionary = {}     # EquipSlot -> Label
var _slot_captions: Dictionary = {}  # EquipSlot -> Label

var _tab_equip: Button
var _tab_shadow: Button
var _page_equip: Control
var _page_shadow: Control
var _tab_index := 0

var _preview: TextureRect
var _preview_drop: DragSlot           # พื้นที่รับของ (ลากของมาวางที่ตัวละคร = สวมใส่)
var _preview_hint: Label
var _preview_caption: Label

var _summary: Label
var _info_slot: int = -1

# ---- สเตตัส ----
var _header: Label
var _point_label: Label
var _stat_rows: Dictionary = {}      # stat -> {"value": Label, "button": Button, "cost": Label}
var _derived: Dictionary = {}        # key -> Label
var _equip_bonus_label: Label


func _ready() -> void:
	window_title = "ตัวละคร — สวมใส่ + สเตตัส"
	super._ready()
	# ---- โทนครีมแบบกระเป๋า ----
	add_theme_stylebox_override("panel", InventoryWindow._style(C_BG, C_BORDER, 12))
	var root := get_child(0)
	var bar := root.get_child(0) as PanelContainer
	bar.add_theme_stylebox_override("panel", InventoryWindow._style(C_BAR, C_BORDER, 8))
	title_label.add_theme_color_override("font_color", C_TEXT)
	custom_minimum_size = Vector2(0, 0)
	Events.equipment_changed.connect(refresh)
	Events.stats_changed.connect(refresh)
	Events.level_up.connect(func(_lv): refresh())
	Events.job_level_up.connect(func(_lv): refresh())
	Events.exp_changed.connect(func(_c, _n): refresh())
	Events.job_exp_changed.connect(func(_c, _n): refresh())


func _cream_button(text: String, min_width: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if min_width > 0:
		b.custom_minimum_size.x = min_width
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", C_TEXT)
	b.add_theme_color_override("font_hover_color", C_TEXT)
	b.add_theme_color_override("font_pressed_color", C_TEXT)
	b.add_theme_stylebox_override("normal", InventoryWindow._style(C_BTN, C_SLOT_EDGE, 8, 4))
	b.add_theme_stylebox_override("hover", InventoryWindow._style(C_BTN_HOVER, C_BORDER, 8, 4))
	b.add_theme_stylebox_override("pressed", InventoryWindow._style(C_SLOT_SEL, C_SEL_EDGE, 8, 4))
	b.add_theme_stylebox_override("disabled", InventoryWindow._style(C_BTN_DISABLED, C_SLOT_EDGE, 8, 4))
	b.add_theme_color_override("font_disabled_color", C_TEXT_DIM)
	return b


func _label(text: String, size: int = 13, color: Color = C_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _slot_box(selected: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = C_SLOT_SEL if selected else C_SLOT
	s.border_color = C_SEL_EDGE if selected else C_SLOT_EDGE
	s.set_border_width_all(2 if selected else 1)
	s.set_corner_radius_all(6)
	return s


# =========================================================
# สร้างหน้าตา
# =========================================================
func _build_content() -> void:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	content.add_child(columns)

	# ================= ซ้าย: ของสวมใส่ =================
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	columns.add_child(left)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	left.add_child(tabs)
	_tab_equip = _cream_button("อุปกรณ์  (equipment)")
	_tab_equip.pressed.connect(func(): _set_tab(0))
	tabs.add_child(_tab_equip)
	_tab_shadow = _cream_button("เงา  (Shadow)")
	_tab_shadow.pressed.connect(func(): _set_tab(1))
	tabs.add_child(_tab_shadow)

	_page_equip = VBoxContainer.new()
	_page_equip.add_theme_constant_override("separation", 6)
	left.add_child(_page_equip)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_page_equip.add_child(row)
	row.add_child(_make_column(LEFT_SLOTS))
	row.add_child(_make_preview())
	row.add_child(_make_column(RIGHT_SLOTS))

	var hint := _label("คลิกช่อง = รายละเอียด · คลิกซ้ำ = ถอด · ★ ลากของจากกระเป๋ามาวางที่นี่ = สวมใส่ ★", 10, C_TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 380
	_page_equip.add_child(hint)

	_page_shadow = VBoxContainer.new()
	_page_shadow.add_theme_constant_override("separation", 8)
	_page_shadow.custom_minimum_size = Vector2(380, PREVIEW_SIZE.y)
	left.add_child(_page_shadow)
	var sh_box := CenterContainer.new()
	sh_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_shadow.add_child(sh_box)
	var sh_text := _label("ช่องอุปกรณ์เงา (Shadow Gear)\nยังไม่เปิดใช้งานในเวอร์ชันนี้", 13, C_TEXT_DIM)
	sh_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sh_box.add_child(sh_text)

	# สรุปโบนัสจากของสวมใส่
	var sum_panel := PanelContainer.new()
	sum_panel.add_theme_stylebox_override("panel", InventoryWindow._style(C_INNER, C_SLOT_EDGE, 8, 5))
	left.add_child(sum_panel)
	var sum_box := VBoxContainer.new()
	sum_box.add_theme_constant_override("separation", 2)
	sum_panel.add_child(sum_box)
	sum_box.add_child(_label("จากของสวมใส่ + การ์ด", 11, C_TEXT_DIM))
	_summary = _label("", 12, C_GOOD)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size.x = 370
	sum_box.add_child(_summary)

	# ================= ขวา: สเตตัส =================
	var vsep := VSeparator.new()
	columns.add_child(vsep)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.custom_minimum_size.x = 300
	columns.add_child(right)

	_header = _label("", 15, C_ACCENT)
	right.add_child(_header)
	_point_label = _label("", 12, C_TEXT)
	right.add_child(_point_label)

	var stat_panel := PanelContainer.new()
	stat_panel.add_theme_stylebox_override("panel", InventoryWindow._style(C_INNER, C_SLOT_EDGE, 8, 5))
	right.add_child(stat_panel)
	var stat_box := VBoxContainer.new()
	stat_box.add_theme_constant_override("separation", 2)
	stat_panel.add_child(stat_box)

	for stat in PlayerStats.STAT_NAMES:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		var name_label := _label(STAT_LABELS[stat], 13, C_TEXT)
		name_label.custom_minimum_size.x = 96
		name_label.tooltip_text = STAT_TIPS.get(stat, "")
		name_label.mouse_filter = Control.MOUSE_FILTER_STOP
		r.add_child(name_label)
		var value_label := _label("1", 14, C_TEXT)
		value_label.custom_minimum_size.x = 78
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		r.add_child(value_label)
		var btn := _cream_button("+", 30)
		btn.tooltip_text = STAT_TIPS.get(stat, "")
		var s: StringName = stat
		btn.pressed.connect(func(): _raise(s))
		r.add_child(btn)
		var cost_label := _label("", 11, C_TEXT_DIM)
		cost_label.custom_minimum_size.x = 26
		r.add_child(cost_label)
		stat_box.add_child(r)
		_stat_rows[stat] = {"value": value_label, "button": btn, "cost": cost_label}

	# ค่าที่คำนวณได้
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 2)
	right.add_child(grid)
	var fields := [
		[&"atk", "ATK"], [&"def", "DEF"],
		[&"matk", "MATK"], [&"mdef", "MDEF"],
		[&"hit", "HIT"], [&"flee", "FLEE"],
		[&"crit", "CRIT"], [&"aspd", "ASPD"],
		[&"max_hp", "MaxHP"], [&"max_sp", "MaxSP"],
		[&"regen", "ฟื้น HP"], [&"sp_regen", "ฟื้น SP"],
		[&"speed", "SPEED"], [&"damage_percent", "ดาเมจ%"],
		[&"hp_drain", "ดูดเลือด"], [&"sp_drain", "ดูดมานา"],
		[&"bag", "ช่องกระเป๋า"], [&"cdr", "ลดคูลดาวน์"],
	]
	for f in fields:
		var key: StringName = f[0]
		grid.add_child(_label(f[1], 11, C_TEXT_DIM))
		var v := _label("-", 12, C_TEXT)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.custom_minimum_size.x = 56
		grid.add_child(v)
		_derived[key] = v

	_equip_bonus_label = _label("", 10, C_TEXT_DIM)
	right.add_child(_equip_bonus_label)

	_set_tab(0)


func _make_column(slot_list: Array, _unused := false) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	for slot in slot_list:
		col.add_child(_make_slot(slot))
	return col


## หนึ่งช่อง = กล่องชื่อไอเทม + ไอคอนขวา แล้วมีป้ายชื่อช่องเล็ก ๆ อยู่ใต้กล่อง
func _make_slot(slot: int) -> VBoxContainer:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 0)

	var btn := DragSlot.new()
	btn.kind = "equip"
	btn.slot_index = slot
	btn.text = ""
	btn.custom_minimum_size = SLOT_SIZE
	btn.clip_contents = true
	btn.add_theme_stylebox_override("normal", _slot_box())
	btn.add_theme_stylebox_override("hover", _slot_box(true))
	btn.add_theme_stylebox_override("pressed", _slot_box(true))
	btn.pressed.connect(func(): _on_slot_pressed(slot))
	btn.drag_icon_func = func() -> Texture2D:
		var inst := PlayerState.equipment.get_item(slot)
		if inst == null or inst.data() == null:
			return null
		return inst.data().icon
	btn.can_drop_func = func(data: Dictionary, _t: DragSlot) -> bool:
		return String(data.get("kind", "")) == "inventory"
	btn.drop_func = func(data: Dictionary, _t: DragSlot) -> bool:
		return _drop_inventory_item(int(data.get("slot", -1)), slot)
	_slot_buttons[slot] = btn
	cell.add_child(btn)

	var box := HBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 5
	box.offset_top = 3
	box.offset_right = -4
	box.offset_bottom = -3
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(box)

	var name_label := _label("", 11, C_TEXT)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.max_lines_visible = 2
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slot_names[slot] = name_label
	box.add_child(name_label)

	var art_frame := PanelContainer.new()
	art_frame.custom_minimum_size = Vector2(ICON_MAX + 4, ICON_MAX + 4)
	art_frame.add_theme_stylebox_override("panel", InventoryWindow._style(C_FRAME, C_SLOT_EDGE, 4, 2))
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

	var caption := _label(SLOT_CAPTION.get(slot, Equipment.SLOT_NAMES[slot]), 9, C_TEXT_DIM)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_slot_captions[slot] = caption
	cell.add_child(caption)
	return cell


func _make_preview() -> Control:
	# กรอบตัวละคร = DragSlot แบบ "any" (รับของที่ลากมาวาง = สวมใส่ช่องที่เหมาะ)
	_preview_drop = DragSlot.new()
	_preview_drop.kind = "any"
	_preview_drop.text = ""
	_preview_drop.custom_minimum_size = PREVIEW_SIZE
	_preview_drop.add_theme_stylebox_override("normal", InventoryWindow._style(C_BTN, C_SLOT_EDGE, 8, 2))
	_preview_drop.add_theme_stylebox_override("hover", InventoryWindow._style(C_BTN_HOVER, C_BORDER, 8, 2))
	_preview_drop.add_theme_stylebox_override("pressed", InventoryWindow._style(C_BTN, C_SLOT_EDGE, 8, 2))
	_preview_drop.can_drop_func = func(data: Dictionary, _t: DragSlot) -> bool:
		return String(data.get("kind", "")) == "inventory"
	_preview_drop.drop_func = func(data: Dictionary, _t: DragSlot) -> bool:
		return _drop_inventory_item(int(data.get("slot", -1)), -1)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 3
	box.offset_top = 3
	box.offset_right = -3
	box.offset_bottom = -3
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_drop.add_child(box)

	_preview = TextureRect.new()
	_preview.name = "CharacterPreview"
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_preview)

	_preview_hint = _label("(ยังไม่มีตัวละครในฉาก)", 11, C_TEXT_DIM)
	_preview_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_preview_hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_preview_hint)

	_preview_caption = _label("", 11, C_ACCENT)
	_preview_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_preview_caption)
	return _preview_drop


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
	fit_to_content()


func _style_tab(b: Button, active: bool) -> void:
	if b == null:
		return
	b.add_theme_stylebox_override("normal",
		InventoryWindow._style(C_SLOT_SEL if active else C_BTN,
			C_SEL_EDGE if active else C_SLOT_EDGE, 8, 4))


# =========================================================
# กดช่อง / ลากวาง
# =========================================================
func _on_slot_pressed(slot: int) -> void:
	var inst := PlayerState.equipment.get_item(slot)
	if inst == null:
		Events.say("ช่องนี้ว่างอยู่ — ลากของจากกระเป๋า (I) มาวางได้เลย")
		UI.hide_item_popup()
		return
	if _info_slot != slot or not UI.item_popup.is_open():
		_info_slot = slot
		UI.show_item(inst, self, "กดช่องนี้อีกครั้งเพื่อถอดออก · หรือลากไปวางในกระเป๋า")
		return
	_info_slot = -1
	UI.hide_item_popup()
	PlayerState.unequip(slot)


## ★ ของจากกระเป๋าถูกลากมาวาง ★ target_slot = ช่องที่วาง (-1 = วางที่ตัวละคร ให้ระบบเลือกช่องเอง)
func _drop_inventory_item(inv_slot: int, target_slot: int) -> bool:
	var inst := PlayerState.inventory.get_slot(inv_slot)
	if inst == null:
		return false
	var d := inst.data()
	if d == null or not d.is_equipment():
		Events.say("ไอเทมนี้สวมใส่ไม่ได้")
		return false
	if target_slot >= 0:
		# วางลงช่องเฉพาะ: ต้องเป็นช่องที่ของชิ้นนี้ใส่ได้
		var want := Equipment.slot_for(d, target_slot == Equipment.EquipSlot.ACCESSORY_2)
		if want != target_slot:
			Events.say("%s ใส่ช่อง%sไม่ได้" % [d.display_name, Equipment.SLOT_NAMES[target_slot]])
			return false
		if d.slot == ItemData.Slot.ACCESSORY:
			return _equip_accessory_to(inv_slot, target_slot)
	var ok := PlayerState.equip_from_inventory(inv_slot)
	if ok:
		UI.hide_item_popup()
	return ok


## เครื่องประดับเลือกช่องเองได้ (ลากไปวางช่อง 1 หรือ 2)
func _equip_accessory_to(inv_slot: int, target_slot: int) -> bool:
	var inst := PlayerState.inventory.get_slot(inv_slot)
	var d := inst.data()
	if PlayerState.stats.level < d.required_level:
		Events.say("ต้องเลเวล %d ขึ้นไปถึงจะใส่ %s ได้" % [d.required_level, d.display_name])
		return false
	PlayerState.inventory.set_slot(inv_slot, null)
	var old := PlayerState.equipment.equip(target_slot, inst)
	if old != null:
		PlayerState.inventory.set_slot(inv_slot, old)
	PlayerState.refresh()
	UI.hide_item_popup()
	return true


# =========================================================
# อัพเดตข้อมูล
# =========================================================
func _raise(stat: StringName) -> void:
	if PlayerState.raise_stat(stat):
		refresh()
	else:
		Events.say("Stat Point ไม่พอ")


const FLAT_NAMES := {"atk": "ATK", "def": "DEF", "matk": "MATK", "mdef": "MDEF", "hit": "HIT", "flee": "FLEE",
	"crit": "CRIT", "max_hp": "MaxHP", "max_sp": "MaxSP", "aspd_percent": "ASPD%",
	"str": "STR", "agi": "AGI", "vit": "VIT", "int": "INT", "dex": "DEX", "luk": "LUK"}
const PCT_NAMES := {"damage_percent": "ดาเมจ", "def_percent": "DEF", "max_hp_percent": "HP", "max_sp_percent": "SP",
	"hp_drain_percent": "ดูดเลือด", "sp_drain_percent": "ดูดมานา", "atk_percent": "ATK", "matk_percent": "MATK",
	"aspd_percent": "ASPD", "move_speed_percent": "SPEED", "crit_damage_percent": "ดาเมจคริ",
	"cooldown_reduction_percent": "ลดคูลดาวน์"}


func refresh() -> void:
	if _summary == null:
		return

	# ---------- ช่องอุปกรณ์ ----------
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
				name_label.text = ""
			btn.tooltip_text = Equipment.SLOT_NAMES[slot] + " — ว่าง (ลากของมาวางได้)"
		else:
			var d := inst.data()
			if art != null:
				art.texture = d.icon if d != null and d.icon != null else null
			if name_label != null:
				name_label.text = inst.display_name()
				name_label.add_theme_color_override("font_color", C_ACCENT if inst.refine > 0 else C_TEXT)
			btn.tooltip_text = "%s\nATK %d  DEF %d" % [inst.display_name(), inst.total_atk(), inst.total_def()]
	_update_preview()

	# ---------- โบนัสจากของสวมใส่ ----------
	var eqp := PlayerState.equipment
	var flat := eqp.collect_bonus()
	var pct := eqp.collect_percent_bonus()
	var watk := eqp.weapon_atk()
	var parts: Array[String] = []
	if watk != 0:
		parts.append("ATK อาวุธ %d" % watk)
	for key in FLAT_NAMES.keys():
		var v := float(flat.get(StringName(key), 0.0))
		if not is_zero_approx(v):
			parts.append("%s %+d" % [FLAT_NAMES[key], int(v)])
	for key in PCT_NAMES.keys():
		var v := float(pct.get(StringName(key), 0.0))
		if not is_zero_approx(v):
			parts.append("%s %+.1f%%" % [PCT_NAMES[key], v])
	_summary.text = "  ".join(parts) if not parts.is_empty() else "— ยังไม่มีโบนัส —"

	# ---------- สเตตัส ----------
	var s := PlayerState.stats
	_header.text = "%s   Base Lv.%d   Job Lv.%d" % [s.job().display_name, s.level, s.job_level]
	var base_need := s.exp_to_next()
	var job_need := s.job_exp_to_next()
	var base_txt: String = "MAX" if base_need <= 0 else "%.1f%%" % (float(s.exp_current) / base_need * 100.0)
	var job_txt: String = "MAX" if job_need <= 0 else "%.1f%%" % (float(s.job_exp_current) / job_need * 100.0)
	_point_label.text = "EXP %s · Job EXP %s\nStat Point เหลือ %d · Skill Point %d" % [base_txt, job_txt, s.stat_points, s.skill_points]

	for stat in PlayerStats.STAT_NAMES:
		var r: Dictionary = _stat_rows[stat]
		var base := s.get_base_stat(stat)
		var total := s.get_total_stat(stat)
		var bonus := total - base
		if bonus != 0:
			(r.value as Label).text = "%d %+d" % [base, bonus]
			(r.value as Label).add_theme_color_override("font_color", C_GOOD)
		else:
			(r.value as Label).text = str(base)
			(r.value as Label).add_theme_color_override("font_color", C_TEXT)
		var cost := s.stat_cost(stat)
		(r.cost as Label).text = str(cost) if cost > 0 else "MAX"
		(r.button as Button).disabled = not s.can_raise_stat(stat)

	# ค่าที่คำนวณ — สีเขียวถ้าของสวมใส่/การ์ดมีส่วน
	_set_derived(&"atk", str(s.atk), watk != 0 or flat.has(&"atk") or pct.has(&"atk_percent"))
	_set_derived(&"def", str(s.def), flat.has(&"def") or pct.has(&"def_percent"))
	_set_derived(&"matk", str(s.matk), flat.has(&"matk"))
	_set_derived(&"mdef", str(s.mdef), flat.has(&"mdef"))
	_set_derived(&"hit", str(s.hit), flat.has(&"hit"))
	_set_derived(&"flee", str(s.flee), flat.has(&"flee"))
	_set_derived(&"crit", "%.1f%%" % s.crit, flat.has(&"crit"))
	_set_derived(&"aspd", "%.2f/s" % s.aspd, flat.has(&"aspd_percent") or pct.has(&"aspd_percent"))
	# ★ รอบ 50 — ช่องกระเป๋าจาก STR · ลดคูลดาวน์จาก DEX ★
	var bag_total: int = PlayerState.inventory.size if PlayerState.inventory != null else 0
	_set_derived(&"bag", "%d (+%d)" % [bag_total, s.bag_bonus_slots], s.bag_bonus_slots > 0)
	_set_derived(&"cdr", "%.0f%%" % s.cooldown_reduction,
		pct.has(&"cooldown_reduction_percent") or s.cooldown_reduction > 0.0)
	_set_derived(&"max_hp", str(s.max_hp), flat.has(&"max_hp") or pct.has(&"max_hp_percent"))
	_set_derived(&"max_sp", str(s.max_sp), flat.has(&"max_sp") or pct.has(&"max_sp_percent"))
	_set_derived(&"regen", "%.1f/s" % s.hp_regen, false)
	_set_derived(&"sp_regen", "%.2f/s" % s.sp_regen, false)
	_set_derived(&"speed", str(int(s.move_speed)), pct.has(&"move_speed_percent"))
	_set_derived(&"damage_percent", "%+.0f%%" % s.damage_percent, s.damage_percent != 0.0)
	_set_derived(&"hp_drain", "%.0f%%" % s.hp_drain_percent, s.hp_drain_percent != 0.0)
	_set_derived(&"sp_drain", "%.0f%%" % s.sp_drain_percent, s.sp_drain_percent != 0.0)
	_equip_bonus_label.text = "สีเขียว = มีผลจากของสวมใส่/การ์ด"


func _set_derived(key: StringName, text: String, boosted: bool) -> void:
	var l: Label = _derived.get(key, null)
	if l == null:
		return
	l.text = text
	l.add_theme_color_override("font_color", C_GOOD if boosted else C_TEXT)


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
	var faces_left = p.get("sprite_faces_left")
	if faces_left != null:
		_preview.flip_h = bool(faces_left)
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
