extends Node
## Autoload "Progression": XP and level. Leveling up unlocks zones (ZoneData.unlock_level).

signal xp_changed
signal leveled_up(level: int)

## XP per action.
const XP := {
	&"till": 1, &"plant": 2, &"water": 1, &"harvest": 6,
	&"fish": 5, &"fish_rare": 15, &"race": 3,
	&"weed": 1, &"spray": 1, &"fertilize": 1, &"collect": 3, &"craft": 4, &"order": 0, &"pond": 4,
}

const LEVEL_GEMS := 5 ## Lượng reward per level-up (the in-game source of premium currency)

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
		GameState.gems += LEVEL_GEMS
		GameState.money_changed.emit()
		GameState.toast("Lên cấp %d! +%d Lượng%s" % [level, LEVEL_GEMS, "  Mở khóa: " + names if names else ""])
		leveled_up.emit(level)
	xp_changed.emit()


func reward(action: StringName) -> void:
	add_xp(XP.get(action, 0))


func is_unlocked(zone: ZoneData) -> bool:
	return level >= zone.unlock_level
