## RefineWindow — หน้าต่างตีบวก/อัพเกรดอุปกรณ์ (คุยกับ NPC ช่างตีเหล็ก)
## หน้าตาแบบเดียวกับร้านค้า: มีไอคอนไอเทม · ชื่อ · ระดับตีบวก · กดดูรายละเอียดได้
class_name RefineWindow
extends GameWindow

## ขนาดไอคอนไอเทมในรายการ
const ICON_SIZE := Vector2(30, 30)

var _list: VBoxContainer
var _info: Label
var _refine_button: Button
var _result: Label
var _zeny_label: Label
var _selected_source := ""   # "inv:<index>" หรือ "eq:<slot>"


func _ready() -> void:
	window_title = "ตีบวกอุปกรณ์"
	super._ready()
	custom_minimum_size = Vector2(440, 0)
	Events.inventory_changed.connect(refresh)
	Events.equipment_changed.connect(refresh)
	Events.zeny_changed.connect(func(_z): refresh())


func _build_content() -> void:
	var head := HBoxContainer.new()
	content.add_child(head)

	var title := UITheme.make_label("เลือกอุปกรณ์ที่จะตีบวก", 13, UITheme.TEXT_DIM)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)

	_zeny_label = UITheme.make_label("0 z", 15, Color("#ffe9a0"))
	head.add_child(_zeny_label)

	content.add_child(UITheme.separator())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 220
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)

	content.add_child(UITheme.separator())

	_info = UITheme.make_label("—", 13, UITheme.TEXT)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size.y = 92
	content.add_child(_info)

	_refine_button = UITheme.make_button("ตีบวก!", 120)
	_refine_button.disabled = true
	_refine_button.pressed.connect(_do_refine)
	content.add_child(_refine_button)

	_result = UITheme.make_label("", 14, UITheme.ACCENT)
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_result)


func _selected_instance() -> ItemInstance:
	if _selected_source.begins_with("inv:"):
		return PlayerState.inventory.get_slot(int(_selected_source.substr(4)))
	elif _selected_source.begins_with("eq:"):
		return PlayerState.equipment.get_item(int(_selected_source.substr(3)))
	return null


func _do_refine() -> void:
	var inst := _selected_instance()
	if inst == null:
		return

	var out := RefineSystem.try_refine(inst, PlayerState.inventory, PlayerState)
	_result.text = out.message
	_result.add_theme_color_override("font_color", UITheme.GOOD if out.success else UITheme.BAD)

	# ของแตก = เอาออกจากช่อง
	if out.get("broke", false):
		if _selected_source.begins_with("inv:"):
			PlayerState.inventory.set_slot(int(_selected_source.substr(4)), null)
		elif _selected_source.begins_with("eq:"):
			PlayerState.equipment.unequip(int(_selected_source.substr(3)))
		_selected_source = ""

	PlayerState.refresh()
	refresh()


func refresh() -> void:
	if _list == null or not visible:
		return

	_zeny_label.text = "%s z" % HUD._comma(PlayerState.zeny)
	GameWindow.clear_container(_list)

	# ---------- ของที่ใส่อยู่ ----------
	for slot in PlayerState.equipment.slots.keys():
		var eq_inst: ItemInstance = PlayerState.equipment.get_item(slot)
		if eq_inst == null or not RefineSystem.can_refine(eq_inst):
			continue
		_add_row(eq_inst, "eq:%d" % slot, "สวมอยู่")

	# ---------- ของในกระเป๋า ----------
	for i in range(PlayerState.inventory.size):
		var inst := PlayerState.inventory.get_slot(i)
		if inst == null or not RefineSystem.can_refine(inst):
			continue
		_add_row(inst, "inv:%d" % i, "")

	if _list.get_child_count() == 0:
		_list.add_child(UITheme.make_label("ไม่มีอุปกรณ์ที่ตีบวกได้", 13, UITheme.TEXT_DIM))

	_update_info()


## หนึ่งแถว = [ไอคอน] [ชื่อไอเทม (กดเพื่อเลือก)] [+ระดับตอนนี้]
func _add_row(inst: ItemInstance, source: String, tag: String) -> void:
	var selected := source == _selected_source

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.slot_style(selected))
	_list.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)

	var d := inst.data()

	# ---------- ★ ไอคอนไอเทม (แบบเดียวกับร้านค้า) ★ ----------
	var frame := PanelContainer.new()
	frame.custom_minimum_size = ICON_SIZE + Vector2(4, 4)
	frame.add_theme_stylebox_override("panel",
		UITheme.panel_style(Color("#0d1119"), UITheme.BORDER, 3))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(frame)

	var art := TextureRect.new()
	art.name = "RefineIcon"
	art.custom_minimum_size = ICON_SIZE
	art.texture = d.icon if d != null else null
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(art)

	# ---------- ชื่อไอเทม (กดแล้วเลือก + เปิดกล่องรายละเอียด) ----------
	var name_btn := Button.new()
	name_btn.name = "PickButton"
	name_btn.text = inst.display_name() + (("  (%s)" % tag) if tag != "" else "")
	name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_btn.flat = true
	name_btn.clip_text = true
	name_btn.focus_mode = Control.FOCUS_NONE
	name_btn.tooltip_text = "กดเพื่อเลือกและดูรายละเอียด"
	name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_btn.add_theme_font_size_override("font_size", 13)
	name_btn.add_theme_color_override("font_color",
		UITheme.ACCENT if selected else UITheme.TEXT)
	name_btn.add_theme_color_override("font_hover_color", UITheme.ACCENT)
	row.add_child(name_btn)

	# ---------- ระดับตีบวกตอนนี้ ----------
	var lv := UITheme.make_label("+%d" % inst.refine, 14,
		Color("#ffe9a0") if inst.refine > 0 else UITheme.TEXT_DIM)
	lv.custom_minimum_size.x = 44
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lv)

	var src := source
	var this_inst := inst
	name_btn.pressed.connect(func():
		_selected_source = src
		_result.text = ""
		UI.show_item(this_inst, self, "เลือกไว้ตีบวกแล้ว")
		refresh()
	)


func _update_info() -> void:
	var inst := _selected_instance()
	if inst == null:
		_info.text = "ยังไม่ได้เลือกอุปกรณ์"
		_refine_button.disabled = true
		return

	var p := RefineSystem.preview(inst)
	var ore_name := GameData.item_name(p.ore_id)
	var have := PlayerState.inventory.count_of(p.ore_id)

	var lines: Array[String] = []
	lines.append("%s   +%d → +%d" % [p.name, p.current_refine, p.next_refine])
	lines.append("โอกาสสำเร็จ: %.0f%%" % p.rate)
	lines.append("ค่าใช้จ่าย: %s z (มี %s z)" % [HUD._comma(p.zeny), HUD._comma(PlayerState.zeny)])
	lines.append("วัตถุดิบ: %s x%d (มี %d)" % [ore_name, p.ore_count, have])
	if p.atk_gain > 0:
		lines.append("สำเร็จแล้วได้ ATK +%d" % p.atk_gain)
	if p.def_gain > 0:
		lines.append("สำเร็จแล้วได้ DEF +%d" % p.def_gain)
	if p.can_downgrade:
		lines.append("⚠ ระดับนี้ถ้าพลาดจะลดลง 1 ขั้น")

	_info.text = "\n".join(lines)
	_refine_button.disabled = PlayerState.zeny < p.zeny or have < p.ore_count
