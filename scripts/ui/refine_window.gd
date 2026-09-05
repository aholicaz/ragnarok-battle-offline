## RefineWindow — หน้าตีบวกอุปกรณ์ (รอบ 57 ทำใหม่ตามตัวอย่าง · รอบ 59 สลับฝั่ง + ลุ้น)
##
## ผัง (รอบ 59): ซ้าย = การ์ดตีบวกของชิ้นที่เลือก · ขวา = รายการอุปกรณ์ที่ตีบวกได้
##   การ์ดซ้าย: วงกลมไอคอน + ป้าย +N → ชื่อไอเทม → ตาราง "ตอนนี้ → หลังตีบวก"
##              → แถบโอกาสสำเร็จ → วัตถุดิบ (ไอคอน + มี/ต้องใช้) → ★หลอดลุ้น★ → ปุ่มตีบวก
##
## ★ จังหวะตีบวก (รอบ 59) ★
##   กดปุ่ม → หลอดวิ่ง ROLL_TIME วิ (เสียง refine_roll) → รู้ผล → คำ SUCCESS / FAIL ใหญ่กลางหน้าต่าง
##   (เสียง refine_success / refine_fail) → ค้าง RESULT_SHOW วิ แล้วจาง
##   ไฟล์เสียงวางที่ Sprites/sfx/refine_roll.ogg · refine_success.ogg · refine_fail.ogg (เปลี่ยนไฟล์ได้เลย)
class_name RefineWindow
extends GameWindow

const ICON_SIZE := Vector2(28, 28)          ## ไอคอนในรายการซ้าย
const BIG_ICON := Vector2(84, 84)           ## ไอคอนใหญ่กลางการ์ด
const MAT_ICON := Vector2(26, 26)           ## ไอคอนวัตถุดิบ
const LIST_WIDTH := 224.0

## ★ ปรับความตื่นเต้นตรงนี้ ★
const ROLL_TIME := 1.6            ## หลอดวิ่งกี่วินาทีก่อนรู้ผล
const RESULT_SHOW := 1.3          ## คำ SUCCESS/FAIL ค้างกี่วินาที
const RESULT_FONT := 52           ## ขนาดตัวอักษรคำผล
const SFX_ROLL := "refine_roll"
const SFX_SUCCESS := "refine_success"
const SFX_FAIL := "refine_fail"

## ยิงตอนรู้ผลแล้ว (เทสต์/ระบบอื่นรอได้)  out = ผลจาก RefineSystem.try_refine
signal refine_finished(out: Dictionary)

var _rolling := false             ## กำลังลุ้นอยู่ (กันกดซ้ำ)
var last_result: Dictionary = {}  ## ผลล่าสุด

var _list: VBoxContainer
var _zeny_label: Label
var _selected_source := ""                  # "inv:<index>" หรือ "eq:<slot>"

# --- การ์ดขวา ---
var _big_icon: TextureRect
var _refine_badge: Label
var _item_name: Label
var _item_sub: Label
var _stat_rows: VBoxContainer
var _rate_bar: ProgressBar
var _rate_label: Label
var _mat_rows: VBoxContainer
var _warn: Label
var _refine_button: Button
var _result: Label
# --- ลุ้น (รอบ 59) ---
var _roll_box: VBoxContainer
var _roll_bar: ProgressBar
var _roll_label: Label
var _big_result: Label            ## คำ SUCCESS / FAIL ทับกลางหน้าต่าง
var _big_tween: Tween


func _ready() -> void:
	window_title = "ตีบวกอุปกรณ์"
	super._ready()
	custom_minimum_size = Vector2(660, 0)
	Events.inventory_changed.connect(refresh)
	Events.equipment_changed.connect(refresh)
	Events.zeny_changed.connect(func(_z): refresh())


func _build_content() -> void:
	# ---------- หัว ----------
	var head := HBoxContainer.new()
	content.add_child(head)
	var title := UITheme.make_label("กดชื่ออุปกรณ์ในรายการทางขวาเพื่อเลือกตีบวก", 13, UITheme.TEXT_DIM)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_zeny_label = UITheme.make_label("0 z", 15, Color("#ffe9a0"))
	head.add_child(_zeny_label)

	content.add_child(UITheme.separator())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	content.add_child(body)

	# ---------- ซ้าย: การ์ดตีบวก (รอบ 59 ย้ายมาซ้าย) ----------
	var right := VBoxContainer.new()          # ชื่อตัวแปรเดิม (การ์ด) — ตอนนี้อยู่ฝั่งซ้าย
	right.name = "Card"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)

	# ---------- ขวา: รายการอุปกรณ์ (รอบ 59 ย้ายมาขวา) ----------
	var left := PanelContainer.new()
	left.name = "ItemList"
	left.custom_minimum_size = Vector2(LIST_WIDTH, 300)
	left.add_theme_stylebox_override("panel", UITheme.panel_style(Color("#161b28cc")))
	body.add_child(left)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)

	# วงกลมไอคอน + ป้าย +N
	var art_box := PanelContainer.new()
	art_box.add_theme_stylebox_override("panel", _circle_style())
	art_box.custom_minimum_size = BIG_ICON + Vector2(22, 22)
	art_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right.add_child(art_box)

	var art_center := CenterContainer.new()
	art_box.add_child(art_center)

	_big_icon = TextureRect.new()
	_big_icon.name = "BigIcon"
	_big_icon.custom_minimum_size = BIG_ICON
	_big_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_big_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_big_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art_center.add_child(_big_icon)

	_refine_badge = UITheme.make_label("", 18, UITheme.ACCENT)
	_refine_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(_refine_badge)

	_item_name = UITheme.make_label("ยังไม่ได้เลือกอุปกรณ์", 16, UITheme.TEXT)
	_item_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_item_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_item_name)

	_item_sub = UITheme.make_label("", 12, UITheme.TEXT_DIM)
	_item_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(_item_sub)

	# ตาราง ตอนนี้ → หลังตีบวก
	var stat_panel := PanelContainer.new()
	stat_panel.add_theme_stylebox_override("panel", UITheme.panel_style(Color("#161b28cc")))
	right.add_child(stat_panel)

	_stat_rows = VBoxContainer.new()
	_stat_rows.add_theme_constant_override("separation", 2)
	stat_panel.add_child(_stat_rows)

	# แถบโอกาสสำเร็จ
	var rate_row := HBoxContainer.new()
	rate_row.add_theme_constant_override("separation", 8)
	right.add_child(rate_row)
	var rate_head := UITheme.make_label("โอกาสสำเร็จ", 13, UITheme.TEXT_DIM)
	rate_head.custom_minimum_size.x = 84
	rate_row.add_child(rate_head)
	_rate_bar = UITheme.make_bar(UITheme.GOOD, 16.0)
	_rate_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rate_bar.max_value = 100.0
	rate_row.add_child(_rate_bar)
	_rate_label = UITheme.make_label("—", 14, UITheme.TEXT)
	_rate_label.custom_minimum_size.x = 52
	_rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rate_row.add_child(_rate_label)

	# วัตถุดิบ
	var mat_panel := PanelContainer.new()
	mat_panel.add_theme_stylebox_override("panel", UITheme.panel_style(Color("#161b28cc")))
	right.add_child(mat_panel)
	_mat_rows = VBoxContainer.new()
	_mat_rows.add_theme_constant_override("separation", 4)
	mat_panel.add_child(_mat_rows)

	_warn = UITheme.make_label("", 12, Color("#ffb36b"))
	_warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_warn)

	# ★ หลอดลุ้น (รอบ 59) — โผล่เฉพาะตอนกดตีบวก ★
	_roll_box = VBoxContainer.new()
	_roll_box.name = "RollBox"
	_roll_box.add_theme_constant_override("separation", 3)
	_roll_box.visible = false
	right.add_child(_roll_box)
	_roll_label = UITheme.make_label("กำลังตีบวก...", 13, Color("#ffe9a0"))
	_roll_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_roll_box.add_child(_roll_label)
	_roll_bar = UITheme.make_bar(Color("#ffb347"), 18.0)
	_roll_bar.name = "RollBar"
	_roll_bar.max_value = 100.0
	_roll_bar.value = 0.0
	_roll_box.add_child(_roll_bar)

	_refine_button = UITheme.make_button("ตีบวก!", 200)
	_refine_button.disabled = true
	_refine_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_refine_button.pressed.connect(_do_refine)
	right.add_child(_refine_button)

	_result = UITheme.make_label("", 14, UITheme.ACCENT)
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(_result)

	# ★ คำ SUCCESS / FAIL ใหญ่ ๆ ทับกลางหน้าต่าง (รอบ 59) ★
	_big_result = Label.new()
	_big_result.name = "BigResult"
	_big_result.set_anchors_preset(Control.PRESET_FULL_RECT)
	_big_result.size_flags_horizontal = Control.SIZE_FILL
	_big_result.size_flags_vertical = Control.SIZE_FILL     # Label ปกติจะย่อเหลือแค่สูงเท่าตัวหนังสือ
	_big_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big_result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_big_result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big_result.add_theme_font_size_override("font_size", RESULT_FONT)
	_big_result.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_big_result.add_theme_constant_override("outline_size", 10)
	var dim := StyleBoxFlat.new()          # ฉากมืดบาง ๆ ทับหน้าต่างให้คำผลเด่น
	dim.bg_color = Color(0, 0, 0, 0.45)
	dim.set_corner_radius_all(6)
	_big_result.add_theme_stylebox_override("normal", dim)
	_big_result.visible = false
	_big_result.z_index = 50
	add_child(_big_result)


static func _circle_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#243050")
	s.border_color = UITheme.ACCENT
	s.set_border_width_all(2)
	s.set_corner_radius_all(64)      # กลมเหมือนตัวอย่าง
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


func _selected_instance() -> ItemInstance:
	if _selected_source.begins_with("inv:"):
		return PlayerState.inventory.get_slot(int(_selected_source.substr(4)))
	elif _selected_source.begins_with("eq:"):
		return PlayerState.equipment.get_item(int(_selected_source.substr(3)))
	return null


## ★ กดตีบวก → ลุ้น (หลอดวิ่ง) → รู้ผล → คำ SUCCESS/FAIL ★
## เป็น coroutine: เทสต์เรียก  await win._do_refine()  หรือรอสัญญาณ refine_finished
func _do_refine() -> void:
	if _rolling:
		return
	var inst := _selected_instance()
	if inst == null:
		return
	if not RefineSystem.can_refine(inst):
		return

	# ---------- ลุ้น ----------
	_rolling = true
	_result.text = ""
	_refine_button.disabled = true
	_refine_button.text = "กำลังตี..."
	_roll_bar.value = 0.0
	_roll_label.text = "กำลังตีบวก..."
	_roll_box.visible = true
	_play_sfx(SFX_ROLL)

	var roll := create_tween()
	roll.tween_property(_roll_bar, "value", 100.0, ROLL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await roll.finished
	if not is_instance_valid(self):
		return
	_rolling = false
	_roll_box.visible = false

	# ระหว่างลุ้น ของอาจถูกย้าย/ขายไป → ไม่ตี
	if _selected_instance() != inst:
		refresh()
		return

	# ---------- ตีจริง ----------
	var out := RefineSystem.try_refine(inst, PlayerState.inventory, PlayerState)
	last_result = out
	_result.text = out.message
	_result.add_theme_color_override("font_color", UITheme.GOOD if out.success else UITheme.BAD)

	# ของแตก = เอาออกจากช่อง
	if out.get("broke", false):
		if _selected_source.begins_with("inv:"):
			PlayerState.inventory.set_slot(int(_selected_source.substr(4)), null)
		elif _selected_source.begins_with("eq:"):
			PlayerState.equipment.unequip(int(_selected_source.substr(3)))
		_selected_source = ""

	if bool(out.ok):
		_show_big_result(bool(out.success), bool(out.get("broke", false)))
		_play_sfx(SFX_SUCCESS if out.success else SFX_FAIL)

	PlayerState.refresh()
	refresh()
	refine_finished.emit(out)


## คำ SUCCESS / FAIL เด้งขึ้นกลางหน้าต่าง แล้วจางหาย
func _show_big_result(success: bool, broke: bool = false) -> void:
	if _big_tween != null and _big_tween.is_valid():
		_big_tween.kill()
	_big_result.text = "SUCCESS!" if success else ("FAIL\nของแตก!" if broke else "FAIL")
	_big_result.add_theme_color_override("font_color",
		Color("#7dff8a") if success else Color("#ff5a5a"))
	_big_result.visible = true
	_big_result.modulate = Color(1, 1, 1, 0)
	_big_result.pivot_offset = size * 0.5      # หมุน/ย่อรอบกลางหน้าต่าง
	_big_result.scale = Vector2(1.8, 1.8) if success else Vector2(0.6, 0.6)
	_big_result.position = Vector2.ZERO

	_big_tween = create_tween()
	_big_tween.set_parallel(true)
	_big_tween.tween_property(_big_result, "modulate:a", 1.0, 0.15)
	_big_tween.tween_property(_big_result, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not success:
		# สั่นซ้าย-ขวาตอนพลาด
		var shake := _big_tween.chain()
		for i in range(5):
			shake.tween_property(_big_result, "position:x", (8.0 if i % 2 == 0 else -8.0), 0.04)
		shake.tween_property(_big_result, "position:x", 0.0, 0.04)
	_big_tween.chain().tween_interval(RESULT_SHOW)
	_big_tween.chain().tween_property(_big_result, "modulate:a", 0.0, 0.35)
	_big_tween.chain().tween_callback(func(): _big_result.visible = false)


func is_rolling() -> bool:
	return _rolling


func _play_sfx(key: String) -> void:
	var g := get_node_or_null("/root/Game")
	if g != null and "sfx" in g and g.sfx != null:
		g.sfx.play(key, 1.0, 0.0)


func refresh() -> void:
	if _list == null or not visible:
		return

	_zeny_label.text = "%s z" % HUD._comma(PlayerState.zeny)
	GameWindow.clear_container(_list)

	for slot in PlayerState.equipment.slots.keys():
		var eq_inst: ItemInstance = PlayerState.equipment.get_item(slot)
		if eq_inst == null or not RefineSystem.can_refine(eq_inst):
			continue
		_add_row(eq_inst, "eq:%d" % slot, "สวมอยู่")

	for i in range(PlayerState.inventory.size):
		var inst := PlayerState.inventory.get_slot(i)
		if inst == null or not RefineSystem.can_refine(inst):
			continue
		_add_row(inst, "inv:%d" % i, "")

	if _list.get_child_count() == 0:
		var empty := UITheme.make_label("ไม่มีอุปกรณ์ที่ตีบวกได้", 13, UITheme.TEXT_DIM)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(empty)

	_update_card()


## หนึ่งแถวในรายการซ้าย = [ไอคอน] [ชื่อ] [+N]
func _add_row(inst: ItemInstance, source: String, tag: String) -> void:
	var selected := source == _selected_source

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.slot_style(selected))
	_list.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	panel.add_child(row)

	var d := inst.data()

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

	var name_btn := Button.new()
	name_btn.name = "PickButton"
	name_btn.text = inst.display_name() + (("  (%s)" % tag) if tag != "" else "")
	name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_btn.flat = true
	name_btn.clip_text = true
	name_btn.focus_mode = Control.FOCUS_NONE
	name_btn.tooltip_text = "กดเพื่อเลือกและดูรายละเอียด"
	name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_btn.add_theme_font_size_override("font_size", 12)
	name_btn.add_theme_color_override("font_color",
		UITheme.ACCENT if selected else UITheme.TEXT)
	name_btn.add_theme_color_override("font_hover_color", UITheme.ACCENT)
	row.add_child(name_btn)

	var lv := UITheme.make_label("+%d" % inst.refine, 13,
		Color("#ffe9a0") if inst.refine > 0 else UITheme.TEXT_DIM)
	lv.custom_minimum_size.x = 32
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lv)

	var src := source
	var this_inst := inst
	name_btn.pressed.connect(func():
		if _rolling:
			return              # กำลังลุ้นอยู่ ห้ามสลับชิ้น
		_selected_source = src
		_result.text = ""
		UI.show_item(this_inst, self, "เลือกไว้ตีบวกแล้ว")
		refresh()
	)


# =========================================================
# การ์ดขวา
# =========================================================
func _update_card() -> void:
	GameWindow.clear_container(_stat_rows)
	GameWindow.clear_container(_mat_rows)

	var inst := _selected_instance()
	if inst == null:
		_big_icon.texture = null
		_refine_badge.text = ""
		_item_name.text = "ยังไม่ได้เลือกอุปกรณ์"
		_item_sub.text = "เลือกจากรายการทางขวา"
		_rate_bar.value = 0.0
		_rate_label.text = "—"
		_warn.text = ""
		_refine_button.disabled = true
		_refine_button.text = "ตีบวก!"
		_roll_box.visible = false
		return

	var d := inst.data()
	var p := RefineSystem.preview(inst)

	_big_icon.texture = d.icon if d != null else null
	_refine_badge.text = "+%d  →  +%d" % [p.current_refine, p.next_refine]
	_item_name.text = inst.display_name()
	var sub: Array[String] = []
	if d != null:
		sub.append("ตีบวกสูงสุด +%d" % d.max_refine)
	if inst.bonus_percent > 0.0:
		sub.append("ของดรอป +%s%%" % ItemInstance._pct_text(inst.bonus_percent))
	_item_sub.text = "  ·  ".join(sub)

	# ---------- ตอนนี้ → หลังตีบวก ----------
	_stat_rows.add_child(_stat_row("ค่าพลัง", "ตอนนี้", "หลังตีบวก", true))
	var gained := false
	if d != null and int(p.atk_gain) > 0 and d.type == ItemData.Type.WEAPON:
		var atk_now := inst.total_atk()
		_stat_rows.add_child(_stat_row("ATK", str(atk_now), str(atk_now + int(p.atk_gain))))
		gained = true
	elif d != null and int(p.atk_gain) > 0:
		var atk_now2 := inst.total_atk()
		_stat_rows.add_child(_stat_row("ATK", str(atk_now2), str(atk_now2 + int(p.atk_gain))))
		gained = true
	if d != null and int(p.def_gain) > 0 and d.type == ItemData.Type.ARMOR:
		var def_now := inst.total_def()
		_stat_rows.add_child(_stat_row("DEF", str(def_now), str(def_now + int(p.def_gain))))
		gained = true
	if not gained:
		_stat_rows.add_child(_stat_row("—", "ชิ้นนี้ตีบวกแล้วไม่เพิ่มค่าพลังโดยตรง", "", false, true))

	# ---------- โอกาสสำเร็จ ----------
	var rate := float(p.rate)
	_rate_bar.value = rate
	_rate_label.text = "%.0f%%" % rate
	var fill := _rate_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null:
		fill.bg_color = UITheme.GOOD if rate >= 70.0 else (UITheme.ACCENT if rate >= 40.0 else UITheme.BAD)

	# ---------- วัตถุดิบ ----------
	var have_ore := PlayerState.inventory.count_of(p.ore_id)
	var ore_item := GameData.get_item(p.ore_id)
	_mat_rows.add_child(_mat_row(ore_item.icon if ore_item != null else null,
		GameData.item_name(p.ore_id), have_ore, int(p.ore_count)))
	_mat_rows.add_child(_mat_row(null, "ซีนี", PlayerState.zeny, int(p.zeny), true))

	# ---------- คำเตือน ----------
	_warn.text = "⚠ ระดับนี้ถ้าตีพลาดจะลดลง 1 ขั้น" if p.can_downgrade else ""

	var ok := PlayerState.zeny >= int(p.zeny) and have_ore >= int(p.ore_count)
	_refine_button.disabled = (not ok) or _rolling
	_refine_button.text = "กำลังตี..." if _rolling else "ตีบวก  +%d → +%d" % [p.current_refine, p.next_refine]


func _stat_row(label: String, now_text: String, next_text: String,
		is_head: bool = false, wide: bool = false) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var c: Color = UITheme.TEXT_DIM if (is_head or wide) else UITheme.TEXT
	var name_lb := UITheme.make_label(label, 13, c)
	name_lb.custom_minimum_size.x = 70
	row.add_child(name_lb)

	var now_lb := UITheme.make_label(now_text, 13, c)
	now_lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	now_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if wide else HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(now_lb)

	if not wide:
		var arrow := UITheme.make_label("→", 13, UITheme.TEXT_DIM)
		arrow.custom_minimum_size.x = 22
		arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(arrow)

		var next_lb := UITheme.make_label(next_text, 14,
			UITheme.TEXT_DIM if is_head else UITheme.GOOD)
		next_lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		next_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(next_lb)
	return row


## แถววัตถุดิบ: [ไอคอน] ชื่อ ....... มี / ต้องใช้
func _mat_row(icon: Texture2D, label: String, have: int, need: int, is_zeny: bool = false) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var frame := PanelContainer.new()
	frame.name = "MatFrame"
	frame.custom_minimum_size = MAT_ICON + Vector2(4, 4)
	frame.add_theme_stylebox_override("panel",
		UITheme.panel_style(Color("#0d1119"), UITheme.BORDER, 3))
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(frame)

	if icon != null:
		var art := TextureRect.new()
		art.custom_minimum_size = MAT_ICON
		art.texture = icon
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		frame.add_child(art)
	else:
		var z := UITheme.make_label("z" if is_zeny else "?", 15, Color("#ffe9a0"))
		z.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		z.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		frame.add_child(z)

	var name_lb := UITheme.make_label(label, 13, UITheme.TEXT)
	name_lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_lb)

	var enough := have >= need
	var amount := UITheme.make_label(
		"ใช้ %s  (มี %s)" % [HUD._comma(need), HUD._comma(have)], 13,
		UITheme.GOOD if enough else UITheme.BAD)
	amount.name = "MatAmount"
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(amount)
	return row
