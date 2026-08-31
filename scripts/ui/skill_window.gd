## SkillWindow — ผังสกิล (กด K)
##
## ★ หน้าตาแบบผังสกิล ★  หนึ่งช่องประกอบด้วย
##   [ 0/5 ]        <- ป้ายเลเวลอยู่บนไอคอน
##   ( ไอคอน ) [+]  <- ปุ่มกลม + มุมขวาล่าง = ใช้ 1 แต้มอัพสกิล (โผล่เฉพาะตอนอัพได้)
##   [ ชื่อ ]
##
## กดที่ไอคอน = เปิดกล่องรายละเอียดข้าง ๆ หน้าต่าง (แบบเดียวกับดูไอเทม)
## ในกล่องนั้นมีปุ่ม "อัพสกิล" และปุ่มตั้งช่องลัด 1-4 ครบ
##
## เงื่อนไขการเรียนตั้งใน SkillData: ช่อง Required Level และ Required Skills ({"bash": 5})
## ช่องที่เงื่อนไขยังไม่ครบจะเป็นสีเทา มีเครื่องหมาย ! และกดอัพไม่ได้
class_name SkillWindow
extends GameWindow

## ขนาดช่องไอคอนสกิล 1 ช่อง
const TILE := Vector2(64, 64)
## ความกว้างของ "คอลัมน์" ทั้งช่อง (ป้ายชื่อยาวกว่าไอคอน จะได้ไม่ถูกตัด)
const COL_W := 88.0
## ระยะห่างระหว่างช่อง
const GAP_X := 10.0
const GAP_Y := 30.0
## ความสูงป้ายเลเวลด้านบน · ป้ายชื่อ
const BADGE_H := 20.0
const NAME_H := 20.0
## ★ ปุ่มกลม + ที่มุมไอคอน ★
const PLUS_SIZE := 24.0

var _tree_box: Control          # กล่องวางผัง (วางช่องด้วยพิกัดเอง)
var _lines: Control             # ชั้นวาดเส้นโยง
var _point_label: Label
var _hint_label: Label
var _selected: StringName = &""

## skill_id -> {"col", "row", "skill"}
var _placed: Dictionary = {}
## เส้นโยง: [{from, to}]
var _links: Array = []
## skill_id -> ปุ่มไอคอน (ให้เทสต์เช็คได้)
var _tiles: Dictionary = {}


func _ready() -> void:
	window_title = "ผังสกิล"
	super._ready()
	# ★ อย่าให้กว้างเกิน ★ ไม่งั้นกล่องรายละเอียดที่เด้งข้าง ๆ จะไม่มีที่ยืน ต้องมาทับหน้าต่าง
	custom_minimum_size = Vector2(700, 0)
	Events.skills_changed.connect(refresh)
	Events.stats_changed.connect(refresh)


func _build_content() -> void:
	_point_label = UITheme.make_label("", 15, UITheme.GOOD)
	content.add_child(_point_label)

	_hint_label = UITheme.make_label(
		"กดที่รูปสกิลเพื่อดูรายละเอียด · ปุ่ม + บนรูป = ใช้ 1 แต้มอัพสกิลนั้น", 12, UITheme.TEXT_DIM)
	content.add_child(_hint_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 300
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)

	_tree_box = Control.new()
	_tree_box.name = "TreeBox"
	_tree_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_tree_box)

	# ชั้นเส้นโยงอยู่หลังช่องสกิล
	_lines = Control.new()
	_lines.name = "Links"
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.draw.connect(_draw_links)
	_tree_box.add_child(_lines)


func _assign_hotkey(index: int) -> void:
	if _selected == &"":
		Events.say("เลือกสกิลก่อน")
		return
	if not PlayerState.skills.is_learned(_selected):
		Events.say("ยังไม่ได้เรียนสกิลนี้")
		return
	PlayerState.skills.set_hotkey(index, _selected)
	Events.say("ตั้งช่องลัด %d เรียบร้อย" % (index + 1))
	_show_popup()


# =========================================================
# จัดผัง — แถว = ความลึก (สกิลต้นทางอยู่แถว 0) · คอลัมน์ = เรียงซ้ายไปขวา
# แม่จะอยู่กึ่งกลางเหนือกลุ่มลูกของตัวเอง
# =========================================================
func _layout(skill_list: Array) -> void:
	_placed.clear()
	_links.clear()

	var by_id := {}
	for s: SkillData in skill_list:
		by_id[s.id] = s

	var children := {}
	var roots: Array = []
	for s: SkillData in skill_list:
		var parent := s.parent_skill()
		if parent != &"" and by_id.has(parent):
			if not children.has(parent):
				children[parent] = []
			children[parent].append(s)
			_links.append({"from": parent, "to": s.id})
		else:
			roots.append(s)

	var next_col := [0]
	var place := func(node: SkillData, row: int, self_ref: Callable) -> void:
		var kids: Array = children.get(node.id, [])
		var col := 0
		if kids.is_empty():
			col = next_col[0]
			next_col[0] += 1
		else:
			var first: int = next_col[0]
			for kid: SkillData in kids:
				self_ref.call(kid, row + 1, self_ref)
			var last: int = next_col[0] - 1
			col = int(round((first + last) / 2.0))
		_placed[node.id] = {"col": col, "row": row, "skill": node}
	for r: SkillData in roots:
		place.call(r, 0, place)


func _tile_pos(col: int, row: int) -> Vector2:
	var cell_h: float = BADGE_H + TILE.y + NAME_H + GAP_Y
	return Vector2(col * (COL_W + GAP_X), row * cell_h)


# =========================================================
func refresh() -> void:
	if _tree_box == null:
		return

	var stats := PlayerState.stats
	var book := PlayerState.skills
	_point_label.text = "แต้มสกิลที่ใช้ได้: %d" % stats.skill_points

	# ลบเฉพาะช่องสกิล เก็บชั้นเส้นไว้
	for c in _tree_box.get_children():
		if c != _lines:
			_tree_box.remove_child(c)
			c.queue_free()
	_tiles.clear()

	var skill_list := GameData.skills_for_job(stats.job_id)
	if skill_list.is_empty():
		_tree_box.add_child(UITheme.make_label("ยังไม่มีสกิลสำหรับอาชีพนี้", 13, UITheme.TEXT_DIM))
		return

	_layout(skill_list)

	var max_col := 0
	var max_row := 0
	for id in _placed.keys():
		max_col = maxi(max_col, int(_placed[id].col))
		max_row = maxi(max_row, int(_placed[id].row))
		_add_tile(_placed[id].skill, int(_placed[id].col), int(_placed[id].row), book, stats)

	# ★ อย่าบวกช่องไฟของช่องสุดท้ายเข้าไป ★ ไม่งั้นผังกว้างเกินหน้าต่างนิดเดียว
	# แล้วจะมีแถบเลื่อนแนวนอนโผล่มาโดยไม่จำเป็น
	var w: float = max_col * (COL_W + GAP_X) + COL_W
	var h: float = max_row * (BADGE_H + TILE.y + NAME_H + GAP_Y) + BADGE_H + TILE.y + NAME_H
	_tree_box.custom_minimum_size = Vector2(w, h)
	_lines.size = Vector2(w, h)
	_lines.queue_redraw()

	_refresh_hint(stats)
	if _selected != &"" and UI.item_popup != null and UI.item_popup.is_open():
		_show_popup()


## หนึ่งช่องในผัง: ป้ายเลเวล -> ไอคอน -> ป้ายชื่อ -> ปุ่มเรียน
func _add_tile(s: SkillData, col: int, row: int, book: SkillBook, stats: PlayerStats) -> void:
	var lv := book.level_of(s.id)
	var blocker := book.learn_blocker(s.id, stats)
	var locked: bool = lv == 0 and blocker != "" \
		and blocker != "ไม่มี Skill Point" and blocker != "เลเวลสูงสุดแล้ว"
	var selected := s.id == _selected

	var box := VBoxContainer.new()
	box.name = "Tile_%s" % String(s.id)
	box.add_theme_constant_override("separation", 2)
	box.position = _tile_pos(col, row)
	box.custom_minimum_size.x = COL_W
	_tree_box.add_child(box)

	# ---------- ป้ายเลเวล 0/5 ----------
	var badge := PanelContainer.new()
	badge.name = "Badge"
	badge.custom_minimum_size = Vector2(COL_W, BADGE_H)
	badge.add_theme_stylebox_override("panel", UITheme.panel_style(
		Color("#3d4763") if not locked else Color("#262b38"),
		UITheme.ACCENT if selected else UITheme.BORDER, 5))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(badge)

	var badge_text := UITheme.make_label("%d/%d" % [lv, s.max_level], 12,
		Color.WHITE if lv > 0 else (UITheme.TEXT_DIM if locked else UITheme.TEXT))
	badge_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(badge_text)

	# ---------- ไอคอน (กดเพื่อเลือก) ----------
	var icon_center := CenterContainer.new()
	icon_center.name = "IconRow"
	icon_center.custom_minimum_size = Vector2(COL_W, TILE.y)
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon_center)

	var btn := Button.new()
	btn.name = "Icon"
	btn.custom_minimum_size = TILE
	btn.focus_mode = Control.FOCUS_NONE
	btn.clip_text = true
	btn.clip_contents = true
	btn.add_theme_font_size_override("font_size", 10)
	btn.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	btn.add_theme_stylebox_override("normal", UITheme.slot_style(selected))
	btn.add_theme_stylebox_override("hover", UITheme.slot_style(true))
	btn.add_theme_stylebox_override("pressed", UITheme.slot_style(true))
	btn.tooltip_text = "%s\n%s" % [s.display_name, s.description]
	var sid := s.id
	btn.pressed.connect(func(): _select(sid))
	icon_center.add_child(btn)
	_tiles[s.id] = btn

	var art := TextureRect.new()
	art.name = "SkillIcon"
	art.texture = s.icon
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 5
	art.offset_top = 5
	art.offset_right = -5
	art.offset_bottom = -5
	# เรียนแล้ว = สีเต็ม · ล็อกอยู่ = เทา · เรียนได้แต่ยังไม่เรียน = จางนิดหน่อย
	if lv > 0:
		art.modulate = Color.WHITE
	elif locked:
		art.modulate = Color(0.42, 0.45, 0.52)
	else:
		art.modulate = Color(0.74, 0.78, 0.86)
	btn.add_child(art)

	# เครื่องหมายบอกว่ายังล็อกอยู่ (ไม่ใช้อีโมจิ ฟอนต์ไทยไม่มี glyph)
	if locked:
		var lock := UITheme.make_label("!", 16, UITheme.BAD)
		lock.name = "LockMark"
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		lock.offset_left = -14
		lock.offset_top = -3
		lock.add_theme_color_override("font_outline_color", Color.BLACK)
		lock.add_theme_constant_override("outline_size", 4)
		btn.add_child(lock)

	# ---------- ป้ายชื่อ ----------
	var name_panel := PanelContainer.new()
	name_panel.name = "NamePanel"
	name_panel.custom_minimum_size = Vector2(COL_W, NAME_H)
	name_panel.add_theme_stylebox_override("panel", UITheme.panel_style(
		Color("#3d4763") if not locked else Color("#262b38"),
		UITheme.ACCENT if selected else UITheme.BORDER, 5))
	name_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_panel)

	var name_label := UITheme.make_label(_short(s.display_name), 10,
		UITheme.ACCENT if selected else (UITheme.TEXT_DIM if locked else UITheme.TEXT))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_panel.add_child(name_label)

	# ---------- ★ ปุ่ม + มุมขวาล่างของรูป ★ ----------
	# โผล่เฉพาะตอน "อัพได้จริง" (เงื่อนไขครบ + มีแต้ม + ยังไม่เต็มเลเวล)
	# เข้าใจง่ายกว่าคำว่า "เรียน +1" เพราะเห็นปุ๊บก็รู้ว่ากดแล้วสกิลนี้ขึ้นเลเวล
	var can_learn := book.can_learn(s.id, stats)
	if can_learn:
		var plus := Button.new()
		plus.name = "Learn"
		plus.text = "+"
		plus.focus_mode = Control.FOCUS_NONE
		plus.custom_minimum_size = Vector2(PLUS_SIZE, PLUS_SIZE)
		plus.size = Vector2(PLUS_SIZE, PLUS_SIZE)
		plus.tooltip_text = "ใช้ 1 แต้มสกิล อัพ %s เป็นเลเวล %d" % [_short(s.display_name), lv + 1]
		plus.add_theme_font_size_override("font_size", 18)
		plus.add_theme_color_override("font_color", Color("#1c2233"))
		plus.add_theme_color_override("font_hover_color", Color("#1c2233"))
		plus.add_theme_color_override("font_pressed_color", Color("#1c2233"))
		plus.add_theme_stylebox_override("normal",
			UITheme.panel_style(UITheme.GOOD, Color("#0d1017"), int(PLUS_SIZE * 0.5)))
		plus.add_theme_stylebox_override("hover",
			UITheme.panel_style(Color("#b6ffcf"), Color.WHITE, int(PLUS_SIZE * 0.5)))
		plus.add_theme_stylebox_override("pressed",
			UITheme.panel_style(Color("#7dffa8"), Color.WHITE, int(PLUS_SIZE * 0.5)))
		# ★ ต้องอยู่ในกรอบไอคอน ★ ปุ่มไอคอนตั้ง clip_contents ไว้ ล้นออกไปแล้วจะโดนตัดหาย
		plus.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		plus.offset_left = -PLUS_SIZE - 3.0
		plus.offset_top = -PLUS_SIZE - 3.0
		plus.offset_right = -3.0
		plus.offset_bottom = -3.0
		plus.pressed.connect(func(): _learn(sid))
		btn.add_child(plus)


## ตัดชื่อสกิลให้สั้นพอใส่ป้าย ("Bash (ฟันแรง)" -> "Bash")
func _short(display_name: String) -> String:
	var cut := display_name.find(" (")
	var out: String = display_name.substr(0, cut) if cut > 0 else display_name
	# ยาวเกินป้ายก็ตัดคำท้ายให้สั้นลง เช่น "Sword Mastery" -> "Sword Mast."
	if out.length() > 11:
		out = out.substr(0, 11) + "."
	return out


# =========================================================
# เส้นโยงระหว่างสกิลแม่กับลูก
# =========================================================
func _draw_links() -> void:
	var color := Color("#5f7bb0")
	var width := 2.0
	var cell_bottom: float = BADGE_H + TILE.y + NAME_H + 6.0
	for link in _links:
		if not _placed.has(link.from) or not _placed.has(link.to):
			continue
		var a: Dictionary = _placed[link.from]
		var b: Dictionary = _placed[link.to]
		var from_pos := _tile_pos(int(a.col), int(a.row))
		var to_pos := _tile_pos(int(b.col), int(b.row))
		var start := from_pos + Vector2(COL_W * 0.5, cell_bottom)
		var end := to_pos + Vector2(COL_W * 0.5, 0.0)
		var mid_y: float = start.y + (end.y - start.y) * 0.5
		_lines.draw_line(start, Vector2(start.x, mid_y), color, width)
		_lines.draw_line(Vector2(start.x, mid_y), Vector2(end.x, mid_y), color, width)
		_lines.draw_line(Vector2(end.x, mid_y), end, color, width)


# =========================================================
# ★ กดที่รูปสกิล = เปิดกล่องรายละเอียดข้าง ๆ หน้าต่าง (แบบเดียวกับดูไอเทม) ★
# =========================================================
func _select(skill_id: StringName) -> void:
	_selected = skill_id
	refresh()
	_show_popup()


## กดปุ่ม + หรือปุ่มในกล่อง = ใช้แต้มอัพสกิล
func _learn(skill_id: StringName) -> void:
	_selected = skill_id
	PlayerState.learn_skill(skill_id)
	refresh()
	_show_popup()


func _refresh_hint(stats: PlayerStats) -> void:
	if _hint_label == null:
		return
	if stats.skill_points > 0:
		_hint_label.text = "กดที่รูปสกิลเพื่อดูรายละเอียด · ปุ่ม + บนรูป = ใช้ 1 แต้มอัพสกิลนั้น"
		_hint_label.add_theme_color_override("font_color", UITheme.TEXT)
	else:
		_hint_label.text = "กดที่รูปสกิลเพื่อดูรายละเอียด · ยังไม่มีแต้ม (ได้เพิ่มตอน Job Level ขึ้น)"
		_hint_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)


## เปิด/อัปเดตกล่องรายละเอียดของสกิลที่เลือกอยู่
func _show_popup() -> void:
	if _selected == &"":
		return
	var s := GameData.get_skill(_selected)
	if s == null:
		return
	var book := PlayerState.skills
	var stats := PlayerState.stats
	var lv := book.level_of(_selected)
	var sid := _selected

	var actions: Array = []

	# ---------- ปุ่มอัพสกิล ----------
	var blocker := book.learn_blocker(sid, stats)
	if lv >= s.max_level:
		actions.append({"hint": "เลเวลสูงสุดแล้ว (%d/%d)" % [lv, s.max_level],
			"hint_color": UITheme.GOOD})
	else:
		var can := book.can_learn(sid, stats)
		var word: String = "เรียนสกิลนี้" if lv == 0 else "อัพเป็นเลเวล %d" % (lv + 1)
		actions.append({"text": "%s   (ใช้ 1 แต้ม)" % word, "on": func(): _learn(sid),
			"disabled": not can,
			"tooltip": blocker if blocker != "" else "ใช้แต้มสกิล 1 แต้ม"})
		if not can and blocker != "":
			actions.append({"hint": "ยังกดไม่ได้: %s" % blocker, "hint_color": UITheme.BAD})

	# ---------- ปุ่มตั้งช่องลัด ----------
	if lv > 0 and s.type != SkillData.SkillType.PASSIVE:
		var row: Array = []
		for i in range(SkillBook.HOTKEY_COUNT):
			var index := i
			var mark: String = " *" if book.hotkey_at(i) == sid else ""
			row.append({"text": "ช่อง %d%s" % [i + 1, mark], "on": func(): _assign_hotkey(index),
				"tooltip": "ตั้งสกิลนี้ไว้ที่ปุ่ม %d" % (i + 1)})
		actions.append({"hint": "ตั้งไว้ที่ช่องลัด:"})
		actions.append({"row": row})
	elif s.type == SkillData.SkillType.PASSIVE:
		actions.append({"hint": "สกิลติดตัว — ไม่ต้องตั้งช่องลัด"})

	UI.show_info(s.display_name, s.icon, describe(s, lv), self,
		UITheme.ACCENT if lv > 0 else UITheme.TEXT, actions)


## ข้อความรายละเอียดสกิล (BBCode เหมือนกล่องไอเทม)
static func describe(s: SkillData, learned_level: int) -> String:
	var lv: int = maxi(1, learned_level)
	var lines: Array[String] = []

	lines.append("[color=#9aa7bd]ประเภท :[/color] %s" % _type_name(s.type))
	lines.append("[color=#9aa7bd]เลเวลสกิล :[/color] %s%d / %d[/color]"
		% ["[color=#7dffa8]" if learned_level > 0 else "[color=#9aa7bd]",
			learned_level, s.max_level])

	# ---------- เงื่อนไข ----------
	var req := s.requirement_text()
	if req != "":
		var ok: bool = PlayerState.skills.learn_blocker(s.id, PlayerState.stats) == ""
		lines.append("[color=#9aa7bd]เงื่อนไข :[/color] [color=%s]%s[/color]"
			% ["#7dffa8" if ok or learned_level > 0 else "#ff7d7d", req])

	# ---------- ค่าพลังตามชนิดสกิล ----------
	var stats_lines: Array[String] = []
	match s.type:
		SkillData.SkillType.HEAL:
			stats_lines.append("ฟื้นเลือด %d" % s.heal_amount(lv, PlayerState.stats.total_int))
		SkillData.SkillType.BUFF:
			var vals := s.buff_values(lv)
			for k in vals.keys():
				stats_lines.append("%s %+.0f" % [k, vals[k]])
			stats_lines.append("นาน %.0f วินาที" % s.duration(lv))
		SkillData.SkillType.PASSIVE:
			var pv := s.passive_values(lv)
			for k in pv.keys():
				stats_lines.append("%s %+.0f (ติดตัวตลอด)" % [k, pv[k]])
		SkillData.SkillType.ACTIVE_DASH:
			stats_lines.append("ดาเมจ %.0f%% ต่อตัว" % (s.damage_mult(lv) * 100.0))
			stats_lines.append("พุ่งไกล %.0f px" % s.dash_range(lv))
			stats_lines.append("โดนทุกตัวที่ขวางทาง (ตัวละ 1 ครั้ง)")
		_:
			stats_lines.append("ดาเมจ %.0f%%%s"
				% [s.damage_mult(lv) * 100.0,
					"  x%d ครั้ง" % s.hit_count if s.hit_count > 1 else ""])
	if not stats_lines.is_empty():
		var head: String = "ค่าตอนนี้" if learned_level > 0 else "ค่าที่เลเวล 1"
		lines.append("[color=#9aa7bd]%s :[/color]" % head)
		lines.append("[color=#7dffa8]%s[/color]" % "\n".join(stats_lines))

	# ---------- ค่าใช้จ่าย ----------
	if s.type != SkillData.SkillType.PASSIVE:
		lines.append("[color=#9aa7bd]ใช้ SP :[/color] %d        [color=#9aa7bd]คูลดาวน์ :[/color] %.1f วิ"
			% [s.sp_cost(lv), s.cooldown])

	# ---------- คำอธิบาย ----------
	if s.description != "":
		lines.append("")
		lines.append("[color=#c8d0e0]%s[/color]" % s.description)

	return "\n".join(lines)


static func _type_name(t: int) -> String:
	match t:
		SkillData.SkillType.ACTIVE_MELEE: return "โจมตี"
		SkillData.SkillType.ACTIVE_AOE: return "รอบตัว"
		SkillData.SkillType.BUFF: return "บัฟ"
		SkillData.SkillType.HEAL: return "ฟื้นฟู"
		SkillData.SkillType.PASSIVE: return "ติดตัว"
		SkillData.SkillType.ACTIVE_DASH: return "พุ่งฟัน"
	return ""
