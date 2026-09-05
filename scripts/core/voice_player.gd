## VoicePlayer — เสียงพากย์ NPC (รอบ 59)
##
## ★★ ใช้ยังไง: วางไฟล์ให้ตรงชื่อ แล้วจบ ★★
##   Sprites/voice/<voice_id>/<key>.ogg   (หรือ .wav / .mp3)
##   voice_id = ช่อง "Voice Id" ของ NPC ในฉาก (เช่น hans · tony · maria)
##   key      = ชื่อประโยค เช่น greeting · dialog_1 · hans_poring_offer_1 (ดูรายการทั้งหมดใน dump_npc_lines.py)
##
## ★ กฎ ★  เสียงพากย์มีช่องเดียว — ขึ้นประโยคใหม่ = ตัดประโยคเก่าทิ้ง · ปิดกล่องสนทนา = หยุด
##         ไม่มีไฟล์ = เงียบเฉย ๆ ไม่ error
##
## ★ ไม่ใช่ Autoload ★ Game สร้างให้ตอนเปิดเกม → Game.voice.play("hans", "greeting")
class_name VoicePlayer
extends Node

const DIRS := ["res://Sprites/voice/", "res://voice/", "res://audio/voice/"]
const EXTS := [".ogg", ".wav", ".mp3"]
const LAYOUT_PATH := "user://ui_layout.cfg"
const DEFAULT_VOLUME := 1.0

var volume: float = DEFAULT_VOLUME
var enabled: bool = true

var _player: AudioStreamPlayer
var _path_cache: Dictionary = {}     ## "id/key" -> path ("" = ไม่มีไฟล์)
var last_played: String = ""         ## path ล่าสุดที่ได้เล่นจริง (ไว้เช็ค/เทสต์)


func _ready() -> void:
	name = "VoicePlayer"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.name = "Voice"
	_player.bus = "Master"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	_load_settings()


## หาไฟล์เสียงของ voice_id/key (คืน "" ถ้าไม่มี)
func find(voice_id: String, key: String) -> String:
	if voice_id == "" or key == "":
		return ""
	return find_path(voice_id + "/" + key)


## หาไฟล์จาก "id/key" หรือ path เต็ม (ไม่ต้องใส่นามสกุลก็ได้)
func find_path(rel: String) -> String:
	if rel == "":
		return ""
	if _path_cache.has(rel):
		return String(_path_cache[rel])
	var found := ""
	var candidates: Array[String] = []
	if rel.begins_with("res://") or rel.begins_with("user://"):
		candidates.append(rel)
	else:
		for dir in DIRS:
			candidates.append(dir + rel)
	for base in candidates:
		if ResourceLoader.exists(base):
			found = base
			break
		for ext in EXTS:
			if ResourceLoader.exists(base + ext):
				found = base + ext
				break
		if found != "":
			break
	_path_cache[rel] = found
	return found


func has(voice_id: String, key: String) -> bool:
	return find(voice_id, key) != ""


## เล่นเสียงพากย์ (ตัดของเก่าทิ้ง) · คืน true ถ้าได้เล่นจริง
func play(voice_id: String, key: String) -> bool:
	return play_path(voice_id + "/" + key if voice_id != "" and key != "" else "")


## เล่นจาก "id/key" หรือ path เต็ม
func play_path(rel: String) -> bool:
	stop()
	if not enabled or volume <= 0.001:
		return false
	var path := find_path(rel)
	if path == "":
		return false
	var stream: AudioStream = load(path)
	if stream == null:
		return false
	_player.stream = stream
	_player.volume_db = linear_to_db(clampf(volume, 0.001, 1.0))
	_player.play()
	last_played = path
	return true


func stop() -> void:
	if _player != null and _player.playing:
		_player.stop()


func is_playing() -> bool:
	return _player != null and _player.playing


# =========================================================
# ตั้งค่า (ไฟล์เดียวกับเพลง/เสียงเอฟเฟกต์)
# =========================================================
func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	if _player != null and _player.playing:
		_player.volume_db = linear_to_db(clampf(volume, 0.001, 1.0))
	_save_settings()


func set_enabled(on: bool) -> void:
	enabled = on
	if not on:
		stop()
	_save_settings()


func volume_percent() -> int:
	return int(round(volume * 100.0))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(LAYOUT_PATH)
	cfg.set_value("voice", "volume", volume)
	cfg.set_value("voice", "enabled", enabled)
	cfg.save(LAYOUT_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(LAYOUT_PATH) != OK:
		return
	volume = clampf(float(cfg.get_value("voice", "volume", DEFAULT_VOLUME)), 0.0, 1.0)
	enabled = bool(cfg.get_value("voice", "enabled", true))
