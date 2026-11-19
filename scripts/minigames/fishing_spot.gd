class_name FishingSpot
extends InteractZone
## Stand here holding the rod (tool 4) and press E: a bait is used, the bobber is cast,
## after a random wait a fish bites ("!" over your head) - press E within `react_time`,
## then win the HUD timing bar. Rarer catches get a narrower, faster bar.
## The catch table depends on the zone (fresh water / sea / island); every fish gets a size
## that goes into the fish journal (J).

const BOBBER := preload("res://assets/models/props/bobber.glb")
## table -> [[item id, weight, green zone width 0..1, marker speed], ...]
const TABLES := {
	&"fresh": [[&"fish_perch", 32, 0.3, 1.0], [&"fish_carp", 24, 0.25, 1.25], [&"fish_gold", 10, 0.12, 2.1],
		[&"trash_can", 18, 0.4, 0.8], [&"trash_bones", 16, 0.4, 0.8]],
	&"sea": [[&"fish_mackerel", 30, 0.3, 1.1], [&"squid", 22, 0.26, 1.3], [&"crab", 18, 0.3, 1.0],
		[&"fish_tuna", 10, 0.15, 1.9], [&"baby_shark", 4, 0.1, 2.4], [&"trash_bottle", 16, 0.4, 0.8]],
	&"isle": [[&"fish_mackerel", 28, 0.3, 1.1], [&"fish_tuna", 25, 0.15, 1.9], [&"fish_gold", 20, 0.12, 2.1],
		[&"swordfish", 15, 0.12, 2.2], [&"baby_shark", 12, 0.1, 2.4]],
}
const ZONE_TABLES := {&"sunny_beach": &"sea", &"little_isle": &"isle"}

@export var cast_point: Node3D ## where the bobber lands (on the water surface)
@export var bait: ItemData = preload("res://resources/items/bait.tres")
@export var bite_wait := Vector2(2.0, 5.0) ## seconds before a bite
@export var react_time := 1.2 ## seconds to press E after the "!"

var _busy := false
var _bite := false
var _hooked := false


func _ready() -> void:
	if prompt_text == "[E] Nói chuyện":
		prompt_text = "[E] Câu cá"
	super()


func interact(player: Player) -> void:
	if _busy:
		return
	if player.tool != Player.Tool.ROD:
		GameState.toast("Chọn Cần câu (phím 4) để câu cá")
		return
	if not GameState.inventory.remove(bait):
		GameState.toast("Hết mồi câu! Mua ở quầy Hạt Giống")
		return
	_fish(player)


func _unhandled_input(event: InputEvent) -> void:
	if _bite and not _hooked and event.is_action_pressed(&"interact"):
		_hooked = true
		get_viewport().set_input_as_handled()


func _fish(player: Player) -> void:
	_busy = true
	GameState.ui_busy = true
	_prompt.visible = false
	var target := cast_point.global_position
	player.begin_activity(&"fish", target)

	var bob: Node3D = BOBBER.instantiate()
	bob.top_level = true
	add_child(bob)
	bob.global_position = player.global_position + Vector3.UP * 1.6
	var arc := create_tween().set_parallel()
	arc.tween_property(bob, "global_position:x", target.x, 0.7)
	arc.tween_property(bob, "global_position:z", target.z, 0.7)
	arc.tween_property(bob, "global_position:y", target.y + 1.5, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	arc.chain().tween_property(bob, "global_position:y", target.y, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await arc.finished

	var idle := create_tween().set_loops()
	idle.tween_property(bob, "global_position:y", target.y + 0.04, 0.5)
	idle.tween_property(bob, "global_position:y", target.y - 0.02, 0.5)
	await get_tree().create_timer(randf_range(bite_wait.x, bite_wait.y)).timeout
	idle.kill()

	# Bite: bobber dips, "!" pops over the player's head.
	bob.global_position.y = target.y - 0.12
	var mark := Label3D.new()
	mark.text = "!"
	mark.font_size = 160
	mark.outline_size = 24
	mark.modulate = Color(1, 0.25, 0.2)
	mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mark.position.y = 2.3
	player.add_child(mark)
	_hooked = false
	_bite = true
	var t := 0.0
	while t < react_time and not _hooked:
		await get_tree().process_frame
		t += get_process_delta_time()
	_bite = false
	mark.queue_free()

	var caught: ItemData = null
	if _hooked:
		var entry := pick(table())
		var hud := get_tree().get_first_node_in_group(&"hud") as Hud
		if hud and await hud.play_timing_bar(entry[2], entry[3]):
			caught = Database.item(entry[0])
	bob.queue_free()

	if caught:
		GameState.inventory.add(caught)
		var rec := GameState.record_fish(caught)
		GameState.toast("Câu được %s%s!%s" % [caught.display_name, " %.1f cm" % rec[0] if rec[0] > 0.0 else "", "  Kỷ lục mới!" if rec[1] else ""])
		Progression.reward(&"fish_rare" if caught.sell_price >= 50 else &"fish")
		_show_catch(player, caught)
	else:
		GameState.toast("Cá thoát mất rồi..." if _hooked else "Chậm tay! Cá ăn mất mồi.")
	player.end_activity()
	GameState.ui_busy = false
	_busy = false
	_prompt.visible = player.interactable == self


func table() -> Array:
	return TABLES[ZONE_TABLES.get(GameState.current_zone, &"fresh")]


## Weighted random entry of a catch table.
static func pick(entries: Array) -> Array:
	var total := 0.0
	for e in entries:
		total += e[1]
	var r := randf() * total
	for e in entries:
		r -= e[1]
		if r <= 0.0:
			return e
	return entries[-1]


## Holds the caught item's model over the player's head for a moment.
func _show_catch(player: Player, item: ItemData) -> void:
	if not item.model:
		return
	var m: Node3D = item.model.instantiate()
	m.position.y = 2.1
	m.scale = Vector3.ONE * 1.6
	player.add_child(m)
	var tw := m.create_tween()
	tw.tween_property(m, "rotation:y", TAU, 1.4)
	tw.tween_callback(m.queue_free)
