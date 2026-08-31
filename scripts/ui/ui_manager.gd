## UI — ตัวจัดการหน้าจอทั้งหมด (Autoload ชื่อ "UI")
## สร้าง HUD และหน้าต่างทุกบานด้วยโค้ด ไม่ต้องจัด Scene เอง
## หมายเหตุ: ไฟล์นี้ห้ามใส่ class_name เพราะจะชนกับชื่อ Autoload
extends Node

var layer: CanvasLayer
var hud: HUD
var confirm: ConfirmDialog
var card_popup: CardGetPopup
var item_popup: ItemInfoPopup
## ★ กล่องสนทนาแบบมีรูปตัวละคร ★
var dialogue: DialogueBox
## ★ ปุ่มจอสัมผัสสำหรับมือถือ ★
var touch: TouchControls
## ★ แผนที่ย่อมุมขวาบน ★
var minimap: Minimap
## ★ แถบปุ่มไอคอนใต้มินิแมพ ★
var menu_bar: IconMenuBar
## ★ หน้าจอตอนตาย (คำอวยพรจากธอร์ + ปุ่มเกิดใหม่) ★
var death_popup: DeathPopup
var windows: Dictionary = {}   # StringName -> GameWindow


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	layer = CanvasLayer.new()
	layer.name = "UILayer"
	layer.layer = 100
	add_child(layer)

	var root := Control.new()
	root.name = "UIRoot"
	# ★ ต้อง _and_offsets_ ★ ไม่งั้นกรอบยังกว้าง 0 (ดูหมายเหตุใน hud.gd)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# ---------- HUD ----------
	hud = HUD.new()
	hud.name = "HUD"
	root.add_child(hud)

	# ---------- ★ มินิแมพ + แถบปุ่มไอคอน (มุมขวาบน) ★ ----------
	# ใส่ก่อนหน้าต่าง จะได้อยู่หลังหน้าต่างเวลาเปิดทับกัน
	minimap = Minimap.new()
	root.add_child(minimap)

	menu_bar = IconMenuBar.new()
	menu_bar.minimap = minimap
	root.add_child(menu_bar)

	# ---------- หน้าต่างต่าง ๆ ----------
	_add_window(&"status", StatusWindow.new(), Vector2(60, 90))
	_add_window(&"inventory", InventoryWindow.new(), Vector2(420, 90))
	_add_window(&"equipment", EquipmentWindow.new(), Vector2(800, 80))
	# ★ ผังสกิลวางชิดซ้าย ★ เผื่อที่ให้กล่องรายละเอียดเด้งอยู่ข้างขวาได้ ไม่ต้องมาทับผัง
	_add_window(&"skills", SkillWindow.new(), Vector2(60, 110))
	_add_window(&"shop", ShopWindow.new(), Vector2(500, 70))
	_add_window(&"refine", RefineWindow.new(), Vector2(500, 70))
	_add_window(&"cards", CardAlbumWindow.new(), Vector2(300, 60))
	_add_window(&"system", SystemWindow.new(), Vector2(420, 140))
	_add_window(&"quests", QuestWindow.new(), Vector2(340, 100))

	# ---------- กล่องรายละเอียดไอเทม (เด้งข้างหน้าต่าง) ----------
	item_popup = ItemInfoPopup.new()
	item_popup.name = "ItemInfoPopup"
	layer.add_child(item_popup)

	# ---------- popup ได้การ์ดใบใหม่ ----------
	card_popup = CardGetPopup.new()
	card_popup.name = "CardGetPopup"
	layer.add_child(card_popup)

	# ---------- ★ ปุ่มจอสัมผัส (มือถือ) ★ ----------
	# อยู่ใต้กล่องสนทนา/หน้าต่าง แต่เหนือเกม
	touch = TouchControls.new()
	layer.add_child(touch)

	# ---------- ★ กล่องสนทนา ★ ----------
	# ใส่ที่ CanvasLayer โดยตรง จะได้อ้างขนาด "จอ" ตรง ๆ (กล่องกินเต็มจอ)
	dialogue = DialogueBox.new()
	dialogue.name = "DialogueBox"
	layer.add_child(dialogue)

	# ---------- ★ หน้าจอตอนตาย ★ ----------
	# ต้องอยู่เกือบบนสุด (ทับทุกอย่างยกเว้นกล่องยืนยัน)
	death_popup = DeathPopup.new()
	layer.add_child(death_popup)

	# ---------- กล่องยืนยัน ----------
	confirm = ConfirmDialog.new()
	confirm.name = "ConfirmDialog"
	# ใส่ไว้ที่ CanvasLayer โดยตรง (ไม่ใช่ใน UIRoot)
	# กล่องจะได้อ้างอิงขนาด "จอ" ตรง ๆ แล้วจัดตัวเองไว้กลางจอได้ถูกต้อง
	layer.add_child(confirm)

	Events.shop_opened.connect(_on_shop_opened)
	Events.refine_npc_opened.connect(_on_refine_opened)
	Events.toggle_window.connect(toggle)


func _add_window(id: StringName, window: GameWindow, pos: Vector2) -> void:
	window.name = String(id)
	window.position = pos
	window.hide()
	layer.get_node("UIRoot").add_child(window)
	windows[id] = window


# =========================================================
# ปุ่มลัด
# =========================================================
## ถามผู้เล่นแล้วรอคำตอบ — ใช้แบบ: var ok: bool = await UI.ask("หัวข้อ", "ข้อความ")
func ask(title: String, message: String, yes_text: String = "ตกลง", no_text: String = "ยกเลิก") -> bool:
	confirm.ask(title, message, yes_text, no_text)
	return await confirm.answered


## โชว์รายละเอียดไอเทมข้าง ๆ หน้าต่างที่กดมา
func show_item(inst: ItemInstance, anchor: Control = null, extra: String = "") -> void:
	if item_popup != null:
		item_popup.show_item(inst, anchor, extra)


## โชว์รายละเอียดจากแม่แบบไอเทม (ร้านค้า)
func show_item_data(d: ItemData, anchor: Control = null, extra: String = "") -> void:
	if item_popup != null:
		item_popup.show_data(d, anchor, extra)


## ★ เล่นบทสนทนา ★ ใช้แบบ: var pick: int = await UI.talk([{...}, {...}])
## รายละเอียดคีย์ของแต่ละบรรทัดดูที่หัวไฟล์ scripts/ui/dialogue_box.gd
func talk(script: Array) -> int:
	if dialogue == null:
		return -1
	return await dialogue.play(script)


## คุยประโยคเดียวจบ (ไม่มีตัวเลือก)
func say_as(speaker: String, text: String, portrait: Variant = null, side: int = 0) -> void:
	await talk([{"name": speaker, "text": text, "portrait": portrait, "side": side}])


## ★ โชว์กล่องรายละเอียดแบบกำหนดเอง (ใช้กับสกิล) ★ ใส่ปุ่มการกระทำมาด้วยได้
func show_info(title: String, art: Texture2D, body: String, anchor: Control = null,
		color: Color = UITheme.TEXT, actions: Array = []) -> void:
	if item_popup != null:
		item_popup.show_info(title, art, body, anchor, color, actions)


func hide_item_popup() -> void:
	if item_popup != null:
		item_popup.hide_popup()


## จุดที่คลิกทับหน้าต่าง/แผงบนจอหรือเปล่า
## ใช้กันไม่ให้ "คลิกซ้ายในหน้าต่างกระเป๋า" กลายเป็นการฟันดาบไปด้วย
func is_point_over_ui(point: Vector2) -> bool:
	if is_asking():
		return true
	# แตะปุ่มบนจอ = ไม่ใช่การสั่งตีมอน
	if touch != null and touch.is_over(point):
		return true
	for w: GameWindow in windows.values():
		if w.visible and w.get_global_rect().has_point(point):
			return true
	if item_popup != null and item_popup.visible \
			and item_popup.get_global_rect().has_point(point):
		return true
	# ★ มินิแมพ + แถบปุ่มไอคอน ★ คลิกตรงนี้ไม่ใช่การสั่งตีมอน
	for p in [minimap, menu_bar]:
		if p != null and p.visible and p.get_global_rect().has_point(point):
			return true
	if hud != null:
		for p in [hud.top_panel, hud.bottom_panel, hud.hotkey_panel]:
			if p != null and p.visible and p.get_global_rect().has_point(point):
				return true
	return false


func is_asking() -> bool:
	if death_popup != null and death_popup.is_open():
		return true
	if card_popup != null and card_popup.is_open():
		return true
	if dialogue != null and dialogue.is_open():
		return true
	return confirm != null and confirm.is_open()


func _unhandled_input(event: InputEvent) -> void:
	if is_asking():
		return
	if event.is_action_pressed("toggle_status"):
		toggle(&"status")
	elif event.is_action_pressed("toggle_inventory"):
		toggle(&"inventory")
	elif event.is_action_pressed("toggle_equipment"):
		toggle(&"equipment")
	elif event.is_action_pressed("toggle_skills"):
		toggle(&"skills")
	elif event.is_action_pressed("toggle_cards"):
		toggle(&"cards")
	elif event.is_action_pressed("toggle_menu"):
		toggle(&"system")
	elif event.is_action_pressed("toggle_quests"):
		toggle(&"quests")
	elif InputMap.has_action("toggle_minimap") and event.is_action_pressed("toggle_minimap"):
		if minimap != null:
			minimap.toggle()
	elif event.is_action_pressed("close_windows"):
		close_all()
	elif event.is_action_pressed("quick_save"):
		SaveManager.save_game(0)
		var sysw: GameWindow = windows.get(&"system", null)
		if sysw != null:
			sysw.refresh()
	elif event.is_action_pressed("quick_load"):
		if SaveManager.load_game(0):
			Game.reload_map()
	else:
		return
	get_viewport().set_input_as_handled()


func toggle(id: StringName) -> void:
	var w: GameWindow = windows.get(id, null)
	if w == null:
		return
	w.toggle()


func open(id: StringName) -> void:
	var w: GameWindow = windows.get(id, null)
	if w != null:
		w.show_window()


func close(id: StringName) -> void:
	var w: GameWindow = windows.get(id, null)
	if w != null:
		w.hide_window()


func close_all() -> void:
	hide_item_popup()
	for w: GameWindow in windows.values():
		w.hide_window()
	var inv := windows.get(&"inventory") as InventoryWindow
	if inv != null:
		inv.sell_mode = false


func is_any_window_open() -> bool:
	for w: GameWindow in windows.values():
		if w.visible:
			return true
	return false


# =========================================================
# NPC เรียกใช้
# =========================================================
func _on_shop_opened(item_ids: Array) -> void:
	var shop := windows.get(&"shop") as ShopWindow
	if shop == null:
		return
	shop.open_shop(item_ids)
	open(&"inventory")


func _on_refine_opened() -> void:
	open(&"refine")
