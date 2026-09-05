## ItemInfoPopup — กล่องรายละเอียดไอเทม เด้งข้าง ๆ หน้าต่างที่กดมา (สไตล์ Ragnarok)
##
## เรียกใช้: UI.show_item(inst, หน้าต่างที่กดมา)  หรือ  UI.show_item_data(item_data, หน้าต่าง)
## กดที่ไอเทมในกระเป๋า / ร้านค้า / ช่องสวมใส่ แล้วกล่องนี้จะโผล่ข้าง ๆ
##
## โครงสร้าง:
##   ItemInfoPopup (PanelContainer)
##   ├── หัวเรื่อง: ชื่อไอเทม + ปุ่มปิด
##   └── HBox: [กรอบรูปใหญ่] [รายละเอียด (เลื่อนได้)]
class_name ItemInfoPopup
extends PanelContainer

## ขนาดกรอบรูปด้านซ้าย
const ART_SIZE := Vector2(120, 120)
## ความกว้างรวมของกล่อง
const BOX_WIDTH := 380.0
## ความสูงสูงสุดก่อนจะมีแถบเลื่อน
const MAX_HEIGHT := 280.0
## เว้นจากขอบหน้าต่างที่กดมากี่พิกเซล
const GAP := 8.0

var _title: Label
var _art: TextureRect
var _art_frame: PanelContainer
var _detail: RichTextLabel
var _scroll: ScrollContainer
var _anchor: Control = null
var _open := false
## ★ แถวปุ่มการกระทำด้านล่างกล่อง ★ (เช่น "อัพสกิล" / "ตั้งปุ่มลัด")
var _action_box: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	z_index = 150
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(BOX_WIDTH, 0)
	add_theme_stylebox_override("panel",
		UITheme.panel_style(Color("#161b28f2"), UITheme.ACCENT, 8))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	# ---------- หัวเรื่อง ----------
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	box.add_child(head)

	_title = UITheme.make_label("", 16, UITheme.ACCENT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(_title)

	var close := UITheme.make_button("✕")
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(hide_popup)
	head.add_child(close)

	box.add_child(UITheme.separator())

	# ---------- รูป + รายละเอียด ----------
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)

	_art_frame = PanelContainer.new()
	_art_frame.custom_minimum_size = ART_SIZE
	_art_frame.add_theme_stylebox_override("panel", UITheme.slot_style())
	row.add_child(_art_frame)

	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_frame.add_child(_art)

	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.custom_minimum_size = Vector2(BOX_WIDTH - ART_SIZE.x - 40.0, ART_SIZE.y)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)

	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.fit_content = true
	_detail.scroll_active = false
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_font_size_override("normal_font_size", 13)
	_detail.add_theme_font_size_override("bold_font_size", 13)
	scroll.add_child(_detail)

	# ---------- แถวปุ่มการกระทำ (ว่างไว้ก่อน หน้าต่างไหนอยากใส่ค่อยส่งมา) ----------
	_action_box = VBoxContainer.new()
	_action_box.name = "Actions"
	_action_box.add_theme_constant_override("separation", 4)
	_action_box.visible = false
	box.add_child(_action_box)


func is_open() -> bool:
	return _open


# =========================================================
# ★ ปุ่มการกระทำ ★
# ส่งมาเป็นรายการ Dictionary:
#   {"text": "อัพสกิล", "on": Callable, "disabled": bool, "hint": "ข้อความใต้ปุ่ม",
#    "row": [ {...}, {...} ]  <- ใส่หลายปุ่มในแถวเดียว}
# =========================================================
func set_actions(actions: Array) -> void:
	if _action_box == null:
		return
	for c in _action_box.get_children():
		_action_box.remove_child(c)
		c.queue_free()
	_action_box.visible = not actions.is_empty()
	for a in actions:
		if a.has("hint"):
			var hint := UITheme.make_label(String(a.hint), 11,
				a.get("hint_color", UITheme.TEXT_DIM))
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_action_box.add_child(hint)
			continue
		if a.has("row"):
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 5)
			_action_box.add_child(row)
			for b in a.row:
				row.add_child(_make_action_button(b, true))
			continue
		_action_box.add_child(_make_action_button(a, false))


func _make_action_button(a: Dictionary, in_row: bool) -> Button:
	var btn := Button.new()
	btn.text = String(a.get("text", ""))
	btn.focus_mode = Control.FOCUS_NONE
	btn.disabled = bool(a.get("disabled", false))
	btn.tooltip_text = String(a.get("tooltip", ""))
	btn.custom_minimum_size.y = 30.0
	btn.add_theme_font_size_override("font_size", 13)
	if in_row:
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if a.has("on"):
		btn.pressed.connect(a.on)
	return btn


# =========================================================
# เปิดกล่อง
# =========================================================
## โชว์รายละเอียดของไอเทมชิ้นจริงในกระเป๋า (มีตีบวก/การ์ดที่ใส่ไว้ด้วย)
const BUFF_LABELS := {
	"atk_percent": "ATK", "matk_percent": "MATK", "def_percent": "DEF", "max_hp_percent": "MaxHP",
	"max_sp_percent": "MaxSP", "aspd_percent": "ความเร็วโจมตี", "move_speed_percent": "ความเร็วเดิน",
	"crit_damage_percent": "ดาเมจคริ", "damage_percent": "ดาเมจ", "atk": "ATK", "def": "DEF", "hit": "HIT", "flee": "FLEE",
	"cooldown_reduction_percent": "ลดคูลดาวน์",
}


func show_item(inst: ItemInstance, anchor: Control = null, extra: String = "") -> void:
	if inst == null:
		hide_popup()
		return
	var d := inst.data()
	if d == null:
		hide_popup()
		return
	_show(inst.display_name(), _texture_for(d), describe(d, inst, extra), anchor,
		UITheme.ACCENT if inst.refine > 0 else UITheme.TEXT)


## โชว์รายละเอียดจากแม่แบบไอเทม (ใช้ในร้านค้า ตอนของยังไม่ได้เป็นของเรา)
func show_data(d: ItemData, anchor: Control = null, extra: String = "") -> void:
	if d == null:
		hide_popup()
		return
	_show(d.display_name, _texture_for(d), describe(d, null, extra), anchor, UITheme.TEXT)


## ★ ใช้กับอย่างอื่นที่ไม่ใช่ไอเทม (เช่นสกิล) ★ ส่งปุ่มการกระทำมาด้วยได้
func show_info(title: String, art: Texture2D, body: String, anchor: Control = null,
		color: Color = UITheme.TEXT, actions: Array = []) -> void:
	_show(title, art, body, anchor, color, actions)


func _show(title: String, art: Texture2D, body: String, anchor: Control, color: Color,
		actions: Array = []) -> void:
	set_actions(actions)
	_title.text = title
	_title.add_theme_color_override("font_color", color)
	_art.texture = art
	_art_frame.visible = art != null
	_detail.text = body
	_anchor = anchor
	_open = true
	visible = true
	move_to_front()
	_reposition()
	_reposition.call_deferred()   # ขนาดกล่องจะนิ่งหลังจัดวางเสร็จ จึงวางอีกรอบ


func hide_popup() -> void:
	_open = false
	visible = false
	_anchor = null


# =========================================================
# ตำแหน่ง — เกาะข้างหน้าต่างที่กดมา
# =========================================================
func _process(_delta: float) -> void:
	if _open:
		# หน้าต่างต้นทางถูกปิด/ลากย้าย ก็ให้ตามไปด้วย
		if _anchor != null and (not is_instance_valid(_anchor) or not _anchor.visible):
			hide_popup()
			return
		_reposition()


## ปรับความสูงกล่องตามเนื้อหา — ยาวมากก็หยุดที่ MAX_HEIGHT แล้วเลื่อนอ่านเอา
## (Control ที่ไม่ได้อยู่ในคอนเทนเนอร์จะไม่หดเอง ต้องสั่งเอง ไม่งั้นกล่องค้างขนาดเดิม)
func _fit_size() -> void:
	if _scroll == null or _detail == null:
		return
	var body_h := _detail.get_combined_minimum_size().y
	var want_h := clampf(body_h + 4.0, ART_SIZE.y, MAX_HEIGHT)
	if absf(_scroll.custom_minimum_size.y - want_h) > 0.5:
		_scroll.custom_minimum_size.y = want_h
	size = Vector2(BOX_WIDTH, get_combined_minimum_size().y)


func _reposition() -> void:
	_fit_size()
	var vp := get_viewport_rect().size
	var want := position

	if _anchor != null and is_instance_valid(_anchor):
		# ลองวางด้านขวาของหน้าต่างก่อน ถ้าล้นจอค่อยย้ายไปด้านซ้าย
		want.x = _anchor.global_position.x + _anchor.size.x + GAP
		want.y = _anchor.global_position.y
		if want.x + size.x > vp.x - 4.0:
			want.x = _anchor.global_position.x - size.x - GAP
	else:
		want = (vp - size) * 0.5

	# ไม่ให้หลุดขอบจอ
	want.x = clampf(want.x, 4.0, maxf(4.0, vp.x - size.x - 4.0))
	want.y = clampf(want.y, 4.0, maxf(4.0, vp.y - size.y - 4.0))
	position = want


# =========================================================
# ข้อความรายละเอียด (ใช้ร่วมกันทุกหน้าต่าง)
# =========================================================
## สร้างข้อความรายละเอียดไอเทม — ส่ง inst มาด้วยถ้าอยากได้ค่าตีบวก/การ์ดที่ใส่ไว้
static func describe(d: ItemData, inst: ItemInstance = null, extra: String = "") -> String:
	if d == null:
		return ""
	var lines: Array[String] = []

	if extra != "":
		lines.append("[color=#ffe9a0]%s[/color]" % extra)

	lines.append("[color=#9aa7bd]ประเภท :[/color] %s" % _type_name(d))

	# ---------- ระดับที่ต้องใช้ ----------
	if d.required_level > 1:
		var lv: int = PlayerState.stats.level if PlayerState.stats != null else 1
		var ok: bool = lv >= d.required_level
		lines.append("[color=#9aa7bd]ต้องการเลเวล :[/color] [color=%s]%d%s[/color]"
			% ["#7dffa8" if ok else "#ff7d7d", d.required_level,
			"" if ok else "  (ยังไม่ถึง — เลเวลคุณ %d)" % lv])

	# ---------- ค่าพลัง ----------
	var stats: Array[String] = []
	var atk: int = inst.total_atk() if inst != null else d.atk
	var def_v: int = inst.total_def() if inst != null else d.def
	if d.type == ItemData.Type.WEAPON:
		stats.append("[color=#9aa7bd]พลังโจมตี :[/color] %d" % atk)
	elif atk != 0:
		stats.append("[color=#9aa7bd]พลังโจมตี :[/color] %+d" % atk)
	if def_v != 0:
		stats.append("[color=#9aa7bd]พลังป้องกัน :[/color] %d" % def_v)
	# ★ รอบ 57 ★ ของดรอปมีโบนัส — โชว์ค่าที่คูณแล้ว (ของร้าน bonus = 0 จึงเท่าเดิม)
	var bp: float = inst.bonus_percent if inst != null else 0.0
	var bst := func(v: int) -> int: return inst.boosted(v) if inst != null else v
	if d.matk != 0: stats.append("MATK %+d" % bst.call(d.matk))
	if d.mdef != 0: stats.append("MDEF %+d" % bst.call(d.mdef))
	if d.hit != 0: stats.append("HIT %+d" % bst.call(d.hit))
	if d.flee != 0: stats.append("FLEE %+d" % bst.call(d.flee))
	if d.crit != 0: stats.append("CRIT %+d" % bst.call(d.crit))
	if d.max_hp != 0: stats.append("MaxHP %+d" % bst.call(d.max_hp))
	if d.max_sp != 0: stats.append("MaxSP %+d" % bst.call(d.max_sp))
	if d.aspd_percent != 0.0: stats.append("ASPD %+.0f%%" % d.aspd_percent)
	for pair in [["STR", d.bonus_str], ["AGI", d.bonus_agi], ["VIT", d.bonus_vit],
			["INT", d.bonus_int], ["DEX", d.bonus_dex], ["LUK", d.bonus_luk]]:
		if int(pair[1]) != 0:
			stats.append("%s %+d" % [pair[0], bst.call(int(pair[1]))])
	if bp > 0.0:
		stats.append("[color=#ffd54a]★ ของดรอป : ค่าพลังดีกว่าของร้าน +%s%%[/color]"
			% ItemInstance._pct_text(bp))
	if d.heal_hp != 0 or d.heal_hp_percent != 0.0:
		stats.append("ฟื้น HP %d (+%.0f%%)" % [d.heal_hp, d.heal_hp_percent])
	if d.heal_sp != 0 or d.heal_sp_percent != 0.0:
		stats.append("ฟื้น SP %d (+%.0f%%)" % [d.heal_sp, d.heal_sp_percent])
	# ★ รอบ 65 — คูลดาวน์ยา ★ ยาฟื้นเยอะยิ่งรอนาน (5-10 วิ)
	var pot_cd := PlayerState.potion_cooldown_of(d)
	if pot_cd > 0.0:
		var pot_left := PlayerState.potion_cooldown_left_for(d)
		if pot_left > 0.0:
			stats.append("[color=#ff9a6a]คูลดาวน์ %.1f วินาที (รออีก %.1f วิ)[/color]" % [pot_cd, pot_left])
		else:
			stats.append("[color=#9aa7bd]คูลดาวน์ %.1f วินาที[/color]" % pot_cd)
	# ★ รอบ 45 — โบนัส % / บัฟไอเทม / ไอเทมพิเศษ ★
	for pair in [["ดาเมจ", d.damage_percent], ["ป้องกัน", d.defense_percent], ["HP สูงสุด", d.hp_percent],
			["SP สูงสุด", d.sp_percent], ["ดูดเลือด", d.hp_drain_percent], ["ดูดมานา", d.sp_drain_percent],
			["ลดคูลดาวน์", d.cooldown_reduction_percent]]:
		if float(pair[1]) != 0.0:
			stats.append("%s %+.1f%%" % [pair[0], float(pair[1])])
	if d.buff_duration > 0.0 and not d.buff_values.is_empty():
		var bparts: Array = []
		for key in d.buff_values.keys():
			bparts.append("%s %+.0f%s" % [BUFF_LABELS.get(String(key), String(key)), float(d.buff_values[key]),
				"%" if String(key).ends_with("_percent") else ""])
		stats.append("บัฟ: %s (%d วินาที)" % [", ".join(bparts), int(d.buff_duration)])
	if d.special_effect == &"reset_skills":
		stats.append("ใช้แล้วรีเซ็ตสกิลทั้งหมด (คืนแต้มสกิล)")
	elif d.special_effect == &"reset_stats":
		stats.append("ใช้แล้วรีเซ็ตสเตตัสทั้งหมด (คืนแต้มสเตตัส)")
	elif d.special_effect == &"warp_town":
		stats.append("ใช้แล้ววาปกลับ%s (ใช้ในเมืองไม่ได้)" % Game.map_display_name(PlayerState.home_town()))
	if not stats.is_empty():
		lines.append("[color=#7dffa8]%s[/color]" % "\n".join(stats))

	# ---------- ตีบวก ----------
	if d.refinable:
		var lv: int = inst.refine if inst != null else 0
		lines.append("[color=#9aa7bd]ตีบวก :[/color] +%d / +%d" % [lv, d.max_refine])

	# ---------- ช่องการ์ด ----------
	# ของที่ซื้อจากร้านไม่มีช่อง · ของที่ดรอปจากมอนถึงจะมี
	var have_slots: int = inst.card_slots() if inst != null else 0
	if have_slots > 0:
		lines.append("[color=#9aa7bd]ช่องการ์ด :[/color] %d/%d" % [inst.cards.size(), have_slots])
		if inst != null:
			for card in inst.card_list():
				lines.append("  [color=%s]◆ %s[/color] — %s"
					% [card.rarity_color().to_html(false), card.display_name,
					card.describe().replace("\n", ", ")])

	if inst != null and have_slots == 0 and d.card_slots > 0:
		lines.append("[color=#9aa7bd]ช่องการ์ด :[/color] [color=#ff9a9a]ไม่มี[/color]"
			+ "  [color=#7b8496](ของจากร้านค้าไม่มีช่อง)[/color]")
	elif inst == null and d.card_slots > 0:
		lines.append("[color=#9aa7bd]ช่องการ์ด :[/color] [color=#ff9a9a]ไม่มี[/color]"
			+ "  [color=#7b8496](สูงสุด %d ช่อง ถ้าดรอปจากมอนสเตอร์)[/color]" % d.card_slots)

	# ---------- การ์ด ----------
	if d is CardData:
		var c := d as CardData
		lines.append("[color=#9aa7bd]ใส่ใน :[/color] %s" % c.slot_name())
		lines.append("[color=#7dffa8]%s[/color]" % c.describe())

	# ---------- คำอธิบาย ----------
	if d.description != "":
		lines.append("")
		lines.append("[color=#c8d0e0]%s[/color]" % d.description)

	# ---------- ราคา ----------
	lines.append("")
	lines.append("[color=#9aa7bd]ราคาขาย :[/color] [color=#ffe9a0]%d z[/color]" % d.sell_price)

	return "\n".join(lines)


static func _type_name(d: ItemData) -> String:
	match d.type:
		ItemData.Type.WEAPON:
			return "อาวุธ" + ("" if d.weapon_type == &"" else " (%s)" % String(d.weapon_type))
		ItemData.Type.ARMOR:
			return _slot_name(d.slot)
		ItemData.Type.CONSUMABLE:
			return "ของใช้"
		ItemData.Type.MATERIAL:
			return "วัตถุดิบ"
		ItemData.Type.QUEST:
			return "ของเควส"
		ItemData.Type.CARD:
			return "การ์ดมอนสเตอร์"
	return "ไอเทม"


static func _slot_name(slot: int) -> String:
	match slot:
		ItemData.Slot.HEAD: return "ของสวมศีรษะ"
		ItemData.Slot.ARMOR: return "ชุดเกราะ"
		ItemData.Slot.GARMENT: return "ผ้าคลุม"
		ItemData.Slot.SHOES: return "รองเท้า"
		ItemData.Slot.ACCESSORY: return "เครื่องประดับ"
		ItemData.Slot.OFFHAND: return "โล่ / อาวุธมือรอง"
	return "ของสวมใส่"


## รูปที่จะโชว์ — ไอคอนของไอเทม ถ้าเป็นการ์ดที่ยังไม่มีไอคอนก็ใช้ภาพการ์ด
static func _texture_for(d: ItemData) -> Texture2D:
	if d.icon != null:
		return d.icon
	if d is CardData:
		return CardView.card_texture(d as CardData)
	return null


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("close_windows"):
		hide_popup()
		get_viewport().set_input_as_handled()
