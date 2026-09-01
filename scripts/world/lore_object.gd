## LoreObject — ของในแมพที่ "กด F แล้วอ่านได้" (รอบ 30)
##
## ใช้ทำ: ชั้นหนังสือในวิหาร · หลุมศพ · รอยไหม้บนเปลือกไม้ · ป้ายบอกทาง ·
##        เป้สะพายของนักล่าที่หายไป · ศิลาจารึก
##
## ★ วิธีใช้ ★
##   1) ลาก scenes/world/lore_object.tscn เข้าไปวางในแมพ
##   2) ตั้งช่อง Lore Id (ชื่ออะไรก็ได้ แต่ต้องไม่ซ้ำ เช่น "shrine_bookshelf")
##   3) พิมพ์ข้อความลงช่อง Text — เว้นบรรทัดว่าง = ขึ้นหน้าใหม่ในกล่องสนทนา
##   4) ถ้าจะให้มันเดินเควส ให้ใส่เงื่อนไขชนิด READ ในไฟล์เควส แล้วใส่ Target = Lore Id เดียวกัน
##
## อยากให้เห็นรูปด้วย ก็แค่เพิ่ม Sprite2D เป็นลูกของโหนดนี้
class_name LoreObject
extends Area2D

## ★ ชื่อเฉพาะของจุดนี้ ★ ใช้ผูกกับเงื่อนไขเควสชนิด READ และใช้จำว่าอ่านไปแล้ว
@export var lore_id: StringName = &"lore"
## ชื่อที่โชว์บนกล่องสนทนา (เว้นว่าง = ไม่โชว์ชื่อ)
@export var title: String = ""
## ★ ข้อความ ★ เว้นบรรทัดว่าง = ขึ้นหน้าใหม่
@export_multiline var text: String = "..."
## ข้อความชุดที่สอง สำหรับตอนกลับมาอ่านซ้ำ (เว้นว่าง = ใช้ข้อความเดิม)
@export_multiline var text_again: String = ""

@export_group("เงื่อนไขและผลลัพธ์")
## ★ ต้องมีธงนี้ก่อนถึงจะอ่านได้ ★ เว้นว่าง = อ่านได้เลย
@export var required_flag: StringName = &""
## ข้อความตอนที่ยังอ่านไม่ได้
@export var locked_text: String = "ยังไม่มีอะไรน่าสนใจตรงนี้"
## ★ อ่านแล้วตั้งธงนี้ ★ เว้นว่าง = ไม่ตั้ง
@export var set_flag: StringName = &""
## ★ อ่านแล้วได้ไอเทมนี้ ★ (ครั้งแรกครั้งเดียว) เว้นว่าง = ไม่ให้
@export var give_item: StringName = &""
@export var give_item_count: int = 1

@export_group("ข้อความบนหัว")
## ป้ายที่ลอยอยู่เหนือของชิ้นนี้ (เว้นว่าง = ไม่โชว์)
@export var label_text: String = ""
@export var prompt_text: String = "กด F เพื่อดู"

var _player_inside := false
var _prompt: Label
var _label: Label


func _ready() -> void:
	add_to_group("lore_object")
	monitoring = true
	monitorable = false
	if get_node_or_null("Shape") == null and get_child_count() == 0:
		_build_default_shape()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_labels()


func _build_default_shape() -> void:
	var col := CollisionShape2D.new()
	col.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(120, 200)
	col.shape = rect
	add_child(col)


func _build_labels() -> void:
	if label_text != "":
		_label = UITheme.make_label(label_text, 14, UITheme.ACCENT)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_label.add_theme_constant_override("outline_size", 5)
		_label.position = Vector2(-90, -170)
		_label.custom_minimum_size.x = 180
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_label)

	_prompt = UITheme.make_label(prompt_text, 13, Color("#9be7ff"))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 5)
	_prompt.position = Vector2(-90, -140)
	_prompt.custom_minimum_size.x = 180
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.hide()
	add_child(_prompt)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		if _prompt != null:
			_prompt.show()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		if _prompt != null:
			_prompt.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside or UI == null:
		return
	if UI.is_asking() or UI.is_any_window_open():
		return
	if not (event.is_action_pressed("interact") or event.is_action_pressed("pickup")):
		return
	# ★ ของที่ตกอยู่มาก่อน ★ กัน F แย่งกันกับการเก็บของ
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("nearest_pickup") and player.nearest_pickup() != null:
		return
	get_viewport().set_input_as_handled()
	read()


## อ่านของชิ้นนี้ (เรียกจากโค้ดอื่นได้ด้วย)
func read() -> void:
	# ---------- ยังอ่านไม่ได้ ----------
	if required_flag != &"" and not PlayerState.has_flag(required_flag):
		await UI.talk([{"name": title, "text": locked_text}])
		return

	var first_time: bool = not PlayerState.has_flag(_read_flag())
	var body: String = text
	if not first_time and text_again.strip_edges() != "":
		body = text_again

	var pages: Array = []
	for part in body.split("\n\n", false):
		var t := String(part).strip_edges()
		if t != "":
			pages.append({"name": title, "text": t})
	if pages.is_empty():
		pages.append({"name": title, "text": body})
	await UI.talk(pages)

	# ---------- ผลลัพธ์ (ครั้งแรกครั้งเดียว) ----------
	if first_time:
		PlayerState.set_flag(_read_flag())
		if give_item != &"" and give_item_count > 0:
			PlayerState.gain_item_id(give_item, give_item_count)
	if set_flag != &"":
		PlayerState.set_flag(set_flag)

	# ★ เดินความคืบหน้าเควสชนิด READ ★
	if PlayerState.quests != null:
		PlayerState.quests.on_read(lore_id)


## ธงที่ใช้จำว่าอ่านชิ้นนี้ไปแล้ว
func _read_flag() -> StringName:
	return StringName("read_%s" % String(lore_id))
