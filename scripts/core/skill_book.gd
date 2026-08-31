## SkillBook — สกิลที่ตัวละครเรียนแล้ว + ปุ่มลัด
class_name SkillBook
extends RefCounted

const HOTKEY_COUNT := 4

var learned: Dictionary = {}          # StringName -> int (เลเวลสกิล)
var hotkeys: Array = [&"", &"", &"", &""]


func level_of(skill_id: StringName) -> int:
	return int(learned.get(skill_id, 0))


func is_learned(skill_id: StringName) -> bool:
	return level_of(skill_id) > 0


## เช็คว่าเรียนสกิลนี้เพิ่มได้ไหม
func can_learn(skill_id: StringName, stats: PlayerStats) -> bool:
	var s := GameData.get_skill(skill_id)
	if s == null:
		return false
	if stats.skill_points <= 0:
		return false
	if level_of(skill_id) >= s.max_level:
		return false
	if stats.level < s.required_level:
		return false
	if not s.job_ids.is_empty() and stats.job_id not in s.job_ids:
		return false
	for req_id in s.required_skills.keys():
		if level_of(StringName(req_id)) < int(s.required_skills[req_id]):
			return false
	return true


## เหตุผลที่เรียนไม่ได้ (เอาไว้โชว์ใน UI)
func learn_blocker(skill_id: StringName, stats: PlayerStats) -> String:
	var s := GameData.get_skill(skill_id)
	if s == null:
		return "ไม่พบสกิล"
	if level_of(skill_id) >= s.max_level:
		return "เลเวลสูงสุดแล้ว"
	if stats.level < s.required_level:
		return "ต้องเลเวล %d" % s.required_level
	if not s.job_ids.is_empty() and stats.job_id not in s.job_ids:
		return "อาชีพนี้เรียนไม่ได้"
	for req_id in s.required_skills.keys():
		var need := int(s.required_skills[req_id])
		if level_of(StringName(req_id)) < need:
			var rs := GameData.get_skill(StringName(req_id))
			var rname: String = rs.display_name if rs != null else String(req_id)
			return "ต้องมี %s เลเวล %d" % [rname, need]
	if stats.skill_points <= 0:
		return "ไม่มี Skill Point"
	return ""


func learn(skill_id: StringName, stats: PlayerStats) -> bool:
	if not can_learn(skill_id, stats):
		return false
	learned[skill_id] = level_of(skill_id) + 1
	stats.skill_points -= 1
	Events.skills_changed.emit()
	return true


## รีเซ็ตสกิลทั้งหมด คืน skill point ให้ครบ
func reset(stats: PlayerStats) -> void:
	var refund := 0
	for lv in learned.values():
		refund += int(lv)
	learned.clear()
	hotkeys = [&"", &"", &"", &""]
	stats.skill_points += refund
	Events.skills_changed.emit()


func set_hotkey(index: int, skill_id: StringName) -> void:
	if index < 0 or index >= HOTKEY_COUNT:
		return
	# ถ้าสกิลนี้อยู่ปุ่มอื่นอยู่แล้ว ให้เอาออกก่อน
	for i in range(HOTKEY_COUNT):
		if hotkeys[i] == skill_id:
			hotkeys[i] = &""
	hotkeys[index] = skill_id
	Events.skills_changed.emit()


func hotkey_at(index: int) -> StringName:
	if index < 0 or index >= HOTKEY_COUNT:
		return &""
	return hotkeys[index]


## รวมโบนัสจากสกิลพาสซีฟทั้งหมด
func passive_bonus() -> Dictionary:
	var out := {}
	for skill_id in learned.keys():
		var s := GameData.get_skill(StringName(skill_id))
		if s == null or s.type != SkillData.SkillType.PASSIVE:
			continue
		var values := s.passive_values(level_of(StringName(skill_id)))
		for key in values.keys():
			out[StringName(key)] = float(out.get(StringName(key), 0.0)) + float(values[key])
	return out


func to_dict() -> Dictionary:
	var l := {}
	for k in learned.keys():
		l[String(k)] = learned[k]
	var h: Array = []
	for x in hotkeys:
		h.append(String(x))
	return {"learned": l, "hotkeys": h}


func from_dict(d: Dictionary) -> void:
	learned.clear()
	var l: Dictionary = d.get("learned", {})
	for k in l.keys():
		learned[StringName(k)] = int(l[k])
	hotkeys = [&"", &"", &"", &""]
	var h: Array = d.get("hotkeys", [])
	for i in range(mini(h.size(), HOTKEY_COUNT)):
		hotkeys[i] = StringName(h[i])
	Events.skills_changed.emit()
