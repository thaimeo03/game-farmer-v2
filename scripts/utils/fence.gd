class_name Fence
## Builds a rectangular fence of solid segments (Kenney nature fence: 1 unit long, sitting
## on its tile's -Z edge) with a gate gap in the middle of the +Z side.

static func build(parent: Node3D, origin: Vector3, width: float, depth: float, segment: float,
		scene: PackedScene, gate := true) -> Node3D:
	var root := Node3D.new()
	root.name = "Fence"
	parent.add_child(root)
	var nx := maxi(1, roundi(width / segment))
	var nz := maxi(1, roundi(depth / segment))
	# [start corner, direction, segment count, segment length, skip index], clockwise
	var sides := [
		[origin, Vector3.RIGHT, nx, width / nx, -1],
		[origin + Vector3(width, 0, 0), Vector3.BACK, nz, depth / nz, -1],
		[origin + Vector3(width, 0, depth), Vector3.LEFT, nx, width / nx, floori(nx / 2.0) if gate else -1],
		[origin + Vector3(0, 0, depth), Vector3.FORWARD, nz, depth / nz, -1],
	]
	for side in sides:
		var dir: Vector3 = side[1]
		var seg_len: float = side[3]
		for i in side[2]:
			if i == side[4]:
				continue
			var holder := StaticBody3D.new()
			holder.position = side[0] + dir * seg_len * (i + 0.5)
			holder.rotation.y = atan2(-dir.z, dir.x) # local +X along the side
			var piece: Node3D = scene.instantiate()
			piece.scale = Vector3.ONE * seg_len
			piece.position.z = 0.5 * seg_len # the model's fence sits on its -Z edge
			holder.add_child(piece)
			var shape := CollisionShape3D.new()
			shape.shape = BoxShape3D.new()
			shape.shape.size = Vector3(seg_len, 0.8, 0.15)
			shape.position.y = 0.4
			holder.add_child(shape)
			root.add_child(holder)
	return root
