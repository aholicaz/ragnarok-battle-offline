## ShopWindow — ร้านค้า (เปิดโดยคุยกับ NPC ประเภท SHOP)
class_name ShopWindow
extends GameWindow

var _tab_buy: Button
var _tab_sell: Button
var _list: VBoxContainer
var _zeny_label: Label
var _mode_buy := true
var _shop_items: Array = []


func _ready() -> void:
	window_title = "ร้านค้า"
	super._ready()
	custom_minimum_size = Vector2(430, 0)
	Events.zeny_changed.connect(func(_z): refresh())
	Events.inventory_changed.connect(refresh)


func open_shop(item_ids: Array) -> void:
	_shop_items = item_ids
	_mode_buy = true
	show_window()


func _build_content() -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	content.add_child(top)

	_tab_buy = UITheme.make_button("ซื้อ", 80)
	_tab_buy.pressed.connect(func(): _set_mode(true))
	top.add_child(_tab_buy)

	_tab_sell = UITheme.make_button("ขาย", 80)
	_tab_sell.pressed.connect(func(): _set_mode(false))
	top.add_child(_tab_sell)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	_zeny_label = UITheme.make_label("0 z", 15, Color("#ffe9a0"))
	top.add_child(_zeny_label)

	content.add_child(UITheme.separator())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 300
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)


func _set_mode(buy: bool) -> void:
	_mode_buy = buy
	refresh()


func refresh() -> void:
	if _list == null or not visible:
		return

	_zeny_label.text = "%s z" % HUD._comma(PlayerState.zeny)
	_tab_buy.add_theme_color_override("font_color", UITheme.ACCENT if _mode_buy else UITheme.TEXT_DIM)
	_tab_sell.add_theme_color_override("font_color", UITheme.TEXT_DIM if _mode_buy else UITheme.ACCENT)

	GameWindow.clear_container(_list)

	if _mode_buy:
		_build_buy_list()
	else:
		_build_sell_list()


func _build_buy_list() -> void:
	for id in _shop_items:
		var d := GameData.get_item(StringName(id))
		if d == null:
			continue
		var row := _make_row(d.display_name, d.icon, "%d z" % d.buy_price, d.description)
		# กดที่ชื่อของ = ดูรายละเอียด
		var dd := d
		_bind_info(row, func(): UI.show_item_data(dd, self, "ราคาซื้อ : %d z" % dd.buy_price))

		var buy1 := UITheme.make_button("ซื้อ 1", 64)
		buy1.disabled = PlayerState.zeny < d.buy_price
		var iid := d.id
		buy1.pressed.connect(func(): PlayerState.buy(iid, 1))
		row.add_child(buy1)

		if d.is_stackable():
			var buy10 := UITheme.make_button("x10", 50)
			buy10.disabled = PlayerState.zeny < d.buy_price * 10
			buy10.pressed.connect(func(): PlayerState.buy(iid, 10))
			row.add_child(buy10)

		_list.add_child(row)


func _build_sell_list() -> void:
	var inv := PlayerState.inventory
	var any := false

	for i in range(inv.size):
		var inst := inv.get_slot(i)
		if inst == null:
			continue
		var d := inst.data()
		if d == null or d.type == ItemData.Type.QUEST:
			continue

		any = true
		var row := _make_row(
			"%s x%d" % [inst.display_name(), inst.count],
			d.icon,
			"%d z" % inst.sell_value(),
			d.description
		)
		# กดที่ชื่อของ = ดูรายละเอียด
		var this_inst := inst
		_bind_info(row, func(): UI.show_item(this_inst, self,
			"ราคาขาย : %d z" % this_inst.sell_value()))

		var index := i
		var sell1 := UITheme.make_button("ขาย 1", 64)
		sell1.pressed.connect(func(): PlayerState.sell_slot(index, 1))
		row.add_child(sell1)

		if inst.count > 1:
			var sell_all := UITheme.make_button("ทั้งหมด", 70)
			var amount := inst.count
			sell_all.pressed.connect(func(): PlayerState.sell_slot(index, amount))
			row.add_child(sell_all)

		_list.add_child(row)

	if not any:
		_list.add_child(UITheme.make_label("ไม่มีของให้ขาย", 13, UITheme.TEXT_DIM))


## ทำให้กดที่แถว (รูป/ชื่อ/ราคา) แล้วเปิดกล่องรายละเอียด
func _bind_info(row: HBoxContainer, action: Callable) -> void:
	var btn := row.get_node_or_null("InfoButton") as Button
	if btn != null:
		btn.pressed.connect(action)


func _make_row(title: String, icon: Texture2D, price: String, tooltip: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.tooltip_text = tooltip

	if icon != null:
		var tex := TextureRect.new()
		tex.texture = icon
		tex.custom_minimum_size = Vector2(28, 28)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(tex)

	var name_btn := Button.new()
	name_btn.name = "InfoButton"
	name_btn.text = title
	name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_btn.flat = true
	name_btn.clip_text = true
	name_btn.focus_mode = Control.FOCUS_NONE
	name_btn.tooltip_text = "กดเพื่อดูรายละเอียด"
	name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_btn.add_theme_font_size_override("font_size", 13)
	name_btn.add_theme_color_override("font_color", UITheme.TEXT)
	name_btn.add_theme_color_override("font_hover_color", UITheme.ACCENT)
	row.add_child(name_btn)

	var price_label := UITheme.make_label(price, 13, Color("#ffe9a0"))
	price_label.custom_minimum_size.x = 80
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(price_label)

	return row
