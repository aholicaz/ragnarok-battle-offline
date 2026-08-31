## StatusWindow — หน้าต่างสเตตัส (กด C)
## อัพ Str / Agi / Vit / Int / Dex / Luk แล้วเห็นผลจริงทันที
class_name StatusWindow
extends GameWindow

const STAT_LABELS := {
	&"str": "STR (พลัง)",
	&"agi": "AGI (ความคล่อง)",
	&"vit": "VIT (ความอึด)",
	&"int": "INT (ปัญญา)",
	&"dex": "DEX (ความแม่นยำ)",
	&"luk": "LUK (โชค)",
}

var _stat_rows: Dictionary = {}   # stat -> { "value": Label, "button": Button, "cost": Label }
var _point_label: Label
var _derived: Dictionary = {}     # key -> Label
var _header: Label


func _ready() -> void:
	window_title = "สเตตัสตัวละคร"
	super._ready()
	custom_minimum_size = Vector2(340, 0)
	Events.stats_changed.connect(refresh)
	Events.level_up.connect(func(_lv): refresh())
	Events.job_level_up.connect(func(_lv): refresh())
	Events.exp_changed.connect(func(_c, _n): refresh())
	Events.job_exp_changed.connect(func(_c, _n): refresh())


func _build_content() -> void:
	_header = UITheme.make_label("", 16, UITheme.ACCENT)
	content.add_child(_header)

	_point_label = UITheme.make_label("", 14, UITheme.GOOD)
	content.add_child(_point_label)
	content.add_child(UITheme.separator())

	# ---------- 6 สเตตัสหลัก ----------
	for stat in PlayerStats.STAT_NAMES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var name_label := UITheme.make_label(STAT_LABELS[stat], 14, UITheme.TEXT)
		name_label.custom_minimum_size.x = 140
		row.add_child(name_label)

		var value_label := UITheme.make_label("1", 15, UITheme.TEXT)
		value_label.custom_minimum_size.x = 70
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value_label)

		var btn := UITheme.make_button("+", 32)
		btn.focus_mode = Control.FOCUS_NONE
		var s: StringName = stat
		btn.pressed.connect(func(): _raise(s))
		row.add_child(btn)

		var cost_label := UITheme.make_label("", 12, UITheme.TEXT_DIM)
		cost_label.custom_minimum_size.x = 28
		row.add_child(cost_label)

		content.add_child(row)
		_stat_rows[stat] = {"value": value_label, "button": btn, "cost": cost_label}

	content.add_child(UITheme.separator())

	# ---------- ค่าที่คำนวณได้ ----------
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	content.add_child(grid)

	var fields := [
		[&"atk", "ATK"], [&"matk", "MATK"],
		[&"def", "DEF"], [&"mdef", "MDEF"],
		[&"hit", "HIT"], [&"flee", "FLEE"],
		[&"crit", "CRIT"], [&"aspd", "ASPD"],
		[&"max_hp", "MaxHP"], [&"max_sp", "MaxSP"],
		[&"speed", "SPEED"], [&"regen", "REGEN"],
	]
	for f in fields:
		var key: StringName = f[0]
		grid.add_child(UITheme.make_label(f[1], 13, UITheme.TEXT_DIM))
		var v := UITheme.make_label("-", 13, UITheme.TEXT)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.custom_minimum_size.x = 60
		grid.add_child(v)
		_derived[key] = v


func _raise(stat: StringName) -> void:
	if PlayerState.raise_stat(stat):
		refresh()
	else:
		Events.say("Stat Point ไม่พอ")


func refresh() -> void:
	if _point_label == null:
		return
	var s := PlayerState.stats

	# ★ Base Level กับ Job Level แยกกัน ★
	_header.text = "%s   Base Lv.%d   Job Lv.%d" % [s.job().display_name, s.level, s.job_level]

	var base_need := s.exp_to_next()
	var job_need := s.job_exp_to_next()
	var base_txt: String = "MAX" if base_need <= 0 else "%d / %d (%.1f%%)" % [
		s.exp_current, base_need, float(s.exp_current) / base_need * 100.0]
	var job_txt: String = "MAX" if job_need <= 0 else "%d / %d (%.1f%%)" % [
		s.job_exp_current, job_need, float(s.job_exp_current) / job_need * 100.0]

	_point_label.text = "Base EXP: %s\nJob EXP: %s\nStat Point เหลือ: %d      Skill Point: %d" % [
		base_txt, job_txt, s.stat_points, s.skill_points]

	for stat in PlayerStats.STAT_NAMES:
		var row: Dictionary = _stat_rows[stat]
		var base := s.get_base_stat(stat)
		var total := s.get_total_stat(stat)
		var bonus := total - base

		if bonus != 0:
			(row.value as Label).text = "%d + %d" % [base, bonus]
			(row.value as Label).add_theme_color_override("font_color", UITheme.GOOD)
		else:
			(row.value as Label).text = str(base)
			(row.value as Label).add_theme_color_override("font_color", UITheme.TEXT)

		var cost := s.stat_cost(stat)
		(row.cost as Label).text = str(cost) if cost > 0 else "MAX"
		(row.button as Button).disabled = not s.can_raise_stat(stat)

	_derived[&"atk"].text = str(s.atk)
	_derived[&"matk"].text = str(s.matk)
	_derived[&"def"].text = str(s.def)
	_derived[&"mdef"].text = str(s.mdef)
	_derived[&"hit"].text = str(s.hit)
	_derived[&"flee"].text = str(s.flee)
	_derived[&"crit"].text = "%.1f%%" % s.crit
	_derived[&"aspd"].text = "%.2f/s" % s.aspd
	_derived[&"max_hp"].text = str(s.max_hp)
	_derived[&"max_sp"].text = str(s.max_sp)
	_derived[&"speed"].text = str(int(s.move_speed))
	_derived[&"regen"].text = "%.1f" % s.hp_regen
