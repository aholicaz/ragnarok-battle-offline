## Events — สัญญาณกลางของเกมทั้งหมด (Autoload ชื่อ "Events")
## ใครก็ตามที่อยากรู้ว่ามีอะไรเกิดขึ้น ให้มา connect ที่นี่
## หมายเหตุ: ไฟล์นี้ห้ามใส่ class_name เพราะจะชนกับชื่อ Autoload
extends Node

# ---------- ตัวละคร ----------
signal stats_changed                       ## ค่าพลังเปลี่ยน (อัพสเตตัส/ใส่ของ/บัฟ)
signal hp_changed(current: int, maximum: int)
signal sp_changed(current: int, maximum: int)
signal exp_changed(current: int, needed: int)
signal level_up(new_level: int)
## ★ ค่าประสบการณ์อาชีพ (Job) แยกจาก Base ★
signal job_exp_changed(current: int, needed: int)
signal job_level_up(new_job_level: int)
signal player_died
signal zeny_changed(amount: int)

# ---------- ไอเทม ----------
signal inventory_changed
signal equipment_changed
signal item_gained(item_id: StringName, count: int)
signal item_used(item_id: StringName)
signal refine_result(success: bool, item_name: String, new_refine: int)
## ★ ได้การ์ดใบนี้เป็น "ครั้งแรก" ★ (ใช้เด้ง popup ยินดีด้วย)
signal card_obtained(card_id: StringName)

# ---------- สกิล ----------
signal skills_changed
signal skill_used(skill_id: StringName, level: int)
signal buff_changed

# ---------- โลก / การต่อสู้ ----------
signal monster_killed(monster_id: StringName, level: int)
## ★ ล้มบอสได้ ★ (ใช้เด้งป้าย MVP)
signal boss_killed(monster_id: StringName, display_name: String)
signal damage_dealt(target: Node, amount: int, is_crit: bool)
signal map_changed(map_id: StringName)
## kind = FloatingTextLayer.Kind (บอกว่าข้อความชนิดไหน จะได้แยกทิศไม่ให้ทับกัน)
signal floating_text_requested(world_position: Vector2, text: String, color: Color, size: int, kind: int)

# ---------- เควส ----------
signal quest_accepted(quest_id: StringName)
signal quest_progress(quest_id: StringName, current: int, needed: int)
signal quest_completed(quest_id: StringName)
## เปลี่ยนแปลงอะไรก็ตามในสมุดเควส (ให้ UI รีเฟรช)
signal quest_changed

# ---------- UI ----------
signal toggle_window(window_name: StringName)
signal shop_opened(shop_item_ids: Array)
signal refine_npc_opened
## ★ รอบ 56 ★ เปิดหน้าเจาะรูการ์ด / ผลการเจาะ
signal socket_npc_opened
signal socket_result(success: bool, item_name: String, new_slots: int)
signal notice(message: String)


## เรียกใช้ง่าย ๆ สำหรับข้อความลอย
func floating_text(world_position: Vector2, text: String, color: Color = Color.WHITE,
		size: int = 20, kind: int = 0) -> void:
	floating_text_requested.emit(world_position, text, color, size, kind)


func say(message: String) -> void:
	notice.emit(message)
