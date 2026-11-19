class_name LuckyWheel
extends InteractZone
## Lucky wheel: pay xu (or a Vé quay may mắn), the disc spins and stops on a weighted prize.
## Segment i of the disc model is centered at angle i*45+22.5 degrees (counter-clockwise from
## +X, seen from the front); the pointer is at the top. Limited spins per in-game day.

## [label, kind, value, weight] in disc segment order.
const PRIZES := [
	["50 xu", "coins", 50, 22], ["Vé quay", "item", &"spin_ticket", 10],
	["3 Phân bón", "item3", &"fertilizer", 16], ["5 Lượng", "gems", 5, 8],
	["100 xu", "coins", 100, 12], ["3 Hạt bí ngô", "item3", &"seed_pumpkin", 14],
	["Phụ kiện bất ngờ", "outfit", null, 4], ["20 xu", "coins", 20, 14],
]

@export var price := 20
@export var daily_limit := 5

var spinning := false

@onready var _disc: Node3D = $Disc


func _ready() -> void:
	if prompt_text == "[E] Nói chuyện":
		prompt_text = "[E] Vòng Quay May Mắn"
	super()


func interact(_player: Player) -> void:
	if spinning:
		return
	var left := daily_limit - GameState.daily_count("wheel")
	var tickets := GameState.inventory.count(Database.item(&"spin_ticket"))
	hud().open_menu("Vòng Quay May Mắn", [
		{"text": "Còn %d lượt hôm nay. Giải: xu, Lượng, phân bón, hạt hiếm, phụ kiện..." % left},
		{"text": "Quay bằng xu (%d xu)" % price, "buttons": [["Quay", spin.bind(false), left > 0 and GameState.coins >= price]]},
		{"text": "Quay bằng vé (có %d vé)" % tickets, "buttons": [["Quay", spin.bind(true), left > 0 and tickets > 0]]},
	])


## Pays, picks the prize, plays the spin and grants it. Returns the prize index (-1 if not spun).
func spin(use_ticket: bool, animate := true) -> int:
	if spinning:
		return -1
	if use_ticket:
		if GameState.inventory.count(Database.item(&"spin_ticket")) == 0:
			return -1
	elif GameState.coins < price:
		GameState.toast("Không đủ xu!")
		return -1
	if not GameState.daily_use("wheel", daily_limit):
		return -1
	if use_ticket:
		GameState.inventory.remove(Database.item(&"spin_ticket"))
	else:
		GameState.spend(price)
	var index := pick_prize()
	if animate:
		spinning = true
		GameState.ui_busy = true
		var target := deg_to_rad(90.0 - (index * 45.0 + 22.5)) # bring that segment under the pointer
		var start := fposmod(_disc.rotation.z, TAU)
		var tw := create_tween()
		tw.tween_property(_disc, "rotation:z", start + TAU * 4.0 + fposmod(target - start, TAU), 3.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		await tw.finished
		spinning = false
		GameState.ui_busy = false
	grant(index)
	return index


static func pick_prize() -> int:
	var total := 0
	for p in PRIZES:
		total += p[3]
	var r := randi() % total
	for i in PRIZES.size():
		r -= PRIZES[i][3]
		if r < 0:
			return i
	return PRIZES.size() - 1


static func grant(index: int) -> void:
	var p: Array = PRIZES[index]
	match p[1]:
		"coins":
			GameState.earn(p[2])
		"gems":
			GameState.gems += p[2]
			GameState.money_changed.emit()
		"item":
			GameState.inventory.add(Database.item(p[2]))
		"item3":
			GameState.inventory.add(Database.item(p[2]), 3)
		"outfit":
			var choices := Database.outfits.values().filter(func(o: OutfitData) -> bool:
				return o.gem_price == 0 and GameState.inventory.count(o.item) == 0)
			if choices.is_empty():
				GameState.earn(100)
				GameState.toast("Trúng: 100 xu (đã đủ phụ kiện)")
				return
			var o: OutfitData = choices.pick_random()
			GameState.inventory.add(o.item)
			GameState.toast("Trúng phụ kiện: %s!" % o.item.display_name)
			return
	GameState.toast("Trúng: %s!" % p[0])
