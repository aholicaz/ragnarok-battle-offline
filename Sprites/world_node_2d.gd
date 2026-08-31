extends Node2D

@export var poring_scene: PackedScene

const PORING_PER_WAVE = 3
const RESPAWN_TIME = 10.0

var alive_poring = 0
var respawning = false


func _ready() -> void:

	# สร้าง Poring ชุดแรก
	spawn_poring_wave()


func spawn_poring_wave() -> void:

	print("เกิด Poring จำนวน ", PORING_PER_WAVE, " ตัว")


	alive_poring = PORING_PER_WAVE


	for i in range(PORING_PER_WAVE):

		spawn_poring(i)


func spawn_poring(index: int) -> void:

	if poring_scene == null:

		print("ยังไม่ได้ใส่ Poring Scene!")

		return


	var poring = poring_scene.instantiate()


	add_child(poring)


	# จุดเกิดแต่ละตัว
	var spawn_positions = [
		Vector2(350, 300),
		Vector2(450, 300),
		Vector2(550, 300)
	]


	poring.global_position = spawn_positions[index]


# ==========================================
# Poring ตาย
# ==========================================

func poring_died() -> void:

	alive_poring -= 1


	print(
		"Poring เหลือ ",
		alive_poring
	)


	# ถ้าตายครบ 3 ตัว
	if alive_poring <= 0 and not respawning:

		respawning = true

		print(
			"Poring ตายครบแล้ว รอ ",
			RESPAWN_TIME,
			" วินาที"
		)


		await get_tree().create_timer(
			RESPAWN_TIME
		).timeout


		spawn_poring_wave()
		
		

		respawning = false
		
		
