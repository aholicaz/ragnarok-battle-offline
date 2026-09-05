## SfxPlayer — เสียงเอฟเฟกต์ (รอบ 57)
##
## ★★ ใช้ยังไง: แค่วางไฟล์เสียงแล้วตั้งชื่อให้ตรง ★★
##   วางที่  Sprites/sfx/<ชื่อ>.ogg (หรือ .wav / .mp3)  แล้วจบ — ไม่ต้องแก้โค้ด
##
## ชื่อที่ระบบเรียกใช้เองตอนนี้:
##   attack_blade   = ฟันดาบ (ท่า Attack_Blade / ดาบทุกเล่มที่ยังไม่มีเสียงเฉพาะตัว)
##   attack_katana · attack_falchion · attack   = ถ้ามีไฟล์ จะใช้แทนของดาบทั่วไปให้เอง
##   hit · skill_<id> · level_up · warp          = เผื่อไว้ ใส่ทีหลังได้เลย
##
## ★ ไม่ใช่ Autoload ★ Game สร้างให้ตอนเปิดเกม → เรียกผ่าน  Game.sfx.play("attack_blade")
class_name SfxPlayer
extends Node

## โฟลเดอร์ที่ไปหาไฟล์ (ไล่จากบนลงล่าง)
const DIRS := ["res://Sprites/sfx/", "res://sfx/", "res://audio/sfx/", "res://Sprites/audio/"]
const EXTS := [".ogg", ".wav", ".mp3"]
const LAYOUT_PATH := "user://ui_layout.cfg"

## เล่นพร้อมกันได้กี่เสียง (เกินนี้จะแย่งช่องที่เก่าสุด)
const VOICES := 8
## ระดับเสียงเริ่มต้น 0.0-1.0
const DEFAULT_VOLUME := 0.8
const SILENT_DB := -60.0
## เสียงเดิมซ้ำถี่กว่านี้ (วินาที) จะไม่เล่นซ้อน (กันหูแตกตอนตีรัว)
const REPEAT_GUARD := 0.05

var volume: float = DEFAULT_VOLUME
var enabled: bool = true

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _path_cache: Dictionary = {}      ## ชื่อ -> path ("" = ไม่มีไฟล์)
var _last_played: Dictionary = {}     ## ชื่อ -> เวลาที่เล่นล่าสุด


func _ready() -> void:
	name = "SfxPlayer"
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(VOICES):
		var p := AudioStreamPlayer.new()
		p.name = "Sfx%d" % (i + 1)
		p.bus = "Master"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_players.append(p)
	_load_settings()


## หาไฟล์เสียงชื่อนี้ (คืน "" ถ้าไม่มี)
func find_sound(key: String) -> String:
	if key == "":
		return ""
	if _path_cache.has(key):
		return String(_path_cache[key])
	var found := ""
	for dir in DIRS:
		for ext in EXTS:
			var path: String = dir + key + ext
			if ResourceLoader.exists(path):
				found = path
				break
		if found != "":
			break
	_path_cache[key] = found
	return found


func has_sound(key: String) -> bool:
	return find_sound(key) != ""


## เล่นเสียง · pitch สุ่มได้นิดหน่อยให้ไม่จำเจ (1.0 = เสียงเดิม)
## คืน true ถ้าได้เล่นจริง
func play(key: String, volume_scale: float = 1.0, pitch_spread: float = 0.06) -> bool:
	if not enabled or volume <= 0.001:
		return false
	var path := find_sound(key)
	if path == "":
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(key, -99.0)) < REPEAT_GUARD:
		return false
	_last_played[key] = now

	var stream: AudioStream = load(path)
	if stream == null:
		return false
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = linear_to_db(clampf(volume * volume_scale, 0.001, 1.0))
	p.pitch_scale = randf_range(1.0 - pitch_spread, 1.0 + pitch_spread)
	p.play()
	return true


## ★ เล่นเสียงตัวแรกที่ "มีไฟล์จริง" ★ ใช้ไล่จากเฉพาะเจาะจง → ทั่วไป
## เช่น play_first(["attack_katana", "attack_blade", "attack"])
func play_first(keys: Array, volume_scale: float = 1.0) -> bool:
	for k in keys:
		if has_sound(String(k)):
			return play(String(k), volume_scale)
	return false


func stop_all() -> void:
	for p in _players:
		p.stop()


# =========================================================
# ตั้งค่า (เก็บไฟล์เดียวกับเสียงเพลง/ปุ่มจอสัมผัส)
# =========================================================
func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	_save_settings()


func set_enabled(on: bool) -> void:
	enabled = on
	if not on:
		stop_all()
	_save_settings()


func volume_percent() -> int:
	return int(round(volume * 100.0))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(LAYOUT_PATH)
	cfg.set_value("sfx", "volume", volume)
	cfg.set_value("sfx", "enabled", enabled)
	cfg.save(LAYOUT_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(LAYOUT_PATH) != OK:
		return
	volume = clampf(float(cfg.get_value("sfx", "volume", DEFAULT_VOLUME)), 0.0, 1.0)
	enabled = bool(cfg.get_value("sfx", "enabled", true))
