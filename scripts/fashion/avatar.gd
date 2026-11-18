class_name Avatar
## Builds and dresses Kenney Mini Character models. Accessories are attached to the head /
## torso bones at anchor points measured from the head and body meshes, so every base
## character gets hats on top of its head, glasses on its face, etc.

const SCALE := 2.2
const BASE_PRICE := 80
const BASES: Array[String] = [
	"character-female-a", "character-female-b", "character-female-c", "character-female-d",
	"character-female-e", "character-female-f", "character-male-a", "character-male-b",
	"character-male-c", "character-male-d", "character-male-e", "character-male-f", "character-male-g",
]


static func base_name(base_id: String) -> String:
	return "Diện mạo %d" % (BASES.find(base_id) + 1)


## Character model scaled for the world and turned to face -Z (our forward).
static func make_model(base_id: String) -> Node3D:
	var path := "res://assets/models/kenney/characters/%s.glb" % base_id
	var model: Node3D = load(path if ResourceLoader.exists(path) else "res://assets/models/kenney/characters/%s.glb" % BASES[1]).instantiate()
	model.name = "Model"
	model.transform = Transform3D(Basis.from_scale(Vector3(-SCALE, SCALE, -SCALE)), Vector3.ZERO)
	return model


## (Re)attaches accessories: equipped = {OutfitData.Slot: OutfitData}.
static func dress(model: Node3D, equipped: Dictionary) -> void:
	var skel := model.find_children("*", "Skeleton3D", true, false).pop_front() as Skeleton3D
	if not skel:
		return
	for old in skel.get_children():
		if old.name.begins_with("Acc"):
			skel.remove_child(old)
			old.queue_free()
	var anchors := _anchors(skel)
	for slot: int in equipped:
		var outfit: OutfitData = equipped[slot]
		var anchor: Array = anchors[slot]
		var bone := skel.find_bone(anchor[0])
		if bone < 0 or not outfit:
			continue
		var att := BoneAttachment3D.new()
		att.name = "Acc%d" % slot
		att.bone_name = anchor[0]
		skel.add_child(att)
		var acc: Node3D = outfit.model.instantiate()
		var rest := skel.get_bone_global_rest(bone)
		acc.transform = rest.affine_inverse() * Transform3D(Basis.from_scale(Vector3.ONE / SCALE), anchor[1])
		att.add_child(acc)


## Slot -> [bone, anchor point in skeleton space].
static func _anchors(skel: Skeleton3D) -> Dictionary:
	var head := _mesh_box(skel, "head")
	var body := _mesh_box(skel, "body")
	var hc := head.get_center()
	var bc := body.get_center()
	return {
		OutfitData.Slot.HAT: ["head", Vector3(hc.x, head.end.y - head.size.y * 0.06, hc.z)],
		OutfitData.Slot.GLASSES: ["head", Vector3(hc.x, head.position.y + head.size.y * 0.42, head.end.z)],
		OutfitData.Slot.NECK: ["torso", Vector3(bc.x, head.position.y + 0.01, hc.z)],
		OutfitData.Slot.BACK: ["torso", Vector3(bc.x, body.position.y + body.size.y * 0.8, body.position.z + body.size.z * 0.15)],
		OutfitData.Slot.AURA: ["head", Vector3(hc.x, head.end.y + head.size.y * 0.35, hc.z)], # floats above any hat
	}


static func _mesh_box(skel: Skeleton3D, part: String) -> AABB:
	for mi: MeshInstance3D in skel.find_children("*", "MeshInstance3D", true, false):
		if mi.name.begins_with(part):
			return mi.transform * mi.get_aabb()
	return AABB(Vector3(-0.15, 0.3, -0.15), Vector3(0.3, 0.35, 0.3))
