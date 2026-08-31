## Game — ตัวจัดการฉาก/การเปลี่ยนแมพ (Autoload ชื่อ "Game")
## หมายเหตุ: ไฟล์นี้ห้ามใส่ class_name เพราะจะชนกับชื่อ Autoload
extends Node

## ทะเบียนแมพทั้งหมด: id -> path ของไฟล์ .tscn
## เพิ่มแมพใหม่ = เพิ่ม 1 บรรทัดตรงนี้
const MAPS := {
	&"prontera_town": "res://scenes/maps/prontera_town.tscn",
	# ★ แมพนี้คือฉากที่คุณทำเอง (พื้นหลัง + TileMap ของคุณ)
	&"prontera_field": "res://Sprites/world_node_2d.tscn",
	## ★ แมพใหม่ ★ Asgard Forest 2 (ต่อจากทุ่งของคุณไปทางขวา)
	&"asgard_forest_2": "res://scenes/maps/asgard_forest_2.tscn",
	&"dark_forest": "res://scenes/maps/dark_forest.tscn",
}

var _spawn_point_name: StringName = &"default"
var _is_changing := false
var _fade: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.ensure()
	_build_fade()


func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


## ชื่อจุดเกิดที่แมพปลายทางควรวางผู้เล่นไว้
func requested_spawn_point() -> StringName:
	return _spawn_point_name


func change_map(map_id: StringName, spawn_point: StringName = &"default") -> void:
	if _is_changing:
		return
	var path: String = MAPS.get(map_id, "")
	if path == "":
		push_error("[Game] ไม่รู้จักแมพ: " + String(map_id))
		return

	_is_changing = true
	_spawn_point_name = spawn_point
	PlayerState.current_map_id = map_id

	await _fade_to(1.0, 0.25)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	Events.map_changed.emit(map_id)
	await _fade_to(0.0, 0.3)
	_is_changing = false


func reload_map() -> void:
	await change_map(PlayerState.current_map_id, _spawn_point_name)


func _fade_to(alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, duration)
	await tween.finished


## เรียกตอนผู้เล่นตาย: กลับเมืองพร้อมฟื้นเลือดครึ่งหนึ่ง
func respawn_in_town() -> void:
	PlayerState.revive(0.5)
	await change_map(&"prontera_town", &"default")
