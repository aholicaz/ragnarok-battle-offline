## Game — ตัวจัดการฉาก/การเปลี่ยนแมพ (Autoload ชื่อ "Game")
## หมายเหตุ: ไฟล์นี้ห้ามใส่ class_name เพราะจะชนกับชื่อ Autoload
extends Node

## ทะเบียนแมพทั้งหมด: id -> path ของไฟล์ .tscn
## เพิ่มแมพใหม่ = เพิ่ม 1 บรรทัดตรงนี้
const MAPS := {
	&"prontera_town": "res://scenes/maps/prontera_town.tscn",
	# ★ แมพนี้คือฉากที่คุณทำเอง (พื้นหลัง + TileMap ของคุณ)
	# รอบ 40: ย้ายจาก Sprites/world_node_2d.tscn มาไว้ให้ถูกที่ถูกชื่อ
	&"prontera_field": "res://scenes/maps/prontera_field.tscn",
	## ★ แมพใหม่ ★ Asgard Forest 2 (ต่อจากทุ่งของคุณไปทางขวา)
	&"asgard_forest_2": "res://scenes/maps/asgard_forest_2.tscn",
	&"dark_forest": "res://scenes/maps/dark_forest.tscn",
	## ★ บทที่ 2 — สวาร์ทัลฟ์เฮม (รอบ 31) ★
	&"iron_road": "res://scenes/maps/iron_road.tscn",
	&"nidavellir_town": "res://scenes/maps/nidavellir_town.tscn",
	&"ember_mine": "res://scenes/maps/ember_mine.tscn",
	&"hall_of_silence": "res://scenes/maps/hall_of_silence.tscn",
	&"cold_forge": "res://scenes/maps/cold_forge.tscn",
	## ★ ลานบอสบทที่ 1 (รอบ 38) ★
	&"thunder_scar": "res://scenes/maps/thunder_scar.tscn",
	## ★ ป่าเงาลึกชั้นใน (รอบ 44) — มอนบท 1 ที่เหลือ + บาฟโฟเมทเฝ้าทางไปบท 2 ★
	&"dark_forest_2": "res://scenes/maps/dark_forest_2.tscn",
}

var _spawn_point_name: StringName = &"default"
var _is_changing := false
var _fade: ColorRect
var _loading_label: Label
## ฉากเปล่าที่ใช้คั่นระหว่างโหลดแมพ (ปล่อยแมพเก่าทิ้งก่อน แล้วค่อยโหลดแมพใหม่)
var _loading_scene: PackedScene

## ★ รอบ 40 — จำแมพที่เคยโหลดไว้ (เข้า-ออกแมพเดิมไม่ต้องโหลดซ้ำ = ไม่กระตุก) ★
## เก็บสูงสุด MAX_CACHED แมพล่าสุด กันกินแรมเกินไป (แมพทุ่งวิหารตัวเดียวมีภาพ ~12 MB)
const MAX_CACHED := 4
var _scene_cache: Dictionary = {}      # path -> PackedScene
var _cache_order: Array[String] = []


## ★ รอบ 52 — เพลงประจำแมพ ★ เรียกใช้ผ่าน Game.music (ดู scripts/core/music_player.gd)
var music: MusicPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.ensure()
	_build_fade()
	music = MusicPlayer.new()
	add_child(music)
	var loading_root := Node.new()
	loading_root.name = "Loading"
	_loading_scene = PackedScene.new()
	_loading_scene.pack(loading_root)
	loading_root.free()


func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)

	# ป้าย "กำลังโหลด..." โผล่เฉพาะตอนโหลดแมพที่ยังไม่เคยโหลดจริง ๆ
	_loading_label = Label.new()
	_loading_label.text = "กำลังโหลด..."
	_loading_label.add_theme_font_size_override("font_size", 22)
	_loading_label.add_theme_color_override("font_color", Color("#e8e2d0"))
	_loading_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_loading_label.offset_left = -220
	_loading_label.offset_top = -60
	_loading_label.offset_right = -28
	_loading_label.offset_bottom = -24
	_loading_label.hide()
	layer.add_child(_loading_label)


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
	# ★★ รอบ 40 — โหลดแมพแบบเบื้องหลัง (ไม่ค้างเกมระหว่างอ่านไฟล์ภาพใหญ่) ★★
	# ★ ต้องสลับไปฉากเปล่าก่อนโหลด ★ ถ้าปล่อยแมพเก่าทำงานระหว่างโหลดเธรด
	# ตัวโหลดจะแย่งแตะรีซอร์สชุดเดียวกันแล้วแครช (signal 11 — เจอตอนเทสต์รอบ 40)
	if not _scene_cache.has(path):
		get_tree().change_scene_to_packed(_loading_scene)
		await get_tree().process_frame
		await get_tree().process_frame
	var scene: PackedScene = await _load_map_scene(path)
	if scene == null:
		push_error("[Game] โหลดแมพไม่สำเร็จ: " + path)
		_is_changing = false
		await _fade_to(0.0, 0.2)
		return
	get_tree().change_scene_to_packed(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	Events.map_changed.emit(map_id)
	await _fade_to(0.0, 0.3)
	_is_changing = false


## โหลดไฟล์ฉากแบบไม่บล็อกเกม + จำไว้ในแคช
func _load_map_scene(path: String) -> PackedScene:
	if _scene_cache.has(path):
		# ขยับขึ้นเป็นตัวล่าสุด
		_cache_order.erase(path)
		_cache_order.append(path)
		return _scene_cache[path]

	var err := ResourceLoader.load_threaded_request(path)
	if err != OK:
		return load(path) as PackedScene   # ทางถอย: โหลดแบบเดิม

	_loading_label.show()
	while true:
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_loading_label.hide()
			return load(path) as PackedScene
		await get_tree().process_frame
	_loading_label.hide()

	var scene := ResourceLoader.load_threaded_get(path) as PackedScene
	if scene != null:
		_scene_cache[path] = scene
		_cache_order.append(path)
		while _cache_order.size() > MAX_CACHED:
			var old_path: String = _cache_order.pop_front()
			_scene_cache.erase(old_path)
	return scene


## ★ กลับหน้าหลัก (รอบ 32) ★
const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"

func go_title() -> void:
	if _is_changing:
		return
	_is_changing = true
	get_tree().paused = false
	if UI != null:
		UI.set_in_game(false)
	await _fade_to(1.0, 0.3)
	get_tree().change_scene_to_file(TITLE_SCENE)
	await get_tree().process_frame
	await get_tree().process_frame
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
