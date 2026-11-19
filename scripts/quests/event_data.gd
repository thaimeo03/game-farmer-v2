class_name EventData
extends Resource
## A seasonal event active on some days of every 30-day month: decorates zones, opens a
## stall selling limited items, and offers a quest while it lasts.

@export var id: StringName
@export var title := ""
@export_multiline var letter := "" ## mailed to the player when the event starts
@export var first_day := 13 ## day of month (1..30), inclusive
@export var last_day := 17
@export var zones: Array[StringName] = [] ## zones with an EventSpot marker that get decorated
@export var stall_title := ""
@export var stock: Array[ItemData] = []
@export var decor: PackedScene ## placed in a ring around EventSpot
@export var quest: QuestData


func is_active(day_of_month: int) -> bool:
	return day_of_month >= first_day and day_of_month <= last_day
