## Portal — ประตูเชื่อมระหว่างแมพ
##
## ★ พฤติกรรมปกติ (ค่าเริ่มต้น) ★
## เดินผ่านเฉย ๆ = ไม่เกิดอะไรขึ้น เดินผ่านไปได้ตามปกติ
## ยืนอยู่ในประตูจะมีป้าย "กด F" ขึ้นมา กดแล้วถึงจะเปลี่ยนแมพ
##
## โครงสร้าง Scene:
##   Portal (Area2D)  <- ใส่สคริปต์นี้
##   ├── CollisionShape2D  (RectangleShape2D)
##   └── Label             (ป้ายบอกทาง — ไม่ใส่ก็ได้)
extends Area2D

## แมพปลายทาง (ต้องมีใน Game.MAPS)
@export var target_map: StringName = &"prontera_town"
## ไปโผล่ที่ Marker2D ชื่ออะไรในแมพปลายทาง
@export var target_spawn_point: StringName = &"default"
@export var label_text: String = "→ เมือง"
## ชื่อปลายทางที่จะโชว์บนป้าย (เว้นว่าง = ใช้ label_text)
@export var destination_name: String = ""

## true = เด้งกล่องยืนยันขึ้นมาแทนการกด F (ปกติปิดไว้)
@export var require_confirm: bool = false
## ใช้เมื่อ require_confirm = false เท่านั้น
## true = เดินชนแล้วไปเลย / false = ต้องกด F (ค่าเริ่มต้น)
@export var auto_enter: bool = false

var _player_inside := false
var _asked := false
var _entering := false
var _hint: Label


func _ready() -> void:
	add_to_group("portal")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var label := get_node_or_null("Label") as Label
	if label != null:
		label.text = label_text
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 5)

	_build_hint()


## ป้าย "กด F เพื่อไป ..." ลอยเหนือประตู โผล่เฉพาะตอนผู้เล่นยืนอยู่ในประตู
func _build_hint() -> void:
	_hint = Label.new()
	_hint.name = "EnterHint"
	_hint.text = "กด F เพื่อไป %s" % _display_name()
	_hint.visible = false
	_hint.z_index = 30
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.custom_minimum_size = Vector2(260, 0)
	_hint.position = Vector2(-130, -110)
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color("#9be7ff"))
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 6)
	add_child(_hint)


func _process(_delta: float) -> void:
	if _hint != null:
		_hint.visible = _player_inside and not _entering \
			and not require_confirm and not auto_enter


func _display_name() -> String:
	if destination_name != "":
		return destination_name
	return label_text.replace("→", "").strip_edges()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or _entering:
		return
	_player_inside = true

	if require_confirm:
		if _asked:
			return
		_asked = true
		_prompt()
	elif auto_enter:
		_enter()
	# ค่าเริ่มต้น: ไม่ทำอะไรเลย เดินผ่านได้ตามปกติ แล้วโชว์ป้าย "กด F" แทน


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		# ออกจากประตูแล้ว ครั้งหน้าเดินเข้ามาใหม่ถึงจะถามอีก
		_asked = false


func _prompt() -> void:
	var ok: bool = await UI.ask(
		"เปลี่ยนแมพ",
		"ต้องการเดินทางไป\n[ %s ]\nหรือไม่?" % _display_name(),
		"ไปเลย",
		"ยังก่อน"
	)
	if not is_instance_valid(self):
		return
	if ok and _player_inside and not _entering:
		_enter()


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside or _entering:
		return
	if not event.is_action_pressed("interact"):
		return

	# ถ้ามีของตกอยู่ตรงนี้ด้วย ให้ปุ่ม F ไปเก็บของก่อน แล้วค่อยกดซ้ำเพื่อเข้าประตู
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("nearest_pickup") and player.nearest_pickup() != null:
		return

	if require_confirm:
		if not UI.is_asking():
			_asked = true
			_prompt()
	else:
		_enter()


func _enter() -> void:
	_entering = true
	if _hint != null:
		_hint.visible = false
	set_deferred("monitoring", false)
	Game.change_map(target_map, target_spawn_point)
