## QuestWindow — สมุดเควส (กด U)
## โชว์เควสที่กำลังทำ ความคืบหน้า และเควสที่ทำเสร็จแล้ว
class_name QuestWindow
extends GameWindow

var _list: VBoxContainer
var _empty: Label


func _ready() -> void:
	window_title = "สมุดเควส"
	super._ready()
	custom_minimum_size = Vector2(420, 260)
	Events.quest_changed.connect(refresh)
	Events.stats_changed.connect(refresh)


func _build_content() -> void:
	content.add_child(UITheme.make_label(
		"คุยกับ NPC ที่มีเครื่องหมาย ! เพื่อรับเควส  ·  ? = เอาไปส่งได้แล้ว",
		12, UITheme.TEXT_DIM))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 300
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	_empty = UITheme.make_label("ยังไม่มีเควส — ลองไปคุยกับ NPC ในเมืองดู", 13, UITheme.TEXT_DIM)
	content.add_child(_empty)


func refresh() -> void:
	if _list == null:
		return
	GameWindow.clear_container(_list)

	var log := PlayerState.quests
	if log == null:
		return

	var shown := 0

	# ---------- กำลังทำ ----------
	for qid in log.active:
		var q := GameData.get_quest(qid)
		if q == null:
			continue
		shown += 1
		_add_row(q, log.count_of(qid), log.is_ready(qid), false)

	# ---------- ทำเสร็จแล้ว ----------
	if not log.completed.is_empty():
		_list.add_child(UITheme.separator())
		_list.add_child(UITheme.make_label("เควสที่ทำเสร็จแล้ว", 12, UITheme.TEXT_DIM))
		for qid in log.completed:
			var q := GameData.get_quest(qid)
			if q == null:
				continue
			shown += 1
			_add_row(q, q.kill_count, false, true)

	_empty.visible = shown == 0


func _add_row(q: QuestData, progress: int, ready: bool, done: bool) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.slot_style(ready))
	_list.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	var head := HBoxContainer.new()
	box.add_child(head)

	var title_color: Color = UITheme.TEXT_DIM if done else (UITheme.GOOD if ready else UITheme.ACCENT)
	var title := UITheme.make_label(q.title, 14, title_color)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)

	var tag_text := "เสร็จแล้ว" if done else ("ส่งได้แล้ว!" if ready else "กำลังทำ")
	head.add_child(UITheme.make_label(tag_text, 11, title_color))

	box.add_child(UITheme.make_label("จาก: %s" % q.giver_name, 11, UITheme.TEXT_DIM))

	# ---------- ★ ความคืบหน้า (รองรับหลายเงื่อนไข) ★ ----------
	var steps := q.steps()
	for i in range(steps.size()):
		var o: ObjectiveData = steps[i]
		var got: int = o.need() if done else PlayerState.quests.count_of(q.id, i)
		var step_ok: bool = done or got >= o.need()

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		box.add_child(row)

		var obj := UITheme.make_label(o.line(got), 12,
			UITheme.TEXT_DIM if done else (UITheme.GOOD if step_ok else UITheme.TEXT))
		obj.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(obj)

		# แถบความคืบหน้าโชว์เฉพาะเงื่อนไขที่ต้องทำหลายครั้ง
		if o.need() > 1:
			var bar := UITheme.make_bar(UITheme.GOOD if step_ok else UITheme.EXP, 12)
			bar.custom_minimum_size = Vector2(140, 12)
			bar.max_value = o.need()
			bar.value = mini(got, o.need())
			row.add_child(bar)

	box.add_child(UITheme.make_label("รางวัล: %s" % q.reward_text(), 11, Color("#ffe9a0")))
