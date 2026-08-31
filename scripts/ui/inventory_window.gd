## InventoryWindow — ช่องเก็บของ (กด I)
class_name InventoryWindow
extends GameWindow

const COLUMNS := 8
const SLOT_SIZE := Vector2(52, 52)

var _grid: GridContainer
var _slot_buttons: Array[Button] = []
var _slot_icons: Array[TextureRect] = []
var _slot_counts: Array[Label] = []
var _info_name: Label
var _info_desc: Label
var _use_button: Button
var _drop_button: Button
## ปุ่มตั้งยาลงช่องด่วน (โผล่เฉพาะตอนเลือกของกิน)
var _potion_row: HBoxContainer
var _set_q_button: Button
var _set_r_button: Button
var _capacity_label: Label
var _zeny_label: Label

var _selected := -1
## โหมดขาย: กดของแล้วขายทันที (ร้านค้าเป็นคนเปิด)
var sell_mode := false


func _ready() -> void:
	window_title = "กระเป๋า"
	super._ready()
	custom_minimum_size = Vector2(470, 0)
	Events.inventory_changed.connect(refresh)
	Events.zeny_changed.connect(func(_z): refresh())


func _build_content() -> void:
	var top := HBoxContainer.new()
	_capacity_label = UITheme.make_label("0 / 40", 13, UITheme.TEXT_DIM)
	_capacity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_capacity_label)
	_zeny_label = UITheme.make_label("0 z", 14, Color("#ffe9a0"))
	top.add_child(_zeny_label)
	content.add_child(top)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	content.add_child(_grid)

	for i in range(PlayerState.INVENTORY_SIZE):
		var btn := Button.new()
		btn.custom_minimum_size = SLOT_SIZE
		btn.focus_mode = Control.FOCUS_NONE
		btn.clip_text = true
		btn.add_theme_font_size_override("font_size", 11)
		btn.add_theme_color_override("font_color", UITheme.TEXT)
		btn.add_theme_stylebox_override("normal", UITheme.slot_style())
		btn.add_theme_stylebox_override("hover", UITheme.slot_style(true))
		btn.add_theme_stylebox_override("pressed", UITheme.slot_style(true))
		var index := i
		btn.pressed.connect(func(): _on_slot_pressed(index))
		_grid.add_child(btn)
		_slot_buttons.append(btn)
		# รูปไอเทมจัดกึ่งกลางช่องเสมอ (ไม่ใช้ btn.icon เพราะ Godot วางชิดมุม)
		var parts := UITheme.make_slot_icon(btn)
		_slot_icons.append(parts[0])
		_slot_counts.append(parts[1])

	content.add_child(UITheme.separator())

	_info_name = UITheme.make_label("— เลือกไอเทม —", 15, UITheme.ACCENT)
	content.add_child(_info_name)

	_info_desc = UITheme.make_label("", 12, UITheme.TEXT_DIM)
	_info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_desc.custom_minimum_size.y = 56
	content.add_child(_info_desc)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	content.add_child(actions)

	_use_button = UITheme.make_button("ใช้ / สวมใส่", 110)
	_use_button.pressed.connect(_use_selected)
	actions.add_child(_use_button)

	_drop_button = UITheme.make_button("ทิ้ง", 60)
	_drop_button.pressed.connect(_drop_selected)
	actions.add_child(_drop_button)

	var sort_btn := UITheme.make_button("เรียงของ", 80)
	sort_btn.pressed.connect(func(): PlayerState.inventory.sort_items())
	actions.add_child(sort_btn)

	var card_btn := UITheme.make_button("อัลบั้มการ์ด", 100)
	card_btn.pressed.connect(func(): UI.open(&"cards"))
	actions.add_child(card_btn)

	# ★ แถวตั้งช่องยาด่วน ★ โผล่เฉพาะตอนเลือกของกิน
	_potion_row = HBoxContainer.new()
	_potion_row.add_theme_constant_override("separation", 6)
	content.add_child(_potion_row)

	_potion_row.add_child(UITheme.make_label("ตั้งเป็นยาด่วน:", 12, UITheme.TEXT_DIM))

	_set_q_button = UITheme.make_button("ช่อง Q (ยาเลือด)", 130)
	_set_q_button.pressed.connect(func(): _assign_potion(0))
	_potion_row.add_child(_set_q_button)

	_set_r_button = UITheme.make_button("ช่อง R (ยามานา)", 130)
	_set_r_button.pressed.connect(func(): _assign_potion(1))
	_potion_row.add_child(_set_r_button)

	_potion_row.hide()


# =========================================================
func _on_slot_pressed(index: int) -> void:
	if sell_mode:
		PlayerState.sell_slot(index, 1)
		refresh()
		return
	_selected = index
	refresh()
	# ★ เด้งกล่องรายละเอียดข้างหน้าต่างกระเป๋า ★
	var inst := PlayerState.inventory.get_slot(index)
	if inst != null:
		UI.show_item(inst, self)
	else:
		UI.hide_item_popup()


## เอาของกินที่เลือกอยู่ไปใส่ช่องยาด่วน
func _assign_potion(slot: int) -> void:
	if _selected < 0:
		return
	var inst := PlayerState.inventory.get_slot(_selected)
	if inst == null:
		return
	var d := inst.data()
	if d == null or d.type != ItemData.Type.CONSUMABLE:
		Events.say("ตั้งได้เฉพาะของกิน/ยา")
		return
	PlayerState.set_item_hotkey(slot, inst.item_id)
	Events.say("ตั้ง %s ไว้ช่อง %s แล้ว" % [d.display_name, "Q" if slot == 0 else "R"])
	refresh()


## อัพเดตแถวปุ่มตั้งช่องยาตามของที่เลือกอยู่
func _refresh_potion_row() -> void:
	if _potion_row == null:
		return
	var inst := PlayerState.inventory.get_slot(_selected) if _selected >= 0 else null
	var d := inst.data() if inst != null else null
	var usable: bool = d != null and d.type == ItemData.Type.CONSUMABLE
	_potion_row.visible = usable
	if not usable:
		return
	# ของชิ้นนี้อยู่ช่องไหนอยู่แล้ว ให้ปุ่มนั้นบอกว่า "ตั้งอยู่"
	for i in range(PlayerState.ITEM_HOTKEY_COUNT):
		var btn: Button = _set_q_button if i == 0 else _set_r_button
		var base: String = "ช่อง Q (ยาเลือด)" if i == 0 else "ช่อง R (ยามานา)"
		var on: bool = PlayerState.item_hotkey_at(i) == inst.item_id
		btn.text = ("★ " + base) if on else base
		btn.add_theme_color_override("font_color",
			UITheme.ACCENT if on else UITheme.TEXT)


func _use_selected() -> void:
	if _selected < 0:
		return
	PlayerState.use_item(_selected)
	refresh()


func _drop_selected() -> void:
	if _selected < 0:
		return
	var inst := PlayerState.inventory.get_slot(_selected)
	if inst == null:
		return
	var d := inst.data()
	if d != null and not d.can_drop:
		Events.say("ไอเทมนี้ทิ้งไม่ได้")
		return
	PlayerState.inventory.take_from_slot(_selected, inst.count)
	Events.say("ทิ้ง %s แล้ว" % inst.display_name())
	refresh()


# =========================================================
func refresh() -> void:
	if _grid == null:
		return

	var inv := PlayerState.inventory
	_capacity_label.text = "ช่องที่ใช้: %d / %d" % [inv.used_slots(), inv.size]
	_zeny_label.text = "%s z" % HUD._comma(PlayerState.zeny)
	set_title("กระเป๋า" + ("  [โหมดขาย — คลิกเพื่อขาย]" if sell_mode else ""))

	for i in range(_slot_buttons.size()):
		var btn := _slot_buttons[i]
		var inst := inv.get_slot(i)

		var art: TextureRect = _slot_icons[i]
		var cnt: Label = _slot_counts[i]

		if inst == null:
			btn.text = ""
			btn.icon = null
			art.texture = null
			cnt.text = ""
			btn.tooltip_text = ""
		else:
			var d := inst.data()
			art.texture = d.icon if d != null and d.icon != null else null
			# การ์ดที่ยังไม่ได้ใส่ไอคอนเอง ใช้ภาพการ์ด (กรอบ+รูปมอน) แทน
			if art.texture == null and d != null and d.is_card():
				art.texture = CardView.card_texture(d as CardData)
				art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			btn.icon = null
			btn.text = "" if art.texture != null else _short_name(inst)
			cnt.text = "x%d" % inst.count if inst.count > 1 else ""
			if art.texture == null and inst.count > 1:
				btn.text = "%s\nx%d" % [btn.text, inst.count]
				cnt.text = ""
			btn.tooltip_text = _tooltip(inst)

		var style := UITheme.slot_style(i == _selected and not sell_mode)
		btn.add_theme_stylebox_override("normal", style)

	# ---------- ข้อมูลไอเทมที่เลือก ----------
	var sel := inv.get_slot(_selected) if _selected >= 0 else null
	if sel == null:
		_info_name.text = "— เลือกไอเทม —"
		_info_desc.text = ""
		_use_button.disabled = true
		_drop_button.disabled = true
	else:
		_info_name.text = sel.display_name()
		_info_desc.text = _tooltip(sel)
		_use_button.disabled = false
		_drop_button.disabled = false
		var sd := sel.data()
		if sd != null and sd.is_card():
			_use_button.text = "เปิดอัลบั้มการ์ด"
		elif sd != null and sd.is_equipment():
			_use_button.text = "สวมใส่"
		else:
			_use_button.text = "ใช้"

	_refresh_potion_row()

func _short_name(inst: ItemInstance) -> String:
	var d := inst.data()
	var n: String = d.display_name if d != null else String(inst.item_id)
	return n.substr(0, 8)


func _tooltip(inst: ItemInstance) -> String:
	var d := inst.data()
	if d == null:
		return String(inst.item_id)

	var lines: Array[String] = [inst.display_name()]
	if d.description != "":
		lines.append(d.description)

	var stats: Array[String] = []
	if d.type == ItemData.Type.WEAPON:
		stats.append("ATK %d" % inst.total_atk())
	elif inst.total_atk() != 0:
		stats.append("ATK %+d" % inst.total_atk())
	if inst.total_def() != 0:
		stats.append("DEF %+d" % inst.total_def())
	if d.matk != 0: stats.append("MATK %+d" % d.matk)
	if d.mdef != 0: stats.append("MDEF %+d" % d.mdef)
	if d.hit != 0: stats.append("HIT %+d" % d.hit)
	if d.flee != 0: stats.append("FLEE %+d" % d.flee)
	if d.crit != 0: stats.append("CRIT %+d" % d.crit)
	if d.max_hp != 0: stats.append("MaxHP %+d" % d.max_hp)
	if d.max_sp != 0: stats.append("MaxSP %+d" % d.max_sp)
	if d.aspd_percent != 0.0: stats.append("ASPD %+.0f%%" % d.aspd_percent)
	if d.bonus_str != 0: stats.append("STR %+d" % d.bonus_str)
	if d.bonus_agi != 0: stats.append("AGI %+d" % d.bonus_agi)
	if d.bonus_vit != 0: stats.append("VIT %+d" % d.bonus_vit)
	if d.bonus_int != 0: stats.append("INT %+d" % d.bonus_int)
	if d.bonus_dex != 0: stats.append("DEX %+d" % d.bonus_dex)
	if d.bonus_luk != 0: stats.append("LUK %+d" % d.bonus_luk)
	if d.heal_hp != 0 or d.heal_hp_percent != 0.0:
		stats.append("ฟื้น HP %d (+%.0f%%)" % [d.heal_hp, d.heal_hp_percent])
	if d.heal_sp != 0 or d.heal_sp_percent != 0.0:
		stats.append("ฟื้น SP %d (+%.0f%%)" % [d.heal_sp, d.heal_sp_percent])

	if not stats.is_empty():
		lines.append("  ".join(stats))

	# ---------- ช่องใส่การ์ด ----------
	if inst.card_slots() > 0:
		lines.append("ช่องการ์ด: %d/%d" % [inst.cards.size(), inst.card_slots()])
		for card in inst.card_list():
			lines.append("  ◆ %s — %s" % [card.display_name, card.describe().replace("\n", ", ")])

	# ---------- ถ้าเป็นการ์ด ----------
	if d is CardData:
		var c := d as CardData
		lines.append("ใส่ใน%s" % c.slot_name())
		lines.append(c.describe())

	lines.append("ราคาขาย %d z" % d.sell_price)
	return "\n".join(lines)
