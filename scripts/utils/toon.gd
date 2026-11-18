class_name Toon
## Shared toon-shaded materials for placeholder primitives, cached per color.

static var _cache := {}


static func material(color: Color) -> StandardMaterial3D:
	if not _cache.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		m.specular_mode = BaseMaterial3D.SPECULAR_TOON
		_cache[color] = m
	return _cache[color]
