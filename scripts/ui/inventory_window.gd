## InventoryWindow — ช่องเก็บของ (กด I) — โฉมใหม่รอบ 38 ตามตัวอย่างของผู้ใช้
##
## ★ หน้าตาแบบ RO: แท็บ 3 หมวด + ช่องค้นหา + ปุ่มเรียง + กริดช่อง + แถบเงินล่างสุด ★
##   แท็บ 1 ของใช้ (ยา/ของกิน) · แท็บ 2 สวมใส่ (อาวุธ/เกราะ) · แท็บ 3 อื่น ๆ (วัตถุดิบ/เควส/การ์ด)
##   เลขจำนวนสีแดงมุมขวาล่างของช่อง เหมือนภาพตัวอย่าง
## ★ แก้สีหน้าต่างนี้ ★ ที่ค่าคงที่ C_XXX ข้างล่าง (หน้าต่างอื่นยังใช้ธีมเดิม)
class_name InventoryWindow
extends GameWindow

const COLUMNS := 8
const SLOT_SIZE := Vector2(50, 50)

# ---- โทนสีครีม-ชมพูแบบตัวอย่าง ----
const C_BG := Color(0.957, 0.918, 0.824, 0.88)   # พื้นหน้าต่าง ครีม โปร่งแสงเล็กน้อย (รอบ 39)
const C_BORDER := Color("#8a6f4d")      # ขอบน้ำตาล
const C_BAR := Color(0.99, 0.975, 0.945, 0.92)   # แถบหัวเรื่อง ขาว (รอบ 39 — เดิมชมพู)
const C_SLOT := Color(0.902, 0.847, 0.722, 0.72) # ช่องว่าง (โปร่งแสงมองทะลุนิด ๆ)
const C_SLOT_EDGE := Color("#b39a6f")
const C_SLOT_SEL := Color("#fff3c4")    # ช่องที่เลือก
const C_TEXT := Color("#4a3a2a")        # ตัวหนังสือเข้ม
const C_TEXT_DIM := Color("#8a795f")
const C_COUNT := Color("#e0314e")       # เลขจำนวน สีแดง
const C_GOLD := Color("#b8860b")

const TAB_NAMES := ["ของใช้", "สวมใส่", "อื่น ๆ"]

var _tab := 0
var _search := ""
var _tab_buttons: Array[Button] = []
var _search_edit: LineEdit
var _grid: GridContainer
var _slot_buttons: Array[Button] = []
var _slot_icons: Array[TextureRect] = []
var _slot_counts: Array[Label] = []
## ช่องที่โชว์ตำแหน่ง i ชี้ไปช่องจริงไหนในกระเป๋า (-1 = ว่าง)
var _display_to_slot: Array[int] = []
var _use_button: Button
var _drop_button: Button
var _potion_row: HBoxContainer
var _set_q_button: Button
var _set_r_button: Button
var _capacity_label: Label
var _zeny_label: Label

var _selected := -1          # ช่องจริงในกระเป๋า
## โหมดขาย: กดของแล้วขายทันที (ร้านค้าเป็นคนเปิด)
var sell_mode := false


func _ready() -> void:
	window_title = "กระเป๋า"
	super._ready()
	# ---- เปลี่ยนโทนหน้าต่างนี้เป็นครีมแบบตัวอย่าง ----
	add_theme_stylebox_override("panel", _style(C_BG, C_BORDER, 12))
	var root := get_child(0)
	var bar := root.get_child(0) as PanelContainer
	bar.add_theme_stylebox_override("panel", _style(C_BAR, C_BORDER, 8))
	title_label.add_theme_color_override("font_color", Color("#5a4a33"))
	Events.inventory_changed.connect(refresh)
	Events.zeny_changed.connect(func(_z): refresh())


static func _style(bg: Color, border: Color, radius: int = 6, margin: float = 6.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s


func _slot_box(selected: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = C_SLOT_SEL if selected else C_SLOT
	s.border_color = Color("#d19a2f") if selected else C_SLOT_EDGE
	s.set_border_width_all(2 if selected else 1)
	s.set_corner_radius_all(6)
	return s


func _cream_button(text: String, min_width: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if min_width > 0:
		b.custom_minimum_size.x = min_width
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", C_TEXT)
	b.add_theme_color_override("font_hover_color", C_TEXT)
	b.add_theme_color_override("font_pressed_color", C_TEXT)
	b.add_theme_stylebox_override("normal", _style(Color("#efdfbc"), C_SLOT_EDGE, 8, 4))
	b.add_theme_stylebox_override("hover", _style(Color("#f8ecd0"), C_BORDER, 8, 4))
	b.add_theme_stylebox_override("pressed", _style(C_SLOT_SEL, Color("#d19a2f"), 8, 4))
	return b


func _label(text: String, size: int = 14, color: Color = C_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


# =========================================================
func _build_content() -> void:
	# ---------- แถวแท็บ 3 หมวด + ปุ่มเรียง ----------
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 5)
	content.add_child(tabs)
	for i in range(TAB_NAMES.size()):
		var t := _cream_button(TAB_NAMES[i], 86)
		var index := i
		t.pressed.connect(func():
			_tab = index
			_selected = -1
			UI.hide_item_popup()
			refresh())
		tabs.add_child(t)
		_tab_buttons.append(t)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	var sort_btn := _cream_button("เรียง", 62)
	sort_btn.tooltip_text = "เรียงของในกระเป๋า"
	sort_btn.pressed.connect(func():
		PlayerState.inventory.sort_items()
		refresh())
	tabs.add_child(sort_btn)

	# ---------- แถวค้นหา ----------
	var find_row := HBoxContainer.new()
	find_row.add_theme_constant_override("separation", 5)
	content.add_child(find_row)
	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "พิมพ์ชื่อไอเทม..."
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.add_theme_font_size_override("font_size", 14)
	_search_edit.add_theme_color_override("font_color", C_TEXT)
	_search_edit.add_theme_stylebox_override("normal", _style(Color("#e2d3b0"), C_SLOT_EDGE, 8, 5))
	_search_edit.add_theme_stylebox_override("focus", _style(Color("#f8ecd0"), C_BORDER, 8, 5))
	_search_edit.text_changed.connect(func(t: String):
		_search = t.strip_edges()
		refresh())
	_search_edit.text_submitted.connect(func(_t): refresh())
	find_row.add_child(_search_edit)
	var find_btn := _cream_button("ค้นหา", 66)
	find_btn.pressed.connect(func():
		_search = _search_edit.text.strip_edges()
		refresh())
	find_row.add_child(find_btn)
	var clear_btn := _cream_button("⟳", 34)
	clear_btn.tooltip_text = "ล้างคำค้น"
	clear_btn.pressed.connect(func():
		_search_edit.text = ""
		_search = ""
		refresh())
	find_row.add_child(clear_btn)

	# ---------- กริดช่องไอเทม ----------
	var grid_panel := PanelContainer.new()
	grid_panel.add_theme_stylebox_override("panel", _style(Color(0.925, 0.875, 0.753, 0.55), C_SLOT_EDGE, 10, 6))
	content.add_child(grid_panel)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	grid_panel.add_child(_grid)

	for i in range(PlayerState.INVENTORY_SIZE):
		var btn := Button.new()
		btn.custom_minimum_size = SLOT_SIZE
		btn.focus_mode = Control.FOCUS_NONE
		btn.clip_text = true
		btn.add_theme_font_size_override("font_size", 10)
		btn.add_theme_color_override("font_color", C_TEXT)
		btn.add_theme_stylebox_override("normal", _slot_box())
		btn.add_theme_stylebox_override("hover", _slot_box(true))
		btn.add_theme_stylebox_override("pressed", _slot_box(true))
		var index := i
		btn.pressed.connect(func(): _on_slot_pressed(index))
		_grid.add_child(btn)
		_slot_buttons.append(btn)
		var parts := UITheme.make_slot_icon(btn)
		_slot_icons.append(parts[0])
		var cnt: Label = parts[1]
		# ★ เลขจำนวนสีแดง มุมขวาล่าง เหมือนตัวอย่าง ★
		cnt.add_theme_font_size_override("font_size", 12)
		cnt.add_theme_color_override("font_color", C_COUNT)
		cnt.add_theme_color_override("font_outline_color", Color("#fff6e0"))
		cnt.add_theme_constant_override("outline_size", 4)
		_slot_counts.append(cnt)
		_display_to_slot.append(-1)

	# (รอบ 39: เอากล่องชื่อ+คำอธิบายในหน้าต่างออก — รายละเอียดโชว์ที่กล่องลอยฝั่งซ้ายที่เดียว)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	content.add_child(actions)
	_use_button = _cream_button("ใช้ / สวมใส่", 110)
	_use_button.pressed.connect(_use_selected)
	actions.add_child(_use_button)
	_drop_button = _cream_button("ทิ้ง", 56)
	_drop_button.pressed.connect(_drop_selected)
	actions.add_child(_drop_button)
	var card_btn := _cream_button("อัลบั้มการ์ด", 100)
	card_btn.pressed.connect(func(): UI.open(&"cards"))
	actions.add_child(card_btn)

	# ---------- แถวตั้งช่องยาด่วน (โผล่เฉพาะของกิน) ----------
	_potion_row = HBoxContainer.new()
	_potion_row.add_theme_constant_override("separation", 6)
	content.add_child(_potion_row)
	_potion_row.add_child(_label("ตั้งเป็นยาด่วน:", 12, C_TEXT_DIM))
	_set_q_button = _cream_button("ช่อง Q (ยาเลือด)", 130)
	_set_q_button.pressed.connect(func(): _assign_potion(0))
	_potion_row.add_child(_set_q_button)
	_set_r_button = _cream_button("ช่อง R (ยามานา)", 130)
	_set_r_button.pressed.connect(func(): _assign_potion(1))
	_potion_row.add_child(_set_r_button)
	_potion_row.hide()

	# ---------- แถบเงินล่างสุด (แบบตัวอย่าง) ----------
	var money_bar := PanelContainer.new()
	money_bar.add_theme_stylebox_override("panel", _style(Color(0.937, 0.875, 0.737, 0.8), C_BORDER, 10, 5))
	content.add_child(money_bar)
	var money_box := HBoxContainer.new()
	money_box.add_theme_constant_override("separation", 8)
	money_bar.add_child(money_box)
	_capacity_label = _label("0 / 40", 12, C_TEXT_DIM)
	money_box.add_child(_capacity_label)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	money_box.add_child(sp2)
	money_box.add_child(_label("ซีนี", 14, C_GOLD))
	var zeny_panel := PanelContainer.new()
	zeny_panel.add_theme_stylebox_override("panel", _style(Color("#fff4d6"), C_GOLD, 8, 4))
	zeny_panel.custom_minimum_size.x = 150
	_zeny_label = _label("0", 15, Color("#7a5a10"))
	_zeny_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_zeny_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zeny_panel.add_child(_zeny_label)
	money_box.add_child(zeny_panel)


# =========================================================
## หมวดของไอเทม → แท็บไหน
static func _tab_of(d: ItemData) -> int:
	if d == null:
		return 2
	if d.type == ItemData.Type.CONSUMABLE:
		return 0
	if d.type == ItemData.Type.WEAPON or d.type == ItemData.Type.ARMOR:
		return 1
	return 2


func _on_slot_pressed(display_index: int) -> void:
	var slot: int = _display_to_slot[display_index]
	if slot < 0:
		# กดช่องว่าง = เลิกเลือก + ปิดกล่องรายละเอียด (พฤติกรรมเดิม)
		_selected = -1
		UI.hide_item_popup()
		refresh()
		return
	if sell_mode:
		PlayerState.sell_slot(slot, 1)
		refresh()
		return
	_selected = slot
	refresh()
	var inst := PlayerState.inventory.get_slot(slot)
	if inst != null:
		UI.show_item(inst, self)
	else:
		UI.hide_item_popup()


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


func _refresh_potion_row() -> void:
	if _potion_row == null:
		return
	var inst := PlayerState.inventory.get_slot(_selected) if _selected >= 0 else null
	var d := inst.data() if inst != null else null
	var usable: bool = d != null and d.type == ItemData.Type.CONSUMABLE
	_potion_row.visible = usable
	if not usable:
		return
	for i in range(PlayerState.ITEM_HOTKEY_COUNT):
		var btn: Button = _set_q_button if i == 0 else _set_r_button
		var base: String = "ช่อง Q (ยาเลือด)" if i == 0 else "ช่อง R (ยามานา)"
		var on: bool = PlayerState.item_hotkey_at(i) == inst.item_id
		btn.text = ("★ " + base) if on else base


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
	if d != null and d.type == ItemData.Type.QUEST:
		Events.say("ของสำคัญของเควส ทิ้งไม่ได้")
		return
	PlayerState.inventory.take_from_slot(_selected, inst.count)
	Events.say("ทิ้ง %s แล้ว" % inst.display_name())
	refresh()


# =========================================================
func refresh() -> void:
	if _grid == null:
		return

	var inv := PlayerState.inventory
	_capacity_label.text = "ช่องที่ใช้ %d / %d" % [inv.used_slots(), inv.size]
	_zeny_label.text = HUD._comma(PlayerState.zeny)
	set_title("กระเป๋า" + ("  [โหมดขาย — คลิกเพื่อขาย]" if sell_mode else ""))

	# ---------- ปุ่มแท็บ: อันที่เลือกอยู่สว่าง ----------
	for i in range(_tab_buttons.size()):
		var tb := _tab_buttons[i]
		tb.add_theme_stylebox_override("normal",
			_style(C_SLOT_SEL if i == _tab else Color("#efdfbc"),
				Color("#d19a2f") if i == _tab else C_SLOT_EDGE, 8, 4))

	# ---------- กรองช่องตามแท็บ + คำค้น ----------
	var shown: Array[int] = []
	var q := _search.to_lower()
	for slot in range(inv.size):
		var inst := inv.get_slot(slot)
		if inst == null:
			continue
		if _tab_of(inst.data()) != _tab:
			continue
		if q != "" and not inst.display_name().to_lower().contains(q):
			continue
		shown.append(slot)

	for i in range(_slot_buttons.size()):
		var btn := _slot_buttons[i]
		var art: TextureRect = _slot_icons[i]
		var cnt: Label = _slot_counts[i]
		var slot: int = shown[i] if i < shown.size() else -1
		_display_to_slot[i] = slot
		var inst := inv.get_slot(slot) if slot >= 0 else null

		if inst == null:
			btn.text = ""
			art.texture = null
			cnt.text = ""
			btn.tooltip_text = ""
			btn.add_theme_stylebox_override("normal", _slot_box())
			continue

		var d := inst.data()
		art.texture = d.icon if d != null and d.icon != null else null
		if art.texture == null and d != null and d.is_card():
			art.texture = CardView.card_texture(d as CardData)
			art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		btn.text = "" if art.texture != null else _short_name(inst)
		cnt.text = str(inst.count) if inst.count > 1 else ""
		btn.tooltip_text = _tooltip(inst)
		btn.add_theme_stylebox_override("normal", _slot_box(slot == _selected and not sell_mode))

	# ---------- ปุ่มตามไอเทมที่เลือก ----------
	var sel := inv.get_slot(_selected) if _selected >= 0 else null
	if sel == null or _tab_of(sel.data()) != _tab:
		_use_button.disabled = true
		_drop_button.disabled = true
	else:
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

	if inst.card_slots() > 0:
		lines.append("ช่องการ์ด: %d/%d" % [inst.cards.size(), inst.card_slots()])
		for card in inst.card_list():
			lines.append("  ◆ %s — %s" % [card.display_name, card.describe().replace("\n", ", ")])

	if d is CardData:
		var c := d as CardData
		lines.append("ใส่ใน%s" % c.slot_name())
		lines.append(c.describe())

	if d.sell_price > 0:
		lines.append("ราคาขาย %d z" % d.sell_price)
	elif d.type == ItemData.Type.QUEST:
		lines.append("ของสำคัญ — ขาย/ทิ้งไม่ได้")
	return "\n".join(lines)
