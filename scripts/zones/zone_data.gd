class_name ZoneData
extends Resource
## One travel destination (its own scene, reached by bus). One .tres per zone in res://resources/zones/.

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export_file("*.tscn") var scene_path := ""
@export var unlock_level := 1
@export var ticket_price := 0 ## xu per bus ride to this zone
@export var order := 0 ## position on the route board
