## QuestLog — สมุดเควสของผู้เล่น (เก็บอยู่ใน PlayerState.quests)
##
## เก็บ 3 อย่าง: เควสที่กำลังทำ · ความคืบหน้า · เควสที่ส่งไปแล้ว
class_name QuestLog
extends RefCounted

enum State { NONE, ACTIVE, READY, DONE }

## id ของเควสที่รับไว้แล้ว (ยังไม่ส่ง)
var active: Array[StringName] = []
## ★ id -> Array[int] ★ ความคืบหน้าของ "แต่ละเงื่อนไข" ในเควสนั้น
## (ของเดิมเก็บเป็นตัวเลขเดียว — โหลดเซฟเก่ามาจะแปลงเป็น [ตัวเลข] ให้เอง)
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


## ความคืบหน้าของเงื่อนไขข้อที่ index (ข้อแรก = 0)
func count_of(quest_id: StringName, index: int = 0) -> int:
	var q := GameData.get_quest(quest_id)
	if q != null:
		var list := q.steps()
		if index >= 0 and index < list.size() and list[index].is_live():
			# COLLECT / FLAG นับสดจากกระเป๋าและธงเนื้อเรื่อง ไม่ได้เก็บตัวเลขไว้
			return list[index].live_progress()
	var arr = progress.get(quest_id, null)
	if arr is Array:
		return int(arr[index]) if index >= 0 and index < arr.size() else 0
	if arr != null:
		return int(arr) if index == 0 else 0    # เซฟเก่าที่เก็บเป็นตัวเลขเดียว
	return 0


## เงื่อนไขข้อนี้ครบแล้วหรือยัง
func step_done(quest_id: StringName, index: int) -> bool:
	var q := GameData.get_quest(quest_id)
	if q == null:
		return false
	var list := q.steps()
	if index < 0 or index >= list.size():
		return false
	return count_of(quest_id, index) >= list[index].need()


## ทำครบทุกเงื่อนไขแล้วหรือยัง
func is_ready(quest_id: StringName) -> bool:
	if quest_id not in active:
		return false
	var q := GameData.get_quest(quest_id)
	if q == null:
		return false
	var list := q.steps()
	if list.is_empty():
		return true          # เควสที่แค่ไปคุยให้จบ
	for i in range(list.size()):
		if not step_done(quest_id, i):
			return false
	return true


## ข้อความความคืบหน้าทุกข้อ (ใช้โชว์ในสมุดเควส)
func progress_lines(quest_id: StringName) -> Array[String]:
	var out: Array[String] = []
	var q := GameData.get_quest(quest_id)
	if q == null:
		return out
	var list := q.steps()
	for i in range(list.size()):
		out.append(list[i].line(count_of(quest_id, i)))
	return out


## รับเควสได้ไหม
func can_accept(quest_id: StringName, level: int) -> bool:
	var q := GameData.get_quest(quest_id)
	if q == null:
		return false
	if quest_id in active:
		return false
	if quest_id in completed and not q.repeatable:
		return false
	if level < q.required_level:
		return false
	# ★ ต้องทำเควสก่อนหน้าจบก่อน ★
	for prev in q.required_quests:
		if prev not in completed:
			return false
	# ★ ต้องมีธงเนื้อเรื่องก่อน ★
	if q.required_flag != &"" and not PlayerState.has_flag(q.required_flag):
		return false
	return true


func accept(quest_id: StringName) -> bool:
	if quest_id in active:
		return false
	active.append(quest_id)
	var q := GameData.get_quest(quest_id)
	var n: int = q.step_count() if q != null else 1
	var zeros: Array = []
	for i in range(maxi(1, n)):
		zeros.append(0)
	progress[quest_id] = zeros
	completed.erase(quest_id)   # เควสทำซ้ำได้ ให้เริ่มนับใหม่
	Events.quest_accepted.emit(quest_id)
	Events.quest_changed.emit()
	return true


## ส่งเควส — คืน true ถ้าส่งสำเร็จ
func turn_in(quest_id: StringName) -> bool:
	if not is_ready(quest_id):
		return false
	var q := GameData.get_quest(quest_id)
	if q != null:
		# ★ ยึดของที่เควสขอ ★ (ปิดได้ที่ช่อง Consume ของเงื่อนไขนั้น)
		for o in q.steps():
			if o.kind == ObjectiveData.Kind.COLLECT and o.consume:
				PlayerState.inventory.remove_id(o.target, o.need())
		if q.set_flag_on_complete != &"":
			PlayerState.set_flag(q.set_flag_on_complete)
	active.erase(quest_id)
	progress.erase(quest_id)
	if quest_id not in completed:
		completed.append(quest_id)
	Events.quest_completed.emit(quest_id)
	Events.quest_changed.emit()
	return true


# =========================================================
# ★★ เดินความคืบหน้า ★★ เรียกจาก PlayerState ตอนเกิดเหตุการณ์ต่าง ๆ
# =========================================================
func on_monster_killed(monster_id: StringName) -> void:
	_advance(ObjectiveData.Kind.KILL, monster_id)


## คุยกับ NPC จบแล้ว — ส่ง "ชื่อ NPC" ที่โชว์บนหัวมา
func on_talked_to(npc_name: String) -> void:
	_advance(ObjectiveData.Kind.TALK, StringName(npc_name))


## เข้าแมพใหม่
func on_map_entered(map_id: StringName) -> void:
	_advance(ObjectiveData.Kind.VISIT, map_id)


## ตรวจ/อ่านของในแมพ (ป้าย ชั้นหนังสือ หลุมศพ ฯลฯ)
func on_read(target: StringName) -> void:
	_advance(ObjectiveData.Kind.READ, target)


## เรียกเมื่อกระเป๋าหรือธงเปลี่ยน — ชนิดที่นับสดไม่ต้องบวกเลข แค่แจ้งให้ UI รู้
func refresh_live() -> void:
	for qid in active.duplicate():
		var q := GameData.get_quest(qid)
		if q == null:
			continue
		for o in q.steps():
			if o.is_live():
				Events.quest_changed.emit()
				_announce_if_ready(qid, q)
				break


## หัวใจของการเดินความคืบหน้า — ใช้ร่วมกันทุกชนิด
func _advance(kind: int, target: StringName) -> void:
	for qid in active.duplicate():
		var q := GameData.get_quest(qid)
		if q == null:
			continue
		var list := q.steps()
		var touched := false
		for i in range(list.size()):
			var o := list[i]
			if o.kind != kind or o.target != target or o.is_live():
				continue
			var before := count_of(qid, i)
			if before >= o.need():
				continue
			_set_progress(qid, i, before + 1, list.size())
			touched = true
			var now := before + 1
			Events.quest_progress.emit(qid, now, o.need())
			if now < o.need() and o.need() >= 10 and now % 10 == 0:
				Events.say("[เควส] %s  %d/%d" % [q.title, now, o.need()])
		if touched:
			Events.quest_changed.emit()
			_announce_if_ready(qid, q)


func _set_progress(quest_id: StringName, index: int, value: int, total: int) -> void:
	var arr = progress.get(quest_id, null)
	if not (arr is Array):
		var zeros: Array = []
		for i in range(maxi(1, total)):
			zeros.append(0)
		if arr != null:
			zeros[0] = int(arr)      # ยกค่าจากเซฟเก่ามา
		arr = zeros
		progress[quest_id] = arr
	while arr.size() <= index:
		arr.append(0)
	arr[index] = value


var _announced: Array[StringName] = []

func _announce_if_ready(quest_id: StringName, q: QuestData) -> void:
	if not is_ready(quest_id):
		_announced.erase(quest_id)
		return
	if quest_id in _announced:
		return
	_announced.append(quest_id)
	Events.say("[เควส] %s — ครบแล้ว! กลับไปหา %s" % [q.title, q.giver_name])


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
		var v = progress[k]
		# ★ เก็บเป็นลิสต์ตัวเลข ★ (เควส 1 อันมีได้หลายเงื่อนไข)
		if v is Array:
			var nums: Array = []
			for n in v:
				nums.append(int(n))
			p[String(k)] = nums
		else:
			p[String(k)] = [int(v)]
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
			var v = p[k]
			# เซฟเก่าเก็บเป็นตัวเลขเดียว — แปลงเป็นลิสต์ให้เข้ากับระบบใหม่
			if v is Array:
				var nums: Array = []
				for n in v:
					nums.append(int(n))
				progress[StringName(k)] = nums
			else:
				progress[StringName(k)] = [int(v)]
	Events.quest_changed.emit()
