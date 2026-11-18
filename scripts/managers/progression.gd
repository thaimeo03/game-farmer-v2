extends Node
## Autoload "Progression": XP and level. Leveling up unlocks zones (ZoneData.unlock_level).

signal xp_changed
signal leveled_up(level: int)

## XP per action.
const XP := {
	&"till": 1, &"plant": 2, &"water": 1, &"harvest": 6,
	&"fish": 5, &"fish_rare": 15, &"race": 3,
}

var level := 1
var xp := 0 ## progress inside the current level


func xp_to_next(at_level: int = level) -> int:
	return 60 * at_level


func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		var unlocked := Database.zones.filter(func(z: ZoneData) -> bool: return z.unlock_level == level)
		var names := ", ".join(unlocked.map(func(z: ZoneData) -> String: return z.display_name))
		GameState.toast("Lên cấp %d!%s" % [level, "  Mở khóa: " + names if names else ""])
		leveled_up.emit(level)
	xp_changed.emit()


func reward(action: StringName) -> void:
	add_xp(XP.get(action, 0))


func is_unlocked(zone: ZoneData) -> bool:
	return level >= zone.unlock_level
