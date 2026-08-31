## QuestLog — สมุดเควสของผู้เล่น (เก็บอยู่ใน PlayerState.quests)
##
## เก็บ 3 อย่าง: เควสที่กำลังทำ · ความคืบหน้า · เควสที่ส่งไปแล้ว
class_name QuestLog
extends RefCounted

enum State { NONE, ACTIVE, READY, DONE }

## id ของเควสที่รับไว้แล้ว (ยังไม่ส่ง)
var active: Array[StringName] = []
## id -> จำนวนที่ล่าได้แล้ว
var progress: Dictionary = {}
## id ของเควสที่ส่งเรียบร้อยแล้ว
var completed: Array[StringName] = []


func state_of(quest_id: StringName) -> State:
	if quest_id in active:
		return State.READY if is_ready(quest_id) else State.ACTIVE
	if quest_id in completed:
		return State.DONE
	return State.NONE


func is_active(quest_id: StringName) -> bool:
	return quest_id in active


func is_done(quest_id: StringName) -> bool:
	return quest_id in completed


func count_of(quest_id: StringName) -> int:
	return int(progress.get(quest_id, 0))


## ทำครบเงื่อนไขแล้วหรือยัง
func is_ready(quest_id: StringName) -> bool:
	if quest_id not in active:
		return false
	var q := GameData.get_quest(quest_id)
	if q == null:
		return false
	if q.kill_monster_id == &"":
		return true
	return count_of(quest_id) >= q.kill_count


## รับเควสได้ไหม
func can_accept(quest_id: StringName, level: int) -> bool:
	var q := GameData.get_quest(quest_id)
	if q == null:
		return false
	if quest_id in active:
		return false
	if quest_id in completed and not q.repeatable:
		return false
	return level >= q.required_level


func accept(quest_id: StringName) -> bool:
	if quest_id in active:
		return false
	active.append(quest_id)
	progress[quest_id] = 0
	completed.erase(quest_id)   # เควสทำซ้ำได้ ให้เริ่มนับใหม่
	Events.quest_accepted.emit(quest_id)
	Events.quest_changed.emit()
	return true


## ส่งเควส — คืน true ถ้าส่งสำเร็จ
func turn_in(quest_id: StringName) -> bool:
	if not is_ready(quest_id):
		return false
	active.erase(quest_id)
	progress.erase(quest_id)
	if quest_id not in completed:
		completed.append(quest_id)
	Events.quest_completed.emit(quest_id)
	Events.quest_changed.emit()
	return true


## เรียกทุกครั้งที่ฆ่ามอน — เดินความคืบหน้าของเควสที่เกี่ยวข้อง
func on_monster_killed(monster_id: StringName) -> void:
	for qid in active.duplicate():
		var q := GameData.get_quest(qid)
		if q == null or q.kill_monster_id != monster_id:
			continue
		var before := count_of(qid)
		if before >= q.kill_count:
			continue
		var now := before + 1
		progress[qid] = now
		Events.quest_progress.emit(qid, now, q.kill_count)
		if now >= q.kill_count:
			Events.say("[เควส] %s — ครบแล้ว! กลับไปหา %s" % [q.title, q.giver_name])
		elif now % 10 == 0:
			Events.say("[เควส] %s  %d/%d" % [q.title, now, q.kill_count])
		Events.quest_changed.emit()


# =========================================================
# เซฟ / โหลด
# =========================================================
func to_dict() -> Dictionary:
	var a: Array = []
	for q in active:
		a.append(String(q))
	var c: Array = []
	for q in completed:
		c.append(String(q))
	var p: Dictionary = {}
	for k in progress.keys():
		p[String(k)] = int(progress[k])
	return {"active": a, "completed": c, "progress": p}


func from_dict(d: Dictionary) -> void:
	active.clear()
	completed.clear()
	progress.clear()
	for q in d.get("active", []):
		active.append(StringName(q))
	for q in d.get("completed", []):
		completed.append(StringName(q))
	var p = d.get("progress", {})
	if p is Dictionary:
		for k in p.keys():
			progress[StringName(k)] = int(p[k])
	Events.quest_changed.emit()
