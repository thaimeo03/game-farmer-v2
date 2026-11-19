class_name Neighbor
extends CharacterBody3D
## A neighbor walking around a zone. NeighborDirector spawns it, sends it to its scheduled
## spot (NavigationAgent3D on the zone's baked navmesh, straight line if there is none) and
## sends it away when the schedule says it is elsewhere. Talk with E; reacts to emotes.

const SPEED := 2.0
const ARRIVE := 0.5

var data: NpcData
var leaving := false ## walking to the exit; freed on arrival

var _target := Vector3.ZERO
var _moving := false
var _agent: NavigationAgent3D
var _anim: AnimationPlayer
var _model: Node3D
var _bubble: Label3D
var _bubble_t := 0.0
var _pose_t := 0.0 ## a one-shot clip (emote) is playing
var _leave_t := 0.0 ## gives up walking out after a while (stuck behind a bench...)
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


static func create(npc: NpcData) -> Neighbor:
	var n := Neighbor.new()
	n.data = npc
	n.name = "Npc_%s" % npc.id
	return n


func _ready() -> void:
	collision_layer = 0 # never blocks the player
	collision_mask = 1
	var body := CollisionShape3D.new()
	body.shape = CapsuleShape3D.new()
	body.shape.radius = 0.3
	body.shape.height = 1.4
	body.position.y = 0.7
	add_child(body)
	_model = Avatar.make_model(data.base_id)
	add_child(_model)
	var worn := {}
	for o in data.outfits:
		worn[o.slot] = o
	Avatar.dress(_model, worn)
	_anim = _model.find_children("*", "AnimationPlayer", true, false).pop_front()
	if _anim:
		for clip: StringName in [&"idle", &"walk", &"sit"]:
			if _anim.has_animation(clip):
				_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		_anim.play(&"idle")
	var tag := Label3D.new()
	tag.text = "%s\n%s" % [data.display_name, data.title]
	tag.position.y = 2.25
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 30
	tag.outline_size = 10
	tag.modulate = Color(0.85, 1.0, 0.85)
	tag.no_depth_test = false
	add_child(tag)
	_bubble = Label3D.new()
	_bubble.position.y = 2.85
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.font_size = 40
	_bubble.outline_size = 14
	_bubble.width = 600.0
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.visible = false
	add_child(_bubble)
	var talk := InteractZone.new()
	talk.name = "Talk"
	talk.prompt_text = "[E] Nói chuyện với %s" % data.display_name
	talk.prompt_height = 3.4
	var area := CollisionShape3D.new()
	area.shape = SphereShape3D.new()
	area.shape.radius = 1.6
	area.position.y = 0.8
	talk.add_child(area)
	talk.interacted.connect(_on_talk)
	add_child(talk)
	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = ARRIVE
	_agent.radius = 0.35
	add_child(_agent)


func go_to(pos: Vector3) -> void:
	_target = pos
	_moving = true
	_agent.target_position = pos


func place_at(pos: Vector3) -> void:
	global_position = pos + Vector3.UP * 0.5
	_target = pos
	_moving = false


func leave(exit: Vector3) -> void:
	leaving = true
	_leave_t = 25.0
	go_to(exit)


func say(text: String, seconds := 3.5) -> void:
	_bubble.text = text
	_bubble.visible = true
	_bubble_t = seconds


## Answer a player's emote (they turn to the player, play a clip, say something).
func react(kind: StringName, player: Node3D) -> void:
	face(player.global_position)
	var reply: Array = {
		&"wave": [&"interact-left", "Chào bạn! 👋"], &"laugh": [&"emote-yes", "Haha! 😄"],
		&"sad": [&"emote-no", "Sao vậy? Vui lên nào! 🤗"], &"jump": [&"jump", "Yay! 🎉"],
		&"heart": [&"emote-yes", "❤ Quý bạn ghê!"], &"sit": [&"emote-yes", "Nghỉ chút cũng hay 😊"],
	}.get(kind, [&"emote-yes", "🙂"])
	_play_once(reply[0])
	say(reply[1], 2.5)
	Social.greet(data)


func face(point: Vector3) -> void:
	var d := point - global_position
	d.y = 0.0
	if d.length() > 0.05:
		_model.rotation.y = atan2(-d.x, -d.z)


func _physics_process(delta: float) -> void:
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	var flat := Vector3.ZERO
	if _moving and (leaving or not GameState.ui_busy): # stand still while the player is in a menu
		var to_target := _target - global_position
		to_target.y = 0.0
		_leave_t -= delta
		if to_target.length() < (1.5 if leaving else ARRIVE) or leaving and _leave_t <= 0.0:
			_moving = false
			if leaving:
				queue_free()
				return
		else:
			var next := _agent.get_next_path_position()
			var step := next - global_position
			step.y = 0.0
			if step.length() < 0.05 or _agent.is_navigation_finished(): # no navmesh: walk straight
				step = to_target
			flat = step.normalized() * SPEED
			face(global_position + flat)
	velocity.x = flat.x
	velocity.z = flat.z
	move_and_slide()
	if global_position.y < -20.0: # fell through something: put back on the target
		place_at(_target)
	if _pose_t <= 0.0 and _anim:
		var clip := &"walk" if flat != Vector3.ZERO else &"idle"
		if _anim.current_animation != clip:
			_anim.play(clip, 0.2)


func _process(delta: float) -> void:
	_pose_t -= delta
	if _bubble_t > 0.0:
		_bubble_t -= delta
		_bubble.visible = _bubble_t > 0.0


func _play_once(clip: StringName) -> void:
	if _anim and _anim.has_animation(clip):
		_anim.play(clip, 0.15)
		_pose_t = _anim.get_animation(clip).length


func _on_talk(player: Player) -> void:
	face(player.global_position)
	player.face(global_position)
	var line := Social.talk(data)
	say(line)
	_play_once(&"interact-left")
	open_menu(line)


## Talk menu: chat line + friendship, gift, personal quest.
func open_menu(line: String) -> void:
	var hud := get_tree().get_first_node_in_group(&"hud") as Hud
	if not hud:
		return
	var rows := [{"text": "%s — %s   %s\n\"%s\"" % [data.display_name, data.title, Social.hearts_text(data.id), line]}]
	rows.append({"text": "Tặng quà (mỗi ngày 1 lần). Thích: %s" % _likes_hint(),
		"buttons": [["Tặng quà", _open_gifts, GameState.daily_count("gift_" + String(data.id)) == 0]]})
	var q := data.quest
	if q and Social.hearts(data.id) >= 3 and not Quests.is_done(q.id):
		if Quests.is_active(q.id):
			rows.append({"text": "Nhiệm vụ: %s — %s" % [q.title, Quests.progress_text(q.id)]})
		else:
			rows.append({"text": "Nhờ giúp: %s\n%s\nThưởng: %s" % [q.title, q.description, q.reward_text()],
				"buttons": [["Nhận", Quests.start.bind(q.id, false), true]]})
	elif q and not Quests.is_done(q.id):
		rows.append({"text": "(Thân hơn — 3 ♥ — %s sẽ nhờ bạn một việc)" % data.display_name})
	rows.append({"text": "", "buttons": [["Tạm biệt", func() -> void: say("Hẹn gặp lại!", 2.0), true]]})
	hud.open_menu(data.display_name, rows)


func _open_gifts() -> void:
	var hud := get_tree().get_first_node_in_group(&"hud") as Hud
	var rows := []
	for item: ItemData in GameState.inventory.items():
		if item.category in [ItemData.Category.TOOL, ItemData.Category.OUTFIT, ItemData.Category.PET, ItemData.Category.FURNITURE]:
			continue
		var liked := "  ♥" if item.id in data.likes else ""
		rows.append({"text": "%s x%d%s" % [item.display_name, GameState.inventory.count(item), liked],
			"buttons": [["Tặng", _give.bind(item), true]]})
	hud.open_menu("Tặng quà cho %s" % data.display_name, rows)


func _give(item: ItemData) -> void:
	var reply := Social.gift(data, item)
	if reply:
		say(reply)
		_play_once(&"emote-yes" if item.id not in data.dislikes else &"emote-no")
		GameState.toast("%s: %s" % [data.display_name, reply])


## Shows liked gifts once you are friends (1+ heart), "???" before.
func _likes_hint() -> String:
	if Social.hearts(data.id) < 1:
		return "???"
	var names: Array[String] = []
	for id in data.likes:
		var item := Database.item(id)
		if item:
			names.append(item.display_name)
	return ", ".join(names)
