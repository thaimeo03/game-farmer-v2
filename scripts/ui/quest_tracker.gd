class_name QuestTracker
extends PanelContainer
## Top-right box with the tracked quest's current step, plus a floating 3D arrow over the
## player pointing at the step's target ("at" node in this zone, or the bus stop / door when
## the step happens in another zone).

var player: Player
var _label: Label
var _arrow: MeshInstance3D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -330.0
	offset_right = -12.0
	offset_top = 118.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size.x = 300
	_label.add_theme_font_size_override(&"font_size", 15)
	add_child(_label)
	Quests.changed.connect(refresh)
	refresh()


func bind(p: Player) -> void:
	player = p
	_arrow = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.4
	cone.height = 1.0
	cone.radial_segments = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 0.85, 0.15)
	mat.no_depth_test = true
	mat.render_priority = 10
	cone.material = mat
	var tip := MeshInstance3D.new()
	tip.mesh = cone
	tip.rotation.x = -PI * 0.5 # tip along -Z, so look_at() aims it
	_arrow.add_child(tip)
	_arrow.top_level = true
	_arrow.visible = false
	player.add_child(_arrow)


func refresh() -> void:
	var id := Quests.tracked()
	var q := Quests.quest(id) if id else null
	visible = q != null
	if q:
		var others := Quests.active.size() - 1
		var line := Quests.progress_text(id)
		var head := line if line.begins_with(q.title) else "%s\n• %s" % [q.title, line]
		_label.text = "%s%s" % [head, "\n(+%d nhiệm vụ khác — L)" % others if others > 0 else ""]


func _process(_delta: float) -> void:
	if not _arrow or not visible:
		if _arrow:
			_arrow.visible = false
		return
	var target := _target()
	var waist := player.global_position + Vector3(0, 0.6, 0)
	var flat := Vector3(target.x, waist.y, target.z) if target != Vector3.INF else waist
	_arrow.visible = target != Vector3.INF and waist.distance_to(flat) > 3.0
	if _arrow.visible:
		# floats 2.2 m ahead of the player on the way to the target, bobbing along it
		var dir := waist.direction_to(flat)
		_arrow.global_position = waist + dir * (2.2 + sin(Time.get_ticks_msec() * 0.006) * 0.15)
		_arrow.look_at(flat)


func _target() -> Vector3:
	var step := Quests.current_step(Quests.tracked())
	var main := player.get_parent()
	var zone: Node = main.call(&"current_zone_root") if main and main.has_method(&"current_zone_root") else null
	if step.is_empty() or zone == null:
		return Vector3.INF
	var where: String = step.get("zone", "")
	var node: Node3D = null
	if where != "" and StringName(where) != GameState.current_zone:
		node = zone.find_child("BusStop", true, false) as Node3D
		if not node:
			node = zone.find_child("ExitDoor", true, false) as Node3D
	elif step.get("at", "") != "":
		node = zone.find_child(step.at, true, false) as Node3D
	return node.global_position if node else Vector3.INF
