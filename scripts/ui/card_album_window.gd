## CardAlbumWindow — อัลบั้มการ์ดมอนสเตอร์ (กด V)
##
## แท็บ "อัลบั้ม"  : โชว์การ์ดทุกใบในเกม ใบที่ยังไม่ได้จะเป็นเงาดำ
## แท็บ "จัดการ"   : ใส่การ์ดลงอุปกรณ์ / ถอดการ์ดออก
class_name CardAlbumWindow
extends GameWindow

const COLUMNS := 5
const MINI_SIZE := Vector2(84, 96)

var _tab_album: Button
var _tab_manage: Button
var _album_page: HBoxContainer
var _manage_page: VBoxContainer

var _grid: GridContainer
var _card_view: CardView
var _progress: Label
var _socket_box: VBoxContainer
var _manage_list: VBoxContainer

var _selected: StringName = &""
var _mode_album := true


func _ready() -> void:
	window_title = "อัลบั้มการ์ดมอนสเตอร์"
	super._ready()
	custom_minimum_size = Vector2(640, 0)
	Events.inventory_changed.connect(refresh)
	Events.equipment_changed.connect(refresh)


func _build_content() -> void:
	# ---------- แท็บ ----------
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	content.add_child(tabs)

	_tab_album = UITheme.make_button("อัลบั้ม", 110)
	_tab_album.pressed.connect(func(): _set_mode(true))
	tabs.add_child(_tab_album)

	_tab_manage = UITheme.make_button("จัดการการ์ด", 130)
	_tab_manage.pressed.connect(func(): _set_mode(false))
	tabs.add_child(_tab_manage)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)

	_progress = UITheme.make_label("", 14, UITheme.ACCENT)
	tabs.add_child(_progress)

	content.add_child(UITheme.separator())

	# ---------- หน้าอัลบั้ม ----------
	_album_page = HBoxContainer.new()
	_album_page.add_theme_constant_override("separation", 10)
	content.add_child(_album_page)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_album_page.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	_album_page.add_child(side)

	_card_view = CardView.new()
	side.add_child(_card_view)

	_socket_box = VBoxContainer.new()
	_socket_box.add_theme_constant_override("separation", 4)
	side.add_child(_socket_box)

	# ---------- หน้าจัดการ ----------
	_manage_page = VBoxContainer.new()
	_manage_page.add_theme_constant_override("separation", 6)
	_manage_page.hide()
	content.add_child(_manage_page)

	_manage_page.add_child(UITheme.make_label(
		"อุปกรณ์ที่ใส่การ์ดอยู่ — กด [ถอด] เพื่อเอาการ์ดคืนเข้ากระเป๋า", 12, UITheme.TEXT_DIM))

	var mscroll := ScrollContainer.new()
	mscroll.custom_minimum_size.y = 330
	mscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_manage_page.add_child(mscroll)

	_manage_list = VBoxContainer.new()
	_manage_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_manage_list.add_theme_constant_override("separation", 4)
	mscroll.add_child(_manage_list)


func _set_mode(album: bool) -> void:
	_mode_album = album
	_album_page.visible = album
	_manage_page.visible = not album
	refresh()


# =========================================================
func refresh() -> void:
	if _grid == null or not visible:
		return

	var all := GameData.all_cards()
	_progress.text = "เก็บได้ %d / %d ใบ" % [PlayerState.cards_collected(), all.size()]
	_tab_album.add_theme_color_override("font_color", UITheme.ACCENT if _mode_album else UITheme.TEXT_DIM)
	_tab_manage.add_theme_color_override("font_color", UITheme.TEXT_DIM if _mode_album else UITheme.ACCENT)

	if _mode_album:
		_build_album(all)
	else:
		_build_manage()


func _build_album(all: Array[CardData]) -> void:
	GameWindow.clear_container(_grid)

	if all.is_empty():
		_grid.add_child(UITheme.make_label("ยังไม่มีการ์ดในเกม", 13, UITheme.TEXT_DIM))
		return

	for card in all:
		var owned := PlayerState.owns_card(card.id)

		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)

		var btn := Button.new()
		btn.custom_minimum_size = MINI_SIZE
		btn.focus_mode = Control.FOCUS_NONE
		btn.tooltip_text = card.display_name if owned else "ยังไม่เก็บได้"
		btn.modulate = Color.WHITE if owned else Color(0.22, 0.24, 0.32)

		var highlight := card.id == _selected
		btn.add_theme_stylebox_override("normal", UITheme.slot_style(highlight))
		btn.add_theme_stylebox_override("hover", UITheme.slot_style(true))
		btn.add_theme_stylebox_override("pressed", UITheme.slot_style(true))

		var cid := card.id
		btn.pressed.connect(func(): _select(cid))
		cell.add_child(btn)
		# รูปการ์ดจัดกึ่งกลางช่องเสมอ
		var art: TextureRect = UITheme.make_slot_icon(btn, 4.0)[0]
		art.texture = CardView.card_texture(card)
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

		var name_label := UITheme.make_label(
			card.display_name.replace("การ์ด", "").strip_edges() if owned else "???",
			10, card.rarity_color() if owned else UITheme.TEXT_DIM)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.clip_text = true
		name_label.custom_minimum_size.x = MINI_SIZE.x
		cell.add_child(name_label)

		_grid.add_child(cell)

	_update_side()


func _select(card_id: StringName) -> void:
	_selected = card_id
	refresh()


func _update_side() -> void:
	var card := GameData.get_card(_selected)
	var owned := card != null and PlayerState.owns_card(card.id)
	_card_view.show_card(card, owned)

	GameWindow.clear_container(_socket_box)
	if card == null or not owned:
		return

	var in_bag := PlayerState.inventory.count_of(card.id)
	if in_bag <= 0:
		_socket_box.add_child(UITheme.make_label("(ใบนี้ใส่ในอุปกรณ์อยู่แล้ว)", 11, UITheme.TEXT_DIM))
		return

	var targets := PlayerState.sockets_for_card(card.id)
	if targets.is_empty():
		_socket_box.add_child(UITheme.make_label(
			"ไม่มี%sที่มีช่องว่าง" % card.slot_name(), 11, UITheme.BAD))
		return

	_socket_box.add_child(UITheme.make_label("ใส่ลงใน:", 12, UITheme.TEXT_DIM))
	for t in targets:
		var btn := UITheme.make_button(t.label)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var inst: ItemInstance = t.instance
		var cid := card.id
		btn.pressed.connect(func(): PlayerState.socket_card(cid, inst))
		_socket_box.add_child(btn)


# =========================================================
func _build_manage() -> void:
	GameWindow.clear_container(_manage_list)
	var found := false

	for slot in PlayerState.equipment.slots.keys():
		var inst: ItemInstance = PlayerState.equipment.get_item(slot)
		if inst != null and not inst.cards.is_empty():
			_add_manage_row(inst, "%s (สวมอยู่)" % Equipment.SLOT_NAMES[slot])
			found = true

	for i in range(PlayerState.inventory.size):
		var inst2 := PlayerState.inventory.get_slot(i)
		if inst2 != null and not inst2.cards.is_empty():
			_add_manage_row(inst2, "ในกระเป๋า")
			found = true

	if not found:
		_manage_list.add_child(UITheme.make_label(
			"ยังไม่ได้ใส่การ์ดในอุปกรณ์ชิ้นไหนเลย\nไปที่แท็บอัลบั้ม เลือกการ์ดที่มี แล้วกดปุ่มใส่ได้เลย",
			13, UITheme.TEXT_DIM))


func _add_manage_row(inst: ItemInstance, where: String) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.PANEL_LIGHT, UITheme.BORDER, 4))
	_manage_list.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)

	var head := HBoxContainer.new()
	var title := UITheme.make_label(inst.display_name(), 14, UITheme.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UITheme.make_label(where, 11, UITheme.TEXT_DIM))
	box.add_child(head)

	for i in range(inst.cards.size()):
		var card := GameData.get_card(inst.cards[i])
		if card == null:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var icon := TextureRect.new()
		icon.texture = CardView.card_texture(card)
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)

		var info := UITheme.make_label(
			"%s — %s" % [card.display_name, card.describe().replace("\n", ", ")],
			12, UITheme.TEXT)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(info)

		var btn := UITheme.make_button("ถอด", 60)
		var target := inst
		var index := i
		btn.pressed.connect(func(): PlayerState.unsocket_card(target, index))
		row.add_child(btn)

		box.add_child(row)
