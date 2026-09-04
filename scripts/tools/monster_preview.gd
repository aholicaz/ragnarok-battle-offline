## MonsterPreview — ฉากดูมอน 1 ตัว (รอบ 54)
##
## ★ ใช้ 2 แบบ ★
##  1) เปิดแท็บฉากนี้ใน Godot → คลิก AnimatedSprite2D → แถบล่างโชว์ "เฟรมแอนิเมชัน" ของมอนตัวนี้
##     (เหมือนหน้า player) แก้เฟรม/ความเร็ว/เพิ่มท่าตรงนั้นได้เลย = แก้ไฟล์ data/sprites/monsters/<id>_frames.tres
##     ที่มอนตัวจริงใช้อยู่ (ไม่ต้องก็อปไปไหน)
##  2) กด "เล่นฉากปัจจุบัน" (F6 / ปุ่ม ▶ กับตัวหนัง) → เกิดมอนตัวจริงบนพื้นจำลอง
##     เห็นการบิน/โยก/เดิน/พัก แบบเดียวกับในเกม + เงาผู้เล่นสูง 240 ไว้เทียบระดับสายตา
##
## สร้างฉากนี้ด้วย  python3 make_monster_preview.py <id>   (เช่น hornet)
extends Node2D

## id ของมอน (ไฟล์ data/monsters/<id>.tres)
@export var monster_id: StringName = &"hornet"
## ความสูงผู้เล่นไว้เทียบ (เท่ากับ auto_fit_height ของ player)
@export var player_height: float = 240.0
## ระดับสายตาผู้เล่น (วัดจากพื้น)
@export var eye_level: float = 190.0

var _monster: Node = null
var _label: Label


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# ซ่อนสไปรท์ตัวอย่างของฉาก (ไว้ให้ editor โชว์เฟรมเฉย ๆ) แล้วเกิดมอนตัวจริงแทน
	var preview := get_node_or_null("AnimatedSprite2D")
	if preview != null:
		preview.hide()

	# ซ่อน HUD/ปุ่มของเกม (autoload UI) — ฉากนี้ดูมอนอย่างเดียว
	var ui := get_node_or_null("/root/UI")
	if ui != null and "layer" in ui and ui.layer != null:
		ui.layer.visible = false
	var touch := get_node_or_null("/root/TouchControls")
	if touch != null and "visible" in touch:
		touch.visible = false

	_build_stage()
	_spawn_monster()
	_build_hud()


func _build_stage() -> void:
	# พื้น
	var ground := StaticBody2D.new()
	ground.name = "Ground"
	ground.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 60)
	shape.shape = rect
	shape.position = Vector2(0, 30)
	ground.add_child(shape)
	ground.position = Vector2(0, 0)
	add_child(ground)

	var floor_draw := ColorRect.new()
	floor_draw.color = Color(0.22, 0.26, 0.2)
	floor_draw.position = Vector2(-2000, 0)
	floor_draw.size = Vector2(4000, 400)
	floor_draw.z_index = -10
	add_child(floor_draw)

	var bg := ColorRect.new()
	bg.color = Color(0.14, 0.16, 0.22)
	bg.position = Vector2(-2000, -1200)
	bg.size = Vector2(4000, 1200)
	bg.z_index = -11
	add_child(bg)

	# เงาผู้เล่นไว้เทียบขนาด (ซ้ายของมอน)
	var silhouette := ColorRect.new()
	silhouette.color = Color(0.3, 0.55, 0.9, 0.35)
	silhouette.size = Vector2(70, player_height)
	silhouette.position = Vector2(-260, -player_height)
	add_child(silhouette)
	var eye := ColorRect.new()
	eye.color = Color(1, 0.85, 0.3, 0.9)
	eye.size = Vector2(700, 2)
	eye.position = Vector2(-260, -eye_level)
	add_child(eye)
	var eye_lbl := Label.new()
	eye_lbl.text = "ระดับสายตาผู้เล่น (%d px)" % int(eye_level)
	eye_lbl.position = Vector2(180, -eye_level - 22)
	eye_lbl.add_theme_font_size_override("font_size", 14)
	add_child(eye_lbl)
	var p_lbl := Label.new()
	p_lbl.text = "ผู้เล่น\n%d px" % int(player_height)
	p_lbl.position = Vector2(-255, -player_height + 6)
	p_lbl.add_theme_font_size_override("font_size", 14)
	add_child(p_lbl)

	var cam := Camera2D.new()
	cam.position = Vector2(0, -180)
	cam.zoom = Vector2(1.0, 1.0)
	add_child(cam)
	cam.make_current()


func _spawn_monster() -> void:
	var data_path := "res://data/monsters/%s.tres" % monster_id
	if not ResourceLoader.exists(data_path):
		push_error("[MonsterPreview] ไม่พบ %s" % data_path)
		return
	var scene: PackedScene = load("res://scenes/monsters/monster.tscn")
	_monster = scene.instantiate()
	_monster.data = load(data_path)
	_monster.position = Vector2(60, -20)
	add_child(_monster)
	if _monster.has_method("set_home"):
		_monster.set_home(_monster.global_position)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(12, 8)
	_label.add_theme_font_size_override("font_size", 16)
	layer.add_child(_label)
	var help := Label.new()
	help.text = "R = เกิดใหม่ · Space = โดนตี (ลดเลือด) · K = ฆ่า · Esc = ปิด"
	help.position = Vector2(12, 690)
	help.add_theme_font_size_override("font_size", 14)
	layer.add_child(help)


func _process(_dt: float) -> void:
	if _label == null:
		return
	if _monster == null or not is_instance_valid(_monster):
		_label.text = "%s — (ตายแล้ว) กด R เกิดใหม่" % monster_id
		return
	var sp: AnimatedSprite2D = _monster.get_node_or_null("AnimatedSprite2D")
	var d = _monster.data
	var lift: float = _monster.hover_lift() if _monster.has_method("hover_lift") else 0.0
	_label.text = "%s (%s)   ท่า %s เฟรม %d/%d %s   HP %d/%d\nบิน: %s  สูง %.0f px  โยก ±%.0f  %.1f รอบ/วิ   ลอยตอนนี้ %.0f px   state %d" % [
		monster_id, d.display_name, sp.animation, sp.frame + 1,
		sp.sprite_frames.get_frame_count(sp.animation) if sp.sprite_frames else 0,
		"▶" if sp.is_playing() else "⏸ ไม่เล่น!",
		_monster.hp, d.max_hp,
		"ใช่" if d.flying else "ไม่", d.hover_height, d.hover_bob, d.hover_bob_speed, lift, _monster.state]


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	var k := event as InputEventKey
	if k.keycode == KEY_R:
		if _monster != null and is_instance_valid(_monster):
			_monster.queue_free()
		_spawn_monster()
	elif k.keycode == KEY_SPACE and _monster != null and is_instance_valid(_monster):
		if _monster.has_method("take_damage_from_player"):
			_monster.take_damage_from_player(0.3, false, 1)
	elif k.keycode == KEY_K and _monster != null and is_instance_valid(_monster):
		if _monster.has_method("take_damage_from_player"):
			for i in range(40):
				_monster.take_damage_from_player(5.0, false, 1)
	elif k.keycode == KEY_ESCAPE:
		get_tree().quit()
