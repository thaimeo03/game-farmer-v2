class_name RingToss
extends InteractZone
## Ring toss booth: pay for 3 rings; each throw is a timing bar (hit the green zone).
## Hits land on a bottle; prizes grow with the number of hits. Limited plays per day.

const RING := preload("res://assets/models/props/toss_ring.glb")
## prize per number of hits (0..3): [xu, Lượng, spin tickets]
const PRIZES := [[0, 0, 0], [15, 0, 0], [40, 0, 0], [100, 2, 1]]
## bottle tops in booth-local space (3x3 grid on the stepped shelves)
const BOTTLES := [
	Vector3(-0.8, 1.55, 0.0), Vector3(0.0, 1.55, 0.0), Vector3(0.8, 1.55, 0.0),
	Vector3(-0.8, 1.7, -0.45), Vector3(0.0, 1.7, -0.45), Vector3(0.8, 1.7, -0.45),
	Vector3(-0.8, 1.85, -0.9), Vector3(0.0, 1.85, -0.9), Vector3(0.8, 1.85, -0.9),
]

@export var fee := 10
@export var daily_limit := 10

var playing := false

@onready var _booth: Node3D = $Booth


func _ready() -> void:
	if prompt_text == "[E] Nói chuyện":
		prompt_text = "[E] Ném vòng (%d xu / 3 vòng)" % fee
	super()


func interact(player: Player) -> void:
	if playing or GameState.coins < fee:
		if not playing:
			GameState.toast("Không đủ xu!")
		return
	if not GameState.daily_use("ring_toss", daily_limit):
		return
	GameState.spend(fee)
	playing = true
	GameState.ui_busy = true
	var hits := 0
	for throw in 3:
		var hit: bool = await hud().play_timing_bar(0.2, 1.5 + throw * 0.2)
		await _throw(player, hit)
		hits += int(hit)
	playing = false
	GameState.ui_busy = false
	award(hits)


static func award(hits: int) -> void:
	var p: Array = PRIZES[clampi(hits, 0, 3)]
	GameState.earn(p[0])
	if p[1] > 0:
		GameState.gems += p[1]
		GameState.money_changed.emit()
	if p[2] > 0:
		GameState.inventory.add(Database.item(&"spin_ticket"), p[2])
	if hits == 0:
		GameState.toast("Trượt cả 3 vòng... thử lại nhé!")
	else:
		GameState.toast("Trúng %d/3! +%d xu%s" % [hits, p[0], " +%d Lượng +1 Vé quay" % p[1] if p[1] > 0 else ""])
	Progression.reward(&"race")


func _throw(player: Player, hit: bool) -> void:
	var ring: Node3D = RING.instantiate()
	ring.top_level = true
	add_child(ring)
	var from := player.global_position + Vector3.UP * 1.2
	var to: Vector3 = _booth.to_global(BOTTLES.pick_random()) if hit else _booth.to_global(Vector3(randf_range(-1.2, 1.2), 0.95, 0.6))
	ring.global_position = from
	var tw := create_tween().set_parallel()
	tw.tween_property(ring, "global_position:x", to.x, 0.6)
	tw.tween_property(ring, "global_position:z", to.z, 0.6)
	tw.tween_property(ring, "global_position:y", maxf(from.y, to.y) + 1.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_property(ring, "global_position:y", to.y, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await tw.finished
	await get_tree().create_timer(0.4).timeout
	ring.queue_free()
