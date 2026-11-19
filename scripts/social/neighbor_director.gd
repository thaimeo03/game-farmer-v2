class_name NeighborDirector
extends Node
## Lives under Main. Keeps the current zone's neighbors in sync with their schedules
## (arrive from the bus stop, walk to their spot, leave again), bakes a navmesh for each zone
## the first time it is entered, runs the daily farm visit and puts up seasonal event decor.

const STALL := preload("res://scenes/city/shop_npc.tscn")
const STALL_KEEPER := preload("res://assets/models/kenney/characters/character-female-d.glb")

var main: Node ## Main (for cached_zone)
var player: Player
var zone: Node3D
var zone_id: StringName
var _people := {} ## npc id -> Neighbor
var _t := 0.0


func set_player(p: Player) -> void:
	player = p
	player.emoted.connect(_on_emote)


func enter(z: Node3D, id: StringName) -> void:
	for n: Neighbor in _people.values():
		if is_instance_valid(n):
			n.queue_free()
	_people.clear()
	zone = z
	zone_id = id
	_bake_nav()
	update(true)


func _process(delta: float) -> void:
	_t += delta
	if _t < 1.0 or not zone:
		return
	_t = 0.0
	update(false)
	var farm: Node = main.call(&"cached_zone", &"my_farm") if main else null
	Social.run_visit(farm.get_node_or_null(^"FarmGrid") as FarmGrid if farm else null)


## snap: put everyone straight on their spot (just arrived in the zone).
func update(snap: bool) -> void:
	if not zone:
		return
	var m := GameState.minute_of_day()
	for npc in Social.npc_list():
		var w := Social.where(npc, m)
		var n: Neighbor = _people.get(npc.id)
		if n and not is_instance_valid(n):
			_people.erase(npc.id)
			n = null
		if StringName(w[0]) == zone_id:
			var spot := spot_for(npc, w[1])
			if n == null:
				n = Neighbor.create(npc)
				zone.add_child(n)
				_people[npc.id] = n
				n.place_at(spot if snap else entry())
				if not snap:
					n.go_to(spot)
			elif n.leaving or n._target.distance_to(spot) > 0.5:
				n.leaving = false
				n.go_to(spot)
		elif n and not n.leaving:
			n.leave(entry())
	_update_event()


func people() -> Array:
	return _people.values().filter(func(n: Neighbor) -> bool: return is_instance_valid(n))


## Where a neighbor stands near `anchor`: in front of it (its +Z), spread sideways per neighbor.
func spot_for(npc: NpcData, anchor: String) -> Vector3:
	var node := zone.find_child(anchor, true, false) as Node3D if anchor else null
	if not node:
		return entry()
	var lateral := (hash(npc.id) % 7 - 3) * 0.6
	var p := node.global_position + node.global_basis.orthonormalized() * Vector3(lateral, 0, 3.2)
	var terrain := zone.get_node_or_null(^"Terrain")
	if terrain and terrain.has_method(&"height_at"):
		p.y = maxf(terrain.height_at(p.x, p.z), node.global_position.y)
	return p


## Where neighbors come from / go to: the bus stop, else the player spawn / dock.
func entry() -> Vector3:
	var stop := zone.find_child("BusStop", true, false) as BusStop
	if stop:
		return stop.exit_point.global_position
	for marker in [&"PlayerSpawn", &"Dock"]:
		var n := zone.get_node_or_null(NodePath(marker)) as Node3D
		if n:
			return n.global_position
	return Vector3.ZERO


func _on_emote(kind: StringName) -> void:
	for n: Neighbor in people():
		if n.global_position.distance_to(player.global_position) < 7.0:
			n.react(kind, player)


func _bake_nav() -> void:
	if zone.has_node(^"NavRegion") or not zone.has_node(^"Terrain"):
		return
	var region := NavigationRegion3D.new()
	region.name = "NavRegion"
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.agent_radius = 0.5
	nm.agent_height = 1.5
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 35.0
	nm.filter_baking_aabb = AABB(Vector3(-50, -6, -50), Vector3(100, 30, 100))
	region.navigation_mesh = nm
	zone.add_child(region)
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, source, zone)
	NavigationServer3D.bake_from_source_geometry_data_async(nm, source, func() -> void:
		if is_instance_valid(region):
			NavigationServer3D.region_set_navigation_mesh(region.get_rid(), nm))


## Seasonal event: lanterns in a ring around the zone's EventSpot and a stall with the event stock.
func _update_event() -> void:
	var ev := Quests.active_event()
	var spot := zone.find_child("EventSpot", true, false) as Node3D
	if not spot:
		return
	var decor := spot.get_node_or_null(^"EventDecor")
	var want := ev != null and zone_id in ev.zones
	if want == (decor != null):
		return
	if decor:
		decor.queue_free()
		return
	decor = Node3D.new()
	decor.name = "EventDecor"
	spot.add_child(decor)
	if ev.decor:
		for i in 6:
			var post: Node3D = ev.decor.instantiate()
			var a := TAU * i / 6.0 + 0.3
			post.position = Vector3(cos(a), 0, sin(a)) * 5.0
			post.rotation.y = -a
			decor.add_child(post)
	var stall: ShopNpc = STALL.instantiate()
	stall.title = ev.stall_title
	stall.stock = ev.stock
	stall.color = Color(0.85, 0.15, 0.12)
	stall.keeper = STALL_KEEPER
	decor.add_child(stall)
