class_name NpcData
extends Resource
## A neighbor: looks, tastes, what they say, and where they are at each hour.

@export var id: StringName
@export var display_name := ""
@export var title := "" ## short role shown under the name ("Bưu tá", ...)
@export var base_id := "character-male-a"
@export var outfits: Array[OutfitData] = []
@export var likes: Array[StringName] = [] ## item ids that make great gifts
@export var dislikes: Array[StringName] = []
## "HH zone_id Anchor" entries sorted by hour: from HH on, the neighbor hangs around the node
## named Anchor in that zone. Zone "home" = indoors (not in any zone). Before the first entry
## of the day the last one still applies (overnight).
@export var schedule: PackedStringArray = []
@export var lines: Array[String] = [] ## small talk with strangers (0-1 hearts)
@export var lines_friend: Array[String] = [] ## 2-3 hearts
@export var lines_close: Array[String] = [] ## 4-5 hearts
@export var quest: QuestData ## personal quest offered at 3 hearts


## [zone_id, anchor] at `minute` of the day.
func where(minute: float) -> PackedStringArray:
	var current := schedule[schedule.size() - 1].split(" ") if schedule.size() > 0 else PackedStringArray(["home", ""])
	for entry in schedule:
		var parts := entry.split(" ")
		if int(parts[0]) * 60 <= minute:
			current = parts
	return PackedStringArray([current[1], current[2] if current.size() > 2 else ""])


func line_for(hearts: int) -> String:
	var pool := lines_close if hearts >= 4 and lines_close.size() > 0 else (lines_friend if hearts >= 2 and lines_friend.size() > 0 else lines)
	return pool.pick_random() if pool.size() > 0 else "Chào bạn!"
