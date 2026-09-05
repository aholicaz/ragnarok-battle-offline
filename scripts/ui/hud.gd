## HUD — แถบสถานะบนจอ: HP / SP / EXP / เลเวล / ซีนี / ปุ่มสกิล / บัฟ
## สร้างทั้งหมดด้วยโค้ด ไม่ต้องจัด Scene เอง
class_name HUD
extends Control

var hp_bar: ProgressBar
var sp_bar: ProgressBar
var exp_bar: ProgressBar
var job_bar: ProgressBar
var hp_text: Label
var sp_text: Label
var exp_text: Label
var job_text: Label
var level_label: Label
var zeny_label: Label
var buff_box: HBoxContainer
var hotkey_box: HBoxContainer
var potion_button: Button        # ช่องยาเลือด (Q)
var sp_potion_button: Button     # ช่องยามานา (R)
var menu_button: Button
## แผงปุ่มลัด — แยกออกมาจากแผงหลอดเลือดแล้ว
var hotkey_panel: PanelContainer
var notice_label: Label
## กรอบบนซ้าย (หลอดเลือด + ปุ่มลัด) และแถบคำใบ้ด้านล่าง — ใช้เช็คว่าคลิกโดน UI หรือเปล่า
var top_panel: PanelContainer
var bottom_panel: PanelContainer

## ★ ขนาดช่องปุ่มลัด ★ เป็นสี่เหลี่ยมจัตุรัส อยากให้ใหญ่ขึ้นแก้เลขนี้
const HOTKEY_SIZE := Vector2(58, 58)
## ★ แผงปุ่มลัดอยู่ "ข้างขวา" ของแผงหลอดเลือด ★ ห่างกันกี่พิกเซล (ไม่ติดกัน)
const HOTKEY_GAP_X := 10.0
## ตำแหน่งสำรอง เผื่อคำนวณขนาดแผงหลอดเลือดไม่ได้
const HOTKEY_PANEL_POS := Vector2(320, 12)
## ที่เก็บตำแหน่งที่ผู้เล่นลากไว้ (แยกจากไฟล์เซฟ ใช้ร่วมกันทุกช่องเซฟ)
const LAYOUT_PATH := "user://ui_layout.cfg"

var _hotkey_buttons: Array[Button] = []
var _hotkey_icons: Array[TextureRect] = []
var _potion_icons: Array[TextureRect] = []
var _potion_counts: Array[Label] = []
var _notice_timer := 0.0
## ★ สถานะการลากแผงปุ่มลัด ★
var _dragging := false
var _drag_offset := Vector2.ZERO
var _drag_moved := false


func _ready() -> void:
	# ★ ต้อง _and_offsets_ ★ ไม่งั้นกรอบ HUD ยังกว้าง 0 อยู่
	# แล้วของที่จัดชิดล่าง/กึ่งกลาง (แถบคำใบ้ปุ่ม, ข้อความแจ้งเตือน) จะหลุดออกนอกจอ
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_top_left()
	_build_hotkeys()
	_build_bottom()
	_build_notice()

	Events.hp_changed.connect(_on_hp_changed)
	Events.sp_changed.connect(_on_sp_changed)
	Events.exp_changed.connect(_on_exp_changed)
	Events.job_exp_changed.connect(_on_job_exp_changed)
	Events.job_level_up.connect(func(_lv): _refresh_all())
	Events.level_up.connect(func(_lv): _refresh_all())
	Events.stats_changed.connect(_refresh_all)
	Events.zeny_changed.connect(_on_zeny_changed)
	Events.skills_changed.connect(_refresh_hotkeys)
	Events.inventory_changed.connect(_refresh_potions)
	Events.buff_changed.connect(_refresh_buffs)
	Events.notice.connect(show_notice)

	_refresh_all()
	_place_hotkey_panel()


# =========================================================
# มุมซ้ายบน: หลอดเลือด/พลัง/ประสบการณ์
# =========================================================
func _build_top_left() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style(Color("#161b28cc")))
	panel.position = Vector2(12, 12)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(panel)
	top_panel = panel

	# แถวใหญ่: [หลอดเลือด/พลัง/EXP]  [ปุ่มสกิล + ยา]  ← ชิดกันเลย
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.custom_minimum_size = Vector2(280, 0)
	row.add_child(box)

	# แถวบน: เลเวล + ซีนี
	var top := HBoxContainer.new()
	box.add_child(top)

	level_label = UITheme.make_label("Lv.1 นักดาบ", 16, UITheme.ACCENT)
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(level_label)

	zeny_label = UITheme.make_label("0 z", 14, Color("#ffe9a0"))
	top.add_child(zeny_label)

	# HP
	var hp_pair := _bar_row("HP", UITheme.HP, 18)
	hp_bar = hp_pair[0]
	hp_text = hp_pair[1]
	box.add_child(hp_pair[2])

	# SP
	var sp_pair := _bar_row("SP", UITheme.SP, 14)
	sp_bar = sp_pair[0]
	sp_text = sp_pair[1]
	box.add_child(sp_pair[2])

	# EXP
	var exp_pair := _bar_row("EXP", UITheme.EXP, 10)
	exp_bar = exp_pair[0]
	exp_text = exp_pair[1]
	box.add_child(exp_pair[2])

	# ★ JOB EXP — หลอดแยกจาก Base ★
	var job_pair := _bar_row("JOB", UITheme.JOB, 10)
	job_bar = job_pair[0]
	job_text = job_pair[1]
	box.add_child(job_pair[2])

	# บัฟที่ติดอยู่
	buff_box = HBoxContainer.new()
	buff_box.add_theme_constant_override("separation", 4)
	box.add_child(buff_box)




# =========================================================
# ★ แผงปุ่มลัด ★ — แผงของตัวเอง วางไว้ "ข้างขวา" ของแผงหลอดเลือด (ไม่ติดกัน)
#   [::] [1][2][3][4]   [Q ยาเลือด][R ยามานา]   [Tab เมนู]
# · ลากที่พื้นแผง (หรือที่จุด [::] ด้านซ้าย) เพื่อย้ายไปวางตรงไหนก็ได้
# · คลิกขวาบนแผง = คืนตำแหน่งเดิม
# · ตำแหน่งถูกจำไว้ในไฟล์ user://ui_layout.cfg
# ช่องยาเลือกยาเองได้จากหน้ากระเป๋า (เลือกไอเทม -> กด "ตั้งช่อง Q/R")
# =========================================================
func _build_hotkeys() -> void:
	hotkey_panel = PanelContainer.new()
	hotkey_panel.name = "HotkeyPanel"
	hotkey_panel.add_theme_stylebox_override("panel", UITheme.panel_style(Color("#161b28cc")))
	hotkey_panel.position = HOTKEY_PANEL_POS
	# ★ ต้องเป็น STOP ★ แผงต้องกินคลิกเองถึงจะลากได้ และตัวละครจะได้ไม่ตีตอนลาก
	hotkey_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	hotkey_panel.tooltip_text = "ลากเพื่อย้ายแถบปุ่มลัด · คลิกขวา = คืนตำแหน่งเดิม"
	hotkey_panel.gui_input.connect(_on_hotkey_panel_input)
	add_child(hotkey_panel)

	hotkey_box = HBoxContainer.new()
	hotkey_box.add_theme_constant_override("separation", 5)
	# ปล่อยให้คลิกทะลุไปโดนแผง (ปุ่มที่เป็นลูกยังกดได้ตามปกติ) เพื่อให้ลากพื้นที่ว่างได้
	hotkey_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hotkey_panel.add_child(hotkey_box)

	# ---------- ที่จับสำหรับลาก ----------
	hotkey_box.add_child(_make_grip())

	# ---------- สกิล 1-4 ----------
	for i in range(SkillBook.HOTKEY_COUNT):
		var btn := _make_slot(str(i + 1), Color("#ffe14a"))
		var index := i
		btn.pressed.connect(func(): _use_hotkey(index))
		hotkey_box.add_child(btn)
		_hotkey_buttons.append(btn)
		_hotkey_icons.append(btn.get_node("SlotArt"))

	hotkey_box.add_child(_gap(10))

	# ---------- ยาเลือด (Q) / ยามานา (R) ----------
	potion_button = _make_slot("Q", Color("#ff9a9a"))
	potion_button.pressed.connect(func(): PlayerState.use_item_hotkey(0))
	hotkey_box.add_child(potion_button)
	_potion_icons.append(potion_button.get_node("SlotArt"))
	_potion_counts.append(potion_button.get_node("SlotCount"))

	sp_potion_button = _make_slot("R", Color("#9ac4ff"))
	sp_potion_button.pressed.connect(func(): PlayerState.use_item_hotkey(1))
	hotkey_box.add_child(sp_potion_button)
	_potion_icons.append(sp_potion_button.get_node("SlotArt"))
	_potion_counts.append(sp_potion_button.get_node("SlotCount"))

	hotkey_box.add_child(_gap(10))

	# ---------- เมนู ----------
	menu_button = _make_slot("Tab", UITheme.TEXT_DIM)
	menu_button.get_node("SlotName").text = "เมนู"
	menu_button.pressed.connect(func(): Events.toggle_window.emit(&"system"))
	hotkey_box.add_child(menu_button)


func _gap(width: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.x = width
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## ★ ที่จับสำหรับลาก ★ จุด 2x3 เม็ดด้านซ้ายของแผง (ไม่กินคลิก ปล่อยให้แผงลากเอง)
func _make_grip() -> Control:
	var grip := Control.new()
	grip.name = "Grip"
	grip.custom_minimum_size = Vector2(12, HOTKEY_SIZE.y)
	grip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mid := HOTKEY_SIZE.y * 0.5
	for row in range(3):
		for col in range(2):
			var dot := ColorRect.new()
			dot.color = UITheme.TEXT_DIM
			dot.size = Vector2(3, 3)
			dot.position = Vector2(2 + col * 5, mid - 9 + row * 7)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grip.add_child(dot)
	return grip


# =========================================================
# ★ ตำแหน่งแผงปุ่มลัด: วางข้างขวาแผงหลอดเลือด + ลากย้ายได้ + จำตำแหน่ง ★
# =========================================================
func _place_hotkey_panel() -> void:
	# รอให้คอนเทนเนอร์คำนวณขนาดจริงก่อน ไม่งั้น size ยังเป็น 0
	await get_tree().process_frame
	await get_tree().process_frame
	if hotkey_panel == null:
		return
	var saved := _load_layout()
	if saved != Vector2.INF:
		hotkey_panel.position = saved
	else:
		hotkey_panel.position = default_hotkey_pos()
	_clamp_hotkey_panel()


## ตำแหน่งเริ่มต้น = ชิดขวาแผงหลอดเลือด เว้นช่องไฟ HOTKEY_GAP_X (แถวเดียวกัน ไม่เชื่อมกัน)
func default_hotkey_pos() -> Vector2:
	if top_panel == null:
		return HOTKEY_PANEL_POS
	var w: float = top_panel.size.x
	if w <= 1.0:
		w = maxf(top_panel.get_combined_minimum_size().x, 300.0)
	return Vector2(top_panel.position.x + w + HOTKEY_GAP_X, top_panel.position.y)


## กันไม่ให้ลากแผงหลุดออกนอกจอ
func _clamp_hotkey_panel() -> void:
	if hotkey_panel == null:
		return
	var screen := get_viewport_rect().size
	var panel_size := hotkey_panel.size
	if panel_size.x <= 1.0:
		panel_size = hotkey_panel.get_combined_minimum_size()
	hotkey_panel.position.x = clampf(hotkey_panel.position.x, 0.0,
		maxf(0.0, screen.x - panel_size.x))
	hotkey_panel.position.y = clampf(hotkey_panel.position.y, 0.0,
		maxf(0.0, screen.y - panel_size.y))


func _on_hotkey_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_drag_moved = false
				_drag_offset = hotkey_panel.global_position - hotkey_panel.get_global_mouse_position()
			else:
				_dragging = false
			hotkey_panel.accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			# คลิกขวาบนแผง = คืนตำแหน่งเดิม (ข้างขวาแผงหลอดเลือด)
			hotkey_panel.position = default_hotkey_pos()
			_clamp_hotkey_panel()
			_save_layout()
			Events.say("คืนตำแหน่งแถบปุ่มลัดแล้ว")
			hotkey_panel.accept_event()


## รับการเคลื่อนเมาส์ที่ระดับ HUD ด้วย เพราะลากเร็ว ๆ เมาส์จะหลุดออกนอกแผง
func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseMotion:
		hotkey_panel.position = get_global_mouse_position() + _drag_offset
		_clamp_hotkey_panel()
		_drag_moved = true
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		_dragging = false
		if _drag_moved:
			_save_layout()
			get_viewport().set_input_as_handled()


func _save_layout() -> void:
	var cfg := ConfigFile.new()
	cfg.load(LAYOUT_PATH)  # อ่านของเดิมก่อน เผื่อมีค่าอื่นในไฟล์
	cfg.set_value("hud", "hotkey_pos", hotkey_panel.position)
	cfg.save(LAYOUT_PATH)


## คืน Vector2.INF ถ้ายังไม่เคยลาก
func _load_layout() -> Vector2:
	var cfg := ConfigFile.new()
	if cfg.load(LAYOUT_PATH) != OK:
		return Vector2.INF
	var v = cfg.get_value("hud", "hotkey_pos", null)
	return v if v is Vector2 else Vector2.INF


## ช่องปุ่มลัด 1 ช่อง: สี่เหลี่ยมจัตุรัส + ป้ายปุ่มมุมซ้ายบน + รูป + จำนวนมุมขวาล่าง
func _make_slot(key_label: String, key_color: Color) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = HOTKEY_SIZE
	btn.focus_mode = Control.FOCUS_NONE
	btn.clip_text = true
	btn.clip_contents = true
	# ★ ฟอนต์ 1 px ★ ข้อความทั้งหมดอยู่ที่ "ป้ายซ้อน" (SlotName) แล้ว
	# ถ้าปล่อยฟอนต์ปกติ Godot จะกันที่ให้ 1 บรรทัดเสมอ ช่องเลยสูงเกินจนไม่เป็นจัตุรัส
	btn.add_theme_font_size_override("font_size", 1)
	btn.add_theme_color_override("font_color", UITheme.TEXT)
	btn.add_theme_stylebox_override("normal", UITheme.slot_style())
	btn.add_theme_stylebox_override("hover", UITheme.slot_style(true))
	btn.add_theme_stylebox_override("pressed", UITheme.slot_style(true))

	var art := TextureRect.new()
	art.name = "SlotArt"
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 5
	art.offset_top = 5
	art.offset_right = -5
	art.offset_bottom = -5
	btn.add_child(art)

	var key := Label.new()
	key.name = "SlotKey"
	key.text = key_label
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	key.offset_left = 4
	key.offset_top = -1
	key.add_theme_font_size_override("font_size", 11)
	key.add_theme_color_override("font_color", key_color)
	key.add_theme_color_override("font_outline_color", Color.BLACK)
	key.add_theme_constant_override("outline_size", 4)
	btn.add_child(key)

	var caption := Label.new()
	caption.name = "SlotName"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.clip_text = true
	caption.add_theme_font_size_override("font_size", 11)
	caption.add_theme_color_override("font_color", UITheme.TEXT)
	caption.add_theme_color_override("font_outline_color", Color.BLACK)
	caption.add_theme_constant_override("outline_size", 3)
	btn.add_child(caption)

	var count := Label.new()
	count.name = "SlotCount"
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	count.offset_left = -HOTKEY_SIZE.x + 4
	count.offset_top = -20
	count.offset_right = -4
	count.offset_bottom = -2
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.add_theme_font_size_override("font_size", 12)
	count.add_theme_color_override("font_color", Color.WHITE)
	count.add_theme_color_override("font_outline_color", Color.BLACK)
	count.add_theme_constant_override("outline_size", 4)
	btn.add_child(count)

	# ★ รอบ 65 — เลขนับถอยหลังคูลดาวน์ ★ ซ้อนกลางช่อง (ปกติซ่อนไว้)
	var cd := Label.new()
	cd.name = "SlotCD"
	cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cd.add_theme_font_size_override("font_size", 20)
	cd.add_theme_color_override("font_color", Color("#ffe9a8"))
	cd.add_theme_color_override("font_outline_color", Color.BLACK)
	cd.add_theme_constant_override("outline_size", 6)
	cd.visible = false
	btn.add_child(cd)

	return btn


## คืน [ProgressBar, Label, Container]
func _bar_row(label_text: String, color: Color, height: float) -> Array:
	var wrapper := Control.new()
	wrapper.custom_minimum_size.y = height
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bar := UITheme.make_bar(color, height)
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(bar)

	var text := UITheme.make_label("", maxi(10, int(height * 0.65)), Color.WHITE)
	text.set_anchors_preset(Control.PRESET_FULL_RECT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_color_override("font_outline_color", Color.BLACK)
	text.add_theme_constant_override("outline_size", 3)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(text)

	return [bar, text, wrapper]


# =========================================================
# ล่างจอ: ปุ่มสกิล 1-4 + ปุ่มลัดหน้าต่าง
# =========================================================
func _build_bottom() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style(Color("#161b28cc")))
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position = Vector2(0, -12)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(panel)
	bottom_panel = panel

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var hint := UITheme.make_label(
		"A/D เดิน  |  W หรือ Space = พุ่งหลบ  |  J หรือ คลิกซ้าย = โจมตี  |  คลิกขวา = สกิลช่อง 1  |  F เก็บของ/คุย/เข้าประตู\n"
		+ "Q ยาเลือด  |  R ยามานา  |  1-4 สกิล  |  C สเตตัส  |  I กระเป๋า  |  E สวมใส่  |  K สกิล  |  V การ์ด  |  U เควส  |  M แผนที่  |  Tab เมนู",
		12, UITheme.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _use_hotkey(index: int) -> void:
	var sid := PlayerState.skills.hotkey_at(index)
	if sid == &"":
		Events.say("ยังไม่ได้ตั้งสกิลในปุ่มนี้ (เปิดหน้าต่างสกิลด้วย K)")
		return
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("use_skill"):
		player.use_skill(sid)


# =========================================================
# ข้อความแจ้งเตือน
# =========================================================
func _build_notice() -> void:
	notice_label = UITheme.make_label("", 18, UITheme.ACCENT)
	# ★ ต้องใช้ set_anchors_AND_OFFSETS_preset ★
	# ถ้าใช้ set_anchors_preset เฉย ๆ กรอบจะยังกว้าง 0 อยู่ ข้อความเลยไปกองมุมซ้าย
	# แล้วไปทับกับแผงหลอดเลือด (ยิ่งตอนนี้มีหลอด JOB เพิ่มมา แผงยิ่งสูง)
	notice_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	notice_label.offset_top = 130
	notice_label.offset_bottom = 172
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notice_label.add_theme_color_override("font_outline_color", Color.BLACK)
	notice_label.add_theme_constant_override("outline_size", 5)
	notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice_label.modulate.a = 0.0
	add_child(notice_label)


func show_notice(message: String) -> void:
	if notice_label == null:
		return
	notice_label.text = message
	notice_label.modulate.a = 1.0
	_notice_timer = 2.5


func _process(delta: float) -> void:
	if _notice_timer > 0.0:
		_notice_timer -= delta
		if _notice_timer <= 0.5:
			notice_label.modulate.a = maxf(0.0, _notice_timer / 0.5)

	# อัพเดตคูลดาวน์บนปุ่มสกิล
	for i in range(_hotkey_buttons.size()):
		var sid := PlayerState.skills.hotkey_at(i)
		if sid == &"":
			continue
		var cd := PlayerState.skill_cooldown_left(sid)
		_hotkey_buttons[i].modulate = Color(0.55, 0.55, 0.55) if cd > 0.0 else Color.WHITE

	# ★ รอบ 65 — คูลดาวน์ยา ★ หรี่ช่อง + นับถอยหลังเป็นวินาที
	_update_potion_cooldowns()

	# ★ ห้ามตั้ง .text ให้ปุ่มช่องลัด ★ ข้อความอยู่ที่ป้ายซ้อน (SlotName/SlotCount) แล้ว
	# ตั้ง text เมื่อไหร่ Godot จะกันที่ให้ 1 บรรทัด ช่องเลยไม่เป็นจัตุรัส
	_refresh_buffs()


# =========================================================
# อัพเดตข้อมูล
# =========================================================
func _refresh_all() -> void:
	var s := PlayerState.stats
	if s == null:
		return
	# ★ โชว์ทั้ง Base Level และ Job Level ★
	level_label.text = "Lv.%d / Job %d  %s" % [s.level, s.job_level, s.job().display_name]
	_on_hp_changed(s.hp, s.max_hp)
	_on_sp_changed(s.sp, s.max_sp)
	_on_exp_changed(s.exp_current, s.exp_to_next())
	_on_job_exp_changed(s.job_exp_current, s.job_exp_to_next())
	_on_zeny_changed(PlayerState.zeny)
	_refresh_hotkeys()


func _on_hp_changed(current: int, maximum: int) -> void:
	hp_bar.max_value = maxi(1, maximum)
	hp_bar.value = current
	hp_text.text = "%d / %d" % [current, maximum]


func _on_sp_changed(current: int, maximum: int) -> void:
	sp_bar.max_value = maxi(1, maximum)
	sp_bar.value = current
	sp_text.text = "%d / %d" % [current, maximum]


func _on_exp_changed(current: int, needed: int) -> void:
	exp_bar.max_value = maxi(1, needed)
	exp_bar.value = current
	if needed <= 0:
		exp_text.text = "MAX"
	else:
		exp_text.text = "%.1f%%" % (float(current) / needed * 100.0)


func _on_job_exp_changed(current: int, needed: int) -> void:
	if job_bar == null:
		return
	job_bar.max_value = maxi(1, needed)
	job_bar.value = current
	if needed <= 0:
		job_text.text = "MAX"
	else:
		job_text.text = "%.1f%%" % (float(current) / needed * 100.0)


func _on_zeny_changed(amount: int) -> void:
	zeny_label.text = "%s z" % _comma(amount)


func _refresh_hotkeys() -> void:
	for i in range(_hotkey_buttons.size()):
		var sid := PlayerState.skills.hotkey_at(i)
		var s := GameData.get_skill(sid) if sid != &"" else null
		var art: TextureRect = _hotkey_icons[i] if i < _hotkey_icons.size() else null
		var cap: Label = _hotkey_buttons[i].get_node_or_null("SlotName")
		if s == null:
			if cap != null:
				cap.text = ""
			_hotkey_buttons[i].tooltip_text = "ยังไม่ได้ตั้งสกิล (เปิดหน้าต่างสกิลด้วย K)"
			if art != null:
				art.texture = null
		else:
			# มีไอคอน = โชว์รูปอย่างเดียว / ไม่มีไอคอน = โชว์ชื่อสกิลย่อ ๆ เหมือนเดิม
			if art != null:
				art.texture = s.icon
			if cap != null:
				cap.text = "" if (art != null and art.texture != null) \
					else _short_skill_name(s.display_name)
			_hotkey_buttons[i].tooltip_text = "%s\n%s" % [s.display_name, s.description]

	_refresh_potions()


## ★ ช่องยา ★ โชว์รูปยาที่เลือกไว้ + จำนวนที่เหลือ
func _refresh_potions() -> void:
	if _potion_icons.is_empty():
		return
	var slot_names := ["Q  ยาเลือด", "R  ยามานา"]
	var buttons := [potion_button, sp_potion_button]
	for i in range(PlayerState.ITEM_HOTKEY_COUNT):
		if i >= _potion_icons.size():
			break
		var id := PlayerState.item_hotkey_at(i)
		var d := GameData.get_item(id) if id != &"" else null
		var art: TextureRect = _potion_icons[i]
		var count: Label = _potion_counts[i]
		var btn: Button = buttons[i]
		var cap: Label = btn.get_node_or_null("SlotName")
		if d == null:
			art.texture = null
			count.text = ""
			if cap != null:
				cap.text = "ว่าง"
			btn.tooltip_text = "%s — ยังไม่ได้เลือกยา\nเปิดกระเป๋า (I) แล้วกดตั้งช่องยา" % slot_names[i]
			continue
		var have := PlayerState.inventory.count_of(id)
		art.texture = d.icon
		if cap != null:
			cap.text = "" if d.icon != null else _short_skill_name(d.display_name)
		count.text = str(have) if have > 0 else "0"
		count.add_theme_color_override("font_color",
			Color.WHITE if have > 0 else Color("#ff8080"))
		btn.tooltip_text = "%s\n%s (เหลือ %d)" % [slot_names[i], d.display_name, have]
		# ★ รอบ 65 ★ บอกคูลดาวน์ของยาชิ้นนี้ไว้ในคำอธิบายช่องด้วย
		var cd := PlayerState.potion_cooldown_of(d)
		if cd > 0.0:
			btn.tooltip_text += "\nคูลดาวน์ %.1f วินาที" % cd


## ★ รอบ 65 — คูลดาวน์ยาบนช่อง Q/R ★
## ติดคูลดาวน์ = ช่องหรี่ลง + มีเลขวินาทีนับถอยหลังตรงกลาง (ยาแรงยิ่งรอนาน)
func _update_potion_cooldowns() -> void:
	var buttons := [potion_button, sp_potion_button]
	for i in range(PlayerState.ITEM_HOTKEY_COUNT):
		if i >= buttons.size() or buttons[i] == null:
			break
		var btn: Button = buttons[i]
		var cd_label: Label = btn.get_node_or_null("SlotCD")
		if cd_label == null:
			continue
		var left := PlayerState.potion_cooldown_left_of_id(PlayerState.item_hotkey_at(i))
		if left > 0.0:
			cd_label.visible = true
			# เหลือน้อยกว่า 1 วิ โชว์ทศนิยม 1 ตำแหน่ง (ให้เห็นว่าใกล้พร้อมแล้ว)
			cd_label.text = ("%.1f" % left) if left < 1.0 else str(int(ceil(left)))
			btn.modulate = Color(0.5, 0.5, 0.55)
		else:
			cd_label.visible = false
			btn.modulate = Color.WHITE


## ตัดชื่อสกิลให้พอดีปุ่มเล็ก ๆ (ใช้ตอนสกิลนั้นยังไม่ได้ใส่ไอคอน)
static func _short_skill_name(full: String) -> String:
	var t := full
	var p := t.find(" (")
	if p > 0:
		t = t.substr(0, p)
	return "\n" + t


func _refresh_buffs() -> void:
	if buff_box == null:
		return
	var wanted := PlayerState.active_buffs.size()
	if buff_box.get_child_count() != wanted:
		GameWindow.clear_container(buff_box)
		for sid in PlayerState.active_buffs.keys():
			var s := GameData.get_skill(StringName(sid))
			var name_text: String = s.display_name if s != null else String(PlayerState.active_buffs[sid].get("name", sid))
			var lbl := UITheme.make_label(name_text, 12, UITheme.ACCENT)
			lbl.name = String(sid)
			buff_box.add_child(lbl)

	for child in buff_box.get_children():
		var info: Dictionary = PlayerState.active_buffs.get(StringName(child.name), {})
		if info.has("time_left") and child is Label:
			var s := GameData.get_skill(StringName(child.name))
			var n: String = s.display_name if s != null else String(info.get("name", child.name))
			(child as Label).text = "%s %ds" % [n, int(info.time_left)]


static func _comma(value: int) -> String:
	var text := str(absi(value))
	var out := ""
	var count := 0
	for i in range(text.length() - 1, -1, -1):
		out = text[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if value < 0 else "") + out
