class_name QuestData
extends Resource
## A quest: ordered steps, each completed by QuestManager.notify(do, what) calls.
## step = {"do": action, "what": optional id filter, "count": n, "text": shown text,
##         "zone": optional zone id, "at": optional node name the guide arrow points to}
## Actions: till plant water harvest fertilize weed spray sell buy visit talk gift fish
## collect craft order play emote pond.

enum Kind { TUTORIAL, DAILY, NPC, EVENT }

@export var id: StringName
@export var title := ""
@export var kind := Kind.TUTORIAL
@export var giver: StringName ## NpcData id for NPC quests
@export_multiline var description := ""
@export var steps: Array[Dictionary] = []
@export var reward_coins := 0
@export var reward_xp := 0
@export var reward_gems := 0
@export var reward_items := {} ## item id -> amount
@export var next: StringName ## quest started when this one is done (tutorial chain)


func reward_text() -> String:
	var parts: Array[String] = []
	if reward_coins: parts.append("%d xu" % reward_coins)
	if reward_xp: parts.append("%d EXP" % reward_xp)
	if reward_gems: parts.append("%d Lượng" % reward_gems)
	for id: StringName in reward_items:
		var item := Database.item(id)
		if item: parts.append("%d %s" % [reward_items[id], item.display_name])
	return ", ".join(parts)
